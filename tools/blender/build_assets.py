"""Rebuild the first 3D asset family with Blender's bundled Python.

Run: blender --background --python tools/blender/build_assets.py
No external packages or model services. Blender +Y becomes Godot -Z (forward).
"""
import json
import math
import random
import argparse
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/game"
SOURCE = ROOT / "art-source/blender"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)


TEXTURE_DIR = SOURCE / "textures"
PANEL_TILE_METRES = 0.5  # one repeat of the 4x4 panel texture; panels come out ~12 cm wide


def build_panel_texture(path, size=512, cells=4):
    """Seamless greyscale panel detail: grooves, lips, rivets, vent slits and speckle.

    Multiplied into each material's base colour, so it adds structure without changing hue. Seeded for stable output.
    """
    rng = np.random.default_rng(11)
    cell = size // cells
    yy, xx = np.mgrid[0:size, 0:size]
    lx, ly = xx % cell, yy % cell
    edge = np.minimum.reduce([lx, cell - 1 - lx, ly, cell - 1 - ly])
    img = 0.95 - rng.random((size, size)) * 0.07
    img = np.where((edge >= 3) & (edge < 6), img * 0.9 + 0.1, img)  # raised lip beside the seam
    img = np.where(edge < 3, 0.38, img)  # groove
    cx, cy = lx - cell / 2, ly - cell / 2
    for sx in (-1, 1):
        for sy in (-1, 1):
            dist = np.hypot(lx - (cell / 2 + sx * (cell / 2 - 14)), ly - (cell / 2 + sy * (cell / 2 - 14)))
            img = np.where(dist < 3.2, 1.0, np.where(dist < 4.8, img * 0.7, img))  # rivet with shadow ring
    cell_x, cell_y = xx // cell, yy // cell
    vent = ((cell_x + 2 * cell_y) % 5 == 1) & (np.abs(cx) < cell * 0.28) & (np.abs(cy) < cell * 0.24)
    slats = (ly // 6) % 2 == 0
    img = np.where(vent & slats, 0.3, np.where(vent, img * 0.82, img))
    img = np.clip(img, 0.0, 1.0)
    pixels = np.stack([img, img, img, np.ones_like(img)], axis=-1).astype(np.float32)
    image = bpy.data.images.new("panel_detail_gen", size, size, alpha=False)
    image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def panel_image():
    path = TEXTURE_DIR / "panel_detail.png"
    if not path.exists():
        TEXTURE_DIR.mkdir(parents=True, exist_ok=True)
        build_panel_texture(path)
    image = bpy.data.images.get("panel_detail") or bpy.data.images.load(str(path))
    image.name = "panel_detail"
    return image


def material(name, color, metal=0.0, glow=False, textured=True, glow_strength=2.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = 0.38
    if glow:
        shader.inputs["Emission Color"].default_value = (*color, 1)
        shader.inputs["Emission Strength"].default_value = glow_strength
    elif textured:
        # Emissive parts stay clean; everything else gets the panel detail multiplied into its colour.
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        texture = nodes.new("ShaderNodeTexImage")
        texture.image = panel_image()
        texture.extension = "REPEAT"
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs[6].default_value = (*color, 1)
        links.new(texture.outputs["Color"], mix.inputs[7])
        links.new(mix.outputs[2], shader.inputs["Base Color"])
    return mat


def empty(name, pos=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = pos
    return obj


def project_uvs(obj, mapping):
    """World-density UVs so the tiled panel texture has the same scale on every part.

    "cyl" wraps around the Z axis (barrels, struts, rims) with caps projected flat; "box" projects each face
    along its dominant normal axis.
    """
    mesh = obj.data
    layer = mesh.uv_layers.active or mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        normal = polygon.normal
        axis = max(range(3), key=lambda i: abs(normal[i]))
        angles = []
        for loop_index in polygon.loop_indices:
            co = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            if mapping == "cyl" and axis != 2:
                angle = math.atan2(co.y, co.x)
                if angles:  # keep the face contiguous across the +-pi seam
                    angle += math.tau * round((angles[0] - angle) / math.tau)
                angles.append(angle)
                u, v = angle * math.hypot(co.x, co.y), co.z
            elif axis == 0:
                u, v = co.y, co.z
            elif axis == 1:
                u, v = co.x, co.z
            else:
                u, v = co.x, co.y
            layer.data[loop_index].uv = (u / PANEL_TILE_METRES, v / PANEL_TILE_METRES)


def finish(obj, name, mat, parent, mapping="box"):
    project_uvs(obj, mapping)
    obj.name = name
    obj.data.materials.append(mat)
    obj.parent = parent
    return obj


SHARP_ANGLE = math.radians(35)
AO_SAMPLES = 96
AO_DISTANCE = 0.4
AO_FLOOR = 0.3  # darkest baked value; keeps crevices readable instead of black


def bevel(obj, width, segments=2):
    """Round hard edges so they catch highlights; the angle limit leaves smooth curved surfaces alone."""
    modifier = obj.modifiers.new("Machined edges", "BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    modifier.angle_limit = SHARP_ANGLE
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def smooth_by_angle(obj):
    """Smooth shading with hard edges kept above SHARP_ANGLE, so bevels shade as a gradient and flat faces stay flat."""
    mesh = obj.data
    mesh.shade_smooth()
    editor = bmesh.new()
    editor.from_mesh(mesh)
    for edge in editor.edges:
        if len(edge.link_faces) == 2 and edge.calc_face_angle(0.0) > SHARP_ANGLE:
            edge.smooth = False
    editor.to_mesh(mesh)
    editor.free()


def box(name, pos, size, mat, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel(obj, min(0.03, min(size) * 0.3))
    smooth_by_angle(obj)
    return finish(obj, name, mat, parent)


def cylinder(name, pos, radius, depth, mat, parent=None, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos)
    obj = bpy.context.object
    # Thin struts get a single narrow bevel; chunky bodies get a rounder two-segment one.
    bevel(obj, min(0.02, radius * 0.25, depth * 0.25), 1 if radius < 0.1 else 2)
    smooth_by_angle(obj)
    return finish(obj, name, mat, parent, "cyl")


def sphere(name, pos, radius, mat, parent=None, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=radius, location=pos)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return finish(obj, name, mat, parent)


def strut(name, start, end, radius, mat, parent=None):
    a, b = Vector(start), Vector(end)
    obj = cylinder(name, (a + b) / 2, radius, (b - a).length, mat, parent, 8)
    obj.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    return obj


def bake_ambient_occlusion(meshes):
    """Bake AO into a per-corner vertex colour (exported as COLOR_0, which Godot multiplies into albedo).

    Rays are cast against the whole assembled model in its rest pose, so parts shade each other. Emission is
    unaffected by vertex colour, so glowing parts keep their glow. Runtime-rotated parts (Aim, legs) keep the
    rest-pose AO; the term is subtle enough that this is not visible in motion.
    """
    bpy.context.view_layer.update()
    vertices, triangles = [], []
    for obj in meshes:
        base = len(vertices)
        vertices.extend(obj.matrix_world @ v.co for v in obj.data.vertices)
        obj.data.calc_loop_triangles()
        triangles.extend(tuple(base + i for i in tri.vertices) for tri in obj.data.loop_triangles)
    tree = BVHTree.FromPolygons(vertices, triangles)
    rng = random.Random(7)  # fixed seed keeps rebuilt GLBs byte-stable
    for obj in meshes:
        mesh = obj.data
        normal_matrix = obj.matrix_world.to_3x3().inverted().transposed()
        colors = mesh.color_attributes.new("AO", "BYTE_COLOR", "CORNER")
        normals = mesh.corner_normals
        values = []
        for loop in mesh.loops:
            position = obj.matrix_world @ mesh.vertices[loop.vertex_index].co
            normal = (normal_matrix @ normals[loop.index].vector).normalized()
            tangent = normal.cross(Vector((0, 0, 1) if abs(normal.z) < 0.9 else (1, 0, 0))).normalized()
            bitangent = normal.cross(tangent)
            origin = position + normal * 0.004
            hits = 0.0
            for _ in range(AO_SAMPLES):
                # Cosine-weighted hemisphere sample.
                r1, r2 = rng.random(), rng.random()
                radius, angle = math.sqrt(r1), math.tau * r2
                direction = tangent * (radius * math.cos(angle)) + bitangent * (radius * math.sin(angle))                     + normal * math.sqrt(1 - r1)
                hit = tree.ray_cast(origin, direction, AO_DISTANCE)
                if hit[0] is not None:
                    hits += 1.0 - hit[3] / AO_DISTANCE  # nearer occluders darken more
            occlusion = hits / AO_SAMPLES
            values.append(AO_FLOOR + (1.0 - AO_FLOOR) * (1.0 - occlusion) ** 1.5)
        for loop_index, value in enumerate(values):
            colors.data[loop_index].color = (value, value, value, 1.0)
        mesh.color_attributes.active_color = colors
        mesh.color_attributes.render_color_index = list(mesh.color_attributes).index(colors)


def save_asset(name, reference, sockets, origin="ground centre"):
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    bake_ambient_occlusion(meshes)
    triangles = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / f"{name}.blend"))
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{name}.glb"), export_format="GLB",
                              export_yup=True, export_animations=False, export_cameras=False,
                              export_lights=False, export_vertex_color="ACTIVE")
    return {"id": name, "triangles": triangles, "mesh_parts": len(meshes),
            "materials": len({m.name for o in meshes for m in o.data.materials}),
            "reference": reference, "required_nodes": sockets,
            "source": f"art-source/blender/{name}.blend",
            "model": f"assets/models/game/{name}.glb",
            "forward": "Godot -Z", "units": "metres", "origin": origin,
            "animation": "Runtime rigid-part articulation; no skeletal rig"}


def build_turret():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shell = material("Ceramic silver", (0.65, 0.76, 0.8), 0.65)
    dark = material("Graphite", (0.035, 0.07, 0.1), 0.7)
    cyan = material("Ion cyan", (0.04, 0.8, 1), 0.2, True)
    root = empty("TurretModel")
    cylinder("Foot", (0, 0, 0.12), 0.43, 0.24, dark, root)
    cylinder("BaseRim", (0, 0, 0.27), 0.38, 0.09, shell, root)
    cylinder("Reactor", (0, 0, 0.45), 0.17, 0.32, cyan, root)
    for angle in (0, 2.094, 4.189):
        x, y = math.cos(angle), math.sin(angle)
        strut("Support", (x * .17, y * .17, .5), (x * .44, y * .44, .06), .055, shell, root)
    aim = empty("Aim", (0, 0, .63), root)
    box("Housing", (0, 0, .02), (.5, .45, .25), shell, aim)
    box("TopInset", (0, -.03, .16), (.3, .28, .035), dark, aim)
    for x in (-.105, .105):
        strut("Barrel", (x, .15, .02), (x, .64, .02), .06, dark, aim)
        tip = cylinder("Emitter", (x, .655, .02), .068, .035, cyan, aim)
        tip.rotation_euler.x = math.pi / 2
    empty("Muzzle", (0, .7, .02), aim)
    return save_asset("ion_turret", "assets/sprites/turrets/turret_basic.png", ["Aim", "Muzzle"])


def build_drone(charger=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shell = material("Drone graphite", (.12, .16, .2), .6)
    orange = material("Hazard copper", (.95, .34, .04), .45)
    red = material("Threat red", (1, .035, .12), .1, True)
    root = empty("DroneModel")
    sphere("Carapace", (0, 0, .48), .34, shell, root, (1, 1.1, .85))
    cylinder("Crown", (0, 0, .7), .16, .055, orange, root)
    eye = cylinder("EyeRing", (0, .32, .5), .15, .09, orange, root)
    eye.rotation_euler.x = math.pi / 2
    sphere("Eye", (0, .375, .5), .112, red, root, (1, .4, 1))
    if charger:
        # Broad amber armor and forward horns identify a charger at gameplay scale.
        box("RamArmor", (0, .04, .69), (.63, .55, .12), orange, root)
        for side in (-1, 1):
            strut("RamHorn", (side * .2, .28, .59), (side * .26, .66, .49), .055, orange, root)
        box("Spine", (0, -.16, .81), (.1, .3, .07), red, root)
    for side in (-1, 1):
        for index, y in enumerate((-.23, 0, .23)):
            leg = empty(f"Leg_{'L' if side < 0 else 'R'}_{index}", (side * .25, y, .43), root)
            knee = (side * .23, y * .35, .06)
            foot = (side * .35, y * .55, -.39)
            strut("Upper", (0, 0, 0), knee, .048, orange, leg)
            strut("Lower", knee, foot, .04, shell, leg)
            sphere("Joint", knee, .063, red, leg)
    return save_asset("charger_drone" if charger else "spider_drone", "assets/sprites/enemy_spider_drone/spider_drone_right.png",
                      [f"Leg_{side}_{i}" for side in ("L", "R") for i in range(3)])


def build_plasma():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shell = material("Ceramic silver", (.65, .76, .8), .65)
    dark = material("Graphite", (.035, .07, .1), .7)
    energy = material("Plasma violet", (.48, .08, 1), .2, True)
    root = empty("PlasmaModel")
    cylinder("Foot", (0, 0, .13), .47, .26, dark, root)
    cylinder("BaseRim", (0, 0, .29), .43, .07, shell, root)
    cylinder("Reactor", (0, 0, .48), .18, .34, energy, root)
    for angle in (0, 2.094, 4.189):
        x, y = math.cos(angle), math.sin(angle)
        strut("Support", (x * .2, y * .2, .6), (x * .4, y * .4, .15), .045, shell, root)
    aim = empty("Aim", (0, 0, .67), root)
    sphere("Chamber", (0, 0, .03), .24, dark, aim, (1, 1.2, 1))
    for y in (.05, .23, .4):
        ring = cylinder("AccelerationRing", (0, y, .03), .23, .045, shell, aim)
        ring.rotation_euler.x = math.pi / 2
    sphere("PlasmaCore", (0, .28, .03), .16, energy, aim, (1, 1.7, 1))
    for x in (-.21, .21):
        box("Rail", (x, .22, .03), (.055, .6, .1), dark, aim)
    empty("Muzzle", (0, .55, .03), aim)
    return save_asset("plasma_turret", "assets/sprites/turrets/turret_plasma_static.png", ["Aim", "Muzzle"])


def build_player():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shell = material("Scout silver", (.62, .75, .77), .6)
    copper = material("Scout copper", (.65, .3, .1), .55)
    cyan = material("Scout cyan", (.03, .9, .85), .2, True)
    root = empty("PlayerModel")
    sphere("Hull", (0, 0, .52), .32, shell, root, (1, .85, 1.12))
    cylinder("Waist", (0, 0, .4), .305, .08, copper, root)
    cylinder("HoverRing", (0, 0, .17), .18, .055, cyan, root)
    sphere("Dome", (0, 0, .87), .245, copper, root, (1, 1, .8))
    sphere("Visor", (0, .205, .88), .175, cyan, root, (1, .35, .65))
    for side in (-1, 1):
        sphere("Shoulder", (side * .33, 0, .58), .115, copper, root)
        box("SidePlate", (side * .34, 0, .48), (.12, .25, .27), shell, root)
    strut("Gun", (.34, 0, .58), (.34, .47, .58), .065, copper, root)
    sphere("Emitter", (.34, .47, .58), .05, cyan, root)
    empty("Muzzle", (.34, .53, .58), root)
    return save_asset("player_bot", "assets/sprites/player/player_static.png", ["Muzzle"])


def build_shock():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    shell = material("Shock silver", (.65, .76, .8), .65)
    dark = material("Shock graphite", (.035, .07, .1), .7)
    energy = material("Shock cyan", (.04, .75, 1), .2, True)
    root = empty("ShockModel")
    cylinder("Foot", (0, 0, .12), .47, .24, dark, root)
    cylinder("Rim", (0, 0, .26), .44, .08, shell, root)
    cylinder("Core", (0, 0, .49), .17, .42, energy, root)
    for angle in (0, 2.094, 4.189):
        x, y = math.cos(angle), math.sin(angle)
        strut("Support", (x * .17, y * .17, .67), (x * .37, y * .37, .25), .065, shell, root)
    aim = empty("Aim", (0, 0, .74), root)
    cylinder("EmitterRing", (0, 0, 0), .4, .1, shell, aim)
    sphere("PulseDome", (0, 0, .07), .27, energy, aim, (1, 1, .8))
    for index in range(6):
        angle = index * math.tau / 6
        box("Electrode", (.34 * math.cos(angle), .34 * math.sin(angle), .11), (.11, .11, .18), dark, aim)
    empty("Muzzle", (0, .45, .08), aim)
    return save_asset("shock_turret", "assets/sprites/turrets/turret_shock.png", ["Aim", "Muzzle"])


def build_scrap():
    """Scrap pickup: a faceted energy crystal with a few salvaged plates, centred on its own origin so it spins in place."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    amber = material("Scrap amber", (1, .34, .02), .1, True, glow_strength=0.55)
    metal = material("Scrap metal", (.1, .13, .16), .7, textured=False)
    root = empty("ScrapModel")
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=.1, location=(0, 0, 0))
    crystal = bpy.context.object
    crystal.scale = (.8, .8, 1.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish(crystal, "Crystal", amber, root)  # flat shaded on purpose: the facets are the look
    for index, angle in enumerate((0.4, 2.5, 4.4)):
        plate = box(f"Plate{index}", (math.cos(angle) * .105, math.sin(angle) * .105, (-.05, .03, -.015)[index]),
                    (.06, .11, .014), metal, root)
        plate.rotation_euler = (.5 + index * .25, .35, angle)
    return save_asset("scrap_shard", "assets/sprites/scrap_sprite.png", [], origin="model centre")


builders = {"ion_turret": build_turret, "spider_drone": build_drone,
            "plasma_turret": build_plasma, "scrap_shard": build_scrap, "charger_drone": lambda: build_drone(True), "player_bot": build_player,
            "shock_turret": build_shock}
parser = argparse.ArgumentParser()
parser.add_argument("--only", nargs="+", choices=list(builders))
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
manifest_path = OUT / "manifest.json"
previous = json.loads(manifest_path.read_text(encoding="utf-8"))["assets"] if manifest_path.exists() else []
by_id = {asset["id"]: asset for asset in previous}
for name in args.only or builders:
    by_id[name] = builders[name]()
assets = [by_id[name] for name in builders if name in by_id]
manifest_path.write_text(json.dumps({"version": 2, "generator": "tools/blender/build_assets.py",
    "blender": bpy.app.version_string, "assets": assets}, indent=2) + "\n", encoding="utf-8", newline="\n")
print("ASSET_MANIFEST " + json.dumps(assets))

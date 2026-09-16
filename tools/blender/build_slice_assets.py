"""Rebuild the first 3D asset family with Blender's bundled Python.

Run: blender --background --python tools/blender/build_slice_assets.py
No external packages or model services. Blender +Y becomes Godot -Z (forward).
"""
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/slice"
SOURCE = ROOT / "art-source/blender"
OUT.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)


def material(name, color, metal=0.0, glow=False):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metal
    shader.inputs["Roughness"].default_value = 0.38
    if glow:
        shader.inputs["Emission Color"].default_value = (*color, 1)
        shader.inputs["Emission Strength"].default_value = 2.0
    return mat


def empty(name, pos=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = pos
    return obj


def finish(obj, name, mat, parent):
    obj.name = name
    obj.data.materials.append(mat)
    obj.parent = parent
    return obj


def box(name, pos, size, mat, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new("Machined edges", "BEVEL")
    bevel.width = 0.025
    bevel.segments = 1
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return finish(obj, name, mat, parent)


def cylinder(name, pos, radius, depth, mat, parent=None, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos)
    return finish(bpy.context.object, name, mat, parent)


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


def save_asset(name, reference, sockets):
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    triangles = 0
    for obj in meshes:
        obj.data.calc_loop_triangles()
        triangles += len(obj.data.loop_triangles)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / f"{name}.blend"))
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{name}.glb"), export_format="GLB",
                              export_yup=True, export_animations=False, export_cameras=False,
                              export_lights=False)
    return {"id": name, "triangles": triangles, "mesh_parts": len(meshes),
            "materials": len({m.name for o in meshes for m in o.data.materials}),
            "reference": reference, "required_nodes": sockets,
            "source": f"art-source/blender/{name}.blend",
            "model": f"assets/models/slice/{name}.glb",
            "forward": "Godot -Z", "units": "metres", "origin": "ground centre",
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


def build_drone():
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
    for side in (-1, 1):
        for index, y in enumerate((-.23, 0, .23)):
            leg = empty(f"Leg_{'L' if side < 0 else 'R'}_{index}", (side * .25, y, .43), root)
            knee = (side * .23, y * .35, .06)
            foot = (side * .35, y * .55, -.39)
            strut("Upper", (0, 0, 0), knee, .048, orange, leg)
            strut("Lower", knee, foot, .04, shell, leg)
            sphere("Joint", knee, .063, red, leg)
    return save_asset("spider_drone", "assets/sprites/enemy_spider_drone/spider_drone_right.png",
                      [f"Leg_{side}_{i}" for side in ("L", "R") for i in range(3)])


assets = [build_turret(), build_drone()]
(OUT / "manifest.json").write_text(json.dumps({"version": 1, "generator": "tools/blender/build_slice_assets.py",
    "blender": bpy.app.version_string, "assets": assets}, indent=2) + "\n", encoding="utf-8", newline="\n")
print("ASSET_MANIFEST " + json.dumps(assets))

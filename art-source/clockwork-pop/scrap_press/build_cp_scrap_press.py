"""Clockwork scrap press - scripted Blender build.

Run: blender --background --python build_cp_scrap_press.py
Exports cp_scrap_press.glb next to this script. Metres, +Z up, weapon forward = +Y.
Aim (rotating head: piston housing + plunger) pivots on the vertical axis at the origin; Muzzle sits at the coin tray edge.
"""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

OUT = Path(__file__).resolve().parent
SHARP = math.radians(35)

bpy.ops.wm.read_factory_settings(use_empty=True)


# ---------------------------------------------------------------- helpers
def material(name, color, metal=0.0, rough=0.4, glow=0.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    sh = mat.node_tree.nodes.get("Principled BSDF")
    sh.inputs["Base Color"].default_value = (*color, 1)
    sh.inputs["Metallic"].default_value = metal
    sh.inputs["Roughness"].default_value = rough
    if glow:
        sh.inputs["Emission Color"].default_value = (*color, 1)
        sh.inputs["Emission Strength"].default_value = glow
    return mat


def empty(name, pos=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = pos
    return obj


def activate(obj):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)


def bevel(obj, width, segments=3):
    if width <= 0:
        return
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = SHARP
    activate(obj)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def smooth(obj):
    mesh = obj.data
    mesh.shade_smooth()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > SHARP:
            e.smooth = False
    bm.to_mesh(mesh)
    bm.free()


def finish(obj, name, mat, bevel_w=0.0, bevel_seg=3):
    bevel(obj, bevel_w, bevel_seg)
    smooth(obj)
    obj.name = name
    obj.data.name = name
    obj.data.materials.append(mat)
    return obj


def box(name, pos, size, mat, bw=0.03, seg=3, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler = rot
    return finish(obj, name, mat, min(bw, min(size) * 0.45), seg)


def cyl(name, pos, radius, depth, mat, axis="Z", bw=0.01, seg=2, verts=32, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=pos)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=r2, depth=depth, location=pos)
    obj = bpy.context.object
    if axis == "X":
        obj.rotation_euler = (0, math.radians(90), 0)
    elif axis == "Y":
        obj.rotation_euler = (math.radians(-90), 0, 0)
    return finish(obj, name, mat, min(bw, radius * 0.45, depth * 0.45), seg)


def sphere(name, pos, radius, mat, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=radius, location=pos)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat)


def prism_xz(name, pts, y0, y1, mat, bw=0.04, seg=4):
    """Extrude a polygon given in (x, z) along Y between y0 and y1, then round its edges."""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    verts = [bm.verts.new((x, y0, z)) for x, z in pts]
    face = bm.faces.new(verts)
    ret = bmesh.ops.extrude_face_region(bm, geom=[face])
    moved = [v for v in ret["geom"] if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=Vector((0, y1 - y0, 0)), verts=moved)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, bw, seg)


def tray(name, pos, size, wall, depth, mat, bw=0.03):
    """Open rounded tub: a box with an inset top face pushed down."""
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    top = max(bm.faces, key=lambda f: f.calc_center_median().z)
    inset = bmesh.ops.inset_individual(bm, faces=[top], thickness=wall)
    ext = bmesh.ops.extrude_discrete_faces(bm, faces=[top])
    for f in ext["faces"]:
        bmesh.ops.translate(bm, vec=Vector((0, 0, -depth)), verts=list(f.verts))
    bm.to_mesh(obj.data)
    bm.free()
    return finish(obj, name, mat, bw, 3)


def dish(name, pos, radius, r_small, length, wall, mat, bw=0.012):
    """Hollow bell (funnel): cone, large end inset and pushed in. Large end faces +Z before rotation."""
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=r_small, radius2=radius, depth=length, location=pos)
    obj = bpy.context.object
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    top = max(bm.faces, key=lambda f: f.calc_center_median().z)
    bmesh.ops.inset_individual(bm, faces=[top], thickness=wall)
    ext = bmesh.ops.extrude_discrete_faces(bm, faces=[top])
    for f in ext["faces"]:
        bmesh.ops.translate(bm, vec=Vector((0, 0, -length * 0.8)), verts=list(f.verts))
    bm.to_mesh(obj.data)
    bm.free()
    return finish(obj, name, mat, bw, 2)


def inset_cap(obj, thickness, push):
    """Coin / badge detail: inset the top face and push it slightly down."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    top = max(bm.faces, key=lambda f: f.calc_center_median().z)
    bmesh.ops.inset_individual(bm, faces=[top], thickness=thickness)
    bmesh.ops.translate(bm, vec=Vector((0, 0, -push)), verts=list(top.verts))
    bm.to_mesh(obj.data)
    bm.free()


def join(objs, name, parent=None):
    target = objs[0]
    if len(objs) == 1:
        target.name = name
        target.parent = parent
        return target
    with bpy.context.temp_override(active_object=target, object=target, selected_editable_objects=objs,
                                   selected_objects=objs):
        bpy.ops.object.join()
    target.name = name
    target.data.name = name
    smooth(target)
    target.parent = parent
    return target


# ---------------------------------------------------------------- materials (10)
TEAL = material("Teal enamel", (0.02, 0.42, 0.40), 0.0, 0.35)
TEAL_DARK = material("Teal slate", (0.06, 0.24, 0.32), 0.0, 0.42)
CORAL = material("Coral enamel", (0.80, 0.12, 0.08), 0.0, 0.33)
BRASS = material("Brass", (0.80, 0.50, 0.08), 0.9, 0.28)
STEEL = material("Steel", (0.20, 0.20, 0.23), 0.85, 0.35)
CREAM = material("Cream enamel", (0.95, 0.75, 0.40), 0.0, 0.4)
GOLD = material("Gold coin", (1.0, 0.66, 0.06), 0.95, 0.22)
RUBBER = material("Rubber", (0.12, 0.07, 0.07), 0.0, 0.7)
PURPLE = material("Purple knob", (0.20, 0.15, 0.50), 0.0, 0.4)
GLOW = material("Porthole glow", (1.0, 0.85, 0.15), 0.0, 0.2, glow=2.0)

PX = 0.38   # pillar centre
PED = 0.38  # pedestal centre
TOPZ = 1.2  # top of pillars / housing
PD = 0.19   # pillar half depth (Y)

# ---------------------------------------------------------------- static body
feet = []
for sx in (-1, 1):
    for sy in (-1, 1):
        feet.append(box("foot", (sx * 0.42, sy * 0.36, 0.06), (0.3, 0.27, 0.12), RUBBER, 0.045, 3))
feet = join(feet, "Feet")

plate = box("BasePlate", (0, 0, 0.14), (1.05, 0.92, 0.13), TEAL, 0.05, 3)
block = box("BaseBlock", (0, 0, 0.29), (0.8, 0.72, 0.2), TEAL_DARK, 0.04, 3)
block.name = "BaseBlock"

ped = []
for sx in (-1, 1):
    ped.append(box("pedestal", (sx * PED, -0.02, 0.42), (0.32, 0.5, 0.44), CORAL, 0.07, 3))
pedestals = join(ped, "Pedestals")

# Teal arch: L-shaped pillars whose arms reach in over the piston housing
frame_parts = []
for sx in (-1, 1):
    pts = [(PX - 0.1, 0.62), (PX + 0.1, 0.62), (PX + 0.1, TOPZ), (0.15, TOPZ), (0.15, TOPZ - 0.18),
           (PX - 0.1, TOPZ - 0.18)]
    pts = [(sx * x, z) for x, z in pts]
    if sx < 0:
        pts.reverse()
    frame_parts.append(prism_xz("pillar", pts, -PD, PD, TEAL, 0.07, 3))
frame_parts.append(cyl("neck", (-0.5, 0.0, 0.98), 0.06, 0.1, TEAL, "X", 0.01, 2, 20))
funnel = dish("funnel", (0, 0, 0), 0.18, 0.08, 0.22, 0.03, TEAL, 0.012)
funnel.rotation_euler = (0, math.radians(-80), 0)  # opening faces -X, tilted slightly up
funnel.location = (-0.62, 0.0, 1.0)
frame_parts.append(funnel)
frame = join(frame_parts, "Frame")
nozzle = cyl("Nozzle", (-0.57, 0.0, 0.86), 0.04, 0.1, RUBBER, "Z", 0.01, 2, 12)

# Brass hardware on the pillars and pedestals
brass_parts, dots = [], []
for sx in (-1, 1):
    brass_parts.append(cyl("bolt_disc", (sx * 0.5, 0.0, 1.0), 0.1, 0.045, BRASS, "X", 0.015, 2, 24))
    brass_parts.append(cyl("bolt_stud", (sx * 0.545, 0.0, 1.0), 0.052, 0.07, BRASS, "X", 0.012, 2, 16))
    brass_parts.append(sphere("bolt_ball", (sx * 0.48, 0.0, 0.78), 0.055, BRASS))
    brass_parts.append(cyl("ped_ring", (sx * 0.555, 0.0, 0.42), 0.11, 0.05, BRASS, "X", 0.015, 2, 24))
    dots.append(cyl("ped_dot", (sx * 0.585, 0.0, 0.42), 0.058, 0.03, RUBBER, "X", 0.008, 1, 16))
brass_static = join(brass_parts, "BrassTrim")
dots_obj = join(dots + [nozzle], "RubberDetails")

purple = cyl("Knob", (0.42, -0.25, 0.9), 0.075, 0.14, PURPLE, "Y", 0.015, 2, 20)

# Press die (steel) sits behind the coin tray
die_parts = [
    box("die_base", (0, -0.1, 0.42), (0.5, 0.36, 0.1), STEEL, 0.02, 2),
    box("die_top", (0, -0.1, 0.52), (0.46, 0.32, 0.1), STEEL, 0.025, 3),
]
die = join(die_parts, "Die")

# Cream coin tray, open towards +Y
tray_obj = tray("CoinTray", (0.0, 0.27, 0.43), (0.9, 0.82, 0.17), 0.06, 0.09, CREAM, 0.04)

# Gold coins on the tray floor (floor is at z=0.43+0.085-0.09=0.425)
coins = []
for (cx, cy, rr) in ((0.05, 0.36, 0.135), (-0.16, 0.28, 0.12), (0.22, 0.38, 0.115)):
    c = cyl("coin", (cx, cy, 0.44), rr, 0.03, GOLD, "Z", 0.006, 2, 28)
    inset_cap(c, 0.014, 0.004)
    coins.append(c)
coins[0].location.z += 0.03   # top coin rests on the others
coins = join(coins, "Coins")

# ---------------------------------------------------------------- Aim: piston housing and plunger
aim = empty("Aim", (0, 0, 0))

HB = TOPZ - 0.44  # housing bottom
HR = 0.225
housing_parts = [cyl("housing", (0, 0, HB + 0.22), HR, 0.44, CORAL, "Z", 0.035, 3, 40)]
for sx in (-1, 1):
    housing_parts.append(cyl("nub", (sx * 0.235, 0.0, TOPZ - 0.12), 0.06, 0.1, CORAL, "X", 0.015, 2, 16))
housing = join(housing_parts, "Housing", aim)

brass_parts = [
    cyl("band", (0, 0, HB + 0.04), 0.255, 0.1, BRASS, "Z", 0.02, 2, 40),
    cyl("cap", (0, 0, TOPZ + 0.04), 0.29, 0.09, BRASS, "Z", 0.03, 3, 40),
    cyl("cap_step", (0, 0, TOPZ + 0.1), 0.19, 0.04, BRASS, "Z", 0.012, 2, 32),
    cyl("collar", (0, 0, TOPZ + 0.14), 0.1, 0.05, BRASS, "Z", 0.012, 2, 24),
    cyl("rod", (0, 0, TOPZ + 0.24), 0.06, 0.22, BRASS, "Z", 0.01, 1, 24),
    cyl("plunger", (0, 0, TOPZ + 0.33), 0.1, 0.1, BRASS, "Z", 0.025, 3, 28),
]
head_brass = join(brass_parts, "PistonBrass", aim)

ram_parts = [
    cyl("ram_collar", (0, 0, HB - 0.045), 0.13, 0.05, STEEL, "Z", 0.012, 2, 24),
    cyl("ram", (0, 0, HB - 0.12), 0.05, 0.1, STEEL, "Z", 0.008, 1, 16),
    cyl("ram_foot", (0, 0, HB - 0.19), 0.085, 0.05, STEEL, "Z", 0.01, 2, 24),
]
ram = join(ram_parts, "PistonRam", aim)

bpy.ops.mesh.primitive_torus_add(major_radius=0.075, minor_radius=0.024, major_segments=24, minor_segments=8,
                                 location=(0, HR - 0.015, HB + 0.24), rotation=(math.radians(90), 0, 0))
ring = bpy.context.object
finish(ring, "PortholeRing", STEEL)
ring.parent = aim
glass = sphere("PortholeGlow", (0, HR - 0.005, HB + 0.24), 0.07, GLOW, (1, 0.5, 1))
glass.parent = aim

muzzle = empty("Muzzle", (0, 0.66, 0.52), aim)

# ---------------------------------------------------------------- export
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=str(OUT / "cp_scrap_press.glb"), export_format="GLB", export_yup=True,
                          export_animations=False, export_cameras=False, export_lights=False)
tris = 0
for o in bpy.context.scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
        print("  ", o.name, len(o.data.loop_triangles))
print("BUILD_OK triangles", tris)

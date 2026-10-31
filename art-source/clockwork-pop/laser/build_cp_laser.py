"""Clockwork laser prism - scripted Blender model.

Run: blender --background --python build_cp_laser.py
Blender +Z up, weapon faces +Y. Aim (rotating head) pivots on the vertical axis at the pole top; Muzzle sits under Aim.
"""
import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT = Path(__file__).parent
SHARP_ANGLE = math.radians(35)

AIM_Z = 0.62          # pole top / head pivot height
BODY_Z = 0.46         # body axis height above the Aim pivot
BODY_R = 0.44
BODY_Y0, BODY_Y1 = -0.45, 0.38
RING_Y0, RING_Y1 = 0.30, 0.52
RING_RI, RING_RO = 0.43, 0.56

bpy.ops.wm.read_factory_settings(use_empty=True)


# --------------------------------------------------------------------------------------------- materials
def srgb(hexcol):
    h = hexcol.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def material(name, hexcol, metal=0.0, rough=0.4, alpha=1.0, glow=0.0, glow_col=None, vcol=False):
    mat = bpy.data.materials.new(name)
    col = srgb(hexcol)
    mat.diffuse_color = (*col, alpha)
    mat.use_nodes = True
    sh = mat.node_tree.nodes.get("Principled BSDF")
    sh.inputs["Base Color"].default_value = (*col, 1)
    sh.inputs["Metallic"].default_value = metal
    sh.inputs["Roughness"].default_value = rough
    sh.inputs["Alpha"].default_value = alpha
    if glow > 0:
        sh.inputs["Emission Color"].default_value = (*(srgb(glow_col) if glow_col else col), 1)
        sh.inputs["Emission Strength"].default_value = glow
    if vcol:
        # per-facet brightness variation baked into a colour attribute, multiplied into the base colour
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        vc = nodes.new("ShaderNodeVertexColor")
        vc.layer_name = "Col"
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs[6].default_value = (*col, 1)
        links.new(vc.outputs["Color"], mix.inputs[7])
        links.new(mix.outputs[2], sh.inputs["Base Color"])
    if alpha < 1.0:
        try:
            mat.surface_render_method = "BLENDED"
        except Exception:
            mat.blend_method = "BLEND"
    return mat


M = {
    "teal": material("Teal_Paint", "#3A9A88", 0.05, 0.42),
    "brass": material("Brass", "#F2A92E", 0.4, 0.3, vcol=True),
    "dark": material("Dark_Iron", "#4B4559", 0.2, 0.5),
    "coral": material("Coral_Knob", "#E9604A", 0.05, 0.4),
    "cream": material("Cream_Ceramic", "#F0E4C6", 0.0, 0.5),
    "glass": material("Crystal_Glass", "#50E8DC", 0.0, 0.04, alpha=0.26, vcol=True),
    "core": material("Crystal_Core", "#22CCC2", 0.25, 0.18, vcol=True),
    "lens": material("Emitter_Lens", "#10131C", 0.0, 0.1, glow=0.4, glow_col="#2A8FA0"),
}


# --------------------------------------------------------------------------------------------- geometry helpers
def revolve(bm, profile, segs, mat4):
    """Revolve a closed (r, z) profile (counter-clockwise, outward normals) around Z, then transform by mat4."""
    rows = []
    for r, z in profile:
        if r < 1e-6:
            rows.append([bm.verts.new(mat4 @ Vector((0, 0, z)))])
        else:
            rows.append([bm.verts.new(mat4 @ Vector((r * math.cos(math.tau * k / segs),
                                                     r * math.sin(math.tau * k / segs), z)))
                         for k in range(segs)])
    n = len(profile)
    for i in range(n):
        a, b = rows[i], rows[(i + 1) % n]
        for k in range(segs):
            k2 = (k + 1) % segs
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                bm.faces.new((a[0], b[k2], b[k]))
            elif len(b) == 1:
                bm.faces.new((a[k], a[k2], b[0]))
            else:
                bm.faces.new((a[k], a[k2], b[k2], b[k]))


AX_Y = Matrix.Rotation(-math.pi / 2, 4, "X")   # Z axis -> +Y
AX_X = Matrix.Rotation(math.pi / 2, 4, "Y")    # Z axis -> +X
AX_NX = Matrix.Rotation(-math.pi / 2, 4, "Y")  # Z axis -> -X
I4 = Matrix.Identity(4)


def at(pos, rot=None):
    m = Matrix.Translation(pos)
    return m @ rot if rot is not None else m


def box(bm, center, size):
    mat = Matrix.Translation(center) @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
    bmesh.ops.create_cube(bm, size=1.0, matrix=mat)


def smooth_by_angle(obj):
    mesh = obj.data
    mesh.shade_smooth()
    ed = bmesh.new()
    ed.from_mesh(mesh)
    for e in ed.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > SHARP_ANGLE:
            e.smooth = False
    ed.to_mesh(mesh)
    ed.free()


def finish_mesh(name, bm, mat, parent, bevel=None, smooth=True, facets=None, seed=1):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    obj.parent = parent
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    if bevel:
        mod = obj.modifiers.new("Machined edges", "BEVEL")
        mod.width = bevel[0]
        mod.segments = bevel[1]
        mod.limit_method = "ANGLE"
        mod.angle_limit = SHARP_ANGLE
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if smooth:
        smooth_by_angle(obj)
    else:
        for p in obj.data.polygons:
            p.use_smooth = False
    if facets or mat.name in ("Crystal_Glass", "Crystal_Core", "Brass"):
        rnd = random.Random(seed)
        layer = obj.data.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        for p in obj.data.polygons:
            if facets and isinstance(facets[0], tuple):
                c = rnd.choice(facets)
            else:
                v = rnd.uniform(*facets) if facets else 1.0
                c = (v, v, v)
            for li in p.loop_indices:
                layer.data[li].color = (*c, 1.0)
    return obj


def empty(name, pos, parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = pos
    return obj


# --------------------------------------------------------------------------------------------- static base
base = empty("Base", (0, 0, 0))

bm = bmesh.new()
revolve(bm, [(0, 0), (0.74, 0), (0.74, 0.07), (0.68, 0.145), (0.46, 0.145), (0.46, 0.10), (0, 0.10)], 32, I4)
revolve(bm, [(0.16, 0.25), (0.16, AIM_Z - 0.02), (0.0, AIM_Z - 0.02), (0.0, 0.25)], 20, I4)
revolve(bm, [(0.18, 0.25), (0.23, 0.25), (0.23, 0.29), (0.18, 0.33)], 20, I4)
for k in range(3):
    a = math.radians(40 + k * 125)
    revolve(bm, [(0, 0.145), (0.025, 0.145), (0.025, 0.165), (0.0, 0.175)], 6,
            at((0.64 * math.cos(a), 0.64 * math.sin(a), 0.0)))
finish_mesh("Base_Dark", bm, M["dark"], base, bevel=(0.012, 1))

bm = bmesh.new()
revolve(bm, [(0.46, 0.10), (0.62, 0.10), (0.62, 0.195), (0.46, 0.195)], 32, I4)
revolve(bm, [(0, 0.10), (0.34, 0.10), (0.34, 0.19), (0.29, 0.19), (0.29, 0.29), (0.24, 0.30), (0, 0.30)], 28, I4)
revolve(bm, [(0.14, 0.49), (0.235, 0.49), (0.235, 0.575), (0.14, 0.575)], 28, I4)
finish_mesh("Base_Brass", bm, M["brass"], base, bevel=(0.014, 1), facets=(0.8, 1.0), seed=3)

# --------------------------------------------------------------------------------------------- rotating head
aim = empty("Aim", (0, 0, AIM_Z))   # vertical axis, identity rotation
Z0 = BODY_Z
UPX = 0.49   # yoke upright x

bm = bmesh.new()
revolve(bm, [(0, -0.05), (0.23, -0.05), (0.23, 0.10), (0, 0.10)], 24, I4)
box(bm, (0, 0.0, 0.06), (2 * UPX, 0.22, 0.11))
for sx in (-1, 1):
    box(bm, (sx * UPX, -0.02, 0.27), (0.075, 0.22, 0.46))
    revolve(bm, [(0, 0), (0.05, 0), (0.05, 0.07), (0, 0.07)], 10,
            at((sx * 0.28, -0.60, Z0 + 0.04), AX_X if sx > 0 else AX_NX))
finish_mesh("Aim_Yoke", bm, M["dark"], aim, bevel=(0.014, 1))

bm = bmesh.new()
revolve(bm, [(0, BODY_Y0), (BODY_R, BODY_Y0), (BODY_R, BODY_Y1), (0, BODY_Y1)], 24, at((0, 0, Z0), AX_Y))
box(bm, (0, -0.60, Z0), (0.56, 0.30, 0.66))
finish_mesh("Aim_Body", bm, M["teal"], aim, bevel=(0.02, 2))

bm = bmesh.new()
revolve(bm, [(0.32, -0.475), (BODY_R + 0.03, -0.475), (BODY_R + 0.03, -0.405), (0.32, -0.405)], 24, at((0, 0, Z0), AX_Y))
for sx in (-1, 1):
    revolve(bm, [(0, 0), (0.12, 0), (0.12, 0.05), (0.085, 0.075), (0.085, 0.11), (0, 0.11)], 16,
            at((sx * (UPX + 0.037), -0.02, Z0), AX_X if sx > 0 else AX_NX))
finish_mesh("Aim_Coral", bm, M["coral"], aim)

bm = bmesh.new()
revolve(bm, [(RING_RI, RING_Y0), (RING_RO, RING_Y0), (RING_RO, RING_Y1), (RING_RI + 0.04, RING_Y1),
             (RING_RI + 0.04, RING_Y1 - 0.04), (RING_RI, RING_Y1 - 0.04)], 36, at((0, 0, Z0), AX_Y))
finish_mesh("Aim_Bezel", bm, M["brass"], aim, bevel=(0.018, 2), facets=(0.75, 1.0), seed=9)

rng = random.Random(5)
cy = BODY_Y1


def gem(bm, centre, scale, jitter, subdiv):
    geo = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
    for v in geo["verts"]:
        k = 1.0 + rng.uniform(-jitter, jitter)
        v.co = Vector((v.co.x * scale[0] * k, v.co.y * scale[1] * k, v.co.z * scale[2] * k)) + Vector(centre)
    drop = [f for f in bm.faces if all(v.co.y < centre[1] - 1e-4 for v in f.verts)]
    bmesh.ops.delete(bm, geom=drop, context="FACES_ONLY")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.holes_fill(bm, edges=[e for e in bm.edges if e.is_boundary])


bm = bmesh.new()
gem(bm, (0, cy, Z0), (RING_RI - 0.005, 0.17, RING_RI - 0.005), 0.06, 2)
finish_mesh("Aim_Crystal", bm, M["glass"], aim, smooth=False, facets=(0.6, 1.0), seed=11)

bm = bmesh.new()
gem(bm, (0, cy + 0.005, Z0), (0.40, 0.17, 0.40), 0.10, 2)
finish_mesh("Aim_CrystalCore", bm, M["core"], aim, smooth=False, seed=21,
            facets=[(0.35, 0.85, 0.9), (0.5, 1.0, 0.95), (0.8, 1.0, 0.8), (1, 1, 1), (0.3, 0.65, 0.85), (0.55, 0.95, 0.7), (0.2, 0.7, 0.75), (0.9, 1.0, 1.0)])

bm = bmesh.new()
revolve(bm, [(0, 0.34), (0.15, 0.34), (0.15, 0.40), (0.10, 0.42), (0.10, 0.64), (0.125, 0.655), (0.125, 0.76), (0, 0.76)],
        20, at((0, 0, Z0), AX_Y))
finish_mesh("Aim_Nozzle", bm, M["dark"], aim, bevel=(0.01, 1))

bm = bmesh.new()
revolve(bm, [(0, 0.76), (0.085, 0.76), (0.085, 0.772), (0.05, 0.782), (0, 0.782)], 16, at((0, 0, Z0), AX_Y))
finish_mesh("Aim_NozzleLens", bm, M["lens"], aim)

bm = bmesh.new()
TOP = Z0 + 0.27


def tube_profile(h):
    return [(0.0, 0.0), (0.11, 0.0), (0.11, h), (0.10, h + 0.012), (0.065, h + 0.012), (0.055, h), (0.055, h - 0.10), (0.0, h - 0.10)]


for (x, y, h) in ((0.14, -0.53, 0.26), (-0.14, -0.68, 0.21)):
    revolve(bm, tube_profile(h), 14, at((x, y, TOP)))
for (x, y, h) in ((-0.14, -0.53, 0.17), (0.14, -0.68, 0.14)):
    revolve(bm, [(r, -z) for r, z in tube_profile(h)][::-1], 14, at((x, y, Z0 - 0.27)))
finish_mesh("Aim_Tubes", bm, M["cream"], aim)

muzzle = empty("Muzzle", (0, 0.79, Z0), aim)

# --------------------------------------------------------------------------------------------- export
tris = 0
for o in bpy.data.objects:
    if o.type == "MESH":
        n = sum(len(p.vertices) - 2 for p in o.data.polygons)
        tris += n
        print("TRIS", o.name, n)
print("TRIS total", tris)
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(
    filepath=str(OUT / "cp_laser.glb"),
    export_format="GLB",
    export_yup=True,
    export_animations=False,
    export_cameras=False,
    export_lights=False,
    export_apply=True,
)

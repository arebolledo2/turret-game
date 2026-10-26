"""Clockwork quake thumper - scripted Blender model.

Run: blender --background --python build_cp_quake.py   (writes cp_quake.glb next to this script)
Metres, +Z up, weapon faces +Y. Static base: cracked stone slab ring, coral legs, indigo hub.
Aim (rotating head, pivot on the vertical axis): chamfered teal cube with lens ports and a brass hammer.
Muzzle: bare empty at the hammer's front (red lens) tip.
"""
import math
import random
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

HERE = Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)

SHARP = math.radians(35)
UV_METRES = 1.1


# ----------------------------------------------------------------------------------------------- textures
def stone_texture(path, size=512):
    """Greyscale blotchy stone with dark cracks and pits, generated here (no external images)."""
    rng = np.random.default_rng(5)

    def blur(a, n):
        for _ in range(n):
            a = (a + np.roll(a, 1, 0) + np.roll(a, -1, 0) + np.roll(a, 1, 1) + np.roll(a, -1, 1)) / 5.0
        return a

    def smooth_noise(n):
        g = rng.random((n + 1, n + 1))
        g[-1], g[:, -1] = g[0], g[:, 0]
        xs = np.linspace(0, n, size, endpoint=False)
        i = xs.astype(int)
        f = xs - i
        f = f * f * (3 - 2 * f)
        a, b, c, d = g[i][:, i], g[i][:, i + 1], g[i + 1][:, i], g[i + 1][:, i + 1]
        return (a * (1 - f)[None, :] + b * f[None, :]) * (1 - f)[:, None] + (c * (1 - f)[None, :] + d * f[None, :]) * f[:, None]

    blotch = 0.55 * smooth_noise(4) + 0.3 * smooth_noise(8) + 0.15 * smooth_noise(24)
    img = 0.74 + 0.30 * (blotch - 0.5) + 0.05 * (blur(rng.random((size, size)), 1) - 0.5)

    def crack(x, y, ang, steps, depth=0):
        for _ in range(steps):
            ang += rng.normal(0, 0.35)
            x += math.cos(ang) * 2.2
            y += math.sin(ang) * 2.2
            xi, yi = int(x) % size, int(y) % size
            img[yi, xi] *= 0.22
            img[(yi + 1) % size, xi] *= 0.5
            img[yi, (xi + 1) % size] *= 0.5
            if depth < 2 and rng.random() < 0.025:
                crack(x, y, ang + rng.choice([-1, 1]) * rng.uniform(0.5, 1.1), int(steps * 0.4), depth + 1)

    for _ in range(11):
        crack(rng.uniform(0, size), rng.uniform(0, size), rng.uniform(0, math.tau), int(rng.integers(50, 130)))
    for _ in range(140):  # pits
        xi, yi = int(rng.integers(0, size)), int(rng.integers(0, size))
        img[yi, xi] *= 0.55
        img[(yi + 1) % size, xi] *= 0.8
    img = np.clip(img, 0.0, 1.0)
    pixels = np.stack([img, img, img, np.ones_like(img)], axis=-1).astype(np.float32)
    image = bpy.data.images.new("stone_gen", size, size, alpha=False)
    image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    bpy.data.images.remove(image)


def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexc(h):
    h = h.lstrip("#")
    return tuple(lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4))


STONE_PNG = HERE / "stone_gen.png"
stone_texture(STONE_PNG)


def material(name, hexcol, metal=0.0, rough=0.4, emit=0.0, alpha=1.0, texture=None, coat=0.0):
    mat = bpy.data.materials.new(name)
    col = hexc(hexcol)
    mat.diffuse_color = (*col, 1)
    mat.use_nodes = True
    sh = mat.node_tree.nodes.get("Principled BSDF")
    sh.inputs["Base Color"].default_value = (*col, 1)
    sh.inputs["Metallic"].default_value = metal
    sh.inputs["Roughness"].default_value = rough
    if coat:
        sh.inputs["Coat Weight"].default_value = coat
        sh.inputs["Coat Roughness"].default_value = 0.15
    if emit:
        sh.inputs["Emission Color"].default_value = (*col, 1)
        sh.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        sh.inputs["Alpha"].default_value = alpha
        mat.surface_render_method = "BLENDED"
    if texture:
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(texture))
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs[6].default_value = (*col, 1)
        links.new(tex.outputs["Color"], mix.inputs[7])
        links.new(mix.outputs[2], sh.inputs["Base Color"])
    return mat


M = {
    "teal": material("Glazed teal", "#1E9686", 0.0, 0.3, coat=0.6),
    "brass": material("Brass", "#EDB02A", 0.8, 0.26),
    "coral": material("Coral enamel", "#EA5F4C", 0.0, 0.38, coat=0.3),
    "cream": material("Cream ivory", "#F3E4B4", 0.0, 0.45),
    "stone": material("Cracked stone", "#7E7E8C", 0.0, 0.85, texture=STONE_PNG),
    "indigo": material("Indigo", "#40307A", 0.2, 0.4),
    "glass": material("Violet glass", "#A15BF2", 0.0, 0.05, alpha=0.62),
    "core": material("Violet core", "#8A3BE8", 0.0, 0.2, emit=0.7),
    "red": material("Red gem", "#C8182A", 0.0, 0.12, emit=0.5),
    "steel": material("Steel", "#9AA0AE", 0.8, 0.3),
}


# ----------------------------------------------------------------------------------------------- helpers
def activate(obj):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def bevel(obj, width, segments=2):
    activate(obj)
    mod = obj.modifiers.new("Bevel", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    mod.angle_limit = SHARP
    bpy.ops.object.modifier_apply(modifier=mod.name)


def smooth_by_angle(obj):
    mesh = obj.data
    mesh.shade_smooth()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > SHARP:
            e.smooth = False
    bm.to_mesh(mesh)
    bm.free()


UV_RNG = random.Random(99)


def project_uvs(obj):
    mesh = obj.data
    layer = mesh.uv_layers.active or mesh.uv_layers.new(name="UVMap")
    ox, oy = UV_RNG.random(), UV_RNG.random()
    for poly in mesh.polygons:
        n = poly.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            u, v = ((co.y, co.z), (co.x, co.z), (co.x, co.y))[axis]
            layer.data[li].uv = (u / UV_METRES + ox, v / UV_METRES + oy)


def align_euler(direction):
    d = Vector(direction).normalized()
    if abs(d.z) > 0.9999:
        return Euler((0, 0 if d.z > 0 else math.pi, 0))
    return d.to_track_quat("Z", "Y").to_euler()


GROUPS = {}
MIRROR = False  # Aim parts are authored in a mirrored frame; this flips them into the final layout
REFLECT = Matrix(((0, -1, 0, 0), (-1, 0, 0, 0), (0, 0, 1, 0), (0, 0, 0, 1)))


def finish(obj, group, mat, rot=None, smooth=True):
    if rot is not None:
        obj.rotation_euler = rot
    obj.data.materials.append(mat)
    if smooth:
        smooth_by_angle(obj)
    activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if MIRROR:
        obj.data.transform(REFLECT)
        obj.data.flip_normals()
        obj.data.update()
    project_uvs(obj)
    GROUPS.setdefault(group, []).append(obj)
    return obj


def box(group, mat, pos, size, bw=0.02, seg=2, rot=(0, 0, 0), extra=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.scale = size
    activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for w, s in ([(bw, seg)] + (extra or [])):
        bevel(obj, min(w, 0.45 * min(size)), s)
    return finish(obj, group, mat, Euler(rot))


def cyl(group, mat, pos, r, length, axis=(0, 0, 1), r2=None, verts=16, bw=None, seg=2):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r2 is None else r2, depth=length,
                                    end_fill_type="NGON", location=pos)
    obj = bpy.context.object
    w = min(r, length / 2) * 0.28 if bw is None else bw
    if seg == 2 and (r < 0.1 or length < 0.1):
        seg = 1
    bevel(obj, min(w, 0.45 * length, 0.45 * min(r, r2 if r2 else r)), seg)
    return finish(obj, group, mat, align_euler(axis))


def sphere(group, mat, pos, r, axis=(0, 0, 1), scale=(1, 1, 1), segs=16, rings=8):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=r, location=pos)
    obj = bpy.context.object
    obj.scale = scale
    activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.shade_smooth()
    return finish(obj, group, mat, align_euler(axis), smooth=False)


def torus(group, mat, pos, major, minor, axis=(0, 0, 1), squash=1.0, maj=24, mnr=6):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=maj,
                                     minor_segments=mnr, location=pos)
    obj = bpy.context.object
    obj.scale = (1, 1, squash)
    activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.shade_smooth()
    return finish(obj, group, mat, align_euler(axis), smooth=False)


def hull(group, mat, points, bw=0.02, seg=2):
    bm = bmesh.new()
    verts = [bm.verts.new(p) for p in points]
    res = bmesh.ops.convex_hull(bm, input=verts)
    dead = [v for v in set(res["geom_interior"] + res["geom_unused"]) if isinstance(v, bmesh.types.BMVert)]
    bmesh.ops.delete(bm, geom=dead, context="VERTS")
    bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(1.0), verts=bm.verts, edges=bm.edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("hull")
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("hull", mesh)
    bpy.context.collection.objects.link(obj)
    bevel(obj, bw, seg)
    return finish(obj, group, mat)


def rivet(group, mat, pos, normal, r=0.02):
    return sphere(group, mat, pos, r, axis=normal, scale=(1, 1, 0.55), segs=6, rings=3)


def basis(normal):
    n = Vector(normal).normalized()
    up = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
    t = n.cross(up).normalized()
    return t, n.cross(t)


def ring_points(center, normal, radius, count, phase=0.0):
    t, b = basis(normal)
    c = Vector(center)
    return [c + (t * math.cos(phase + math.tau * i / count) + b * math.sin(phase + math.tau * i / count)) * radius
            for i in range(count)]


def lens_port(center, normal, R, orb, orb_mat="glass", inner_mat="coral", group_trim="Aim_Trim",
              group_lens="Aim_Lenses", rivets=4):
    c, n = Vector(center), Vector(normal).normalized()
    torus(group_trim, M["brass"], c + n * 0.008, R, R * 0.27, n, squash=0.75)
    torus(group_trim, M[inner_mat], c + n * 0.004, R * 0.7, R * 0.15, n, squash=0.9)
    cyl(group_lens, M["indigo"], c + n * 0.006, R * 0.74, 0.02, n, verts=24, bw=0.004, seg=1)
    if orb_mat == "glass":
        sphere(group_lens, M["core"], c + n * orb * 0.25, orb * 0.8, n)
        sphere(group_lens, M["glass"], c + n * orb * 0.25, orb, n)
    else:
        sphere(group_lens, M["red"], c + n * orb * 0.25, orb, n)
    for p in ring_points(c + n * 0.006, n, R * 1.35, rivets, math.pi / 4):
        rivet(group_trim, M["brass"], p, n, 0.02)


def merge(group, name, parent=None):
    objs = GROUPS[group]
    target = objs[0]
    with bpy.context.temp_override(active_object=target, object=target, selected_editable_objects=objs,
                                   selected_objects=objs):
        bpy.ops.object.join()
    target.name = name
    target.data.name = name
    if parent is not None:
        target.parent = parent
        target.matrix_parent_inverse = parent.matrix_world.inverted()
    return target


def empty(name, pos, parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.location = pos
    if parent is not None:
        obj.parent = parent
    return obj


# ----------------------------------------------------------------------------------------------- static base
H = 0.35            # cube half edge
AIM_Z = 0.52        # cube bottom / Aim pivot height
CZ = AIM_Z + H      # cube centre height
rng = random.Random(21)

# inner paving: irregular wedge tiles
cuts = sorted(rng.uniform(0, math.tau) for _ in range(7))
FLOOR_R, FLOOR_H = 0.63, 0.09
for i, a0 in enumerate(cuts):
    a1 = cuts[(i + 1) % len(cuts)] + (math.tau if i == len(cuts) - 1 else 0)
    am = (a0 + a1) / 2
    pts2 = [(0.0, 0.0)] + [(FLOOR_R * math.cos(a), FLOOR_R * math.sin(a)) for a in (a0, (a0 + am) / 2, am, (am + a1) / 2, a1)]
    cx = sum(p[0] for p in pts2) / len(pts2)
    cy = sum(p[1] for p in pts2) / len(pts2)
    pts2 = [(cx + (x - cx) * 0.95, cy + (y - cy) * 0.95) for x, y in pts2]
    h = FLOOR_H + rng.uniform(-0.01, 0.01)
    hull("Base_Stone", M["stone"], [(x, y, z) for x, y in pts2 for z in (0.0, h)], bw=0.018, seg=2)

# outer ring of chunky slabs
N_RING = 10
base_ang = [(i + rng.uniform(-0.15, 0.15)) * math.tau / N_RING for i in range(N_RING)]
for i, a in enumerate(base_ang):
    rad = 0.74 + rng.uniform(-0.015, 0.015)
    tang = math.tau * rad / N_RING * rng.uniform(0.86, 0.95)
    depth = rng.uniform(0.25, 0.29)
    h = rng.uniform(0.13, 0.2)
    box("Base_Stone", M["stone"], (rad * math.cos(a), rad * math.sin(a), h / 2 + 0.003), (depth, tang, h),
        bw=0.06, seg=2, rot=(rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), a + rng.uniform(-0.07, 0.07)))

# loose chunks just outside the ring
for a, s in ((math.radians(235), 0.085), (math.radians(20), 0.075), (math.radians(300), 0.07)):
    cxr, cyr = 0.94 * math.cos(a), 0.94 * math.sin(a)
    pts = []
    for _ in range(9):
        pts.append((cxr + rng.uniform(-s, s) * 1.2, cyr + rng.uniform(-s, s) * 1.2, rng.choice([0.0, rng.uniform(0.09, 0.15)])))
    pts += [(cxr + s, cyr, 0.0), (cxr - s, cyr, 0.0), (cxr, cyr + s, 0.0), (cxr, cyr - s, 0.0)]
    hull("Base_Stone", M["stone"], pts, bw=0.018, seg=1)

# hub, swivel ring, side fittings
HZ = AIM_Z - 0.075
HR_HUB = 0.29
cyl("Base_Hub", M["indigo"], (0, 0, HZ), HR_HUB, 0.17, verts=14, bw=0.025)
torus("Base_Hub", M["brass"], (0, 0, AIM_Z - 0.005), HR_HUB - 0.02, 0.028, squash=0.8, maj=32)
for ang, kind in ((190, "plate"), (70, "port"), (310, "plate")):
    a = math.radians(ang)
    d = Vector((math.cos(a), math.sin(a), 0))
    rot = (0, 0, a)
    zc = Vector((0, 0, HZ))
    r0 = HR_HUB + 0.01
    if kind == "plate":
        box("Base_Hub", M["brass"], d * r0 + zc, (0.07, 0.25, 0.18), bw=0.022, rot=rot)
        cyl("Base_Hub", M["steel"], d * (r0 + 0.045) + zc, 0.04, 0.05, d, verts=14, bw=0.012)
        t = Vector((-d.y, d.x, 0))
        for off in (-0.09, 0.09):
            for dz in (0.065, -0.065):
                rivet("Base_Hub", M["brass"], d * (r0 + 0.035) + t * off + zc + Vector((0, 0, dz)), d, 0.015)
    else:
        box("Base_Hub", M["indigo"], d * r0 + zc, (0.08, 0.2, 0.18), bw=0.025, rot=rot)
        torus("Base_Hub", M["brass"], d * (r0 + 0.045) + zc, 0.048, 0.017, d, squash=0.9, maj=20)
        torus("Base_Hub", M["coral"], d * (r0 + 0.048) + zc, 0.028, 0.011, d, maj=16)
        sphere("Base_Hub", M["indigo"], d * (r0 + 0.05) + zc, 0.025, d, scale=(1, 1, 0.8), segs=10, rings=5)

# three coral legs with brass collars and domes
for ang in (130, 250, 10):
    a = math.radians(ang)
    d = Vector((math.cos(a), math.sin(a), 0))
    p0 = d * 0.47 + Vector((0, 0, 0.12))
    p1 = d * 0.34 + Vector((0, 0, AIM_Z - 0.06))
    axis = p1 - p0
    cyl("Base_Legs", M["coral"], (p0 + p1) / 2, 0.135, axis.length, axis, r2=0.095, verts=18, bw=0.02)
    cyl("Base_Legs", M["brass"], d * 0.47 + Vector((0, 0, 0.125)), 0.18, 0.07, verts=20, bw=0.025)
    cyl("Base_Legs", M["brass"], d * 0.47 + Vector((0, 0, 0.18)), 0.15, 0.045, verts=20, bw=0.015)
    sphere("Base_Legs", M["brass"], p1, 0.105, axis, scale=(1, 1, 0.9), segs=18, rings=9)

for n in ("Base_Stone", "Base_Hub", "Base_Legs"):
    merge(n, n)

# ----------------------------------------------------------------------------------------------- aim: cube body
MIRROR = True
box("Aim_Body", M["teal"], (0, 0, CZ), (2 * H, 2 * H, 2 * H), bw=0.135, seg=1, extra=[(0.02, 2)])

# front-in-authoring-frame (+Y) violet lens port, back (-Y) red lens port, top violet orb in coral ring
lens_port((0.03, H, CZ - 0.01), (0, 1, 0), 0.135, 0.083)
lens_port((-0.02, -H, CZ), (0, -1, 0), 0.11, 0.068, orb_mat="red", inner_mat="coral")
c_top = Vector((0.06, 0.0, CZ + H - 0.01))
torus("Aim_Trim", M["coral"], c_top + Vector((0, 0, 0.01)), 0.16, 0.043, squash=0.9, maj=32, mnr=10)
torus("Aim_Trim", M["brass"], c_top, 0.193, 0.015, maj=32)
cyl("Aim_Lenses", M["indigo"], c_top + Vector((0, 0, 0.004)), 0.155, 0.02, verts=24, bw=0.004, seg=1)
sphere("Aim_Lenses", M["core"], c_top + Vector((0, 0, 0.035)), 0.1, segs=20, rings=10)
sphere("Aim_Lenses", M["glass"], c_top + Vector((0, 0, 0.035)), 0.122, segs=20, rings=10)

# +X (authoring frame) side: coral disc port with brass rim and indigo dome
SX = (H + 0.04, 0.0, CZ - 0.005)
cyl("Aim_Trim", M["coral"], SX, 0.18, 0.09, (1, 0, 0), verts=24, bw=0.028)
torus("Aim_Trim", M["brass"], (H + 0.088, 0.0, CZ - 0.005), 0.18, 0.029, (1, 0, 0), squash=0.8, maj=32)
sphere("Aim_Lenses", M["indigo"], (H + 0.08, 0.0, CZ - 0.005), 0.12, (1, 0, 0), scale=(1, 1, 0.45), segs=18, rings=9)
torus("Aim_Trim", M["brass"], (H + 0.09, 0.0, CZ - 0.005), 0.105, 0.014, (1, 0, 0), maj=24)
for p in ring_points((H + 0.09, 0.0, CZ - 0.005), (1, 0, 0), 0.14, 6, 0.3):
    rivet("Aim_Trim", M["brass"], p, (1, 0, 0), 0.014)

# brass boom cylinder poking out of the back-right top corner
boom = Vector((0.62, -0.35, 0.70)).normalized()
bp = Vector((0.22, -0.16, CZ + 0.22))
cyl("Aim_Trim", M["brass"], bp + boom * 0.12, 0.065, 0.27, boom, verts=18, bw=0.02)
cyl("Aim_Trim", M["brass"], bp + boom * 0.245, 0.08, 0.045, boom, verts=18, bw=0.013)
cyl("Aim_Trim", M["brass"], bp + boom * 0.04, 0.082, 0.045, boom, verts=18, bw=0.013)

# brass bracket on the -X (authoring frame) face (hammer mount)
BZ = 0.80
box("Aim_Trim", M["brass"], (-H - 0.012, 0.04, BZ), (0.05, 0.32, 0.42), bw=0.03, seg=2)
for y in (-0.09, 0.17):
    for z in (BZ - 0.15, BZ + 0.15):
        rivet("Aim_Trim", M["brass"], (-H - 0.04, y, z), (-1, 0, 0), 0.019)

# misc rivets on the teal faces
for x, z in ((0.19, CZ - 0.17), (-0.17, CZ - 0.17), (0.19, CZ + 0.17), (-0.17, CZ + 0.17)):
    rivet("Aim_Trim", M["brass"], (x, H, z), (0, 1, 0), 0.016)
for x, z in ((0.17, CZ - 0.17), (-0.17, CZ - 0.17), (0.17, CZ + 0.17), (-0.19, CZ + 0.17)):
    rivet("Aim_Trim", M["brass"], (x, -H, z), (0, -1, 0), 0.016)
for y, z in ((0.19, CZ - 0.17), (-0.19, CZ - 0.17), (0.19, CZ + 0.17), (-0.19, CZ + 0.17)):
    rivet("Aim_Trim", M["steel"], (H, y, z), (1, 0, 0), 0.015)

# ----------------------------------------------------------------------------------------------- hammer
B = Vector((-0.58, 0.04, 0.70))
T = Vector((-0.30, 0.04, 1.47))
handle = T - B
hd = handle.normalized()
cyl("Hammer_Metal", M["brass"], (B + T) / 2, 0.06, handle.length, hd, verts=16, bw=0.014)
for f, r, ln in ((0.17, 0.088, 0.1), (0.90, 0.095, 0.13)):
    cyl("Hammer_Metal", M["brass"], B + handle * f, r, ln, hd, verts=18, bw=0.02)
for f in (0.11, 0.24):
    torus("Hammer_Metal", M["brass"], B + handle * f, 0.068, 0.015, hd, maj=20)
# pivot arm from the bracket to the handle foot
cyl("Hammer_Metal", M["brass"], (-0.48, 0.04, B.z), 0.06, 0.2, (1, 0, 0), verts=16, bw=0.012)
cyl("Hammer_Metal", M["brass"], (-0.58, 0.04, B.z), 0.08, 0.03, (1, 0, 0), verts=18, bw=0.008)
sphere("Hammer_Metal", M["steel"], (-0.595, 0.04, B.z), 0.038, (-1, 0, 0), scale=(1, 1, 0.7), segs=12, rings=6)

# head (authoring axis +Y); red lens at the front end, cream cap at the other end
HY = (0, 1, 0)
HR = 0.17
cyl("Hammer_Metal", M["brass"], T, HR, 0.32, HY, verts=24, bw=0.03)
cyl("Hammer_Metal", M["brass"], T + Vector((0, -0.18, 0)), HR + 0.012, 0.05, HY, verts=24, bw=0.015)
cyl("Hammer_Metal", M["brass"], T + Vector((0, 0.18, 0)), HR + 0.012, 0.05, HY, verts=24, bw=0.015)
cyl("Hammer_Metal", M["brass"], T + Vector((0, 0.30, 0)), HR + 0.005, 0.2, HY, verts=24, bw=0.035)
torus("Hammer_Metal", M["brass"], T + Vector((0, 0.397, 0)), 0.102, 0.028, HY, squash=0.8, maj=24)
cyl("Hammer_Metal", M["brass"], T + Vector((0, -0.225, 0)), HR - 0.015, 0.04, HY, verts=24, bw=0.012)
cyl("Hammer_Metal", M["indigo"], T + Vector((0, 0.395, 0)), 0.098, 0.02, HY, verts=20, bw=0.004, seg=1)
sphere("Hammer_Lens", M["red"], T + Vector((0, 0.405, 0)), 0.076, HY, scale=(1, 1, 0.85), segs=18, rings=9)
sphere("Hammer_Metal", M["steel"], T + Vector((0, 0.0, HR - 0.01)), 0.044, (0, 0, 1), scale=(1, 1, 0.7), segs=14, rings=7)
for yy, ph, rr in ((0.18, 0.2, HR + 0.012), (0.27, 0.5, HR + 0.005)):
    c0 = T + Vector((0, yy, 0))
    for p in ring_points(c0, HY, rr, 6, ph):
        rivet("Hammer_Metal", M["brass"], p, p - c0, 0.014)

# cream striking cap and cream stop block at the handle base
cyl("Hammer_Cream", M["cream"], T + Vector((0, -0.30, 0)), HR - 0.01, 0.16, HY, verts=8, bw=0.045, seg=3)
box("Hammer_Cream", M["cream"], (-0.55, 0.21, 0.62), (0.21, 0.31, 0.22), bw=0.065, seg=3, rot=(0.0, 0.1, 0.13))

# ----------------------------------------------------------------------------------------------- assemble
aim = empty("Aim", (0, 0, AIM_Z))
bpy.context.view_layer.update()
for g in ("Aim_Body", "Aim_Trim", "Aim_Lenses", "Hammer_Metal", "Hammer_Cream", "Hammer_Lens"):
    merge(g, g, aim)

muzzle = empty("Muzzle", REFLECT @ (T + Vector((0, 0.46, 0))) - aim.location, aim)
for o in bpy.context.scene.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        print("OBJTRIS", o.name, len(o.data.loop_triangles))

out = HERE / "cp_quake.glb"
bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", export_yup=True, export_animations=False,
                          export_cameras=False, export_lights=False)
print("EXPORTED", out)

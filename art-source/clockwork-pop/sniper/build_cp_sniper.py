"""Clockwork sniper rifle on a brass-ringed tripod -> cp_sniper.glb

Run: blender --background --python build_cp_sniper.py
Metres, Blender +Z up, weapon faces +Y. Static tripod (Base_*), rotating head (Aim) carrying rifle, scope and receiver.
All parts are built from bmesh lathes / bevelled boxes and merged per (group, material).
"""
import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

OUT = Path(__file__).parent
SHARP = math.radians(35)
AIM_Z = 0.70          # height of the swivel (top of the brass collar)
BARREL_Z = 0.92       # barrel axis height (world)
SCOPE_Z = 1.18        # scope axis height (world)
SHIFT = 0.11          # rifle is slid back relative to the swivel so the whole model stays centred


# ----------------------------------------------------------------------------------------------------- materials
def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h):
    return tuple(lin(int(h[i:i + 2], 16) / 255) for i in (1, 3, 5))


def material(name, hexc, metal=0.0, rough=0.42, alpha=1.0, spec=0.5):
    mat = bpy.data.materials.new(name)
    col = hexcol(hexc)
    mat.diffuse_color = (*col, alpha)
    mat.use_nodes = True
    sh = mat.node_tree.nodes.get("Principled BSDF")
    sh.inputs["Base Color"].default_value = (*col, 1)
    sh.inputs["Metallic"].default_value = metal
    sh.inputs["Roughness"].default_value = rough
    if alpha < 1.0:
        sh.inputs["Alpha"].default_value = alpha
        try:
            mat.surface_render_method = "BLENDED"
        except Exception:
            pass
    return mat


# ----------------------------------------------------------------------------------------------------- accumulators
ACC = {}  # (group, material name) -> bmesh


def acc(group, mat):
    key = (group, mat.name)
    if key not in ACC:
        ACC[key] = (bmesh.new(), mat)
    return ACC[key][0]


def merge(group, mat, tmp, matrix):
    dst = acc(group, mat)
    vmap = {v: dst.verts.new(matrix @ v.co) for v in tmp.verts}
    for f in tmp.faces:
        try:
            dst.faces.new([vmap[v] for v in f.verts])
        except ValueError:
            pass
    tmp.free()


# ----------------------------------------------------------------------------------------------------- primitives
def lathe_bm(profile, segs=24):
    """Revolve a closed (r, h) profile around local Z. Points with r == 0 become single vertices."""
    bm = bmesh.new()
    rings = []
    for r, h in profile:
        if r < 1e-6:
            rings.append([bm.verts.new((0, 0, h))])
        else:
            rings.append([bm.verts.new((r * math.cos(math.tau * j / segs), r * math.sin(math.tau * j / segs), h))
                          for j in range(segs)])
    n = len(profile)
    for i in range(n):
        a, b = rings[i], rings[(i + 1) % n]
        if len(a) == 1 and len(b) == 1:
            continue
        for j in range(segs):
            j2 = (j + 1) % segs
            if len(a) == 1:
                vs = [a[0], b[j], b[j2]]
            elif len(b) == 1:
                vs = [a[j], b[0], a[j2]]
            else:
                vs = [a[j], b[j], b[j2], a[j2]]
            try:
                bm.faces.new(vs)
            except ValueError:
                pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def prof_cyl(r, h, c=0.004):
    c = min(c, r * 0.4, h * 0.4)
    return [(0, 0), (r - c, 0), (r, c), (r, h - c), (r - c, h), (0, h)]


def prof_ring(ro, ri, h, c=0.004):
    c = min(c, (ro - ri) * 0.4, h * 0.4)
    return [(ri, 0), (ro - c, 0), (ro, c), (ro, h - c), (ro - c, h), (ri, h)]


def prof_dome(r, depth, steps=6):
    pts = [(0, 0), (r, 0)]
    for i in range(1, steps):
        t = math.pi / 2 * i / steps
        pts.append((r * math.cos(t), depth * math.sin(t)))
    pts.append((0, depth))
    return pts


def at(origin, axis="Z", sign=1):
    """Matrix placing a lathe (local +Z) at origin pointing along +/-axis."""
    o = Matrix.Translation(Vector(origin))
    if axis == "Z":
        return o @ (Matrix.Rotation(math.pi, 4, "X") if sign < 0 else Matrix.Identity(4))
    if axis == "Y":
        return o @ Matrix.Rotation(-math.pi / 2 * sign, 4, "X")
    return o @ Matrix.Rotation(math.pi / 2 * sign, 4, "Y")


def lathe(group, mat, profile, matrix, segs=24):
    merge(group, mat, lathe_bm(profile, segs), matrix)


def box(group, mat, center, size, bevel=0.01, rot=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    w = min(bevel, min(size) * 0.3)
    if w > 1e-4:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=w, segments=1, profile=0.5, affect="EDGES")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    m = Matrix.Translation(Vector(center))
    if rot is not None:
        m = m @ rot
    merge(group, mat, bm, m)


def orient(direction, up=(0, 0, 1)):
    """Rotation matrix whose local Z points along direction."""
    d = Vector(direction).normalized()
    return d.to_track_quat("Z", "Y").to_matrix().to_4x4()


def extrude_profile(group, mat, pts, x0, x1, bevel=0.008):
    """Extrude a (y, z) outline sideways in X from x0 to x1."""
    bm = bmesh.new()
    verts = [bm.verts.new((x0, y, z)) for y, z in pts]
    face = bm.faces.new(verts)
    res = bmesh.ops.extrude_face_region(bm, geom=[face])
    ext = [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, vec=(x1 - x0, 0, 0), verts=ext)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if bevel > 1e-4:
        try:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, profile=0.5, affect="EDGES")
        except Exception:
            pass
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    merge(group, mat, bm, Matrix.Identity(4))


def tube(group, mat, a, b, r0, r1, segs=10):
    a, b = Vector(a), Vector(b)
    L = (b - a).length
    prof = [(0, 0), (r0 * 0.85, 0), (r0, 0.004), (r1, L - 0.004), (r1 * 0.85, L), (0, L)]
    lathe(group, mat, prof, Matrix.Translation(a) @ orient(b - a), segs)


# ----------------------------------------------------------------------------------------------------- build
def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    teal = material("Teal enamel", "#1f7d86", 0.15, 0.38)
    coral = material("Coral enamel", "#f2564b", 0.05, 0.42)
    brass = material("Brass", "#f2b52c", 0.6, 0.3)
    slate = material("Slate legs", "#34505f", 0.2, 0.45)
    graphite = material("Graphite", "#26283a", 0.3, 0.5)
    grey = material("Scope tube", "#59635f", 0.35, 0.4)
    mint = material("Mint button", "#22d1b4", 0.1, 0.3)
    violet = material("Violet button", "#8d52e0", 0.1, 0.3)
    maroon = material("Maroon ring", "#6b3144", 0.2, 0.5)
    glass_b = material("Lens blue", "#2b45c8", 0.0, 0.05, alpha=0.7)
    glass_r = material("Lens red", "#e0203f", 0.0, 0.05, alpha=0.8)

    B, A = "Base", "Aim"

    # ---------------- tripod (static) ----------------
    lathe(B, graphite, prof_cyl(0.04, 0.035, 0.008), at((0, 0, 0.27)), 14)           # column foot cap
    lathe(B, slate, prof_cyl(0.045, 0.31, 0.006), at((0, 0, 0.30)), 14)               # centre column
    lathe(B, maroon, prof_ring(0.072, 0.04, 0.045, 0.008), at((0, 0, 0.37)), 16)      # maroon lock ring
    lathe(B, graphite, prof_cyl(0.125, 0.07, 0.012), at((0, 0, 0.58)), 20)            # hub
    lathe(B, brass, prof_cyl(0.155, 0.065, 0.014), at((0, 0, 0.635)), 28)  # swivel collar
    lathe(B, graphite, prof_ring(0.158, 0.135, 0.012, 0.003), at((0, 0, 0.665)), 28)  # dark band in the collar
    for k in range(3):
        th = math.radians(90 + 120 * k)
        radial = Vector((math.cos(th), math.sin(th), 0))
        hinge = Vector((radial.x * 0.10, radial.y * 0.10, 0.57))
        foot = Vector((radial.x * 0.46, radial.y * 0.46, 0.035))
        d = (foot - hinge).normalized()
        # leg + foot + brass ring
        tube(B, slate, hinge, foot - d * 0.06, 0.05, 0.036, 10)
        lathe(B, graphite, prof_cyl(0.042, 0.075, 0.008), Matrix.Translation(foot - d * 0.07) @ orient(d), 12)
        lathe(B, brass, prof_ring(0.06, 0.034, 0.04, 0.006), Matrix.Translation(foot - d * 0.12) @ orient(d), 16)
        # hinge bracket (angular dark block, brass rivet)
        centre = hinge + d * 0.05 + Vector((0, 0, 0.03))
        box(B, graphite, centre, (0.12, 0.10, 0.19), 0.02, orient(d))
        rivet_pos = centre + radial * 0.06 + Vector((0, 0, 0.02))
        lathe(B, brass, prof_dome(0.016, 0.012, 3), Matrix.Translation(rivet_pos) @ orient(radial), 10)
        # hub-side gusset linking bracket to hub
        box(B, graphite, (radial.x * 0.085, radial.y * 0.085, 0.62), (0.07, 0.07, 0.07), 0.012, orient(radial))

    # ---------------- aim: pedestal + knob ----------------
    S = SHIFT
    box(A, teal, (0, 0.0 + S, 0.725), (0.15, 0.17, 0.05), 0.012)
    box(A, teal, (0, 0.02 + S, 0.775), (0.22, 0.30, 0.07), 0.016)
    lathe(A, brass, prof_cyl(0.035, 0.055, 0.006), at((-0.10, 0.03 + S, 0.745), "X", -1), 16)
    lathe(A, graphite, prof_cyl(0.024, 0.02, 0.004), at((-0.155, 0.03 + S, 0.745), "X", -1), 14)

    # ---------------- coral forearm / receiver / stock ----------------
    body = [(0.53, 0.77), (0.565, 0.83), (0.34, 0.93), (0.0, 0.93), (-0.02, 1.0), (-0.24, 1.0), (-0.18, 0.77)]
    extrude_profile(A, coral, body, -0.068, 0.068, 0.008)
    stock = [(-0.20, 1.0), (-0.25, 1.04), (-0.50, 1.04), (-0.52, 0.80), (-0.45, 0.72), (-0.32, 0.70), (-0.24, 0.78),
             (-0.19, 0.80)]
    extrude_profile(A, coral, stock, -0.072, 0.072, 0.009)
    box(A, graphite, (0, -0.54, 0.92), (0.15, 0.05, 0.25), 0.012)                    # butt pad
    # forearm underside skid and mint rail
    box(A, mint, (-0.070, 0.26, 0.905), (0.012, 0.44, 0.022), 0.004)
    box(A, mint, (0.070, 0.26, 0.905), (0.012, 0.44, 0.022), 0.004)
    # brass screws
    for y, z in ((0.43, 0.82), (0.14, 0.82), (-0.31, 1.005)):
        for sx in (-1, 1):
            lathe(A, brass, prof_dome(0.014, 0.012, 3), at((sx * (0.068 if z < 1 else 0.072), y, z), "X", sx), 10)
    # trigger guard
    for sx in (-0.022, 0.022):
        R, m = 0.06, 0.011
        prof = [(R + m * math.cos(t), m * math.sin(t)) for t in [math.tau * i / 8 for i in range(8)]]
        lathe(A, graphite, prof, at((sx, -0.125, 0.76), "X", 1), 20)
    box(A, graphite, (0, -0.135, 0.785), (0.014, 0.016, 0.05), 0.003, Matrix.Rotation(0.3, 4, "X"))

    # buttons and stock inlays, both sides
    for sx in (-1, 1):
        lathe(A, mint, prof_cyl(0.042, 0.022, 0.006), at((sx * 0.062, -0.11, 0.905), "X", sx), 20)
        lathe(A, violet, prof_cyl(0.028, 0.02, 0.005), at((sx * 0.062, -0.19, 0.96), "X", sx), 16)
        box(A, mint, (sx * 0.074, -0.40, 0.92), (0.014, 0.05, 0.14), 0.005)
        lathe(A, violet, prof_dome(0.013, 0.01, 3), at((sx * 0.072, -0.31, 0.82), "X", sx), 10)

    # ---------------- teal upper receiver + barrel ----------------
    box(A, teal, (0, 0.14, 0.97), (0.14, 0.30, 0.09), 0.014)
    lathe(A, teal, prof_cyl(0.098, 0.30, 0.006), at((0, 0.0, BARREL_Z), "Y"), 28)         # rear barrel shroud
    lathe(A, teal, prof_cyl(0.088, 0.60, 0.004), at((0, 0.30, BARREL_Z), "Y"), 28)        # barrel
    lathe(A, graphite, prof_ring(0.103, 0.08, 0.012, 0.002), at((0, 0.295, BARREL_Z), "Y"), 28)  # seam
    lathe(A, brass, prof_ring(0.124, 0.08, 0.075, 0.009), at((0, 0.70, BARREL_Z), "Y"), 32)    # big brass ring
    lathe(A, brass, prof_ring(0.110, 0.093, 0.12, 0.008), at((0, 0.85, BARREL_Z), "Y"), 32)     # muzzle ring
    lathe(A, graphite, prof_cyl(0.095, 0.01, 0.002), at((0, 0.88, BARREL_Z), "Y"), 28)        # bore
    # front sight
    box(A, brass, (0, 0.58, 1.018), (0.024, 0.05, 0.02), 0.004)
    lathe(A, brass, prof_cyl(0.012, 0.03, 0.003), at((0, 0.58, 1.0), "Z"), 10)

    # ---------------- scope ----------------
    box(A, brass, (0, 0.09, 1.057), (0.115, 0.26, 0.035), 0.008)
    box(A, brass, (0, 0.0, 1.10), (0.075, 0.04, 0.07), 0.008)
    box(A, brass, (0, 0.18, 1.10), (0.075, 0.04, 0.07), 0.008)
    lathe(A, grey, prof_cyl(0.042, 0.50, 0.004), at((0, -0.22, SCOPE_Z), "Y"), 18)        # main tube y -0.12..0.28
    lathe(A, brass, prof_ring(0.062, 0.04, 0.045, 0.006), at((0, 0.165, SCOPE_Z), "Y"), 20)
    lathe(A, brass, prof_ring(0.056, 0.04, 0.03, 0.005), at((0, 0.215, SCOPE_Z), "Y"), 20)
    lathe(A, brass, prof_ring(0.058, 0.04, 0.025, 0.005), at((0, -0.075, SCOPE_Z), "Y"), 20)
    # turret cube
    box(A, brass, (0, 0.10, SCOPE_Z), (0.115, 0.13, 0.115), 0.016)
    lathe(A, brass, prof_cyl(0.038, 0.05, 0.007), at((0, 0.10, SCOPE_Z + 0.05)), 18)
    lathe(A, graphite, prof_cyl(0.026, 0.012, 0.003), at((0, 0.10, SCOPE_Z + 0.098)), 14)
    for sx in (-1, 1):
        lathe(A, brass, prof_ring(0.044, 0.026, 0.05, 0.007), at((sx * 0.05, 0.10, SCOPE_Z), "X", sx), 20)
        lathe(A, graphite, prof_cyl(0.028, 0.01, 0.002), at((sx * 0.062, 0.10, SCOPE_Z), "X", sx), 16)
        lathe(A, glass_r, prof_dome(0.027, 0.018, 5), at((sx * 0.072, 0.10, SCOPE_Z), "X", sx), 16)
    # objective bell (front)
    bell = [(0, 0), (0.05, 0), (0.062, 0.025), (0.088, 0.07), (0.095, 0.09), (0.095, 0.145), (0.082, 0.145),
            (0.082, 0.105), (0, 0.105)]
    bell = [(r * 1.12 if r > 0.05 else r, h) for r, h in bell]
    lathe(A, brass, bell, at((0, 0.27, SCOPE_Z), "Y"), 32)
    lathe(A, graphite, prof_cyl(0.091, 0.012, 0.002), at((0, 0.27 + 0.105, SCOPE_Z), "Y"), 28)
    lathe(A, glass_b, prof_dome(0.088, 0.028, 6), at((0, 0.27 + 0.117, SCOPE_Z), "Y"), 28)
    # eyepiece (rear): brass body, grey band, brass cap
    lathe(A, brass, prof_ring(0.07, 0.04, 0.09, 0.008), at((0, -0.17, SCOPE_Z), "Y"), 28)
    lathe(A, grey, prof_ring(0.076, 0.04, 0.04, 0.004), at((0, -0.25, SCOPE_Z), "Y"), 28)
    ercap = [(0, 0), (0.07, 0), (0.084, 0.012), (0.088, 0.03), (0.088, 0.08), (0.074, 0.08), (0.074, 0.05), (0, 0.05)]
    lathe(A, brass, ercap, at((0, -0.29, SCOPE_Z), "Y"), 28)
    lathe(A, graphite, prof_cyl(0.07, 0.01, 0.002), at((0, -0.29 + 0.05, SCOPE_Z), "Y"), 24)
    lathe(A, glass_b, prof_dome(0.066, 0.018, 5), at((0, -0.29 + 0.06, SCOPE_Z), "Y"), 24)

    # ---------------- objects ----------------
    root = bpy.data.objects.new("CP_Sniper", None)
    bpy.context.collection.objects.link(root)
    aim = bpy.data.objects.new("Aim", None)
    bpy.context.collection.objects.link(aim)
    aim.parent = root
    aim.location = (0, 0, AIM_Z)
    muzzle = bpy.data.objects.new("Muzzle", None)
    bpy.context.collection.objects.link(muzzle)
    muzzle.parent = aim
    muzzle.location = (0, 0.97 - SHIFT, BARREL_Z - AIM_Z)

    meshes = []
    for (group, matname), (bm, mat) in ACC.items():
        # smooth shading with hard edges above the sharp angle
        for f in bm.faces:
            f.smooth = True
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > SHARP:
                e.smooth = False
        if group == A:
            bmesh.ops.translate(bm, vec=(0, -SHIFT, -AIM_Z), verts=bm.verts)
        mesh = bpy.data.meshes.new(f"{group}_{matname}")
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(mat)
        obj = bpy.data.objects.new(f"{group}_{matname.replace(' ', '_')}", mesh)
        bpy.context.collection.objects.link(obj)
        obj.parent = aim if group == A else root
        meshes.append(obj)
    return meshes


def bake_ao(meshes, samples=40, distance=0.25, floor=0.55):
    bpy.context.view_layer.update()
    verts, tris = [], []
    for obj in meshes:
        base = len(verts)
        verts.extend(obj.matrix_world @ v.co for v in obj.data.vertices)
        obj.data.calc_loop_triangles()
        tris.extend(tuple(base + i for i in t.vertices) for t in obj.data.loop_triangles)
    tree = BVHTree.FromPolygons(verts, tris)
    rng = random.Random(7)
    for obj in meshes:
        mesh = obj.data
        if any(m.name.startswith("Lens") for m in mesh.materials):
            continue
        nm = obj.matrix_world.to_3x3().inverted().transposed()
        colors = mesh.color_attributes.new("AO", "BYTE_COLOR", "CORNER")
        normals = mesh.corner_normals
        for loop in mesh.loops:
            pos = obj.matrix_world @ mesh.vertices[loop.vertex_index].co
            n = (nm @ normals[loop.index].vector).normalized()
            t = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
            bt = n.cross(t)
            origin = pos + n * 0.004
            hits = 0.0
            for _ in range(samples):
                r1, r2 = rng.random(), rng.random()
                rr, ang = math.sqrt(r1), math.tau * r2
                d = t * (rr * math.cos(ang)) + bt * (rr * math.sin(ang)) + n * math.sqrt(1 - r1)
                h = tree.ray_cast(origin, d, distance)
                if h[0] is not None:
                    hits += 1.0 - h[3] / distance
            occ = hits / samples
            v = floor + (1 - floor) * (1 - occ) ** 1.5
            colors.data[loop.index].color = (v, v, v, 1.0)
        mesh.color_attributes.active_color = colors
        mesh.color_attributes.render_color_index = list(mesh.color_attributes).index(colors)


if __name__ == "__main__":
    objs = build()
    bake_ao(objs)
    bpy.ops.export_scene.gltf(filepath=str(OUT / "cp_sniper.glb"), export_format="GLB", export_yup=True,
                              export_animations=False, export_cameras=False, export_lights=False,
                              export_vertex_color="ACTIVE")
    tri = 0
    for o in objs:
        o.data.calc_loop_triangles()
        tri += len(o.data.loop_triangles)
    print("BUILD OK tris", tri, "meshes", len(objs))

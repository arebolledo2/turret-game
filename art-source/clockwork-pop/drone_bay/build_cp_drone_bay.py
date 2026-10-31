"""Clockwork drone bay - scripted Blender build (Blender 5.x, --background).

Round coral/grey base, teal+brass hangar tunnel, coral tower, teal sensor head (Aim) with lens eyes,
dome and antenna, two hovering drones.  Exports cp_drone_bay.glb next to this script.
Blender +Z up, weapon faces +Y.
"""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT = Path(__file__).parent
SHARP = math.radians(35)

bpy.ops.wm.read_factory_settings(use_empty=True)


# --------------------------------------------------------------------------- materials
def lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h):
    h = h.lstrip("#")
    return tuple(lin(int(h[i:i + 2], 16) / 255) for i in (0, 2, 4))


def material(name, hexc, metal=0.0, rough=0.42, glow=0.0, alpha=1.0):
    col = hexcol(hexc)
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*col, alpha)
    mat.use_nodes = True
    sh = mat.node_tree.nodes.get("Principled BSDF")
    sh.inputs["Base Color"].default_value = (*col, 1)
    sh.inputs["Metallic"].default_value = metal
    sh.inputs["Roughness"].default_value = rough
    if glow:
        sh.inputs["Emission Color"].default_value = (*col, 1)
        sh.inputs["Emission Strength"].default_value = glow
    if alpha < 1.0:
        sh.inputs["Alpha"].default_value = alpha
        try:
            mat.surface_render_method = "BLENDED"
        except Exception:
            pass
    return mat


MAT = {
    "coral": material("coral", "#E5604F", rough=0.5),
    "teal": material("teal", "#2C8A86", rough=0.38),
    "brass": material("brass", "#D9A52F", metal=0.85, rough=0.3),
    "grey": material("slate", "#625A78", rough=0.55),
    "mint": material("mint", "#74CDAE", rough=0.6),
    "cream": material("cream", "#EADCC6", rough=0.5),
    "tile": material("tile", "#B5A6AE", rough=0.55),
    "plum": material("plum", "#33263F", rough=0.3),
    "violet": material("violet", "#6E4FD0", rough=0.3, glow=0.35),
    "glass": material("glass", "#4B2F72", rough=0.08, alpha=0.55),
    "glow_teal": material("glow_teal", "#4FE0CF", glow=1.2),
    "glow_orange": material("glow_orange", "#FF7A14", glow=1.2),
    "glow_white": material("glow_white", "#FFF4DC", glow=1.0),
}


# --------------------------------------------------------------------------- parts / geometry helpers
def empty(name, pos=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = pos
    return obj


class Part:
    parts = []

    def __init__(self, name, mat, parent=None):
        self.name, self.mat, self.parent = name, mat, parent
        self.scale = 1.0
        self.bm = bmesh.new()
        Part.parts.append(self)

    def vert(self, co):
        return self.bm.verts.new(co)

    def face(self, vs):
        try:
            self.bm.faces.new(vs)
        except ValueError:
            pass

    def merge(self, src, m):
        mp = {v: self.bm.verts.new(m @ v.co) for v in src.verts}
        for f in src.faces:
            self.face([mp[v] for v in f.verts])

    def build(self):
        bm = self.bm
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        # parts under Aim are authored in Aim-local coordinates; the others in world coordinates
        off = Vector(self.parent.location) if (self.parent and self.parent is not aim) else Vector()
        if self.scale != 1.0:
            for v in bm.verts:
                v.co = off + (v.co - off) * self.scale
        for v in bm.verts:
            v.co -= off
        for f in bm.faces:
            f.smooth = True
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > SHARP:
                e.smooth = False
        mesh = bpy.data.meshes.new(self.name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(self.mat)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.parent = self.parent
        return obj


def xform(pos, axis=(0, 0, 1), scale=(1, 1, 1), spin=0.0):
    a = Vector(axis).normalized()
    q = Vector((0, 0, 1)).rotation_difference(a)
    return (Matrix.Translation(pos) @ q.to_matrix().to_4x4()
            @ Matrix.Rotation(spin, 4, "Z") @ Matrix.Diagonal((*scale, 1)))


def lathe(part, profile, seg=32, pos=(0, 0, 0), axis=(0, 0, 1), scale=(1, 1, 1), loop=False):
    """Revolve a (radius, z) profile around +Z. Profile points with r~0 collapse onto the axis."""
    # iter08: segment count follows the part's size (small fittings need far fewer sides than the base disc)
    max_r = max(r for r, _ in profile) * max(scale[0], scale[1])
    seg = max(6, min(int(seg * 0.62), int(6 + max_r * 30)))
    m = xform(pos, axis, scale)
    rings = []
    for r, z in profile:
        if r < 1e-6:
            rings.append([part.vert(m @ Vector((0, 0, z)))])
        else:
            rings.append([part.vert(m @ Vector((r * math.cos(math.tau * j / seg),
                                                 r * math.sin(math.tau * j / seg), z))) for j in range(seg)])
    n = len(rings)
    for i in range(n if loop else n - 1):
        a, b = rings[i], rings[(i + 1) % n]
        if len(a) == 1 and len(b) == 1:
            continue
        for j in range(seg):
            j1 = (j + 1) % seg
            if len(a) == 1:
                part.face([a[0], b[j1], b[j]])
            elif len(b) == 1:
                part.face([a[j], a[j1], b[0]])
            else:
                part.face([a[j], a[j1], b[j1], b[j]])


def arc(cx, cz, rad, a0, a1, n):
    return [(cx + rad * math.cos(math.radians(a0 + (a1 - a0) * k / n)),
             cz + rad * math.sin(math.radians(a0 + (a1 - a0) * k / n))) for k in range(n + 1)]


def rr(r0, r1, z0, z1, rad, n=3):
    """Rounded-rectangle profile: solid disc if r0 == 0, ring (closed loop) otherwise."""
    rad = min(rad, (z1 - z0) / 2, (r1 - r0) / 2 if r0 > 0 else rad)
    n = 1 if rad < 0.013 else min(n, 2)   # iter08: tiny corner radii need no extra arc points
    pts = arc(r1 - rad, z0 + rad, rad, -90, 0, n) + arc(r1 - rad, z1 - rad, rad, 0, 90, n)
    if r0 < 1e-6:
        return [(0, z0)] + pts + [(0, z1)]
    return pts + arc(r0 + rad, z1 - rad, rad, 90, 180, n) + arc(r0 + rad, z0 + rad, rad, 180, 270, n)


def sphere(part, pos, r, seg=24, rings=12, scale=(1, 1, 1), axis=(0, 0, 1)):
    rings = max(4, min(rings, 4 + int(r * 25)))   # iter08: ring count follows size
    prof = [(r * math.sin(math.pi * k / rings), -r * math.cos(math.pi * k / rings)) for k in range(rings + 1)]
    prof[0] = (0, prof[0][1])
    prof[-1] = (0, prof[-1][1])
    lathe(part, prof, seg, pos, axis, scale)


def dome(part, pos, r, h=None, seg=24, rings=6, axis=(0, 0, 1)):
    """Flat-bottomed cap of an ellipsoid with base radius r and height h."""
    h = r if h is None else h
    rings = max(3, min(rings, 3 + int(r * 25)))   # iter08
    prof = [(0, 0)] + [(r * math.cos(math.pi / 2 * k / rings), h * math.sin(math.pi / 2 * k / rings))
                       for k in range(rings + 1)]
    prof[-1] = (0, h)
    lathe(part, prof, seg, pos, axis)


def box(part, pos, size, rot_z=0.0, bevel=0.01):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, min(size) * 0.45), segments=2,
                        affect="EDGES", profile=0.5)
    part.merge(bm, Matrix.Translation(pos) @ Matrix.Rotation(rot_z, 4, "Z"))
    bm.free()


def tube(part, pts, radius, sides=8):
    """Sweep a circle along a polyline (parallel transport), capped at both ends."""
    pts = [Vector(p) for p in pts]
    rings = []
    prev_n = None
    for i, p in enumerate(pts):
        t = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        if prev_n is None:
            ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
            nrm = t.cross(ref).normalized()
        else:
            nrm = (prev_n - t * prev_n.dot(t)).normalized()
        bin_ = t.cross(nrm)
        prev_n = nrm
        rings.append([part.vert(p + (nrm * math.cos(math.tau * j / sides)
                                     + bin_ * math.sin(math.tau * j / sides)) * radius) for j in range(sides)])
    for a, b in zip(rings, rings[1:]):
        for j in range(sides):
            j1 = (j + 1) % sides
            part.face([a[j], a[j1], b[j1], b[j]])
    for ring, p in ((rings[0], pts[0]), (rings[-1], pts[-1])):
        c = part.vert(p)
        for j in range(sides):
            part.face([ring[j], ring[(j + 1) % sides], c])


def bezier(p0, p1, p2, n=10):
    p0, p1, p2 = Vector(p0), Vector(p1), Vector(p2)
    return [(1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2 for t in (k / n for k in range(n + 1))]


def arch_outline(R, zbase, zleg, n=14):
    pts = [(-R, zbase)]
    for k in range(n + 1):
        t = math.pi * (1 - k / n)
        pts.append((R * math.cos(t), zleg + R * math.sin(t)))
    pts.append((R, zbase))
    return pts


def arch_sweep(part, R_out, R_in, zbase, zleg, y0, y1, n=14):
    """Closed solid: arch-shaped tube (annulus if R_in) running along Y from y0 to y1."""
    out = arch_outline(R_out, zbase, zleg, n)
    inn = arch_outline(R_in, zbase, zleg, n) if R_in else None
    vo = [(part.vert((x, y0, z)), part.vert((x, y1, z))) for x, z in out]
    m = len(out)
    for i in range(m):
        a, b = vo[i], vo[(i + 1) % m]
        part.face([a[0], b[0], b[1], a[1]])
    if inn:
        vi = [(part.vert((x, y0, z)), part.vert((x, y1, z))) for x, z in inn]
        for i in range(m):
            a, b = vi[i], vi[(i + 1) % m]
            part.face([a[0], b[0], b[1], a[1]])
            part.face([vo[i][0], vo[(i + 1) % m][0], b[0], a[0]])
            part.face([vo[i][1], vo[(i + 1) % m][1], b[1], a[1]])
    else:
        part.face([v[0] for v in vo])
        part.face([v[1] for v in vo])


# --------------------------------------------------------------------------- scene layout
TY = -0.10          # tower axis y
FLOOR = 0.165       # mint floor height
AIM_Z = 0.82        # neck height (Aim pivot)
ZB, ZL = 0.15, 0.19  # tunnel base / arch-spring heights
DS = 1.4            # drone scale

aim = empty("Aim", (0, TY, AIM_Z))
muzzle = empty("Muzzle", (0, 0.36, 0.27), aim)
drone_l = empty("Drone_Wire", (0.84, 0.30, 0.76))
drone_r = empty("Drone_Arm", (-0.93, -0.28, 0.58))

# ---- static base ---------------------------------------------------------
p = Part("Base_Slate", MAT["grey"])
lathe(p, rr(0, 1.15, 0.0, 0.10, 0.035, 3), 80)

p = Part("Base_Coral", MAT["coral"])
lathe(p, rr(0, 1.09, 0.09, 0.14, 0.02, 3), 80)
lathe(p, rr(0.93, 1.09, 0.10, 0.205, 0.045, 3), 80)
# tower
lathe(p, [(0, 0.16), (0.33, 0.16), (0.325, 0.22), (0.30, 0.30), (0.27, 0.35), (0.27, 0.78),
          (0.262, 0.82), (0.25, 0.84), (0, 0.84)], 44, (0, TY, 0))
# coral band wrapping the rear of the tunnel
arch_sweep(p, 0.525, 0.43, ZB, ZL, 0.17, 0.42)
arch_sweep(p, 0.48, 0.43, ZB, ZL, 0.84, 0.91)   # inner coral lip
# pad ring in front of the tunnel
lathe(p, rr(0.25, 0.32, 0.15, 0.205, 0.02, 3), 44, (0, 0.58, 0))

p = Part("Base_Mint", MAT["mint"])
lathe(p, rr(0, 0.95, 0.10, FLOOR, 0.01, 2), 80)

p = Part("Base_Cream", MAT["cream"])
a = math.atan2(0.9, -0.52)
box(p, (-0.52, 0.9, 0.155), (0.46, 0.27, 0.10), a - math.pi / 2, 0.03)

p = Part("Pad_Tile", MAT["tile"])
lathe(p, rr(0, 0.26, 0.15, 0.19, 0.012, 2), 44, (0, 0.58, 0))

p = Part("Tunnel_Teal", MAT["teal"])
arch_sweep(p, 0.50, 0.45, ZB, ZL, 0.40, 0.88)
# studs along the arch
p_studs = Part("Brass_Fixed", MAT["brass"])
for k in range(13):
    ang = math.radians(6 + k * 168 / 12)
    sphere(p_studs, (0.505 * math.cos(ang), 0.45, ZL + 0.505 * math.sin(ang)), 0.018, 8, 5)
for k in range(9):
    ang = math.radians(15 + k * 150 / 8)
    sphere(p_studs, (0.505 * math.cos(ang), 0.835, ZL + 0.505 * math.sin(ang)), 0.014, 8, 5)

# front brass trim, brackets, base strip
arch_sweep(p_studs, 0.54, 0.465, ZB, ZL, 0.86, 0.92)
box(p_studs, (0.54, 0.87, 0.23), (0.08, 0.10, 0.16), 0, 0.02)
box(p_studs, (-0.55, 0.66, 0.20), (0.05, 0.40, 0.06), 0, 0.015)
# collar and brackets at tower top
lathe(p_studs, rr(0.19, 0.295, 0.78, 0.855, 0.03, 3), 44, (0, TY, 0))
for ang in (70, 118):
    r = math.radians(ang)
    box(p_studs, (0.265 * math.cos(r), TY + 0.265 * math.sin(r), 0.81), (0.07, 0.05, 0.1), r - math.pi / 2, 0.012)
# indicator lens ring on tower side + pipe ball
IA = math.radians(198)
idir = Vector((math.cos(IA), math.sin(IA), 0))
tpos = Vector((0, TY, 0))
lathe(p_studs, rr(0.045, 0.082, 0, 0.04, 0.015, 2), 28, tpos + idir * 0.265 + Vector((0, 0, 0.45)), idir)
sphere(p_studs, (-0.68, 0.55, 0.31), 0.068, 20, 10)
lathe(p_studs, rr(0, 0.075, FLOOR - 0.01, 0.21, 0.012, 2), 24, (-0.68, 0.55, 0))
# small pod
lathe(p_studs, rr(0.075, 0.11, FLOOR - 0.005, 0.2, 0.012, 2), 24, (-0.70, 0.08, 0))
dome(p_studs, (-0.70, 0.08, 0.34), 0.05, 0.05, 20, 4)
# left wire base, right arm base
lathe(p_studs, rr(0, 0.06, FLOOR - 0.01, 0.2, 0.012, 2), 24, (0.68, 0.30, 0))
sphere(p_studs, (-0.74, -0.30, 0.42), 0.052, 16, 8)
tube(p_studs, bezier((-0.74, -0.30, 0.42), (-0.98, -0.36, 0.44), (-0.93, -0.28, 0.50)), 0.02, 8)

p = Part("Grey_Fixed", MAT["grey"])
# posts, pipe, wire, indicator panel
box(p, tuple(tpos + idir * 0.275 + Vector((0, 0, 0.66))), (0.05, 0.12, 0.21), IA, 0.015)
lathe(p, rr(0, 0.032, 0.16, 0.31, 0.01, 2), 14, (-0.68, 0.55, 0))
lathe(p, rr(0, 0.03, 0, 0.13, 0.008, 2), 14, (-0.55, 0.55, 0.31), (-1, 0, 0))
lathe(p, rr(0, 0.04, FLOOR - 0.005, 0.42, 0.01, 2), 14, (-0.74, -0.30, 0))
tube(p, bezier((0.84, 0.30, 0.65), (0.94, 0.30, 0.34), (0.68, 0.30, 0.19)), 0.009, 6)

p = Part("Interior_Plum", MAT["plum"])
arch_sweep(p, 0.46, 0.42, ZB, ZL, 0.20, 0.89)
arch_sweep(p, 0.46, 0, ZB, ZL, 0.19, 0.25)

p = Part("Teal_Pod", MAT["teal"])
sphere(p, (-0.70, 0.08, 0.26), 0.098, 24, 12, (1, 1, 0.95))

p = Part("Violet_Fixed", MAT["violet"])
lathe(p, rr(0.25, 0.345, 0.19, 0.265, 0.03, 3), 44, (0, TY, 0))
dome(p, tuple(tpos + idir * 0.28 + Vector((0, 0, 0.45))), 0.044, 0.03, 20, 4, tuple(idir))

p = Part("Glow_Teal", MAT["glow_teal"])
for z in (0.72, 0.62):
    lathe(p, rr(0, 0.028, 0, 0.022, 0.008, 2), 16, tpos + idir * 0.30 + Vector((0, 0, z)), idir)

p = Part("Glow_White_Fixed", MAT["glow_white"])
sphere(p, (-0.78, 0.38, 0.195), 0.03, 12, 6)

# ---- Aim: sensor head (Aim-local coordinates) -------------------------------------
HC = 0.27   # head centre height above neck pivot
HR = 0.36   # head radius
EYE_Z = HC - 0.025
S38 = math.radians(38)
eye_dirs = [Vector((s * math.sin(S38), math.cos(S38), 0)) for s in (1, -1)]
pod_dirs = [Vector((s * 0.97, -0.22, 0)).normalized() for s in (1, -1)]
ANT = (0.20, -0.17)

p = Part("Head_Teal", MAT["teal"], aim)
sphere(p, (0, 0, HC), HR, 52, 26, (1, 1, 0.95))
for d in pod_dirs:
    lathe(p, rr(0, 0.105, 0, 0.20, 0.035, 3), 32, d * 0.18 + Vector((0, 0, HC + 0.035)), d)

p = Part("Head_Brass", MAT["brass"], aim)
lathe(p, rr(0.32, 0.352, 0.15, 0.172, 0.009, 2), 48, (0, 0, 0.0))          # seam bead
lathe(p, rr(0.13, 0.205, 0.575, 0.645, 0.02, 3), 40, (0, 0, 0))              # dome ring
for k in range(4):
    ang = math.radians(35 + 90 * k)
    sphere(p, (0.205 * math.cos(ang), 0.205 * math.sin(ang), 0.63), 0.018, 10, 6)
for d, dp in zip(eye_dirs, pod_dirs):
    lathe(p, rr(0.125, 0.20, 0, 0.12, 0.028, 3), 36, d * 0.29 + Vector((0, 0, EYE_Z)), d)
    lathe(p, rr(0.075, 0.135, 0, 0.05, 0.014, 3), 30, dp * 0.34 + Vector((0, 0, HC + 0.035)), dp)
lathe(p, rr(0, 0.026, 0.50, 0.55, 0.009, 2), 14, (*ANT, 0))                  # antenna ferrule
lathe(p, rr(0, 0.016, 0.75, 0.78, 0.006, 2), 12, (*ANT, 0))

p = Part("Head_Plum", MAT["plum"], aim)
for d, dp in zip(eye_dirs, pod_dirs):
    lathe(p, rr(0, 0.13, 0.0, 0.06, 0.012, 2), 32, d * 0.29 + Vector((0, 0, EYE_Z)), d)
    lathe(p, rr(0, 0.078, 0, 0.045, 0.01, 2), 24, dp * 0.34 + Vector((0, 0, HC + 0.035)), dp)

p = Part("Head_Glass", MAT["glass"], aim)
for d in eye_dirs:
    dome(p, d * 0.385 + Vector((0, 0, EYE_Z)), 0.13, 0.06, 32, 6, tuple(d))

p = Part("Head_Slate", MAT["plum"], aim)
dome(p, (0, 0, 0.575), 0.16, 0.12, 40, 8)
tube(p, [(*ANT, 0.52), (*ANT, 0.76)], 0.009, 8)

p = Part("Antenna_Bulb", MAT["glow_white"], aim)
sphere(p, (*ANT, 0.81), 0.042, 18, 10)


# ---- drones ---------------------------------------------------------------------
def build_drone(name, emp, side):
    d2 = Vector((0.6 * side, 0.8, 0)).normalized()
    c = Vector(emp.location)
    pb = Part(f"{name}_Brass", MAT["brass"], emp)
    lathe(pb, rr(0, 0.17, -0.035, -0.005, 0.012, 3), 36, c)                    # dish
    lathe(pb, rr(0.14, 0.175, -0.035, 0.02, 0.012, 3), 36, c)                  # rim
    lathe(pb, [(0, -0.075), (0.028, -0.06), (0.04, -0.035), (0, -0.035)], 16, c)
    for k in range(4):
        ang = math.radians(45 + 90 * k)
        sx, sy = 0.195 * math.cos(ang), 0.195 * math.sin(ang)
        lathe(pb, rr(0, 0.008, -0.02, 0.05, 0.003, 1), 8, c + Vector((sx, sy, 0)))
        sphere(pb, c + Vector((sx, sy, 0.063)), 0.016, 10, 6)
    lathe(pb, rr(0.026, 0.05, 0, 0.018, 0.006, 2), 20, c + d2 * 0.085 + Vector((0, 0, 0.05)), d2)
    pt = Part(f"{name}_Teal", MAT["teal"], emp)
    sphere(pt, c + Vector((0, 0, 0.05)), 0.108, 32, 16, (1, 1, 0.92))
    pc = Part(f"{name}_Cream", MAT["cream"], emp)
    dome(pc, c + Vector((0, 0, 0.145)), 0.04, 0.012, 20, 3)
    pg = Part(f"{name}_Glow", MAT["glow_orange"], emp)
    sphere(pg, c + d2 * 0.095 + Vector((0, 0, 0.05)), 0.03, 16, 8, (1, 1, 1))
    pp = Part(f"{name}_Props", MAT["grey"], emp)   # separate so it can spin
    for k in range(4):
        ang = math.radians(45 + 90 * k)
        pos = c + Vector((0.195 * math.cos(ang), 0.195 * math.sin(ang), 0.044))
        m = Matrix.Translation(pos) @ Matrix.Rotation(ang + 0.5, 4, "Z") @ Matrix.Diagonal((0.075, 0.026, 0.008, 1))
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=5, radius=1.0)
        pp.merge(bm, m)
        bm.free()
    for part in (pb, pt, pc, pg, pp):
        part.scale = DS


build_drone("Drone_Wire", drone_l, 1)
build_drone("Drone_Arm", drone_r, -1)

# --------------------------------------------------------------------------- finish + export
for part in Part.parts:
    part.build()

bpy.context.view_layer.update()
bpy.ops.export_scene.gltf(
    filepath=str(OUT / "cp_drone_bay.glb"),
    export_format="GLB",
    export_yup=True,
    export_animations=False,
    export_cameras=False,
    export_lights=False,
)

"""Clockwork decoy bumper post: round coral/cream bumper base, chrome spring, teal dome head with two
brass-ringed purple lens eyes, cream bumper ring, brass lantern cage with a glowing bulb.

Run: blender --background --python build_cp_decoy.py
Metres, +Z up, weapon faces +Y. Static base; Aim (head, lantern, bumper ring) rotates about the vertical axis.
"""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT = Path(__file__).parent
SHARP = math.radians(35)
SEG = 48  # lathe segments around the axis

bpy.ops.wm.read_factory_settings(use_empty=True)

# ---------------------------------------------------------------- materials


def material(name, color, metal=0.0, rough=0.35, emit=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, alpha)
    mat.use_nodes = True
    sh = mat.node_tree.nodes.get("Principled BSDF")
    sh.inputs["Base Color"].default_value = (*color, 1)
    sh.inputs["Metallic"].default_value = metal
    sh.inputs["Roughness"].default_value = rough
    if emit:
        sh.inputs["Emission Color"].default_value = (*color, 1)
        sh.inputs["Emission Strength"].default_value = emit
    if alpha < 1.0:
        sh.inputs["Alpha"].default_value = alpha
        try:
            mat.surface_render_method = "BLENDED"
        except Exception:
            pass
    return mat


M = {
    "coral": material("Coral", (0.72, 0.10, 0.045), rough=0.30),
    "cream": material("Cream", (0.86, 0.62, 0.30), rough=0.34),
    "teal": material("Teal", (0.012, 0.30, 0.27), rough=0.25),
    "brass": material("Brass", (0.86, 0.46, 0.06), metal=0.8, rough=0.30),
    "dbrass": material("DarkBrass", (0.42, 0.26, 0.07), metal=0.6, rough=0.4),
    "chrome": material("Chrome", (0.82, 0.84, 0.88), metal=1.0, rough=0.16),
    "dark": material("DarkRubber", (0.10, 0.09, 0.12), rough=0.55),
    "lens": material("PurpleLens", (0.30, 0.06, 0.52), rough=0.06),
    "bulb": material("BulbCore", (1.0, 0.82, 0.25), emit=3.0, rough=0.3),
    "glass": material("BulbGlass", (1.0, 0.93, 0.62), rough=0.05, alpha=0.30),
}

# ---------------------------------------------------------------- mesh builder


class Part:
    """Accumulates geometry (several materials allowed) into one mesh object."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []

    def mi(self, key):
        mat = M[key]
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    def _face(self, verts, mi):
        try:
            f = self.bm.faces.new(verts)
            f.material_index = mi
        except ValueError:
            pass

    def lathe(self, profile, mat, xf=Matrix.Identity(4), seg=SEG, closed=False):
        """Revolve (r, z) profile about Z. Points with r~0 collapse onto the axis."""
        mi = self.mi(mat)
        rings = []
        for r, z in profile:
            if r < 1e-6:
                rings.append([self.bm.verts.new(xf @ Vector((0, 0, z)))])
            else:
                rings.append([self.bm.verts.new(xf @ Vector((r * math.cos(math.tau * i / seg),
                                                            r * math.sin(math.tau * i / seg), z)))
                              for i in range(seg)])
        pairs = list(zip(rings[:-1], rings[1:]))
        if closed:
            pairs.append((rings[-1], rings[0]))
        for a, b in pairs:
            for i in range(seg):
                j = (i + 1) % seg
                if len(a) == 1 and len(b) == 1:
                    continue
                if len(a) == 1:
                    self._face([a[0], b[j], b[i]], mi)
                elif len(b) == 1:
                    self._face([a[i], a[j], b[0]], mi)
                else:
                    self._face([a[i], a[j], b[j], b[i]], mi)

    def tube(self, pts, radius, mat, sides=8, sub=0, caps=True):
        mi = self.mi(mat)
        pts = [Vector(p) for p in pts]
        if sub:  # Catmull-Rom resample
            ext = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
            out = []
            for k in range(1, len(ext) - 2):
                p0, p1, p2, p3 = ext[k - 1], ext[k], ext[k + 1], ext[k + 2]
                for s in range(sub):
                    t = s / sub
                    out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                                      + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3))
            out.append(pts[-1])
            pts = out
        tans = []
        for i in range(len(pts)):
            a = pts[max(i - 1, 0)]
            b = pts[min(i + 1, len(pts) - 1)]
            tans.append((b - a).normalized())
        n = tans[0].cross(Vector((0, 0, 1)) if abs(tans[0].z) < 0.9 else Vector((1, 0, 0))).normalized()
        rings = []
        for p, t in zip(pts, tans):
            n = (n - t * n.dot(t)).normalized()
            b = t.cross(n)
            rings.append([self.bm.verts.new(p + radius * (math.cos(math.tau * k / sides) * n
                                                          + math.sin(math.tau * k / sides) * b))
                          for k in range(sides)])
        for a, b in zip(rings[:-1], rings[1:]):
            for k in range(sides):
                m = (k + 1) % sides
                self._face([a[k], a[m], b[m], b[k]], mi)
        if caps:
            self._face(rings[0][::-1], mi)
            self._face(rings[-1], mi)

    def box(self, size, mat, xf, bevel, segs=3):
        mi = self.mi(mat)
        tmp = bmesh.new()
        res = bmesh.ops.create_cube(tmp, size=1.0)
        for v in res["verts"]:
            v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
        bmesh.ops.bevel(tmp, geom=list(tmp.edges), offset=bevel, offset_type="OFFSET", segments=segs,
                        profile=0.5, affect="EDGES")
        vmap = {v: self.bm.verts.new(xf @ v.co) for v in tmp.verts}
        for f in tmp.faces:
            self._face([vmap[v] for v in f.verts], mi)
        tmp.free()

    def finish(self, parent=None, parent_z=0.0):
        bm = self.bm
        if parent is not None:  # Aim parts: uniform scale about the ring height, then lower the whole head assembly
            bmesh.ops.transform(bm, matrix=AIM_XF, verts=bm.verts)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        for f in bm.faces:
            f.smooth = True
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > SHARP:
                e.smooth = False
        mesh = bpy.data.meshes.new(self.name)
        bm.to_mesh(mesh)
        bm.free()
        for m in self.mats:
            mesh.materials.append(m)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.collection.objects.link(obj)
        if parent is not None:  # vertices are stored in world space; cancel the parent's offset
            obj.parent = parent
            obj.location = (0, 0, -parent_z)
        return obj


# ---------------------------------------------------------------- profile helpers


def rrect(r0, r1, z0, z1, rad, n=3):
    """Rounded-rectangle (r, z) profile. r0 == 0 gives an open profile that starts/ends on the axis."""
    def arc(cr, cz, a0):
        return [(cr + rad * math.cos(math.radians(a0 + 90 * k / n)),
                 cz + rad * math.sin(math.radians(a0 + 90 * k / n))) for k in range(n + 1)]
    pts = arc(r1 - rad, z0 + rad, -90) + arc(r1 - rad, z1 - rad, 0)
    if r0 <= 1e-6:
        return [(0, z0)] + pts + [(0, z1)]
    return pts + arc(r0 + rad, z1 - rad, 90) + arc(r0 + rad, z0 + rad, 180)


def ellipse(rx, rz, cz, a0=-90, a1=90, n=16):
    return [(rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)), cz + rz * math.sin(math.radians(a0 + (a1 - a0) * i / n)))
            for i in range(n + 1)]


def place(pos, direction=None):
    """Transform placing a +Z-built object at pos, with +Z pointing along direction."""
    m = Matrix.Translation(pos)
    if direction is not None:
        m = m @ Vector((0, 0, 1)).rotation_difference(Vector(direction).normalized()).to_matrix().to_4x4()
    return m


def polar(r, az_deg):
    """Azimuth measured from +Y (forward) toward +X."""
    a = math.radians(az_deg)
    return Vector((r * math.sin(a), r * math.cos(a), 0))


# ---------------------------------------------------------------- scene skeleton

AIM_Z = 0.50
AIM_S = 1.10            # head assembly scale (modelled at 1.0, enlarged to match concept proportions)
AIM_P0, AIM_P1 = 0.55, 0.46   # ring height before/after
AIM_XF = (Matrix.Translation((0, 0, AIM_P1)) @ Matrix.Scale(AIM_S, 4) @ Matrix.Translation((0, 0, -AIM_P0)))
aim = bpy.data.objects.new("Aim", None)
aim.location = (0, 0, AIM_Z)
bpy.context.collection.objects.link(aim)
muzzle = bpy.data.objects.new("Muzzle", None)
muzzle.parent = aim
muzzle.location = (AIM_XF @ Vector((0, 0.325, 0.77))) - Vector((0, 0, AIM_Z))
bpy.context.collection.objects.link(muzzle)

# ================================================================ STATIC BASE

# Base body: coral outer ring, teal recessed deck, coral hub
base = Part("Base_Body")
base.lathe(rrect(0.265, 0.42, 0.0, 0.13, 0.05, 2), "coral", closed=True, seg=48)
base.lathe(rrect(0.0, 0.29, 0.02, 0.10, 0.03, 2), "teal", seg=48)
base.lathe(rrect(0.0, 0.155, 0.09, 0.20, 0.04, 2), "coral", seg=40)
base.lathe(rrect(0.0, 0.105, 0.195, 0.22, 0.012, 2), "dark", seg=28)
base.finish()

# Cream bumper blocks around the base ring
blocks = Part("Base_Blocks")
for az in (45, 135, 225, 315):
    c = polar(0.355, az)
    xf = Matrix.Translation((c.x, c.y, 0.09)) @ Matrix.Rotation(-math.radians(az), 4, "Z")
    blocks.box((0.23, 0.22, 0.18), "cream", xf, 0.045, 2)
blocks.finish()

# Dark rubber feet
feet = Part("Base_Feet")
for az in (20, 150, 260):
    c = polar(0.44, az)
    feet.lathe(ellipse(0.04, 0.028, 0.022, -90, 90, 6), "dark", Matrix.Translation((c.x, c.y, 0.0)), seg=12)
feet.finish()

# Chrome coil spring + dark core
spring = Part("Spring")
turns, steps, rad_s = 3.5, 18, 0.105
helix = [Vector((rad_s * math.cos(math.tau * k / steps), rad_s * math.sin(math.tau * k / steps),
                 0.24 + 0.16 * k / (turns * steps))) for k in range(int(turns * steps) + 1)]
spring.tube(helix, 0.017, "chrome", sides=8)
spring.finish()
core = Part("Spring_Core")
core.lathe(rrect(0.0, 0.088, 0.21, 0.46, 0.012, 2), "dark", seg=24)
core.finish()

# ================================================================ AIM (rotating head)

HC = Vector((0, 0, 0.76))  # head equator centre (seam height)
HRX = 0.30
UPPER, LOWER = 0.35, 0.245
HTOP = HC.z + UPPER

# Head: dome above the seam, near-cylindrical bowl below it, seam groove between
head = Part("Head")
prof = []
for i in range(0, 13):  # lower bowl, bottom -> equator
    a = -90 + 90 * i / 12
    prof.append((HRX * max(math.cos(math.radians(a)), 0.0) ** 0.6, HC.z + LOWER * math.sin(math.radians(a))))
prof[0] = (0.0, prof[0][1])
for i in range(1, 17):  # upper dome
    a = 90 * i / 16
    prof.append((HRX * math.cos(math.radians(a)), HC.z + UPPER * math.sin(math.radians(a))))
# seam: pinch the two profile points straddling the equator
prof = [(r * (0.945 if abs(z - HC.z) < 0.022 else 1.0), z) for r, z in prof]
head.lathe(prof, "teal", seg=44)
# Front rivet-button below the eyes
bd = Vector((0, 0.95, -0.3)).normalized()
bp = Vector((0, 0.235, 0.615))
head.lathe(rrect(0, 0.04, -0.02, 0.016, 0.008, 2), "coral", place(bp, bd), seg=20)
head.lathe(ellipse(0.021, 0.02, 0.014, 0, 90, 5), "chrome", place(bp, bd), seg=14)
head.finish(aim, AIM_Z)

# Eyes: coral flange, thin brass barrel with rivets, big purple lens
for side, name in ((-1, "Eye_L"), (1, "Eye_R")):
    az = math.radians(side * 42)
    el = 0.10
    d = Vector((math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)))
    p = HC + Vector((0, 0, 0.02)) + d * 0.265
    xf = place(p, d)
    eye = Part(name)
    eye.lathe(rrect(0.115, 0.165, -0.04, 0.035, 0.026, 2), "coral", xf, seg=28, closed=True)
    eye.lathe(rrect(0.0, 0.165, -0.05, -0.01, 0.008, 2), "coral", xf, seg=28)
    eye.lathe(rrect(0.104, 0.132, -0.02, 0.085, 0.01, 2), "brass", xf, seg=28, closed=True)
    eye.lathe(rrect(0.0, 0.108, -0.03, -0.01, 0.006, 2), "dark", xf, seg=20)
    eye.lathe(ellipse(0.106, 0.10, 0.005, -30, 90, 8), "lens", xf, seg=24)
    for k in range(8):
        a = math.tau * k / 8
        eye.lathe(ellipse(0.009, 0.008, 0.0, 0, 90, 2), "chrome",
                  xf @ Matrix.Translation((0.118 * math.cos(a), 0.118 * math.sin(a), 0.086)), seg=6)
    eye.finish(aim, AIM_Z)

# Side pods behind the eyes (left: coral drum, right: brass drum)
for side, name, key in ((1, "Pod_R", "brass"), (-1, "Pod_L", "coral")):
    pod = Part(name)
    axis = Vector((side, -0.35, 0)).normalized()
    xf = place(Vector((side * 0.235, -0.085, 0.905)), axis)
    pod.lathe(rrect(0.0, 0.105, 0.0, 0.10, 0.025, 2), key, xf, seg=24)
    pod.lathe(rrect(0.0, 0.07, 0.095, 0.115, 0.008, 2), "dbrass" if side > 0 else "chrome", xf, seg=16)
    pod.lathe(rrect(0.0, 0.125, -0.03, 0.02, 0.008, 2), "coral" if side > 0 else "brass", xf, seg=24)
    pod.finish(aim, AIM_Z)

# Cream bumper ring around the neck (round-sectioned band) with chunky blocks
ring = Part("Bumper_Ring")
RZ = 0.55
ring.lathe(rrect(0.252, 0.345, RZ - 0.045, RZ + 0.045, 0.042, 2), "cream", closed=True, seg=44)
for az in (45, 135, 225, 315):
    c = polar(0.32, az)
    xf = Matrix.Translation((c.x, c.y, RZ)) @ Matrix.Rotation(-math.radians(az), 4, "Z")
    ring.box((0.21, 0.19, 0.15), "cream", xf, 0.04, 2)
ring.finish(aim, AIM_Z)

# Lantern: brass collar, socket (LZ = collar base)
LZ = HTOP - 0.03
collar = Part("Lantern_Collar")
collar.lathe(rrect(0.0, 0.175, LZ, LZ + 0.07, 0.03, 2), "brass", seg=36)
collar.lathe(rrect(0.0, 0.115, LZ + 0.06, LZ + 0.09, 0.008, 2), "dbrass", seg=28)
collar.lathe(rrect(0.0, 0.082, LZ + 0.085, LZ + 0.125, 0.014, 2), "brass", seg=24)
collar.finish(aim, AIM_Z)

# Bulb: glowing core + translucent glass
BC = LZ + 0.225  # bulb centre
bulb = Part("Bulb")
bulb.lathe([(0.0, BC - 0.12), (0.045, BC - 0.12), (0.045, BC - 0.09)] + ellipse(0.115, 0.115, BC, -45, 90, 10)[1:], "bulb", seg=22)
bulb.finish(aim, AIM_Z)
glass = Part("Bulb_Glass")
glass.lathe([(0.0, BC - 0.13), (0.06, BC - 0.13), (0.06, BC - 0.11)] + ellipse(0.145, 0.145, BC, -50, 90, 12)[1:], "glass", seg=22)
glass.finish(aim, AIM_Z)

# Cage: two bowed handles, top cap, dome, neck, finial
CZ = BC + 0.165  # cap underside
cage = Part("Lantern_Cage")
for s in (-1, 1):
    path = [(s * 0.105, 0, LZ + 0.10), (s * 0.19, 0, LZ + 0.105), (s * 0.245, 0, LZ + 0.15),
            (s * 0.24, 0, BC + 0.02), (s * 0.175, 0, CZ + 0.01)]
    cage.tube(path, 0.016, "brass", sides=8, sub=5)
    cage.lathe(ellipse(0.028, 0.028, 0, -90, 90, 6), "brass", Matrix.Translation((s * 0.105, 0, LZ + 0.10)), seg=10)
cage.lathe(rrect(0.0, 0.195, CZ, CZ + 0.032, 0.014, 2), "brass", seg=36)
cage.lathe(ellipse(0.13, 0.04, CZ + 0.028, 0, 90, 8), "brass", seg=28)
cage.lathe(rrect(0.0, 0.06, CZ + 0.06, CZ + 0.082, 0.008, 2), "dbrass", seg=20)
cage.lathe(rrect(0.0, 0.095, CZ + 0.076, CZ + 0.10, 0.01, 2), "brass", seg=28)
cage.lathe(ellipse(0.032, 0.032, CZ + 0.118, -90, 90, 8), "brass", seg=16)
cage.finish(aim, AIM_Z)

# ---------------------------------------------------------------- export
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=str(OUT / "cp_decoy.glb"), export_format="GLB", export_yup=True,
                          export_animations=False, export_cameras=False, export_lights=False)
print("exported", OUT / "cp_decoy.glb")

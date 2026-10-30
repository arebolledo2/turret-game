"""Clockwork mine layer: hexagonal teal tower, funnel hopper of spiked mines, brass-ringed coral barrel.

Run: blender --background --python build_cp_mine_layer.py
Metres, Blender +Z up, weapon faces +Y. Aim (hopper + barrel) rotates on the vertical axis; Muzzle sits at the barrel mouth.
Geometry is lathed/boxed in bmesh (no bpy.ops primitives) and merged into one mesh object per material per assembly.
"""
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

OUT = Path(__file__).parent
SHARP = math.radians(35)

# ---------------------------------------------------------------- scene setup
bpy.ops.wm.read_factory_settings(use_empty=True)


def srgb(hexstr):
    h = hexstr.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x ** 2.2 for x in c)


def material(name, hexcol, metal=0.0, rough=0.38, spec=0.5):
    mat = bpy.data.materials.new(name)
    col = (*srgb(hexcol), 1)
    mat.diffuse_color = col
    mat.use_nodes = True
    sh = mat.node_tree.nodes.get("Principled BSDF")
    sh.inputs["Base Color"].default_value = col
    sh.inputs["Metallic"].default_value = metal
    sh.inputs["Roughness"].default_value = rough
    return mat


M = {
    "teal": material("Teal_Paint", "#1E8C86", rough=0.34),
    "coral": material("Coral_Paint", "#EE675F", rough=0.34),
    "brass": material("Brass", "#D9951A", metal=0.2, rough=0.42),
    "cream": material("Cream_Mine", "#F3E6C6", rough=0.42),
    "dark": material("Dark_Interior", "#12373A", rough=0.5),
    "mint": material("Mint_Dome", "#92E4D2", rough=0.3),
    "lilac": material("Lilac_Dome", "#B49CE3", rough=0.3),
    "orange": material("Port_Orange", "#F28A2C", rough=0.35),
}

base = bpy.data.objects.new("Base", None)
bpy.context.collection.objects.link(base)
AIM_POS = Vector((0, 0, 0.70))
aim = bpy.data.objects.new("Aim", None)
bpy.context.collection.objects.link(aim)
aim.parent = base
aim.location = AIM_POS

# ---------------------------------------------------------------- mesh builders
groups = {}  # name -> (bmesh, material key, is_aim)


def group(name, mat, is_aim=False):
    if name not in groups:
        groups[name] = (bmesh.new(), mat, is_aim)
    return groups[name][0]


def orient(direction):
    d = Vector(direction).normalized()
    if abs(d.z) > 0.9999:
        return Quaternion((1, 0, 0, 0)) if d.z > 0 else Quaternion((1, 0, 0), math.pi)
    return d.to_track_quat("Z", "Y")


def finish_geom(bm, verts, faces, bev):
    bmesh.ops.remove_doubles(bm, verts=[v for v in verts if v.is_valid], dist=1e-6)
    faces = [f for f in faces if f.is_valid]
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    if bev > 0:
        edges = set()
        for f in faces:
            for e in f.edges:
                if len(e.link_faces) == 2:
                    ang = e.calc_face_angle(0.0)
                    if ang > SHARP:
                        edges.add(e)
        if edges:
            bmesh.ops.bevel(bm, geom=list(edges), offset=bev, segments=1, profile=0.5,
                            affect="EDGES", clamp_overlap=True)


def lathe(name, mat, profile, n, pos=(0, 0, 0), direction=(0, 0, 1), rot=0.0, closed=False, bev=0.0,
          is_aim=False, scale=1.0):
    """Revolve (radius, z) profile about local Z. rot = degrees offset of the first vertex."""
    bm = group(name, mat, is_aim)
    q = orient(direction)
    xf = Matrix.Translation(Vector(pos)) @ q.to_matrix().to_4x4()
    rings = []
    verts = []
    for r, z in profile:
        r *= scale
        z *= scale
        if r < 1e-7:
            v = bm.verts.new(xf @ Vector((0, 0, z)))
            verts.append(v)
            rings.append([v] * n)
        else:
            ring = []
            for j in range(n):
                a = math.radians(rot) + math.tau * j / n
                v = bm.verts.new(xf @ Vector((r * math.cos(a), r * math.sin(a), z)))
                ring.append(v)
                verts.append(v)
            rings.append(ring)
    faces = []
    pairs = list(range(len(rings) - 1)) + ([len(rings) - 1] if closed else [])
    for i in pairs:
        r0, r1 = rings[i], rings[(i + 1) % len(rings)]
        for j in range(n):
            quad = [r0[j], r0[(j + 1) % n], r1[(j + 1) % n], r1[j]]
            uniq = []
            for v in quad:
                if v not in uniq:
                    uniq.append(v)
            if len(uniq) >= 3:
                try:
                    faces.append(bm.faces.new(uniq))
                except ValueError:
                    pass
    finish_geom(bm, verts, faces, bev)


def sphere_profile(r, rings, a0=-90, a1=90):
    pts = []
    for i in range(rings + 1):
        a = math.radians(a0 + (a1 - a0) * i / rings)
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


def ball(name, mat, pos, r, seg=8, rings=4, is_aim=False):
    lathe(name, mat, sphere_profile(r, rings), seg, pos=pos, is_aim=is_aim)


def box(name, mat, center, size, rotz=0.0, bev=0.008, is_aim=False):
    """size = (x, y, z) in the box's own frame (x = radial when rotz = outward angle in degrees)."""
    bm = group(name, mat, is_aim)
    res = bmesh.ops.create_cube(bm, size=1.0)
    verts = res["verts"]
    xf = (Matrix.Translation(Vector(center)) @ Matrix.Rotation(math.radians(rotz), 4, "Z")
          @ Matrix.Diagonal((*size, 1.0)))
    for v in verts:
        v.co = xf @ v.co
    faces = list({f for v in verts for f in v.link_faces})
    finish_geom(bm, verts, faces, min(bev, min(size) * 0.3))


def radial(ang, r, z):
    a = math.radians(ang)
    return Vector((r * math.cos(a), r * math.sin(a), z))


def body_ap(z):
    """Apothem (face distance) of the hex body at height z (body tapers slightly)."""
    R = 0.54 - (min(max(z, 0.16), 0.80) - 0.16) / 0.64 * 0.05
    return R * math.cos(math.radians(30))


HOP_Z0, HOP_Z1 = 0.78, 1.46


def hop_ap(z):
    return (0.38 + (z - HOP_Z0) * (0.195 / (HOP_Z1 - HOP_Z0))) * math.cos(math.radians(22.5))



# ================================================================ STATIC BASE
# --- hex body
lathe("Body_Teal", "teal", [(0, 0.10), (0.50, 0.10), (0.54, 0.16), (0.49, 0.80), (0, 0.80)], 6, bev=0.014)
# recessed floor around the hopper (inside the collar)
lathe("Body_Teal", "teal", [(0.26, 0.80), (0.54, 0.80), (0.54, 0.90), (0.26, 0.90)], 6, bev=0.0)
# coral collar band, overhanging the body
lathe("Body_Coral", "coral",
      [(0.605, 0.78), (0.64, 0.82), (0.64, 0.92), (0.60, 0.98), (0.53, 0.98), (0.515, 0.91), (0.515, 0.78)],
      6, closed=True, bev=0.012)

# --- feet on each face
for k in range(6):
    ang = 30 + 60 * k
    box("Body_Coral", "coral", radial(ang, 0.48, 0.035), (0.26, 0.34, 0.07), ang, bev=0.02)
    box("Body_Teal", "teal", radial(ang, 0.435, 0.135), (0.18, 0.24, 0.13), ang, bev=0.015)
    box("Body_Dark", "dark", radial(ang, 0.525, 0.135), (0.02, 0.12, 0.045), ang, bev=0.004)
    if ang != 90:
        box("Body_Coral", "coral", radial(ang, body_ap(0.28) + 0.012, 0.28), (0.05, 0.26, 0.07), ang, bev=0.02)

# --- side port bosses on the two front flanks
PORT_COR = [(0.10, -0.03), (0.18, -0.03), (0.185, 0.02), (0.165, 0.045), (0.10, 0.045)]
PORT_BRS = [(0.06, 0.02), (0.112, 0.02), (0.122, 0.05), (0.108, 0.082), (0.06, 0.082)]
PORT_ORG = [(0, 0.03), (0.062, 0.03), (0.062, 0.058), (0.04, 0.072), (0, 0.075)]
PZ = 0.56
for ang in (30, 150):
    d = radial(ang, 1, 0)
    c = radial(ang, body_ap(PZ) - 0.005, PZ)
    lathe("Body_Coral", "coral", PORT_COR, 24, pos=c, direction=d, closed=True)
    lathe("Body_Brass", "brass", PORT_BRS, 24, pos=c, direction=d, closed=True)
    lathe("Body_Orange", "orange", PORT_ORG, 24, pos=c, direction=d)

# --- three stub pipes with brass flanges (back-left, back-right, rear)
for ang in (210, 270, 330):
    d = radial(ang, 1, 0)
    ap = body_ap(0.58)
    c = radial(ang, ap, 0.58)
    ext = 0.07 if ang == 270 else 0.0
    lathe("Body_Dark", "dark", [(0.0, -0.04), (0.105, -0.04), (0.105, 0.20 + ext), (0, 0.20 + ext)], 16, pos=c,
          direction=d)
    lathe("Body_Brass", "brass", [(0.08, 0.15 + ext), (0.15, 0.15 + ext), (0.155, 0.18 + ext), (0.145, 0.21 + ext),
                                 (0.08, 0.21 + ext)], 20, pos=c, direction=d, closed=True)
    lathe("Body_Coral", "coral", [(0.11, 0.04), (0.145, 0.04), (0.145, 0.075), (0.11, 0.075)], 20,
          pos=c, direction=d, closed=True)

# ================================================================ AIM: HOPPER
lathe("Hopper_Teal", "teal",
      [(0, HOP_Z0), (0.38, HOP_Z0), (0.575, 1.46), (0.595, 1.48), (0.595, 1.52), (0.46, 1.52), (0.43, 1.49),
       (0.40, 1.34), (0.40, 1.26), (0, 1.26)], 8, rot=22.5, bev=0.014, is_aim=True)
lathe("Hopper_Coral", "coral", [(0, 1.30), (0.40, 1.30), (0.40, 1.34), (0, 1.34)], 8, rot=22.5, is_aim=True)

# --- mines in the hopper, spiked with brass studs
mine_r = 0.125
mine_pos = [(0.0, 0.21), (0.0, -0.21), (0.23, 0.0), (-0.23, 0.0)]
for mi, (mx, my) in enumerate(mine_pos):
    c = Vector((mx, my, 1.46))
    lathe("Mines_Cream", "cream", sphere_profile(mine_r, 8), 16, pos=c, is_aim=True)
    studs = [(0, 90)]
    studs += [(72 * i + 20 * mi, 48) for i in range(5)]
    studs += [(72 * i + 36 + 20 * mi, 12) for i in range(5)]
    for az, el in studs:
        e, a = math.radians(el), math.radians(az)
        dvec = Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e)))
        ball("Hopper_Brass", "brass", c + dvec * (mine_r + 0.005), 0.022, 6, 3, is_aim=True)

# --- hopper ports (45 / 135 deg faces), front stud, rim nubs
HP_BRS = [(0.062, 0.0), (0.118, 0.0), (0.124, 0.03), (0.11, 0.064), (0.062, 0.064)]
HP_ORG = [(0, 0.012), (0.063, 0.012), (0.063, 0.04), (0.04, 0.054), (0, 0.057)]
for ang in (45, 135):
    z = 1.12
    ap = hop_ap(z)
    d = Vector((math.cos(math.radians(ang)) * 0.961, math.sin(math.radians(ang)) * 0.961, -0.276))
    c = radial(ang, ap, z) - d * 0.012
    lathe("Hopper_Brass", "brass", HP_BRS, 24, pos=c, direction=d, closed=True, is_aim=True)
    lathe("Hopper_Orange", "orange", HP_ORG, 24, pos=c, direction=d, is_aim=True)
ball("Hopper_Brass", "brass", radial(90, hop_ap(1.30) + 0.006, 1.30), 0.048, 12, 6, is_aim=True)
for sx in (-1, 1):
    ball("Hopper_Brass", "brass", Vector((sx * 0.56, 0, 1.44)), 0.046, 12, 6, is_aim=True)

# ================================================================ AIM: BARREL (axis +Y at z = 0.50)
BZ = 0.50
BYS = -0.045  # barrel shift so the overall bounds stay centred on the origin
BP = Vector((0, BYS, BZ))
BD = (0, 1, 0)
# local z maps to world +Y offset, so profile heights are world Y positions
lathe("Barrel_Teal", "teal", [(0.12, 0.20), (0.18, 0.20), (0.18, 0.74), (0.12, 0.74)], 28, pos=BP, direction=BD,
      closed=True, is_aim=True)
lathe("Barrel_Coral", "coral",
      [(0.12, 0.72), (0.205, 0.72), (0.225, 0.745), (0.225, 0.89), (0.205, 0.915), (0.12, 0.915)], 32, pos=BP,
      direction=BD, closed=True, is_aim=True)
for i in range(6):
    a = math.radians(30 + 60 * i)
    c = BP + Vector((0.225 * math.cos(a), 0.82, 0.225 * math.sin(a)))
    ball("Barrel_Brass", "brass", c, 0.03, 8, 4, is_aim=True)
lathe("Barrel_Brass", "brass",
      [(0.105, 0.895), (0.19, 0.895), (0.205, 0.925), (0.19, 0.955), (0.105, 0.955)], 32, pos=BP, direction=BD,
      closed=True, is_aim=True)
lathe("Barrel_Brass", "brass", [(0.105, 0.66), (0.12, 0.66), (0.12, 0.955), (0.105, 0.955)], 28, pos=BP,
      direction=BD, closed=True, is_aim=True)
fy = body_ap(BZ) - 0.04 - BYS
lathe("Barrel_Brass", "brass",
      [(0.18, fy), (0.245, fy), (0.27, fy + 0.025), (0.27, fy + 0.075), (0.245, fy + 0.10), (0.18, fy + 0.10)], 32,
      pos=BP, direction=BD, closed=True, is_aim=True)
lathe("Barrel_Dark", "dark", [(0, 0.64), (0.12, 0.64), (0.12, 0.66), (0, 0.66)], 24, pos=BP, direction=BD,
      is_aim=True)

# ================================================================ SPIKED MINE DISH (static prop)
DC = Vector((-0.60, 0.60, 0))
lathe("Dish_Brass", "brass",
      [(0, 0.0), (0.12, 0.0), (0.17, 0.03), (0.25, 0.05), (0.262, 0.09), (0.235, 0.118), (0.168, 0.105),
       (0.152, 0.075), (0, 0.065)], 28, pos=DC)
dome_c = DC + Vector((0, 0, 0.17))
lathe("Dish_Mint", "mint", sphere_profile(0.17, 7, 15, 90), 20, pos=dome_c)
lathe("Dish_Lilac", "lilac", sphere_profile(0.17, 3, -35, 15), 20, pos=dome_c)
for az, el in [(0, 90)] + [(72 * i + 15, 42) for i in range(5)]:
    e, a = math.radians(el), math.radians(az)
    dvec = Vector((math.cos(e) * math.cos(a), math.cos(e) * math.sin(a), math.sin(e)))
    ball("Dish_Brass", "brass", dome_c + dvec * 0.175, 0.025, 8, 4)

# ================================================================ finalize meshes
for name, (bm, matkey, is_aim) in groups.items():
    # smooth shading with hard edges above the angle limit
    for e in bm.edges:
        if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > SHARP:
            e.smooth = False
    for f in bm.faces:
        f.smooth = True
    if is_aim:
        bmesh.ops.translate(bm, verts=bm.verts, vec=-AIM_POS)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(M[matkey])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = aim if is_aim else base

muzzle = bpy.data.objects.new("Muzzle", None)
bpy.context.collection.objects.link(muzzle)
muzzle.parent = aim
muzzle.location = Vector((0, 0.955 + BYS, BZ)) - AIM_POS

# ================================================================ export
bpy.ops.export_scene.gltf(
    filepath=str(OUT / "cp_mine_layer.glb"),
    export_format="GLB",
    export_yup=True,
    export_animations=False,
    export_cameras=False,
    export_lights=False,
)
print("exported", OUT / "cp_mine_layer.glb")

"""Clockwork Thunder Spear (Shock/Lance level-15 capstone turret).

Run: blender --background --python build_cp_thunder_spear.py
Builds from scratch with bmesh, generates a shared 4-image texture atlas in numpy (base colour, ORM, normal,
emission), UV-maps every part into its material tile, bakes a light vertex-colour AO and exports a GLB.
Blender +Z up, weapon faces +Y. Aim (rotating head) carries box + lance; Muzzle at the spear tip.
"""
import math
import random
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Vector
from mathutils.bvhtree import BVHTree

HERE = Path(__file__).resolve().parent
TEX_DIR = HERE / "textures"
TEX_DIR.mkdir(exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)

SHARP = math.radians(35)
ATLAS = 1024
GRID = 4
TILE = ATLAS // GRID
MARGIN = 10
rng_np = np.random.default_rng(15)

# ---------------------------------------------------------------- palette / tiles
# name: (tile index, sRGB colour, roughness, metallic)
SURFACES = {
    "Teal":   (0, (0.12, 0.56, 0.53), 0.32, 0.08),
    "Coral":  (1, (0.93, 0.35, 0.29), 0.42, 0.0),
    "Brass":  (2, (0.98, 0.75, 0.28), 0.17, 0.88),
    "Ivory":  (3, (0.96, 0.89, 0.72), 0.26, 0.0),
    "Cream":  (4, (0.96, 0.89, 0.75), 0.32, 0.0),
    "JewelMint":   (5, (0.12, 0.86, 0.70), 0.05, 0.0),
    "JewelViolet": (6, (0.52, 0.18, 0.86), 0.05, 0.0),
    "Dark":   (7, (0.20, 0.15, 0.24), 0.55, 0.15),
    "Steel":  (8, (0.80, 0.80, 0.78), 0.28, 0.95),
    "TealDeep": (9, (0.07, 0.36, 0.36), 0.40, 0.08),
}


def tile_origin(index):
    col, row = index % GRID, index // GRID
    return col * TILE, row * TILE


def fbm(size, octaves=4, seed=0):
    r = np.random.default_rng(seed)
    out = np.zeros((size, size))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        cells = 4 * 2 ** o
        g = r.random((cells + 1, cells + 1))
        y = np.linspace(0, cells, size, endpoint=False)
        i = y.astype(int)
        f = y - i
        f = f * f * (3 - 2 * f)
        a = g[i][:, i] * (1 - f)[None, :] + g[i][:, i + 1] * f[None, :]
        b = g[i + 1][:, i] * (1 - f)[None, :] + g[i + 1][:, i + 1] * f[None, :]
        out += amp * (a * (1 - f)[:, None] + b * f[:, None])
        total += amp
        amp *= 0.5
    return out / total


def build_atlas():
    base = np.zeros((ATLAS, ATLAS, 4), np.float32)
    base[..., 3] = 1
    orm = np.zeros((ATLAS, ATLAS, 4), np.float32)
    orm[..., 0] = 1
    orm[..., 3] = 1
    height = np.zeros((ATLAS, ATLAS), np.float32)
    emit = np.zeros((ATLAS, ATLAS, 4), np.float32)
    emit[..., 3] = 1
    yy, xx = np.mgrid[0:TILE, 0:TILE] / (TILE - 1)
    for name, (index, colour, rough, metal) in SURFACES.items():
        x0, y0 = tile_origin(index)
        col = np.array(colour)[None, None, :] * np.ones((TILE, TILE, 1))
        r = np.full((TILE, TILE), rough)
        h = np.zeros((TILE, TILE))
        e = np.zeros((TILE, TILE, 3))
        soft = fbm(TILE, 4, index) - 0.5
        fine = rng_np.random((TILE, TILE)) - 0.5
        if name in ("Teal", "TealDeep"):
            # Satin paint: gentle cloudy value shift + faint orange peel, roughness breathes a little.
            col *= (1 + 0.06 * soft + 0.012 * fine)[..., None]
            r += 0.05 * soft
            h = 0.25 * fbm(TILE, 3, 40 + index)
        elif name in ("Coral", "Cream"):
            col *= (1 + 0.05 * soft + 0.01 * fine)[..., None]
            r += 0.06 * soft
            h = 0.2 * fbm(TILE, 3, 50 + index)
        elif name in ("Brass", "Steel"):
            # Brushed/polished metal: streaks along u, a couple of bright polish bands.
            streak = rng_np.random(TILE)[None, :] * np.ones((TILE, 1))
            streak = np.convolve(streak[0], np.ones(5) / 5, "same")[None, :] * np.ones((TILE, 1))
            band = np.exp(-((yy - 0.3) / 0.08) ** 2) * 0.10 + np.exp(-((yy - 0.72) / 0.05) ** 2) * 0.06
            col *= (0.95 + 0.08 * (streak.T - 0.5) + band + 0.03 * soft)[..., None]
            r += 0.08 * (streak.T - 0.5) + 0.04 * soft
            h = 0.6 * streak.T
        elif name == "Ivory":
            # Glazed ceramic: subtle warm-to-white gradient, very clean.
            col *= (1 + 0.04 * soft)[..., None]
            col[..., 2] *= 0.98 + 0.04 * yy
            r += 0.04 * soft
        elif name.startswith("Jewel"):
            # Faceted gem look: radial core glow, darker rim, crisp specular dot.
            d = np.hypot(xx - 0.5, yy - 0.5) / 0.5
            core = np.clip(1.15 - d, 0, 1) ** 1.1
            rim = np.clip((d - 0.75) / 0.25, 0, 1)
            light = np.array(colour) * 1.15 + 0.1
            dark = np.array(colour) * 0.55
            col = dark[None, None] * (1 - core[..., None]) + np.clip(light, 0, 1)[None, None] * core[..., None]
            col *= (1 - 0.35 * rim)[..., None]
            spec = np.exp(-(np.hypot(xx - 0.36, yy - 0.64) / 0.07) ** 2)
            col = col * (1 - spec[..., None]) + spec[..., None]
            facets = (np.floor(np.arctan2(yy - 0.5, xx - 0.5) / (math.tau / 8)) % 2) * 0.06
            col *= (1 - facets * (d > 0.35))[..., None]
            e = np.array(colour)[None, None] * (0.06 + 0.22 * core[..., None])
        elif name == "Dark":
            col *= (1 + 0.08 * soft)[..., None]
        base[y0:y0 + TILE, x0:x0 + TILE, :3] = np.clip(col, 0, 1)
        orm[y0:y0 + TILE, x0:x0 + TILE, 1] = np.clip(r, 0.03, 1)
        orm[y0:y0 + TILE, x0:x0 + TILE, 2] = metal
        height[y0:y0 + TILE, x0:x0 + TILE] = h
        emit[y0:y0 + TILE, x0:x0 + TILE, :3] = np.clip(e, 0, 1)
    gy, gx = np.gradient(height)
    strength = 1.2
    n = np.stack([-gx * strength, -gy * strength, np.ones_like(height)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    normal = np.concatenate([n * 0.5 + 0.5, np.ones((ATLAS, ATLAS, 1))], -1).astype(np.float32)
    return base, orm, normal, emit


def save_image(name, pixels, colour):
    img = bpy.data.images.new(name, ATLAS, ATLAS, alpha=False)
    img.colorspace_settings.name = "sRGB" if colour else "Non-Color"
    img.pixels.foreach_set(pixels.ravel())
    img.filepath_raw = str(TEX_DIR / f"{name}.png")
    img.file_format = "PNG"
    img.save()
    img.reload()
    return img


base_px, orm_px, normal_px, emit_px = build_atlas()
IMG_BASE = save_image("thunder_spear_basecolor", base_px, True)
IMG_ORM = save_image("thunder_spear_orm", orm_px, False)
IMG_NORMAL = save_image("thunder_spear_normal", normal_px, False)
IMG_EMIT = save_image("thunder_spear_emission", emit_px, True)


def make_material(name):
    index, colour, rough, metal = SURFACES[name]
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*colour, 1)
    mat.use_nodes = True
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    bsdf = nodes.get("Principled BSDF")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = IMG_BASE
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    orm = nodes.new("ShaderNodeTexImage")
    orm.image = IMG_ORM
    sep = nodes.new("ShaderNodeSeparateColor")
    links.new(orm.outputs["Color"], sep.inputs["Color"])
    links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    nrm = nodes.new("ShaderNodeTexImage")
    nrm.image = IMG_NORMAL
    nmap = nodes.new("ShaderNodeNormalMap")
    nmap.inputs["Strength"].default_value = 0.6
    links.new(nrm.outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    em = nodes.new("ShaderNodeTexImage")
    em.image = IMG_EMIT
    links.new(em.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.0
    if name.startswith("Jewel"):
        bsdf.inputs["Coat Weight"].default_value = 1.0
        bsdf.inputs["Coat Roughness"].default_value = 0.03
    if name == "Ivory":
        bsdf.inputs["Coat Weight"].default_value = 0.3
        bsdf.inputs["Coat Roughness"].default_value = 0.08
    return mat


MATS = {name: make_material(name) for name in SURFACES}

# ---------------------------------------------------------------- geometry helpers
PARTS = []  # (obj, surface, mapping)


def bevel_sharp(bm, width, segments=3, angle=SHARP):
    bm.normal_update()
    edges = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > angle]
    if edges and width > 0:
        bmesh.ops.bevel(bm, geom=edges, offset=width, offset_type="OFFSET", segments=segments, profile=0.5,
                        affect="EDGES", clamp_overlap=True)


def lathe(n, r_bottom, r_top, h, offset=0.0):
    """n-sided frustum along Z centred on origin; r_top may be 0 for a cone apex."""
    bm = bmesh.new()
    bottom, top = [], []
    for i in range(n):
        a = offset + math.tau * i / n
        bottom.append(bm.verts.new((r_bottom * math.cos(a), r_bottom * math.sin(a), -h / 2)))
        if r_top > 0:
            top.append(bm.verts.new((r_top * math.cos(a), r_top * math.sin(a), h / 2)))
    bm.faces.new(list(reversed(bottom)))
    if r_top > 0:
        bm.faces.new(top)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((bottom[i], bottom[j], top[j], top[i]))
    else:
        apex = bm.verts.new((0, 0, h / 2))
        for i in range(n):
            bm.faces.new((bottom[i], bottom[(i + 1) % n], apex))
    return bm


def torus_bm(major, minor, seg=48, ring=16):
    bm = bmesh.new()
    grid = []
    for i in range(seg):
        a = math.tau * i / seg
        row = []
        for j in range(ring):
            b = math.tau * j / ring
            rr = major + minor * math.cos(b)
            row.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), minor * math.sin(b))))
        grid.append(row)
    for i in range(seg):
        for j in range(ring):
            i2, j2 = (i + 1) % seg, (j + 1) % ring
            bm.faces.new((grid[i][j], grid[i2][j], grid[i2][j2], grid[i][j2]))
    return bm


def box_bm(size):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    return bm


def sphere_bm(radius, scale=(1, 1, 1), seg=32, rings=16):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=radius)
    for v in bm.verts:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]))
    return bm


def orient(direction):
    return Vector((0, 0, 1)).rotation_difference(Vector(direction).normalized()).to_euler()


def make(name, bm, surface, pos, parent=None, rot=(0, 0, 0), mapping="box", smooth_all=False):
    bm.normal_update()
    for f in bm.faces:
        f.smooth = True
    if not smooth_all:
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > SHARP:
                e.smooth = False
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(MATS[surface])
    obj.rotation_euler = rot if isinstance(rot, Euler) else Euler(rot)
    if parent is not None:
        obj.parent = parent
        obj.location = Vector(pos) - parent.location
    else:
        obj.location = pos
    project_uvs(obj, mapping)
    PARTS.append((obj, surface, mapping))
    return obj


def project_uvs(obj, mapping):
    """Raw UVs in metres (fitted into the atlas tile later)."""
    mesh = obj.data
    layer = mesh.uv_layers.new(name="UVMap")
    for poly in mesh.polygons:
        nrm = poly.normal
        axis = max(range(3), key=lambda i: abs(nrm[i]))
        angles = []
        for li in poly.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            if mapping == "planar":
                u, v = co.x, co.y
            elif mapping == "cyl" and axis != 2:
                ang = math.atan2(co.y, co.x)
                if angles:
                    ang += math.tau * round((angles[0] - ang) / math.tau)
                angles.append(ang)
                u, v = ang * max(math.hypot(co.x, co.y), 0.02), co.z
            elif axis == 0:
                u, v = co.y, co.z
            elif axis == 1:
                u, v = co.x, co.z
            else:
                u, v = co.x, co.y
            layer.data[li].uv = (u, v)


def fit_uvs():
    """Per surface: one uniform texel density (largest part fits the tile), each part placed at the tile origin.
    Jewels are centred so the radial gem gradient sits under the dome."""
    extents = {}
    for obj, surface, mapping in PARTS:
        uv = np.array([d.uv[:] for d in obj.data.uv_layers[0].data])
        ext = (uv.max(0) - uv.min(0)).max()
        extents.setdefault(surface, []).append(ext)
    inner = (TILE - 2 * MARGIN) / ATLAS
    for obj, surface, mapping in PARTS:
        layer = obj.data.uv_layers[0]
        uv = np.array([d.uv[:] for d in layer.data])
        lo = uv.min(0)
        index = SURFACES[surface][0]
        x0, y0 = tile_origin(index)
        if surface.startswith("Jewel"):
            ext = max((uv.max(0) - lo).max(), 1e-6)
            centre = (uv.max(0) + lo) / 2
            uv = (uv - centre) / ext * inner + np.array([(x0 + TILE / 2) / ATLAS, (y0 + TILE / 2) / ATLAS])
        else:
            scale = inner / max(max(extents[surface]), 1e-6)
            uv = (uv - lo) * scale + np.array([(x0 + MARGIN) / ATLAS, (y0 + MARGIN) / ATLAS])
        for d, value in zip(layer.data, uv):
            d.uv = value


def empty(name, pos, parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.empty_display_size = 0.1
    if parent is not None:
        obj.parent = parent
        obj.location = Vector(pos) - parent.location
    else:
        obj.location = pos
    return obj


def cyl(name, surface, pos, radius, depth, parent=None, direction=(0, 0, 1), n=24, bevel=None, segs=2, top=None):
    bm = lathe(n, radius, radius if top is None else top, depth)
    bevel_sharp(bm, min(radius * 0.3, depth * 0.3) if bevel is None else bevel, segs)
    return make(name, bm, surface, pos, parent, orient(direction), "cyl")


def rbox(name, surface, pos, size, parent=None, bevel=0.02, segs=2, rot=(0, 0, 0)):
    bm = box_bm(size)
    bevel_sharp(bm, bevel, segs)
    return make(name, bm, surface, pos, parent, rot, "box")


def jewel(name, surface, pos, radius, direction, parent=None, depth_scale=0.7, bezel_surface="Brass",
          bezel_major=None, bezel_minor=None):
    d = Vector(direction).normalized()
    rot = orient(d)
    make(name, sphere_bm(radius, (1, 1, depth_scale), 16, 8), surface, pos, parent, rot, "planar", smooth_all=True)
    major = bezel_major or radius * 1.12
    minor = bezel_minor or radius * 0.28
    make(name + "_Bezel", torus_bm(major, minor, 20, 6), bezel_surface, Vector(pos) + d * radius * 0.05,
         parent, rot, "cyl", smooth_all=True)


def rivets(name, positions, normals, parent=None, radius=0.011, surface="Steel"):
    """Many small domed rivets merged into a single mesh object."""
    bm = bmesh.new()
    origin = parent.location if parent is not None else Vector()
    for p, nrm in zip(positions, normals):
        tmp = sphere_bm(radius, (1, 1, 0.55), 6, 3)
        q = Vector((0, 0, 1)).rotation_difference(Vector(nrm).normalized())
        for v in tmp.verts:
            v.co = q @ v.co + Vector(p) - origin
        mesh = bpy.data.meshes.new("tmp")
        tmp.to_mesh(mesh)
        tmp.free()
        bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)
    obj = make(name, bm, surface, origin if parent is None else parent.location, parent, (0, 0, 0), "box",
               smooth_all=True)
    return obj


# ---------------------------------------------------------------- static base
HEX_OFF = math.radians(30)  # vertices at 30, 90, ... so flat faces look at 0, 60, 120 ... degrees
P_Z0, P_Z1 = 0.065, 0.40
P_R0, P_R1 = 0.235, 0.172

for k, ang in enumerate((90, 210, 330)):
    a = math.radians(ang)
    fx, fy = 0.285 * math.cos(a), 0.285 * math.sin(a)
    cyl(f"Foot_{k}_Rim", "Brass", (fx, fy, 0.022), 0.098, 0.044, bevel=0.012)
    cyl(f"Foot_{k}_Pad", "Coral", (fx, fy, 0.066), 0.078, 0.06, bevel=0.022, top=0.07)
    rivets(f"Foot_{k}_Rivets",
           [(fx + 0.088 * math.cos(math.radians(t)), fy + 0.088 * math.sin(math.radians(t)), 0.044)
            for t in range(0, 360, 60)], [(0, 0, 1)] * 6, radius=0.008)
    # strut from foot into pedestal
    s = rbox(f"Foot_{k}_Strut", "TealDeep", (0.19 * math.cos(a), 0.19 * math.sin(a), 0.05),
             (0.13, 0.07, 0.05), bevel=0.015, rot=(0, 0, a))

cyl("Pedestal_BaseTrim", "Brass", (0, 0, 0.068), 0.252, 0.05, n=6, bevel=0.012).rotation_euler.z = HEX_OFF
bm = lathe(6, P_R0, P_R1, P_Z1 - P_Z0, HEX_OFF)
bevel_sharp(bm, 0.018, 3)
make("Pedestal_Body", bm, "Teal", (0, 0, (P_Z0 + P_Z1) / 2), mapping="box")
cyl("Pedestal_TopPlate", "Brass", (0, 0, 0.425), 0.215, 0.05, n=6, bevel=0.014).rotation_euler.z = HEX_OFF
cyl("Pedestal_TopCap", "TealDeep", (0, 0, 0.455), 0.15, 0.02, n=24, bevel=0.006)
rivets("Pedestal_Rivets",
       [(0.19 * math.cos(math.radians(30 + 60 * i)), 0.19 * math.sin(math.radians(30 + 60 * i)), 0.45)
        for i in range(6)], [(0, 0, 1)] * 6, radius=0.012)

tilt = math.atan2((P_R0 - P_R1) * math.cos(math.radians(30)), P_Z1 - P_Z0)


def face_point(theta_deg, z, out=0.0):
    t = (z - P_Z0) / (P_Z1 - P_Z0)
    apothem = (P_R0 + (P_R1 - P_R0) * t) * math.cos(math.radians(30))
    th = math.radians(theta_deg)
    nrm = Vector((math.cos(th) * math.cos(tilt), math.sin(th) * math.cos(tilt), math.sin(tilt)))
    return Vector((apothem * math.cos(th), apothem * math.sin(th), z)) + nrm * out, nrm


p, nrm = face_point(60, 0.23, 0.012)
jewel("Pedestal_Jewel", "JewelMint", p + nrm * 0.008, 0.05, nrm, bezel_major=0.058, bezel_minor=0.016)
p, nrm = face_point(120, 0.23, 0.0)
make("Pedestal_ButtonRim", lathe(20, 0.058, 0.058, 0.03), "Cream", p + nrm * 0.006, None, orient(nrm), "cyl")
bm = lathe(20, 0.045, 0.04, 0.03)
bevel_sharp(bm, 0.012, 2)
make("Pedestal_Button", bm, "Cream", p + nrm * 0.022, None, orient(nrm), "cyl")
for th in (0, 180, 240, 300):
    p, nrm = face_point(th, 0.23, 0.004)
    rbox(f"Pedestal_Vent_{th}", "TealDeep", p, (0.012, 0.11, 0.17), bevel=0.005,
         rot=(0, -tilt, math.radians(th)))
cyl("Swivel_Lower", "Coral", (0, 0, 0.485), 0.135, 0.05, bevel=0.016)
cyl("Swivel_Gap", "Dark", (0, 0, 0.515), 0.105, 0.03, bevel=0.004)

# ---------------------------------------------------------------- Aim (rotating head)
AIM_Z = 0.50
aim = empty("Aim", (0, 0, AIM_Z))
LZ = 0.80  # lance axis height
BOX_C = Vector((0, -0.02, 0.828))
BOX_S = (0.42, 0.40, 0.36)
BT = BOX_C.z + BOX_S[2] / 2   # box top
BB = BOX_C.y - BOX_S[1] / 2   # box back
BF = BOX_C.y + BOX_S[1] / 2   # box front
FWD = (0, 1, 0)

cyl("Swivel_Upper", "Coral", (0, 0, 0.555), 0.125, 0.06, aim, bevel=0.018)
cyl("Swivel_UpperRing", "Brass", (0, 0, 0.59), 0.11, 0.018, aim, bevel=0.005)
cyl("Neck", "Dark", (0, 0, 0.625), 0.075, 0.07, aim, bevel=0.01)
cyl("Neck_Knob", "Coral", (0.1, 0.0, 0.565), 0.042, 0.06, aim, direction=(1, 0, 0), bevel=0.014)

rbox("Box_Body", "Teal", BOX_C, BOX_S, aim, bevel=0.038, segs=3)
# brass strap wrapping the rear of the box
rbox("Box_Strap", "Brass", (0, BB + 0.035, BOX_C.z), (BOX_S[0] + 0.014, 0.034, BOX_S[2] + 0.014), aim, bevel=0.014)
# top coral plates
rbox("Box_TopPlateFront", "Coral", (0, 0.075, BT + 0.012), (0.30, 0.19, 0.055), aim, bevel=0.018)
rbox("Box_FrontLip", "Coral", (0, BF + 0.004, BT - 0.03), (0.30, 0.03, 0.085), aim, bevel=0.012)
rbox("Box_TopPlateRear", "Coral", (0.0, -0.115, BT + 0.006), (0.2, 0.085, 0.045), aim, bevel=0.013)
cyl("Box_TopKnob", "Teal", (0.0, -0.115, BT + 0.035), 0.026, 0.03, aim, bevel=0.009)
cyl("Box_DomeSeat", "Brass", (0, 0.075, BT + 0.045), 0.078, 0.024, aim, bevel=0.008)
make("Box_DomeJewel", sphere_bm(0.066, (1, 1, 0.95), 24, 10), "JewelMint", (0, 0.075, BT + 0.05), aim, (0, 0, 0), "planar",
     smooth_all=True)
make("Box_DomeBezel", torus_bm(0.071, 0.014, 28, 6), "Brass", (0, 0.075, BT + 0.056), aim, (0, 0, 0), "cyl",
     smooth_all=True)
rivets("Box_TopRivets", [(sx * 0.13, y, BT + 0.04) for sx in (1, -1) for y in (0.0, 0.15)],
       [(0, 0, 1)] * 4, aim, radius=0.009)
# side jewels (violet) with coral bezels on both cheeks
for sx in (1, -1):
    side = "R" if sx > 0 else "L"
    px = sx * (BOX_S[0] / 2 + 0.004)
    cyl(f"Box_JewelPlate_{side}", "Coral", (px, -0.005, BOX_C.z), 0.072, 0.022, aim, direction=(sx, 0, 0),
        bevel=0.008)
    jewel(f"Box_Jewel_{side}", "JewelViolet", (px + sx * 0.013, -0.005, BOX_C.z), 0.05, (sx, 0, 0), aim,
          bezel_surface="Coral", bezel_major=0.058, bezel_minor=0.015)
    rivets(f"Box_Rivets_{side}",
           [(px, y, z) for y in (-0.15, 0.145) for z in (BOX_C.z - 0.14, BOX_C.z + 0.14)], [(sx, 0, 0)] * 4, aim)
# rear coil housing + big brass ring
RZ = LZ + 0.015
cyl("Rear_Housing", "Teal", (0, BB - 0.035, RZ), 0.172, 0.09, aim, direction=(0, -1, 0), bevel=0.02)
cyl("Rear_Ring", "Brass", (0, BB - 0.06, RZ), 0.212, 0.06, aim, direction=(0, -1, 0), bevel=0.018, n=36)
cyl("Rear_Cap", "TealDeep", (0, BB - 0.095, RZ), 0.155, 0.022, aim, direction=(0, -1, 0), bevel=0.007)
cyl("Rear_Hub", "Coral", (0, BB - 0.11, RZ), 0.05, 0.022, aim, direction=(0, -1, 0), bevel=0.008)
for i, dz in enumerate((-0.085, -0.045, 0.045, 0.085)):
    w = math.sqrt(max(0.14 ** 2 - dz ** 2, 0)) * 1.4
    rbox(f"Rear_Vent_{i}", "Dark", (0, BB - 0.106, RZ + dz), (w, 0.012, 0.017), aim, bevel=0.005)
for sx in (1, -1):
    rbox(f"Rear_Clamp_{'R' if sx > 0 else 'L'}", "Coral", (sx * 0.135, BB - 0.06, RZ - 0.16), (0.075, 0.075, 0.06),
         aim, bevel=0.018, rot=(0, sx * math.radians(40), 0))
rivets("Rear_Rivets", [(0.18 * math.cos(math.radians(a)), BB - 0.091, RZ + 0.18 * math.sin(math.radians(a)))
                       for a in range(0, 360, 45)], [(0, -1, 0)] * 8, aim, radius=0.01)
# front collar (double brass ring with dark coil gap)
cyl("Collar_Outer", "Brass", (0, BF + 0.02, LZ), 0.172, 0.06, aim, direction=FWD, bevel=0.019, n=36)
cyl("Collar_Gap", "Dark", (0, BF + 0.06, LZ), 0.13, 0.04, aim, direction=FWD, bevel=0.006, segs=1)
cyl("Collar_Inner", "Brass", (0, BF + 0.095, LZ), 0.142, 0.045, aim, direction=FWD, bevel=0.016, n=36)
cyl("Collar_Throat", "Dark", (0, BF + 0.12, LZ), 0.085, 0.02, aim, direction=FWD, bevel=0.004)
# lance shaft
SHAFT_Y0, SHAFT_Y1 = BF + 0.11, 0.80
cyl("Lance_Shaft", "Teal", (0, (SHAFT_Y0 + SHAFT_Y1) / 2, LZ), 0.066, SHAFT_Y1 - SHAFT_Y0, aim, direction=FWD,
    bevel=0.006, n=24, segs=1)
cyl("Lance_RootSleeve", "TealDeep", (0, BF + 0.15, LZ), 0.078, 0.05, aim, direction=FWD, bevel=0.01)
for i, y in enumerate((0.585, 0.66, 0.735)):
    cyl(f"Lance_Coil_{i}", "Brass", (0, y, LZ), 0.102, 0.05, aim, direction=FWD, bevel=0.017, n=28)
    cyl(f"Lance_CoilCore_{i}", "Dark", (0, y + 0.037, LZ), 0.08, 0.026, aim, direction=FWD, bevel=0.004, n=20, segs=1)
# tip collar + side jewels + ivory spear head
cyl("Tip_Collar", "Brass", (0, 0.80, LZ), 0.092, 0.05, aim, direction=FWD, bevel=0.016, n=28)
for sx in (1, -1):
    jewel(f"Tip_Jewel_{'R' if sx > 0 else 'L'}", "JewelMint", (sx * 0.097, 0.803, LZ), 0.026, (sx, 0, 0), aim,
          bezel_major=0.03, bezel_minor=0.008)
TIP_Y0, TIP_L = 0.825, 0.30
bm = lathe(6, 0.135, 0.0, TIP_L, math.radians(90))
bevel_sharp(bm, 0.006, 2, math.radians(25))
make("Tip_Spear", bm, "Ivory", (0, TIP_Y0 + TIP_L / 2, LZ), aim, orient(FWD), "cyl")
bm = lathe(6, 0.105, 0.135, 0.025, math.radians(90))
bevel_sharp(bm, 0.005, 2)
make("Tip_Base", bm, "Ivory", (0, TIP_Y0 - 0.01, LZ), aim, orient(FWD), "cyl")
TIP_Y = TIP_Y0 + TIP_L
muzzle = empty("Muzzle", (0, TIP_Y + 0.005, LZ), aim)


fit_uvs()


def merge_groups():
    """Join parts that share a material and move together: one static object and one Aim object per material."""
    groups = {}
    for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
        owner = "Aim" if obj.parent is not None else "Base"
        groups.setdefault((owner, obj.data.materials[0].name), []).append(obj)
    for (owner, mat_name), objs in groups.items():
        target = objs[0]
        if len(objs) > 1:
            with bpy.context.temp_override(active_object=target, object=target, selected_editable_objects=objs,
                                           selected_objects=objs):
                bpy.ops.object.join()
        target.name = f"{owner}_{mat_name}"
        target.data.name = target.name


merge_groups()

# ---------------------------------------------------------------- vertex-colour AO (light)
AO_SAMPLES, AO_DIST, AO_FLOOR = 20, 0.25, 0.55


def bake_ao(meshes):
    bpy.context.view_layer.update()
    verts, tris = [], []
    for obj in meshes:
        b = len(verts)
        verts.extend(obj.matrix_world @ v.co for v in obj.data.vertices)
        obj.data.calc_loop_triangles()
        tris.extend(tuple(b + i for i in t.vertices) for t in obj.data.loop_triangles)
    tree = BVHTree.FromPolygons(verts, tris)
    rnd = random.Random(7)
    dirs = []
    for _ in range(AO_SAMPLES):
        r1, r2 = rnd.random(), rnd.random()
        rad, ang = math.sqrt(r1), math.tau * r2
        dirs.append((rad * math.cos(ang), rad * math.sin(ang), math.sqrt(1 - r1)))
    for obj in meshes:
        mesh = obj.data
        nm = obj.matrix_world.to_3x3().inverted().transposed()
        col = mesh.color_attributes.new("AO", "BYTE_COLOR", "CORNER")
        cache = {}
        normals = mesh.corner_normals
        for loop in mesh.loops:
            key = (loop.vertex_index, tuple(round(c, 2) for c in normals[loop.index].vector))
            if key not in cache:
                pos = obj.matrix_world @ mesh.vertices[loop.vertex_index].co
                n = (nm @ normals[loop.index].vector).normalized()
                t = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
                bt = n.cross(t)
                o = pos + n * 0.003
                hits = 0.0
                for dx, dy, dz in dirs:
                    h = tree.ray_cast(o, t * dx + bt * dy + n * dz, AO_DIST)
                    if h[0] is not None:
                        hits += 1 - h[3] / AO_DIST
                occ = hits / AO_SAMPLES
                cache[key] = AO_FLOOR + (1 - AO_FLOOR) * (1 - occ) ** 1.5
            v = cache[key]
            col.data[loop.index].color = (v, v, v, 1)
        mesh.color_attributes.active_color = col
        mesh.color_attributes.render_color_index = list(mesh.color_attributes).index(col)


meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
bake_ao(meshes)

tri = 0
for o in meshes:
    o.data.calc_loop_triangles()
    tri += len(o.data.loop_triangles)
print(f"STATS triangles={tri} meshes={len(meshes)} materials={len(MATS)}")

bpy.ops.export_scene.gltf(filepath=str(HERE / "cp_thunder_spear.glb"), export_format="GLB", export_yup=True,
                          export_animations=False, export_cameras=False, export_lights=False,
                          export_vertex_color="ACTIVE")

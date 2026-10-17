"""Clockwork Storm Network (Tesla/Relay level-15 turret) - scripted Blender build with procedural atlas textures.

Run: blender --background --python build_cp_storm_network.py
Writes cp_storm_network.glb beside this script. Metres, +Z up, weapon faces +Y.

Structure
  StormNetwork (root empty)
    Base_Static      clover plate, gold trim, seams, brass-ringed front jewel      (static)
    Aim (empty)      pivot on the turret's vertical axis, identity rotation
      Aim_Tower_A/B/C  complete coil towers (feet, rings, body, springs, jewels, insulator coil, gem)
      Aim_Bridge       toothed brass rod + hubs linking towers A and B
      Muzzle (empty)   tip of tower A's gem (A is the +Y-most tower)

Textures: one 1024 atlas set (albedo, metal/rough, normal, emissive) drawn by numpy; every part is UV-mapped into a
256 px cell of the atlas by angle-around-axis (u) and height (v), so texel density is consistent.
"""
import math
import os
import random
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

OUT = Path(__file__).resolve().parent
TAU = math.tau
SHARP = math.radians(40)

# ---------------------------------------------------------------------------------------------------------------
# Layout (metres)
# ---------------------------------------------------------------------------------------------------------------
TOWER_R = 0.365                       # tower circumradius around the turret axis
TOWERS = {                           # name -> (x, y)
    "A": (TOWER_R * math.cos(math.radians(90)), TOWER_R * math.sin(math.radians(90))),    # front (+Y)
    "B": (TOWER_R * math.cos(math.radians(210)), TOWER_R * math.sin(math.radians(210))),
    "C": (TOWER_R * math.cos(math.radians(330)), TOWER_R * math.sin(math.radians(330))),
}
BASE_Z = 0.17
APOTHEM = 0.152                      # hex body apothem
HEX_ROUND = 1.07                     # corner clip radius / apothem
JEWEL_ANGLES = (90, 210, 330)        # degrees, flats carrying jewel + spring slot
H_MAX = 1.55                         # world height mapped to the atlas v range
GEM_Z = 1.497
GEM_R = 0.080

# ---------------------------------------------------------------------------------------------------------------
# Atlas
# ---------------------------------------------------------------------------------------------------------------
ATLAS = 1024
CELL = 256
PAD = 4
CELLS = {"teal": (0, 0), "teal_dark": (1, 0), "coral": (2, 0), "brass": (3, 0),
         "cream": (0, 1), "gem": (1, 1), "graphite": (2, 1), "pearl": (3, 1),
         "gold": (0, 2), "spring": (1, 2)}


def srgb(r, g, b):
    return np.array((r, g, b), dtype=np.float32) / 255.0


def smooth01(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def brushed(rng, n, width=3):
    """Row-wise noise (constant along u): reads as brushed / machined brass."""
    s = np.convolve(rng.normal(size=n + width * 2), np.ones(width * 2 + 1) / (width * 2 + 1), "valid")[:n]
    return (s / (np.abs(s).max() + 1e-6)).astype(np.float32)


def make_cells():
    rng = np.random.default_rng(15)
    px = np.arange(CELL)
    t = np.clip((px - PAD) / (CELL - 1 - 2 * PAD), 0.0, 1.0).astype(np.float32)
    U, V = np.meshgrid(t, t)          # rows ascend with v (Blender image rows are bottom-up)
    one = np.ones_like(U)
    cells = {}

    def put(name, rgb, rough, metal, height=None, emis=None):
        cells[name] = dict(rgb=rgb.astype(np.float32), rough=(rough * one).astype(np.float32),
                           metal=(metal * one).astype(np.float32),
                           height=(np.zeros_like(U) if height is None else height).astype(np.float32),
                           emis=(np.zeros(U.shape + (3,), np.float32) if emis is None else emis.astype(np.float32)))

    # teal tower body: glossy enamel, faint panel seams at the hex corners
    d = np.abs(((U * 6 + 0.5) % 1.0) - 0.5) / 6.0
    groove = np.exp(-(d / 0.0055) ** 2)
    glow = np.exp(-(d / 0.03) ** 2)
    shade = (0.93 + 0.09 * V)[..., None]
    rgb = srgb(30, 152, 146)[None, None, :] * shade
    rgb = rgb * (1 - 0.20 * groove[..., None]) + 0.035 * glow[..., None]
    put("teal", rgb, 0.27, 0.0, -0.9 * groove)
    # tinted base teal, darker and slightly bluer, with a darkened foot
    shade = (0.74 + 0.26 * smooth01(V / 0.12))[..., None]
    put("teal_dark", srgb(24, 124, 128)[None, None, :] * shade, 0.30, 0.0)
    # coral rings: smooth, saturated enamel
    put("coral", srgb(226, 84, 68)[None, None, :] * (0.92 + 0.10 * V)[..., None], 0.34, 0.0)
    # brass: brushed, slightly warm, metallic
    s = brushed(rng, CELL)[:, None]
    put("brass", srgb(226, 168, 56)[None, None, :] * (1 + 0.06 * s)[..., None], 0.30 + 0.07 * s * one, 0.92, 0.18 * s * one)
    s = brushed(rng, CELL)[:, None]
    put("gold", srgb(242, 182, 60)[None, None, :] * (1 + 0.05 * s)[..., None], 0.22 + 0.06 * s * one, 0.94, 0.14 * s * one)
    s = brushed(rng, CELL, 2)[:, None]
    put("spring", srgb(206, 146, 42)[None, None, :] * (1 + 0.07 * s)[..., None], 0.26 + 0.07 * s * one, 0.93, 0.10 * s * one)
    # cream insulator: soft porcelain, subtle warm gradient
    put("cream", srgb(255, 236, 176)[None, None, :] * (0.93 + 0.09 * V)[..., None], 0.42, 0.0)
    # graphite / dark metal in recesses
    put("graphite", srgb(72, 60, 68)[None, None, :] * (0.9 + 0.1 * V)[..., None], 0.50, 0.15)
    put("pearl", srgb(250, 246, 236)[None, None, :] * one[..., None], 0.20, 0.0)
    # violet gems: deep gradient with per-facet tint blocks (flat-shaded facets pick different blocks)
    block = rng.uniform(-1, 1, size=32).astype(np.float32)
    facet = block[np.minimum((U * 32).astype(int), 31)]
    lo, hi = srgb(78, 10, 150), srgb(128, 52, 222)
    mix = np.clip(0.30 + 0.45 * V + 0.30 * facet, 0, 1)[..., None]
    rgb = (lo[None, None, :] * (1 - mix) + hi[None, None, :] * mix) * (1 + 0.10 * facet)[..., None]
    put("gem", rgb, 0.07, 0.0, None, emis=rgb * 0.22 * (0.4 + 0.8 * V)[..., None])
    return cells


def build_atlas():
    cells = make_cells()
    alb = np.zeros((ATLAS, ATLAS, 4), np.float32)
    alb[..., :3] = 0.5
    alb[..., 3] = 1.0
    mr = np.zeros((ATLAS, ATLAS, 4), np.float32)
    mr[..., 0] = 1.0
    mr[..., 1] = 0.5
    mr[..., 3] = 1.0
    height = np.zeros((ATLAS, ATLAS), np.float32)
    emis = np.zeros((ATLAS, ATLAS, 4), np.float32)
    emis[..., 3] = 1.0
    for name, (cx, cy) in CELLS.items():
        c = cells[name]
        ys, xs = slice(cy * CELL, (cy + 1) * CELL), slice(cx * CELL, (cx + 1) * CELL)
        alb[ys, xs, :3] = np.clip(c["rgb"], 0, 1)
        mr[ys, xs, 1] = np.clip(c["rough"], 0.04, 1)
        mr[ys, xs, 2] = c["metal"]
        height[ys, xs] = c["height"]
        emis[ys, xs, :3] = np.clip(c["emis"], 0, 1)
    gy, gx = np.gradient(height)           # gy is d/dv (rows ascend with v)
    nx, ny, nz = -gx * 1.2, -gy * 1.2, np.ones_like(height)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    normal = np.stack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5, np.ones_like(height)], -1)

    def image(name, data, is_data):
        img = bpy.data.images.new(name, ATLAS, ATLAS, alpha=False, is_data=is_data)
        img.pixels.foreach_set(data.astype(np.float32).ravel())
        try:
            img.pack()
        except Exception:
            pass
        img.update()
        return img

    images = dict(albedo=image("storm_albedo", alb, False), mr=image("storm_metal_rough", mr, True),
                  normal=image("storm_normal", normal, True), emissive=image("storm_emissive", emis, False))
    for key, arr in (("albedo", alb), ("mr", mr), ("normal", normal), ("emissive", emis)):
        try:  # keep a copy next to the script for inspection (the GLB embeds its own)
            tex_dir = OUT / "textures"
            tex_dir.mkdir(exist_ok=True)
            im = images[key].copy()
            im.filepath_raw = str(tex_dir / f"atlas_{key}.png")
            im.file_format = "PNG"
            im.save()
            bpy.data.images.remove(im)
        except Exception:
            pass
    return images


def make_material(images):
    mat = bpy.data.materials.new("Storm_Atlas")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get("Principled BSDF")

    def tex(img, loc):
        n = nodes.new("ShaderNodeTexImage")
        n.image = img
        n.interpolation = "Linear"
        n.extension = "EXTEND"
        n.location = loc
        return n

    albedo = tex(images["albedo"], (-700, 300))
    links.new(albedo.outputs["Color"], bsdf.inputs["Base Color"])
    mr = tex(images["mr"], (-700, 0))
    sep = nodes.new("ShaderNodeSeparateColor")
    sep.location = (-420, 0)
    links.new(mr.outputs["Color"], sep.inputs["Color"])
    links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    nrm = tex(images["normal"], (-700, -300))
    nmap = nodes.new("ShaderNodeNormalMap")
    nmap.location = (-420, -300)
    links.new(nrm.outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    em = tex(images["emissive"], (-700, -600))
    links.new(em.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 1.0
    return mat


# ---------------------------------------------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------------------------------------------
def fillet_path(pts, radii, steps=5, closed=False):
    """Replace corners with quadratic-bezier arcs; radii are tangent lengths (0 keeps a sharp corner)."""
    n = len(pts)
    out = []
    for i in range(n):
        p = np.array(pts[i], float)
        r = radii[i]
        if r <= 0 or (not closed and (i == 0 or i == n - 1)):
            out.append(tuple(p))
            continue
        a = np.array(pts[(i - 1) % n], float)
        b = np.array(pts[(i + 1) % n], float)
        u1, u2 = a - p, b - p
        l1, l2 = np.linalg.norm(u1), np.linalg.norm(u2)
        u1, u2 = u1 / l1, u2 / l2
        t = min(r, l1 * 0.5, l2 * 0.5)
        s0, e0 = p + u1 * t, p + u2 * t
        for k in range(steps + 1):
            s = k / steps
            out.append(tuple((1 - s) ** 2 * s0 + 2 * s * (1 - s) * p + s * s * e0))
    return out


def hex_factor(theta):
    """Rounded-hexagon radius relative to the apothem; flats centred on 30+60k degrees, corners on 60k."""
    phi = (theta % (math.pi / 3)) - math.pi / 6
    hexr = 1.0 / math.cos(phi)
    k = 0.10
    h = max(k - abs(hexr - HEX_ROUND), 0.0) / k
    return min(hexr, HEX_ROUND) - h * h * k / 4.0


def surface_from_rings(bm, rings, closed_profile=False, cap_ends=False):
    """rings: list of lists of 3D points (closed around) or a single point tuple (pole). Outward normals when the
    ring direction x path direction points outward (see notes in revolve)."""
    verts = []
    for ring in rings:
        if isinstance(ring[0], (int, float)):
            verts.append(bm.verts.new(ring))
        else:
            verts.append([bm.verts.new(p) for p in ring])
    faces = []
    count = len(rings) if closed_profile else len(rings) - 1
    for i in range(count):
        a, b = verts[i], verts[(i + 1) % len(rings)]
        a_pole, b_pole = not isinstance(a, list), not isinstance(b, list)
        n = len(b) if not b_pole else len(a)
        for j in range(n):
            j2 = (j + 1) % n
            try:
                if a_pole:
                    f = bm.faces.new((a, b[j2], b[j]))
                elif b_pole:
                    f = bm.faces.new((a[j], a[j2], b))
                else:
                    f = bm.faces.new((a[j], a[j2], b[j2], b[j]))
                faces.append(f)
            except ValueError:
                pass
    if cap_ends:
        for ring in (verts[0], verts[-1]):
            if isinstance(ring, list):
                try:
                    faces.append(bm.faces.new(ring))
                except ValueError:
                    pass
    return faces


def revolve(bm, path, segs, center=(0.0, 0.0), shape=None, closed=False):
    """Lathe a (r, z) path around the vertical axis through `center`. Path runs bottom -> out -> up -> in (outward
    normals). Entries with r == 0 at either end become poles."""
    rings = []
    cx, cy = center
    for i, (r, z) in enumerate(path):
        if r <= 1e-9 and not closed and (i == 0 or i == len(path) - 1):
            rings.append((cx, cy, z))
            continue
        ring = []
        for j in range(segs):
            th = j * TAU / segs
            f = shape(th) if shape else 1.0
            ring.append((cx + r * f * math.cos(th), cy + r * f * math.sin(th), z))
        rings.append(ring)
    return surface_from_rings(bm, rings, closed_profile=closed)


def circle_path(r0, z0, rx, rz, n=12):
    return [(r0 + rx * math.cos(TAU * k / n), z0 + rz * math.sin(TAU * k / n)) for k in range(n)]


def uv_scale(cell, u, v):
    cx, cy = CELLS[cell]
    k = CELL - 1 - 2 * PAD
    return ((cx * CELL + PAD + 0.5 + u * k) / ATLAS, (cy * CELL + PAD + 0.5 + v * k) / ATLAS)


def assign_uv(bm, cell, vrange=(0.0, H_MAX), center=(0.0, 0.0), caps=True):
    """u = angle around the part's axis, v = height; near-horizontal faces take a tiny planar patch so their
    tangent frame stays valid. `cell` is a name or a callable(face) -> name."""
    bm.normal_update()
    layer = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    cx, cy = center
    if vrange is None:
        zs = [v.co.z for v in bm.verts]
        vrange = (min(zs), max(zs) + 1e-6)
    v0, v1 = vrange
    for f in bm.faces:
        name = cell(f) if callable(cell) else cell
        cap = caps and abs(f.normal.z) > 0.75
        facet = name == "gem"
        us, vs, poles = [], [], []
        for lp in f.loops:
            co = lp.vert.co
            vz = (co.z - v0) / (v1 - v0)
            if name == "gem":
                u = (math.floor(((f.index * 0.6180339887) % 1.0) * 32) + 0.5) / 32.0 + (co.x - cx) * 0.06
                vv = vz
                poles.append(False)
            elif cap:
                u = 0.25 + (co.x - cx) * 0.03
                vv = vz + (co.y - cy) * 0.02
                poles.append(False)
            else:
                dx, dy = co.x - cx, co.y - cy
                poles.append(math.hypot(dx, dy) < 1e-7)
                u = (math.atan2(dy, dx) % TAU) / TAU
                if u > 1 - 1e-6:
                    u = 0.0
                vv = vz
            us.append(u)
            vs.append(vv)
        if not cap and not facet:
            good = [u for u, p in zip(us, poles) if not p]
            if good and max(good) - min(good) > 0.5:
                us = [u + 1.0 if (u < 0.25 and not p) else u for u, p in zip(us, poles)]
                good = [u for u, p in zip(us, poles) if not p]
            mean = sum(good) / len(good) if good else 0.5
            us = [mean if p else u for u, p in zip(us, poles)]
            us = [min(max(u, 0.0), 1.0) for u in us]
        for lp, u, vv in zip(f.loops, us, vs):
            lp[layer].uv = uv_scale(name, u, min(max(vv, 0.0), 1.0))


def shade(bm, smooth=True):
    bm.normal_update()
    for f in bm.faces:
        f.smooth = smooth
    if smooth:
        for e in bm.edges:
            if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > SHARP:
                e.smooth = False


class Group:
    def __init__(self):
        self.bm = bmesh.new()
        self.bm.loops.layers.uv.new("UVMap")

    def add(self, part, matrix=None):
        if matrix is not None:
            part.transform(matrix)
        mesh = bpy.data.meshes.new("tmp")
        part.to_mesh(mesh)
        part.free()
        self.bm.from_mesh(mesh)
        bpy.data.meshes.remove(mesh)


def part(group, builder, cell, vrange=(0.0, H_MAX), center=(0.0, 0.0), matrix=None, smooth=True, caps=True):
    bm = bmesh.new()
    builder(bm)
    assign_uv(bm, cell, vrange, center, caps)
    shade(bm, smooth)
    group.add(bm, matrix)


def frame(origin, forward, up=(0, 0, 1)):
    """Matrix whose local +Z -> forward, local +X -> up (for horizontal forward)."""
    z = Vector(forward).normalized()
    x = Vector(up).normalized()
    y = z.cross(x)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = Vector(origin)
    return m


def sphere_path(radius, cz, steps=10):
    return [(radius * math.sin(math.pi * k / steps), cz - radius * math.cos(math.pi * k / steps)) for k in range(steps + 1)]


def icosphere(bm, radius, scale=(1, 1, 1), center=(0, 0, 0), subdiv=2):
    ret = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    for v in ret["verts"]:
        v.co = Vector((v.co.x * scale[0] + center[0], v.co.y * scale[1] + center[1], v.co.z * scale[2] + center[2]))


# ---------------------------------------------------------------------------------------------------------------
# Tower
# ---------------------------------------------------------------------------------------------------------------
def slot_cut(bm, center, z0, z1, angle_deg, half_deg, depth):
    cx, cy = center
    sel = []
    for f in bm.faces:
        c = f.calc_center_median()
        if abs(f.normal.z) < 0.3 and z0 + 1e-4 < c.z < z1 - 1e-4:
            ang = math.degrees(math.atan2(c.y - cy, c.x - cx))
            if abs((ang - angle_deg + 180) % 360 - 180) <= half_deg:
                sel.append(f)
    before = set(bm.faces)
    ret = bmesh.ops.extrude_face_region(bm, geom=sel)
    new_verts = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMVert)]
    new_set = set(new_verts)
    for v in new_verts:
        dx, dy = v.co.x - cx, v.co.y - cy
        d = math.hypot(dx, dy)
        k = (d - depth) / d
        v.co.x, v.co.y = cx + dx * k, cy + dy * k
    floor = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMFace)]
    walls = [f for f in bm.faces if f not in before and f not in set(floor)]
    bmesh.ops.delete(bm, geom=floor + sel, context="FACES_ONLY")
    # orient wall faces toward the window centre
    a = math.radians(angle_deg)
    centre = Vector((cx + math.cos(a) * APOTHEM, cy + math.sin(a) * APOTHEM, (z0 + z1) / 2))
    bm.normal_update()
    flip = [f for f in walls if f.is_valid and f.normal.dot(f.calc_center_median() - centre) > 0]
    if flip:
        bmesh.ops.reverse_faces(bm, faces=flip)


def helix(bm, center, radius, tube, z0, z1, turns, per_turn=28, tube_pts=8):
    cx, cy = center
    n = int(turns * per_turn)
    pitch = (z1 - z0) / turns
    rings = []
    for k in range(n + 1):
        t = TAU * k / per_turn
        c = Vector((cx + radius * math.cos(t), cy + radius * math.sin(t), z0 + pitch * t / TAU))
        tangent = Vector((-radius * math.sin(t), radius * math.cos(t), pitch / TAU)).normalized()
        nrm = Vector((math.cos(t), math.sin(t), 0))
        bino = tangent.cross(nrm).normalized()
        rings.append([tuple(c + tube * (math.cos(TAU * j / tube_pts) * nrm + math.sin(TAU * j / tube_pts) * bino))
                      for j in range(tube_pts)])
    surface_from_rings(bm, rings, cap_ends=True)


def build_tower(name, tx, ty, gems_out):
    g = Group()
    ctr = (tx, ty)
    # --- feet and rings --------------------------------------------------------------------------------------
    foot = fillet_path([(0, BASE_Z), (0.205, BASE_Z), (0.205, 0.29), (0.14, 0.29), (0, 0.29)], [0, 0.02, 0.036, 0, 0])
    part(g, lambda bm: revolve(bm, foot, 72, ctr), "coral", center=ctr)
    neck = [(0, 0.29), (0.135, 0.29), (0.135, 0.385), (0, 0.385)]
    part(g, lambda bm: revolve(bm, neck, 48, ctr), "graphite", center=ctr)
    mid = fillet_path([(0, 0.38), (0.19, 0.38), (0.19, 0.48), (0.15, 0.48), (0, 0.48)], [0, 0.028, 0.032, 0, 0])
    part(g, lambda bm: revolve(bm, mid, 72, ctr), "coral", center=ctr)

    # --- teal rounded-hex body with three spring windows ---------------------------------------------------
    body_path = [(0, 0.48), (APOTHEM, 0.48), (APOTHEM, 0.515), (APOTHEM, 0.725), (APOTHEM, 0.80), (APOTHEM - 0.012, 0.885),
                 (APOTHEM - 0.028, 0.90), (0, 0.90)]

    def body(bm):
        revolve(bm, body_path, 96, ctr, shape=hex_factor)
        for ang in JEWEL_ANGLES:
            slot_cut(bm, ctr, 0.515, 0.725, ang, 21.0, 0.026)
    part(g, body, "teal", center=ctr)
    part(g, lambda bm: revolve(bm, [(0, 0.48), (0.092, 0.48), (0.092, 0.90), (0, 0.90)], 40, ctr), "graphite", center=ctr)
    part(g, lambda bm: helix(bm, ctr, 0.108, 0.0125, 0.50, 0.74, 4.0), "spring", center=ctr)
    # brass band running through the jewels
    band = circle_path(APOTHEM + 0.001, 0.80, 0.011, 0.0085)
    part(g, lambda bm: revolve(bm, band, 96, ctr, shape=hex_factor, closed=True), "gold", center=ctr)
    # --- jewels ---------------------------------------------------------------------------------------------------
    for ang in JEWEL_ANGLES:
        a = math.radians(ang)
        d = Vector((math.cos(a), math.sin(a), 0))
        origin = (tx + d.x * (APOTHEM + 0.004), ty + d.y * (APOTHEM + 0.004), 0.80)
        m = frame(origin, d)
        bezel = circle_path(0.052, 0.002, 0.0125, 0.0115)
        part(g, lambda bm: revolve(bm, bezel, 28, closed=True), "gold", vrange=(-0.012, 0.016), matrix=m)
        part(g, lambda bm: icosphere(bm, 0.046, (1, 1, 0.62), (0, 0, 0.004)), "gem", vrange=(-0.03, 0.035), matrix=m,
             smooth=False, caps=False)
    # brass ear brackets on three hex corners (skipping the corner that carries the bridge)
    skip = {"A": 240, "B": 60}.get(name)
    for ang in (0, 120, 180, 300):
        if ang == skip:
            continue
        a = math.radians(ang)
        d = Vector((math.cos(a), math.sin(a), 0))
        m = frame((tx + d.x * 0.145, ty + d.y * 0.145, 0.862), d)
        ear = fillet_path([(0, 0), (0.026, 0), (0.026, 0.024), (0.012, 0.03), (0, 0.03)], [0, 0.008, 0.006, 0.006, 0])
        part(g, lambda bm: revolve(bm, ear, 24), "gold", vrange=None, matrix=m, caps=False)
    # --- cap ring, neck and collar ----------------------------------------------------------------------------
    cap = fillet_path([(0, 0.90), (0.185, 0.90), (0.185, 1.0), (0.108, 1.0), (0.088, 0.985), (0, 0.985)],
                      [0, 0.02, 0.036, 0.01, 0.01, 0])
    part(g, lambda bm: revolve(bm, cap, 72, ctr), "coral", center=ctr)
    part(g, lambda bm: revolve(bm, [(0, 0.985), (0.066, 0.985), (0.066, 1.10), (0, 1.10)], 36, ctr), "graphite", center=ctr)
    part(g, lambda bm: revolve(bm, circle_path(0.068, 1.065, 0.011, 0.01), 36, ctr, closed=True), "gold", center=ctr)
    # --- cream stacked-ring insulator coil -------------------------------------------------------------------------
    part(g, lambda bm: revolve(bm, [(0, 1.09), (0.052, 1.09), (0.052, GEM_Z - 0.03), (0, GEM_Z - 0.03)], 32, ctr),
         "graphite", center=ctr)
    for k in range(7):
        zc = 1.115 + 0.052 * k
        part(g, lambda bm, zc=zc: revolve(bm, circle_path(0.087, zc, 0.034, 0.031, 14), 60, ctr, closed=True), "cream", center=ctr)
    # --- faceted violet gem on top ------------------------------------------------------------------------------------
    part(g, lambda bm: icosphere(bm, GEM_R, center=(tx, ty, GEM_Z), subdiv=2), "gem", vrange=(GEM_Z - GEM_R, GEM_Z + GEM_R),
         center=ctr, smooth=False, caps=False)
    gems_out[name] = (tx, ty, GEM_Z + GEM_R)
    # --- brass ball feet + pearl ------------------------------------------------------------------------------------
    for ang in (30, 150, 270):
        a = math.radians(ang)
        c = (tx + 0.222 * math.cos(a), ty + 0.222 * math.sin(a))
        part(g, lambda bm, c=c: revolve(bm, sphere_path(0.05, BASE_Z + 0.04, 12), 24, c), "brass", center=c)
    pa = math.radians({"A": 128, "B": 248, "C": 8}[name])
    pc = (tx + 0.205 * math.cos(pa), ty + 0.205 * math.sin(pa))
    part(g, lambda bm: revolve(bm, sphere_path(0.017, 0.235, 8), 16, pc), "pearl", center=pc)
    return g


# ---------------------------------------------------------------------------------------------------------------
# Bridge
# ---------------------------------------------------------------------------------------------------------------
def build_bridge():
    g = Group()
    a, b = Vector(TOWERS["A"] + (0,)), Vector(TOWERS["B"] + (0,))
    d = (b - a).normalized()
    length_ab = (b - a).length
    zc = 0.95
    start = Vector((a.x, a.y, zc))

    def at(t):
        return frame(start + d * t, d)

    # hubs bolted to each cap ring
    hub = fillet_path([(0, 0), (0.042, 0), (0.042, 0.03), (0, 0.03)], [0, 0.008, 0.008, 0])
    flange = fillet_path([(0, 0), (0.034, 0), (0.034, 0.012), (0, 0.012)], [0, 0.004, 0.004, 0])
    hub_a, hub_b = 0.168, length_ab - 0.168 - 0.03
    for t in (hub_a, hub_b):
        part(g, lambda bm: revolve(bm, hub, 32), "gold", vrange=None, matrix=at(t), caps=False)
    rod0, rod1 = hub_a + 0.03, hub_b
    rod_len = rod1 - rod0
    # rod core with end collars
    core = fillet_path([(0, 0), (0.03, 0), (0.03, rod_len), (0, rod_len)], [0, 0.004, 0.004, 0])
    part(g, lambda bm: revolve(bm, core, 28), "brass", vrange=None, matrix=at(rod0), caps=False)
    for t in (rod0 + 0.004, rod1 - 0.022):
        col = fillet_path([(0, 0), (0.04, 0), (0.04, 0.018), (0, 0.018)], [0, 0.005, 0.005, 0])
        part(g, lambda bm: revolve(bm, col, 28), "gold", vrange=None, matrix=at(t), caps=False)
    # toothed underside (rack): trapezoid teeth hanging below the rod
    nteeth = 6
    inner0, inner1 = rod0 + 0.03, rod1 - 0.03
    for k in range(nteeth):
        zt = inner0 + (inner1 - inner0) * (k + 0.5) / nteeth
        w0, w1 = 0.5 * (inner1 - inner0) / nteeth * 0.86, 0.5 * (inner1 - inner0) / nteeth * 0.30

        def tooth(bm, zt=zt, w0=w0, w1=w1):
            pts = {}
            for sy in (-0.019, 0.019):
                pts[sy] = [bm.verts.new(p) for p in ((-0.016, sy, zt - w0), (-0.016, sy, zt + w0),
                                                      (-0.078, sy, zt + w1), (-0.078, sy, zt - w1))]
            f = bm.faces.new(pts[-0.019])
            bm.faces.new(pts[0.019])
            for i in range(4):
                j = (i + 1) % 4
                bm.faces.new((pts[-0.019][i], pts[-0.019][j], pts[0.019][j], pts[0.019][i]))
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
            bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.003, segments=2, affect="EDGES")
        part(g, tooth, "brass", vrange=(-0.06, 0.03), matrix=at(rod0), caps=False)
    return g


# ---------------------------------------------------------------------------------------------------------------
# Base
# ---------------------------------------------------------------------------------------------------------------
def clover_outline(n=144):
    towers = [np.array(v) for v in TOWERS.values()]
    lobe, centre = 0.32, 0.345
    r = np.zeros(n)
    for k in range(n):
        th = TAU * k / n
        d = np.array((math.cos(th), math.sin(th)))
        best = centre
        for c in towers:
            b = float(d @ c)
            disc = b * b - float(c @ c) + lobe * lobe
            if disc >= 0:
                best = max(best, b + math.sqrt(disc))
        r[k] = best
    sigma = n * 5.5 / 360.0
    idx = np.arange(-int(4 * sigma), int(4 * sigma) + 1)
    kern = np.exp(-0.5 * (idx / sigma) ** 2)
    kern /= kern.sum()
    sm = sum(kern[i] * np.roll(r, -int(s)) for i, s in enumerate(idx))
    pts = np.stack([sm * np.cos(TAU * np.arange(n) / n), sm * np.sin(TAU * np.arange(n) / n)], -1)
    tan = np.roll(pts, -1, 0) - np.roll(pts, 1, 0)
    tan /= np.linalg.norm(tan, axis=1, keepdims=True)
    nor = np.stack([tan[:, 1], -tan[:, 0]], -1)          # outward for a CCW outline
    return pts, nor


def build_base():
    g = Group()
    pts, nor = clover_outline()

    def ring(d, z, s=1.0):
        return [(float(p[0] * s + q[0] * d), float(p[1] * s + q[1] * d), z) for p, q in zip(pts, nor)]

    # slab: bottom pole -> inset scales -> rounded outer edge -> top
    prof = fillet_path([(-0.1, 0.0), (0.0, 0.0), (0.0, BASE_Z), (-0.1, BASE_Z)], [0, 0.014, 0.032, 0], 6)[1:-1]

    def slab(bm):
        rings = [(0.0, 0.0, 0.0)] + [ring(0, 0.0, s) for s in (0.25, 0.5, 0.7, 0.85)]
        rings += [ring(dd, z) for dd, z in prof]
        rings += [ring(0, BASE_Z, s) for s in (0.85, 0.7, 0.5, 0.25)] + [(0.0, 0.0, BASE_Z)]
        surface_from_rings(bm, rings)

    def cell_of(f):
        return "teal" if f.normal.z > 0.35 else "teal_dark"
    part(g, slab, cell_of, vrange=(0.0, H_MAX))
    # gold trim band around the outline
    band = fillet_path([(-0.008, 0.062), (0.014, 0.062), (0.014, 0.092), (-0.008, 0.092)], [0.006] * 4, 4, closed=True)

    def trim(bm):
        surface_from_rings(bm, [ring(dd, z) for dd, z in band], closed_profile=True)
    part(g, trim, "gold", vrange=(0.0, H_MAX), caps=False)
    # seams between the lobes
    for ang in (30, 270):
        a = math.radians(ang)
        d = Vector((math.cos(a), math.sin(a), 0))
        m = Matrix.Translation(d * 0.23 + Vector((0, 0, BASE_Z))) @ Matrix.Rotation(a, 4, "Z")

        def seam(bm):
            bmesh.ops.create_cube(bm, size=1.0)
            for v in bm.verts:
                v.co = Vector((v.co.x * 0.16, v.co.y * 0.0075, v.co.z * 0.006 + 0.0))
        part(g, seam, "graphite", vrange=(-0.01, 0.01), matrix=m, caps=False)
    # large brass-ringed violet jewel on the front notch
    ja = math.radians(150)
    jc = (0.225 * math.cos(ja), 0.225 * math.sin(ja))
    flange = fillet_path([(0, BASE_Z - 0.004), (0.094, BASE_Z - 0.004), (0.094, BASE_Z + 0.012), (0, BASE_Z + 0.012)], [0, 0.008, 0.012, 0])
    part(g, lambda bm: revolve(bm, flange, 40, jc), "gold", vrange=(0.1, 0.2), center=jc)
    part(g, lambda bm: revolve(bm, circle_path(0.07, BASE_Z + 0.026, 0.0165, 0.0155), 40, jc, closed=True), "gold",
         vrange=(0.1, 0.2), center=jc)
    part(g, lambda bm: icosphere(bm, 0.074, (1, 1, 0.52), (jc[0], jc[1], BASE_Z + 0.022), subdiv=2), "gem",
         vrange=(BASE_Z - 0.017, BASE_Z + 0.057), center=jc, smooth=False, caps=False)
    return g


# ---------------------------------------------------------------------------------------------------------------
# Ambient occlusion in vertex colours (COLOR_0)
# ---------------------------------------------------------------------------------------------------------------
def bake_ao(objects, samples=20, distance=0.22, floor=0.62):
    bpy.context.view_layer.update()
    verts, tris = [], []
    for o in objects:
        base = len(verts)
        verts.extend(o.matrix_world @ v.co for v in o.data.vertices)
        o.data.calc_loop_triangles()
        tris.extend(tuple(base + i for i in t.vertices) for t in o.data.loop_triangles)
    tree = BVHTree.FromPolygons(verts, tris)
    rng = random.Random(7)
    for o in objects:
        mesh = o.data
        nm = o.matrix_world.to_3x3().inverted().transposed()
        colors = mesh.color_attributes.new("AO", "BYTE_COLOR", "CORNER")
        normals = mesh.corner_normals
        cache = {}
        for loop in mesh.loops:
            n = (nm @ normals[loop.index].vector).normalized()
            key = (loop.vertex_index, round(n.x, 2), round(n.y, 2), round(n.z, 2))
            if key not in cache:
                pos = o.matrix_world @ mesh.vertices[loop.vertex_index].co
                tangent = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
                bitan = n.cross(tangent)
                origin = pos + n * 0.004
                hits = 0.0
                for _ in range(samples):
                    r1, r2 = rng.random(), rng.random()
                    rad, ang = math.sqrt(r1), TAU * r2
                    dirv = tangent * (rad * math.cos(ang)) + bitan * (rad * math.sin(ang)) + n * math.sqrt(1 - r1)
                    hit = tree.ray_cast(origin, dirv, distance)
                    if hit[0] is not None:
                        hits += 1.0 - hit[3] / distance
                occ = hits / samples
                cache[key] = floor + (1.0 - floor) * (1.0 - occ) ** 1.4
            val = cache[key]
            colors.data[loop.index].color = (val, val, val, 1.0)
        mesh.color_attributes.active_color = colors
        mesh.color_attributes.render_color_index = list(mesh.color_attributes).index(colors)


# ---------------------------------------------------------------------------------------------------------------
# Assembly
# ---------------------------------------------------------------------------------------------------------------
def make_object(name, group, material, parent):
    bm = group.bm
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    mesh.materials.append(material)
    obj.parent = parent
    obj.matrix_parent_inverse = parent.matrix_world.inverted()
    return obj


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    images = build_atlas()
    mat = make_material(images)

    def empty(name, loc, parent=None):
        e = bpy.data.objects.new(name, None)
        e.empty_display_type = "PLAIN_AXES"
        e.empty_display_size = 0.1
        bpy.context.scene.collection.objects.link(e)
        e.location = loc
        if parent:
            e.parent = parent
        bpy.context.view_layer.update()
        return e

    root = empty("StormNetwork", (0, 0, 0))
    aim = empty("Aim", (0, 0, BASE_Z), root)
    objects = [make_object("Base_Static", build_base(), mat, root)]
    gems = {}
    for name, (x, y) in TOWERS.items():
        objects.append(make_object(f"Aim_Tower_{name}", build_tower(name, x, y, gems), mat, aim))
    objects.append(make_object("Aim_Bridge", build_bridge(), mat, aim))
    tip = gems["A"]
    muzzle = empty("Muzzle", (0, 0, 0), aim)
    muzzle.location = (tip[0], tip[1], tip[2] - BASE_Z)
    bpy.context.view_layer.update()

    if not os.environ.get("STORM_NO_AO"):
        bake_ao(objects)

    tris = 0
    for o in objects:
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
    print("BUILD_STATS", {"triangles": tris, "objects": len(objects), "materials": 1})
    bpy.ops.export_scene.gltf(filepath=str(OUT / "cp_storm_network.glb"), export_format="GLB", export_yup=True,
                              export_animations=False, export_cameras=False, export_lights=False,
                              export_vertex_color="ACTIVE")


main()

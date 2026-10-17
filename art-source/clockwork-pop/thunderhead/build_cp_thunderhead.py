"""Clockwork Thunderhead (Tesla / Capacitor level-15 turret) - scripted Blender build with procedural textures.

Run: blender --background --python build_cp_thunderhead.py
Metres, +Z up, weapon faces +Y. Writes cp_thunderhead.glb next to this script.
Static base (hex plate, three capacitor drums, springs, core) + rotating Aim head (teal drum, coil, cloud insulator).
All images are generated here with numpy (two albedo atlases + two packed ORM atlases, 1024x1024 each).
"""
import math
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

OUT_DIR = Path(__file__).resolve().parent
TAU = math.tau
SHARP = math.radians(35)

# ----------------------------------------------------------------------------------------------------------------------
# Layout constants (metres)
# ----------------------------------------------------------------------------------------------------------------------
R_PLATE = 0.80
PLATE_H = 0.09
DRUM_ANGLES = (90, 32, 148)  # front drum plus two flanking it in an arc; the back stays open (core pillar)
DRUM_DIST = 0.555
DRUM_R = 0.225
PIVOT_Z = 0.93  # Aim empty height (underside of the teal drum), in concept-scale metres
CLOUD_CENTER_Z = 2.34
S = 0.58  # global scale: the concept is a tall tower; this fits it under the 1.6 m height limit


# ----------------------------------------------------------------------------------------------------------------------
# Procedural textures
# ----------------------------------------------------------------------------------------------------------------------
TILE = 512  # each atlas is 2x2 tiles of 512 px = 1024 px
RNG = np.random.default_rng(2026)


def smooth_noise(h, w, cy, cx):
    g = RNG.random((cy + 2, cx + 2))
    ys = np.linspace(0, cy, h, endpoint=False)
    xs = np.linspace(0, cx, w, endpoint=False)
    y0, x0 = ys.astype(int), xs.astype(int)
    fy, fx = ys - y0, xs - x0
    fy = (fy * fy * (3 - 2 * fy))[:, None]
    fx = (fx * fx * (3 - 2 * fx))[None, :]
    a, b = g[np.ix_(y0, x0)], g[np.ix_(y0, x0 + 1)]
    c, d = g[np.ix_(y0 + 1, x0)], g[np.ix_(y0 + 1, x0 + 1)]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(cells=4, octaves=4, aniso=(1, 1)):
    total, amp, norm = 0.0, 1.0, 0.0
    for o in range(octaves):
        cy = max(1, int(cells * aniso[0] * 2 ** o))
        cx = max(1, int(cells * aniso[1] * 2 ** o))
        total = total + amp * smooth_noise(TILE, TILE, min(cy, TILE - 2), min(cx, TILE - 2))
        norm += amp
        amp *= 0.5
    return total / norm


def rgb8(r, g, b):
    return np.array([r, g, b], dtype=float) / 255.0


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def glaze_tile(color, rough, tint2=None):
    """Glossy enamel: very soft mottling, a faint vertical sheen gradient and fine grain. Pristine, not weathered."""
    v = np.linspace(0, 1, TILE)[:, None]
    n = fbm(3, 4)
    shade = 1.0 + 0.09 * (n - 0.5) + 0.05 * (v - 0.5) + RNG.normal(0, 0.008, (TILE, TILE))
    base = rgb8(*color)[None, None, :] * shade[..., None]
    if tint2 is not None:
        m = smoothstep(0.35, 0.8, fbm(2, 3))[..., None] * 0.45
        base = base * (1 - m) + rgb8(*tint2)[None, None, :] * shade[..., None] * m
    rgb = np.clip(base, 0, 1)
    r = np.clip(rough + 0.05 * (fbm(5, 3) - 0.5), 0, 1)
    return rgb, r, np.zeros_like(r)


def metal_tile(color, rough, metal, streak_amp=0.10):
    """Brushed metal: fine horizontal streaks plus a very slight broad tonal drift."""
    streak = fbm(2, 3, aniso=(96, 1))
    drift = fbm(2, 3)
    shade = 1.0 + streak_amp * (streak - 0.5) * 2 + 0.05 * (drift - 0.5) + RNG.normal(0, 0.006, (TILE, TILE))
    rgb = np.clip(rgb8(*color)[None, None, :] * shade[..., None], 0, 1)
    r = np.clip(rough + 0.12 * (streak - 0.5), 0.05, 1)
    return rgb, r, np.full_like(r, metal)


def gem_tile(edge, mid, core):
    """Cabochon gem seen from above (planar-projected dome): deep rim, saturated body, bright core, soft glint."""
    x = np.linspace(-1, 1, TILE)[None, :]
    y = np.linspace(-1, 1, TILE)[:, None]
    r = np.clip(np.hypot(x, y), 0, 1)
    w_mid = 1.0 - smoothstep(0.45, 1.0, r)
    col = rgb8(*edge)[None, None, :] * (1 - w_mid[..., None]) + rgb8(*mid)[None, None, :] * w_mid[..., None]
    w_core = (1.0 - smoothstep(0.0, 0.62, r))[..., None] * 0.85
    col = col * (1 - w_core) + rgb8(*core)[None, None, :] * w_core
    d = np.hypot(x + 0.36, y - 0.40)
    glint = (np.exp(-(d / 0.13) ** 2) * 0.8)[..., None]
    col = col * (1 - glint) + np.array([1.0, 1.0, 1.0])[None, None, :] * glint
    # faint facet ripple so the gem is not a perfect gradient
    ang = np.arctan2(y, x)
    col = col * (1.0 + 0.035 * np.cos(ang * 6.0)[..., None] * (r[..., None] ** 1.5))
    rgb = np.clip(col, 0, 1)
    rough = np.full((TILE, TILE), 0.06)
    return rgb, rough, np.zeros_like(rough)


def assemble(tiles):
    """2x2 atlas, tile 0 bottom-left; pixel row 0 is the bottom (Blender image convention)."""
    albedo = np.zeros((2 * TILE, 2 * TILE, 4), dtype=np.float32)
    orm = np.zeros_like(albedo)
    albedo[..., 3] = 1.0
    orm[..., 3] = 1.0
    for idx, (rgb, rough, metal) in enumerate(tiles):
        r0, c0 = (idx // 2) * TILE, (idx % 2) * TILE
        albedo[r0:r0 + TILE, c0:c0 + TILE, :3] = rgb
        orm[r0:r0 + TILE, c0:c0 + TILE, 0] = 1.0  # occlusion (unused; AO lives in vertex colour)
        orm[r0:r0 + TILE, c0:c0 + TILE, 1] = rough
        orm[r0:r0 + TILE, c0:c0 + TILE, 2] = metal
    return albedo, orm


def make_image(name, pixels, srgb):
    img = bpy.data.images.new(name, pixels.shape[1], pixels.shape[0], alpha=False)
    img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"  # set before writing: changing it resets the buffer
    img.pixels.foreach_set(pixels.astype(np.float32).ravel())
    img.update()
    img.file_format = "PNG"
    img.pack()
    return img


# tile slots: name -> (atlas, index)
TILES = {
    "teal": ("A", 0), "coral": ("A", 1), "cream": ("A", 2), "darkteal": ("A", 3),
    "brass": ("B", 0), "steel": ("B", 1), "cyan": ("B", 2), "violet": ("B", 3), "orb": ("B", 3),
}


def make_textures():
    atlas_a = [
        glaze_tile((0, 190, 166), 0.5),                                  # teal enamel
        glaze_tile((246, 74, 50), 0.42),                                   # coral enamel
        glaze_tile((255, 236, 184), 0.5, tint2=(252, 208, 164)),          # cream ceramic
        glaze_tile((4, 112, 120), 0.45),                                   # dark teal
    ]
    atlas_b = [
        metal_tile((252, 168, 22), 0.30, 0.30, 0.03),                            # polished brass
        metal_tile((54, 50, 62), 0.36, 0.75, 0.07),                        # blackened steel (coils)
        gem_tile((0, 100, 130), (16, 228, 208), (150, 255, 240)),          # cyan jewel
        gem_tile((50, 0, 130), (140, 36, 244), (226, 160, 255)),          # violet jewel / orb
    ]
    alb_a, orm_a = assemble(atlas_a)
    alb_b, orm_b = assemble(atlas_b)
    return {
        "A": (make_image("thunderhead_enamel_albedo", alb_a, True), make_image("thunderhead_enamel_orm", orm_a, False)),
        "B": (make_image("thunderhead_trim_albedo", alb_b, True), make_image("thunderhead_trim_orm", orm_b, False)),
    }


def make_material(name, atlas_imgs, emission=0.0):
    albedo, orm = atlas_imgs
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = albedo
    tex.extension = "EXTEND"
    tex2 = nodes.new("ShaderNodeTexImage")
    tex2.image = orm
    tex2.extension = "EXTEND"
    sep = nodes.new("ShaderNodeSeparateColor")
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    links.new(tex2.outputs["Color"], sep.inputs["Color"])
    links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    if emission > 0:
        links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


# ----------------------------------------------------------------------------------------------------------------------
# Geometry helpers (bmesh, built directly in world coordinates, collected per group+material)
# ----------------------------------------------------------------------------------------------------------------------
def fillet(points, setbacks, seg=3):
    """Round the corners of a closed 2D polygon (quadratic Bezier per corner). setbacks: scalar or per-point."""
    out = []
    n = len(points)
    for i, p in enumerate(points):
        sb = setbacks[i] if isinstance(setbacks, (list, tuple)) else setbacks
        if sb <= 0:
            out.append(tuple(p))
            continue
        P, A, B = Vector(p), Vector(points[i - 1]), Vector(points[(i + 1) % n])
        d1, d2 = A - P, B - P
        t = min(sb, 0.5 * d1.length, 0.5 * d2.length)
        s, e = P + d1.normalized() * t, P + d2.normalized() * t
        for k in range(seg + 1):
            q = k / seg
            out.append(tuple((1 - q) ** 2 * s + 2 * q * (1 - q) * P + q * q * e))
    return out


def lathe(profile, seg=40):
    """Revolve a closed (r, z) profile about Z. Vertices sit at angle 0 and pi so mirrored cylindrical UVs stay clean."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        rings.append([bm.verts.new((r * math.cos(TAU * i / seg), r * math.sin(TAU * i / seg), z)) for i in range(seg)])
    n = len(profile)
    for k in range(n):
        if profile[k][0] < 1e-9 and profile[(k + 1) % n][0] < 1e-9:
            continue
        a, b = rings[k], rings[(k + 1) % n]
        for i in range(seg):
            j = (i + 1) % seg
            try:
                bm.faces.new((a[i], a[j], b[j], b[i]))
            except ValueError:
                pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def ring_profile(r0, r1, z0, z1, f_bi=0.0, f_bo=0.01, f_to=0.01, f_ti=0.0, seg=3):
    return fillet([(r0, z0), (r1, z0), (r1, z1), (r0, z1)], [f_bi, f_bo, f_to, f_ti], seg)


def disc_profile(r, z0, z1, f_bo=0.008, f_to=0.01, seg=3):
    return fillet([(0, z0), (r, z0), (r, z1), (0, z1)], [0, f_bo, f_to, 0], seg)


def torus_profile(R, tr, z=0.0, n=12):
    return [(R + tr * math.cos(TAU * k / n), z + tr * math.sin(TAU * k / n)) for k in range(n)]


def dome(radius, flat=0.62, seg=28, rings=14):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=radius)
    for v in bm.verts:
        v.co.z *= flat
    return bm


def box(size, bevel_w, seg=3):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel_w, segments=seg, profile=0.5, affect="EDGES")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def prism(n, radius, z0, z1, rot=0.0):
    bm = bmesh.new()
    bot, top = [], []
    for i in range(n):
        a = rot + TAU * i / n
        bot.append(bm.verts.new((radius * math.cos(a), radius * math.sin(a), z0)))
        top.append(bm.verts.new((radius * math.cos(a), radius * math.sin(a), z1)))
    bm.faces.new(bot[::-1])
    bm.faces.new(top)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((bot[i], bot[j], top[j], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def helix(R, tr, z0, z1, turns, per_turn=22, tube=8):
    """Swept circular tube along a helix about Z (a coil spring)."""
    bm = bmesh.new()
    steps = int(turns * per_turn)
    rings = []
    for s in range(steps + 1):
        q = s / steps
        phi = TAU * turns * q
        c = Vector((R * math.cos(phi), R * math.sin(phi), z0 + (z1 - z0) * q))
        radial = Vector((math.cos(phi), math.sin(phi), 0.0))
        tangent = Vector((-R * math.sin(phi) * TAU * turns, R * math.cos(phi) * TAU * turns, z1 - z0)).normalized()
        binormal = tangent.cross(radial).normalized()
        rings.append([bm.verts.new(c + tr * (math.cos(TAU * t / tube) * radial + math.sin(TAU * t / tube) * binormal))
                      for t in range(tube)])
    for s in range(steps):
        for t in range(tube):
            u = (t + 1) % tube
            bm.faces.new((rings[s][t], rings[s][u], rings[s + 1][u], rings[s + 1][t]))
    for ring in (rings[0], rings[-1]):
        bm.faces.new(ring)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def place(bm, pos=(0, 0, 0), rot=None):
    m = Matrix.Translation(Vector(pos))
    if rot is not None:
        m = m @ rot
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)


def basis(t1, t2, n):
    return Matrix(((t1.x, t2.x, n.x), (t1.y, t2.y, n.y), (t1.z, t2.z, n.z))).to_4x4()


def radial_frame(theta):
    n = Vector((math.cos(theta), math.sin(theta), 0.0))
    t1 = Vector((-math.sin(theta), math.cos(theta), 0.0))
    return n, t1, Vector((0, 0, 1))


# ----------------------------------------------------------------------------------------------------------------------
# UV projection into atlas tiles
# ----------------------------------------------------------------------------------------------------------------------
def project_uv(bm, spec, tile_key):
    bm.normal_update()
    uvl = bm.loops.layers.uv.verify()
    _, idx = TILES[tile_key]
    u0, v0 = (idx % 2) * 0.5, (idx // 2) * 0.5
    inset = 0.008
    span = 0.5 - 2 * inset
    kind = spec[0]
    for f in bm.faces:
        n = f.normal
        axis = max(range(3), key=lambda i: abs(n[i]))
        for loop in f.loops:
            p = loop.vert.co
            if kind == "cyl":  # ("cyl", (cx, cy), zc, M): mirrored angle around Z, caps planar
                _, c, zc, M = spec
                if abs(n.z) > 0.6:
                    u, v = 0.5 + (p.x - c[0]) / M, 0.5 + (p.y - c[1]) / M
                else:
                    u, v = abs(math.atan2(p.y - c[1], p.x - c[0])) / math.pi, 0.5 + (p.z - zc) / M
            elif kind == "box":  # ("box", centre, M): project along dominant normal axis, ~constant density
                _, c, M = spec
                a, b = {0: (1, 2), 1: (0, 2), 2: (0, 1)}[axis]
                u, v = 0.5 + (p[a] - c[a]) / M, 0.5 + (p[b] - c[b]) / M
            else:  # ("dome", centre, t1, t2, M): planar projection for round gems
                _, c, t1, t2, M = spec
                d = p - Vector(c)
                u, v = 0.5 + d.dot(t1) / M, 0.5 + d.dot(t2) / M
            u, v = min(max(u, 0.0), 1.0), min(max(v, 0.0), 1.0)
            loop[uvl].uv = (u0 + inset + u * span, v0 + inset + v * span)


GROUPS = {}


def append_plain(dst, src):
    vmap = {v: dst.verts.new(v.co) for v in src.verts}
    for f in src.faces:
        dst.faces.new([vmap[v] for v in f.verts])


def append_bm(dst, src):
    vmap = {v: dst.verts.new(v.co) for v in src.verts}
    uv_s, uv_d = src.loops.layers.uv.active, dst.loops.layers.uv.verify()
    for f in src.faces:
        nf = dst.faces.new([vmap[v] for v in f.verts])
        for ls, ld in zip(f.loops, nf.loops):
            ld[uv_d].uv = ls[uv_s].uv


def add(group, mat_key, bm, uv_spec):
    project_uv(bm, uv_spec, mat_key)
    dst = GROUPS.setdefault((group, mat_key), bmesh.new())
    append_bm(dst, bm)
    bm.free()


def cyl_uv(c, zc=0.3, M=1.2):
    return ("cyl", (c[0], c[1]), zc, M)


def add_jewel(group, theta, centre, surface_r, z, bezel_out, gem_r, gem_key):
    """Brass bezel + glossy domed jewel on a cylinder surface, facing outward at angle theta."""
    n, t1, t2 = radial_frame(theta)
    P = Vector((centre[0], centre[1], z)) + n * surface_r
    rot = basis(t1, t2, n)
    bez = lathe(ring_profile(gem_r * 0.8, bezel_out, -0.02, 0.026, 0.0, 0.012, 0.012, 0.006), 32)
    place(bez, P, rot)
    add(group, "brass", bez, ("box", P, 1.0))
    gem = dome(gem_r, 0.62)
    place(gem, P + n * 0.004, rot)
    add(group, gem_key, gem, ("dome", P, t1, t2, 2 * gem_r))


def add_rivet(group, P, n, r=0.014, t1=None, t2=None):
    if t1 is None:
        t1 = n.cross(Vector((0, 0, 1)))
        if t1.length < 1e-4:
            t1 = Vector((1, 0, 0))
        t1.normalize()
    t2 = n.cross(t1)
    # basis(t1, t2, n) must be right handed: t1 x t2 = n
    if t1.cross(t2).dot(n) < 0:
        t2 = -t2
    bm = dome(r, 0.7, 16, 8)
    place(bm, P, basis(t1, t2, n))
    add(group, "brass", bm, ("box", P, 1.0))


# ----------------------------------------------------------------------------------------------------------------------
# The model
# ----------------------------------------------------------------------------------------------------------------------
DRUM_Z0, DRUM_Z1 = 0.37, 0.80  # drum underside / top of its upper brass band
DECK_Z = 1.29  # teal deck level
FRONT = {"y": 0.15}  # cloud front surface, filled in by build_cloud


def build_base():
    # Hexagonal teal plate, corner toward +Y, generous bevels.
    plate = prism(6, R_PLATE, 0.0, PLATE_H, rot=math.radians(30))
    bmesh.ops.bevel(plate, geom=list(plate.edges), offset=0.02, segments=3, profile=0.5, affect="EDGES")
    add("Base", "teal", plate, ("box", (0, 0, 0), 2.0))
    # gold corner feet (all six; three are hidden from the concept view)
    for k in range(6):
        th = math.radians(30 + 60 * k)
        foot = box((0.19, 0.075, 0.115), 0.016)
        pos = Vector((math.cos(th) * (R_PLATE - 0.012), math.sin(th) * (R_PLATE - 0.012), 0.0575))
        place(foot, pos, Matrix.Rotation(th - math.pi / 2, 4, "Z"))
        add("Base", "brass", foot, ("box", pos, 1.0))
    # dark teal core column visible between the drums
    core = lathe(disc_profile(0.33, PLATE_H - 0.01, 0.95, 0.0, 0.01), 40)
    add("Base", "darkteal", core, cyl_uv((0, 0), 0.5))
    for zr, h in ((PLATE_H + 0.02, 0.07), (0.56, 0.09)):  # brass bands so the open back reads as designed
        band = lathe(ring_profile(0.30, 0.352, zr, zr + h, 0.0, 0.012, 0.012, 0.0), 40)
        add("Base", "brass", band, cyl_uv((0, 0), zr))
    for k in range(8):
        a = TAU * (k + 0.5) / 8 + math.pi
        add_rivet("Base", Vector((0.332 * math.cos(a), 0.332 * math.sin(a), 0.36)), Vector((math.cos(a), math.sin(a), 0)), 0.016)
    z0, z1 = DRUM_Z0, DRUM_Z1
    for ang in DRUM_ANGLES:
        th = math.radians(ang)
        n, t1, _ = radial_frame(th)
        c = n * DRUM_DIST
        # brass washer + coil spring
        washer = lathe(ring_profile(0.062, 0.13, PLATE_H, PLATE_H + 0.05, 0.006, 0.012, 0.016, 0.008), 36)
        place(washer, (c.x, c.y, 0))
        add("Base", "brass", washer, cyl_uv(c, 0.1))
        spring = helix(0.07, 0.021, PLATE_H + 0.07, z0 - 0.04, 4.6)
        place(spring, (c.x, c.y, 0))
        add("Base", "steel", spring, cyl_uv(c, 0.25))
        post = lathe(disc_profile(0.056, PLATE_H, z0 + 0.02, 0, 0), 20)
        place(post, (c.x, c.y, 0))
        add("Base", "steel", post, cyl_uv(c, 0.25))
        # coral capacitor drum with gold bands
        body = lathe(disc_profile(DRUM_R, z0 + 0.01, z1 - 0.02, 0.006, 0.006), 44)
        place(body, (c.x, c.y, 0))
        add("Base", "coral", body, cyl_uv(c, 0.6))
        low = lathe(ring_profile(0.19, DRUM_R + 0.022, z0 - 0.005, z0 + 0.07, 0.008, 0.014, 0.014, 0.008), 44)
        place(low, (c.x, c.y, 0))
        add("Base", "brass", low, cyl_uv(c, 0.4))
        high = lathe(ring_profile(0.20, DRUM_R + 0.022, z1 - 0.09, z1, 0.008, 0.016, 0.016, 0.01), 44)
        place(high, (c.x, c.y, 0))
        add("Base", "brass", high, cyl_uv(c, 0.75))
        add_jewel("Base", th, c, DRUM_R, (z0 + z1) / 2 + 0.01, 0.098, 0.062, "cyan")
        for k in range(10):  # rivets around the upper rim and studs on the lower band
            a = TAU * (k + 0.5) / 10
            add_rivet("Base", Vector((c.x + 0.215 * math.cos(a), c.y + 0.215 * math.sin(a), z1)), Vector((0, 0, 1)), 0.013)
        for k in range(6):
            a = th + math.radians(30) + TAU * k / 6
            add_rivet("Base", Vector((c.x + (DRUM_R + 0.022) * math.cos(a), c.y + (DRUM_R + 0.022) * math.sin(a), z0 + 0.032)),
                      Vector((math.cos(a), math.sin(a), 0)), 0.012)


def build_aim():
    G = "Aim"
    zb = PIVOT_Z  # underside of the lower brass band
    body = lathe(disc_profile(0.465, zb + 0.01, DECK_Z, 0.008, 0.008), 56)
    add(G, "teal", body, cyl_uv((0, 0), 1.1, 1.3))
    band = lathe(fillet([(0.40, zb), (0.50, zb), (0.534, zb + 0.04), (0.526, zb + 0.08), (0.40, zb + 0.08)],
                        [0, 0.012, 0.014, 0.012, 0], 3), 56)
    add(G, "brass", band, cyl_uv((0, 0), zb + 0.04, 1.3))
    rim = lathe(ring_profile(0.435, 0.528, 1.19, 1.36, 0.0, 0.014, 0.018, 0.012, 4), 56)
    add(G, "brass", rim, cyl_uv((0, 0), 1.27, 1.3))
    well = lathe(ring_profile(0.15, 0.258, DECK_Z - 0.01, 1.43, 0.0, 0.014, 0.02, 0.012, 4), 44)
    add(G, "brass", well, cyl_uv((0, 0), 1.36, 1.3))
    pit = lathe(disc_profile(0.156, DECK_Z - 0.02, DECK_Z + 0.02, 0, 0), 32)
    add(G, "steel", pit, cyl_uv((0, 0), 1.3))
    # violet jewels left and right of centre, brass lugs at the sides, rivets
    jz = (zb + 0.08 + 1.19) / 2
    for ang in (52, 128):
        add_jewel(G, math.radians(ang), (0, 0), 0.465, jz, 0.1, 0.064, "violet")
    for ang in (0, 180):
        n, t1, _ = radial_frame(math.radians(ang))
        lug = box((0.045, 0.07, 0.2), 0.016)
        place(lug, n * 0.535 + Vector((0, 0, 1.25)), Matrix.Rotation(math.radians(ang), 4, "Z"))
        add(G, "brass", lug, ("box", n * 0.53, 1.0))
    for ang in (90, 270, 150, 210, 30, 330):
        a = math.radians(ang)
        add_rivet(G, Vector((0.4655 * math.cos(a), 0.4655 * math.sin(a), jz)), Vector((math.cos(a), math.sin(a), 0)), 0.018)
    for ang in (18, 66, 112, 160, 205, 250, 300, 345):
        a = math.radians(ang)
        add_rivet(G, Vector((0.365 * math.cos(a), 0.365 * math.sin(a), DECK_Z)), Vector((0, 0, 1)), 0.022)
    # tall dark spiral coil rising out of the well to a brass collar
    coil = helix(0.088, 0.034, DECK_Z + 0.16, 1.98, 6.4, 24, 10)
    add(G, "steel", coil, cyl_uv((0, 0), 1.7))
    spine = lathe(disc_profile(0.08, DECK_Z, 2.06, 0, 0), 24)
    add(G, "steel", spine, cyl_uv((0, 0), 1.7))
    collar = lathe(ring_profile(0.115, 0.20, 2.0, 2.09, 0.008, 0.014, 0.02, 0.012, 4), 44)
    add(G, "brass", collar, cyl_uv((0, 0), 2.05, 1.3))
    build_cloud()


def build_cloud():
    """Puffy cartoon cloud: overlapping spheres voxel-remeshed into one solid, then lightly relaxed."""
    G = "Aim"
    puffs = [(0.0, 0.0, 0.21), (-0.17, -0.005, 0.15), (0.17, -0.01, 0.15), (-0.03, 0.115, 0.15), (0.11, 0.09, 0.11),
             (-0.11, -0.085, 0.13), (0.11, -0.09, 0.13), (0.0, -0.095, 0.14)]
    src = bmesh.new()
    for x, z, r in puffs:
        part = bmesh.new()
        r *= 1.05
        bmesh.ops.create_uvsphere(part, u_segments=32, v_segments=16, radius=r)
        for v in part.verts:
            v.co = Vector((x + v.co.x, v.co.y * 0.95, z * 1.15 + v.co.z))
        append_plain(src, part)
        part.free()
    me = bpy.data.meshes.new("cloud_src")
    src.to_mesh(me)
    src.free()
    obj = bpy.data.objects.new("cloud_src", me)
    bpy.context.collection.objects.link(obj)
    me.remesh_voxel_size = 0.013
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.voxel_remesh()
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bpy.data.objects.remove(obj)
    bpy.data.meshes.remove(me)
    for _ in range(3):
        bmesh.ops.smooth_vert(bm, verts=bm.verts, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    for v in bm.verts:
        v.co = Vector((v.co.x, v.co.y, v.co.z + CLOUD_CENTER_Z))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    xs, ys, zs = ([v.co[i] for v in bm.verts] for i in range(3))
    print("CLOUD bbox x", min(xs), max(xs), "y", min(ys), max(ys), "z", min(zs), max(zs), "verts", len(bm.verts))
    add(G, "cream", bm, ("box", (0, 0, CLOUD_CENTER_Z), 1.0))
    front = max(ys)
    FRONT["y"] = front
    # violet orb in the cloud face with a soft cream collar
    orb_c = Vector((0, front - 0.045, CLOUD_CENTER_Z + 0.02))
    orb = bmesh.new()
    bmesh.ops.create_uvsphere(orb, u_segments=40, v_segments=20, radius=0.145)
    for v in orb.verts:
        v.co.y *= 0.68  # a cabochon set into the cloud face rather than a ball stuck on it
    place(orb, orb_c)
    add(G, "orb", orb, ("dome", orb_c, Vector((1, 0, 0)), Vector((0, 0, 1)), 0.29))
    collar = lathe(torus_profile(0.15, 0.03), 40)
    place(collar, orb_c + Vector((0, -0.05, 0)), Matrix.Rotation(-math.pi / 2, 4, "X"))
    add(G, "cream", collar, ("box", orb_c, 1.0))


MESH_NAMES = {"teal": "Teal", "darkteal": "DarkTeal", "coral": "Coral", "cream": "Cream", "brass": "Brass",
              "steel": "Steel", "cyan": "Cyan", "violet": "Violet", "orb": "Orb"}


COS_SHARP = math.cos(SHARP)


def loop_normals(bm):
    """Per-corner normals: smooth within SHARP degrees, but horizontal caps and big flat faces keep a true flat normal
    (so bevelled plates and drum tops do not pick up a dished gradient from their rounded rims)."""
    bm.normal_update()
    out = []
    for f in bm.faces:
        n = f.normal
        flat = abs(n.z) > 0.9995 or f.calc_area() > 0.012
        for loop in f.loops:
            if flat:
                out.append(n.copy())
                continue
            acc = Vector()
            for other in loop.vert.link_loops:
                g = other.face
                if g.normal.dot(n) >= COS_SHARP:
                    acc += g.normal * other.calc_angle()
            out.append(acc.normalized() if acc.length > 1e-9 else n.copy())
    return out


def finalize(mats, aim, root):
    objs = []
    for (group, key), bm in GROUPS.items():
        for v in bm.verts:
            if group == "Aim":
                v.co.z -= PIVOT_Z
            v.co *= S
        bm.normal_update()
        for f in bm.faces:
            f.smooth = True
        for e in bm.edges:
            e.smooth = not (len(e.link_faces) == 2 and e.calc_face_angle(0.0) > SHARP)
        name = f"{group}_{MESH_NAMES[key]}"
        normals = loop_normals(bm)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.normals_split_custom_set(normals)
        me.materials.append(mats[key])
        obj = bpy.data.objects.new(name, me)
        bpy.context.collection.objects.link(obj)
        obj.parent = aim if group == "Aim" else root
        objs.append(obj)
    return objs


def bake_vertex_ao(objs, samples=18, distance=0.12, floor=0.7):
    """Cheap per-vertex ambient occlusion (BVH ray casts) stored as a corner colour attribute."""
    bpy.context.view_layer.update()
    verts, tris = [], []
    for o in objs:
        base = len(verts)
        verts.extend(o.matrix_world @ v.co for v in o.data.vertices)
        o.data.calc_loop_triangles()
        tris.extend(tuple(base + i for i in t.vertices) for t in o.data.loop_triangles)
    tree = BVHTree.FromPolygons(verts, tris)
    rng = np.random.default_rng(7)
    for o in objs:
        me = o.data
        nm = o.matrix_world.to_3x3().inverted().transposed()
        values = []
        for v in me.vertices:
            pos = o.matrix_world @ v.co
            nrm = (nm @ v.normal).normalized()
            tan = nrm.cross(Vector((0, 0, 1)) if abs(nrm.z) < 0.9 else Vector((1, 0, 0))).normalized()
            bit = nrm.cross(tan)
            origin = pos + nrm * 0.004
            occ = 0.0
            for _ in range(samples):
                r1, r2 = rng.random(), rng.random()
                rr, ang = math.sqrt(r1), TAU * r2
                d = tan * (rr * math.cos(ang)) + bit * (rr * math.sin(ang)) + nrm * math.sqrt(1 - r1)
                hit = tree.ray_cast(origin, d, distance)
                if hit[0] is not None:
                    occ += 1.0 - hit[3] / distance
            occ /= samples
            values.append(floor + (1.0 - floor) * (1.0 - occ) ** 1.6)
        fl = 0.9 if o.name.endswith(("Cream", "Orb")) else floor
        values = [fl + (1.0 - fl) * (v - floor) / (1.0 - floor) for v in values]
        col = me.color_attributes.new("AO", "BYTE_COLOR", "CORNER")
        for li, loop in enumerate(me.loops):
            val = values[loop.vertex_index]
            col.data[li].color = (val, val, val, 1.0)
        me.color_attributes.active_color = col
        me.color_attributes.render_color_index = list(me.color_attributes).index(col)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    imgs = make_textures()
    mats = {
        "teal": make_material("Teal enamel", imgs["A"]),
        "darkteal": make_material("Dark teal enamel", imgs["A"]),
        "coral": make_material("Coral enamel", imgs["A"]),
        "cream": make_material("Cream ceramic", imgs["A"]),
        "brass": make_material("Polished brass", imgs["B"]),
        "steel": make_material("Blackened steel", imgs["B"]),
        "cyan": make_material("Cyan jewel", imgs["B"]),
        "violet": make_material("Violet jewel", imgs["B"]),
        "orb": make_material("Violet orb glow", imgs["B"], emission=0.7),
    }
    root = bpy.data.objects.new("Thunderhead", None)
    bpy.context.collection.objects.link(root)
    aim = bpy.data.objects.new("Aim", None)
    bpy.context.collection.objects.link(aim)
    aim.parent = root
    aim.location = (0, 0, PIVOT_Z * S)

    build_base()
    build_aim()
    objs = finalize(mats, aim, root)

    muzzle = bpy.data.objects.new("Muzzle", None)
    bpy.context.collection.objects.link(muzzle)
    muzzle.parent = aim
    muzzle.location = (0, (FRONT['y'] + 0.16) * S, (CLOUD_CENTER_Z + 0.09 - PIVOT_Z) * S)

    bake_vertex_ao(objs)

    tris = 0
    for o in objs:
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
    print("BUILD triangles", tris, "mesh objects", len(objs), "materials", len(mats))

    bpy.ops.export_scene.gltf(filepath=str(OUT_DIR / "cp_thunderhead.glb"), export_format="GLB", export_yup=True,
                              export_animations=False, export_cameras=False, export_lights=False,
                              export_vertex_color="ACTIVE")


main()

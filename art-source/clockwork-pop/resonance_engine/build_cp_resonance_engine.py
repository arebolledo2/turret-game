"""Clockwork Resonance Engine (Shock/Resonator level-15 capstone turret) - scripted Blender build.

Run: blender --background --python build_cp_resonance_engine.py
Metres, +Z up, weapon faces +Y. Writes cp_resonance_engine.glb next to this script.
Everything (geometry, UVs, 4 procedural 1024px textures) is generated here; no external assets.
"""
import math
import random
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

OUT = Path(__file__).resolve().parent
SHARP = math.radians(40)
TILE = 0.6  # metres per repeat of the tiling paint / normal textures
TS = 1024

# --------------------------------------------------------------------------------------------------
# procedural textures
# --------------------------------------------------------------------------------------------------


def fnoise(sx, sy=None, seed=0, size=TS):
    """Periodic gaussian-filtered noise with unit std (so every texture tiles seamlessly)."""
    rng = np.random.default_rng(seed)
    f = np.fft.fft2(rng.standard_normal((size, size)))
    ky = np.fft.fftfreq(size)[:, None]
    kx = np.fft.fftfreq(size)[None, :]
    sy = sx if sy is None else sy
    n = np.fft.ifft2(f * np.exp(-2 * np.pi ** 2 * ((kx * sx) ** 2 + (ky * sy) ** 2))).real
    n -= n.mean()
    return n / max(n.std(), 1e-9)


def tex_paint():
    """Pristine painted-enamel detail (grey, multiplied by each material tint): soft mottle, faint brush, fine grain."""
    g = (0.955 + 0.014 * fnoise(80, seed=1) + 0.010 * fnoise(16, seed=2)
         + 0.010 * fnoise(70, 2.2, seed=3) + 0.006 * fnoise(0.9, seed=4))
    g = np.clip(g, 0.86, 1.0)
    return np.stack([g, g, g], -1)


def tex_normal():
    """Very fine orange-peel tangent-space normal map for the painted shell."""
    h = 0.6 * fnoise(1.6, seed=11) + 0.4 * fnoise(6, seed=12)
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5
    n = np.stack([-dx * 0.55, -dy * 0.55, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def tex_brass():
    """Brushed gold. Rows 0-511 plain brass; rows 512-1023 the segmented collar band (seam + lip at the u wrap)."""
    streak = fnoise(110, 1.6, seed=5)
    mott = fnoise(45, seed=6)
    grain = fnoise(0.8, seed=7)
    lum = 1 + 0.018 * streak + 0.022 * mott + 0.008 * grain
    rows = (np.arange(TS)[:, None] % (TS // 2)) / (TS // 2)
    lum = lum + 0.035 * np.exp(-((rows - 0.72) / 0.13) ** 2) - 0.03 * np.exp(-((rows - 0.08) / 0.1) ** 2)
    base = np.array([0.84, 0.60, 0.15])
    col = base * lum[..., None]
    hi = np.clip((lum - 1.04) * 9, 0, 1)[..., None]
    col = col * (1 - 0.5 * hi) + np.array([0.98, 0.83, 0.42]) * 0.5 * hi
    x = np.arange(TS)[None, :]
    e = np.minimum(x, TS - 1 - x) * np.ones((TS, 1))
    seam = np.where(e < 3, 0.45, np.where(e < 9, 1.0 + 0.09 * (1 - (e - 3) / 6), 1.0))
    seam[: TS // 2] = 1.0
    col = col * seam[..., None]
    return np.clip(col, 0, 1)


def tex_gem():
    """Atlas: left half mint crystal (u 0-0.5), right half violet crystal (u 0.5-1). Content in normalised part space."""
    half = TS // 2
    a = (np.arange(half)[None, :] + 0.5) / half
    b = (np.arange(TS)[:, None] + 0.5) / TS
    a = a * np.ones((TS, 1))
    b = b * np.ones((1, half))
    rng = np.random.default_rng(21)
    # mint: radial glow, voronoi facet cells with lighter facet edges
    pts = rng.random((38, 2))
    shade = 1 + 0.10 * (rng.random(38) - 0.5) * 2
    d = np.sqrt((a[..., None] - pts[:, 0]) ** 2 + (b[..., None] - pts[:, 1]) ** 2)
    order = np.argsort(d, axis=-1)
    d1 = np.take_along_axis(d, order[..., :1], -1)[..., 0]
    d2 = np.take_along_axis(d, order[..., 1:2], -1)[..., 0]
    cell = shade[order[..., 0]]
    rad = np.clip(np.hypot(a - 0.5, b - 0.5) / 0.5, 0, 1) ** 0.8
    centre = np.array([0.30, 0.96, 0.66])
    edge = np.array([0.04, 0.62, 0.42])
    mint = centre * (1 - rad[..., None]) + edge * rad[..., None]
    mint = mint * cell[..., None]
    mint = np.where((d2 - d1)[..., None] < 0.012, np.minimum(mint * 1.12 + 0.03, 1.0), mint)
    # violet: dark base to bright tip, soft vertical facet bands
    t = b
    bot = np.array([0.30, 0.16, 0.56])
    top = np.array([0.74, 0.54, 0.98])
    vio = bot * (1 - t[..., None]) + top * t[..., None]
    band = 1 + 0.10 * np.sin(a * 6 * np.pi) * np.sin(a * 2 * np.pi * 3 + 0.7)
    vio = vio * band[..., None]
    vio = np.where((t > 0.86)[..., None], np.minimum(vio * 1.1 + 0.04, 1.0), vio)
    img = np.zeros((TS, TS, 3))
    img[:, :half] = mint
    img[:, half:] = vio
    return np.clip(img, 0, 1)


def make_image(name, rgb, data=False):
    img = bpy.data.images.new(name, TS, TS, alpha=False)
    px = np.ones((TS, TS, 4), dtype=np.float32)
    px[..., :3] = rgb
    img.pixels.foreach_set(px.ravel())
    if data:
        img.colorspace_settings.name = "Non-Color"
    img.file_format = "PNG"
    img.pack()
    return img


# --------------------------------------------------------------------------------------------------
# materials
# --------------------------------------------------------------------------------------------------
IMG = {}


def lin(c):
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


def setv(node, name, value):
    try:
        node.inputs[name].default_value = value
    except KeyError:
        pass


def new_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    return m, m.node_tree.nodes, m.node_tree.links, m.node_tree.nodes["Principled BSDF"]


def tex_node(nodes, image, ext="REPEAT"):
    n = nodes.new("ShaderNodeTexImage")
    n.image = image
    n.extension = ext
    n.interpolation = "Linear"
    return n


def mat_paint(name, srgb, rough=0.42, metal=0.0, normal=0.3, coat=0.35):
    """Painted enamel: tiling grey detail x tint (in Base Color) + orange-peel normal map."""
    m, nodes, links, bsdf = new_mat(name)
    tint = tuple(min(1.0, c / 0.91) for c in lin(srgb))
    t = tex_node(nodes, IMG["paint"])
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    mix.inputs[6].default_value = (*tint, 1)
    links.new(t.outputs["Color"], mix.inputs[7])
    links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    if normal > 0:
        nt = tex_node(nodes, IMG["normal"])
        nm = nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = normal
        links.new(nt.outputs["Color"], nm.inputs["Color"])
        links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    setv(bsdf, "Coat Weight", coat)
    setv(bsdf, "Coat Roughness", 0.12)
    m.diffuse_color = (*lin(srgb), 1)
    return m


def mat_brass(name="Brass"):
    m, nodes, links, bsdf = new_mat(name)
    t = tex_node(nodes, IMG["brass"])
    links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Metallic"].default_value = 0.8
    bsdf.inputs["Roughness"].default_value = 0.3
    m.diffuse_color = (*lin((0.80, 0.58, 0.19)), 1)
    return m


def mat_gem(name, emit, rough=0.12, alpha=1.0, coat=0.0):
    """Gem atlas drives both Base Color and Emission; alpha < 1 gives the translucent glass orb."""
    m, nodes, links, bsdf = new_mat(name)
    t = tex_node(nodes, IMG["gem"], "EXTEND")
    links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
    if emit > 0:
        links.new(t.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emit
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = rough
    setv(bsdf, "Coat Weight", coat)
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
        try:
            m.blend_method = "BLEND"
        except Exception:
            pass
    return m


def mat_glint(name="Glint"):
    m, nodes, links, bsdf = new_mat(name)
    bsdf.inputs["Base Color"].default_value = (1, 1, 1, 1)
    bsdf.inputs["Emission Color"].default_value = (0.9, 1.0, 0.97, 1)
    bsdf.inputs["Emission Strength"].default_value = 1.4
    bsdf.inputs["Roughness"].default_value = 0.2
    return m


# --------------------------------------------------------------------------------------------------
# geometry helpers (bmesh based; every part is built in a local frame, then placed with a matrix)
# --------------------------------------------------------------------------------------------------


def fillet(pts, radii, seg=4, closed=False):
    pts = [np.array(p, dtype=float) for p in pts]
    n = len(pts)
    out = []
    for i, p in enumerate(pts):
        r = radii[i] if isinstance(radii, (list, tuple)) else radii
        if (not closed and (i == 0 or i == n - 1)) or r <= 1e-9:
            out.append(p)
            continue
        a, b = pts[i - 1], pts[(i + 1) % n]
        va, vb = a - p, b - p
        la, lb = np.linalg.norm(va), np.linalg.norm(vb)
        d = min(r, 0.48 * la, 0.48 * lb)
        t1, t2 = p + va / la * d, p + vb / lb * d
        for k in range(seg + 1):
            t = k / seg
            out.append((1 - t) ** 2 * t1 + 2 * t * (1 - t) * p + t ** 2 * t2)
    return out


def lathe(profile, segs=64, closed=False, brass=None):
    """Revolve (r, z) points around Z. Poles (r ~ 0) become single vertices. brass=(cells, vlo, vhi) writes
    arc-length UVs for the brass atlas (u wraps `cells` times around, v runs along the profile)."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.verify()
    m = len(profile)
    rows = []
    for r, z in profile:
        if r < 1e-6:
            rows.append([bm.verts.new((0, 0, z))])
        else:
            rows.append([bm.verts.new((r * math.cos(math.tau * i / segs), r * math.sin(math.tau * i / segs), z))
                         for i in range(segs)])
    s = [0.0]
    for j in range(1, m):
        s.append(s[-1] + math.hypot(profile[j][0] - profile[j - 1][0], profile[j][1] - profile[j - 1][1]))
    total = s[-1]
    nseg = m - 1
    if closed:
        total += math.hypot(profile[0][0] - profile[-1][0], profile[0][1] - profile[-1][1])
        nseg = m
    total = max(total, 1e-9)
    for j in range(nseg):
        j2 = (j + 1) % m
        sa = s[j] / total
        sb = (s[j2] if j2 else total) / total
        for i in range(segs):
            i2 = (i + 1) % segs
            ra, rb = rows[j], rows[j2]
            corners = [
                (ra[i] if len(ra) > 1 else ra[0], (i, sa)),
                (ra[i2] if len(ra) > 1 else ra[0], (i + 1, sa)),
                (rb[i2] if len(rb) > 1 else rb[0], (i + 1, sb)),
                (rb[i] if len(rb) > 1 else rb[0], (i, sb)),
            ]
            clean = []
            for v, uvp in corners:
                if clean and clean[-1][0] is v:
                    continue
                clean.append((v, uvp))
            if len(clean) > 1 and clean[0][0] is clean[-1][0]:
                clean.pop()
            if len(clean) < 3:
                continue
            try:
                f = bm.faces.new([c[0] for c in clean])
            except ValueError:
                continue
            if brass:
                cells, vlo, vhi = brass
                for loop, (_, (ci, sv)) in zip(f.loops, clean):
                    loop[uvl].uv = (ci / segs * cells, vlo + sv * (vhi - vlo))
    return bm


def ellipsoid(rx, rz, t0=-90, t1=90, n=14):
    pts = [(rx * math.cos(math.radians(t)), rz * math.sin(math.radians(t)))
           for t in np.linspace(t0, t1, n + 1)]
    if pts[0][0] > 1e-6:
        pts.insert(0, (0.0, pts[0][1]))
    if pts[-1][0] > 1e-6:
        pts.append((0.0, pts[-1][1]))
    return pts


def ring_profile(pts, radii, seg=4):
    return fillet(pts, radii, seg, closed=True)


def solid_profile(pts, radii, seg=4):
    return fillet(pts, radii, seg, closed=False)


def box(size, bevel=0.01, seg=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = (v.co.x * size[0], v.co.y * size[1], v.co.z * size[2])
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, min(size) * 0.45), offset_type="OFFSET",
                        segments=seg, profile=0.5, affect="EDGES")
    return bm


def icosphere(radius, scale=(1, 1, 1), jitter=0.0, seed=0, sub=2):
    bm = bmesh.new()
    try:
        bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=radius)
    except TypeError:
        bmesh.ops.create_icosphere(bm, subdivisions=sub, diameter=radius)
    rng = random.Random(seed)
    for v in bm.verts:
        k = 1 + jitter * (rng.random() * 2 - 1)
        v.co = (v.co.x * scale[0] * k, v.co.y * scale[1] * k, v.co.z * scale[2] * k)
    return bm


def loft(outline, prof):
    """Sweep a closed 2D outline through (scale, z) stations and cap both ends."""
    bm = bmesh.new()
    rings = [[bm.verts.new((p[0] * s, p[1] * s, z)) for p in outline] for s, z in prof]
    n = len(outline)
    for j in range(len(prof) - 1):
        for i in range(n):
            bm.faces.new([rings[j][i], rings[j][(i + 1) % n], rings[j + 1][(i + 1) % n], rings[j + 1][i]])
    bm.faces.new(rings[-1])
    bm.faces.new(rings[0][::-1])
    return bm


def frame(d, pos):
    """Local x = horizontal tangent, y = up, z = outward along horizontal direction d."""
    t = Vector((-d.y, d.x, 0))
    return Matrix(((t.x, 0, d.x, pos.x), (t.y, 0, d.y, pos.y), (t.z, 1, d.z, pos.z), (0, 0, 0, 1)))


def radial(angle_deg, r0, z):
    a = math.radians(angle_deg)
    d = Vector((math.cos(a), math.sin(a), 0))
    return frame(d, d * r0 + Vector((0, 0, z)))


# --------------------------------------------------------------------------------------------------
# UV modes
# --------------------------------------------------------------------------------------------------


def uv_world(bm, tile):
    uvl = bm.loops.layers.uv.verify()
    bm.normal_update()
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for lp in f.loops:
            c = lp.vert.co
            u, v = (c.y, c.z) if ax == 0 else (c.x, c.z) if ax == 1 else (c.x, c.y)
            lp[uvl].uv = (u / tile, v / tile)


def uv_const(bm, uv):
    uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for lp in f.loops:
            lp[uvl].uv = uv


def uv_gem(bm, region):
    """Planar per-facet projection normalised to the part's bounding box, placed in an atlas half."""
    u0, u1, v0, v1 = region
    uvl = bm.loops.layers.uv.verify()
    bm.normal_update()
    co = np.array([v.co[:] for v in bm.verts])
    mn, mx = co.min(0), co.max(0)
    span = np.maximum(mx - mn, 1e-6)
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        ia, ib = {0: (1, 2), 1: (0, 2), 2: (0, 1)}[ax]
        for lp in f.loops:
            c = lp.vert.co
            a = (c[ia] - mn[ia]) / span[ia]
            b = (c[ib] - mn[ib]) / span[ib]
            lp[uvl].uv = (u0 + a * (u1 - u0), v0 + b * (v1 - v0))


MINT = (0.02, 0.48, 0.02, 0.98)
VIOLET = (0.52, 0.98, 0.02, 0.98)

# --------------------------------------------------------------------------------------------------
# object groups
# --------------------------------------------------------------------------------------------------
SCENE = None
GROUPS = {}


class Group:
    def __init__(self, name, mat, parent, smooth=True, ao=True):
        self.name, self.mat, self.parent, self.smooth, self.ao = name, mat, parent, smooth, ao
        self.bm = bmesh.new()
        self.bm.loops.layers.uv.verify()
        self.obj = None

    def add(self, src, matrix=None, uv=("world",)):
        if uv[0] == "gem":
            uv_gem(src, uv[1])
        elif uv[0] == "const":
            uv_const(src, uv[1])
        if matrix is not None:
            bmesh.ops.transform(src, matrix=matrix, verts=src.verts)
        bmesh.ops.recalc_face_normals(src, faces=src.faces)
        if uv[0] == "world":
            uv_world(src, TILE)
        dst, duv = self.bm, self.bm.loops.layers.uv.verify()
        suv = src.loops.layers.uv.verify()
        vm = {v: dst.verts.new(v.co) for v in src.verts}
        for f in src.faces:
            nf = dst.faces.new([vm[v] for v in f.verts])
            nf.smooth = f.smooth
            for ln, lo in zip(nf.loops, f.loops):
                ln[duv].uv = lo[suv].uv
        src.free()

    def build(self):
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        for f in bm.faces:
            f.smooth = self.smooth
        if self.smooth:
            for e in bm.edges:
                if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > SHARP:
                    e.smooth = False
        mesh = bpy.data.meshes.new(self.name)
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(self.mat)
        self.obj = bpy.data.objects.new(self.name, mesh)
        SCENE.collection.objects.link(self.obj)
        return self.obj


def group(name, mat, parent, **kw):
    if name not in GROUPS:
        GROUPS[name] = Group(name, mat, parent, **kw)
    return GROUPS[name]


def empty(name, pos=(0, 0, 0), parent=None):
    o = bpy.data.objects.new(name, None)
    SCENE.collection.objects.link(o)
    o.location = pos
    if parent is not None:
        o.parent = parent
        o.matrix_parent_inverse = Matrix.Translation(-parent.location)
    return o


# --------------------------------------------------------------------------------------------------
# ambient occlusion into vertex colours
# --------------------------------------------------------------------------------------------------


def bake_ao(objs, skip, samples=28, dist=0.32, floor=0.55):
    bpy.context.view_layer.update()
    verts, tris = [], []
    for o in objs:
        if o.name in skip:
            continue
        base = len(verts)
        verts.extend(o.matrix_world @ v.co for v in o.data.vertices)
        o.data.calc_loop_triangles()
        tris.extend(tuple(base + i for i in t.vertices) for t in o.data.loop_triangles)
    tree = BVHTree.FromPolygons(verts, tris)
    rng = random.Random(7)
    for o in objs:
        if o.name in skip:
            continue
        mesh = o.data
        nm = o.matrix_world.to_3x3().inverted().transposed()
        vals = []
        for v in mesh.vertices:
            pos = o.matrix_world @ v.co
            n = (nm @ v.normal).normalized()
            tan = n.cross(Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))).normalized()
            bit = n.cross(tan)
            org = pos + n * 0.004
            hits = 0.0
            for _ in range(samples):
                r1, r2 = rng.random(), rng.random()
                rad, ang = math.sqrt(r1), math.tau * r2
                dr = tan * (rad * math.cos(ang)) + bit * (rad * math.sin(ang)) + n * math.sqrt(1 - r1)
                h = tree.ray_cast(org, dr, dist)
                if h[0] is not None:
                    hits += 1.0 - h[3] / dist
            vals.append(floor + (1 - floor) * (1 - hits / samples) ** 1.4)
        col = mesh.color_attributes.new("AO", "BYTE_COLOR", "CORNER")
        for lp in mesh.loops:
            x = vals[lp.vertex_index]
            col.data[lp.index].color = (x, x, x, 1.0)
        mesh.color_attributes.active_color = col
        mesh.color_attributes.render_color_index = list(mesh.color_attributes).index(col)


# --------------------------------------------------------------------------------------------------
# the model
# --------------------------------------------------------------------------------------------------


def build():
    global SCENE
    bpy.ops.wm.read_factory_settings(use_empty=True)
    SCENE = bpy.context.scene
    IMG["paint"] = make_image("tex_paint", tex_paint())
    IMG["normal"] = make_image("tex_paint_normal", tex_normal(), data=True)
    IMG["brass"] = make_image("tex_brass", tex_brass())
    IMG["gem"] = make_image("tex_gem", tex_gem())

    teal = mat_paint("Teal enamel", (0.06, 0.55, 0.56))
    teal_deep = mat_paint("Teal deep", (0.06, 0.34, 0.38), normal=0.2)
    coral = mat_paint("Coral enamel", (0.80, 0.19, 0.13), rough=0.55, coat=0.12)
    cream = mat_paint("Cream cap", (0.93, 0.78, 0.48), rough=0.34)
    dark = mat_paint("Graphite", (0.17, 0.17, 0.23), rough=0.4, normal=0.2)
    brass = mat_brass()
    mint_glass = mat_gem("Mint crystal glass", 0.22, rough=0.06, alpha=0.9, coat=0.0)
    mint_core = mat_gem("Mint core glow", 0.7, rough=0.2)
    mint_jewel = mat_gem("Mint jewel", 0.2, rough=0.08, coat=0.0)
    violet = mat_gem("Violet crystal", 0.3, rough=0.1, coat=0.3)
    glint = mat_glint()

    root = empty("ResonanceEngine")
    AIM_Z = 0.80
    aim = empty("Aim", (0, 0, AIM_Z), root)

    def S(name, mat, ao=True, smooth=True):  # static group
        return group(name, mat, root, ao=ao, smooth=smooth)

    def A(name, mat, ao=True, smooth=True):  # rotating (Aim) group
        return group(name, mat, aim, ao=ao, smooth=smooth)

    T = Matrix.Translation
    BR_PLAIN = (6, 0.02, 0.48)

    # ---------------- static base ----------------
    outline = fillet([(0.64 * math.cos(k * math.pi / 4), 0.64 * math.sin(k * math.pi / 4)) for k in range(8)],
                     0.11, 4, closed=True)
    slab = loft(outline, [(0.90, 0.040), (0.975, 0.058), (1.0, 0.090), (1.0, 0.125), (0.985, 0.133),
                          (0.985, 0.153), (1.0, 0.161), (1.0, 0.215), (0.965, 0.245), (0.92, 0.255)])
    S("Base_Slab", coral).add(slab)

    disc = lathe(solid_profile([(0, 0.245), (0.47, 0.245), (0.47, 0.292), (0.435, 0.322), (0, 0.322)],
                               [0, 0, 0.02, 0.05, 0]), 72)
    S("Base_Disc", teal).add(disc)
    # service notch on the teal disc (front-right in the concept)
    notch_m = radial(125, 0.385, 0.31)
    S("Base_Notch", dark).add(box((0.23, 0.09, 0.15), 0.014), notch_m)
    dot = lathe(ellipsoid(0.04, 0.034, 0, 90, 8), 16)
    S("Base_NotchLamp", teal).add(dot, radial(108, 0.45, 0.318))

    neck = lathe(solid_profile([(0, 0.30), (0.22, 0.30), (0.22, 0.53), (0, 0.53)], [0, 0, 0, 0]), 48)
    S("Neck", dark).add(neck)
    collar = lathe(ring_profile([(0.20, 0.30), (0.34, 0.30), (0.355, 0.335), (0.335, 0.405), (0.285, 0.440),
                                 (0.20, 0.440)], [0, 0.02, 0.02, 0.03, 0.02, 0]), 64)
    S("Neck_Collar", coral).add(collar)

    for k in range(4):
        a = math.radians(k * 90)
        foot = lathe(solid_profile([(0, 0), (0.115, 0), (0.115, 0.085), (0, 0.085)], [0, 0, 0.02, 0]), 32)
        S("Feet", dark).add(foot, T(Vector((math.cos(a) * 0.585, math.sin(a) * 0.585, 0))))
        cap = lathe(ellipsoid(0.092, 0.07, 0, 90, 10), 32)
        S("Feet_Caps", cream).add(cap, T(Vector((math.cos(a) * 0.585, math.sin(a) * 0.585, 0.082))))

    # ---------------- rotating head ----------------
    DZ = 0.11  # the collar / crown assembly sits this much higher than the first draft
    HC, HRZ = 0.86, 0.43  # housing ellipsoid centre height and vertical radius
    zcut = 0.915 + DZ + 0.06
    tmax = math.degrees(math.asin((zcut - HC) / HRZ))
    housing = lathe([(r, z + HC) for r, z in ellipsoid(0.47, HRZ, -90, tmax, 24)], 96)
    A("Housing", teal).add(housing)

    skirt = lathe(ring_profile([(0.15, 0.49), (0.385, 0.49), (0.405, 0.54), (0.395, 0.60), (0.15, 0.60)],
                               [0, 0.02, 0.03, 0.02, 0]), 80)
    A("Skirt", coral).add(skirt)

    # brass collar: 8 segments (seams in the texture) + rivets
    collar_b = lathe(ring_profile([(0.445, 0.915 + DZ), (0.560, 0.915 + DZ), (0.590, 0.990 + DZ),
                                   (0.572, 1.070 + DZ), (0.450, 1.085 + DZ), (0.442, 1.000 + DZ)],
                                  [0, 0.02, 0.035, 0.03, 0.012, 0.01], 5), 96, brass=(8, 0.52, 0.98))
    A("Collar_Ring", brass).add(collar_b, uv=("keep",))
    for k in range(8):
        a = math.radians(22.5 + 45 * k)
        riv = lathe(ellipsoid(0.021, 0.014, 0, 90, 8), 14)
        A("Collar_Rivets", brass).add(riv, T(Vector((math.cos(a) * 0.512, math.sin(a) * 0.512, 1.0745 + DZ))),
                                      uv=("const", (0.3, 0.25)))
    knob = lathe(ellipsoid(0.032, 0.032, -90, 90, 10), 18)
    a = math.radians(125)
    A("Collar_Knob", brass).add(knob, T(Vector((math.cos(a) * 0.588, math.sin(a) * 0.588, 0.99 + DZ))),
                                uv=("const", (0.3, 0.25)))

    ledge = lathe(solid_profile([(0, 0.90 + DZ), (0.446, 0.90 + DZ), (0.446, 0.992 + DZ), (0.375, 0.972 + DZ),
                                 (0, 0.972 + DZ)], [0, 0, 0.008, 0, 0]), 96)
    A("Ledge", teal).add(ledge)
    inner = lathe(ring_profile([(0.262, 0.975 + DZ), (0.36, 0.975 + DZ), (0.373, 1.040 + DZ),
                                (0.352, 1.120 + DZ), (0.272, 1.126 + DZ), (0.258, 1.070 + DZ)],
                               [0, 0, 0.03, 0.03, 0.012, 0.01], 5), 80, brass=(10, 0.03, 0.47))
    A("Inner_Ring", brass).add(inner, uv=("keep",))
    FL = 1.03 + DZ  # well floor
    well = lathe(solid_profile([(0, FL - 0.08), (0.268, FL - 0.08), (0.268, FL - 0.03), (0.24, FL), (0, FL)],
                               [0, 0, 0.01, 0.02, 0]), 72)
    A("Well", teal_deep).add(well)

    # six violet crystal spikes on dark bases, ringed around the orb (one dead ahead on +Y)
    for k in range(6):
        a = math.radians(90 + 60 * k)
        p = Vector((math.cos(a) * 0.225, math.sin(a) * 0.225, FL))
        base = lathe(solid_profile([(0, 0), (0.05, 0), (0.05, 0.026), (0.04, 0.034), (0, 0.034)],
                                   [0, 0, 0.008, 0.01, 0]), 20)
        A("Spike_Bases", dark).add(base, T(p))
        sp = lathe([(0, 0), (0.034, 0), (0.034, 0.17), (0, 0.24)], 6)
        A("Spikes", violet, ao=False, smooth=False).add(
            sp, T(p + Vector((0, 0, 0.030))) @ Matrix.Rotation(math.pi / 6, 4, "Z"), uv=("gem", VIOLET))

    # glass orb + core + glints
    OR = 0.19
    OC = Vector((0, 0, FL + OR - 0.012))
    orb = icosphere(OR, (1, 1, 1), 0.035, 3, 2)
    A("Orb", mint_glass, ao=False, smooth=False).add(orb, T(OC), uv=("gem", MINT))
    core = icosphere(0.115, (1, 1, 1), 0.03, 5, 1)
    A("Orb_Core", mint_core, ao=False, smooth=False).add(core, T(OC), uv=("gem", MINT))
    for d, r in (((0.40, 0.46, 0.80), 0.030), ((0.78, 0.18, 0.60), 0.015), ((0.15, 0.55, 0.40), 0.010)):
        dv = Vector(d).normalized()
        g = lathe(ellipsoid(r, r * 0.45, -90, 90, 8), 12)
        m = Matrix.Translation(OC + dv * (OR - 0.004)) @ dv.to_track_quat("Z", "Y").to_matrix().to_4x4()
        A("Orb_Glints", glint, ao=False, smooth=True).add(g, m, uv=("const", (0.5, 0.5)))

    # ---------------- side ports ----------------
    ZP = 0.80
    R0 = 0.40
    port_angles = {50: "jewel", 130: "button", -50: "jewel", -130: "button"}
    for ang, kind in port_angles.items():
        M = radial(ang, R0, ZP)
        ring = lathe(ring_profile([(0.108, -0.12), (0.160, -0.12), (0.160, 0.100), (0.148, 0.135),
                                   (0.112, 0.135)], [0, 0, 0.028, 0.018, 0.008], 5), 64,
                     brass=(8, 0.03, 0.47))
        A("Port_Rings", brass).add(ring, M, uv=("keep",))
        step = lathe(ring_profile([(0.078, -0.1), (0.112, -0.1), (0.112, 0.086), (0.078, 0.086)],
                                  [0, 0, 0.012, 0.012], 4), 56, brass=(6, 0.03, 0.47))
        A("Port_Steps", brass).add(step, M, uv=("keep",))
        sock = lathe(solid_profile([(0, -0.10), (0.114, -0.10), (0.114, 0.035), (0, 0.035)], [0, 0, 0, 0]), 48)
        A("Port_Sockets", dark).add(sock, M)
        if kind == "jewel":
            gj = icosphere(0.092, (1, 1, 0.62), 0.03, ang + 7, 2)
            A("Port_Jewels", mint_jewel, ao=False, smooth=False).add(gj, M @ T(Vector((0, 0, 0.045))),
                                                                    uv=("gem", MINT))
        else:
            btn = lathe(solid_profile([(0, 0.0), (0.090, 0.0), (0.090, 0.112), (0.074, 0.136), (0, 0.141)],
                                      [0, 0, 0.012, 0.034, 0]), 48)
            A("Port_Buttons", cream).add(btn, M)

    # front panel and back vent
    A("Front_Panel", dark).add(box((0.16, 0.15, 0.05), 0.014), radial(90, R0, ZP) @ T(Vector((0, 0, 0.055))))
    vent_m = radial(270, R0, ZP) @ T(Vector((0, 0, 0.055)))
    A("Vent_Plate", dark).add(box((0.20, 0.15, 0.05), 0.014), vent_m)
    for i in range(4):
        slat = box((0.16, 0.014, 0.014), 0.004, 1)
        A("Vent_Slats", brass).add(slat, vent_m @ T(Vector((0, -0.048 + i * 0.032, 0.028))),
                                   uv=("const", (0.3, 0.25)))
    # small brass side lugs
    for ang in (0, 180):
        M = radial(ang, 0.40, 0.95)
        lug = lathe(solid_profile([(0, -0.05), (0.052, -0.05), (0.052, 0.095), (0.036, 0.12), (0, 0.124)],
                                  [0, 0, 0.018, 0.02, 0]), 32, brass=(4, 0.03, 0.47))
        A("Side_Lugs", brass).add(lug, M, uv=("keep",))
        back = lathe(solid_profile([(0, -0.05), (0.075, -0.05), (0.075, 0.03), (0, 0.03)], [0, 0, 0.01, 0]), 32)
        A("Side_Lug_Plates", dark).add(back, M)

    # ---------------- finish ----------------
    objs = []
    for g in GROUPS.values():
        o = g.build()
        o.parent = g.parent
        if g.parent is aim:
            o.matrix_parent_inverse = Matrix.Translation(-aim.location)
        objs.append(o)
    muzzle = empty("Muzzle", (0, 0.585, 1.09 + 0.11), aim)

    skip = {g.name for g in GROUPS.values() if not g.ao}
    bake_ao(objs, skip)
    return objs


def stats(objs):
    tris = 0
    for o in objs:
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
    mats = {m.name for o in objs for m in o.data.materials}
    print(f"STATS triangles={tris} mesh_objects={len(objs)} materials={len(mats)}")


if __name__ == "__main__":
    objects = build()
    stats(objects)
    bpy.ops.export_scene.gltf(filepath=str(OUT / "cp_resonance_engine.glb"), export_format="GLB", export_yup=True,
                              export_animations=False, export_cameras=False, export_lights=False,
                              export_vertex_color="ACTIVE")

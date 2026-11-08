"""Tech Vault - hero supply crate with a glass window onto a glowing energy core.

Run: blender --background --python build_tech_vault.py
Builds everything from scratch with bmesh, generates 4 procedural 1024px textures with numpy, exports tech_vault.glb.
Metres, Blender +Z up, window faces +Y. Static parts are merged into one object per material; the core sphere and the
two orbit rings are separate objects under their own pivot empties (Core, Ring_Outer, Ring_Inner).
"""
import math
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
TEX_DIR = HERE / "textures"
TEX_DIR.mkdir(exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
SCENE = bpy.context.scene

SHARP = math.radians(35)
UV_TILE = 0.6           # metres per repeat of the tiling metal textures
UV_NAME = "UVMap"
TEX = 1024

# Shell dimensions
HS = 0.46               # half size of the shell box (x, y)
Z0, Z1 = 0.10, 0.96     # shell bottom / top
CH = 0.06               # big chamfer on every shell edge
FLAT = HS - CH          # half extent of the flat region on each face
CORE_C = Vector((0.0, 0.10, 0.575))
CAV_HW, CAV_Z0, CAV_Z1, CAV_BACK = 0.325, 0.185, 0.875, -0.372


# --------------------------------------------------------------------------------------------------------------------
# Procedural textures
# --------------------------------------------------------------------------------------------------------------------
rng = np.random.default_rng(1234)
FY = np.fft.fftfreq(TEX)[:, None] * TEX
FX = np.fft.fftfreq(TEX)[None, :] * TEX


def pnoise(cutoff, ax=1.0, ay=1.0):
    """Periodic (seamless) gaussian-filtered noise, normalised to unit std."""
    white = rng.standard_normal((TEX, TEX))
    f = np.hypot(FX / ax, FY / ay)
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * np.exp(-(f / cutoff) ** 2)))
    return (out - out.mean()) / (out.std() + 1e-9)


def splats(count, radius, soft=1.0):
    """Periodic field of small disks (pits, specks); 0..1."""
    imp = np.zeros((TEX, TEX))
    idx = rng.integers(0, TEX, (count, 2))
    np.add.at(imp, (idx[:, 0], idx[:, 1]), rng.uniform(0.6, 1.0, count))
    d = np.hypot(np.minimum(np.arange(TEX), TEX - np.arange(TEX))[:, None],
                 np.minimum(np.arange(TEX), TEX - np.arange(TEX))[None, :])
    kernel = np.clip((radius + soft * 0.5 - d) / soft, 0, 1)
    out = np.real(np.fft.ifft2(np.fft.fft2(imp) * np.fft.fft2(kernel)))
    return np.clip(out, 0, 1)


def save_image(name, rgb, non_color):
    img = bpy.data.images.new(name, TEX, TEX, alpha=False)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    px = np.concatenate([np.clip(rgb, 0, 1), np.ones((TEX, TEX, 1))], axis=2).astype(np.float32)
    img.pixels.foreach_set(px.ravel())
    img.filepath_raw = str(TEX_DIR / f"{name}.png")
    img.file_format = "PNG"
    img.save()
    return img


def build_metal_textures():
    m1, m2, m3 = pnoise(4), pnoise(22), pnoise(140)
    streak = pnoise(70, ax=0.04, ay=1.0)             # faint horizontal machining streaks
    pits = splats(900, 1.2)
    dings = splats(40, 3.0, soft=2.0)
    specks = splats(450, 0.9)
    v = 0.86 + 0.010 * m1 + 0.014 * m2 + 0.016 * m3 + 0.012 * streak - 0.32 * pits - 0.05 * dings + 0.10 * specks
    v = np.clip(v, 0, 1)
    base = np.stack([v * 0.975, v * 0.99, v], axis=2)
    rough = np.clip(0.42 + 0.012 * m1 + 0.018 * m2 + 0.02 * m3 - 0.025 * streak + 0.30 * pits + 0.08 * dings, 0.12, 0.95)
    metal = np.clip(0.78 - 0.45 * pits, 0, 1)
    orm = np.stack([np.ones_like(v), rough, metal], axis=2)
    h = -0.75 * pits - 0.5 * dings + 0.05 * m3 + 0.025 * streak + 0.4 * specks
    k = 2.2
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * k
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * k
    n = np.stack([-dx, -dy, np.ones_like(h)], axis=2)
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return (save_image("vault_metal_base", base, False), save_image("vault_metal_orm", orm, True),
            save_image("vault_metal_normal", n * 0.5 + 0.5, True))


def build_circuit_texture():
    """Dark teal board with cyan / gold traces, pads, chips. Used as base colour AND emission (dark board barely glows)."""
    img = np.zeros((TEX, TEX, 3))
    img[:] = (0.05, 0.10, 0.13)
    img *= (1 + 0.08 * pnoise(30)[..., None])
    grid = ((np.arange(TEX) % 32) == 0)
    img[grid, :] *= 1.25
    img[:, grid] *= 1.25
    cyan, gold, dim = (0.35, 0.95, 1.0), (0.78, 0.6, 0.24), (0.14, 0.34, 0.42)
    cell = 16

    def rect(x0, y0, x1, y1, col):
        x0, x1 = sorted((int(np.clip(x0, 0, TEX)), int(np.clip(x1, 0, TEX))))
        y0, y1 = sorted((int(np.clip(y0, 0, TEX)), int(np.clip(y1, 0, TEX))))
        img[y0:y1, x0:x1] = col

    def pad(cx, cy, r, col):
        y0, y1, x0, x1 = max(cy - r - 1, 0), min(cy + r + 2, TEX), max(cx - r - 1, 0), min(cx + r + 2, TEX)
        yy, xx = np.mgrid[y0:y1, x0:x1]
        d = np.hypot(xx - cx, yy - cy)
        ring = (d <= r) & (d >= r * 0.45)
        img[y0:y1, x0:x1][ring] = col
        img[y0:y1, x0:x1][d < r * 0.45] = (0.02, 0.03, 0.04)

    for i in range(70):
        col = cyan if i % 5 in (0, 1) else gold if i % 5 in (2, 3) else dim
        w = 5 if i % 7 == 0 else 3
        x, y = int(rng.integers(2, TEX // cell - 2)) * cell, int(rng.integers(2, TEX // cell - 2)) * cell
        pad(x, y, 6, col)
        horiz = bool(rng.integers(0, 2))
        for _ in range(int(rng.integers(2, 5))):
            step = int(rng.integers(3, 16)) * cell * (1 if rng.random() < 0.5 else -1)
            if horiz:
                nx = int(np.clip(x + step, cell, TEX - cell))
                rect(x, y - w // 2, nx, y + w - w // 2, col)
                x = nx
            else:
                ny = int(np.clip(y + step, cell, TEX - cell))
                rect(x - w // 2, y, x + w - w // 2, ny, col)
                y = ny
            horiz = not horiz
        pad(x, y, 6, col)
    for _ in range(9):
        cw, chh = int(rng.integers(5, 10)) * cell, int(rng.integers(4, 8)) * cell
        cx, cy = int(rng.integers(2, TEX // cell - 10)) * cell, int(rng.integers(2, TEX // cell - 9)) * cell
        rect(cx - 6, cy - 6, cx + cw + 6, cy + chh + 6, (0.03, 0.05, 0.06))
        for px in range(cx + 4, cx + cw - 2, 10):
            rect(px, cy - 6, px + 4, cy - 1, gold)
            rect(px, cy + chh + 1, px + 4, cy + chh + 6, gold)
        rect(cx, cy, cx + cw, cy + chh, (0.07, 0.08, 0.09))
        rect(cx + 6, cy + chh - 14, cx + 14, cy + chh - 6, cyan)
    return save_image("vault_circuit", np.clip(img, 0, 1), False)


IMG_BASE, IMG_ORM, IMG_NRM = build_metal_textures()
IMG_CIRCUIT = build_circuit_texture()


# --------------------------------------------------------------------------------------------------------------------
# Materials
# --------------------------------------------------------------------------------------------------------------------
def _principled(name):
    mat = bpy.data.materials.new(name)
    try:
        mat.use_nodes = True
    except AttributeError:
        pass
    return mat, mat.node_tree, mat.node_tree.nodes.get("Principled BSDF")


def mat_metal(name, color, normal_strength=0.7, emit=None):
    """Tiling metal: generated base colour multiplied by a tint (exports as baseColorFactor), ORM + normal maps."""
    mat, nt, p = _principled(name)
    mat.diffuse_color = (*color, 1)
    tb = nt.nodes.new("ShaderNodeTexImage")
    tb.image = IMG_BASE
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 1.0
    mix.inputs[7].default_value = (*color, 1)
    nt.links.new(tb.outputs["Color"], mix.inputs[6])
    nt.links.new(mix.outputs[2], p.inputs["Base Color"])
    to = nt.nodes.new("ShaderNodeTexImage")
    to.image = IMG_ORM
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(to.outputs["Color"], sep.inputs[0])
    nt.links.new(sep.outputs[1], p.inputs["Roughness"])
    nt.links.new(sep.outputs[2], p.inputs["Metallic"])
    tn = nt.nodes.new("ShaderNodeTexImage")
    tn.image = IMG_NRM
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nm.inputs["Strength"].default_value = normal_strength
    nt.links.new(tn.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    if emit:
        p.inputs["Emission Color"].default_value = (*emit, 1)
        p.inputs["Emission Strength"].default_value = 1.0
    return mat


def mat_circuit(name):
    mat, nt, p = _principled(name)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = IMG_CIRCUIT
    nt.links.new(tex.outputs["Color"], p.inputs["Base Color"])
    nt.links.new(tex.outputs["Color"], p.inputs["Emission Color"])
    p.inputs["Emission Strength"].default_value = 2.0
    p.inputs["Metallic"].default_value = 0.2
    p.inputs["Roughness"].default_value = 0.35
    return mat


def mat_emit(name, color, strength, alpha=1.0, base=None):
    mat, nt, p = _principled(name)
    mat.diffuse_color = (*color, alpha)
    p.inputs["Base Color"].default_value = (*(base or color), 1)
    p.inputs["Emission Color"].default_value = (*color, 1)
    p.inputs["Emission Strength"].default_value = strength
    p.inputs["Roughness"].default_value = 0.3
    if alpha < 1.0:
        p.inputs["Alpha"].default_value = alpha
        _blended(mat)
    return mat


def _blended(mat):
    for attr, value in (("surface_render_method", "BLENDED"), ("blend_method", "BLEND")):
        try:
            setattr(mat, attr, value)
        except (AttributeError, TypeError):
            pass
    try:
        mat.use_backface_culling = False
    except AttributeError:
        pass


def mat_glass(name):
    mat, nt, p = _principled(name)
    p.inputs["Base Color"].default_value = (0.36, 0.56, 0.62, 1)
    p.inputs["Metallic"].default_value = 0.0
    p.inputs["Roughness"].default_value = 0.04
    p.inputs["Alpha"].default_value = 0.07
    mat.diffuse_color = (0.62, 0.86, 0.95, 0.07)
    _blended(mat)
    mat.use_backface_culling = True
    return mat


M = {
    "Gunmetal": mat_metal("Gunmetal", (0.15, 0.155, 0.17), 0.5),
    "Steel": mat_metal("Steel", (0.36, 0.37, 0.39), 0.4),
    "Interior": mat_metal("Interior", (0.13, 0.27, 0.33), emit=(0.02, 0.19, 0.25)),
    "Brass": mat_metal("Brass", (0.80, 0.58, 0.22), 0.3),
    "Copper": mat_metal("Copper", (0.72, 0.36, 0.18), 0.3),
    "Circuit": mat_circuit("Circuit"),
    "Trim": mat_emit("Trim_Glow", (0.15, 0.85, 1.0), 5.0),
    "CoreGlow": mat_emit("Core_Glow", (0.55, 0.95, 1.0), 8.0),
    "CoreHalo": mat_emit("Core_Halo", (0.2, 0.85, 1.0), 2.5, alpha=0.22),
    "Beam": mat_emit("Beam_Glow", (0.2, 0.85, 1.0), 1.2, alpha=0.05),
    "LED": mat_emit("LED_Red", (1.0, 0.08, 0.04), 5.0),
    "Glass": mat_glass("Window_Glass"),
}


# --------------------------------------------------------------------------------------------------------------------
# Geometry helpers (all geometry built in bmesh; parts are collected per material and merged at the end)
# --------------------------------------------------------------------------------------------------------------------
class Assembly:
    """One output object: a growing bmesh plus its material list (face material_index set per added part)."""

    def __init__(self, name, mats):
        self.name, self.mats, self.bm = name, mats, bmesh.new()

    def add(self, part, mat_key=None):
        idx = self.mats.index(mat_key) if mat_key else 0
        for f in part.faces:
            f.material_index = idx
        me = bpy.data.meshes.new("_tmp")
        part.to_mesh(me)
        part.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)


STATIC = {}


def S(key):
    """Static per-material assembly."""
    if key not in STATIC:
        STATIC[key] = Assembly(f"Vault_{key}", [key])
    return STATIC[key]


def bevel_bm(bm, width, segs=2, angle=SHARP):
    if width <= 0:
        return
    edges = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0.0) > angle]
    if edges:
        bmesh.ops.bevel(bm, geom=edges, offset=width, offset_type="OFFSET", segments=segs, profile=0.5,
                        affect="EDGES", clamp_overlap=True)


def orient(center, axis, spin=0.0):
    """Matrix placing local +Z along `axis` at `center`, optionally spun about that axis."""
    axis = Vector(axis).normalized()
    q = Vector((0, 0, 1)).rotation_difference(axis)
    return Matrix.Translation(Vector(center)) @ q.to_matrix().to_4x4() @ Matrix.Rotation(spin, 4, "Z")


def box(target, center, size, bev=0.005, segs=2, rot=None, mat=None):
    bm = bmesh.new()
    mtx = Matrix.Translation(Vector(center)) @ (rot.to_4x4() if rot is not None else Matrix.Identity(4))
    bmesh.ops.create_cube(bm, size=1.0, matrix=mtx @ Matrix.Diagonal((*size, 1)))
    bevel_bm(bm, min(bev, min(size) * 0.3), segs if min(size) > 0.015 else 1)
    target.add(bm, mat)


def box_m(target, mtx, size, bev=0.005, segs=2, mat=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=mtx @ Matrix.Diagonal((*size, 1)))
    bevel_bm(bm, min(bev, min(size) * 0.3), segs)
    target.add(bm, mat)


def box_span(target, a, b, bev=0.005, segs=2, mat=None):
    a, b = Vector(a), Vector(b)
    box(target, (a + b) / 2, [abs(b[i] - a[i]) for i in range(3)], bev, segs, mat=mat)


def cyl(target, center, r, h, axis=(0, 0, 1), segs=24, bev=0.003, mat=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=segs, radius1=r, radius2=r, depth=h,
                          matrix=orient(center, axis))
    bevel_bm(bm, min(bev, r * 0.3, h * 0.3), 2)
    target.add(bm, mat)


def lathe(target, profile, mtx, segs=32, closed=False, mat=None, bev=0.0):
    """Revolve (r, z) profile about local Z. Points with r == 0 collapse to poles."""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        if r < 1e-7:
            rings.append([bm.verts.new(mtx @ Vector((0, 0, z)))])
        else:
            rings.append([bm.verts.new(mtx @ Vector((r * math.cos(math.tau * k / segs),
                                                     r * math.sin(math.tau * k / segs), z))) for k in range(segs)])
    pairs = list(zip(rings[:-1], rings[1:]))
    if closed:
        pairs.append((rings[-1], rings[0]))
    for a, b in pairs:
        if len(a) == 1 and len(b) == 1:
            continue
        for k in range(segs):
            k2 = (k + 1) % segs
            if len(a) == 1:
                bm.faces.new((a[0], b[k], b[k2]))
            elif len(b) == 1:
                bm.faces.new((a[k], b[0], a[k2]))
            else:
                bm.faces.new((a[k], b[k], b[k2], a[k2]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bevel_bm(bm, bev, 1)
    target.add(bm, mat)


def torus(target, R, r, mtx, nR=64, nr=10, mat=None):
    bm = bmesh.new()
    rings = []
    for i in range(nR):
        a = math.tau * i / nR
        rings.append([bm.verts.new(mtx @ Vector(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a),
                                                 r * math.sin(b)))) for b in (math.tau * j / nr for j in range(nr))])
    for i in range(nR):
        for j in range(nr):
            i2, j2 = (i + 1) % nR, (j + 1) % nr
            bm.faces.new((rings[i][j], rings[i2][j], rings[i2][j2], rings[i][j2]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    target.add(bm, mat)


def sphere(target, center, r, u=32, v=16, mat=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=r, matrix=Matrix.Translation(Vector(center)))
    target.add(bm, mat)


def tube(target, pts, r, sides=8, caps=True, mat=None):
    """Sweep a circle along a polyline using parallel-transport frames."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    tans = []
    for i in range(n):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, n - 1)]
        tans.append((b - a).normalized())
    nrm = tans[0].orthogonal().normalized()
    bm = bmesh.new()
    rings = []
    for i in range(n):
        if i > 0:
            nrm = tans[i - 1].rotation_difference(tans[i]) @ nrm
            nrm = (nrm - tans[i] * nrm.dot(tans[i])).normalized()
        bin_ = tans[i].cross(nrm)
        rings.append([bm.verts.new(pts[i] + (nrm * math.cos(math.tau * k / sides) + bin_ * math.sin(math.tau * k / sides)) * r)
                      for k in range(sides)])
    for i in range(n - 1):
        for k in range(sides):
            k2 = (k + 1) % sides
            bm.faces.new((rings[i][k], rings[i + 1][k], rings[i + 1][k2], rings[i][k2]))
    if caps:
        bm.faces.new(rings[0])
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    target.add(bm, mat)


def rounded_path(corners, bend=0.03, steps=6):
    """Polyline through corner points with each interior corner replaced by a quadratic bend."""
    c = [Vector(p) for p in corners]
    out = [c[0]]
    for i in range(1, len(c) - 1):
        din, dout = (c[i] - c[i - 1]), (c[i + 1] - c[i])
        b = min(bend, din.length * 0.45, dout.length * 0.45)
        p0, p2 = c[i] - din.normalized() * b, c[i] + dout.normalized() * b
        for s in range(steps + 1):
            t = s / steps
            out.append(p0 * (1 - t) ** 2 + c[i] * 2 * t * (1 - t) + p2 * t * t)
    out.append(c[-1])
    return out


def helix(center, R, z0, z1, turns, per_turn=32, phase=0.0):
    n = int(turns * per_turn)
    return [Vector((center[0] + R * math.cos(phase + math.tau * turns * i / n), center[1] + R * math.sin(phase + math.tau * turns * i / n),
                    z0 + (z1 - z0) * i / n)) for i in range(n + 1)]


def rrect(hw, hh, r, cz=0.0, seg=8):
    """Rounded rectangle outline (CCW) in (u, v)."""
    pts = []
    for cx, cy, a0 in ((hw - r, hh - r, 0), (-hw + r, hh - r, 90), (-hw + r, -hh + r, 180), (hw - r, -hh + r, 270)):
        for s in range(seg + 1):
            a = math.radians(a0 + 90 * s / seg)
            pts.append((cx + r * math.cos(a), cz + cy + r * math.sin(a)))
    return pts


FRONT_MAP = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # (u, v, w) -> (x, z, y): u=x, v=z, w=y


def ring_prism(target, outer, inner, w0, w1, mtx=FRONT_MAP, bev=0.006, segs=2, mat=None):
    """Extruded ring between two matching outlines (same point counts)."""
    bm = bmesh.new()
    n = len(outer)
    of = [bm.verts.new(mtx @ Vector((u, v, w1))) for u, v in outer]
    ob = [bm.verts.new(mtx @ Vector((u, v, w0))) for u, v in outer]
    inf = [bm.verts.new(mtx @ Vector((u, v, w1))) for u, v in inner]
    ib = [bm.verts.new(mtx @ Vector((u, v, w0))) for u, v in inner]
    for k in range(n):
        k2 = (k + 1) % n
        bm.faces.new((of[k], of[k2], inf[k2], inf[k]))
        bm.faces.new((ob[k], ib[k], ib[k2], ob[k2]))
        bm.faces.new((of[k], ob[k], ob[k2], of[k2]))
        bm.faces.new((inf[k], inf[k2], ib[k2], ib[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bevel_bm(bm, bev, segs)
    target.add(bm, mat)


def slab(target, outline, w0, w1, mtx=FRONT_MAP, bev=0.0, segs=2, mat=None):
    """Extruded solid polygon."""
    bm = bmesh.new()
    front = [bm.verts.new(mtx @ Vector((u, v, w1))) for u, v in outline]
    back = [bm.verts.new(mtx @ Vector((u, v, w0))) for u, v in outline]
    n = len(outline)
    bm.faces.new(front)
    bm.faces.new(back[::-1])
    for k in range(n):
        k2 = (k + 1) % n
        bm.faces.new((front[k], back[k], back[k2], front[k2]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bevel_bm(bm, bev, segs)
    target.add(bm, mat)


def hex_bolt(target, pos, normal, s=0.011, washer=True, mat=None):
    mtx = orient(pos, normal, spin=math.radians(30))
    if washer:
        lathe(target, [(1.35 * s, -0.002), (1.35 * s, 0.12 * s), (1.25 * s, 0.2 * s), (0, 0.2 * s)], mtx, 10, mat=mat)
    lathe(target, [(s, 0.0), (s, 0.55 * s), (0.82 * s, 0.72 * s), (0, 0.72 * s)], mtx, 6, mat=mat)


def rivet(target, pos, normal, r=0.006, mat=None):
    lathe(target, [(r, -0.002), (r, 0.25 * r), (0.72 * r, 0.75 * r), (0, 0.95 * r)],
          orient(pos, normal), 8, mat=mat)


# Face frames for the outer shell: (u, v, w) -> world, w measured outward from the flat face.
FACES = {
    "+X": (Vector((1, 0, 0)), lambda u, v, w: Vector((HS + w, u, v))),
    "-X": (Vector((-1, 0, 0)), lambda u, v, w: Vector((-HS - w, u, v))),
    "+Y": (Vector((0, 1, 0)), lambda u, v, w: Vector((u, HS + w, v))),
    "-Y": (Vector((0, -1, 0)), lambda u, v, w: Vector((u, -HS - w, v))),
    "+Z": (Vector((0, 0, 1)), lambda u, v, w: Vector((u, v, Z1 + w))),
    "-Z": (Vector((0, 0, -1)), lambda u, v, w: Vector((u, v, Z0 - w))),
}


def fp(face, u, v, w):
    return FACES[face][1](u, v, w)


def fbox(face, u0, u1, v0, v1, w0, w1, key="Gunmetal", bev=0.004, segs=2):
    box_span(S(key), fp(face, u0, v0, w0), fp(face, u1, v1, w1), bev, segs)


def fbolt(face, u, v, w, s=0.011):
    hex_bolt(S("Steel"), fp(face, u, v, w), FACES[face][0], s)


def plate(face, u0, u1, v0, v1, t=0.012, rivets=True, key="Gunmetal"):
    fbox(face, u0, u1, v0, v1, -0.01, t, key, bev=0.004, segs=2)
    if rivets:
        ins = 0.022
        us = [u0 + ins, u1 - ins]
        vs = [v0 + ins, v1 - ins]
        for u in us:
            for v in vs:
                if u in (us[0], us[-1]) or v in (vs[0], vs[-1]):
                    rivet(S("Steel"), fp(face, u, v, t), FACES[face][0], 0.0055)


def trim(face, u0, u1, v0, v1, w0=-0.004, w1=0.006):
    fbox(face, u0, u1, v0, v1, w0, w1, "Trim", bev=0.0015, segs=1)


# --------------------------------------------------------------------------------------------------------------------
# Outer shell with the window cavity cut by an exact boolean
# --------------------------------------------------------------------------------------------------------------------
def build_shell():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0, 0, (Z0 + Z1) / 2)) @
                          Matrix.Diagonal((2 * HS, 2 * HS, Z1 - Z0, 1)))
    bmesh.ops.bevel(bm, geom=bm.edges[:], offset=CH, offset_type="OFFSET", segments=1, profile=0.5,
                    affect="EDGES", clamp_overlap=True)
    bevel_bm(bm, 0.008, 2)
    me = bpy.data.meshes.new("shell")
    bm.to_mesh(me)
    bm.free()
    shell = bpy.data.objects.new("shell", me)
    SCENE.collection.objects.link(shell)

    cbm = bmesh.new()
    outline = rrect(CAV_HW, (CAV_Z1 - CAV_Z0) / 2, 0.05, cz=(CAV_Z0 + CAV_Z1) / 2, seg=8)
    front = [cbm.verts.new(FRONT_MAP @ Vector((u, v, 0.62))) for u, v in outline]
    back = [cbm.verts.new(FRONT_MAP @ Vector((u, v, CAV_BACK))) for u, v in outline]
    cbm.faces.new(front)
    cbm.faces.new(back[::-1])
    for k in range(len(outline)):
        k2 = (k + 1) % len(outline)
        cbm.faces.new((front[k], back[k], back[k2], front[k2]))
    bmesh.ops.recalc_face_normals(cbm, faces=cbm.faces[:])
    cme = bpy.data.meshes.new("cutter")
    cbm.to_mesh(cme)
    cbm.free()
    cutter = bpy.data.objects.new("cutter", cme)
    SCENE.collection.objects.link(cutter)

    mod = shell.modifiers.new("cavity", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.object = cutter
    mod.solver = "EXACT"
    dg = bpy.context.evaluated_depsgraph_get()
    ev = shell.evaluated_get(dg)
    res = ev.to_mesh()
    full = bmesh.new()
    full.from_mesh(res)
    ev.to_mesh_clear()
    bpy.data.objects.remove(shell)
    bpy.data.objects.remove(cutter)

    # Split: faces lining the cavity -> Interior, the rest -> Gunmetal.
    for key, want_inside in (("Gunmetal", False), ("Interior", True)):
        part = full.copy()
        kill = []
        for f in part.faces:
            c = f.calc_center_median()
            inside = abs(c.x) < CAV_HW + 0.002 and CAV_Z0 - 0.002 < c.z < CAV_Z1 + 0.002 and CAV_BACK - 0.002 < c.y < HS - 0.004
            if inside != want_inside:
                kill.append(f)
        bmesh.ops.delete(part, geom=kill, context="FACES")
        S(key).add(part)
    full.free()


# --------------------------------------------------------------------------------------------------------------------
# Exterior detail
# --------------------------------------------------------------------------------------------------------------------
def build_exterior():
    F = FLAT - 0.008  # plate extent on the flat faces

    # ---- -X side: vault door face -------------------------------------------------------------------------------
    plate("-X", -F, 0.232, Z0 + 0.068, Z1 - 0.068)
    plate("-X", 0.252, F, Z0 + 0.068, 0.512)
    plate("-X", 0.252, F, 0.528, Z1 - 0.068)
    trim("-X", 0.238, 0.246, 0.56, 0.885)
    trim("-X", 0.238, 0.246, 0.175, 0.33)
    trim("-X", 0.262, 0.33, 0.516, 0.524)
    # Front-edge clamps
    for vc in (0.79, 0.30):
        fbox("-X", 0.272, 0.372, vc - 0.065, vc + 0.065, 0.0, 0.042, bev=0.008, segs=3)
        fbox("-X", 0.282, 0.362, vc - 0.05, vc + 0.05, 0.042, 0.050, bev=0.003)
        fbolt("-X", 0.322, vc + 0.03, 0.05, 0.009)
        fbolt("-X", 0.322, vc - 0.03, 0.05, 0.009)
    # Door
    dc_u, dc_v = -0.06, 0.53
    dm = orient(fp("-X", dc_u, dc_v, 0.012), (-1, 0, 0))
    G, St = S("Gunmetal"), S("Steel")
    lathe(G, [(0, 0), (0.27, 0), (0.27, 0.010), (0.263, 0.018), (0, 0.018)], dm, 72)
    lathe(G, [(0.205, 0.012), (0.205, 0.05), (0.213, 0.066), (0.23, 0.077), (0.25, 0.077), (0.265, 0.069),
              (0.273, 0.054), (0.273, 0.012)], dm, 64, closed=True)
    lathe(G, [(0.205, 0.016), (0.215, 0.016), (0.215, 0.024), (0.205, 0.024)], dm, 64, closed=True)
    torus(St, 0.165, 0.0045, dm @ Matrix.Translation((0, 0, 0.019)), 64, 8)
    torus(St, 0.105, 0.0035, dm @ Matrix.Translation((0, 0, 0.019)), 48, 8)
    lathe(G, [(0, 0.014), (0.088, 0.014), (0.088, 0.07), (0.08, 0.08), (0.06, 0.084), (0.06, 0.10),
              (0.052, 0.108), (0.024, 0.111), (0, 0.111)], dm, 48)
    for k in range(8):  # hub bolts
        a = math.tau * k / 8
        p = dm @ Vector((0.073 * math.cos(a), 0.073 * math.sin(a), 0.081))
        hex_bolt(St, p, (-1, 0, 0), 0.006, washer=False)
    for a in (90, 210, 330):  # spokes
        ar = math.radians(a)
        sm = dm @ Matrix.Translation((0.148 * math.cos(ar), 0.148 * math.sin(ar), 0.048)) @ Matrix.Rotation(ar, 4, "Z")
        box_m(G, sm, (0.15, 0.046, 0.04), 0.009, 3)
        box_m(G, dm @ Matrix.Translation((0.19 * math.cos(ar), 0.19 * math.sin(ar), 0.07)) @ Matrix.Rotation(ar, 4, "Z"),
              (0.03, 0.056, 0.012), 0.004)
    for k in range(12):  # rim rivets
        a = math.tau * (k + 0.5) / 12
        rivet(St, dm @ Vector((0.24 * math.cos(a), 0.24 * math.sin(a), 0.077)), (-1, 0, 0), 0.0045)
    # Hinge blocks on the back edge
    for vc in (0.74, 0.32):
        fbox("-X", -0.395, -0.315, vc - 0.07, vc + 0.07, 0.0, 0.036, bev=0.008, segs=3)
        cyl(G, fp("-X", -0.37, vc, 0.058), 0.022, 0.15, segs=24, bev=0.004)
        lathe(St, [(0, 0), (0.016, 0), (0.016, 0.006), (0.01, 0.01), (0, 0.01)], orient(fp("-X", -0.37, vc, 0.058) + Vector((0, 0, 0.075)), (0, 0, 1)), 16)
        fbox("-X", -0.37, -0.28, vc - 0.025, vc + 0.025, 0.012, 0.046, bev=0.005)
        fbolt("-X", -0.345, vc + 0.045, 0.036, 0.008)
        fbolt("-X", -0.345, vc - 0.045, 0.036, 0.008)

    # ---- +X side: vent + access hatch ---------------------------------------------------------------------------
    plate("+X", -F, 0.232, 0.528, Z1 - 0.068)
    plate("+X", -F, 0.232, Z0 + 0.068, 0.512)
    plate("+X", 0.252, F, Z0 + 0.068, 0.512)
    plate("+X", 0.252, F, 0.528, Z1 - 0.068)
    trim("+X", 0.238, 0.246, 0.56, 0.885)
    trim("+X", 0.238, 0.246, 0.175, 0.40)
    trim("+X", -0.36, 0.22, 0.516, 0.524)
    # Vent grille
    u0, u1, v0, v1 = -0.30, 0.13, 0.63, 0.82
    fbox("+X", u0, u1, v0, v1, 0.012, 0.018, bev=0.003)
    for (a0, a1, b0, b1) in ((u0 - 0.02, u1 + 0.02, v1, v1 + 0.02), (u0 - 0.02, u1 + 0.02, v0 - 0.02, v0),
                             (u0 - 0.02, u0, v0, v1), (u1, u1 + 0.02, v0, v1)):
        fbox("+X", a0, a1, b0, b1, 0.012, 0.03, bev=0.005)
    for i in range(9):
        v = v0 + 0.012 + i * (v1 - v0 - 0.024) / 8
        box(S("Gunmetal"), fp("+X", (u0 + u1) / 2, v, 0.024), (0.012, u1 - u0, 0.012), 0.003,
            rot=Matrix.Rotation(math.radians(30), 3, "Y"))
    for u, v in ((u0 - 0.01, v0 - 0.01), (u1 + 0.01, v0 - 0.01), (u0 - 0.01, v1 + 0.01), (u1 + 0.01, v1 + 0.01)):
        fbolt("+X", u, v, 0.03, 0.007)
    # Access hatch
    fbox("+X", -0.30, 0.13, 0.23, 0.44, 0.012, 0.024, bev=0.006, segs=3)
    fbox("+X", -0.27, 0.10, 0.26, 0.41, 0.024, 0.028, bev=0.003)
    for u, v in ((-0.285, 0.245), (0.115, 0.245), (-0.285, 0.425), (0.115, 0.425)):
        fbolt("+X", u, v, 0.024, 0.008)
    tube(St, rounded_path([fp("+X", -0.13, 0.335, 0.024), fp("+X", -0.13, 0.335, 0.05), fp("+X", -0.03, 0.335, 0.05),
                           fp("+X", -0.03, 0.335, 0.024)], 0.015), 0.007, 10)
    trim("+X", 0.04, 0.08, 0.40, 0.41, 0.024, 0.031)
    for vc in (0.79, 0.52, 0.27):
        fbox("+X", 0.29, 0.37, vc - 0.045, vc + 0.045, 0.0, 0.038, bev=0.008, segs=3)
        fbolt("+X", 0.33, vc, 0.038, 0.009)

    # ---- -Y back --------------------------------------------------------------------------------------------------
    plate("-Y", -F, -0.008, 0.528, Z1 - 0.068)
    plate("-Y", 0.008, F, 0.528, Z1 - 0.068)
    plate("-Y", -F, F, Z0 + 0.068, 0.512)
    trim("-Y", -0.004, 0.004, 0.545, 0.88)
    trim("-Y", -0.38, 0.38, 0.516, 0.524)
    for su in (-1, 1):  # armour sub-plates
        fbox("-Y", su * 0.06, su * 0.33, 0.6, 0.83, 0.012, 0.026, bev=0.007, segs=3)
        for u, v in ((0.08, 0.62), (0.31, 0.62), (0.08, 0.81), (0.31, 0.81)):
            fbolt("-Y", su * u, v, 0.026, 0.008)
    u0, u1, v0, v1 = -0.27, 0.27, 0.24, 0.44
    for (a0, a1, b0, b1) in ((u0 - 0.02, u1 + 0.02, v1, v1 + 0.02), (u0 - 0.02, u1 + 0.02, v0 - 0.02, v0),
                             (u0 - 0.02, u0, v0, v1), (u1, u1 + 0.02, v0, v1)):
        fbox("-Y", a0, a1, b0, b1, 0.012, 0.03, bev=0.005)
    fbox("-Y", u0, u1, v0, v1, 0.012, 0.016, bev=0.002)
    for i in range(14):
        u = u0 + 0.018 + i * (u1 - u0 - 0.036) / 13
        fbox("-Y", u - 0.006, u + 0.006, v0 + 0.005, v1 - 0.005, 0.014, 0.026, bev=0.003)
    for u in (-0.15, 0.15):  # carry handle brackets + bar
        fbox("-Y", u - 0.025, u + 0.025, 0.86, 0.90, 0.012, 0.03, bev=0.006)
    tube(St, rounded_path([fp("-Y", -0.15, 0.88, 0.03), fp("-Y", -0.15, 0.88, 0.06), fp("-Y", 0.15, 0.88, 0.06),
                           fp("-Y", 0.15, 0.88, 0.03)], 0.02), 0.009, 12)

    # ---- +Z top ----------------------------------------------------------------------------------------------------
    plate("+Z", -F, -0.262, -F, F)
    plate("+Z", 0.262, F, -F, F)
    plate("+Z", -0.246, 0.246, 0.262, F, rivets=False)
    plate("+Z", -0.246, 0.246, -F, -0.262, rivets=False)
    plate("+Z", -0.246, 0.246, -0.246, 0.246, rivets=False)
    trim("+Z", -0.24, 0.24, 0.250, 0.258)
    trim("+Z", -0.258, -0.250, -0.20, 0.24)
    trim("+Z", 0.250, 0.258, 0.05, 0.24)
    fbox("+Z", -0.205, 0.205, -0.215, 0.205, 0.012, 0.03, bev=0.008, segs=3)
    fbox("+Z", -0.175, 0.175, -0.185, 0.175, 0.03, 0.034, bev=0.003)
    for u, v in ((-0.19, -0.2), (0.19, -0.2), (-0.19, 0.19), (0.19, 0.19)):
        hex_bolt(St, fp("+Z", u, v, 0.03), (0, 0, 1), 0.009)
    fbox("+Z", -0.06, 0.06, 0.12, 0.15, 0.034, 0.04, bev=0.004)  # grip
    for su in (-1, 1):
        for sv in (-1, 1):
            c = fp("+Z", su * 0.335, sv * 0.335, 0.012)
            lathe(G, [(0, 0), (0.036, 0), (0.036, 0.016), (0.031, 0.022), (0.016, 0.022), (0.016, 0.014), (0, 0.014)],
                  orient(c, (0, 0, 1)), 32)
            hex_bolt(St, c + Vector((0, 0, 0.014)), (0, 0, 1), 0.009, washer=False)

    # ---- corner brackets on the vertical edges -----------------------------------------------------------------------
    hexa = [(0.33, 0.40), (0.33, HS + 0.014), (HS + 0.014 - CH * 0.75, HS + 0.014), (HS + 0.014, HS + 0.014 - CH * 0.75),
            (HS + 0.014, 0.33), (0.40, 0.33)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            pts = [(sx * a, sy * b) for a, b in hexa]
            for z0, z1 in ((0.75, 0.895), (0.165, 0.31)):
                slab(G, pts, z0, z1, mtx=Matrix.Identity(4), bev=0.006, segs=2)
                zc = (z0 + z1) / 2
                hex_bolt(St, (sx * (HS + 0.014), sy * 0.37, zc), (sx, 0, 0), 0.009)
                if sy < 0:
                    hex_bolt(St, (sx * 0.37, sy * (HS + 0.014), zc), (0, sy, 0), 0.009)

    # ---- underside and feet --------------------------------------------------------------------------------------
    fbox("-Z", -0.36, 0.36, -0.36, 0.36, -0.005, 0.012, bev=0.006)
    for sx in (-1, 1):
        for sy in (-1, 1):
            lathe(G, [(0, 0), (0.07, 0), (0.079, 0.006), (0.079, 0.026), (0.071, 0.033), (0.056, 0.037), (0.053, 0.045),
                      (0.053, 0.084), (0.06, 0.088), (0.06, 0.106), (0, 0.106)], orient((sx * 0.32, sy * 0.32, 0), (0, 0, 1)), 32)

    # ---- front window frame ----------------------------------------------------------------------------------------
    zc = 0.53
    ring_prism(G, rrect(0.385, 0.375, 0.075, zc, 10), rrect(0.305, 0.325, 0.05, zc, 10), 0.445, 0.50, bev=0.011, segs=3)
    ring_prism(G, rrect(0.334, 0.352, 0.06, zc, 10), rrect(0.292, 0.312, 0.04, zc, 10), 0.42, 0.468, bev=0.004)
    ring_prism(S("Trim"), rrect(0.306, 0.326, 0.05, zc, 10), rrect(0.297, 0.317, 0.043, zc, 10), 0.466, 0.479, bev=0.0)
    trim("+Y", -0.42, -0.412, 0.20, 0.50, 0.0, 0.012)  # vertical glow strip by the front-left corner
    for x, z in ((-0.345, 0.865), (0.345, 0.865), (-0.345, 0.195), (0.345, 0.195), (0.12, 0.882), (-0.12, 0.178),
                 (0.12, 0.178), (0.345, 0.40), (0.345, 0.66)):
        hex_bolt(St, (x, 0.50, z), (0, 1, 0), 0.0105)
    box_span(G, (-0.235, 0.495, 0.862), (-0.095, 0.522, 0.898), 0.006, 3)   # top-left latch
    box_span(St, (-0.22, 0.52, 0.872), (-0.11, 0.528, 0.888), 0.003)
    box_span(G, (-0.372, 0.495, 0.40), (-0.322, 0.524, 0.64), 0.007, 3)     # left latch bar
    box_span(St, (-0.362, 0.52, 0.43), (-0.332, 0.53, 0.61), 0.003)
    for z in (0.42, 0.62):
        hex_bolt(St, (-0.347, 0.524, z), (0, 1, 0), 0.007, washer=False)
    box_span(G, (0.385, 0.40, 0.25), (0.41, 0.49, 0.36), 0.006, 3)          # right-hand catch
    box_span(G, (0.385, 0.40, 0.70), (0.41, 0.49, 0.81), 0.006, 3)
    return


# --------------------------------------------------------------------------------------------------------------------
# Interior - the hero detail
# --------------------------------------------------------------------------------------------------------------------
def build_interior():
    I, St, G, Br, Cu, Tr = S("Interior"), S("Steel"), S("Gunmetal"), S("Brass"), S("Copper"), S("Trim")
    yb = CAV_BACK

    # Circuit backplane with chips and raised brass traces
    box_span(S("Circuit"), (-0.322, yb, CAV_Z0 + 0.005), (0.322, yb + 0.012, CAV_Z1 - 0.005), 0.002)
    for x, z, w, h in ((-0.22, 0.77, 0.09, 0.06), (-0.07, 0.80, 0.07, 0.05), (0.07, 0.74, 0.06, 0.08),
                       (-0.25, 0.47, 0.06, 0.10), (0.10, 0.46, 0.05, 0.05), (-0.12, 0.62, 0.04, 0.04)):
        box_span(I, (x - w / 2, yb + 0.01, z - h / 2), (x + w / 2, yb + 0.022, z + h / 2), 0.003)
        for k in range(int(w / 0.012)):
            px = x - w / 2 + 0.006 + k * 0.012
            box_span(Br, (px - 0.002, yb + 0.012, z - h / 2 - 0.008), (px + 0.002, yb + 0.016, z - h / 2), 0.0)
            box_span(Br, (px - 0.002, yb + 0.012, z + h / 2), (px + 0.002, yb + 0.016, z + h / 2 + 0.008), 0.0)
    yt = yb + 0.016
    for path in (((-0.31, 0.70), (-0.15, 0.70), (-0.15, 0.60), (-0.05, 0.60)),
                 ((-0.31, 0.64), (-0.20, 0.64), (-0.20, 0.30), (-0.10, 0.30)),
                 ((-0.12, 0.86), (-0.12, 0.74), (0.02, 0.74), (0.02, 0.64)),
                 ((0.16, 0.86), (0.16, 0.66), (0.08, 0.66), (0.08, 0.52)),
                 ((-0.30, 0.38), (-0.26, 0.38), (-0.26, 0.24))):
        tube(Br, rounded_path([(x, yt, z) for x, z in path], 0.02), 0.0028, 6)
    for x, z in ((-0.05, 0.60), (-0.10, 0.30), (0.02, 0.64), (0.08, 0.52), (-0.26, 0.24)):
        cyl(Tr, (x, yt, z), 0.007, 0.006, axis=(0, 1, 0), segs=12, bev=0.0)

    # Side wall liner panels, ceiling and floor
    for sx in (-1, 1):
        for y0, y1 in ((yb, -0.01), (0.005, 0.40)):
            box_span(I, (sx * CAV_HW, y0, CAV_Z0 + 0.01), (sx * (CAV_HW - 0.01), y1, CAV_Z1 - 0.01), 0.003)
        for z in (0.36, 0.70):
            box_span(St, (sx * (CAV_HW - 0.008), yb, z - 0.006), (sx * (CAV_HW - 0.016), 0.40, z + 0.006), 0.003)
    box_span(I, (-CAV_HW, yb, 0.185), (CAV_HW, 0.43, 0.20), 0.003)
    for k in range(9):
        y = -0.33 + k * 0.085
        box_span(St, (-0.31, y - 0.006, 0.20), (0.31, y + 0.006, 0.204), 0.0015)
    box_span(G, (-0.31, 0.40, 0.19), (0.31, 0.44, 0.215), 0.005)
    box_span(Tr, (-0.28, 0.398, 0.203), (0.28, 0.402, 0.211), 0.0)  # glow strip along the inner sill
    box_span(I, (-0.30, -0.30, CAV_Z1 - 0.012), (0.30, 0.40, CAV_Z1 + 0.002), 0.003)
    box_span(St, (-0.26, 0.27, 0.858), (0.26, 0.33, 0.866), 0.002)
    box_span(Tr, (-0.24, 0.285, 0.853), (0.24, 0.315, 0.859), 0.0015)

    # Pedestal: machined base, bolt ring, coiled column, emitter cap
    px, py = CORE_C.x, CORE_C.y
    pm = orient((px, py, 0), (0, 0, 1))
    lathe(I, [(0, 0.199), (0.152, 0.199), (0.152, 0.213), (0.146, 0.221), (0.112, 0.222), (0.108, 0.226),
              (0.108, 0.238), (0.101, 0.244), (0, 0.244)], pm, 72)
    lathe(G, [(0.112, 0.214), (0.142, 0.214), (0.142, 0.2225), (0.112, 0.2225)], pm, 64, closed=True)
    for k in range(12):
        a = math.tau * k / 12
        hex_bolt(St, (px + 0.128 * math.cos(a), py + 0.128 * math.sin(a), 0.2225), (0, 0, 1), 0.0065)
    torus(S("CoreGlow"), 0.088, 0.0035, Matrix.Translation((px, py, 0.2445)), 64, 8)
    cyl(I, (px, py, 0.295), 0.042, 0.10, segs=32, bev=0.0)
    torus(G, 0.064, 0.011, Matrix.Translation((px, py, 0.256)), 40, 10)
    torus(G, 0.064, 0.011, Matrix.Translation((px, py, 0.334)), 40, 10)
    tube(G, helix((px, py), 0.058, 0.268, 0.322, 3.5, 32), 0.0072, 8)
    tube(Cu, helix((px, py), 0.047, 0.262, 0.330, 9, 20, phase=1.0), 0.0032, 6)
    for a in (0, 120, 240):  # support ribs
        ar = math.radians(a)
        box_m(St, Matrix.Translation((px + 0.078 * math.cos(ar), py + 0.078 * math.sin(ar), 0.295)) @ Matrix.Rotation(ar, 4, "Z"),
              (0.012, 0.014, 0.09), 0.003)
    lathe(St, [(0, 0.343), (0.07, 0.343), (0.07, 0.350), (0.06, 0.357), (0.04, 0.358), (0.04, 0.353), (0, 0.353)], pm, 48)
    cyl(S("CoreGlow"), (px, py, 0.354), 0.037, 0.004, segs=32, bev=0.0)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=False, cap_tris=False, segments=32, radius1=0.036, radius2=0.06, depth=0.15,
                          matrix=Matrix.Translation((px, py, 0.357 + 0.075)))
    S("Beam").add(bm)

    # Capacitor bank (back-left)
    box_span(I, (-0.315, -0.35, 0.20), (-0.17, -0.15, 0.213), 0.004)
    for x in (-0.282, -0.205):
        for y in (-0.315, -0.25, -0.185):
            m = orient((x, y, 0), (0, 0, 1))
            lathe(I, [(0, 0.213), (0.026, 0.213), (0.028, 0.218), (0.028, 0.305), (0.025, 0.309), (0, 0.309)], m, 24)
            lathe(St, [(0, 0.307), (0.022, 0.307), (0.022, 0.314), (0.016, 0.317), (0, 0.317)], m, 24)
            torus(Tr, 0.0285, 0.0018, Matrix.Translation((x, y, 0.29)), 32, 6)
            torus(Br, 0.0285, 0.0022, Matrix.Translation((x, y, 0.232)), 32, 6)

    # Control module (front-left) with vents and LEDs, wired to the pedestal
    box_span(I, (-0.315, 0.06, 0.20), (-0.17, 0.24, 0.272), 0.007)
    for k in range(5):
        y = 0.085 + k * 0.03
        box_span(St, (-0.30, y - 0.006, 0.272), (-0.19, y + 0.006, 0.278), 0.002)
    for k, z in enumerate((0.225, 0.245)):
        box_span(S("LED") if k == 0 else Tr, (-0.165, 0.10, z - 0.005), (-0.162, 0.13, z + 0.005), 0.0)
    for dz, mk in ((0.0, Br), (0.012, Cu)):
        tube(mk, rounded_path([(-0.17, 0.17 - dz, 0.225 + dz), (-0.13, 0.17 - dz, 0.225 + dz), (-0.13, 0.05 - dz, 0.206),
                               (-0.12, 0.03, 0.206)], 0.025), 0.0035, 6)

    # Canister (front-right), mounted horizontally from the right wall
    cm = orient((CAV_HW - 0.01, 0.15, 0.258), (-1, 0, 0))
    lathe(St, [(0, 0), (0.05, 0), (0.05, 0.012), (0.043, 0.017), (0.043, 0.088), (0.05, 0.093), (0.05, 0.105),
               (0.036, 0.11), (0.022, 0.128), (0.022, 0.145), (0.027, 0.148), (0.027, 0.158), (0, 0.158)], cm, 36)
    torus(Tr, 0.0445, 0.0026, cm @ Matrix.Translation((0, 0, 0.052)), 36, 6)
    for z in (0.03, 0.074):
        torus(G, 0.0445, 0.004, cm @ Matrix.Translation((0, 0, z)), 36, 8)
    box_span(I, (0.21, 0.11, 0.20), (0.29, 0.19, 0.215), 0.004)
    for x in (0.225, 0.275):
        box_span(G, (x - 0.006, 0.105, 0.20), (x + 0.006, 0.195, 0.235), 0.003)
    tube(Br, rounded_path([(0.165, 0.15, 0.258), (0.14, 0.15, 0.258), (0.14, 0.08, 0.207), (0.12, 0.04, 0.207)], 0.025), 0.004, 6)
    tube(Br, rounded_path([(0.312, 0.25, 0.20), (0.312, 0.25, 0.86), (0.312, -0.1, 0.86)], 0.04), 0.008, 10)

    # Coil bank (back-right, under the server shelf)
    for x, y in ((0.205, -0.33), (0.27, -0.33), (0.205, -0.262), (0.27, -0.262)):
        m = orient((x, y, 0), (0, 0, 1))
        lathe(St, [(0, 0.20), (0.03, 0.20), (0.03, 0.212), (0, 0.212)], m, 24)
        lathe(St, [(0, 0.318), (0.03, 0.318), (0.03, 0.33), (0, 0.33)], m, 24)
        cyl(I, (x, y, 0.265), 0.017, 0.106, segs=20, bev=0.0)
        tube(Cu, helix((x, y), 0.0235, 0.216, 0.314, 8, 14), 0.004, 5, caps=False)
    box_span(St, (0.165, yb, 0.385), (CAV_HW, -0.205, 0.40), 0.003)
    for x in (0.175, 0.315):
        cyl(St, (x, -0.214, 0.2925), 0.007, 0.185, segs=12, bev=0.0)

    # Server stack (back-right) with vertical vent slats, LEDs and drive bays
    box_span(I, (0.172, yb, 0.40), (0.322, -0.218, 0.862), 0.006)
    for k in range(10):
        x = 0.186 + k * 0.0135
        box_span(St, (x - 0.0035, -0.222, 0.52), (x + 0.0035, -0.208, 0.80), 0.0015)
    box_span(G, (0.176, -0.222, 0.505), (0.318, -0.214, 0.515), 0.002)
    box_span(G, (0.176, -0.222, 0.805), (0.318, -0.214, 0.815), 0.002)
    for z in (0.43, 0.47):
        box_span(G, (0.18, -0.222, z - 0.016), (0.314, -0.212, z + 0.016), 0.003)
        box_span(Tr, (0.19, -0.2125, z - 0.003), (0.24, -0.209, z + 0.003), 0.0)
        box_span(S("LED"), (0.295, -0.2125, z - 0.004), (0.303, -0.209, z + 0.004), 0.0)
    for k in range(3):
        box_span(S("LED") if k != 1 else Tr, (0.19 + k * 0.018, -0.218, 0.835), (0.2 + k * 0.018, -0.209, 0.845), 0.0)
    for k in range(6):  # ribs facing the core
        z = 0.53 + k * 0.05
        box_span(St, (0.164, -0.36, z - 0.005), (0.172, -0.225, z + 0.005), 0.002)

    # Small LED box (mid-right)
    box_span(I, (0.235, -0.10, 0.40), (CAV_HW, 0.06, 0.49), 0.006)
    box_span(S("Circuit"), (0.245, 0.058, 0.415), (0.30, 0.064, 0.455), 0.0)
    for k in range(3):
        box_span(S("LED"), (0.25 + k * 0.018, 0.058, 0.468), (0.258 + k * 0.018, 0.066, 0.476), 0.0)

    # Pipes on the left wall with clamps
    p1 = rounded_path([(-0.30, 0.33, 0.20), (-0.30, 0.33, 0.79), (-0.30, yb + 0.01, 0.79)], 0.05)
    tube(St, p1, 0.012, 12)
    p2 = rounded_path([(-0.307, -0.12, 0.213), (-0.307, -0.12, 0.70), (-0.307, 0.22, 0.70), (-0.307, 0.22, CAV_Z1)], 0.035)
    tube(Br, p2, 0.007, 10)
    for y, z in ((0.33, 0.30), (0.33, 0.55), (0.0, 0.79), (-0.25, 0.79)):
        if y == 0.33:
            box_span(G, (-0.322, y - 0.02, z - 0.012), (-0.282, y + 0.02, z + 0.012), 0.004)
        else:
            box_span(G, (-0.322, y - 0.012, z - 0.02), (-0.282, y + 0.012, z + 0.02), 0.004)
    tube(St, rounded_path([(0.30, 0.10, 0.862), (-0.30, 0.10, 0.862)], 0.03), 0.009, 10)

    # Wall-mounted junction boxes with indicator strips and conduits up to the ceiling
    for sx, (y0, y1, z0, z1) in ((-1, (-0.02, 0.12, 0.42, 0.56)), (1, (-0.06, 0.10, 0.60, 0.72))):
        xw, xf = sx * (CAV_HW - 0.01), sx * (CAV_HW - 0.045)
        box_span(I, (xw, y0, z0), (xf, y1, z1), 0.006)
        box_span(G, (xf, y0 + 0.012, z0 + 0.012), (xf - sx * 0.004, y1 - 0.012, z1 - 0.012), 0.002)
        box_span(Tr, (xf - sx * 0.004, y0 + 0.02, z1 - 0.03), (xf - sx * 0.007, y0 + 0.07, z1 - 0.022), 0.0)
        box_span(S("LED"), (xf - sx * 0.004, y1 - 0.035, z1 - 0.032), (xf - sx * 0.008, y1 - 0.025, z1 - 0.022), 0.0)
        for k, mk in enumerate((Cu, St, Br)):
            y = y0 + 0.03 + k * 0.035
            tube(mk, rounded_path([(sx * (CAV_HW - 0.028), y, z1), (sx * (CAV_HW - 0.028), y, CAV_Z1)], 0.02), 0.0045, 6)
    # Cable bundle in the back corner behind the capacitor bank
    for k, mk in enumerate((Cu, Br, St, Cu)):
        dx, dy = (k % 2) * 0.012, (k // 2) * 0.012
        tube(mk, rounded_path([(-0.30 + dx, -0.345 + dy, 0.32), (-0.30 + dx, -0.345 + dy, 0.80),
                               (-0.18 + dx, -0.345 + dy, CAV_Z1)], 0.05), 0.0048, 6, caps=False)
    for z in (0.40, 0.60):
        box_span(G, (-0.31, -0.355, z - 0.01), (-0.276, -0.322, z + 0.01), 0.003)
    for x in (-0.2, 0.0, 0.2):
        box_span(G, (x - 0.01, 0.085, 0.85), (x + 0.01, 0.115, CAV_Z1), 0.003)


# --------------------------------------------------------------------------------------------------------------------
# Moving parts: core sphere + two orbit rings (local coordinates around the core centre)
# --------------------------------------------------------------------------------------------------------------------
def build_core_parts():
    core = Assembly("Core_Sphere", ["CoreGlow", "CoreHalo"])
    sphere(core, (0, 0, 0), 0.055, 40, 20, "CoreGlow")
    sphere(core, (0, 0, 0), 0.072, 32, 16, "CoreHalo")

    inner = Assembly("Ring_Inner_Mesh", ["CoreGlow", "Steel"])
    rot_x = Matrix.Rotation(math.radians(90), 4, "X")   # ring in the XZ plane (faces the window), spins about X
    torus(inner, 0.118, 0.0055, rot_x, 96, 8, "CoreGlow")
    torus(inner, 0.104, 0.0022, rot_x, 96, 5, "CoreGlow")
    for k in range(4):
        a = math.tau * (k + 0.5) / 4
        p = rot_x @ Vector((0.118 * math.cos(a), 0.118 * math.sin(a), 0))
        t = rot_x.to_3x3() @ Vector((-math.sin(a), math.cos(a), 0))
        cyl(inner, p, 0.0095, 0.022, axis=t, segs=16, bev=0.002, mat="Steel")

    outer = Assembly("Ring_Outer_Mesh", ["CoreGlow", "Steel"])  # horizontal ring, spins about Y
    torus(outer, 0.2, 0.006, Matrix.Identity(4), 128, 8, "CoreGlow")
    torus(outer, 0.186, 0.0025, Matrix.Identity(4), 128, 5, "CoreGlow")
    for k in range(6):
        a = math.tau * k / 6
        p = Vector((0.2 * math.cos(a), 0.2 * math.sin(a), 0))
        t = Vector((-math.sin(a), math.cos(a), 0))
        cyl(outer, p, 0.0105, 0.024, axis=t, segs=16, bev=0.002, mat="Steel")
        box(outer, Vector((0.193 * math.cos(a), 0.193 * math.sin(a), 0)), (0.016, 0.006, 0.008), 0.001,
            rot=Matrix.Rotation(a, 3, "Z"), mat="Steel")
    return core, inner, outer


# --------------------------------------------------------------------------------------------------------------------
# Finalise: UVs, shading, objects
# --------------------------------------------------------------------------------------------------------------------
def project_uvs(bm, offset=Vector((0, 0, 0)), circuit=False):
    uv = bm.loops.layers.uv.get(UV_NAME) or bm.loops.layers.uv.new(UV_NAME)
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for loop in f.loops:
            co = loop.vert.co + offset
            if circuit:
                if ax == 0:
                    u, v = (co.y + 0.37) / 0.8, (co.z - CAV_Z0) / (CAV_Z1 - CAV_Z0)
                else:
                    u, v = (co.x + 0.325) / 0.65, (co.z - CAV_Z0) / (CAV_Z1 - CAV_Z0)
            else:
                if ax == 0:
                    u, v = (co.y if n.x > 0 else -co.y) + 0.13, co.z
                elif ax == 1:
                    u, v = (-co.x if n.y > 0 else co.x) + 0.37, co.z + 0.21
                else:
                    u, v = co.x + 0.71, (co.y if n.z > 0 else -co.y) + 0.05
                u, v = u / UV_TILE, v / UV_TILE
            loop[uv].uv = (u, v)


def finish(asm, parent, offset=Vector((0, 0, 0))):
    bm = asm.bm
    for v in bm.verts:  # authored mirrored; flip X so the door is on +X (left of the window, as in the concept)
        v.co.x = -v.co.x
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    bm.normal_update()
    project_uvs(bm, offset, circuit=asm.mats == ["Circuit"])
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        e.smooth = e.is_manifold and e.calc_face_angle(0.0) <= SHARP
    me = bpy.data.meshes.new(asm.name)
    bm.to_mesh(me)
    bm.free()
    for key in asm.mats:
        me.materials.append(M[key])
    obj = bpy.data.objects.new(asm.name, me)
    SCENE.collection.objects.link(obj)
    obj.parent = parent
    return obj


def empty(name, loc, parent=None):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_size = 0.1
    SCENE.collection.objects.link(obj)
    obj.parent = parent
    obj.location = loc
    return obj


build_shell()
build_exterior()
build_interior()
for key in ("Glass",):
    zc = 0.53
    gbm = bmesh.new()
    gbm.faces.new([gbm.verts.new(FRONT_MAP @ Vector((u, v, 0.471))) for u, v in rrect(0.312, 0.332, 0.052, zc, 10)][::-1])
    gbm.normal_update()
    S("Glass").add(gbm)
core_asm, inner_asm, outer_asm = build_core_parts()

body = empty("Body", (0, 0, 0))
core_e = empty("Core", CORE_C, body)
ring_outer_e = empty("Ring_Outer", CORE_C, body)
ring_inner_e = empty("Ring_Inner", CORE_C, body)

for key in list(STATIC):
    obj = finish(STATIC[key], body)
    if key == "Glass":
        obj.name = obj.data.name = "Window_Glass"
finish(core_asm, core_e, CORE_C)
finish(inner_asm, ring_inner_e, CORE_C)
finish(outer_asm, ring_outer_e, CORE_C)

tris = 0
for o in SCENE.objects:
    if o.type == "MESH":
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
        print(f"MESH {o.name:24s} tris={len(o.data.loop_triangles):6d} mats={[m.name for m in o.data.materials]}")
print("TOTAL TRIS", tris)

bpy.ops.export_scene.gltf(filepath=str(HERE / "tech_vault.glb"), export_format="GLB", export_yup=True,
                          export_animations=False, export_cameras=False, export_lights=False)
print("EXPORTED", HERE / "tech_vault.glb")

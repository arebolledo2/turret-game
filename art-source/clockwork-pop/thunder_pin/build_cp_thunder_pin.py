"""Clockwork Thunder Pin (Shock/Lance level-10 turret).

Builds the model from scratch in Blender 5.2 (--background) and exports cp_thunder_pin.glb beside this script.
Metres, +Z up, weapon faces +Y. Aim (rotating head) carries box, shaft, rings and tip; Muzzle sits at the pin tip.

Surfaces come from four procedurally generated 1024x1024 atlases (base colour, ORM, normal, emissive). The atlas is a
4x4 grid of 256 px material cells; every part is UV-mapped into its material's cell (lathed parts get a natural
around/along unwrap, box-like parts a dominant-axis projection), so brushed brass streaks run around the rings and
jewels get a rim-to-crown gradient.
"""
import math
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

OUT = Path(__file__).parent
bpy.ops.wm.read_factory_settings(use_empty=True)

# --------------------------------------------------------------------------------------------------------------------
# Procedural texture atlas
# --------------------------------------------------------------------------------------------------------------------
TEX, CELL, GRID = 1024, 256, 4
MARGIN = 12 / TEX
CELLS = {
    "teal": (0, 0), "coral": (1, 0), "brass": (2, 0), "ivory": (3, 0),
    "black": (0, 1), "mint": (1, 1), "violet": (2, 1), "steel": (3, 1),
    "dark": (0, 2), "tealdeep": (1, 2),
}
RNG = np.random.default_rng(11)


def srgb(*c):
    return np.array(c, dtype=np.float32) / 255.0


def value_noise(size, freq, rng):
    """Smooth tileable value noise in [0,1], size x size."""
    grid = rng.random((freq, freq))
    t = np.linspace(0, freq, size, endpoint=False)
    i0 = t.astype(int)
    f = t - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % freq
    a = grid[i0][:, i0]
    b = grid[i0][:, i1]
    c = grid[i1][:, i0]
    d = grid[i1][:, i1]
    fx = f[None, :]
    fy = f[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def streaks(size, rng, count=90):
    """Fine 1-D brushing streaks that vary along rows only (v), smoothed slightly."""
    line = rng.random(size)
    for _ in range(2):
        line = (np.roll(line, 1) + line + np.roll(line, -1)) / 3
    line = (line - line.min()) / (line.max() - line.min() + 1e-6)
    return np.repeat(line[:, None], size, axis=1)


def build_atlases():
    color = np.zeros((TEX, TEX, 4), np.float32)
    orm = np.zeros((TEX, TEX, 4), np.float32)
    nrm = np.zeros((TEX, TEX, 4), np.float32)
    emit = np.zeros((TEX, TEX, 4), np.float32)
    color[..., :3] = srgb(60, 60, 70)
    color[..., 3] = 1
    orm[..., 0] = 1
    orm[..., 1] = 0.5
    orm[..., 3] = 1
    nrm[...] = (0.5, 0.5, 1.0, 1.0)
    emit[..., 3] = 1

    v = (np.arange(CELL)[:, None] + 0.5) / CELL * np.ones((1, CELL))  # row coordinate (along profile)
    soft = lambda f, amp: (value_noise(CELL, f, RNG) - 0.5) * amp

    def put(name, rgb, rough, metal, n_xy=None, glow=None):
        cx, cy = CELLS[name]
        ys, xs = slice(cy * CELL, (cy + 1) * CELL), slice(cx * CELL, (cx + 1) * CELL)
        color[ys, xs, :3] = np.clip(rgb, 0, 1)
        orm[ys, xs, 1] = np.clip(rough, 0.02, 1)
        orm[ys, xs, 2] = metal
        if n_xy is not None:
            nx, ny = n_xy
            nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
            nrm[ys, xs, 0] = nx * 0.5 + 0.5
            nrm[ys, xs, 1] = ny * 0.5 + 0.5
            nrm[ys, xs, 2] = nz * 0.5 + 0.5
        if glow is not None:
            emit[ys, xs, :3] = np.clip(glow, 0, 1)

    one = np.ones((CELL, CELL, 1), np.float32)

    # Satin teal enamel: clean, very gentle tonal drift, soft satin sheen.
    drift = soft(3, 0.05)[..., None]
    put("teal", srgb(30, 100, 118) * (1 + drift), 0.40 + soft(4, 0.06), 0.0)
    put("tealdeep", srgb(28, 76, 92) * (1 + drift), 0.42 + soft(4, 0.06), 0.0)

    # Glossy coral enamel.
    put("coral", srgb(226, 72, 60) * (1 + soft(3, 0.04)[..., None]), 0.30 + soft(5, 0.05), 0.0)

    # Polished brass: circumferential brushing (streaks vary along v) + soft lathe bands for crisp highlights.
    st = streaks(CELL, RNG)
    band = 0.5 + 0.5 * np.cos(v * math.tau * 1.0)
    brass_rgb = srgb(250, 204, 92) * (0.94 + 0.08 * st[..., None] + 0.05 * band[..., None])
    grad = np.gradient(st, axis=0) * 6.0
    put("brass", brass_rgb, 0.16 + 0.08 * st, 0.75, (np.zeros_like(grad), np.clip(grad, -0.25, 0.25)))

    # Ivory ceramic: warm, faint mottling and a micro orange-peel normal.
    mott = soft(6, 0.04)[..., None]
    peel = value_noise(CELL, 24, RNG)
    gy, gx = np.gradient(peel)
    put("ivory", srgb(248, 238, 214) * (1 + mott), 0.26 + soft(8, 0.04), 0.0,
        (np.clip(gx * 0.6, -0.03, 0.03), np.clip(gy * 0.6, -0.03, 0.03)))

    # Black spring steel / column.
    put("black", srgb(40, 38, 52) * one, 0.30 + 0.08 * streaks(CELL, RNG), 0.65)
    put("dark", srgb(22, 28, 38) * one, 0.65, 0.0)
    put("steel", srgb(128, 134, 148) * (0.95 + 0.1 * streaks(CELL, RNG)[..., None]), 0.28, 0.9)

    # Jewels: deep rim -> bright crown along v, glossy, emissive core.
    t = np.clip(v, 0, 1)[..., None]
    mint = srgb(22, 160, 124) * (1 - t) + srgb(150, 248, 214) * t
    put("mint", mint, 0.05, 0.0, glow=mint * 0.35)
    violet = srgb(84, 36, 168) * (1 - t) + srgb(196, 150, 255) * t
    put("violet", violet, 0.06, 0.0, glow=violet * 0.30)
    return color, orm, nrm, emit


def make_image(name, arr, noncolor):
    img = bpy.data.images.new(name, TEX, TEX, alpha=False)
    if noncolor:
        img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(arr.astype(np.float32).ravel())
    img.filepath_raw = str(OUT / f"{name}.png")
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img


_c, _o, _n, _e = build_atlases()
IMG_COLOR = make_image("pin_basecolor", _c, False)
IMG_ORM = make_image("pin_orm", _o, True)
IMG_NRM = make_image("pin_normal", _n, True)
IMG_EMIT = make_image("pin_emissive", _e, False)


def atlas_material(name, emissive=False, coat=0.0):
    mat = bpy.data.materials.new(name)
    nt = mat.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = nt.nodes.get("Material Output") or nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(bsdf.outputs[0], out.inputs[0])
    links = nt.links

    def tex(img, x, y):
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = img
        node.interpolation = "Linear"
        node.location = (x, y)
        return node

    tc = tex(IMG_COLOR, -700, 300)
    links.new(tc.outputs["Color"], bsdf.inputs["Base Color"])
    to = tex(IMG_ORM, -700, 0)
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    sep.location = (-400, 0)
    links.new(to.outputs["Color"], sep.inputs["Color"])
    links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    tn = tex(IMG_NRM, -700, -300)
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nm.location = (-400, -300)
    nm.inputs["Strength"].default_value = 1.0
    links.new(tn.outputs["Color"], nm.inputs["Color"])
    links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if emissive:
        te = tex(IMG_EMIT, -700, -600)
        links.new(te.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = 1.0
    if coat > 0:
        bsdf.inputs["Coat Weight"].default_value = coat
        bsdf.inputs["Coat Roughness"].default_value = 0.03
    return mat


MATS = {
    "teal": atlas_material("Teal_Satin"),
    "tealdeep": atlas_material("Teal_Deep"),
    "coral": atlas_material("Coral_Enamel"),
    "brass": atlas_material("Brass_Polished"),
    "ivory": atlas_material("Ivory_Ceramic", coat=0.4),
    "black": atlas_material("Black_Spring"),
    "dark": atlas_material("Dark_Recess"),
    "steel": atlas_material("Steel_Rivet"),
    "mint": atlas_material("Jewel_Mint", emissive=True, coat=1.0),
    "violet": atlas_material("Jewel_Violet", emissive=True, coat=1.0),
}

# --------------------------------------------------------------------------------------------------------------------
# Geometry helpers (bmesh, built in world space)
# --------------------------------------------------------------------------------------------------------------------
SHARP = math.radians(38)
SEG_K = 0.6  # global tessellation factor for lathed parts
AIM_POS = Vector((0.0, 0.0, 0.58))
SHAFT_Z = 0.87
HEAD_DY = 0.0  # head stays centred over the column (Aim pivot at world origin XY)
TIP_DY = 0.10   # lance length tweak for the charging ring, cone and point


def empty(name, pos=(0, 0, 0), parent=None):
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = pos
    obj.empty_display_size = 0.08
    return obj


BASE = empty("Base")
AIM = empty("Aim", AIM_POS, BASE)


def cell_uv(cell, u, v):
    cx, cy = CELLS[cell]
    span = 1 / GRID - 2 * MARGIN
    return (cx / GRID + MARGIN + min(max(u, 0), 1) * span, cy / GRID + MARGIN + min(max(v, 0), 1) * span)


def finish(name, bm, cell, parent, shift=True):
    for face in bm.faces:
        face.smooth = True
    for edge in bm.edges:
        if len(edge.link_faces) == 2 and edge.calc_face_angle(0.0) > SHARP:
            edge.smooth = False
    if parent is AIM:
        off = -AIM_POS + (Vector((0, HEAD_DY, 0)) if shift else Vector())
        bmesh.ops.translate(bm, vec=off, verts=bm.verts)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(MATS[cell])
    obj.parent = parent
    return obj


def rounded(points, closed=False, n=3):
    """Round polyline corners. Each point is (r, z) or (r, z, radius)."""
    pts = [(p[0], p[1], p[2] if len(p) > 2 else 0.0) for p in points]
    out = []
    count = len(pts)
    for i, (r, z, rad) in enumerate(pts):
        has_prev = closed or i > 0
        has_next = closed or i < count - 1
        if rad <= 0 or not (has_prev and has_next):
            out.append((r, z))
            continue
        p1 = Vector((r, z))
        p0 = Vector(pts[i - 1][:2])
        p2 = Vector(pts[(i + 1) % count][:2])
        d0, d2 = p0 - p1, p2 - p1
        rr = min(rad, d0.length * 0.48, d2.length * 0.48)
        a = p1 + d0.normalized() * rr
        b = p1 + d2.normalized() * rr
        for k in range(n + 1):
            t = k / n
            q = a * (1 - t) ** 2 + p1 * 2 * (1 - t) * t + b * t * t
            out.append((q.x, q.y))
    return out


def axis_matrix(axis, origin):
    rot = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized()).to_matrix().to_4x4()
    return Matrix.Translation(Vector(origin)) @ rot


def lathe(name, profile, cell, seg=48, axis=(0, 0, 1), origin=(0, 0, 0), phase=0.0, closed=False, parent=None,
          rounding=3, shift=True):
    """Surface of revolution. Profile (r, z) runs counter-clockwise in the r/z plane (outer walls going up) so faces
    point outward. Open profiles should start and end on the axis (r = 0)."""
    if seg > 6:
        seg = max(8, int(round(seg * SEG_K)))
    prof = rounded(profile, closed, rounding)
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    rows = []
    for r, z in prof:
        if r < 1e-6:
            rows.append([bm.verts.new((0, 0, z))])
        else:
            rows.append([bm.verts.new((r * math.cos(phase + math.tau * j / seg),
                                        r * math.sin(phase + math.tau * j / seg), z)) for j in range(seg)])
    lengths = [0.0]
    pairs = list(zip(prof, prof[1:] + ([prof[0]] if closed else [])))
    for (r0, z0), (r1, z1) in pairs:
        lengths.append(lengths[-1] + math.hypot(r1 - r0, z1 - z0))
    total = lengths[-1] or 1.0
    nrows = len(rows)
    for i in range(len(pairs)):
        a, b = rows[i], rows[(i + 1) % nrows]
        va, vb = lengths[i] / total, lengths[i + 1] / total
        for j in range(seg):
            j1 = (j + 1) % seg
            ua, ub = j / seg, (j + 1) / seg
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                verts, uvs = (a[0], b[j1], b[j]), ((ua + 0.5 / seg, va), (ub, vb), (ua, vb))
            elif len(b) == 1:
                verts, uvs = (a[j], a[j1], b[0]), ((ua, va), (ub, va), (ua + 0.5 / seg, vb))
            else:
                verts, uvs = (a[j], a[j1], b[j1], b[j]), ((ua, va), (ub, va), (ub, vb), (ua, vb))
            try:
                face = bm.faces.new(verts)
            except ValueError:
                continue
            for loop, (u, v) in zip(face.loops, uvs):
                loop[uv].uv = cell_uv(cell, u, v)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bm.transform(axis_matrix(axis, origin))
    bm.normal_update()
    return finish(name, bm, cell, parent, shift)


def box_uv(bm, cell):
    uv = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.new("UVMap")
    co = [v.co for v in bm.verts]
    lo = Vector((min(c.x for c in co), min(c.y for c in co), min(c.z for c in co)))
    hi = Vector((max(c.x for c in co), max(c.y for c in co), max(c.z for c in co)))
    span = max(hi - lo) or 1.0
    for face in bm.faces:
        n = face.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        a, b = [(1, 2), (0, 2), (0, 1)][ax]
        for loop in face.loops:
            p = loop.vert.co
            loop[uv].uv = cell_uv(cell, (p[a] - lo[a]) / span, (p[b] - lo[b]) / span)


def rbox(name, center, size, cell, bevel_w, segs=4, parent=None, rot_z=0.0, profile=0.5, band_edge=None):
    """Rounded box. With band_edge set, the four edges along Y get the big rounding (so a thin band wrapping the
    capacitor box follows its curvature) and the band's own faces get a small band_edge rounding."""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if band_edge:
        along_y = [e for e in bm.edges if abs((e.verts[0].co - e.verts[1].co).normalized().y) > 0.9]
        bmesh.ops.bevel(bm, geom=along_y, offset=bevel_w, offset_type="OFFSET", segments=segs, profile=profile,
                        affect="EDGES", clamp_overlap=False)
        bm.normal_update()
        rest = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(60)]
        bmesh.ops.bevel(bm, geom=rest, offset=band_edge, offset_type="OFFSET", segments=3, profile=0.5,
                        affect="EDGES", clamp_overlap=True)
    else:
        bmesh.ops.bevel(bm, geom=list(bm.edges) + list(bm.verts), offset=bevel_w, offset_type="OFFSET",
                        segments=segs, profile=profile, affect="EDGES", clamp_overlap=True)
    bm.normal_update()
    box_uv(bm, cell)
    bm.transform(Matrix.Translation(Vector(center)) @ Matrix.Rotation(rot_z, 4, "Z"))
    bm.normal_update()
    return finish(name, bm, cell, parent)


def helix(name, radius, wire, z0, z1, turns, cell, parent=None, steps_per_turn=22, ring=7):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    n = int(turns * steps_per_turn)
    pitch = (z1 - z0) / (turns * math.tau)
    rings = []
    for i in range(n + 1):
        ang = math.tau * turns * i / n
        c = Vector((radius * math.cos(ang), radius * math.sin(ang), z0 + pitch * ang))
        tan = Vector((-radius * math.sin(ang), radius * math.cos(ang), pitch)).normalized()
        nor = Vector((math.cos(ang), math.sin(ang), 0))
        bi = tan.cross(nor)
        rings.append([bm.verts.new(c + wire * (math.cos(math.tau * k / ring) * nor + math.sin(math.tau * k / ring) * bi))
                      for k in range(ring)])
    for i in range(n):
        for k in range(ring):
            k1 = (k + 1) % ring
            face = bm.faces.new((rings[i][k], rings[i][k1], rings[i + 1][k1], rings[i + 1][k]))
            for loop, (u, v) in zip(face.loops, ((i / n, k / ring), (i / n, (k + 1) / ring),
                                                 ((i + 1) / n, (k + 1) / ring), ((i + 1) / n, k / ring))):
                loop[uv].uv = cell_uv(cell, u, v)
    for r in (rings[0], rings[-1]):
        bm.faces.new(r)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return finish(name, bm, cell, parent)


def dome(name, center, axis, radius, height, cell, parent=None, seg=30, base_drop=0.004, shift=True):
    """Jewel / stud dome sitting on a surface, crown pointing along axis."""
    prof = [(0, -base_drop), (radius, -base_drop), (radius, 0.0)]
    for k in range(1, 6):
        a = k / 5 * math.pi / 2
        prof.append((radius * math.cos(a), height * math.sin(a)))
    prof[-1] = (0, height)
    return lathe(name, prof, cell, seg, axis, center, parent=parent, rounding=3, shift=shift)


# --------------------------------------------------------------------------------------------------------------------
# Static base: brass feet, teal plinth, coral hex pedestal, brass collar, black spring column
# --------------------------------------------------------------------------------------------------------------------
FOOT_ANGLES = [math.radians(a) for a in (90, 210, 330)]
for i, ang in enumerate(FOOT_ANGLES):
    c = Vector((math.cos(ang), math.sin(ang), 0)) * 0.39
    rbox(f"Foot_{i}", (c.x, c.y, 0.065), (0.20, 0.23, 0.13), "brass", 0.04, segs=1, parent=BASE, rot_z=ang)
    cap = Vector((math.cos(ang), math.sin(ang), 0)) * 0.43
    rbox(f"FootCap_{i}", (cap.x, cap.y, 0.132), (0.10, 0.14, 0.02), "brass", 0.008, segs=2, parent=BASE, rot_z=ang)

lathe("Plinth", [(0, 0.03), (0.37, 0.03, 0.015), (0.385, 0.055, 0.015), (0.385, 0.125, 0.02), (0.35, 0.15, 0.02),
                 (0, 0.15)], "teal", seg=6, phase=math.radians(30), parent=BASE)
lathe("PlinthSkirt", [(0, 0.012), (0.30, 0.012, 0.01), (0.31, 0.04), (0, 0.04)], "tealdeep", seg=6,
      phase=math.radians(30), parent=BASE)
lathe("Pedestal", [(0, 0.145), (0.29, 0.145, 0.012), (0.295, 0.16, 0.012), (0.295, 0.265, 0.03), (0.245, 0.32, 0.02),
                   (0, 0.32)], "coral", seg=6, phase=math.radians(30), parent=BASE)

# Violet studs: three on the top chamfer corners, three on alternating side faces.
for i, deg in enumerate((30, 150, 270)):
    a = math.radians(deg)
    d = Vector((math.cos(a), math.sin(a), 0))
    p = d * 0.215 + Vector((0, 0, 0.318))
    dome(f"StudTop_{i}", p, (0, 0, 1), 0.027, 0.02, "violet", BASE, seg=16)
for i, deg in enumerate((0, 120, 240)):
    a = math.radians(deg)
    d = Vector((math.cos(a), math.sin(a), 0))
    apothem = 0.295 * math.cos(math.radians(30))
    dome(f"StudSide_{i}", d * apothem + Vector((0, 0, 0.215)), d, 0.024, 0.016, "violet", BASE, seg=16)
    lathe(f"StudBezel_{i}", [(0.024, -0.003), (0.034, -0.003), (0.034, 0.006, 0.003), (0.024, 0.006)], "brass",
          seg=20, axis=d, origin=d * apothem + Vector((0, 0, 0.215)), closed=True, parent=BASE, rounding=2)

lathe("PedestalCollar", [(0.062, 0.31), (0.118, 0.31, 0.01), (0.122, 0.37, 0.018), (0.10, 0.392, 0.012),
                         (0.062, 0.392)], "brass", closed=True, parent=BASE)
lathe("Column", [(0, 0.30), (0.056, 0.30), (0.056, 0.585, 0.01), (0, 0.585)], "dark", seg=32, parent=BASE)
helix("Spring", 0.064, 0.0115, 0.395, 0.565, 4.5, "black", parent=BASE)
lathe("ColumnRing", [(0.055, 0.565), (0.08, 0.565, 0.006), (0.08, 0.58, 0.006), (0.055, 0.58)], "brass", seg=32,
      closed=True, parent=BASE, rounding=2)

# --------------------------------------------------------------------------------------------------------------------
# Aim: capacitor box, bands, jewels, lance
# --------------------------------------------------------------------------------------------------------------------
lathe("Neck", [(0, 0.578), (0.09, 0.578, 0.02), (0.125, 0.60, 0.02), (0.125, 0.70), (0, 0.70)], "coral", seg=40,
      parent=AIM, shift=False)
dome("NeckBolt", (0, 0.122, 0.635), (0, 1, 0), 0.026, 0.016, "brass", AIM, seg=20, shift=False)

BOX_C = Vector((0, -0.03, 0.90))
BOX_S = Vector((0.50, 0.54, 0.46))
rbox("CapacitorBox", BOX_C, BOX_S, "teal", 0.09, segs=4, parent=AIM)
BAND_Y = -0.085
rbox("CoralBand", (0, BAND_Y, 0.90), (0.53, 0.13, 0.49), "coral", 0.105, segs=5, parent=AIM, band_edge=0.02)
rbox("CoralRearBand", (0, -0.212, 0.90), (0.52, 0.046, 0.48), "coral", 0.10, segs=5, parent=AIM, band_edge=0.014)

# Rear capacitor end cap (teal drum out of the back) with a brass trim.
lathe("RearCap", [(0, 0.0), (0.125, 0.0), (0.125, 0.035, 0.015), (0.105, 0.06, 0.02), (0, 0.06)], "teal", seg=40,
      axis=(0, -1, 0), origin=(0, -0.29, 0.92), parent=AIM)
lathe("RearCapTrim", [(0.118, 0.01), (0.138, 0.01, 0.006), (0.138, 0.03, 0.006), (0.118, 0.03)], "brass", seg=40,
      axis=(0, -1, 0), origin=(0, -0.29, 0.92), closed=True, parent=AIM, rounding=2)

lathe("RearBoss", [(0.035, -0.004), (0.06, -0.004, 0.006), (0.062, 0.018, 0.008), (0.035, 0.018)], "brass",
      seg=40, axis=(0, -1, 0), origin=(0, -0.35, 0.92), closed=True, parent=AIM, rounding=2)
dome("RearJewel", (0, -0.354, 0.92), (0, -1, 0), 0.04, 0.03, "violet", AIM)

# Top brass ring holding the mint dome jewel.
TOP = BOX_C.z + BOX_S.z / 2
lathe("TopRing", [(0.066, TOP - 0.02), (0.104, TOP - 0.02, 0.01), (0.106, TOP + 0.03, 0.016),
                  (0.088, TOP + 0.045, 0.01), (0.066, TOP + 0.045)], "brass", closed=True,
      origin=(0, 0.075, 0), parent=AIM)
lathe("TopSeat", [(0, TOP - 0.01), (0.07, TOP - 0.01), (0.07, TOP + 0.012), (0, TOP + 0.012)], "dark", seg=32,
      origin=(0, 0.075, 0), parent=AIM)
dome("TopJewel", (0, 0.075, TOP + 0.01), (0, 0, 1), 0.066, 0.062, "mint", AIM)

# Side jewels in coral bezels on the band (both sides).
for side, sx in (("R", 1), ("L", -1)):
    ax = (sx, 0, 0)
    base = Vector((sx * 0.262, BAND_Y, 0.90))
    lathe(f"SideBezel_{side}", [(0, 0.0), (0.108, 0.0), (0.108, 0.03, 0.015), (0.09, 0.048, 0.012), (0.07, 0.048),
                                (0.07, 0.04), (0, 0.04)], "coral", seg=40, axis=ax, origin=base, parent=AIM)
    lathe(f"SideJewelRim_{side}", [(0.068, 0.038), (0.078, 0.038, 0.004), (0.078, 0.052, 0.005), (0.068, 0.052)],
          "brass", seg=40, axis=ax, origin=base, closed=True, parent=AIM, rounding=2)
    dome(f"SideJewel_{side}", base + Vector(ax) * 0.04, ax, 0.068, 0.05, "mint", AIM)
    # Small violet jewels low on the front corner of each side face.
    dome(f"VioletJewel_{side}", (sx * 0.25, 0.15, 0.745), ax, 0.022, 0.015, "violet", AIM, seg=16)
    dome(f"VioletJewelHi_{side}", (sx * 0.25, -0.255, 0.76), ax, 0.018, 0.012, "violet", AIM, seg=16)

# Steel rivets: front face corners, side face front corners, back corners.
FRONT_Y = BOX_C.y + BOX_S.y / 2
for i, (x, z) in enumerate(((-0.17, 0.75), (0.17, 0.75), (-0.17, 1.05), (0.17, 1.05))):
    dome(f"RivetFront_{i}", (x, FRONT_Y, z), (0, 1, 0), 0.016, 0.011, "steel", AIM, seg=14)
for side, sx in (("R", 1), ("L", -1)):
    for j, z in enumerate((1.05,)):
        dome(f"RivetSide_{side}{j}", (sx * 0.25, 0.15, z), (sx, 0, 0), 0.016, 0.011, "steel", AIM, seg=14)
BACK_Y = BOX_C.y - BOX_S.y / 2
for i, (x, z) in enumerate(((-0.17, 0.75), (0.17, 0.75), (-0.17, 1.05), (0.17, 1.05))):
    dome(f"RivetBack_{i}", (x, BACK_Y, z), (0, -1, 0), 0.016, 0.011, "steel", AIM, seg=14)

# Lance: brass entry collar, teal shaft, charging ring, ivory cone, mint jewel point. Profiles are (r, y).
LANCE = dict(axis=(0, 1, 0), origin=(0, 0, SHAFT_Z), parent=AIM)
TIPL = dict(axis=(0, 1, 0), origin=(0, TIP_DY, SHAFT_Z), parent=AIM)
lathe("EntryCollar", [(0.112, FRONT_Y - 0.03), (0.182, FRONT_Y - 0.03, 0.01), (0.182, FRONT_Y + 0.055, 0.026),
                      (0.16, FRONT_Y + 0.09, 0.014), (0.112, FRONT_Y + 0.09, 0.008)], "brass", seg=56, closed=True,
      **LANCE)
lathe("EntryRecess", [(0.09, FRONT_Y - 0.02), (0.116, FRONT_Y - 0.02), (0.116, FRONT_Y + 0.08), (0.09, FRONT_Y + 0.08)],
      "dark", seg=40, closed=True, **LANCE)
lathe("Shaft", [(0, FRONT_Y - 0.02), (0.095, FRONT_Y - 0.02), (0.095, 0.70 + TIP_DY), (0, 0.70 + TIP_DY)], "teal", seg=48, **LANCE)
lathe("ChargeBacking", [(0.08, 0.632), (0.138, 0.632, 0.008), (0.138, 0.66), (0.08, 0.66)], "coral", seg=48,
      closed=True, **TIPL)
lathe("ChargingRing", [(0.08, 0.655), (0.145, 0.655, 0.012), (0.152, 0.70, 0.02), (0.148, 0.765, 0.014),
                       (0.128, 0.78, 0.008), (0.08, 0.78)], "brass", seg=56, closed=True, **TIPL)
cone = [(0, 0.72), (0.128, 0.72)]
for k in range(1, 13):
    t = k / 12
    cone.append((0.032 + (0.128 - 0.032) * (1 - t ** 1.3), 0.74 + 0.27 * t))
cone[-1] = (0.032, 1.01, 0.012)
cone.append((0, 1.012))
lathe("CeramicTip", cone, "ivory", seg=56, rounding=4, **TIPL)
lathe("JewelPoint", [(0, 0.998), (0.036, 0.998), (0.037, 1.006, 0.004), (0.015, 1.044, 0.008), (0, 1.054)], "mint",
      seg=40, rounding=4, **TIPL)

MUZZLE = empty("Muzzle", (0, 1.055 + TIP_DY + HEAD_DY, SHAFT_Z - AIM_POS.z), AIM)


# --------------------------------------------------------------------------------------------------------------------
# Merge: one mesh per (static base | rotating head) x material
# --------------------------------------------------------------------------------------------------------------------
from collections import defaultdict

groups = defaultdict(list)
for o in [o for o in bpy.data.objects if o.type == "MESH"]:
    groups[(o.parent.name, o.data.materials[0].name)].append(o)
for (pname, mname), objs in groups.items():
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    if len(objs) > 1:
        bpy.ops.object.join()
    keep = bpy.context.view_layer.objects.active
    keep.name = f"{'Head' if pname == 'Aim' else 'Base'}_{mname}"
    keep.data.name = keep.name

# --------------------------------------------------------------------------------------------------------------------
# Export
# --------------------------------------------------------------------------------------------------------------------
bpy.context.view_layer.update()
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
tris = 0
for o in meshes:
    o.data.calc_loop_triangles()
    tris += len(o.data.loop_triangles)
print(f"THUNDER_PIN meshes={len(meshes)} tris={tris} materials={len(bpy.data.materials)}")
bpy.ops.export_scene.gltf(filepath=str(OUT / "cp_thunder_pin.glb"), export_format="GLB", export_yup=True,
                          export_animations=False, export_cameras=False, export_lights=False)

"""Glass Dome Shock Turret (engine visibility pass) - scripted Blender build with an authored four-map texture atlas.

Run:  blender --background --python build_cp_shock_dome3.py
Writes cp_shock_dome3.glb (and the four atlas PNGs in ./textures) next to this script.

Engine pass (continuation of cp_shock_dome2): the same glass-dome shock turret, retuned for how it reads in Godot
(Filmic tonemap, glow threshold 1.0, a high game camera about 50-60 degrees looking down, ~60 px tall on screen):
  1. glass jar   - alpha ~0.42 per surface, bright thick baked rim bands top and bottom, solid ivory (base) and brass (top)
                   collars so the dome visibly sits on a jar that visibly sits on the base
  2. crystal     - 1.4x bigger, much taller jar and a flatter dome so the lower half of the gem shows below the cap from the
                   game camera; emissive strengths 4.0 / 2.0 / 2.5 (well past the glow threshold) with a white-hot core, warm light
                   spill on the coil and the ivory disc so the lamp reads even where the gem is hidden by the cap
  3. brass       - metallic ~0.68 (not 0.9), brighter warm albedo, roughness ~0.38 and a small warm self-lit term so the teal
                   environment cannot turn it olive
  4. teal enamel - retuned from cyan to a softer, deeper teal centred on #2aa89a

Layout  : metres, +Z up, weapon faces +Y. Origin on the base centre, feet on the ground.
Rig     : TurretModel > (static base meshes, Aim > (jar, collar, dome, coil, crystal layers, glow ...), Muzzle under Aim).
Textures: every mesh is UV-mapped into ONE shared 1024x1024 atlas (albedo+alpha, ORM, normal, emissive).
          Maps are painted from the *world position / normal / curvature* of each texel (rasterised from the real
          mesh), so ambient occlusion, edge wear and material gradients are baked per texel without Cycles.
          R of the ORM map is occlusion, G roughness, B metallic (glTF packing).
"""
import math
import os
import time
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

T0 = time.time()
HERE = Path(__file__).resolve().parent
GLB = HERE / "cp_shock_dome3.glb"
TEX_DIR = HERE / "textures"
QUICK = bool(os.environ.get("DOME_QUICK"))   # private fast iteration only (coarse AO bake); the harness never sets it
A = 1024          # atlas size
PAD = 3           # gutter (px) around every UV region
AIM_Z = 0.25      # height of the Aim pivot (ring top)

# ---- vertical layout of the head (world z, metres) -------------------------------------------------------------------
JAR_Z0, JAR_Z1 = 0.251, 1.030     # glass jar: very tall so the lamp window under the cap is large from a high camera
JAR_RO, JAR_RI = 0.293, 0.280
BASE_COLLAR_TOP = 0.302           # ivory collar where the jar meets the base ring
LIP = 0.990                       # bottom edge of the teal dome
SKIRT_TOP = 1.025                 # top of the straight dome skirt, the (flatter) crown starts here
H_CROWN = 0.115                   # crown height (v2: 0.160)
CT = SKIRT_TOP + H_CROWN          # crown top = 1.140
COLLAR_Z0, COLLAR_Z1 = 0.987, 1.031   # brass collar band wrapped around the dome lip
DOME_R, DOME_RI = 0.3055, 0.297
DOME_SE = 2.0 / 2.4               # superellipse exponent: fuller bullet shoulder than a plain ellipse

# ---- crystal: 1.4x the v2 gem. Placement is a geometric compromise (see notes): from a 50-60 degree camera the opaque cap
# hides everything whose screen position is above the cap's front rim, so a HIGHER gem is hidden MORE. The jar is 0.19 m
# taller instead (rim 0.22 m higher) and the gem sits low in the window so about half of it shows under the rim.
CRYSTAL_C = np.array([0.0, 0.0, 0.50])
CRYSTAL_R = 0.161       # mean radius of the outer cut gem (v2 0.115)
CORE_R = 0.112          # mean radius of the inner hot core gem (v2 0.080)
NF_SHELL = 72           # facets of the outer gem (more, so the silhouette is rounder)
NF_CORE = 24            # facets of the inner gem
# emission strengths: far above Godot's glow threshold (1.0) so the gem blooms under Filmic; exported as
# KHR_materials_emissive_strength (importers without it clamp to 1.0 and still look lit)
EMI_CORE = 3.6
EMI_SHELL = 2.0
EMI_GLOW = 2.5
DISC_DZ = -0.025   # the ivory disc sits this much lower than in v2 (top level with the ring), more room for the spring
COIL_Z0 = 0.2835 + DISC_DZ
SEGS = 48         # radial segments of the big lathe parts
SEGS_BIG = 64     # jar, dome, collars: the large visible silhouettes


def log(msg):
    print(f"[build {time.time() - T0:6.1f}s] {msg}", flush=True)


# ----------------------------------------------------------------------------------------------------------------------
# Atlas layout: name -> (x, y, w, h) in pixels (y counted from the bottom, like Blender UVs). The rect includes the gutter.
# The big regions are fixed; the small ones are shelf-packed underneath them.
# ----------------------------------------------------------------------------------------------------------------------
SHELL_CELL, SHELL_COLS = 42, 8          # one 42 px square cell per facet (8 x 9 grid = 72)
CORE_CELL, CORE_COLS = 36, 10           # 10 x 3 grid
FLECK_CELL, FLECK_COLS = 24, 7          # 7 x 4 grid
REGIONS = {
    "ring": (0, 0, 1024, 224),
    "coil": (0, 224, 1024, 64),
    "shell": (0, 288, SHELL_COLS * SHELL_CELL, 384),    # outer gem: planar per-facet islands, identical texel density
    "dome": (336, 288, 688, 160),
    "glass": (336, 448, 688, 224),
}


def shelf_pack(items, y0):
    shelves, out, y = [], {}, y0
    for name, w, h in sorted(items, key=lambda t: (-t[2], -t[1])):
        for sh in shelves:
            if h <= sh[1] and sh[2] + w <= A:
                out[name] = (sh[2], sh[0], w, h)
                sh[2] += w
                break
        else:
            shelves.append([y, h, w])
            out[name] = (0, y, w, h)
            y += h
    assert y <= A, f"atlas overflow: {y}"
    return out


_small = [("core", 360, 108), ("fleck", 168, 96), ("halo", 112, 112), ("spark", 52, 52), ("disc", 384, 96), ("saucer", 384, 96),
          ("finial", 224, 112), ("capdisc", 288, 96), ("collar_top", 320, 48), ("collar_base", 320, 48)]
_small += [(f"foot{i}", 96, 80) for i in range(3)] + [(f"stud{i}", 64, 48) for i in range(3)]
_small += [(f"dstud{i}", 48, 40) for i in range(4)] + [(f"cap{i}", 64, 56) for i in range(3)]
REGIONS.update(shelf_pack(_small, 672))
# Regions whose left/right (u) or top/bottom (v) edges wrap, so the gutter is filled with the wrapped texels.
WRAP = {k: "u" for k in REGIONS}
WRAP.update({"coil": "v", "shell": None, "core": None, "halo": None, "spark": None, "fleck": None})


def check_layout():
    grid = np.zeros((A, A), np.int8)
    for name, (x, y, w, h) in REGIONS.items():
        assert x >= 0 and y >= 0 and x + w <= A and y + h <= A, name
        assert grid[y:y + h, x:x + w].sum() == 0, f"overlap {name}"
        grid[y:y + h, x:x + w] = 1


def to_atlas(region, u, v):
    x0, y0, w, h = REGIONS[region]
    return ((x0 + PAD + u * (w - 2 * PAD)) / A, (y0 + PAD + v * (h - 2 * PAD)) / A)


# ----------------------------------------------------------------------------------------------------------------------
# Geometry generators. Each returns {"verts": (N,3), "faces": [[..]], "uvs": [[(u,v)..]] (atlas uv per corner), "wear": (N,)}
# ----------------------------------------------------------------------------------------------------------------------
def arc(cx, cz, radius, a0, a1, n):
    return [(cx + radius * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cz + radius * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def join_path(*parts):
    out = []
    for part in parts:
        for p in part:
            if not out or math.hypot(p[0] - out[-1][0], p[1] - out[-1][1]) > 1e-7:
                out.append((float(p[0]), float(p[1])))
    return out


def sphere_path(radius, n):
    return arc(0.0, 0.0, radius, -90, 90, n)


def lathe(paths, segs, region, wear_on=True, scale=(1, 1, 1), rot=None, offset=(0, 0, 0), hard_deg=50.0):
    """Revolve profile paths (r, z) around Z. Paths run counter-clockwise around the solid in the (r, z) view so the
    exterior is on their right and faces point outward. Corners sharper than hard_deg split the path (hard edge).
    Per-vertex wear is 1 on convex rounded edges (turning angle), used later for polished-edge wear in the textures."""
    polylines = []
    for pts, weight in paths:
        n = len(pts)
        tans = []
        for i in range(n - 1):
            dx, dz = pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]
            length = math.hypot(dx, dz)
            tans.append((dx / length, dz / length))
        wear = [0.0] * n
        cuts = []
        for i in range(1, n - 1):
            ax, az = tans[i - 1]
            bx, bz = tans[i]
            ang = math.atan2(ax * bz - az * bx, ax * bx + az * bz)
            if wear_on and ang > 0:
                wear[i] = min(1.0, max(0.0, (ang - 0.06) / 0.2))
            if abs(math.degrees(ang)) > hard_deg:
                cuts.append(i)
                wear[i] = 1.0 if (wear_on and ang > 0) else 0.0
        bounds = [0] + cuts + [n - 1]
        for a, b in zip(bounds[:-1], bounds[1:]):
            polylines.append(([(pts[i][0], pts[i][1], wear[i]) for i in range(a, b + 1)], weight))

    def plen(pl):
        return sum(math.hypot(pl[i + 1][0] - pl[i][0], pl[i + 1][1] - pl[i][1]) for i in range(len(pl) - 1))

    total = sum(w * plen(pl) for pl, w in polylines)
    verts, faces, uvs, wears = [], [], [], []
    cursor = 0.0
    for pl, weight in polylines:
        length = plen(pl)
        span = weight * length / total
        cum = 0.0
        rows = []
        for i, (r, z, wv) in enumerate(pl):
            if i:
                cum += math.hypot(r - pl[i - 1][0], z - pl[i - 1][1])
            v = cursor + span * (cum / length)
            if r < 1e-7:
                verts.append((0.0, 0.0, z))
                wears.append(wv)
                rows.append(([len(verts) - 1] * segs, True, v))
            else:
                base = len(verts)
                for j in range(segs):
                    th = math.tau * j / segs
                    verts.append((r * math.cos(th), r * math.sin(th), z))
                    wears.append(wv)
                rows.append((list(range(base, base + segs)), False, v))
        cursor += span
        for k in range(len(rows) - 1):
            ia, apa, va = rows[k]
            ib, apb, vb = rows[k + 1]
            for j in range(segs):
                j1 = (j + 1) % segs
                ua, ub, um = j / segs, (j + 1) / segs, (j + 0.5) / segs
                if apa:
                    faces.append([ia[j], ib[j1], ib[j]])
                    uv = [(um, va), (ub, vb), (ua, vb)]
                elif apb:
                    faces.append([ia[j], ia[j1], ib[j1]])
                    uv = [(ua, va), (ub, va), (um, vb)]
                else:
                    faces.append([ia[j], ia[j1], ib[j1], ib[j]])
                    uv = [(ua, va), (ub, va), (ub, vb), (ua, vb)]
                uvs.append([to_atlas(region, u, v) for u, v in uv])
    V = np.array(verts, np.float64) * np.array(scale)
    if rot is not None:
        V = V @ np.array(rot).T
    V = V + np.array(offset)
    return {"verts": V, "faces": faces, "uvs": uvs, "wear": np.array(wears)}


def helix_tube(radius, tube, z0, pitch, turns, steps_per_turn, sides, region):
    n = int(round(turns * steps_per_turn))
    verts = []
    for i in range(n + 1):
        phi = math.tau * turns * i / n
        c = np.array([radius * math.cos(phi), radius * math.sin(phi), z0 + pitch * phi / math.tau])
        tangent = np.array([-radius * math.sin(phi), radius * math.cos(phi), pitch / math.tau])
        tangent /= np.linalg.norm(tangent)
        n1 = np.array([math.cos(phi), math.sin(phi), 0.0])
        n2 = np.cross(tangent, n1)
        taper = max(0.12, min(1.0, i / (0.05 * n), (n - i) / (0.05 * n)) ** 0.5)
        for j in range(sides):
            al = math.tau * j / sides
            verts.append(c + tube * taper * (math.cos(al) * n1 + math.sin(al) * n2))
    V = np.array(verts)
    faces, uvs = [], []
    for i in range(n):
        for j in range(sides):
            j1 = (j + 1) % sides
            f = [i * sides + j, i * sides + j1, (i + 1) * sides + j1, (i + 1) * sides + j]
            faces.append(f)
            uvs.append([to_atlas(region, i / n, j / sides), to_atlas(region, i / n, (j + 1) / sides),
                        to_atlas(region, (i + 1) / n, (j + 1) / sides), to_atlas(region, (i + 1) / n, j / sides)])
    # make sure the winding points away from the tube axis
    f = faces[len(faces) // 2]
    p = V[f]
    normal = np.cross(p[1] - p[0], p[2] - p[0])
    i = (len(faces) // 2) // sides
    centre = np.array([radius * math.cos(math.tau * turns * (i + 0.5) / n), radius * math.sin(math.tau * turns * (i + 0.5) / n),
                       z0 + pitch * turns * (i + 0.5) / n])
    if np.dot(normal, p.mean(0) - centre) < 0:
        faces = [list(reversed(f)) for f in faces]
        uvs = [list(reversed(u)) for u in uvs]
    return {"verts": V, "faces": faces, "uvs": uvs, "wear": np.zeros(len(V))}


def fib_sphere(n):
    i = np.arange(n) + 0.5
    ph = np.arccos(1 - 2 * i / n)
    th = math.pi * (1 + 5 ** 0.5) * i
    return np.stack([np.cos(th) * np.sin(ph), np.sin(th) * np.sin(ph), np.cos(ph)], 1)


def hull_triangles(points):
    """Triangles (index triples) of the convex hull of `points`."""
    bm = bmesh.new()
    vs = [bm.verts.new(tuple(float(c) for c in p)) for p in points]
    res = bmesh.ops.convex_hull(bm, input=vs, use_existing_faces=False)
    idx = {v: i for i, v in enumerate(vs)}
    tris = []
    for g in res["geom"]:
        if isinstance(g, bmesh.types.BMFace):
            tris.append(tuple(idx[v] for v in g.verts))
    bm.free()
    return tris


def dual_gem(nf, seed, dir_jit, depth_jit, mean_r):
    """Convex 'cut gem': the intersection of nf half-spaces n_i . x <= d_i. Every facet is one exactly planar polygon of
    its own size (irregular like a hand-cut stone). Built through the polar dual: the hull triangles of n_i / d_i are the
    polyhedron's vertices, the triangles around point i are the corners of facet i. Returns (vertices, facets)."""
    rng = np.random.default_rng(seed)
    n = fib_sphere(nf) + rng.normal(0, dir_jit, (nf, 3))
    n /= np.linalg.norm(n, axis=1, keepdims=True)
    d = 1.0 + rng.uniform(-depth_jit, depth_jit, nf)
    tris = hull_triangles(n / d[:, None])
    X = np.array([np.linalg.solve(np.stack([n[a], n[b], n[c]]), np.array([d[a], d[b], d[c]])) for a, b, c in tris])
    X *= mean_r / np.linalg.norm(X, axis=1).mean()
    inc = {}
    for fi, tri in enumerate(tris):
        for p in tri[:3]:
            inc.setdefault(p, []).append(fi)
    facets = []
    for p in sorted(inc):
        fl = inc[p]
        if len(fl) < 3:
            continue
        pts = X[fl]
        cen = pts.mean(0)
        nrm = n[p]
        helper = np.array([0.0, 0.0, 1.0]) if abs(nrm[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
        t1 = np.cross(helper, nrm)
        t1 /= np.linalg.norm(t1)
        t2 = np.cross(nrm, t1)
        ang = np.arctan2((pts - cen) @ t2, (pts - cen) @ t1)
        order = np.argsort(ang)
        facets.append({"normal": nrm, "corners": [fl[k] for k in order], "t1": t1, "t2": t2})
    return X, facets


def gem_part(X, facets, centre, region, cell, cols):
    """Mesh dict for a dual gem: each facet is a fan of triangles around a centre vertex (per-vertex wear: 0 at the
    facet centre, 1 on its edges, which the painters use for edge glints). One UV island (planar projection, identical
    texel density) per facet, laid out on a grid of `cell` px squares inside `region`. facet attr = facet id."""
    x0, y0, w, h = REGIONS[region]
    assert len(facets) <= cols * (h // cell), (region, len(facets))
    rmax = 0.0
    for f in facets:
        pts = X[f["corners"]]
        rmax = max(rmax, np.linalg.norm(pts - pts.mean(0), axis=1).max())
    sc = (cell - 2 * PAD) / (2 * rmax)
    verts = [X[i] + centre for i in range(len(X))]
    wears = [1.0] * len(X)
    faces, uvs, fids = [], [], []
    for k, f in enumerate(facets):
        cs = f["corners"]
        cen = X[cs].mean(0)
        ci = len(verts)
        verts.append(cen + centre)
        wears.append(0.0)
        cx = x0 + (k % cols) * cell + cell / 2
        cy = y0 + (k // cols) * cell + cell / 2

        def uv(p, cen=cen, f=f, cx=cx, cy=cy):
            dd = p - cen
            return ((cx + (dd @ f["t1"]) * sc) / A, (cy + (dd @ f["t2"]) * sc) / A)

        for j in range(len(cs)):
            a, b = cs[j], cs[(j + 1) % len(cs)]
            faces.append([ci, a, b])
            uvs.append([uv(cen), uv(X[a]), uv(X[b])])
            fids.append(float(k))
    return {"verts": np.array(verts), "faces": faces, "uvs": uvs, "wear": np.array(wears), "facet": np.array(fids)}


def build_shell():
    X, facets = dual_gem(NF_SHELL, 31, 0.13, 0.045, CRYSTAL_R * 1.03)
    log(f"shell facets={len(facets)} verts={len(X)}")
    return gem_part(X, facets, CRYSTAL_C, "shell", SHELL_CELL, SHELL_COLS)


def build_core():
    X, facets = dual_gem(NF_CORE, 77, 0.16, 0.05, CORE_R * 1.04)
    log(f"core facets={len(facets)} verts={len(X)}")
    return gem_part(X, facets, CRYSTAL_C, "core", CORE_CELL, CORE_COLS)


def build_flecks(n=24, cell=FLECK_CELL, cols=FLECK_COLS):
    """Small bright planar plates (4-6 sided) floating just inside the shell, at random tangents: the 'bright facet
    shards' seen inside the concept's resin. One UV cell per plate, one global texel density."""
    rng = np.random.default_rng(89)
    x0, y0, w, h = REGIONS["fleck"]
    rmax = 0.034
    sc = (cell - 2 * PAD) / (2 * rmax)
    verts, faces, uvs, fids = [], [], [], []
    for k in range(n):
        d = rng.normal(size=3)
        d /= np.linalg.norm(d)
        c = CRYSTAL_C + d * rng.uniform(0.122, 0.131)
        nrm = d + rng.normal(size=3) * 0.55
        nrm /= np.linalg.norm(nrm)
        helper = np.array([0.0, 0.0, 1.0]) if abs(nrm[2]) < 0.9 else np.array([1.0, 0.0, 0.0])
        t1 = np.cross(helper, nrm)
        t1 /= np.linalg.norm(t1)
        t2 = np.cross(nrm, t1)
        sides = int(rng.integers(4, 7))
        size = rng.uniform(0.018, 0.027)
        ang = np.sort(rng.uniform(0, math.tau, sides) * 0.0 + (np.arange(sides) + rng.uniform(-0.25, 0.25, sides)) * math.tau / sides)
        rad = size * rng.uniform(0.75, 1.25, sides)
        base = len(verts)
        cx = x0 + (k % cols) * cell + cell / 2
        cy = y0 + (k // cols) * cell + cell / 2
        uv = []
        for a, r in zip(ang, rad):
            local = np.cos(a) * t1 * r + np.sin(a) * t2 * r
            verts.append(c + local)
            uv.append(((cx + r * math.cos(a) * sc) / A, (cy + r * math.sin(a) * sc) / A))
        faces.append(list(range(base, base + sides)))
        uvs.append(uv)
        fids.append(float(k))
    V = np.array(verts)
    return {"verts": V, "faces": faces, "uvs": uvs, "wear": np.zeros(len(V)), "facet": np.array(fids)}


def card(centre, a1, a2, half, region):
    """One double-sided quad centred on `centre`, spanned by unit vectors a1, a2, mapped onto the whole `region`."""
    c = np.array(centre, float)
    a1, a2 = np.array(a1, float), np.array(a2, float)
    verts = [c - a1 * half - a2 * half, c + a1 * half - a2 * half, c + a1 * half + a2 * half, c - a1 * half + a2 * half]
    uv = [to_atlas(region, 0, 0), to_atlas(region, 1, 0), to_atlas(region, 1, 1), to_atlas(region, 0, 1)]
    return np.array(verts), [[0, 1, 2, 3]], [uv]


def merge_parts(cards):
    verts, faces, uvs, off = [], [], [], 0
    for v, f, u in cards:
        verts.append(v)
        faces += [[i + off for i in fc] for fc in f]
        uvs += u
        off += len(v)
    V = np.concatenate(verts)
    return {"verts": V, "faces": faces, "uvs": uvs, "wear": np.zeros(len(V)), "facet": np.zeros(len(faces))}


def build_glow():
    """Soft halo (four vertical cards at 0/45/90/135 degrees + a faint horizontal one) and a handful of four-point glints.
    All cards are double sided; nothing here writes depth, so there are no hard intersection lines."""
    cards = []
    cz = CRYSTAL_C[2]
    for yaw in (0, 45, 90, 135):
        a = math.radians(yaw)
        cards.append(card(CRYSTAL_C, (math.cos(a), math.sin(a), 0.0), (0.0, 0.0, 1.0), 0.272, "halo"))
    cards.append(card(CRYSTAL_C, (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), 0.235, "halo"))
    # (x, y, dz, size): glints scattered inside the jar around the gem (dz relative to the gem centre)
    spots = [(-0.235, 0.05, 0.05, 0.036), (0.215, 0.08, 0.00, 0.032), (0.12, -0.17, 0.12, 0.036), (-0.17, -0.12, -0.04, 0.026),
             (0.25, 0.02, -0.07, 0.030), (-0.09, 0.22, 0.10, 0.026), (0.04, 0.19, -0.10, 0.024), (-0.21, 0.15, -0.02, 0.024),
             (0.15, 0.16, 0.17, 0.022), (-0.15, -0.19, -0.12, 0.022), (0.02, -0.23, -0.03, 0.026), (-0.25, -0.02, 0.15, 0.022),
             (-0.12, 0.10, 0.30, 0.026), (0.17, -0.06, 0.37, 0.022), (-0.20, -0.10, 0.45, 0.024), (0.08, 0.20, 0.27, 0.020)]
    for x, y, dz, sz in spots:
        c = (x, y, cz + dz)
        cards.append(card(c, (1, 0, 0), (0, 0, 1), sz, "spark"))
        cards.append(card(c, (0, 1, 0), (0, 0, 1), sz, "spark"))
        cards.append(card(c, (1, 0, 0), (0, 1, 0), sz * 0.8, "spark"))
    return merge_parts(cards)


# ----------------------------------------------------------------------------------------------------------------------
# Noise / painting helpers
# ----------------------------------------------------------------------------------------------------------------------
def fft_noise(h, w, sx, sy, rng):
    """Periodic gaussian-filtered noise with std-dev (sx, sy) pixels, normalised to unit std."""
    n = rng.standard_normal((h, w))
    f = np.fft.rfft2(n)
    fy = np.fft.fftfreq(h)[:, None]
    fx = np.fft.rfftfreq(w)[None, :]
    filt = np.exp(-2.0 * np.pi ** 2 * ((sx * fx) ** 2 + (sy * fy) ** 2))
    out = np.fft.irfft2(f * filt, s=(h, w))
    out = out - out.mean()
    return (out / (out.std() + 1e-9)).astype(np.float32)


def sstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def ramp(stops, t):
    t = np.clip(t, 0.0, 1.0)
    ps = [s[0] for s in stops]
    out = np.zeros(t.shape + (3,), np.float32)
    for ch in range(3):
        out[..., ch] = np.interp(t, ps, [s[1][ch] for s in stops])
    return out


def mix(a, b, t):
    t = t[..., None]
    return a * (1 - t) + np.array(b, np.float32)[None, None, :] * t


def apply_ao(col, ao, k, warm=(1.0, 1.0, 1.0)):
    f = (1.0 - k * (1.0 - ao))[..., None]
    lin = np.power(np.clip(col, 0, 1), 2.2) * f
    wv = np.array(warm, np.float32)[None, None, :]
    lin = lin * np.power(wv, (1.0 - ao)[..., None] * 3.0)
    return np.power(np.clip(lin, 0, 1), 1 / 2.2)


def normal_from_height(H, tilt, valid=None):
    """Tangent-space normal (OpenGL, +Y = +V) from a height field; `tilt` is the RMS slope of the result."""
    gx = (np.roll(H, -1, 1) - np.roll(H, 1, 1)) * 0.5
    gy = (np.roll(H, -1, 0) - np.roll(H, 1, 0)) * 0.5
    if valid is not None:
        ok = valid & np.roll(valid, 1, 0) & np.roll(valid, -1, 0) & np.roll(valid, 1, 1) & np.roll(valid, -1, 1)
        gx = np.where(ok, gx, 0)
        gy = np.where(ok, gy, 0)
        s = np.sqrt((gx ** 2 + gy ** 2)[ok].mean() if ok.any() else 1.0) + 1e-9
    else:
        s = np.sqrt(np.mean(gx ** 2 + gy ** 2)) + 1e-9
    k = tilt / s
    nx, ny = -gx * k, -gy * k
    inv = 1.0 / np.sqrt(nx * nx + ny * ny + 1.0)
    return np.stack([nx * inv * 0.5 + 0.5, ny * inv * 0.5 + 0.5, inv * 0.5 + 0.5], -1).astype(np.float32)


def flat_normal(h, w):
    out = np.zeros((h, w, 3), np.float32)
    out[..., :] = (0.5, 0.5, 1.0)
    return out


def scratches(h, w, rng, count, length=(25, 180), tilt=0.02):
    S = np.zeros((h, w), np.float32)
    for _ in range(count):
        L = int(rng.integers(length[0], length[1]))
        x0 = int(rng.integers(0, w))
        y0 = float(rng.uniform(1, max(2, h - 2)))
        sl = float(rng.normal(0, tilt))
        i = np.arange(L)
        xs = (x0 + i) % w
        ys = y0 + sl * i
        yi = np.floor(ys).astype(int)
        fy = (ys - yi).astype(np.float32)
        amp = (float(rng.uniform(0.35, 1.0)) * np.sin(np.pi * (i + 0.5) / L) ** 0.6).astype(np.float32)
        ok = (yi >= 0) & (yi < h - 1)
        np.maximum.at(S, (yi[ok], xs[ok]), (amp * (1 - fy))[ok])
        np.maximum.at(S, (yi[ok] + 1, xs[ok]), (amp * fy)[ok])
    return S


class Ctx:
    def __init__(self, ys, xs, G, seed):
        self.h = ys.stop - ys.start
        self.w = xs.stop - xs.start
        self.pos = G["pos"][ys, xs]
        self.nrm = G["nrm"][ys, xs]
        self.wear = G["wear"][ys, xs]
        self.facet = G["facet"][ys, xs]
        self.mask = G["mask"][ys, xs]
        self.ao = G["ao"][ys, xs]
        self.rng = np.random.default_rng(seed)


def pack_result(col, alpha, ao, rough, metal, normal, emis=None):
    h, w = col.shape[:2]
    alb = np.concatenate([col, alpha[..., None] if alpha is not None else np.ones((h, w, 1), np.float32)], -1)
    orm = np.stack([ao, rough, metal], -1)
    return alb.astype(np.float32), orm.astype(np.float32), normal, (emis if emis is not None else np.zeros((h, w, 3), np.float32))


# ----------------------------------------------------------------------------------------------------------------------
# Material painters
# ----------------------------------------------------------------------------------------------------------------------
BRASS_STOPS = [(0.0, (0.46, 0.20, 0.03)), (0.28, (0.84, 0.42, 0.06)), (0.52, (1.0, 0.65, 0.13)),
               (0.78, (1.0, 0.78, 0.26)), (1.0, (1.0, 0.91, 0.48))]
# faint warm self-light (LINEAR) baked into the brass emissive map: with metallic only ~0.68 the teal sky cannot turn the
# brass olive, because even in shade the red channel still dominates
BRASS_SELF = np.array([0.32, 0.115, 0.008], np.float32)


def lin_to_srgb(x):
    return np.power(np.clip(x, 0, 1), 1 / 2.2).astype(np.float32)


def paint_brass(c, z0, z1, grain=1.0, rough=0.38, scratch=1.0, metallic=0.68, lift=0.0, warm=(1.0, 1.0, 1.0), selflit=1.0):
    """Lathe-brushed brass, bright warm gold: fine horizontal grain in albedo, roughness and normal; bright polished worn
    edges; AO baked into albedo with a warm crevice shift. Metallic ~0.68 and roughness ~0.38 (v2: 0.9 / 0.27) so the
    teal engine environment is only a minor part of the colour, plus a small baked self-light in the emissive map.
    U runs around the part, so grain runs along U."""
    h, w, rng = c.h, c.w, c.rng
    g_long = fft_noise(h, w, 120, 0.7, rng)
    g_fine = fft_noise(h, w, 28, 0.5, rng)
    g_band = fft_noise(h, w, 280, 2.8, rng)
    blot = fft_noise(h, w, 50, 10, rng)
    patch = fft_noise(h, w, 10, 4, rng)
    z = c.pos[..., 2]
    nz = c.nrm[..., 2]
    zt = np.clip((z - z0) / (z1 - z0), 0, 1)
    wear = np.clip(c.wear * (0.7 + 0.3 * np.clip(patch + 0.6, 0, 1)), 0, 1)
    S = scratches(h, w, rng, int(34 * scratch * h * w / (1024 * 320)) + 2) * scratch
    tone = (0.48 + 0.22 * (zt - 0.5) + 0.07 * np.clip(nz, 0, 1) - 0.07 * np.clip(-nz, 0, 1)
            + grain * (0.026 * g_long + 0.020 * g_fine + 0.008 * g_band) + 0.014 * blot + 0.20 * wear + 0.10 * S + lift)
    col = ramp(BRASS_STOPS, tone) * np.array(warm, np.float32)
    col = apply_ao(col, c.ao, 0.80, (1.0, 0.82, 0.58))
    r = (rough + grain * (0.06 * g_long + 0.04 * g_fine + 0.02 * g_band) + 0.02 * blot - 0.15 * wear - 0.10 * S
         + 0.18 * (1 - c.ao))
    r = np.clip(r, 0.16, 0.62)
    metal = np.clip(metallic - 0.10 * (1 - c.ao) ** 2, 0, 1)
    H = grain * (1.0 * g_long + 0.8 * g_fine) - 1.4 * S * scratch
    normal = normal_from_height(H, 0.16 * max(grain, 0.05))
    emi = lin_to_srgb(BRASS_SELF[None, None, :] * (selflit * (0.45 + 0.55 * c.ao) * (0.75 + 0.5 * np.clip(tone - 0.3, 0, 0.7)))[..., None])
    return pack_result(col, None, c.ao, r, metal, normal, emi)


# teal enamel centred on #2aa89a (0.165, 0.659, 0.604): softer and deeper than the v2 cyan-leaning ramp
TEAL_STOPS = [(0.0, (0.06, 0.38, 0.34)), (0.42, (0.13, 0.57, 0.52)), (0.66, (0.165, 0.659, 0.604)), (1.0, (0.33, 0.80, 0.73))]


def paint_teal(c):
    """Glossy teal enamel: broad soft tonal gradient + faint baked window reflections; clear-coat comes from the material."""
    h, w, rng = c.h, c.w, c.rng
    n = c.nrm
    z = c.pos[..., 2]
    zt = np.clip((z - LIP) / (CT - LIP), 0, 1)
    up = sstep(0.0, 0.95, np.clip(n[..., 2], 0, 1))
    t = 0.38 + 0.20 * up + 0.10 * zt
    col = ramp(TEAL_STOPS, t)
    L1 = np.array([0.55, 0.50, 0.67]); L1 /= np.linalg.norm(L1)
    L2 = np.array([-0.60, 0.40, 0.69]); L2 /= np.linalg.norm(L2)
    h1 = sstep(0.82, 0.985, n @ L1)
    h2 = sstep(0.86, 0.99, n @ L2) * 0.35
    phi = np.arctan2(c.pos[..., 0], c.pos[..., 1])            # 0 = front (+Y); positive toward +X (viewer's left)
    elev = np.arcsin(np.clip(n[..., 2], -1, 1))               # 0 on the skirt, pi/2 at the crown
    win1 = sstep(0.50, 0.78, phi) * (1 - sstep(1.02, 1.28, phi)) * sstep(0.30, 0.62, elev) * (1 - sstep(1.00, 1.30, elev))
    win2 = sstep(-0.98, -0.70, phi) * (1 - sstep(-0.52, -0.30, phi)) * sstep(0.35, 0.62, elev) * (1 - sstep(0.95, 1.25, elev))
    streak = sstep(0.18, 0.30, elev) * (1 - sstep(0.30, 0.42, elev)) * sstep(0.2, 0.5, phi) * (1 - sstep(0.7, 1.0, phi))
    refl = np.clip(0.26 * h1 + h2 * 0.5 + 0.28 * win1 + 0.18 * win2 + 0.08 * streak, 0, 0.5)
    col = mix(col, (0.80, 0.96, 0.92), refl)
    # darker enamel pooling toward the skirt lip, thin bright rolled-lip reflection
    col = col * (0.84 + 0.16 * sstep(LIP, LIP + 0.045, z))[..., None]
    lip = np.exp(-((z - (LIP + 0.0055)) / 0.0035) ** 2) * (1 - np.clip(n[..., 2], 0, 1))
    col = mix(col, (0.62, 0.92, 0.88), np.clip(lip * 0.55, 0, 1))
    col = apply_ao(col, c.ao, 0.65, (0.92, 0.97, 1.0))
    peel = fft_noise(h, w, 6.0, 6.0, rng)
    rough = np.clip(0.095 + 0.015 * fft_noise(h, w, 30, 30, rng) + 0.07 * (1 - c.ao) + 0.04 * h1, 0.05, 0.4)
    return pack_result(col, None, c.ao, rough, np.zeros((h, w), np.float32), normal_from_height(peel, 0.010))


def paint_coral(c, kind):
    """Coral enamel. The coil also gets a baked warm light-spill from the crystal (emissive map, linear < 1: no bloom), more
    towards the top turns, so it reads as lit at gameplay distance."""
    h, w, rng = c.h, c.w, c.rng
    n = c.nrm
    up = sstep(-0.8, 0.9, n[..., 2])
    if kind == 'coil':      # more saturated coral red: survives the teal ambient and the dome shadow at distance
        stops = [(0.0, (0.60, 0.11, 0.08)), (0.5, (0.96, 0.31, 0.21)), (0.85, (1.0, 0.46, 0.34)), (1.0, (1.0, 0.64, 0.52))]
    else:                   # cap disc: the concept's softer salmon
        stops = [(0.0, (0.52, 0.15, 0.13)), (0.5, (0.92, 0.38, 0.32)), (0.85, (0.98, 0.54, 0.45)), (1.0, (1.0, 0.68, 0.58))]
    col = ramp(stops, 0.36 + 0.60 * up)
    L1 = np.array([0.55, 0.50, 0.67]); L1 /= np.linalg.norm(L1)
    hl = sstep(0.72, 0.985, n @ L1)
    col = mix(col, (1.0, 0.80, 0.68), np.clip(0.5 * hl, 0, 1))
    emi = np.zeros((h, w, 3), np.float32)
    if kind == 'coil':
        zt = np.clip((c.pos[..., 2] - (COIL_Z0 - 0.003)) / (CRYSTAL_C[2] - CRYSTAL_R + 0.03 - (COIL_Z0 - 0.003)), 0, 1)
        spill = (0.30 + 0.45 * zt ** 1.2) * (0.6 + 0.4 * c.ao)
        emi = lin_to_srgb(np.array([0.95, 0.27, 0.13], np.float32)[None, None, :] * spill[..., None])
        col = mix(col, (1.0, 0.50, 0.26), 0.25 * zt ** 1.5)
    col = apply_ao(col, c.ao, 0.55 if kind == 'coil' else 0.8, (0.94, 0.74, 0.66))
    rough = np.clip(0.15 + 0.02 * fft_noise(h, w, 20, 20, rng) + 0.10 * (1 - c.ao) + 0.04 * hl, 0.06, 0.5)
    peel = fft_noise(h, w, 5.0, 5.0, rng)
    return pack_result(col, None, c.ao, rough, np.zeros((h, w), np.float32), normal_from_height(peel, 0.006), emi)


def paint_ivory(c, swirl_amt=1.0, pool=0.0):
    """Ivory ceramic. The disc (pool > 0) also gets a warm light pool around the coil base (emissive, linear < 1)."""
    h, w, rng = c.h, c.w, c.rng
    x, y = c.pos[..., 0], c.pos[..., 1]
    r = np.hypot(x, y)
    ang = np.arctan2(y, x)
    nz = c.nrm[..., 2]
    low = fft_noise(h, w, 40, 6, rng)
    swirl = np.sin(math.tau * (r / 0.036 + 0.45 * low + 0.10 * np.sin(3 * ang))) * swirl_amt
    mott = fft_noise(h, w, 14, 5, rng)
    tone = 0.64 + 0.08 * np.clip(nz, 0, 1) + 0.010 * swirl + 0.016 * mott
    tone += 0.05 * np.exp(-((r - 0.205) / 0.016) ** 2) * -1.0 * swirl_amt   # slightly darker in the turned groove
    col = ramp([(0.0, (0.58, 0.52, 0.40)), (0.5, (0.90, 0.85, 0.72)), (0.8, (0.96, 0.92, 0.82)), (1.0, (1.0, 0.97, 0.90))], tone)
    # small neutral-warm self-light (linear, far below the glow threshold) so the cream never turns grey-green in shade
    emi = lin_to_srgb(np.array([0.20, 0.175, 0.13], np.float32)[None, None, :] * (0.55 + 0.45 * c.ao)[..., None])
    if pool > 0:
        pl = np.exp(-((r - 0.10) / 0.11) ** 2) * np.clip(nz, 0, 1)
        col = mix(col, (1.0, 0.78, 0.45), np.clip(0.30 * pool * pl, 0, 1))
        emi = lin_to_srgb(np.array([0.20, 0.175, 0.13], np.float32)[None, None, :] * (0.55 + 0.45 * c.ao)[..., None]
                          + np.array([0.62, 0.27, 0.05], np.float32)[None, None, :] * (pool * 0.85 * pl)[..., None])
    col = apply_ao(col, c.ao, 0.80, (0.97, 0.90, 0.78))
    rough = np.clip(0.30 + 0.012 * swirl + 0.03 * mott + 0.10 * (1 - c.ao), 0.15, 0.55)
    H = 0.7 * swirl + 0.15 * fft_noise(h, w, 1.5, 1.5, rng)
    return pack_result(col, None, c.ao, rough, np.zeros((h, w), np.float32), normal_from_height(H, 0.010 * max(swirl_amt, 0.2)), emi)


def paint_graphite(c, z0, z1):
    h, w, rng = c.h, c.w, c.rng
    nz = c.nrm[..., 2]
    speck = fft_noise(h, w, 0.8, 0.8, rng)
    soft = fft_noise(h, w, 24, 8, rng)
    zt = np.clip((c.pos[..., 2] - z0) / (z1 - z0), 0, 1)
    tone = 0.40 + 0.20 * sstep(-0.3, 1.0, nz) + 0.10 * (zt - 0.5) + 0.025 * speck + 0.012 * soft + 0.20 * c.wear
    col = ramp([(0.0, (0.09, 0.095, 0.12)), (0.5, (0.22, 0.23, 0.27)), (1.0, (0.42, 0.43, 0.49))], tone)
    col = apply_ao(col, c.ao, 0.85)
    rough = np.clip(0.46 + 0.025 * soft + 0.03 * speck - 0.10 * c.wear + 0.1 * (1 - c.ao), 0.2, 0.7)
    metal = np.clip(0.38 + 0.03 * soft, 0, 1)
    return pack_result(col, None, c.ao, rough, metal, normal_from_height(speck, 0.025))


def paint_glass(c):
    """Teal glass that now reads in the engine: ~0.42 alpha per surface (two culled surfaces are visible: front outer, back
    inner), a distinctly brighter, THICK pale-aqua rim band at the bottom and top (baked into albedo + alpha, nearly opaque
    right at the collars), a crisp bright line just inside each collar and a few vertical reflection streaks. Plain alpha
    blend, no transmission. A touch less alpha around the crystal so the gem stays vivid."""
    h, w, rng = c.h, c.w, c.rng
    x, y, z = c.pos[..., 0], c.pos[..., 1], c.pos[..., 2]
    phi = np.arctan2(x, y)

    def streak(center_deg, width_deg, strength):
        d = (phi - math.radians(center_deg) + math.pi) % math.tau - math.pi
        return strength * np.exp(-(d / math.radians(width_deg)) ** 2)

    zlo, zhi = BASE_COLLAR_TOP, COLLAR_Z0
    fade = sstep(zlo + 0.05, zlo + 0.16, z) * (1 - sstep(zhi - 0.16, zhi - 0.05, z))
    s = streak(40, 3.5, 1.0) + streak(-33, 2.2, 0.55) + streak(66, 1.3, 0.45) + streak(150, 4.0, 0.5) + streak(-120, 2.5, 0.35)
    s = s * fade
    bb = 1 - sstep(zlo + 0.012, zlo + 0.075, z)           # thick bottom rim band (about 7 cm, fully bright in the first 1.2 cm)
    tb = sstep(zhi - 0.095, zhi - 0.015, z)               # thick top rim band
    bl = np.exp(-((z - (zlo + 0.014)) / 0.007) ** 2)      # crisp line just above the base collar
    tl = np.exp(-((z - (zhi - 0.014)) / 0.007) ** 2)      # crisp line just below the top collar
    zone = np.exp(-((z - CRYSTAL_C[2]) / 0.17) ** 2)       # clearer around the gem
    haze = fft_noise(h, w, 30, 12, rng)
    alpha = 0.41 - 0.06 * zone + 0.40 * bb + 0.40 * tb + 0.22 * s + 0.30 * (bl + tl) + 0.012 * haze
    alpha = np.clip(alpha, 0.30, 0.93)
    tint = ramp([(0.0, (0.22, 0.68, 0.63)), (0.5, (0.26, 0.72, 0.67)), (1.0, (0.22, 0.66, 0.62))], (z - zlo) / (zhi - zlo))
    band = np.clip(0.85 * bb + 0.85 * tb + 0.9 * (bl + tl) + 0.75 * s, 0, 1)
    col = mix(tint, (0.80, 0.98, 0.94), band)
    ao = np.ones((h, w), np.float32)
    return pack_result(col, alpha, ao, np.full((h, w), 0.035, np.float32), np.zeros((h, w), np.float32), flat_normal(h, w))


# Albedo is a deep saturated amber kept dark on purpose (a lit jewel: most of what you see is transmitted/emitted light,
# and a bright albedo just turns pale pink under strong key lights). Emission carries the glow.
AMBER_ALB = [(0.0, (0.26, 0.045, 0.002)), (0.4, (0.52, 0.13, 0.004)), (0.75, (0.74, 0.27, 0.01)), (1.0, (0.92, 0.50, 0.04))]
AMBER_EMI = [(0.0, (0.90, 0.22, 0.010)), (0.35, (1.0, 0.40, 0.025)), (0.7, (1.0, 0.60, 0.09)), (1.0, (1.0, 0.84, 0.40))]
HOT_EMI = [(0.0, (1.0, 0.50, 0.05)), (0.45, (1.0, 0.70, 0.14)), (0.8, (1.0, 0.88, 0.40)), (1.0, (1.0, 0.97, 0.70))]


def unit_dirs(seed, n):
    d = np.random.default_rng(seed).normal(size=(n, 3))
    return d / np.linalg.norm(d, axis=1, keepdims=True)


# small dark orange inclusions (directions from the crystal centre) like the specks in the concept's resin
INCL_SHELL = unit_dirs(4, 7)
INCL_CORE = unit_dirs(9, 4)


def paint_shell(c):
    """Outer cut gem (alpha blended). Per facet: random depth of colour (deep orange -> gold), about a third of the facets
    are 'bright planes' (pale gold, nearly opaque, strongly emissive) and the rest are clearer deep amber, so the hot core
    shows through them. Facet edges get a thin bright rim; a few dark orange inclusions. Albedo stays saturated amber."""
    h, w, rng = c.h, c.w, c.rng
    m = c.mask
    P = (c.pos[m] - CRYSTAL_C) / CRYSTAL_R
    Pn = P / (np.linalg.norm(P, axis=1, keepdims=True) + 1e-9)
    nrm = c.nrm[m]
    fid = np.clip(c.facet[m].astype(int), 0, NF_SHELL - 1)
    wear = np.clip(c.wear[m], 0, 1)
    rnd = np.random.default_rng(21).random((NF_SHELL, 6))
    r = rnd[fid]
    bright = sstep(0.57, 0.80, r[:, 1])                       # ~40% bright planes
    kl = np.clip(nrm @ np.array([-0.45, 0.35, 0.82]), 0, 1) ** 2   # facets turned toward the upper left catch more light
    tilt = unit_dirs(13, NF_SHELL)[fid]
    grad = np.clip(np.einsum("ij,ij->i", P, tilt) * 0.55, -0.25, 0.25)
    t = np.clip(0.14 + 0.46 * r[:, 0] + 0.42 * bright + 0.25 * kl + grad, 0, 1)
    edge = sstep(0.60, 0.97, wear) ** 1.5                     # soft multi-texel band (a 1-2 px band aliases into a comb)
    alb = ramp(AMBER_ALB, t * 0.92) * 0.62
    alb = alb * (1.0 - 0.28 * edge)[:, None]                   # darker orange cut lines between planes
    alpha = 0.47 + 0.32 * bright + 0.06 * kl + 0.08 * edge + 0.04 * r[:, 2] - 0.06 * (1 - bright) * r[:, 3]
    emi = ramp(AMBER_EMI, np.clip(t + 0.10, 0, 1)) * (0.30 + 0.66 * bright + 0.20 * kl + 0.55 * edge)[:, None]
    # inclusions: dark orange-red specks, denser and dimmer
    for d in INCL_SHELL:
        dd = np.linalg.norm(Pn - d, axis=1)
        wgt = np.exp(-(dd / 0.115) ** 2)
        alb = alb * (1 - wgt[:, None]) + wgt[:, None] * np.array([0.42, 0.055, 0.004], np.float32)
        alpha = np.maximum(alpha, 0.94 * wgt)
        emi = emi * (1 - 0.72 * wgt)[:, None]
    emis = np.zeros((h, w, 3), np.float32)
    emis[m] = np.clip(emi, 0, 1)
    col = np.zeros((h, w, 3), np.float32)
    col[m] = np.clip(alb, 0, 1)
    al = np.ones((h, w), np.float32)
    al[m] = np.clip(alpha, 0, 1)
    rough = np.full((h, w), 0.2, np.float32)
    rough[m] = 0.10 + 0.07 * (1 - bright) + 0.04 * (1 - edge)
    return pack_result(col, al, np.ones((h, w), np.float32), rough, np.zeros((h, w), np.float32), flat_normal(h, w), emis)


def paint_core(c):
    """Inner gem (opaque, hot). Bright gold-yellow facets with a few deeper orange ones, dark edges between planes and
    a few red-orange inclusions. Strongly emissive: this is what shows through the shell as the lit centre."""
    h, w, rng = c.h, c.w, c.rng
    m = c.mask
    P = (c.pos[m] - CRYSTAL_C) / CORE_R
    Pn = P / (np.linalg.norm(P, axis=1, keepdims=True) + 1e-9)
    nrm = c.nrm[m]
    fid = np.clip(c.facet[m].astype(int), 0, NF_CORE - 1)
    wear = np.clip(c.wear[m], 0, 1)
    rnd = np.random.default_rng(55).random((NF_CORE, 4))
    r = rnd[fid]
    kl = np.clip(nrm @ np.array([-0.45, 0.35, 0.82]), 0, 1) ** 2
    t = np.clip(0.06 + 0.64 * r[:, 0] + 0.24 * kl, 0, 1)
    edge = sstep(0.60, 0.98, wear) ** 1.5
    emi = ramp(HOT_EMI, t) * (0.68 + 0.55 * r[:, 1] - 0.16 * edge)[:, None]
    alb = ramp(AMBER_ALB, t * 0.85) * 0.55
    for d in INCL_CORE:
        dd = np.linalg.norm(Pn - d, axis=1)
        wgt = np.exp(-(dd / 0.16) ** 2)
        emi = emi * (1 - 0.55 * wgt)[:, None] * np.array([1.0, 0.62, 0.30], np.float32) ** wgt[:, None]
        alb = alb * (1 - 0.6 * wgt)[:, None]
    emis = np.zeros((h, w, 3), np.float32)
    emis[m] = np.clip(emi, 0, 1)
    col = np.zeros((h, w, 3), np.float32)
    col[m] = np.clip(alb, 0, 1)
    rough = np.full((h, w), 0.2, np.float32)
    rough[m] = 0.55
    return pack_result(col, None, np.ones((h, w), np.float32), rough, np.zeros((h, w), np.float32), flat_normal(h, w), emis)


def paint_fleck(c):
    """Bright pale-gold plates (opaque, emissive, glossy): the crisp 'shards' that sparkle through the shell."""
    h, w = c.h, c.w
    m = c.mask
    fid = np.clip(c.facet[m].astype(int), 0, 31)
    rnd = np.random.default_rng(66).random((32, 3))
    r = rnd[fid]
    t = np.clip(0.50 + 0.50 * r[:, 0], 0, 1)
    emi = ramp(HOT_EMI, t) * (0.85 + 0.30 * r[:, 1])[:, None]
    emis = np.zeros((h, w, 3), np.float32)
    emis[m] = np.clip(emi, 0, 1)
    col = np.zeros((h, w, 3), np.float32)
    col[m] = np.array([0.50, 0.26, 0.03], np.float32)
    rough = np.full((h, w), 0.18, np.float32)
    return pack_result(col, None, np.ones((h, w), np.float32), rough, np.zeros((h, w), np.float32), flat_normal(h, w), emis)


def card_uv(c):
    """Region-local (u, v) in [-1, 1] for a texel grid that spans a whole card region."""
    u = ((np.arange(c.w) + 0.5) / c.w) * 2 - 1
    v = ((np.arange(c.h) + 0.5) / c.h) * 2 - 1
    return np.meshgrid(u, v)


def paint_halo(c):
    """Soft warm glow: alpha holds its strength out to the crystal's limb, then falls smoothly to zero at the card edge."""
    h, w = c.h, c.w
    U, V = card_uv(c)
    r = np.hypot(U, V)
    # a corona: faint over the gem itself (so the stacked cards do not wash out its facets), strongest just outside its rim
    alpha = (0.23 * np.exp(-((r - 0.58) / 0.28) ** 2) + 0.06 * (1.0 - sstep(0.30, 0.60, r))) * (1.0 - sstep(0.35, 1.0, r)) ** 1.4
    inner = 1.0 - sstep(0.30, 0.95, r)
    emis = ramp([(0.0, (1.0, 0.40, 0.04)), (0.5, (1.0, 0.56, 0.10)), (1.0, (1.0, 0.78, 0.30))], inner) * 0.62
    col = np.zeros((h, w, 3), np.float32)
    col[...] = (0.20, 0.09, 0.012)
    return pack_result(col, alpha.astype(np.float32), np.ones((h, w), np.float32), np.ones((h, w), np.float32),
                       np.zeros((h, w), np.float32), flat_normal(h, w), emis.astype(np.float32))


def paint_spark(c):
    """Soft glint: bright round core with four thin tapering rays, all fading to zero at the card edge."""
    h, w = c.h, c.w
    U, V = card_uv(c)
    r = np.hypot(U, V)
    core = np.exp(-(r / 0.17) ** 2)
    halo = 0.35 * np.exp(-(r / 0.42) ** 2)
    ray = (np.exp(-np.abs(V) / 0.05) * np.clip(1 - np.abs(U), 0, 1) ** 2.4
           + np.exp(-np.abs(U) / 0.05) * np.clip(1 - np.abs(V), 0, 1) ** 2.4)
    edge = 1.0 - sstep(0.80, 1.0, np.maximum(np.abs(U), np.abs(V)))
    alpha = np.clip(core + halo + 0.85 * ray, 0, 1) * edge
    emis = ramp([(0.0, (1.0, 0.70, 0.22)), (1.0, (1.0, 0.95, 0.72))], np.clip(core + 0.5 * ray, 0, 1))
    col = np.zeros((h, w, 3), np.float32)
    col[...] = (0.25, 0.16, 0.04)
    return pack_result(col, alpha.astype(np.float32), np.ones((h, w), np.float32), np.ones((h, w), np.float32),
                       np.zeros((h, w), np.float32), flat_normal(h, w), emis.astype(np.float32))


PAINT = {
    "ring": ("brass", dict(z0=0.12, z1=0.264, grain=1.0, rough=0.38, metallic=0.68, lift=0.05)),
    "coil": ("coral", dict(kind="coil")),
    "shell": ("shell", {}),
    "core": ("core", {}),
    "halo": ("halo", {}),
    "spark": ("spark", {}),
    "fleck": ("fleck", {}),
    "dome": ("teal", {}),
    "glass": ("glass", {}),
    "disc": ("ivory", dict(pool=1.0)),
    "saucer": ("graphite", dict(z0=0.04, z1=0.2)),
    "finial": ("brass", dict(z0=CT + 0.008, z1=CT + 0.100, grain=0.25, rough=0.30, scratch=0.2, metallic=0.70, lift=0.20,
                             warm=(1.0, 0.93, 0.70))),
    "capdisc": ("coral", dict(kind="disc")),
    "collar_top": ("brass", dict(z0=COLLAR_Z0, z1=COLLAR_Z1, grain=0.7, rough=0.30, scratch=0.3, metallic=0.70, lift=0.10)),
    "collar_base": ("ivory", dict(swirl_amt=0.0)),
}
for i in range(3):
    PAINT[f"foot{i}"] = ("graphite", dict(z0=0.01, z1=0.13))
    PAINT[f"stud{i}"] = ("brass", dict(z0=0.165, z1=0.215, grain=0.3, rough=0.32, scratch=0.1, metallic=0.70, lift=0.12))
    PAINT[f"cap{i}"] = ("brass", dict(z0=0.0, z1=0.05, grain=0.8, rough=0.36, scratch=0.3, metallic=0.68, lift=0.08))
for i in range(4):
    PAINT[f"dstud{i}"] = ("brass", dict(z0=1.01, z1=1.06, grain=0.3, rough=0.30, scratch=0.1, metallic=0.70, lift=0.14))
PAINTERS = {"brass": paint_brass, "teal": paint_teal, "coral": paint_coral, "ivory": paint_ivory, "graphite": paint_graphite,
            "glass": paint_glass, "shell": paint_shell, "core": paint_core, "halo": paint_halo, "spark": paint_spark, "fleck": paint_fleck}


# ----------------------------------------------------------------------------------------------------------------------
# Blender objects, materials, rasteriser, AO bake
# ----------------------------------------------------------------------------------------------------------------------
WEAR = {}
FACETS = {}
IMG = {}


def make_images():
    specs = {"albedo": ("shock_dome_albedo", "sRGB", True), "orm": ("shock_dome_orm", "Non-Color", False),
             "normal": ("shock_dome_normal", "Non-Color", False), "emissive": ("shock_dome_emissive", "sRGB", False)}
    for key, (name, space, alpha) in specs.items():
        img = bpy.data.images.new(name, A, A, alpha=alpha, float_buffer=False)
        img.colorspace_settings.name = space
        IMG[key] = img


def occlusion_group():
    ng = bpy.data.node_groups.get("glTF Material Output")
    if ng is None:
        ng = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
        ng.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
    return ng


def build_material(name, kind):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]

    def tex(key, x, y):
        n = nodes.new("ShaderNodeTexImage")
        n.image = IMG[key]
        n.interpolation = "Linear"
        n.extension = "EXTEND"
        n.location = (x, y)
        return n

    alb = tex("albedo", -700, 300)
    links.new(alb.outputs["Color"], bsdf.inputs["Base Color"])
    orm = tex("orm", -700, 0)
    sep = nodes.new("ShaderNodeSeparateColor")
    sep.mode = "RGB"
    sep.location = (-420, 0)
    links.new(orm.outputs["Color"], sep.inputs["Color"])
    links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    grp = nodes.new("ShaderNodeGroup")
    grp.node_tree = occlusion_group()
    grp.location = (-200, -250)
    links.new(sep.outputs["Red"], grp.inputs["Occlusion"])
    nrm = tex("normal", -700, -300)
    nmap = nodes.new("ShaderNodeNormalMap")
    nmap.space = "TANGENT"
    nmap.uv_map = "UVMap"
    nmap.location = (-420, -300)
    links.new(nrm.outputs["Color"], nmap.inputs["Color"])
    links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    if kind in ("body", "enamel", "crystal", "fleck", "shell", "glow"):
        emi = tex("emissive", -700, -600)
        links.new(emi.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = {"body": 1.0, "enamel": 1.0, "crystal": EMI_CORE, "fleck": EMI_CORE,
                                                          "shell": EMI_SHELL, "glow": EMI_GLOW}[kind]
    if kind == "enamel":
        bsdf.inputs["Coat Weight"].default_value = 1.0
        bsdf.inputs["Coat Roughness"].default_value = 0.03
    elif kind in ("crystal", "fleck", "shell", "glow"):
        # the core is a pure light source (no specular, so no blown-out sun glint on one flat facet); the shell keeps
        # a soft glint so the cut planes sparkle
        bsdf.inputs["Specular IOR Level"].default_value = 0.0 if kind == "crystal" else 0.35
        if kind not in ("crystal", "fleck"):
            links.new(alb.outputs["Alpha"], bsdf.inputs["Alpha"])
            bsdf.inputs["IOR"].default_value = 1.55 if kind == "shell" else 1.45
            set_blended(mat)
    elif kind == "glass":
        links.new(alb.outputs["Alpha"], bsdf.inputs["Alpha"])
        bsdf.inputs["IOR"].default_value = 1.45
        set_blended(mat)
    mat.use_backface_culling = kind not in ("glow", "fleck")   # glow cards and flecks are double sided, the rest single sided
    return mat


def set_blended(mat):
    try:
        mat.surface_render_method = "BLENDED"
    except Exception:
        mat.blend_method = "BLEND"


def make_object(name, parts, material, parent=None, smooth=True, local_z=0.0):
    verts = np.concatenate([p["verts"] for p in parts]) - np.array([0.0, 0.0, local_z])
    faces, uvs, wear, facets, off = [], [], [], [], 0
    for p in parts:
        faces += [[int(i) + off for i in f] for f in p["faces"]]
        uvs += p["uvs"]
        wear.append(p["wear"])
        facets.append(p.get("facet", np.zeros(len(p["faces"]))))
        off += len(p["verts"])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts.tolist(), [], faces)
    mesh.update()
    layer = mesh.uv_layers.new(name="UVMap")
    layer.data.foreach_set("uv", [float(c) for f in uvs for uv in f for c in uv])
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    WEAR[name] = np.concatenate(wear)
    FACETS[name] = np.concatenate(facets)
    return obj


def empty(name, pos, parent=None):
    obj = bpy.data.objects.new(name, None)
    obj.empty_display_type = "PLAIN_AXES"
    bpy.context.scene.collection.objects.link(obj)
    obj.parent = parent
    obj.location = pos
    return obj


def rasterize(objs):
    G = {"pos": np.zeros((A, A, 3), np.float32), "nrm": np.zeros((A, A, 3), np.float32), "wear": np.zeros((A, A), np.float32),
         "facet": np.zeros((A, A), np.float32), "mask": np.zeros((A, A), bool)}
    for obj in objs:
        me = obj.data
        me.calc_loop_triangles()
        mw = np.array(obj.matrix_world, np.float64)
        nv = len(me.vertices)
        co = np.empty(nv * 3)
        me.vertices.foreach_get("co", co)
        wco = co.reshape(nv, 3) @ mw[:3, :3].T + mw[:3, 3]
        nl = len(me.loops)
        uv = np.empty(nl * 2)
        me.uv_layers["UVMap"].data.foreach_get("uv", uv)
        uv = uv.reshape(nl, 2) * A
        try:
            cn = np.empty(nl * 3, np.float32)
            me.corner_normals.foreach_get("vector", cn)
            cn = cn.reshape(nl, 3)
        except Exception:
            cn = np.array([list(n.vector) for n in me.corner_normals], np.float32)
        cn = cn @ mw[:3, :3].T
        lv = np.empty(nl, np.int32)
        me.loops.foreach_get("vertex_index", lv)
        nt = len(me.loop_triangles)
        tl = np.empty(nt * 3, np.int32)
        me.loop_triangles.foreach_get("loops", tl)
        tl = tl.reshape(nt, 3)
        tp = np.empty(nt, np.int32)
        me.loop_triangles.foreach_get("polygon_index", tp)
        wv = WEAR[obj.name]
        fr = FACETS[obj.name]
        for t in range(nt):
            li = tl[t]
            p = uv[li]
            d = (p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0]) + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1])
            if abs(d) < 1e-9:
                continue
            x0, x1 = int(max(0, math.floor(p[:, 0].min()))), int(min(A - 1, math.ceil(p[:, 0].max())))
            y0, y1 = int(max(0, math.floor(p[:, 1].min()))), int(min(A - 1, math.ceil(p[:, 1].max())))
            xi, yi = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
            X, Y = xi + 0.5, yi + 0.5
            l0 = ((p[1, 1] - p[2, 1]) * (X - p[2, 0]) + (p[2, 0] - p[1, 0]) * (Y - p[2, 1])) / d
            l1 = ((p[2, 1] - p[0, 1]) * (X - p[2, 0]) + (p[0, 0] - p[2, 0]) * (Y - p[2, 1])) / d
            l2 = 1.0 - l0 - l1
            inside = (l0 >= -1e-4) & (l1 >= -1e-4) & (l2 >= -1e-4)
            if not inside.any():
                continue
            a, b, cc = l0[inside], l1[inside], l2[inside]
            vi = lv[li]
            ty, tx = yi[inside], xi[inside]
            G["pos"][ty, tx] = a[:, None] * wco[vi[0]] + b[:, None] * wco[vi[1]] + cc[:, None] * wco[vi[2]]
            nn = a[:, None] * cn[li[0]] + b[:, None] * cn[li[1]] + cc[:, None] * cn[li[2]]
            G["nrm"][ty, tx] = nn / (np.linalg.norm(nn, axis=1, keepdims=True) + 1e-9)
            G["wear"][ty, tx] = a * wv[vi[0]] + b * wv[vi[1]] + cc * wv[vi[2]]
            G["facet"][ty, tx] = fr[tp[t]]
            G["mask"][ty, tx] = True
    return G


def bake_ao(G, occluders, stride=3, rays=40, dist=0.22, floor=0.22):
    verts, tris = [], []
    for obj in occluders:
        me = obj.data
        mw = np.array(obj.matrix_world, np.float64)
        nv = len(me.vertices)
        co = np.empty(nv * 3)
        me.vertices.foreach_get("co", co)
        wco = co.reshape(nv, 3) @ mw[:3, :3].T + mw[:3, 3]
        base = len(verts)
        verts.extend(wco.tolist())
        me.calc_loop_triangles()
        for tri in me.loop_triangles:
            tris.append(tuple(base + i for i in tri.vertices))
    tree = BVHTree.FromPolygons(verts, tris)
    mask = G["mask"]
    ys, xs = np.nonzero(mask[::stride, ::stride])
    ys, xs = ys * stride, xs * stride
    P, N = G["pos"][ys, xs].astype(np.float64), G["nrm"][ys, xs].astype(np.float64)
    helper = np.where(np.abs(N[:, 2:3]) < 0.9, np.array([[0, 0, 1.0]]), np.array([[1.0, 0, 0]]))
    T = np.cross(N, helper)
    T /= np.linalg.norm(T, axis=1, keepdims=True)
    B = np.cross(N, T)
    rng = np.random.default_rng(7)
    k = np.arange(rays)
    u1 = (k + 0.5) / rays
    u2 = (k * 0.6180339887) % 1.0
    phi = math.tau * u2[None, :] + rng.uniform(0, math.tau, (len(P), 1))
    rr = np.sqrt(u1)[None, :]
    lx, ly, lz = rr * np.cos(phi), rr * np.sin(phi), np.sqrt(1 - u1)[None, :] * np.ones_like(phi)
    dirs = T[:, None, :] * lx[..., None] + B[:, None, :] * ly[..., None] + N[:, None, :] * lz[..., None]
    origins = (P + N * 0.003).tolist()
    dl = dirs.tolist()
    occ = np.zeros(len(P))
    for i in range(len(P)):
        o = origins[i]
        s = 0.0
        for d in dl[i]:
            hit = tree.ray_cast(o, d, dist)
            if hit[0] is not None:
                s += 1.0 - hit[3] / dist
        occ[i] = s / rays
    ao = floor + (1 - floor) * (1 - occ) ** 1.6
    hc, wc = (A + stride - 1) // stride, (A + stride - 1) // stride
    S = np.zeros((hc, wc), np.float32)
    W = np.zeros((hc, wc), np.float32)
    S[ys // stride, xs // stride] = ao
    W[ys // stride, xs // stride] = 1.0

    def up(arr):
        yc = np.arange(A) / stride
        y0 = np.clip(np.floor(yc).astype(int), 0, hc - 1)
        y1 = np.clip(y0 + 1, 0, hc - 1)
        fy = (yc - y0).astype(np.float32)[:, None]
        xc = np.arange(A) / stride
        x0 = np.clip(np.floor(xc).astype(int), 0, wc - 1)
        x1 = np.clip(x0 + 1, 0, wc - 1)
        fx = (xc - x0).astype(np.float32)[None, :]
        return (arr[y0][:, x0] * (1 - fy) * (1 - fx) + arr[y0][:, x1] * (1 - fy) * fx
                + arr[y1][:, x0] * fy * (1 - fx) + arr[y1][:, x1] * fy * fx)

    rid = np.zeros((A, A), np.int32)
    for k, (x0, y0, w, h) in enumerate(REGIONS.values()):
        rid[y0:y0 + h, x0:x0 + w] = k + 1
    rc = rid[::stride, ::stride][:hc, :wc]
    SW, WW = S * W, W.copy()
    bs, bw = SW.copy(), WW.copy()
    for dy in (-2, -1, 0, 1, 2):
        for dx in (-2, -1, 0, 1, 2):
            if dy == 0 and dx == 0:
                continue
            same = (np.roll(rc, (dy, dx), (0, 1)) == rc).astype(np.float32)
            bs += np.roll(SW, (dy, dx), (0, 1)) * same
            bw += np.roll(WW, (dy, dx), (0, 1)) * same
    S, W = bs, bw
    num, den = up(S), up(W)
    ao_full = np.where(den > 0.02, num / np.maximum(den, 1e-6), 1.0).astype(np.float32)
    ao_full = np.where(mask, ao_full, 1.0)
    return ao_full


def dilate(maps, mask, iterations=4):
    m = mask.copy()
    for _ in range(iterations):
        new = m.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            src = np.roll(m, (dy, dx), (0, 1))
            sel = (~new) & src
            if sel.any():
                for arr in maps:
                    arr[sel] = np.roll(arr, (dy, dx), (0, 1))[sel]
                new |= sel
        m = new
    return m


def paint_atlas(G):
    alb = np.zeros((A, A, 4), np.float32)
    orm = np.zeros((A, A, 3), np.float32)
    nrm = np.zeros((A, A, 3), np.float32)
    emi = np.zeros((A, A, 3), np.float32)
    for idx, (name, rect) in enumerate(REGIONS.items()):
        x0, y0, w, h = rect
        ys, xs = slice(y0 + PAD, y0 + h - PAD), slice(x0 + PAD, x0 + w - PAD)
        ctx = Ctx(ys, xs, G, 1000 + idx)
        kind, params = PAINT[name]
        a, o, n, e = PAINTERS[kind](ctx, **params)
        alb[ys, xs], orm[ys, xs], nrm[ys, xs], emi[ys, xs] = a, o, n, e
    m = dilate([alb, orm, nrm, emi], G["mask"], 4)
    # wrap the gutter of lathe-style regions so bilinear filtering across the seam stays continuous
    for name, (x0, y0, w, h) in REGIONS.items():
        mode = WRAP.get(name)
        ys, xs = slice(y0 + PAD, y0 + h - PAD), slice(x0 + PAD, x0 + w - PAD)
        for arr in (alb, orm, nrm, emi):
            if mode == "u":
                arr[ys, x0:x0 + PAD] = arr[ys, x0 + w - 2 * PAD:x0 + w - PAD]
                arr[ys, x0 + w - PAD:x0 + w] = arr[ys, x0 + PAD:x0 + 2 * PAD]
            elif mode == "v":
                arr[y0:y0 + PAD, xs] = arr[y0 + h - 2 * PAD:y0 + h - PAD, xs]
                arr[y0 + h - PAD:y0 + h, xs] = arr[y0 + PAD:y0 + 2 * PAD, xs]
    neutral = ~m
    alb[neutral] = (0.30, 0.30, 0.30, 1.0)
    orm[neutral] = (1.0, 0.6, 0.0)
    nrm[neutral] = (0.5, 0.5, 1.0)
    emi[neutral] = 0.0
    return alb, orm, nrm, emi


def write_images(alb, orm, nrm, emi):
    TEX_DIR.mkdir(exist_ok=True)

    def fill(key, rgb, alpha=None):
        img = IMG[key]
        buf = np.ones((A, A, 4), np.float32)
        buf[..., :3] = np.clip(rgb, 0, 1)
        if alpha is not None:
            buf[..., 3] = np.clip(alpha, 0, 1)
        img.pixels.foreach_set(buf.ravel())
        img.update()
        img.filepath_raw = str(TEX_DIR / f"{img.name}.png")
        img.file_format = "PNG"
        img.save()
        img.pack()

    fill("albedo", alb[..., :3], alb[..., 3])
    fill("orm", orm)
    fill("normal", nrm)
    fill("emissive", emi)


# ----------------------------------------------------------------------------------------------------------------------
# Assembly
# ----------------------------------------------------------------------------------------------------------------------
def rz(angle):
    c, s = math.cos(angle), math.sin(angle)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1.0]])


RY90 = np.array([[0, 0, 1.0], [0, 1, 0], [-1, 0, 0]])   # maps +Z to +X


def ry(angle):
    c, s_ = math.cos(angle), math.sin(angle)
    return np.array([[c, 0, s_], [0, 1.0, 0], [-s_, 0, c]])


def dome_profile_point(theta_deg):
    """Outer crown point (r, z) and its outward normal elevation (rad) at superellipse parameter theta."""
    t = math.radians(theta_deg)
    r = DOME_R * math.cos(t) ** DOME_SE
    z = SKIRT_TOP + H_CROWN * math.sin(t) ** DOME_SE
    nx = H_CROWN * math.sin(t) ** (DOME_SE - 1) * math.cos(t)
    nz = DOME_R * math.cos(t) ** (DOME_SE - 1) * math.sin(t)
    return r, z, math.atan2(nz, nx)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    check_layout()
    make_images()
    body = build_material("Shock_Body", "body")
    enamel = build_material("Shock_Enamel", "enamel")
    crystal_mat = build_material("Shock_Crystal", "crystal")
    shell_mat = build_material("Shock_CrystalShell", "shell")
    glow_mat = build_material("Shock_Glow", "glow")
    fleck_mat = build_material("Shock_CrystalFleck", "fleck")
    glass_mat = build_material("Shock_Glass", "glass")

    root = empty("TurretModel", (0, 0, 0))
    aim = empty("Aim", (0, 0, AIM_Z), root)

    # ---- static base ------------------------------------------------------------------------------------------------
    ring_path = join_path(
        [(0.27, 0.12), (0.325, 0.12)], arc(0.325, 0.155, 0.035, -90, 0, 6),
        [(0.36, 0.168), (0.3565, 0.172), (0.36, 0.176), (0.36, 0.215)], arc(0.325, 0.215, 0.035, 0, 90, 6),
        [(0.312, 0.25)], arc(0.304, 0.25, 0.008, 0, 180, 6), [(0.27, 0.25), (0.27, 0.12)])
    ring = lathe([(ring_path, 1.0)], SEGS, "ring")
    make_object("Base_Ring", [ring], body, root)

    # ivory collar where the glass jar meets the base ring: solid, so the jar visibly stands on the base
    r_in, r_out, zb, zt, f = 0.272, 0.305, 0.247, BASE_COLLAR_TOP, 0.010
    base_collar_path = join_path(
        [(r_in, zb), (r_out - f, zb)], arc(r_out - f, zb + f, f, -90, 0, 5), [(r_out, zt - f)], arc(r_out - f, zt - f, f, 0, 90, 5),
        [(r_in + 0.004, zt)], arc(r_in + 0.004, zt - 0.004, 0.004, 90, 180, 3), [(r_in, zb)])
    make_object("Base_Collar", [lathe([(base_collar_path, 1.0)], SEGS_BIG, "collar_base", wear_on=False)], body, root)

    flank = [(0.155 + 0.178 * math.sin(math.radians(t)), 0.125 - 0.085 * math.cos(math.radians(t))) for t in range(0, 91, 9)]
    saucer = lathe([(join_path([(0.0, 0.04)], flank, [(0.333, 0.136)]), 1.0),
                    (join_path([(0.333, 0.136), (0.272, 0.136), (0.272, 0.20), (0.0, 0.20)]), 0.1)], SEGS, "saucer")
    make_object("Base_Saucer", [saucer], body, root)

    disc_path = join_path(
        arc(0.24, 0.215, 0.015, -90, 0, 5), [(0.255, 0.255)], arc(0.235, 0.255, 0.02, 0, 90, 6),
        [(0.205, 0.275), (0.198, 0.2715), (0.192, 0.2715), (0.185, 0.275), (0.115, 0.275), (0.105, 0.2725), (0.095, 0.2695),
         (0.085, 0.268), (0.0, 0.268)])
    disc_path = [(r, z + DISC_DZ) for r, z in disc_path]
    disc = lathe([(disc_path, 1.0)], SEGS, "disc", wear_on=False)
    make_object("Base_Disc", [disc], body, root)

    studs, feet, caps = [], [], []
    for i, ang in enumerate((90, 210, 330)):
        a = math.radians(ang)
        stud_path = join_path(arc(0.0, -0.005, 0.024, math.degrees(math.asin(0.005 / 0.024)), 90, 6))
        studs.append(lathe([(stud_path, 1.0)], 20, f"stud{i}", wear_on=False, rot=rz(a) @ RY90,
                           offset=(0.357 * math.cos(a), 0.357 * math.sin(a), 0.19)))
    make_object("Base_Studs", studs, body, root)
    for i, ang in enumerate((30, 150, 270)):
        a = math.radians(ang)
        fx, fy = 0.27 * math.cos(a), 0.27 * math.sin(a)
        # chunky round feet (concept: round grey balls on brass cups): r 0.060, slightly squashed
        feet.append(lathe([(sphere_path(0.060, 12), 1.0)], 32, f"foot{i}", wear_on=False, scale=(1, 1, 0.92), offset=(fx, fy, 0.074)))
        cap_path = join_path([(0.0, 0.0), (0.033, 0.0)], arc(0.033, 0.004, 0.004, -90, 0, 3), [(0.0385, 0.012)],
                             [(0.0435, 0.026), (0.0485, 0.038), (0.0525, 0.046), (0.0505, 0.0485)])
        caps.append(lathe([(cap_path, 1.0)], 32, f"cap{i}", offset=(fx, fy, 0.0)))
    make_object("Base_Feet", feet, body, root)
    make_object("Base_FootCaps", caps, body, root)

    # ---- Aim: jar, collar, dome cap, coil, crystal ------------------------------------------------------------------
    # The jar is split into pieces only to give the rim bands more atlas rows (the paint is evaluated per texel by height).
    zmid0, zmid1 = 0.42, 0.86
    glass_out = [
        (join_path([(JAR_RO - 0.009, JAR_Z0), (JAR_RO - 0.004, JAR_Z0)], arc(JAR_RO - 0.004, JAR_Z0 + 0.004, 0.004, -90, 0, 4),
                   [(JAR_RO, zmid0)]), 2.4),
        (join_path([(JAR_RO, zmid0), (JAR_RO, zmid1)]), 1.0),
        (join_path([(JAR_RO, zmid1), (JAR_RO, JAR_Z1 - 0.004)], arc(JAR_RO - 0.004, JAR_Z1 - 0.004, 0.004, 0, 90, 4),
                   [(JAR_RI, JAR_Z1)]), 2.4),
    ]
    glass_in = [
        (join_path([(JAR_RI, JAR_Z1), (JAR_RI, zmid1)]), 1.0),
        (join_path([(JAR_RI, zmid1), (JAR_RI, zmid0)]), 1.0),
        (join_path([(JAR_RI, zmid0), (JAR_RI, JAR_Z0), (JAR_RO - 0.009, JAR_Z0)]), 2.4),
    ]
    glass = lathe(glass_out + glass_in, SEGS_BIG, "glass", wear_on=False)
    make_object("Glass_Jar", [glass], glass_mat, aim, local_z=AIM_Z)

    # brass collar wrapped around the dome lip: solid support between dome and jar
    rin, rout, z0c, z1c, f = 0.286, 0.3175, COLLAR_Z0, COLLAR_Z1, 0.0125
    top_collar_path = join_path(
        [(rin, z0c), (rout - f, z0c)], arc(rout - f, z0c + f, f, -90, 0, 5), [(rout, z1c - f)], arc(rout - f, z1c - f, f, 0, 90, 5),
        [(rin, z1c), (rin, z0c)])
    make_object("Jar_Collar", [lathe([(top_collar_path, 1.0)], SEGS_BIG, "collar_top")], body, aim, local_z=AIM_Z)

    thetas = [3, 8, 14, 21, 29, 37, 45, 53, 61, 69, 76, 82, 87, 90]
    se = DOME_SE
    outer = join_path([(DOME_R - 0.0075, LIP)], arc(DOME_R - 0.0075, LIP + 0.0075, 0.0075, -90, 0, 4), [(DOME_R, SKIRT_TOP)],
                      [(DOME_R * math.cos(math.radians(t)) ** se, SKIRT_TOP + H_CROWN * math.sin(math.radians(t)) ** se) for t in thetas])
    inner = join_path([(DOME_RI * math.cos(math.radians(t)) ** se, SKIRT_TOP + (H_CROWN - 0.008) * math.sin(math.radians(t)) ** se)
                       for t in reversed([0] + thetas)],
                      [(DOME_RI, LIP), (DOME_R - 0.0075, LIP)])
    dome = lathe([(outer, 1.0), (inner, 0.3)], SEGS_BIG, "dome")
    make_object("Dome_Cap", [dome], enamel, aim, local_z=AIM_Z)

    dstuds = []
    r_s, z_s, tau = dome_profile_point(12.0)
    for i, ang in enumerate((45, 135, 225, 315)):
        a = math.radians(ang)
        r0 = 0.0145
        sp = join_path(arc(0.0, -0.003, r0, math.degrees(math.asin(0.003 / r0)), 90, 5))
        nrm = np.array([math.cos(a) * math.cos(tau), math.sin(a) * math.cos(tau), math.sin(tau)])
        pos = np.array([r_s * math.cos(a), r_s * math.sin(a), z_s]) - nrm * 0.002
        dstuds.append(lathe([(sp, 1.0)], 16, f"dstud{i}", wear_on=False, rot=rz(a) @ ry(math.pi / 2 - tau), offset=tuple(pos)))
    make_object("Dome_Studs", dstuds, body, aim, local_z=AIM_Z)

    cap_disc_path = join_path(arc(0.105, CT + 0.001, 0.012, -90, 0, 4), [(0.117, CT + 0.005)], arc(0.105, CT + 0.005, 0.012, 0, 90, 4),
                              [(0.06, CT + 0.0195), (0.0, CT + 0.0205)])
    cap_disc = lathe([(cap_disc_path, 1.0)], SEGS_BIG, "capdisc", wear_on=False)
    make_object("Dome_CapDisc", [cap_disc], enamel, aim, local_z=AIM_Z)
    finial = lathe([(sphere_path(0.046, 12), 1.0)], 40, "finial", wear_on=False, offset=(0, 0, CT + 0.054))
    make_object("Finial", [finial], body, aim, local_z=AIM_Z)

    # a wider spring (concept: the coil is nearly as wide as the gem) that stops just under the gem's lower hemisphere;
    # thicker tube so it still reads at gameplay distance
    coil = helix_tube(0.112, 0.0138, COIL_Z0, 0.0405, 2.65, 72, 14, "coil")
    make_object("Coil", [coil], enamel, aim, local_z=AIM_Z)

    make_object("Crystal_Core", [build_core()], crystal_mat, aim, smooth=False, local_z=AIM_Z)
    make_object("Crystal_Flecks", [build_flecks()], fleck_mat, aim, smooth=False, local_z=AIM_Z)
    make_object("Crystal_Shell", [build_shell()], shell_mat, aim, smooth=False, local_z=AIM_Z)
    make_object("Glow", [build_glow()], glow_mat, aim, smooth=False, local_z=AIM_Z)

    empty("Muzzle", (0.0, 0.20, CRYSTAL_C[2] - AIM_Z), aim)
    return root, aim, [body, enamel, crystal_mat, fleck_mat, shell_mat, glow_mat, glass_mat]


def main():
    root, aim, mats = build()
    bpy.context.view_layer.update()
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    log(f"geometry done: {len(meshes)} meshes")
    G = rasterize(meshes)
    log(f"rasterised, {int(G['mask'].sum())} covered texels")
    occluders = [o for o in meshes if o.name not in ("Glass_Jar", "Crystal_Shell", "Glow", "Crystal_Flecks")]
    G["ao"] = bake_ao(G, occluders, **(dict(stride=8, rays=8) if QUICK else {}))
    log("AO baked")
    alb, orm, nrm, emi = paint_atlas(G)
    log("atlas painted")
    write_images(alb, orm, nrm, emi)
    log("images written")
    tris = 0
    for o in meshes:
        o.data.calc_loop_triangles()
        tris += len(o.data.loop_triangles)
        log(f"  {o.name:16s} tris={len(o.data.loop_triangles):6d} verts={len(o.data.vertices):6d} mat={o.data.materials[0].name}")
    log(f"triangles={tris} mesh_objects={len(meshes)} materials={len(mats)}")
    bpy.ops.export_scene.gltf(filepath=str(GLB), export_format="GLB", export_yup=True, export_animations=False,
                              export_cameras=False, export_lights=False)
    log(f"exported {GLB.name}")


main()

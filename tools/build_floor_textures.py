"""Generate the seamless sci-fi arena floor texture sets (albedo, normal, roughness, emission), one per terrain theme.

Run: python tools/build_floor_textures.py [theme|all] [--preview]     (needs numpy and Pillow)
Output: assets/textures/floor/<theme>/floor_{albedo,normal,roughness,emission}.png, 1024 px, covering TILE_METRES square.
Themes (see ArenaLayouts): foundry (Crossroads), concrete (Highlands), grating (The Sump).
Everything is periodic (FFT noise, wrapped distances), so each tile repeats without visible edges.

Art rules shared by every theme: the floor is a gameplay surface under enemies, projectiles and coloured zone overlays
(blue, olive, hazard orange, violet), so albedo stays dark, low-contrast and low-saturation and the detail lives in the
normal and roughness maps. Orange/copper is reserved for the no-build zone; only the foundry theme keeps its legacy stripes.
`--preview` also writes a 2x2 tiled, approximately lit render to .test-results/floor/<theme>_preview.png.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 1024
TILE_METRES = 6.4  # keep in sync with FLOOR_TILE_METRES in scripts/game/world_geometry.gd
PX_PER_M = SIZE / TILE_METRES  # 160
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/textures/floor"
PREVIEW_OUT = ROOT / ".test-results/floor"
HALF = SIZE / 2

yy, xx = np.mgrid[0:SIZE, 0:SIZE]
_freq = np.fft.fftfreq(SIZE)
_fx, _fy = np.meshgrid(_freq, _freq)


# --- Shared helpers ------------------------------------------------------------------------------------------------

def periodic_noise(sigma, seed):
    """Gaussian-blurred white noise via FFT, so it wraps seamlessly. Returned in [0, 1]."""
    noise = np.random.default_rng(seed).standard_normal((SIZE, SIZE))
    kernel = np.exp(-2 * (np.pi * sigma) ** 2 * (_fx ** 2 + _fy ** 2))
    out = np.real(np.fft.ifft2(np.fft.fft2(noise) * kernel))
    out -= out.min()
    return (out / out.max()).astype(np.float32)


def noise(sigma, seed, sigma_y=None):
    """Periodic Gaussian noise standardised to zero mean and unit deviation. `sigma_y` stretches it along y."""
    sy = sigma if sigma_y is None else sigma_y
    white = np.random.default_rng(seed).standard_normal((SIZE, SIZE))
    kernel = np.exp(-2 * np.pi ** 2 * ((sigma * _fx) ** 2 + (sy * _fy) ** 2))
    out = np.real(np.fft.ifft2(np.fft.fft2(white) * kernel))
    return ((out - out.mean()) / out.std()).astype(np.float32)


def uniform(field):
    """Rank-transform a field to a flat [0, 1] distribution, so a threshold t covers exactly (1 - t) of the tile."""
    order = np.argsort(field, axis=None)
    out = np.empty(field.size, np.float32)
    out[order] = np.linspace(0, 1, field.size, dtype=np.float32)
    return out.reshape(field.shape)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def wrap_delta(a, b):
    """Shortest signed distance from b to a on the periodic tile."""
    return (a - b + HALF) % SIZE - HALF


def tint(base, color, mask):
    """Blend `color` over an (H, W, 3) image where `mask` (H, W) is 1."""
    return base * (1 - mask[..., None]) + np.asarray(color, np.float32) * mask[..., None]


def band_cells(c, edges):
    """Split the periodic axis at `edges`. Returns cell index, position inside the cell, cell size and distance to the cell border."""
    edges = np.asarray(edges, np.float32)
    rel = edges - edges[0]
    shifted = (c - edges[0]) % SIZE
    idx = np.searchsorted(rel, shifted, side="right") - 1
    upper = np.append(rel[1:], SIZE)
    local = shifted - rel[idx]
    size = upper[idx] - rel[idx]
    return idx, local, size, np.minimum(local, size - local)


def rect_sdf(u, v, cx, cy, half_w, half_h):
    """Signed distance (px, negative inside) to a rectangle centred on (cx, cy), wrapping around the tile."""
    return np.maximum(np.abs(wrap_delta(u, cx)) - half_w, np.abs(wrap_delta(v, cy)) - half_h)


def segment_dist(u, v, x0, y0, x1, y1):
    """Distance (px) to the segment (x0,y0)-(x1,y1); the segment is placed on the tile and wraps."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    px, py = wrap_delta(u, cx), wrap_delta(v, cy)
    ax, ay = x0 - cx, y0 - cy
    bx, by = x1 - cx, y1 - cy
    dx, dy = bx - ax, by - ay
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy), 0, 1)
    return np.hypot(px - (ax + t * dx), py - (ay + t * dy))


def voronoi(u, v, cells, seed, jitter=0.9):
    """Periodic Worley noise on a cells x cells jittered grid. Returns the distances (px) to the nearest and second nearest
    feature point plus the nearest point's cell id. (f2 - f1) / 2 approximates the distance to the nearest cell border."""
    rng = np.random.default_rng(seed)
    cell = SIZE / cells
    points = rng.random((cells, cells, 2)).astype(np.float32)
    u = (u % SIZE).astype(np.float32)
    v = (v % SIZE).astype(np.float32)
    ci = (u // cell).astype(np.int32)
    cj = (v // cell).astype(np.int32)
    f1 = np.full(u.shape, 1e9, np.float32)
    f2 = np.full(u.shape, 1e9, np.float32)
    ident = np.zeros(u.shape, np.int32)
    for dj in (-1, 0, 1):
        for di in (-1, 0, 1):
            ni, nj = ci + di, cj + dj
            offset = points[nj % cells, ni % cells]
            px = (ni + 0.5 + (offset[..., 0] - 0.5) * jitter) * cell
            py = (nj + 0.5 + (offset[..., 1] - 0.5) * jitter) * cell
            dist = np.hypot(u - px, v - py)
            closer = dist < f1
            f2 = np.where(closer, f1, np.minimum(f2, dist))
            ident = np.where(closer, (nj % cells) * cells + (ni % cells), ident)
            f1 = np.where(closer, dist, f1)
    return f1, f2, ident


def normal_from_height(height, strength):
    """OpenGL-convention tangent normal (+Y green = up in the image) from a periodic height map, as [0, 1] RGB."""
    dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5
    drow = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5
    normal = np.stack([-dx * strength, drow * strength, np.ones_like(dx)], axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    return normal * 0.5 + 0.5


def save(theme, name, array):
    folder = OUT / theme
    folder.mkdir(parents=True, exist_ok=True)
    data = (np.clip(array, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(data).save(folder / name, optimize=True)


def pack(albedo, normal, roughness, emission):
    return {"albedo": albedo, "normal": normal, "roughness": np.stack([roughness] * 3, axis=-1), "emission": emission}


# --- Theme: foundry (Crossroads) -- the original dark teal plating ---------------------------------------------------

def build_foundry():
    """4x4 plates, each a seeded variant (plain, vent grille, hazard band, hatch), with grooves, bevels, rivets, wear and
    glowing seam lines. Authored directly in sRGB, like the flat colour it replaced."""
    rng = np.random.default_rng(2026)
    plates = 4
    plate = SIZE // plates  # 256 px, 1.6 m
    lx, ly = xx % plate, yy % plate
    px, py = xx // plate, yy // plate
    cx, cy = lx - plate / 2 + 0.5, ly - plate / 2 + 0.5
    edge = np.minimum.reduce([lx, plate - 1 - lx, ly, plate - 1 - ly]).astype(np.float32)

    # Each plate picks a variant from a seeded table: 0 plain, 1 vent grille, 2 hazard band, 3 hatch.
    variants = rng.integers(0, 4, (plates, plates))
    variants[0, 0] = 0
    variant = variants[py, px]

    # Height (1 = plate surface, 0 = deep groove)
    height = smoothstep(2, 9, edge)  # groove between plates with a soft bevel up to the surface
    inset = np.abs(edge - 20)  # shallow engraved border line inside every plate
    height = np.where(inset < 1.6, height * 0.82, height)
    for sx in (-1, 1):
        for sy in (-1, 1):
            dist = np.hypot(cx - sx * (plate / 2 - 34), cy - sy * (plate / 2 - 34))
            height = height + np.where(dist < 6, 0.16 * smoothstep(6, 2.5, dist), 0)  # rivet dome
    vent = (variant == 1) & (np.abs(cx) < 70) & (np.abs(cy) < 52)
    slat = (np.abs(cy) % 13) < 6
    height = np.where(vent & slat, 0.12, np.where(vent, height * 0.9, height))
    radius = np.hypot(cx, cy)
    hatch = variant == 3
    height = np.where(hatch & (np.abs(radius - 58) < 2.5), height * 0.4, height)
    height = np.where(hatch & (radius < 56), height * 0.93, height)
    height = np.where(hatch & ((np.abs(cx) < 2.5) | (np.abs(cy) < 2.5)) & (radius < 56), height * 0.55, height)
    scuff = periodic_noise(1.2, 5)
    height = height - 0.05 * scuff

    # Albedo
    base = np.array([0.09, 0.17, 0.215])  # matches the previous flat floor colour
    tone = 0.82 + 0.3 * periodic_noise(40, 6) + 0.12 * (scuff - 0.5)  # broad mottling plus fine scuffs
    albedo = base[None, None, :] * tone[..., None]
    groove_ao = smoothstep(0, 8, edge)  # grooves read darker
    albedo *= (0.35 + 0.65 * groove_ao)[..., None]
    wear = smoothstep(10, 3, edge) * smoothstep(0.55, 0.9, periodic_noise(3, 7))  # edge wear shows bare metal
    albedo = albedo * (1 - wear[..., None]) + np.array([0.3, 0.36, 0.38]) * wear[..., None]
    # Hazard band: diagonal copper stripes along the lower edge of "hazard" plates.
    band = (variant == 2) & (ly > plate - 64) & (ly < plate - 30) & (edge > 6)
    stripes = ((lx + ly) // 14) % 2 == 0
    hazard = np.array([0.42, 0.27, 0.10])
    albedo = np.where((band & stripes)[..., None], hazard * tone[..., None] * 0.9, albedo)
    albedo = np.where((band & ~stripes)[..., None], albedo * 0.45, albedo)
    albedo = np.where((vent & slat)[..., None], albedo * 0.3, albedo)

    # Roughness (worn edges are shinier, plates satin)
    roughness = 0.62 - 0.22 * wear + 0.12 * (scuff - 0.5)
    roughness = np.where(vent & slat, 0.9, roughness)
    roughness = np.clip(roughness, 0.25, 0.95)

    # Emission: dim cyan lines along the tile seam, status dots, and vent glow
    seam_x = np.minimum(xx, SIZE - 1 - xx) < 2  # the tile border seam wraps, so light both sides
    seam_y = np.minimum(yy, SIZE - 1 - yy) < 2
    emission = np.zeros((SIZE, SIZE, 3), np.float32)
    cyan = np.array([0.04, 0.75, 0.9], np.float32)
    amber = np.array([0.9, 0.5, 0.1], np.float32)
    emission += (seam_x | seam_y)[..., None] * cyan * 0.55
    for sx in (-1, 1):
        for sy in (-1, 1):
            dist = np.hypot(cx - sx * (plate / 2 - 34), cy - sy * (plate / 2 - 34))
            lit = (dist < 3.2) & ((px + py + (sx > 0) + 2 * (sy > 0)) % 5 == 0)  # a few rivets are indicator lights
            emission += lit[..., None] * np.where(((px + py) % 2 == 0)[..., None], cyan, amber) * 0.9
    emission += (vent & ~slat & (np.abs(cx) < 66))[..., None] * cyan * 0.08
    emission += (hatch & (np.abs(radius - 58) < 1.2))[..., None] * cyan * 0.35

    return pack(albedo, normal_from_height(height, 5.0), roughness, emission)


# --- Theme: concrete (Highlands) -- cracked survey-grade slabs ---------------------------------------------------------

def build_concrete():
    """Five poured slabs in two staggered rows with expansion joints, each with its own level, tilt, tone and crack load; hairline
    and tar-sealed cracks, damp stains, oil, dust drifts, a repair patch, an asphalt patch and faint teal survey paint.
    Warm grey, very rough and non-metallic (use metallic 0 on the material)."""
    seed = 7301
    fx = xx.astype(np.float32)
    fy = yy.astype(np.float32)

    # Joints drift only slightly; cracks meander. Both warps are periodic, so the tile still wraps.
    ju = fx + noise(45, seed + 1) * 2.2
    jv = fy + noise(45, seed + 2) * 2.2
    cu = fx + noise(16, seed + 3) * 9 + noise(4.5, seed + 4) * 2.2
    cv = fy + noise(16, seed + 5) * 9 + noise(4.5, seed + 6) * 2.2

    # --- Slab layout: two rows with staggered vertical joints (ids: row * 3 + column).
    row, row_local, row_size, dist_y = band_cells(jv, [0, 560])
    slab = np.zeros(fx.shape, np.int32)
    sx_local = np.zeros(fx.shape, np.float32)
    sx_size = np.ones(fx.shape, np.float32)
    dist_x = np.zeros(fx.shape, np.float32)
    for r, splits in enumerate([[90, 650], [300, 640, 930]]):
        idx, local, size, dist = band_cells(ju, splits)
        here = row == r
        slab = np.where(here, r * 3 + idx, slab)
        sx_local = np.where(here, local, sx_local)
        sx_size = np.where(here, size, sx_size)
        dist_x = np.where(here, dist, dist_x)
    sxn = sx_local / sx_size - 0.5
    syn = row_local / row_size - 0.5
    rng = np.random.default_rng(seed)
    slab_tone = rng.normal(0, 0.09, 9)
    slab_hue = rng.normal(0, 0.005, (9, 1)) * np.array([1.0, 0.3, -1.0])  # each pour dried a slightly warmer or cooler grey
    slab_level = rng.normal(0, 0.03, 9)
    slab_tilt = rng.normal(0, 0.05, (9, 2))
    slab_wear = rng.uniform(0.0, 1.0, 9)  # how much aggregate shows through
    slab_cracks = np.array([0.34, 0.0, 0, 0.16, 0.50, 0.08, 0, 0, 0])[slab]

    jd = np.minimum(dist_y, dist_x)  # px to the nearest expansion joint centre line
    jd_chipped = np.maximum(jd + noise(2.5, seed + 7) * 1.4 + noise(9, seed + 8) * 2.6 - 1.0, 0)
    groove = smoothstep(4.0, 1.2, jd_chipped)
    arris = smoothstep(11, 2, jd_chipped)

    # --- Cracks: a coarse Voronoi network, gated by noise so each crack starts and stops, sparse per slab.
    f1, f2, _ = voronoi(cu, cv, 5, seed + 10)
    edge = (f2 - f1) * 0.5
    gate = uniform(noise(30, seed + 11))
    on = np.where(slab_cracks > 0, smoothstep(slab_cracks, slab_cracks * 0.45 + 1e-4, gate), 0)
    crack_w = 0.7 + 0.9 * on
    crack = smoothstep(crack_w, crack_w * 0.25, edge) * on
    sealed = smoothstep(0.52, 0.62, uniform(noise(60, seed + 12)))  # some cracks were routed and filled with tar
    tar = np.clip(smoothstep(crack_w * 1.7, crack_w * 0.8, edge) * on * sealed, 0, 1)
    # A few long cracks run clean across slabs and joints (coarse network, not gated by slab).
    l1, l2, _ = voronoi(cu, cv, 3, seed + 50, 1.0)
    long_on = smoothstep(0.30, 0.12, uniform(noise(70, seed + 51)))
    crack = np.maximum(crack, smoothstep(1.5, 0.3, (l2 - l1) * 0.5) * long_on)
    tar = np.maximum(tar, smoothstep(2.4, 1.0, (l2 - l1) * 0.5) * long_on * sealed)
    crack_open = crack * (1 - sealed)
    g1, g2, _ = voronoi(cu * 1.0, cv * 1.0, 14, seed + 13)
    hair_edge = (g2 - g1) * 0.5
    hair_gate = uniform(noise(24, seed + 14))
    hair = smoothstep(0.9, 0.15, hair_edge) * smoothstep(0.20, 0.08, hair_gate)

    # --- Patches: a lighter concrete repair, an asphalt skim, a narrow utility trench.
    rough_edge = noise(3, seed + 15) * 2.0
    repair = smoothstep(1.2, -1.2, rect_sdf(cu, cv, 830, 190, 92, 66) + rough_edge)
    asphalt = smoothstep(1.5, -1.5, rect_sdf(cu, cv, 470, 770, 92, 60) + rough_edge * 2.2 + noise(20, seed + 16) * 7)
    trench = smoothstep(1.2, -1.2, rect_sdf(fx, fy, 330, 330, 80, 10) + rough_edge * 0.5)
    patch_seam = np.maximum.reduce([smoothstep(2.4, 0.4, np.abs(rect_sdf(cu, cv, 830, 190, 92, 66) + rough_edge)),
                                    smoothstep(2.4, 0.4, np.abs(rect_sdf(fx, fy, 330, 330, 80, 10) + rough_edge * 0.5))])

    # --- Large-scale tone, stains, dust.
    mottle = noise(80, seed + 20) * 0.05 + noise(26, seed + 21) * 0.032 + noise(7, seed + 22) * 0.018
    stain = smoothstep(0.76, 0.95, uniform(noise(16, seed + 23) + 0.8 * noise(48, seed + 24) + 0.45 * noise(5, seed + 43)))
    oil = smoothstep(0.988, 0.997, uniform(noise(8, seed + 25) + 0.5 * noise(24, seed + 26)))
    oil_halo = smoothstep(0.965, 0.990, uniform(noise(8, seed + 25) + 0.5 * noise(24, seed + 26)))
    dust = smoothstep(0.45, 0.95, uniform(noise(38, seed + 27) + 0.4 * noise(10, seed + 28)))
    drift = smoothstep(0.55, 0.97, uniform(noise(55, seed + 45, 9) + 0.5 * noise(18, seed + 46, 4)))  # wind-blown sand streaks
    joint_dust = smoothstep(18, 3, jd) * (0.55 + 0.45 * uniform(noise(7, seed + 29)))
    trafficked = smoothstep(0.58, 0.92, uniform(noise(55, seed + 30)))

    grain_fine = noise(0.8, seed + 31)
    grain = noise(1.5, seed + 32)
    grain_mid = noise(3.2, seed + 33)
    pits = smoothstep(2.0, 3.0, noise(1.1, seed + 34))
    stones = smoothstep(1.6, 2.4, noise(2.0, seed + 35)) * slab_wear[slab]
    grit = smoothstep(1.5, 2.3, noise(0.9, seed + 44)) * smoothstep(48, 6, jd)  # sand and chips swept against the joints

    # --- Survey paint (teal, worn, never orange): crosshair with ring, dashed station line, corner bracket.
    pu = fx + noise(2, seed + 36) * 0.8
    pv = fy + noise(2, seed + 37) * 0.8
    cross = np.minimum(segment_dist(pu, pv, 260 - 42, 150, 260 + 42, 150), segment_dist(pu, pv, 260, 150 - 42, 260, 150 + 42))
    ring = np.abs(np.hypot(wrap_delta(pu, 260), wrap_delta(pv, 150)) - 21)
    line_dash = ((fx + 60) % 112) < 72
    station = np.where(line_dash, np.abs(wrap_delta(pv, 868)), 99)
    bracket = np.minimum(segment_dist(pu, pv, 700, 650, 700, 732), segment_dist(pu, pv, 700, 732, 782, 732))
    paint_shape = np.maximum.reduce([smoothstep(3.0, 1.8, cross), smoothstep(2.6, 1.4, ring), smoothstep(3.4, 2.2, station),
                                     smoothstep(3.4, 2.2, bracket)])
    paint = paint_shape * smoothstep(0.30, 0.62, uniform(noise(2.4, seed + 38) + 0.8 * noise(14, seed + 39)))
    glints = paint * smoothstep(0.84, 0.92, uniform(noise(1.6, seed + 40)))

    # --- Height
    height = slab_level[slab] + slab_tilt[slab, 0] * sxn + slab_tilt[slab, 1] * syn
    height += 0.05 * noise(30, seed + 41) + 0.02 * noise(7, seed + 42)
    height += (0.020 * grain_mid + 0.020 * grain + 0.012 * grain_fine) * (1 - 0.6 * repair)
    height -= 0.05 * pits
    height += 0.035 * stones + 0.04 * grit
    height -= 0.10 * arris + 0.38 * groove
    height -= 0.30 * crack_open + 0.12 * tar + 0.07 * hair + 0.05 * smoothstep(7, 1, edge) * on
    height += 0.025 * repair + 0.012 * asphalt - 0.05 * trench - 0.05 * patch_seam
    height -= 0.015 * stain
    height += 0.006 * paint

    # --- Albedo (sRGB)
    base = np.array([0.215, 0.193, 0.165], np.float32)
    tone = 1 + mottle + slab_tone[slab]
    tone = tone + 0.05 * (grain_mid * 0.4 + grain * 0.3 + grain_fine * 0.3) * (0.4 + 0.6 * slab_wear[slab])
    albedo = (base[None, None, :] + slab_hue[slab]) * tone[..., None]
    albedo = tint(albedo, base * np.array([0.88, 0.86, 0.84]), stain * 0.5)
    albedo = tint(albedo, base * np.array([1.10, 1.06, 1.0]), dust * 0.5)
    albedo = tint(albedo, base * np.array([1.16, 1.11, 1.03]), drift * 0.3)
    albedo = tint(albedo, base * np.array([0.9, 0.86, 0.8]) * 0.55, oil_halo * 0.5)
    albedo = tint(albedo, [0.11, 0.108, 0.105], oil * 0.6)
    albedo = tint(albedo, np.array([0.10, 0.098, 0.092]), np.clip(pits * 0.5, 0, 1))
    albedo = tint(albedo, base * np.array([1.18, 1.14, 1.06]), np.clip(stones * 0.7 + grit * 0.5, 0, 1))
    albedo = tint(albedo, np.array([0.205, 0.197, 0.18]), repair * 0.75)
    albedo = tint(albedo, np.array([0.178, 0.174, 0.168]), asphalt * 0.5)
    albedo = tint(albedo, np.array([0.12, 0.115, 0.105]), trench * 0.8)
    ao = 0.5 + 0.5 * smoothstep(0, 7, jd_chipped)
    albedo = albedo * ao[..., None]
    albedo = tint(albedo, np.array([0.115, 0.105, 0.095]), groove * 0.9)  # joint fill: packed dirt
    albedo = tint(albedo, base * np.array([1.2, 1.12, 1.0]), joint_dust * 0.45 * (1 - groove))
    albedo = tint(albedo, np.array([0.06, 0.058, 0.058]), crack_open * 0.85)
    albedo = tint(albedo, np.array([0.055, 0.055, 0.058]), tar * 0.9)
    albedo = tint(albedo, np.array([0.06, 0.058, 0.056]), hair * 0.7)
    albedo = tint(albedo, np.array([0.07, 0.065, 0.06]), patch_seam * 0.7)
    albedo = tint(albedo, np.array([0.165, 0.285, 0.29]), paint * 0.6)  # faded survey teal

    # --- Roughness
    roughness = 0.87 + 0.045 * grain_mid + 0.03 * grain
    roughness -= 0.13 * trafficked
    roughness -= 0.05 * stain
    roughness += 0.09 * dust + 0.05 * drift
    roughness = lerp(roughness, 0.42, oil * 0.9)
    roughness = lerp(roughness, 0.60, oil_halo * 0.4)
    roughness = lerp(roughness, 0.74, repair)
    roughness = lerp(roughness, 0.82, asphalt)
    roughness = lerp(roughness, 0.95, groove)
    roughness = lerp(roughness, 0.55, tar * 0.9)
    roughness = lerp(roughness, 0.66, paint * 0.8)
    roughness = lerp(roughness, 0.96, joint_dust * 0.5)
    roughness = np.clip(roughness, 0.3, 1.0)

    # --- Emission: only the survey paint's reflective flecks, barely there.
    emission = np.zeros((SIZE, SIZE, 3), np.float32)
    emission += glints[..., None] * np.array([0.08, 0.62, 0.58], np.float32) * 0.22

    return pack(albedo, normal_from_height(height, 6.0), roughness, emission)


# --- Theme: grating (The Sump) -- wet, corroded deck plating over a lit drain -----------------------------------------

def build_grating():
    """Eight 3.2 x 1.6 m deck plates in staggered rows: welded seams with bolted edges, a bar-grating panel in each direction,
    a perforated drain, a diamond-tread plate, a pipe run with a valve branch, rust blooms streaking from bolts and seams, green
    slime in the joints and glossy puddles. The grates and drain holes glow with dim green-teal sump light from below.
    Dark green-grey steel, rust kept brown and desaturated (never orange); use metallic ~0.3 on the material."""
    seed = 9120
    fx = xx.astype(np.float32)
    fy = yy.astype(np.float32)
    rng = np.random.default_rng(seed)
    plate_w, plate_h = 512, 256

    # --- Plate layout: four rows of two plates, each row shifted along x (ids: row * 2 + column).
    row, ly, _, dist_y = band_cells(fy, [0, 256, 512, 768])
    plate = np.zeros(fx.shape, np.int32)
    lx = np.zeros(fx.shape, np.float32)
    dist_x = np.zeros(fx.shape, np.float32)
    for r, offset in enumerate([0, 300, 120, 410]):
        idx, local, _, dist = band_cells(fx, [offset, offset + plate_w])
        here = row == r
        plate = np.where(here, r * 2 + idx, plate)
        lx = np.where(here, local, lx)
        dist_x = np.where(here, dist, dist_x)
    SOLID, GRATE_X, DRAIN, TREAD, GRATE_Y = range(5)
    variant = np.array([SOLID, GRATE_X, DRAIN, SOLID, TREAD, SOLID, SOLID, GRATE_Y])[plate]
    plate_tone = rng.normal(0, 0.07, 8)
    plate_level = rng.normal(0, 0.02, 8)
    plate_rust = rng.uniform(0.2, 1.0, 8)
    ed = np.minimum(dist_x, dist_y)  # px to the nearest plate seam

    # --- Bolts: every 64 px along the plate borders, inset 16 px.
    dx = ((lx - 32) % 64) - 32
    dy = ((ly - 32) % 64) - 32
    bolt_d = np.minimum.reduce([np.hypot(dx, ly - 16), np.hypot(dx, ly - (plate_h - 16)),
                                np.hypot(lx - 16, dy), np.hypot(lx - (plate_w - 16), dy)]).astype(np.float32)
    bolt_d = np.where((ed > 8) & (ed < 26), bolt_d, 99)

    # --- Pipe run along the row seam at y = 768 (flanges every 256 px), a thin conduit beside it, a valve branch at x = 860.
    pipe_r, conduit_r = 22.0, 9.0
    pd = np.abs(wrap_delta(fy, 768))
    flange_x = np.abs(((fx - 100 + 128) % 256) - 128)
    strap_x = np.abs(((fx - 228 + 128) % 256) - 128)
    pipe_h = np.sqrt(np.maximum(pipe_r ** 2 - pd ** 2, 0)) / pipe_r
    flange_h = np.where(flange_x < 8, np.sqrt(np.maximum((pipe_r + 5) ** 2 - pd ** 2, 0)) / (pipe_r + 5), 0)
    strap_h = np.where(strap_x < 3.5, np.sqrt(np.maximum((pipe_r + 2) ** 2 - pd ** 2, 0)) / (pipe_r + 2), 0)
    pipe_main = np.maximum.reduce([pipe_h * 0.55, flange_h * 0.66, strap_h * 0.6])
    cd = np.abs(wrap_delta(fy, 768 + 40))
    clamp_x = np.abs(((fx - 164 + 64) % 128) - 64)
    conduit_h = np.sqrt(np.maximum(conduit_r ** 2 - cd ** 2, 0)) / conduit_r
    clamp_h = np.where(clamp_x < 4, np.sqrt(np.maximum((conduit_r + 3) ** 2 - cd ** 2, 0)) / (conduit_r + 3), 0)
    conduit = np.maximum(conduit_h * 0.4, clamp_h * 0.5)
    branch_d = segment_dist(fx, fy, 860, 768, 860, 470)
    branch_h = np.sqrt(np.maximum(14.0 ** 2 - branch_d ** 2, 0)) / 14.0
    cap_d = np.hypot(wrap_delta(fx, 860), wrap_delta(fy, 470))
    branch = np.maximum(branch_h * 0.5, np.where(cap_d < 24, 0.62 - 0.1 * smoothstep(8, 3, cap_d), 0))
    box_sdf = rect_sdf(fx, fy, 860, 768, 34, 34)
    valve_box = smoothstep(1.2, -1.2, box_sdf) * 0.8
    wheel_d = np.hypot(wrap_delta(fx, 860), wrap_delta(fy, 768))
    spokes = np.minimum(np.abs(wrap_delta(fx, 860)), np.abs(wrap_delta(fy, 768)))
    wheel = np.maximum(smoothstep(2.6, 1.0, np.abs(wheel_d - 19)), np.where(wheel_d < 19, smoothstep(2.4, 0.8, spokes), 0))
    lamp = smoothstep(4.4, 3.0, cap_d)  # a sump indicator on the branch cap
    pipes = np.maximum.reduce([pipe_main, conduit, branch, valve_box, 0.95 * wheel])
    pipe_mask = np.maximum.reduce([smoothstep(pipe_r + 1, pipe_r - 2, pd), smoothstep(conduit_r + 1, conduit_r - 2, cd),
                                   smoothstep(15, 12, branch_d), smoothstep(25, 22, cap_d), smoothstep(1.2, -1.2, box_sdf)])
    pipe_halo = np.maximum.reduce([smoothstep(pipe_r + 16, pipe_r, pd), smoothstep(conduit_r + 10, conduit_r, cd),
                                   smoothstep(30, 14, branch_d), smoothstep(14, 0, box_sdf)])

    # --- Grating panels (recessed bar grids over a lit void), drain (perforated hex pattern), diamond tread.
    inner = smoothstep(26, 28.5, np.minimum.reduce([lx, plate_w - lx, ly, plate_h - ly]))
    along = np.where(variant == GRATE_X, lx, ly)  # position along the bars
    across = np.where(variant == GRATE_X, ly, lx)
    slot = smoothstep(7.4, 5.0, np.abs((across % 26) - 13)) * smoothstep(1.6, 4.0, np.minimum(along % 104, 104 - along % 104))
    is_grate = (variant == GRATE_X) | (variant == GRATE_Y)
    grate_gap = np.where(is_grate, slot * inner, 0).astype(np.float32)
    drain_sdf = rect_sdf(fx, fy, 556, 384, 112, 62)
    drain_in = smoothstep(1.2, -1.2, drain_sdf + 8) * (variant == DRAIN)
    px, py = wrap_delta(fx, 556), wrap_delta(fy, 384)
    hex_row = np.round(py / 21)
    qx = ((px - (hex_row % 2) * 13 + 13) % 26) - 13
    qy = py - hex_row * 21
    hole_inside = (np.abs(px - qx) < 100) & (np.abs(py - qy) < 46)  # whole holes only, never clipped by the recess
    holes = smoothstep(7.4, 5.4, np.hypot(qx, qy)) * hole_inside
    holes = np.where(variant == DRAIN, holes, 0).astype(np.float32)
    drain_lip = smoothstep(3.2, 0.5, np.abs(drain_sdf + 4)) * (variant == DRAIN)
    tread = np.where(variant == TREAD, 1.0, 0.0) * smoothstep(12, 20, ed)
    tcx, tcy = (lx % 40) - 20, (ly % 40) - 20
    sign = np.where((lx // 40 + ly // 40) % 2 == 0, 1.0, -1.0)
    tu = (tcx + sign * tcy) * 0.7071
    tv = (-sign * tcx + tcy) * 0.7071
    lug = smoothstep(1.0, 0.55, np.sqrt((tu / 18.5) ** 2 + (tv / 5.5) ** 2)) * tread

    # --- Weld seams and the plate surface.
    seam_core = smoothstep(3.0, 1.0, ed)
    bead = smoothstep(10, 6, ed) * smoothstep(1.5, 4.5, ed)
    bead_ripple = 0.75 + 0.25 * np.sin((fx + fy) * 0.55 + noise(6, seed + 1) * 2.0)
    scuff = noise(1.4, seed + 2)
    dents = noise(7, seed + 3)
    wave = noise(34, seed + 4)
    height = 0.5 + plate_level[plate] + 0.012 * wave + 0.006 * dents + 0.004 * scuff
    height += 0.13 * lug
    height += 0.10 * smoothstep(6.5, 2.5, bolt_d)
    height += 0.10 * bead * bead_ripple - 0.34 * seam_core
    height = np.where(is_grate, lerp(height, 0.46, inner), height)
    height = lerp(height, 0.04, grate_gap)
    height = lerp(height, 0.38, drain_in)
    height += 0.09 * drain_lip
    height = lerp(height, 0.02, holes)
    height = lerp(height, 0.5 + 0.55 * pipes, pipe_mask)  # pipes sit on top of whatever is underneath

    # --- Corrosion, grime, slime, water.
    seam_prox = smoothstep(34, 3, ed)
    near = np.maximum.reduce([seam_prox, smoothstep(24, 5, bolt_d), pipe_halo * 0.9, drain_lip * 0.8])
    rust_noise = uniform(noise(11, seed + 10) + 0.9 * noise(36, seed + 11) + 0.35 * noise(3.2, seed + 12))
    rust_drive = rust_noise * 0.7 + near * 0.5 + plate_rust[plate] * 0.22
    rust = smoothstep(0.78, 0.98, rust_drive)
    streak_field = uniform(noise(1.8, seed + 13, 46) + 0.6 * noise(5, seed + 14, 70))
    streak = smoothstep(0.80, 0.96, streak_field) * smoothstep(0.1, 0.8, near + 0.3 * rust_noise)
    rust = np.clip(rust + streak * 0.55, 0, 1)
    rust_tex = np.clip(noise(1.7, seed + 15) * 0.5 + noise(5, seed + 16) * 0.5, -1, 1)
    grime = smoothstep(0.55, 0.95, uniform(noise(18, seed + 17) + 0.5 * noise(52, seed + 18))) * (0.35 + 0.65 * near)
    slime = smoothstep(0.84, 0.97, uniform(noise(9, seed + 19) + 0.7 * noise(30, seed + 20))) * (0.2 + 0.8 * seam_prox)
    wet = smoothstep(0.30, 0.75, uniform(noise(60, seed + 21) + 0.4 * noise(20, seed + 22)))

    surface = (1 - np.maximum.reduce([pipe_mask, grate_gap, holes])) * (1 - inner * is_grate) * (1 - drain_in)
    pud_field = uniform(noise(24, seed + 23) * 0.8 + noise(85, seed + 24) * 1.0 + noise(8, seed + 25) * 0.25
                        + 0.7 * smoothstep(40, 6, np.abs(drain_sdf)))
    puddle = smoothstep(0.895, 0.93, pud_field) * surface * (1 - 0.8 * smoothstep(0.1, 0.5, np.maximum(bead, lug)))
    halo = smoothstep(0.85, 0.91, pud_field) * surface * (1 - puddle)
    water_level = 0.5 + plate_level[plate] + 0.03
    height = np.where(puddle > 0.02, lerp(height, np.maximum(height, water_level) + 0.0015 * noise(3, seed + 26), puddle), height)
    height = height - 0.006 * rust + 0.009 * rust * noise(1.3, seed + 27)  # pitted, flaking corrosion (kept gentle: steep pits catch the warm rim light)

    # --- Albedo (sRGB)
    base = np.array([0.092, 0.128, 0.122], np.float32)
    mottle = noise(70, seed + 30) * 0.06 + noise(22, seed + 31) * 0.04 + noise(5, seed + 32) * 0.02
    albedo = base[None, None, :] * (1 + mottle + plate_tone[plate])[..., None]
    bright = np.clip(smoothstep(0.55, 1.0, scuff * 0.5 + 0.5) * smoothstep(6, 2, ed) * 0.5 + 0.18 * lug, 0, 1)
    albedo = tint(albedo, base * 1.35, bright)
    albedo = tint(albedo, base * 0.6, grime * 0.55)
    rust_color = np.array([0.118, 0.090, 0.074], np.float32)
    albedo = tint(albedo, rust_color * (0.75 + 0.35 * rust_tex)[..., None], np.clip(rust * 0.8, 0, 1))
    albedo = tint(albedo, np.array([0.072, 0.118, 0.088], np.float32), slime * 0.7)
    ao = 0.35 + 0.65 * smoothstep(0, 7, ed)
    albedo = albedo * ao[..., None]
    pipe_color = np.array([0.105, 0.135, 0.14], np.float32)
    albedo = tint(albedo, pipe_color * (1 + 0.1 * scuff)[..., None], pipe_mask * 0.9)
    rust_pipe = smoothstep(0.80, 0.97, rust_noise) * 0.75
    albedo = tint(albedo, rust_color * 0.9, pipe_mask * rust_pipe)
    pipe_shade = 0.55 + 0.6 * np.clip(pipes * 1.3, 0, 1)
    albedo = albedo * lerp(1.0, pipe_shade, pipe_mask)[..., None]
    albedo = albedo * (1 - 0.35 * pipe_halo * (1 - pipe_mask))[..., None]
    albedo = tint(albedo, np.array([0.02, 0.028, 0.03]), np.maximum(grate_gap, holes) * 0.95)
    albedo = tint(albedo, base * 0.8, drain_in * 0.5)
    albedo = tint(albedo, albedo * 0.8, halo * 0.6)
    albedo = tint(albedo, albedo * 0.92 + np.array([0.003, 0.009, 0.009], np.float32), puddle)

    # --- Roughness: bare plate is satin, rust is dry and matte, slime and wet streaks are slick, puddles are mirrors.
    # The engine's orange back light glares off anything much shinier than this, so only puddles go truly glossy.
    roughness = 0.86 + 0.05 * noise(9, seed + 40) + 0.03 * scuff
    roughness = roughness - 0.12 * wet
    roughness = lerp(roughness, 0.62, slime * 0.8)
    roughness = lerp(roughness, 0.95, np.clip(rust * 0.9, 0, 1))
    roughness = lerp(roughness, 0.9, grime * 0.4)
    roughness = lerp(roughness, 0.6, pipe_mask * 0.5)
    roughness = lerp(roughness, 0.95, np.maximum(grate_gap, holes))
    roughness = lerp(roughness, 0.72, halo * 0.8)
    roughness = lerp(roughness, 0.07, puddle)
    roughness = np.clip(roughness, 0.03, 1.0)

    # --- Emission: sump light leaking up through the grates, drain holes and the odd indicator lamp.
    emission = np.zeros((SIZE, SIZE, 3), np.float32)
    glow_color = np.array([0.08, 0.72, 0.55], np.float32)
    flicker = 0.55 + 0.45 * uniform(noise(28, seed + 41) + 0.5 * noise(9, seed + 42))
    gap_glow = grate_gap * smoothstep(7.4, 1.5, np.abs((across % 26) - 13)) * 0.9 + grate_gap * 0.1
    emission += ((gap_glow + holes * 1.1) * flicker)[..., None] * glow_color * 0.34
    emission += ((puddle * (0.55 + 0.45 * flicker) + halo * 0.25) * 0.5)[..., None] * glow_color * 0.5  # water mirrors the sump lights
    emission += lamp[..., None] * np.array([0.1, 0.85, 0.6], np.float32) * 0.8
    emission += (np.where((flange_x < 2.5) & (pd < 3), 1.0, 0.0) * ((fx // 256) % 2 == 0))[..., None] * glow_color * 0.45

    return pack(albedo, normal_from_height(height, 5.5), roughness, emission)


# --- Theme registry ------------------------------------------------------------------------------------------------

THEMES = {
    "foundry": build_foundry,
    "concrete": build_concrete,
    "grating": build_grating,
}


# --- Preview -------------------------------------------------------------------------------------------------------

def render_preview(theme, maps, repeat=2):
    """Approximate the in-game look: the arena sun plus sky ambient on a repeat x repeat tiling, filmic-ish tonemap.
    Not a substitute for Godot (tools/preview_floor_theme.tscn), but fast enough to judge seams and balance."""
    albedo = np.clip(maps["albedo"], 0, 1) ** 2.2
    n = maps["normal"] * 2 - 1
    rough = maps["roughness"][..., 0]
    emission = np.clip(maps["emission"], 0, 1) ** 2.2
    light = np.array([-0.243, -0.520, 0.819])  # sun, tangent space (x right, y image-up, z out of the floor)
    view = np.array([0.0, -0.581, 0.814])
    half = light + view
    half /= np.linalg.norm(half)
    ndl = np.clip((n * light).sum(-1), 0, 1)
    ndh = np.clip((n * half).sum(-1), 0, 1)
    gloss = np.clip(1 - rough, 0.02, 1)
    spec = (ndh ** (2 + 400 * gloss ** 3)) * (0.04 + 0.5 * gloss ** 2) * (1 + 6 * gloss ** 3)
    sun = np.array([0.82, 0.92, 1.0]) * 1.4
    ambient = np.array([0.10, 0.20, 0.25]) * 0.7
    sky = np.array([0.16, 0.34, 0.40]) * 0.9
    fresnel = 0.04 + 0.96 * (1 - np.clip(n[..., 2] * view[2] + n[..., 1] * view[1], 0, 1)) ** 5
    color = albedo * (sun * ndl[..., None] + ambient) + (spec * ndl)[..., None] * sun + (fresnel * gloss ** 4 * 3)[..., None] * sky + emission * 0.9
    color = color * 1.0
    mapped = color / (1 + color * 0.9)  # soft shoulder
    mapped = np.clip(mapped, 0, 1) ** (1 / 2.2)
    tile = np.tile(mapped, (repeat, repeat, 1))
    PREVIEW_OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray((tile * 255 + 0.5).astype(np.uint8)).save(PREVIEW_OUT / f"{theme}_preview.png")
    sheet = np.concatenate([np.clip(maps["albedo"], 0, 1), maps["normal"], maps["roughness"], np.clip(maps["emission"] * 2, 0, 1)], axis=1)
    Image.fromarray((sheet * 255 + 0.5).astype(np.uint8)).resize((2048, 512), Image.LANCZOS).save(PREVIEW_OUT / f"{theme}_maps.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("theme", nargs="?", default="all", choices=["all", *THEMES])
    parser.add_argument("--preview", action="store_true", help="also write approximate lit previews to .test-results/floor/")
    args = parser.parse_args()
    for theme in THEMES if args.theme == "all" else [args.theme]:
        maps = THEMES[theme]()
        for name, array in maps.items():
            save(theme, f"floor_{name}.png", array)
        if args.preview:
            render_preview(theme, maps)
        print(f"{theme}: floor textures written to {OUT / theme} (tile {TILE_METRES} m)")


if __name__ == "__main__":
    main()

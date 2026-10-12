"""Generate the seamless arena floor texture sets (albedo, normal, roughness, emission), one per terrain theme.

Run: python tools/build_floor_textures.py [theme|all] [--preview]     (needs numpy and Pillow)
Output: assets/textures/floor/<theme>/floor_{albedo,normal,roughness,emission}.png, 2048 px covering TILE_METRES square
(320 px per metre). Everything is periodic (FFT noise, wrapped distances), so each tile repeats without visible edges.

Themes (ArenaLayouts ids -> theme ids; the ids are code names, the looks are Clockwork Pop):
  foundry  (Crossroads)  teal enamel stage plates, brass inlay, dials, cogs, key-wound spirals, rivets
  concrete (Highlands)   warm terracotta and stone flagstones, ivory grout, brass-edged stones, copper inlay, cog medallions
  grating  (The Sump)    oxidised copper deck, verdigris, brass bar gratings and drains, copper pipe-work, damp sheen

Art rules (see doc/art/floor-themes.md): the floor is a quiet supporting stage under teal/coral/brass models, gold pickups and
coloured zone overlays (blue, olive, hazard orange, violet, red damage). Albedo stays dark and low-saturation with clear value
structure (plate / groove / inlay), brass and copper stay muted bronze, no stripes or saturated reds, and roughness stays mostly
0.72-0.95 because the scene's orange rim light glares off anything glossier. Emission is a few pale seam/indicator lines only,
since the game tints it per wave.

Anti-aliasing: shapes are signed distance fields turned into coverage with `cover()` (1.2-1.6 px wide edges); noise is only used
smoothly (wide smoothsteps), never hard-thresholded at pixel scale. `--preview` writes a 2x2 tiled, approximately lit render to
.test-results/floor/<theme>_preview.png.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 2048
TILE_METRES = 6.4  # keep in sync with FLOOR_TILE_METRES in scripts/game/world_geometry.gd
PX_PER_M = SIZE / TILE_METRES  # 320
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/textures/floor"
PREVIEW_OUT = ROOT / ".test-results/floor"
HALF = SIZE / 2
TAU = np.float32(2 * np.pi)

_axis = (np.arange(SIZE, dtype=np.float32) + 0.5)
X = _axis[None, :]  # pixel-centre coordinates; broadcast against each other
Y = _axis[:, None]


# --- Maths helpers -------------------------------------------------------------------------------------------------

def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def lerp(a, b, t):
    return a + (b - a) * t


def cover(d, w=1.4):
    """Anti-aliased coverage from a signed distance in px (negative inside): a smooth edge about `w` px wide."""
    return smoothstep(w * 0.5, -w * 0.5, d)


def wrap_delta(a, b):
    """Shortest signed distance from b to a on the periodic tile."""
    return (a - b + HALF) % SIZE - HALF


_noise_kernels = {}


def noise(sigma, seed, sigma_y=None):
    """Periodic Gaussian noise (sigma in px) standardised to zero mean and unit deviation; `sigma_y` stretches it along y."""
    sy = sigma if sigma_y is None else sigma_y
    key = (float(sigma), float(sy))
    if key not in _noise_kernels:
        fy = np.fft.fftfreq(SIZE).astype(np.float32)[:, None]
        fx = np.fft.rfftfreq(SIZE).astype(np.float32)[None, :]
        _noise_kernels[key] = np.exp(-2 * np.pi ** 2 * ((sigma * fx) ** 2 + (sy * fy) ** 2)).astype(np.float32)
    white = np.random.default_rng(seed).standard_normal((SIZE, SIZE), dtype=np.float32)
    out = np.fft.irfft2(np.fft.rfft2(white) * _noise_kernels[key], s=(SIZE, SIZE)).astype(np.float32)
    return (out - out.mean()) / out.std()


def uniform(field):
    """Rank-transform a field to a flat [0, 1] distribution, so a threshold t covers exactly (1 - t) of the tile."""
    order = np.argsort(field, axis=None)
    out = np.empty(field.size, np.float32)
    out[order] = np.linspace(0, 1, field.size, dtype=np.float32)
    return out.reshape(field.shape)


def hash01(*values):
    """Deterministic pseudo-random float in [0, 1) from integers (numpy arrays or scalars)."""
    arrays = np.broadcast_arrays(*[np.asarray(v).astype(np.uint32) for v in values])
    h = np.zeros(arrays[0].shape, np.uint32)
    for v in arrays:
        h = (h ^ (v + np.uint32(0x9E3779B9) + (h << np.uint32(6)) + (h >> np.uint32(2)))) * np.uint32(2654435761)
        h ^= h >> np.uint32(15)
    return (h & np.uint32(0xFFFFFF)).astype(np.float32) / np.float32(0x1000000)


# --- Signed distance shapes (px, negative inside) -----------------------------------------------------------------------

def sd_circle(cx, cy, radius, x=X, y=Y):
    return np.hypot(wrap_delta(x, cx), wrap_delta(y, cy)) - radius


def sd_box(cx, cy, half_w, half_h, rounding=0.0, x=X, y=Y):
    qx = np.abs(wrap_delta(x, cx)) - (half_w - rounding)
    qy = np.abs(wrap_delta(y, cy)) - (half_h - rounding)
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - rounding


def sd_segment(x0, y0, x1, y1, radius=0.0, x=X, y=Y):
    """Capsule from (x0, y0) to (x1, y1); the segment is placed on the tile and wraps with it."""
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    px, py = wrap_delta(x, cx), wrap_delta(y, cy)
    ax, ay, bx, by = x0 - cx, y0 - cy, x1 - cx, y1 - cy
    dx, dy = bx - ax, by - ay
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy), 0, 1)
    return np.hypot(px - (ax + t * dx), py - (ay + t * dy)) - radius


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


def voronoi(u, v, cells, seed, jitter=0.8):
    """Periodic Worley cells on a cells x cells jittered grid. Returns the exact distance (px) to the nearest cell border, the
    nearest and second nearest cell ids, the nearest feature point and the per-cell point table (px, shape cells x cells x 2)."""
    rng = np.random.default_rng(seed)
    cell = SIZE / cells
    points = rng.random((cells, cells, 2)).astype(np.float32)
    u = (u % SIZE).astype(np.float32)
    v = (v % SIZE).astype(np.float32)
    ci = (u // cell).astype(np.int32)
    cj = (v // cell).astype(np.int32)
    shape = np.broadcast(u, v).shape
    f1 = np.full(shape, 1e9, np.float32)
    f2 = np.full(shape, 1e9, np.float32)
    p1x = np.zeros(shape, np.float32)
    p1y = np.zeros(shape, np.float32)
    p2x = np.zeros(shape, np.float32)
    p2y = np.zeros(shape, np.float32)
    id1 = np.zeros(shape, np.int32)
    id2 = np.zeros(shape, np.int32)
    for dj in (-2, -1, 0, 1, 2):
        for di in (-2, -1, 0, 1, 2):
            ni, nj = ci + di, cj + dj
            offset = points[nj % cells, ni % cells]
            px = (ni + 0.5 + (offset[..., 0] - 0.5) * jitter) * cell
            py = (nj + 0.5 + (offset[..., 1] - 0.5) * jitter) * cell
            dist = np.hypot(u - px, v - py)
            ident = (nj % cells) * cells + (ni % cells)
            first = dist < f1
            second = ~first & (dist < f2)
            f2 = np.where(first, f1, np.where(second, dist, f2))
            p2x = np.where(first, p1x, np.where(second, px, p2x))
            p2y = np.where(first, p1y, np.where(second, py, p2y))
            id2 = np.where(first, id1, np.where(second, ident, id2))
            f1 = np.where(first, dist, f1)
            p1x = np.where(first, px, p1x)
            p1y = np.where(first, py, p1y)
            id1 = np.where(first, ident, id1)
    gap = np.maximum(np.hypot(p2x - p1x, p2y - p1y), 1e-3)
    border = (f2 * f2 - f1 * f1) / (2 * gap)
    table = np.empty((cells, cells, 2), np.float32)
    table[..., 0] = (np.arange(cells)[None, :] + 0.5 + (points[..., 0] - 0.5) * jitter) * cell
    table[..., 1] = (np.arange(cells)[:, None] + 0.5 + (points[..., 1] - 0.5) * jitter) * cell
    return border, id1, id2, (p1x, p1y), table


def stamp_lines(count, seed, length=(40, 160), width=0.9, direction_bias=None):
    """Hairline scratch coverage: `count` random capsules drawn in small windows (so it stays cheap), wrapping with the tile."""
    rng = np.random.default_rng(seed)
    out = np.zeros((SIZE, SIZE), np.float32)
    for _ in range(count):
        cx, cy = rng.uniform(0, SIZE, 2)
        angle = rng.uniform(0, np.pi) if direction_bias is None or rng.random() < 0.3 else direction_bias + rng.normal(0, 0.18)
        half = rng.uniform(*length) / 2
        dx, dy = np.cos(angle) * half, np.sin(angle) * half
        strength = rng.uniform(0.25, 1.0)
        reach = int(half + 4)
        ys = (np.arange(int(cy) - reach, int(cy) + reach + 1)) % SIZE
        xs = (np.arange(int(cx) - reach, int(cx) + reach + 1)) % SIZE
        gx = (np.arange(int(cx) - reach, int(cx) + reach + 1) + 0.5 - cx).astype(np.float32)[None, :]
        gy = (np.arange(int(cy) - reach, int(cy) + reach + 1) + 0.5 - cy).astype(np.float32)[:, None]
        t = np.clip((gx * dx + gy * dy) / (half * half), -1, 1)
        d = np.hypot(gx - t * dx, gy - t * dy)
        taper = 1 - 0.6 * np.abs(t)
        cov = cover(d - width * 0.5 * taper, 1.1) * strength
        window = out[np.ix_(ys, xs)]
        out[np.ix_(ys, xs)] = np.maximum(window, cov)
    return out


# --- Canvas: layered albedo / roughness / height / emission ---------------------------------------------------------------

class Canvas:
    """Paints coverage masks into the four maps. Heights are in px of relief (slope 1 = 45 degrees)."""

    def __init__(self, albedo, rough):
        self.albedo = np.empty((SIZE, SIZE, 3), np.float32)
        self.albedo[:] = np.asarray(albedo, np.float32)
        self.rough = np.full((SIZE, SIZE), rough, np.float32)
        self.height = np.zeros((SIZE, SIZE), np.float32)
        self.emission = np.zeros((SIZE, SIZE, 3), np.float32)

    def paint(self, mask, color=None, rough=None, height=None, height_add=None, emission=None):
        m = np.asarray(mask, np.float32)
        if m.shape != (SIZE, SIZE):
            m = np.broadcast_to(m, (SIZE, SIZE))
        if color is not None:
            c = np.asarray(color, np.float32)
            self.albedo += (c - self.albedo) * m[..., None]
        if rough is not None:
            self.rough += (np.asarray(rough, np.float32) - self.rough) * m
        if height is not None:
            self.height += (np.asarray(height, np.float32) - self.height) * m
        if height_add is not None:
            self.height += np.asarray(height_add, np.float32) * m
        if emission is not None:
            self.emission += np.asarray(emission, np.float32) * m[..., None]

    def maps(self, normal_strength=1.0):
        return pack(self.albedo, normal_from_height(self.height, normal_strength), np.clip(self.rough, 0.3, 0.98), self.emission)


def normal_from_height(height, strength=1.0):
    """OpenGL-convention tangent normal (+Y green = up in the image) from a periodic height map in px, as [0, 1] RGB (Sobel)."""
    def roll(a, dy, dx):
        return np.roll(np.roll(a, dy, 0), dx, 1)
    dx = (roll(height, 0, -1) - roll(height, 0, 1)) * 2 + (roll(height, -1, -1) - roll(height, -1, 1)) + (roll(height, 1, -1) - roll(height, 1, 1))
    dy = (roll(height, -1, 0) - roll(height, 1, 0)) * 2 + (roll(height, -1, -1) - roll(height, 1, -1)) + (roll(height, -1, 1) - roll(height, 1, 1))
    dx *= strength / 8
    dy *= strength / 8
    normal = np.stack([-dx, dy, np.ones_like(dx)], axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    return normal * 0.5 + 0.5


def pack(albedo, normal, roughness, emission):
    return {"albedo": albedo, "normal": normal, "roughness": roughness, "emission": emission}


def save(theme, name, array):
    folder = OUT / theme
    folder.mkdir(parents=True, exist_ok=True)
    data = (np.clip(array, 0, 1) * 255 + 0.5).astype(np.uint8)
    image = Image.fromarray(data, "L" if data.ndim == 2 else "RGB")
    image.save(folder / name, optimize=True, compress_level=9)


def rrect_sd(cx, cy, half_w, half_h, rounding):
    """Rounded rectangle centred on the origin of local coordinates (cx, cy); half sizes may be per-pixel arrays."""
    qx = np.abs(cx) - (half_w - rounding)
    qy = np.abs(cy) - (half_h - rounding)
    return np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - rounding


def cog(r, theta, radius, tooth_h, teeth, half_base, half_tip, phase=0.0, w=1.4):
    """Coverage of a cog wheel centred on the polar origin: body of `radius` plus trapezoid teeth up to radius + tooth_h."""
    pitch = TAU / teeth
    arc = ((theta - phase + pitch / 2) % pitch - pitch / 2) * r  # signed arc length to the nearest tooth centre (px)
    frac = np.clip((r - radius) / tooth_h, 0, 1)
    half = lerp(half_base, half_tip, frac)
    tooth = cover(np.abs(arc) - half, w) * cover(r - (radius + tooth_h), w)
    return np.maximum(cover(r - radius, w), tooth)


def point_field(centers, reach=16):
    """Distance (px) to, and offset from, the nearest of a few point centres, evaluated only in small windows (rivets, studs)."""
    dist = np.full((SIZE, SIZE), 99.0, np.float32)
    off_x = np.zeros((SIZE, SIZE), np.float32)
    off_y = np.zeros((SIZE, SIZE), np.float32)
    for cx, cy in centers:
        ys = np.arange(int(cy) - reach, int(cy) + reach + 1)
        xs = np.arange(int(cx) - reach, int(cx) + reach + 1)
        dx = (xs + 0.5 - cx).astype(np.float32)[None, :]
        dy = (ys + 0.5 - cy).astype(np.float32)[:, None]
        d = np.hypot(dx, dy)
        window = np.ix_(ys % SIZE, xs % SIZE)
        closer = d < dist[window]
        dist[window] = np.where(closer, d, dist[window])
        off_x[window] = np.where(closer, dx + 0 * dy, off_x[window])
        off_y[window] = np.where(closer, dy + 0 * dx, off_y[window])
    return dist, off_x, off_y


def dome(d, radius, height):
    """Spherical-cap relief for a rivet head: `height` px at the centre falling to zero at `radius`."""
    return height * np.sqrt(np.maximum(1 - (d / radius) ** 2, 0))


# --- Theme: foundry (Crossroads) -- teal enamel stage plates with brass inlay -----------------------------------------

BRONZE = np.array([0.29, 0.245, 0.15], np.float32)  # muted brass: never brighter or more orange than this
BRONZE_HI = np.array([0.45, 0.39, 0.24], np.float32)
BRONZE_DARK = np.array([0.20, 0.158, 0.095], np.float32)


def build_foundry():
    """Enamel stage plates on a 1.6 m grid, some merged into 3.2 x 1.6 and 1.6 x 3.2 panels so the grid does not read as wallpaper.
    Each plate has a brass inlay frame, domed rivets and a plain, toothed or tick-marked border; 1.6 m slots carry a dial, a
    cog or a key-wound spiral. Cyan watch-jewel lights, a few amber studs and a pale seam light on the tile border."""
    seed = 2026
    rng = np.random.default_rng(seed)
    S = 512  # slot size (1.6 m)
    # Plate rectangles as (col, row, cols, rows) on the 4 x 4 slot grid; the border of the tile is always a seam.
    rects = [(0, 0, 2, 1), (2, 0, 1, 1), (3, 0, 1, 2), (0, 1, 1, 1), (1, 1, 2, 1), (0, 2, 1, 2),
             (1, 2, 1, 1), (2, 2, 2, 1), (1, 3, 1, 1), (2, 3, 1, 1), (3, 3, 1, 1)]
    PLAIN, TICKS, TOOTHED = range(3)
    frame_style = [PLAIN, TICKS, PLAIN, TOOTHED, PLAIN, PLAIN, TICKS, PLAIN, TOOTHED, PLAIN, TICKS]
    cell_rect = np.zeros((4, 4), np.int32)
    for index, (c, r_, w_, h_) in enumerate(rects):
        cell_rect[r_:r_ + h_, c:c + w_] = index
    rect_x0 = np.array([c * S for c, _, _, _ in rects], np.float32)
    rect_y0 = np.array([r_ * S for _, r_, _, _ in rects], np.float32)
    rect_w = np.array([w_ * S for _, _, w_, _ in rects], np.float32)
    rect_h = np.array([h_ * S for _, _, _, h_ in rects], np.float32)
    rid = cell_rect[(Y // S).astype(np.int32), (X // S).astype(np.int32)]
    lx, ly = X - rect_x0[rid], Y - rect_y0[rid]
    pw, ph = rect_w[rid], rect_h[rid]
    ed = np.minimum(np.minimum(lx, pw - lx), np.minimum(ly, ph - ly))
    rcx, rcy = lx - pw / 2, ly - ph / 2

    # Slot motifs (1.6 m cells): none, dial, cog or spiral.
    NONE, DIAL, COG, SPIRAL = range(4)
    slot_kind = np.array([[DIAL, COG, NONE, SPIRAL],
                          [NONE, NONE, DIAL, NONE],
                          [COG, NONE, DIAL, NONE],
                          [NONE, SPIRAL, COG, NONE]]).ravel()
    slot = ((Y // S) * 4 + (X // S)).astype(np.int32)
    variant = slot_kind[slot]
    cxl, cyl = (X % S) - S / 2, (Y % S) - S / 2
    r = np.hypot(cxl, cyl)
    th = np.arctan2(cyl, cxl)
    tone_rng = rng.normal(0, 0.065, len(rects))
    hue_rng = rng.uniform(-1, 1, len(rects))  # -1 blue-slate .. +1 green-teal
    phase_rng = rng.uniform(0, TAU, 16)
    hand_a = rng.uniform(0, TAU, 16)
    hand_b = rng.uniform(0, TAU, 16)

    # Enamel: dark teal-slate, a painted top-left light across each plate, per-plate tone and hue, and slow drift across the tile.
    base = np.array([0.080, 0.160, 0.182], np.float32)
    drift = noise(300, seed + 1) * 0.05 + noise(90, seed + 2) * 0.03
    light = 1 + 0.06 * (-rcx / pw - rcy / ph)
    tone = (1 + tone_rng[rid] + drift) * light
    hue = hue_rng[rid][..., None] * np.array([-0.012, 0.006, -0.022], np.float32)
    cv = Canvas(0, 0.80)
    cv.albedo[:] = (base[None, None, :] + hue) * tone[..., None]

    # Seams, bevel, enamel relief.
    seam = cover(ed - 3.6)
    cv.height += 2.6 * smoothstep(3.6, 9.5, ed) + 1.6 * smoothstep(4, 40, ed)
    cv.paint(seam, color=[0.022, 0.045, 0.055], rough=0.95, height=-4.0)
    cv.paint(cover(np.abs(ed - 8.2) - 1.1) * (1 - seam) * 0.55, color=base * 1.55)  # crisp chamfer highlight round every plate

    # Brass inlay frame set 26 px in, with a thin dark channel either side so it reads as inlay.
    fd = rrect_sd(rcx, rcy, pw / 2 - 26, ph / 2 - 26, 16)
    frame = cover(np.abs(fd) - 2.4, 1.3)
    cv.paint(cover(np.abs(fd) - 5.0, 1.3) * (1 - frame), color=base * 0.55, rough=0.9, height=-0.8)
    cv.paint(frame, color=BRONZE, rough=0.66, height=1.4)

    # Toothed and tick-marked borders just inside the frame.
    style = np.array(frame_style)[rid]
    along_h = np.minimum(ly, ph - ly) <= np.minimum(lx, pw - lx)
    along = np.where(along_h, lx, ly)
    length = np.where(along_h, pw, ph)
    inside = cover(np.abs(ed - 46) - 7.5) * cover(np.abs(along - length / 2) - (length / 2 - 74), 1.3)
    tooth = cover(np.abs((along % 28) - 14) - 7.0)
    toothed = (style == TOOTHED) * inside
    cv.paint(toothed * (1 - tooth) * 0.5, color=base * 0.55, rough=0.9, height_add=-1.0)
    cv.paint(toothed * tooth, color=BRONZE * 0.9, rough=0.66, height=1.5)
    major = ((along // 16) % 4 == 0)
    tick = cover(np.abs((along % 16) - 8) - np.where(major, 2.0, 1.1)) * cover(np.abs(ed - 46) - np.where(major, 10.5, 6.5))
    cv.paint((style == TICKS) * tick * cover(np.abs(along - length / 2) - (length / 2 - 74), 1.3), color=BRONZE * 0.9, rough=0.66, height=1.2)

    # Dials: engraved rings, minor and major tick marks, two hands and a watch-jewel boss.
    dial = (variant == DIAL).astype(np.float32)
    cv.paint(dial * cover(np.abs(r - 166) - 1.3), color=base * 0.5, rough=0.9, height_add=-1.4)
    cv.paint(dial * cover(np.abs(r - 118) - 1.3), color=base * 0.5, rough=0.9, height_add=-1.2)
    ticks_minor = cover(np.abs(((th + np.pi) / TAU * 60 % 1 - 0.5) * (TAU / 60) * r) - 1.2) * cover(np.abs(r - 150) - 9)
    ticks_major = cover(np.abs(((th + np.pi) / TAU * 12 % 1 - 0.5) * (TAU / 12) * r) - 2.6) * cover(np.abs(r - 146) - 17)
    cv.paint(dial * ticks_minor, color=base * 0.5, rough=0.9, height_add=-1.3)
    cv.paint(dial * cover(np.abs(r - 178) - 2.6), color=BRONZE, rough=0.66, height=1.6)
    cv.paint(dial * ticks_major, color=BRONZE, rough=0.66, height=1.5)
    for angles, length_, width in ((hand_a, 78, 5.0), (hand_b, 110, 3.4)):
        a = angles[slot]
        u = cxl * np.cos(a) + cyl * np.sin(a)
        v = -cxl * np.sin(a) + cyl * np.cos(a)
        hw = lerp(width, 1.0, np.clip(u / length_, 0, 1))
        cv.paint(dial * cover(np.maximum(np.abs(v) - hw, np.maximum(-u - 8, u - length_))), color=BRONZE_DARK, rough=0.7, height=1.0)
    cv.paint(dial * cover(r - 15), color=BRONZE, rough=0.6, height=dome(r, 15, 3.0) + 1.0)
    cv.paint(dial * smoothstep(5, 0.5, np.hypot(cxl + 4, cyl + 4)) * 0.6, color=BRONZE_HI)
    jewel = dial * cover(r - 5.5)
    cv.paint(jewel, color=[0.10, 0.40, 0.42], rough=0.5, height_add=1.2, emission=[0.30, 0.52, 0.52])

    # Cogs: bronze wheel in a shallow engraved recess, five windows, hub and axle hole.
    cogm = (variant == COG).astype(np.float32)
    phase = phase_rng[slot]
    wheel = cog(r, th, 112, 22, 14, 12.5, 6.5, phase)
    recess = cog(r, th, 118, 24, 14, 16, 10, phase)
    windows = np.zeros_like(r)
    for k in range(5):
        a = phase + k * TAU / 5
        windows = np.maximum(windows, cover(np.hypot(cxl - 66 * np.cos(a), cyl - 66 * np.sin(a)) - 24))
    gear_color = BRONZE * 0.64 + np.array([0.0, 0.012, 0.012], np.float32)
    cv.paint(cogm * recess * (1 - wheel), color=base * 0.75, rough=0.92, height_add=-2.0)
    cv.paint(cogm * wheel, color=gear_color, rough=0.68, height=1.8)
    cv.paint(cogm * wheel * windows, color=base * 0.8, rough=0.9, height=-1.2)
    cv.paint(cogm * cover(np.abs(r - 100) - 1.2) * wheel, color=BRONZE_DARK * 0.8, height_add=-0.7)
    cv.paint(cogm * cover(r - 24), color=BRONZE * 0.9, rough=0.6, height=dome(r, 24, 3.4) + 1.6)
    cv.paint(cogm * cover(r - 7), color=base * 0.4, rough=0.9, height=-1.0)
    cv.paint(cogm * smoothstep(8, 0.5, np.hypot(cxl + 8, cyl + 8)) * 0.5, color=BRONZE_HI * 0.9)

    # Key-wound spirals: an engraved groove with a bronze wire laid in it, ending in a winding-key boss.
    spiral = (variant == SPIRAL).astype(np.float32)
    pitch = 40.0
    phase_s = (r - 34 - pitch * (th / TAU)) / pitch
    arm = (phase_s - np.round(phase_s)) * pitch
    extent = cover(r - 174) * (1 - cover(r - 40))
    cv.paint(spiral * cover(np.abs(arm) - 4.2) * extent, color=base * 0.42, rough=0.9, height_add=-2.4)
    cv.paint(spiral * cover(np.abs(arm) - 1.4) * extent, color=BRONZE * 0.9, rough=0.66, height_add=2.0)
    key = cover(r - 30)
    slot_cut = cover(np.maximum(np.abs(cxl) - 14, np.abs(cyl) - 3.2) - 1.0)
    cv.paint(spiral * key, color=BRONZE, rough=0.62, height=2.6)
    cv.paint(spiral * key * slot_cut, color=base * 0.4, rough=0.9, height=0.2)

    # Rivets: domed brass heads at plate corners (and where a merged panel crosses a slot boundary) with a painted highlight.
    centers = []
    for c, r_, w_, h_ in rects:
        xs_ = [c * S + 60] + [c * S + k * S for k in range(1, w_)] + [(c + w_) * S - 60]
        ys_ = [r_ * S + 60, (r_ + h_) * S - 60]
        centers += [(x_, y_) for x_ in xs_ for y_ in ys_]
        if h_ > 1:
            centers += [(x_, r_ * S + S) for x_ in (c * S + 60, (c + w_) * S - 60)]
    rd, rox, roy = point_field(centers)
    cv.paint(cover(rd - 12) * (1 - cover(rd - 8.6)), color=base * 0.5, rough=0.9, height_add=-0.6)
    rivet = cover(rd - 8.6)
    cv.paint(rivet, color=BRONZE, rough=0.6, height=1.4 + dome(rd, 8.6, 5.0))
    cv.paint(smoothstep(4.6, 0.4, np.hypot(rox + 2.6, roy + 2.6)) * rivet * 0.85, color=BRONZE_HI)
    amber_ids = {3, 11, 20, 29, 41}
    amber_centers = [centers[i % len(centers)] for i in amber_ids]
    ad, aox, aoy = point_field(amber_centers)
    amber = cover(ad - 8.6)
    cv.paint(amber, color=[0.40, 0.30, 0.13], emission=[0.45, 0.34, 0.14])
    cv.paint(smoothstep(4.6, 0.4, np.hypot(aox + 2.6, aoy + 2.6)) * amber * 0.85, color=BRONZE_HI)

    # Fine scratches and enamel grain so close-ups are never smooth plastic.
    scratch = stamp_lines(110, seed + 5, (60, 200), 1.0, direction_bias=0.35) * (1 - seam)
    cv.paint(scratch * 0.4, color=[0.27, 0.33, 0.34], rough=0.62, height_add=-0.5)
    grain = noise(1.1, seed + 6) * 0.22 + noise(2.6, seed + 7) * 0.14 + noise(14, seed + 8) * 0.16
    cv.height += grain * (1 - seam)
    cv.rough += (noise(7, seed + 9) * 0.03 + noise(60, seed + 10) * 0.025) * (1 - seam)

    # Emission: a pale seam light round the tile border (pale so the per-wave tint can warm it).
    border = np.minimum(np.minimum(X, SIZE - X), np.minimum(Y, SIZE - Y))
    cv.emission += (cover(border - 2.2, 1.4) * 0.5)[..., None] * np.array([0.55, 0.92, 0.92], np.float32)
    return cv.maps(1.0)


# --- Theme: concrete (Highlands) -- terracotta and stone flagstones with ivory grout and copper inlay ----------------------

COPPER = np.array([0.255, 0.180, 0.125], np.float32)  # muted copper: darker and less orange than the coral shells above it
COPPER_HI = np.array([0.40, 0.30, 0.21], np.float32)


def build_concrete():
    """Seven by seven irregular flagstones in warm terracotta, sandstone, warm grey and umber, set in ivory grout with a slight
    pillow bevel. Some joints carry a fine copper wire, some stones a brass-edged inset line, four large stones a cog-ring
    medallion, and a few survey studs glow faintly. Dry and rough: roughness stays 0.74 to 0.97."""
    seed = 7301
    cells = 7
    wu = X + noise(70, seed + 1) * 5.0 + noise(20, seed + 2) * 1.6
    wv = Y + noise(70, seed + 3) * 5.0 + noise(20, seed + 4) * 1.6
    border, id1, id2, (p1x, p1y), table = voronoi(wu, wv, cells, seed + 5, jitter=0.66)
    n_cells = cells * cells
    rng = np.random.default_rng(seed)

    # Stone types by cell, drifting across the tile with a slow regional field so clay and umber patches form.
    region = noise(380, seed + 6)
    region_at = region[(p1y % SIZE).astype(np.int32), (p1x % SIZE).astype(np.int32)]
    pick = hash01(id1, seed) + 0.55 * np.tanh(region_at)
    TERRA, TERRA_DARK, SAND, GREY, SLATE = range(5)
    kind = np.select([pick < 0.25, pick < 0.52, pick < 0.80, pick < 1.02], [TERRA_DARK, TERRA, SAND, GREY], SLATE)
    palette = np.array([[0.226, 0.146, 0.116], [0.186, 0.121, 0.100], [0.246, 0.212, 0.166], [0.196, 0.180, 0.158], [0.150, 0.132, 0.118]], np.float32)
    # Terracotta is baked smooth and slightly glossy, sandstone is coarse, umber is honed.
    rough_by_kind = np.array([0.80, 0.82, 0.92, 0.88, 0.76], np.float32)
    grain_by_kind = np.array([0.5, 0.5, 1.0, 0.8, 0.35], np.float32)
    tone = 1 + (hash01(id1, seed + 1) - 0.5) * 0.16
    tilt_x = (hash01(id1, seed + 2) - 0.5) * 2.4
    tilt_y = (hash01(id1, seed + 3) - 0.5) * 2.4

    cv = Canvas(0, 0.85)
    mottle = noise(90, seed + 7) * 0.045 + noise(22, seed + 8) * 0.03
    grain_albedo = noise(1.3, seed + 9) * 0.022 + noise(3.4, seed + 10) * 0.018
    stone = palette[kind] * (tone + mottle + grain_albedo)[..., None]
    wear = smoothstep(34, 5, border)
    stone = stone * (1 + 0.10 * wear)[..., None]  # edges are worn lighter
    ao = 0.80 + 0.20 * smoothstep(4, 24, border)
    cv.albedo[:] = stone * ao[..., None]
    cv.rough[:] = rough_by_kind[kind] - 0.05 * wear + noise(9, seed + 11) * 0.025

    # Grout: ivory dust packed between the stones, with a pillow bevel on the stones themselves.
    grout = cover(border - 5.0)
    gdx, gdy = wrap_delta(X, p1x), wrap_delta(Y, p1y)
    cv.height += 3.4 * smoothstep(5, 24, border) + tilt_x * gdx / 150 + tilt_y * gdy / 150
    grout_color = np.array([0.310, 0.278, 0.222], np.float32) * (1 + noise(7, seed + 12) * 0.05 + noise(1.5, seed + 13) * 0.03)[..., None]
    cv.paint(grout, color=grout_color, rough=0.95, height=-3.0)
    cv.paint(cover(np.abs(border - 6.4) - 0.9) * (1 - grout), color=palette[kind] * 0.55, height_add=-0.4)  # crisp edge line where stone meets grout

    # Copper wire along some joints; a brass-edged inset on some stones.
    lo, hi = np.minimum(id1, id2), np.maximum(id1, id2)
    wired = (hash01(lo, hi, seed + 20) < 0.30) * 1.0
    cv.paint(cover(border - 2.0) * wired, color=COPPER, rough=0.7, height_add=1.8)
    cv.paint(cover(border - 0.9) * wired * 0.35, color=COPPER_HI)
    framed = (hash01(id1, seed + 21) < 0.25) * 1.0
    inset = cover(np.abs(border - 18.0) - 1.5) * framed
    cv.paint(inset, color=BRONZE * 0.95, rough=0.64, height_add=1.4)

    # Medallions: inlaid in the four stones with the most room, alternating a spoked cog and a tick-ring dial.
    inradius = np.zeros(n_cells, np.float32)
    np.maximum.at(inradius, id1.ravel(), border.ravel())
    for slot, cid in enumerate(np.argsort(inradius)[::-1][:4]):
        room = float(inradius[cid])
        if room < 80:
            continue
        flat = np.argmax(np.where(id1 == cid, border, -1.0))
        cy, cx = divmod(int(flat), SIZE)
        radius = min(room * 0.8, 120.0)
        lx, ly = wrap_delta(X, cx + 0.5), wrap_delta(Y, cy + 0.5)
        r = np.hypot(lx, ly)
        th = np.arctan2(ly, lx)
        phase = rng.uniform(0, TAU)
        socket = cover(r - radius * 1.06)  # a shallow, darker socket the inlay sits in
        cv.paint(socket * 0.4, color=palette[kind] * 0.62, height_add=-1.2)
        cv.paint(cover(np.abs(r - radius * 1.06) - 1.0), color=palette[kind] * 0.5, height_add=-0.6)
        boss = cover(r - radius * 0.15)
        if slot % 2 == 0:
            ring = cog(r, th, radius * 0.80, radius * 0.18, 16, radius * 0.075, radius * 0.045, phase) * (1 - cover(r - radius * 0.62))
            pitch = TAU / 5
            spoke_arc = ((th - phase * 0.5 + pitch / 2) % pitch - pitch / 2) * r
            spokes = cover(np.abs(spoke_arc) - radius * 0.055) * cover(r - radius * 0.70) * (1 - cover(r - radius * 0.14))
            cv.paint(np.maximum(ring, spokes), color=BRONZE * 0.88, rough=0.68, height_add=1.6)
            cv.paint(cover(np.abs(r - radius * 0.62) - 1.0) * (1 - ring), color=palette[kind] * 0.5, height_add=-0.5)  # engraved line inside the rim
        else:
            for ring_r, hw in ((0.94, 1.8), (0.84, 1.1), (0.54, 1.4)):
                cv.paint(cover(np.abs(r - radius * ring_r) - hw), color=BRONZE * 0.88, rough=0.68, height_add=1.4)
            sector = ((th + np.pi) / TAU * 60) % 1
            tick = cover(np.abs((sector - 0.5) * (TAU / 60) * r) - 1.0) * cover(np.abs(r - radius * 0.74) - radius * 0.07)
            major = cover(np.abs((((th + np.pi) / TAU * 12) % 1 - 0.5) * (TAU / 12) * r) - 2.0) * cover(np.abs(r - radius * 0.72) - radius * 0.12)
            cv.paint(np.maximum(tick, major), color=BRONZE * 0.8, rough=0.7, height_add=1.0)
            cv.paint(cover(np.minimum(sd_segment(cx + 0.5, cy + 0.5, cx + 0.5 + np.cos(phase) * radius * 0.46, cy + 0.5 + np.sin(phase) * radius * 0.46, 2.4),
                                      sd_segment(cx + 0.5, cy + 0.5, cx + 0.5 + np.cos(phase + 2.2) * radius * 0.34, cy + 0.5 + np.sin(phase + 2.2) * radius * 0.34, 2.4))),
                     color=BRONZE * 0.88, rough=0.68, height_add=1.4)
        cv.paint(boss, color=BRONZE_HI * 0.9, rough=0.62, height_add=2.0 + dome(r, radius * 0.15, 2.6))

    # Survey studs: small brass benchmarks at five stone centres, faintly lit.
    stud_cells = rng.choice(n_cells, 5, replace=False)
    stud_centres = [(float(table[c // cells, c % cells, 0]), float(table[c // cells, c % cells, 1])) for c in stud_cells]
    sd_, sox, soy = point_field([(cx_ % SIZE, cy_ % SIZE) for cx_, cy_ in stud_centres], 12)
    stud = cover(sd_ - 6.5)
    cv.paint(cover(sd_ - 9.5) * (1 - stud), color=[0.06, 0.05, 0.045], height_add=-0.5)
    cv.paint(stud, color=[0.36, 0.30, 0.17], rough=0.6, height_add=1.0 + dome(sd_, 6.5, 3.2), emission=[0.55, 0.48, 0.30])
    cv.paint(smoothstep(3.4, 0.3, np.hypot(sox + 1.8, soy + 1.8)) * stud * 0.8, color=COPPER_HI)

    # Fine surface grain (kept off the grout joints), and a few hairline scratches.
    g = grain_by_kind[kind]
    cv.height += (noise(1.2, seed + 14) * 0.26 + noise(3.0, seed + 15) * 0.2 + noise(12, seed + 16) * 0.14) * g * (1 - grout)
    cv.height += noise(1.3, seed + 17) * 0.3 * grout
    scratch = stamp_lines(70, seed + 18, (50, 170), 1.0, direction_bias=1.2) * (1 - grout)
    cv.paint(scratch * 0.3, color=[0.30, 0.27, 0.23], rough=0.7, height_add=-0.4)
    cv.rough += noise(70, seed + 19) * 0.02
    return cv.maps(1.0)


# --- Theme: grating (The Sump) -- oxidised copper deck, verdigris, brass bar gratings, pipe-work with damp sheen ----------------

PATINA = np.array([0.090, 0.178, 0.158], np.float32)  # verdigris: teal-green and well below the enamel teal of the units
PLATE = np.array([0.150, 0.116, 0.088], np.float32)  # oxidised copper deck plate
RUST = np.array([0.178, 0.112, 0.074], np.float32)
VOID = np.array([0.012, 0.02, 0.02], np.float32)


def perimeter_points(x0, y0, w, h, inset, spacing):
    """Rivet positions along the border of a plate (unwrapped; the point field wraps them)."""
    nx = max(int(round((w - 2 * inset) / spacing)), 1)
    ny = max(int(round((h - 2 * inset) / spacing)), 1)
    pts = []
    for i in range(nx + 1):
        x = x0 + inset + i * (w - 2 * inset) / nx
        pts += [(x, y0 + inset), (x, y0 + h - inset)]
    for j in range(1, ny):
        y = y0 + inset + j * (h - 2 * inset) / ny
        pts += [(x0 + inset, y), (x0 + w - inset, y)]
    return pts


def build_grating():
    """Nine deck plates in an irregular running bond (3.2 m class), oxidised copper with smooth verdigris that gathers in the
    seams, damp patches, two brass bar gratings over softly lit green-teal voids, a round drain, a pipe run between four brass
    junction boxes (cog hub, pressure dial, set-screw cap, lamp) with a toothed valve wheel, and a few small oily puddles."""
    seed = 9100
    rng = np.random.default_rng(seed)
    rows = [(0, 480, [0, 1056]), (480, 560, [380, 1290]), (1040, 464, [200, 800, 1500]), (1504, 544, [60, 1010])]
    grates = [(0, 1), (2, 0)]
    corner = 14.0

    # --- Plate layout: distance to the nearest plate border (rounded corners), plate id, local coordinates --------------------
    d_edge = np.empty((SIZE, SIZE), np.float32)
    pid = np.empty((SIZE, SIZE), np.int32)
    lx = np.empty((SIZE, SIZE), np.float32)
    ly = np.empty((SIZE, SIZE), np.float32)
    plates = {}
    for r, (y0, h, edges) in enumerate(rows):
        idx, local, size, dx = band_cells(X[0], edges)
        yl = (np.arange(y0, y0 + h, dtype=np.float32) + 0.5 - y0)[:, None]
        dy = np.minimum(yl, h - yl)
        dxx = dx[None, :]
        d = np.minimum(dxx, dy)
        in_corner = (dxx < corner) & (dy < corner)
        d = np.where(in_corner, corner - np.hypot(corner - dxx, corner - dy), d)
        sl = slice(y0, y0 + h)
        d_edge[sl] = d
        pid[sl] = r * 10 + idx[None, :]
        lx[sl] = (local - size / 2)[None, :] + 0 * yl
        ly[sl] = (yl - h / 2) + 0 * dxx
        for c, ex in enumerate(edges):
            w = (edges[c + 1] - ex) if c + 1 < len(edges) else edges[0] + SIZE - ex
            plates[r * 10 + c] = (ex, y0, w, h)
    grate_ids = [r * 10 + c for r, c in grates]
    is_grate = np.isin(pid, grate_ids)

    # --- Base: oxidised copper, verdigris creeping in from the seams, rust bloom, damp patches ------------------------------
    tone = 1 + (hash01(pid, seed) - 0.5) * 0.20
    bias = (hash01(pid, seed + 1) - 0.5) * 0.7
    tilt_x = (hash01(pid, seed + 2) - 0.5) * 1.6
    tilt_y = (hash01(pid, seed + 3) - 0.5) * 1.6
    mottle = noise(80, seed + 2) * 0.05 + noise(20, seed + 3) * 0.03
    patina_field = noise(75, seed + 4) * 0.8 + noise(20, seed + 5) * 0.3 + bias + 0.95 * np.exp(-d_edge / 45)
    P = smoothstep(0.15, 0.95, patina_field)  # soft edges, tens of px wide: no hard threshold
    rustm = smoothstep(0.7, 1.7, noise(120, seed + 6) + 0.4 * noise(30, seed + 7)) * (1 - P) * 0.55
    wet = smoothstep(0.0, 1.0, noise(240, seed + 8) + 0.4 * noise(50, seed + 9))

    cv = Canvas(PLATE, 0.86)
    base = PLATE * (tone + mottle)[..., None]
    patina_col = PATINA * (1 + noise(6, seed + 10) * 0.07 + noise(1.6, seed + 11) * 0.035)[..., None]
    albedo = base + (patina_col - base) * P[..., None]
    albedo = albedo + (RUST - albedo) * rustm[..., None]
    albedo *= (1 - 0.20 * wet)[..., None]
    wear = smoothstep(26, 4, d_edge)
    albedo *= (0.84 + 0.16 * smoothstep(3, 26, d_edge))[..., None]
    cv.albedo[:] = albedo
    cv.rough[:] = 0.88 - 0.17 * wet + 0.04 * P - 0.03 * wear + noise(9, seed + 12) * 0.025

    # --- Seams, bevel, engraved inset line --------------------------------------------------------------------------------
    seam = cover(d_edge - 2.4)
    cv.height += 2.8 * smoothstep(2.5, 16, d_edge) + tilt_x * lx / 300 + tilt_y * ly / 300
    cv.paint(seam, color=[0.024, 0.026, 0.026], rough=0.95, height=-3.0)
    cv.paint(cover(np.abs(d_edge - 5.5) - 1.1) * (1 - seam) * 0.45, color=BRONZE * 0.8)
    inset = cover(np.abs(d_edge - 32) - 1.2) * (1 - is_grate)
    cv.paint(inset * 0.55, color=PLATE * 0.45, height_add=-0.9)
    cv.paint(cover(np.abs(d_edge - 34.4) - 0.7) * (1 - is_grate) * 0.35, color=BRONZE * 0.75)

    # --- Puddles: small, smooth, dark oily teal, in solid plates away from the pipe run -------------------------------------
    puddles = [(380, 250, 110), (700, 1750, 120), (1950, 1390, 68), (1660, 790, 120)]
    puddle_mask = np.zeros((SIZE, SIZE), np.float32)
    for i, (px, py, pr) in enumerate(puddles):
        wobble = 1 + 0.16 * noise(42, seed + 40 + i)
        dp = np.hypot(wrap_delta(X, px), wrap_delta(Y, py)) - pr * wobble
        body = cover(dp, 3.0)
        shore = smoothstep(26, 0, np.abs(dp)) * 0.22
        cv.albedo *= (1 - shore)[..., None]
        depth = smoothstep(0, -pr * 0.7, dp)  # deeper, darker water towards the middle
        shallow = np.array([0.060, 0.098, 0.100], np.float32)
        deep = np.array([0.030, 0.058, 0.066], np.float32)
        sheen = 0.5 + 0.5 * np.tanh(noise(26, seed + 50 + i) * 1.4)
        tint = np.array([0.012, -0.004, 0.012], np.float32)  # a faint oily violet drift
        water = (shallow + (deep - shallow) * depth[..., None]) + tint * sheen[..., None]
        # A painted highlight crescent on the top-left lip keeps the water readable without a glossy (glare prone) roughness.
        shifted = np.hypot(wrap_delta(X, px + 13), wrap_delta(Y, py + 13)) - pr * wobble
        crescent = cover(dp, 1.6) * (1 - cover(shifted, 1.6))
        cv.paint(body, color=water, rough=0.74, height=-1.6)
        cv.paint(crescent * 0.55, color=[0.17, 0.25, 0.25])
        puddle_mask = np.maximum(puddle_mask, body)

    # --- Gratings: brass frame and bars over green-teal voids ---------------------------------------------------------------
    frame = 30.0
    glow = 0.35 + 0.65 * smoothstep(-0.5, 1.0, noise(140, seed + 13))
    for gid in grate_ids:
        ex, y0, w, h = plates[gid]
        sel = (pid == gid).astype(np.float32)
        inner = cover(frame - d_edge) * sel
        n = int(round((h - 2 * frame) / 40))
        pitch = (h - 2 * frame) / n
        bar_hw = pitch * 0.27
        t = ((ly + h / 2 - frame) % pitch) - pitch / 2
        bar = cover(np.abs(t) - bar_hw, 1.6)
        ties = int(round((w - 2 * frame) / 250))
        tpitch = (w - 2 * frame) / ties
        tx = ((lx + w / 2 - frame) % tpitch) - tpitch / 2
        tie = cover(np.abs(tx) - 8.0, 1.6)
        solid = np.maximum(bar, tie)
        void = inner * (1 - solid)
        bars = inner * solid
        bar_col = BRONZE * 0.84 + (PATINA * 1.15 - BRONZE * 0.84) * (P * 0.55)[..., None]
        cv.paint(void, color=VOID, rough=0.9, height=-5.0)
        cv.emission += (void * glow * 0.55)[..., None] * np.array([0.11, 0.45, 0.40], np.float32)
        cv.paint(bars, color=bar_col, rough=0.74, height_add=1.4 + 0.7 * (1 - smoothstep(0.0, bar_hw, np.abs(t))))
        # a lighter lip on the frame next to the bars
        cv.paint(cover(np.abs(d_edge - frame) - 1.2) * sel * 0.5, color=BRONZE * 0.8, height_add=1.0)

    # --- Drain: sunken bronze dish with radial slots ----------------------------------------------------------------------
    dcx, dcy, dR = 1560.0, 1776.0, 150.0
    lxd, lyd = wrap_delta(X, dcx), wrap_delta(Y, dcy)
    dr = np.hypot(lxd, lyd)
    dth = np.arctan2(lyd, lxd)
    dish = cover(dr - dR)
    rim = cover(np.abs(dr - (dR + 12)) - 9)
    cv.paint(cover(dr - (dR + 26)) * (1 - dish) * (1 - rim) * 0.5, color=PLATE * 0.5, height_add=-0.6)
    cv.paint(rim, color=BRONZE * 0.92, rough=0.7, height_add=3.0)
    cv.paint(dish, color=BRONZE * 0.55 + PATINA * 0.18, rough=0.8, height=-2.0)
    pitch = TAU / 16
    arc = ((dth + pitch / 2) % pitch - pitch / 2) * dr
    slot = cover(np.abs(arc) - 8.5) * cover(np.abs(dr - 86) - 52) * dish
    cv.paint(slot, color=VOID, rough=0.9, height=-9.0)
    cv.emission += (slot * 0.5)[..., None] * np.array([0.11, 0.45, 0.40], np.float32)
    hub = cover(dr - 26)
    cv.paint(hub, color=BRONZE * 0.95, rough=0.66, height_add=3.0 + dome(dr, 26, 3.4))
    cv.paint(cover(np.abs(dr - 10) - 1.2) * hub * 0.6, color=BRONZE * 0.4)

    # --- Pipe run: copper pipes with brass collars, between junction boxes -------------------------------------------------------
    PR = 36.0
    # pipes stop 6 px inside the junction box edge (box half size 86), so the box top stays flat
    runs = [("h", 760.0, 600.0, 1100.0, (640.0, 1050.0)), ("v", 1180.0, 840.0, 1190.0, (900.0, 1130.0)), ("h", 1270.0, 1260.0, 1660.0, (1330.0, 1560.0))]
    pipe_m = np.zeros((SIZE, SIZE), np.float32)
    pipe_h = np.zeros((SIZE, SIZE), np.float32)
    collar_m = np.zeros((SIZE, SIZE), np.float32)
    pipe_u = np.zeros((SIZE, SIZE), np.float32)
    for orient, fixed, a0, a1, collars in runs:
        if orient == "h":
            dperp = np.abs(wrap_delta(Y, fixed)) + 0 * X
            along = X + 0 * Y
            signed = wrap_delta(Y, fixed) + 0 * X
        else:
            dperp = np.abs(wrap_delta(X, fixed)) + 0 * Y
            along = Y + 0 * X
            signed = wrap_delta(X, fixed) + 0 * Y
        ext = cover(np.maximum(a0 - along, along - a1))
        m = cover(dperp - PR) * ext
        prof = 0.55 * np.sqrt(np.maximum(PR * PR - dperp * dperp, 0)) * ext
        for ct in collars:
            cm = cover(np.abs(along - ct) - 11) * cover(dperp - (PR + 9)) * ext
            cprof = 0.55 * np.sqrt(np.maximum((PR + 9) ** 2 - dperp * dperp, 0)) * ext
            collar_m = np.maximum(collar_m, cm)
            prof = np.where(cm > 0.02, np.maximum(prof, cprof), prof)
            m = np.maximum(m, cm)
        pipe_h = np.maximum(pipe_h, prof)
        pipe_m = np.maximum(pipe_m, m)
        pipe_u = np.where(m > 0, signed / PR, pipe_u)
    # contact shadow around the pipes, then the pipes themselves
    near = np.full((SIZE, SIZE), 99.0, np.float32)
    for orient, fixed, a0, a1, collars in runs:
        dperp = (np.abs(wrap_delta(Y, fixed)) if orient == "h" else np.abs(wrap_delta(X, fixed))) + 0 * X + 0 * Y
        along = (X if orient == "h" else Y) + 0 * X + 0 * Y
        endd = np.maximum(a0 - along, along - a1)
        near = np.minimum(near, np.hypot(np.maximum(dperp - PR, 0), np.maximum(endd, 0)))
    cv.albedo *= (1 - 0.35 * smoothstep(28, 0, near) * (1 - pipe_m))[..., None]
    pn = smoothstep(0.1, 0.9, noise(45, seed + 30) * 0.8 + 0.5 * pipe_u ** 2)
    shade = (0.72 + 0.28 * np.sqrt(np.maximum(1 - pipe_u ** 2, 0)))[..., None]
    copper = np.array([0.225, 0.164, 0.116], np.float32)
    pipe_col = (copper + (PATINA * 1.15 - copper) * pn[..., None]) * shade
    cv.paint(pipe_m, color=pipe_col, rough=0.74, height_add=pipe_h)
    streak = cover(np.abs(pipe_u + 0.42) * PR - 1.6) * pipe_m * 0.22 * (1 - collar_m)
    cv.paint(streak, color=[0.34, 0.27, 0.20])
    cv.paint(cover(np.abs(np.abs(pipe_u) * PR - PR) - 1.3) * pipe_m * 0.5 * (1 - collar_m), color=[0.035, 0.03, 0.028])
    cv.paint(collar_m, color=BRONZE * 0.92 * shade, rough=0.66)

    # --- Junction boxes and fixtures ------------------------------------------------------------------------------------------
    boxes = [(520.0, 760.0), (1180.0, 760.0), (1180.0, 1270.0), (1740.0, 1270.0)]
    half = 86.0
    bolt_pts = []
    for bx, by in boxes:
        bd = rrect_sd(wrap_delta(X, bx), wrap_delta(Y, by), half, half, 20)
        cv.albedo *= (1 - 0.4 * smoothstep(26, 0, np.maximum(bd, 0)) * (bd > 0))[..., None]
        bnoise = smoothstep(0.2, 1.0, noise(50, seed + 31 + int(bx) % 7) * 0.8)
        box_col = BRONZE * 1.02 + (PATINA * 1.3 - BRONZE * 1.02) * (bnoise * 0.45)[..., None]
        bm = cover(bd)
        cv.paint(bm, color=box_col, rough=0.72, height_add=7.0 * smoothstep(0, 11, -bd))
        cv.paint(cover(np.abs(bd + 22) - 1.3) * bm, color=BRONZE * 0.4, height_add=-0.8)
        cv.paint(cover(np.abs(bd) - 1.4) * 0.65, color=[0.03, 0.028, 0.026])  # inked outline keeps the box crisp against the plate
        cv.paint(cover(np.abs(bd + 6.5) - 1.0) * bm * 0.4, color=BRONZE_HI)
        for ox, oy in [(-58, -58), (58, -58), (-58, 58), (58, 58), (0, -62), (0, 62), (-62, 0), (62, 0)]:
            bolt_pts.append((bx + ox, by + oy))
    bd_, box_ox, box_oy = point_field(bolt_pts, 14)
    bolt = cover(bd_ - 8.0)
    cv.paint(cover(bd_ - 11.0) * (1 - bolt), color=[0.045, 0.04, 0.035], height_add=-0.4)
    cv.paint(bolt, color=BRONZE_HI * 0.85, rough=0.62, height_add=2.0 + dome(bd_, 8.0, 3.6))
    cv.paint(smoothstep(3.4, 0.3, np.hypot(box_ox + 2.2, box_oy + 2.2)) * bolt * 0.8, color=BRONZE_HI * 1.1)

    def polar(cx_, cy_):
        a, b = wrap_delta(X, cx_), wrap_delta(Y, cy_)
        return np.hypot(a, b), np.arctan2(b, a)

    # J1: cog hub
    r_, th_ = polar(520.0, 760.0)
    cogm = cog(r_, th_, 40, 11, 10, 7, 4.5, 0.3) * (1 - cover(r_ - 24))
    spokes = cover(np.abs(((th_ + 0.2 + np.pi / 5) % (TAU / 5) - np.pi / 5) * r_) - 4.5) * cover(r_ - 36) * (1 - cover(r_ - 8))
    cv.paint(cover(r_ - 56) * (1 - cogm) * 0.45, color=BRONZE * 0.4, height_add=-1.0)
    cv.paint(np.maximum(cogm, spokes), color=BRONZE * 0.95, rough=0.68, height_add=2.2)
    cv.paint(cover(r_ - 9), color=BRONZE_HI * 0.9, rough=0.62, height_add=2.0 + dome(r_, 9, 3.0))

    # J2: pressure dial
    r_, th_ = polar(1180.0, 760.0)
    face = cover(r_ - 44)
    cv.paint(cover(np.abs(r_ - 49) - 5), color=BRONZE * 0.95, rough=0.66, height_add=3.4)
    cv.paint(face, color=[0.038, 0.074, 0.074], rough=0.55, height=-1.2)
    cv.emission += (face * 0.35)[..., None] * np.array([0.10, 0.42, 0.38], np.float32)
    ticks = cover(np.abs((((th_ + np.pi) / TAU * 24) % 1 - 0.5) * (TAU / 24) * r_) - 1.0) * cover(np.abs(r_ - 35) - 5)
    cv.paint(ticks, color=[0.30, 0.36, 0.30], height_add=0.5)
    needle = cover(sd_segment(1180.0, 760.0, 1180.0 + np.cos(-0.9) * 30, 760.0 + np.sin(-0.9) * 30, 1.8))
    cv.paint(needle, color=[0.32, 0.30, 0.22], height_add=1.0)
    cv.paint(cover(r_ - 5), color=BRONZE_HI * 0.9, height_add=2.0 + dome(r_, 5, 2.0))

    # J3: set-screw cap
    r_, th_ = polar(1180.0, 1270.0)
    cv.paint(cover(r_ - 46), color=BRONZE * 0.82, rough=0.7, height_add=2.6)
    cv.paint(cover(np.abs(r_ - 40) - 1.2), color=BRONZE * 0.4, height_add=-0.8)
    screw_pts = [(1180.0 + np.cos(a) * 28, 1270.0 + np.sin(a) * 28) for a in np.linspace(0, TAU, 7)[:-1] + 0.4]
    sd2, sox2, soy2 = point_field(screw_pts, 10)
    cv.paint(cover(sd2 - 5.5), color=[0.05, 0.045, 0.04], height_add=-1.2)
    cv.paint(cover(r_ - 11), color=BRONZE_HI * 0.9, rough=0.62, height_add=1.5 + dome(r_, 11, 3.2))

    # J4: indicator lamp
    r_, th_ = polar(1740.0, 1270.0)
    cv.paint(cover(np.abs(r_ - 22) - 5.5), color=BRONZE * 0.95, rough=0.66, height_add=3.4)
    lamp = cover(r_ - 17)
    cv.paint(lamp, color=[0.09, 0.19, 0.16], rough=0.5, height_add=1.0 + dome(r_, 17, 5.0))
    cv.emission += (lamp * 0.9)[..., None] * np.array([0.14, 0.60, 0.50], np.float32)

    # --- Toothed valve wheel on the first pipe ------------------------------------------------------------------------------------
    r_, th_ = polar(850.0, 760.0)
    wheel = cog(r_, th_, 52, 12, 12, 7.5, 4.5, 0.2) * (1 - cover(r_ - 40))
    wspokes = cover(np.abs(((th_ - 0.5 + np.pi / 5) % (TAU / 5) - np.pi / 5) * r_) - 5.0) * cover(r_ - 44) * (1 - cover(r_ - 14))
    cv.albedo *= (1 - 0.35 * smoothstep(20, 0, np.maximum(r_ - 64, 0)) * (r_ > 64))[..., None]
    wheel_all = np.maximum(wheel, wspokes)
    cv.paint(wheel_all, color=PATINA * 1.3 + BRONZE * 0.3, rough=0.7, height_add=12.0)
    cv.paint(cover(r_ - 15), color=BRONZE_HI * 0.9, rough=0.62, height_add=12.0 + dome(r_, 15, 4.0))

    # --- Rivets along the plates ---------------------------------------------------------------------------------------------------
    def blocked(x, y):
        x, y = x % SIZE, y % SIZE
        for bx, by in boxes:
            if abs(x - bx) < half + 20 and abs(y - by) < half + 20:
                return True
        for orient, fixed, a0, a1, collars in runs:
            if orient == "h" and abs(y - fixed) < PR + 18 and a0 - 20 < x < a1 + 20:
                return True
            if orient == "v" and abs(x - fixed) < PR + 18 and a0 - 20 < y < a1 + 20:
                return True
        if np.hypot(x - dcx, y - dcy) < dR + 40:
            return True
        for px, py, pr in puddles:
            if np.hypot(x - px, y - py) < pr * 1.3:
                return True
        return False

    solid_pts, grate_pts = [], []
    for pid_, (ex, y0, w, h) in plates.items():
        if pid_ in grate_ids:
            grate_pts += [p for p in perimeter_points(ex, y0, w, h, 14, 120) if not blocked(*p)]
        else:
            solid_pts += [p for p in perimeter_points(ex, y0, w, h, 26, 190) if not blocked(*p)]
    for pts, radius, hgt in ((solid_pts, 9.5, 5.0), (grate_pts, 6.5, 3.4)):
        rd, rox, roy = point_field(pts, int(radius) + 6)
        rivet = cover(rd - radius)
        cv.paint(cover(rd - (radius + 3.0)) * (1 - rivet) * 0.8, color=[0.04, 0.036, 0.032], height_add=-0.5)
        rcol = BRONZE * 0.92 + (PATINA * 1.1 - BRONZE * 0.92) * (0.35 * P)[..., None]
        cv.paint(rivet, color=rcol, rough=0.66, height_add=1.0 + dome(rd, radius, hgt))
        cv.paint(smoothstep(radius * 0.38, 0.3, np.hypot(rox + radius * 0.3, roy + radius * 0.3)) * rivet * 0.75, color=BRONZE_HI * 1.05)

    # --- Fine detail: grain and scratches ---------------------------------------------------------------------------------------------------
    grain = noise(1.1, seed + 14) * 0.22 + noise(2.6, seed + 15) * 0.16 + noise(14, seed + 16) * 0.16
    cv.height += grain * (1 - seam) * (1 - 0.85 * puddle_mask)
    scratch = stamp_lines(110, seed + 17, (50, 190), 1.0, direction_bias=0.12) * (1 - seam) * (1 - puddle_mask)
    cv.paint(scratch * 0.28, color=[0.30, 0.24, 0.18], rough=0.7, height_add=-0.4)
    cv.rough += noise(70, seed + 18) * 0.02
    return cv.maps(1.0)


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
    rough = maps["roughness"]
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
    color = albedo * (sun * ndl[..., None] + ambient) + (spec * ndl)[..., None] * sun + emission * 0.9
    mapped = np.clip(color / (1 + color * 0.9), 0, 1) ** (1 / 2.2)
    tile = np.tile(mapped, (repeat, repeat, 1))
    PREVIEW_OUT.mkdir(parents=True, exist_ok=True)
    Image.fromarray((tile * 255 + 0.5).astype(np.uint8)).resize((2048, 2048), Image.LANCZOS).save(PREVIEW_OUT / f"{theme}_preview.png")
    rough_rgb = np.stack([rough] * 3, axis=-1)
    sheet = np.concatenate([np.clip(maps["albedo"], 0, 1), maps["normal"], rough_rgb, np.clip(maps["emission"] * 2, 0, 1)], axis=1)
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
        print(f"{theme}: floor textures written to {OUT / theme} (tile {TILE_METRES} m, {SIZE} px)")


if __name__ == "__main__":
    main()

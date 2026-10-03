"""Generate the seamless sci-fi arena floor texture set (albedo, normal, roughness, emission).

Run: python tools/build_floor_textures.py     (needs numpy and Pillow)
Output: assets/textures/floor/. One tile covers TILE_METRES square: 4x4 plates, each a seeded variant
(plain, vent grille, hazard band, hatch), with grooves, bevels, rivets, wear and glowing seam lines.
Everything is periodic, so the tile repeats without visible edges.
"""
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 1024
PLATES = 4
TILE_METRES = 6.4
OUT = Path(__file__).resolve().parents[1] / "assets/textures/floor"
rng = np.random.default_rng(2026)
plate = SIZE // PLATES  # 256 px, 1.6 m
yy, xx = np.mgrid[0:SIZE, 0:SIZE]
lx, ly = xx % plate, yy % plate
px, py = xx // plate, yy // plate
cx, cy = lx - plate / 2 + 0.5, ly - plate / 2 + 0.5
edge = np.minimum.reduce([lx, plate - 1 - lx, ly, plate - 1 - ly]).astype(np.float32)


def periodic_noise(sigma, seed):
    """Gaussian-blurred white noise via FFT, so it wraps seamlessly. Returned in [0, 1]."""
    noise = np.random.default_rng(seed).standard_normal((SIZE, SIZE))
    freq = np.fft.fftfreq(SIZE)
    fx, fy = np.meshgrid(freq, freq)
    kernel = np.exp(-2 * (np.pi * sigma) ** 2 * (fx ** 2 + fy ** 2))
    out = np.real(np.fft.ifft2(np.fft.fft2(noise) * kernel))
    out -= out.min()
    return (out / out.max()).astype(np.float32)


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


# Each plate picks a variant from a seeded table: 0 plain, 1 vent grille, 2 hazard band, 3 hatch.
variants = rng.integers(0, 4, (PLATES, PLATES))
variants[0, 0] = 0
variant = variants[py, px]

# --- Height (1 = plate surface, 0 = deep groove) -------------------------------------------------
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

# --- Albedo --------------------------------------------------------------------------------------
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

# --- Roughness (worn edges are shinier, plates satin) --------------------------------------------
roughness = 0.62 - 0.22 * wear + 0.12 * (scuff - 0.5)
roughness = np.where(vent & slat, 0.9, roughness)
roughness = np.clip(roughness, 0.25, 0.95)

# --- Emission: dim cyan lines along the tile seam, status dots, and vent glow ---------------------
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

# --- Normal map (OpenGL convention: +Y green = up in the image) ----------------------------------
STRENGTH = 5.0
dx = (np.roll(height, -1, 1) - np.roll(height, 1, 1)) * 0.5
drow = (np.roll(height, -1, 0) - np.roll(height, 1, 0)) * 0.5
normal = np.stack([-dx * STRENGTH, drow * STRENGTH, np.ones_like(dx)], axis=-1)
normal /= np.linalg.norm(normal, axis=-1, keepdims=True)


def save(name, array):
    OUT.mkdir(parents=True, exist_ok=True)
    data = (np.clip(array, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(data).save(OUT / name, optimize=True)


# Albedo and emission are authored directly in sRGB, like the colours they replace.
save("floor_albedo.png", albedo)
save("floor_normal.png", normal * 0.5 + 0.5)
save("floor_roughness.png", np.stack([roughness] * 3, axis=-1))
save("floor_emission.png", emission)
print(f"floor textures written to {OUT} (tile {TILE_METRES} m)")

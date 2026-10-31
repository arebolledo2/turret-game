# cp_laser-v1 notes

Iterations used: 5 of 8 (final = iter05, contract passes).

## What failed and fixes
- iter01: height 1.702 m (limit 1.7) and 17k triangles. Shortened tubes, resized body/ring/base proportions, cut bevel segments and revolve segment counts.
- iter02-03: crystal read as a pale flat disc (over-bright emission + alpha). Removed emission, made glass a thinner tint, added bigger gem facets with jittered icosphere.
- iter04-05: crystal core given metallic/low-roughness facets so the facets read; brass made more saturated; nozzle and tubes enlarged.

## Remaining flaws vs concept
- Crystal facets are subtler and less bright than the painted concept; no highlights/sparkle.
- Brass is a bit duller than the painted gold; no baked AO or hand-painted gradient.
- Teal body is a round barrel with a box rear housing rather than the slightly faceted barrel in the concept; yoke is a symmetric U-cradle (concept shows a single L-bracket on the visible side).
- Underside of the rear housing has two short cream tubes (invented).

## Counts
Triangles 6884 (target 5000, exceeded: smooth revolved/bevelled rings, faceted gem and rivet-free detail were kept for fidelity), 11 mesh objects (target 16), 8 materials (target 10).
Size 1.48 x 1.57 x 1.64 m, lowest point z = 0.

Self-score: 7/10.

# cp_resonance_engine-v1 notes

- Iterations used: 4 of 8 (final iteration 4 passes the contract; no failed checks, no advisory overruns).
- Final counts: 55,344 triangles, 31 mesh objects, 11 materials, 4 embedded 1024x1024 textures (paint detail, orange-peel normal map, brushed brass with segmented collar band, mint/violet gem atlas).
- Size 1.40 x 1.40 x 1.508 m, lowest point z = 0.0. Aim at (0,0,0.8) identity rotation carries housing, collar, rings, orb, crystals, ports, panel, vent, lugs; Muzzle is a bare empty under Aim at (0, 0.585, 1.2) on the front collar rim.

## What changed per iteration
1. First full build: passed the contract. Coral looked salmon, brass looked wood-grained, orb pale, housing too squat.
2. Raised collar/crown assembly by 0.11 m and taller ellipsoid housing (matches concept proportions), bigger port rings, bigger feet caps, calmer brass texture (less streak/banding), more saturated paints.
3. Darker coral with low clearcoat (gloss was washing it out), taller slab, larger side notch, taller spikes, more faceted orb.
4. Removed clearcoat from gems and deepened the mint so orb and jewel read green rather than white.

## Remaining flaws vs the concept
- Orb glow and soft bloom halo are missing (emissive is subtle); orb facets are coarser than the concept's gem.
- Brass top surfaces still show faint concentric banding from the texture gradient; seam lines on the collar are subtle.
- Base is simpler: no stepped teal ramp, only a dark notch plus lamp; teal disc is thin.
- Coral still slightly glossy/pale in the checker; no painterly shading baked in.
- Back vent and back ports are invented (mirrored ports, slatted vent).

## Self-score: 7 / 10

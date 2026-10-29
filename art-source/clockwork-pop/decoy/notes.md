# cp_decoy-v1 notes

Iterations used: 6 of 8 (final = 6, contract passed).

Final stats: 19,886 triangles, 15 mesh objects, 10 materials (advisory targets 5,000 / 16 / 10).
Size 0.893 x 0.875 x 1.643 m, min z -0.006. Nodes: Aim (pivot at z=0.5 on the vertical axis, identity rotation), Muzzle (bare empty under Aim, front of head).
The triangle overrun is deliberate: smooth lathe-built domes, torus-like bands, a helical spring and rivets. No degradation for budget.

## What failed / fixes
- It1: 49k tris, min z -0.029 (feet), height 1.70. Fixed feet; cut segment/corner counts.
- It2: contract passed but the model was too wide and squat (footprint 1.7 m vs concept ~0.5 width:height). Re-derived proportions from the concept in head-widths: narrower base/ring, taller spring, bigger lantern.
- It3: overshot (spring too long, head too small). It4: whole Aim assembly scaled 1.1x and lowered to shorten the spring.
- It5: bigger lens/thin brass rim, bigger bulb, deeper/more saturated colours, warmer cream. It6: narrower lantern cap (handles slant in), shorter head bowl.

## Remaining flaws vs concept
- Bumper ring reads as a flatter shelf with boxy blocks, not the soft tube band with rounded blocks; it is horizontal rather than dipping at the front.
- Left lens is the same bright purple as the right (concept left is near black); kept to hold the 10-material count.
- Bulb is emissive + translucent glass and reads as a pale cream blob in the checker (expected); no warm glow halo.
- No cage struts at front/back (concept shows only the two side handles; unseen sides invented as the same).
- Chrome spring has a flat grey look under the checker lighting; teal head slightly less glossy/saturated than concept.
- Base cream blocks are simple bevelled boxes; no baked AO or textures.

Self-score: 7/10.

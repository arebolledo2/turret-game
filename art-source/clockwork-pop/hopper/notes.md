# Rivet Hopper / eco_hopper-v1

Final harness iteration: **4 of 8**. Contract: **PASS**.

Created from scratch from the single concept, using only procedural geometry and four scripted 1024 x 1024 images. The silhouette is explicitly mechanical insect anatomy: round lens-bearing head, antennae, split red elytra, black segmented abdomen, two short forward stabilizers and two larger folded rear jumping legs. No canine anatomy, skeleton, armature, or external source assets.

## Final export

- `build_eco_hopper.py`: rebuilds, writes the four maps, saves packed source, exports GLB.
- `eco_hopper.glb`: self-contained candidate, **3,959,260 bytes**.
- `eco_hopper.blend`: packed editable source.
- **18,592 triangles, 15 mesh objects, 6 used materials** after GLB round trip.
- Bounds: **1.360 x 1.123 x 0.972 m**; lowest point **z = 0.004 m**; front +Y, up +Z.
- Four packed 1024 x 1024 base-colour images: clean red enamel, brushed dark carapace, brushed steel, and polar amber/teal lens depth. Gloss and metallic response use material settings. No normal/roughness images or AO bake.
- Required empty pivots: Body, Leg_L_0, Leg_R_0, Leg_L_1, Leg_R_1. Hip pivots carry upper geometry; child knee/ankle pivots provide rigid joint motion. Shell geometry sharing Body is merged into one mesh to reduce node count.

## Animation audit

`animation_audit.json` checks actual GLB binary samples and embedded images. No EcoHopper root node is animated.

| Clip | Duration | Channels | Endpoint difference |
|---|---:|---:|---:|
| Idle | 2.0 s | 15 | < 5e-18 |
| Walk | 1.0 s | 16 | < 3e-17 |
| Swim | 1.0 s | 16 | < 3e-17 |
| Attack | 0.8 s | 16 | < 5e-33 |

Idle sways the antennae with a small body bob. Walk uses alternating articulated legs with bent-knee recovery; Swim is an additional compatible copy of the in-place cycle required by the generated subject contract. Attack compresses the rear mechanism and pitches the body before returning to rest. Loop endpoints agree numerically. glTF has no general looping flag; the parent must set Idle/Walk/Swim looping after Godot import. Attack should remain a one-shot. There is no locomotion/root translation; only small local Body bob/compression.

## Iterations and fixes

1. Passed contract. Found intersecting flat turquoise inlays, excessively round feet, an unnecessary split into 18 objects, and a risk of stale parent matrices during pivot creation.
2. Build failed after foot work: a polygon loop reused the hip-pivot variable. No final export was produced by this iteration.
3. Fixed variable collision; conformed turquoise inlays to the wing curvature, added transverse wing seams, replaced rounded toes with bevelled pointed mechanical tarsi, updated parent matrices before assigning pivots, consolidated stationary body components. Passed.
4. Changed the visible collar to graphite and added dorsal steel vent details plus small brass facial studs. Passed. Inspected final five-view comparison.

## Judgment and limitations

Self-score: **7.5 / 10**. Strong insect silhouette and clear concept palette, but still a cleaner and more schematic toy-like interpretation than the reference. Rear legs are intentionally larger to fulfill the jumping-leg request. Face and shell construction are simpler than the reference's irregular cast plates; hind abdomen and underside are invented from the one view. Feet and hinges use simpler machinery, and the body has less nuanced painted reflection than the illustration. No optical transparency, fine normal relief, or baked ambient occlusion. The Walk is a cosmetic rigid cycle: no inverse kinematics, planted-foot constraints, collision response, or game locomotion synchronization. Some foot sliding is expected. Godot import/playback and gameplay-camera verification are delegated to the parent as directed; this run did not write to the game.

The 10,000 triangle target is exceeded to retain smooth large surfaces, circular optics, seam borders, steel rings, and exposed spring coils. Mesh/material/texture targets are satisfied. Crowd optimization and performance measurements have not been performed.

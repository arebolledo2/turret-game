# Clockwork Puppet — eco_puppet-v1

Completed in **3 of 8 allowed harness iterations**. Final contract passes in `renders/iter03/validate.json`.

This is an independent compact support minion: domed ivory porcelain skull with cheek lobes and inset rose eyes, glossy plum chest and limb casings, brass joint caps, exposed graphite/steel mechanisms, a brass winding key on the back, simplified mitten claws and oversized boots. Rose optics follow the written brief; the supplied reference has turquoise optics. Head and boot proportions are intentionally larger than the reference's taller humanoid proportions.

## Iterations and fixes

1. First build passed every contract check, exported the required clips plus Walk, and embedded all four generated textures. It used 21,565 triangles. Inspected the full comparison sheet: recognizable mechanical toy, but the neck/joint construction had unnecessary tessellation and the nose vent sat partly inside the mask.
2. Reduced small cylinder and sphere tessellation, simplified torus cross sections and eliminated unnecessary bevels on fine detail. Result: 14,205 triangles with the same 10 rigid mesh groups and 7 materials. Moved the nose vent onto the face. Inspected comparison again; silhouette and polished material highlights were retained.
3. Corrected the nose vent winding, enlarged the head about 16% horizontally and 7% vertically, and enlarged the boots to emphasize the chibi minion direction. Final neutral bounds and pivots pass. Inspected the final `compare.png` critically.

## Final measurements

- Triangles: **14,205** (soft advisory target 5,000 exceeded).
- Mesh objects: **10** (all disconnected components that move together joined per rigid pivot).
- Materials: **7**.
- Packed procedural images: **4 × 1024 × 1024** — plum enamel, ivory porcelain, brushed brass and machined graphite.
- Dimensions: **0.612 × 0.339 × 0.898 m**. Lowest point **z = 0.006 m**.
- Required pivots: Body, Head, Arm_L, Arm_R, Leg_L, Leg_R. Extra Elbow_L/R and Knee_L/R allow actual rigid segment articulation.
- Named clips: Idle **2.4 s**, Walk **1.0 s**, Swim **1.6 s**, Attack **1.1 s**.
- Binary audit confirms actual varying transform channels in all four clips, matching first/last transform samples, no root channels, four embedded images and no external image URIs. Attack returns to its resting pose. See `animation_audit.json` and `audit_glb.py`.

The triangle overrun buys smooth ceramic/enamel silhouette and rounded joint hardware, toes, brassy eye rims and readable claws. It was reduced 34% after the first comparison. Geometry/material complexity remains a provisional visual candidate, with performance optimization deferred until acceptance.

## Remaining limitations

The provided concept's faceted panel details, some fine gold shell fasteners, antenna and dangling finger cables are simplified; the winding key replaces the antenna as the back silhouette feature requested by the brief. Surface textures deliberately stay subtle on this clean toy, so the visual richness primarily comes from controlled gloss, separate materials and geometry. The supplied single view leaves the back invented. Compared with the concept, the skull remains rounder and the arm shoulders more spherical.

Godot integration, playback verification and the animated preview are delegated to the parent task; this run did not modify the game. The export has been validated and rendered through the Blender harness, and animation samples were inspected directly in the exported GLB.

Self-score: **8/10** for a polished smaller puppet in the requested clockwork family; **7/10** for literal single-view likeness because of the intentional chibi/rose/winding-key deviations and simplified panel construction.

## Artifacts

- `build_eco_puppet.py` — deterministic from-scratch Blender builder.
- `eco_puppet.glb` — self-contained game candidate.
- `eco_puppet.blend` — packed editable source.
- `renders/iter03/compare.png` — reviewed final reference + five views.
- `renders/iter03/validate.json` — passing contract and advisory counts.
- `animation_audit.json` — exported animation/root/image audit.

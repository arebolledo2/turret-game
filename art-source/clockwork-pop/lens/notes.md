# eco_lens-v1 — independent Prism Lens satellite

Final candidate: `eco_lens.glb`; source: `build_eco_lens.py` and packed `eco_lens.blend`.
Final comparison inspected directly: `renders/iter03/compare.png`.

## Iterations and corrections

3 harness runs used of the permitted 8. All three passed the contract.

1. Built a separate shallow optical satellite rather than reproducing the reference parent boss. Preserved the reference's violet enamel, pale ceramic, satin gold and large faceted pink-violet aperture. The initial fin inserts faced mainly backward and the crystal was too subdued.
2. Brightened the procedural crystal palette and extended ivory panels to both fin faces. The comparison exposed intersections from the original nonplanar fin faces.
3. Made each swept fin and its inset panel planar on matched parallel planes. The final front, three-quarter, side, rear and top images were inspected. The two ceramic fins now read cleanly and separately, with thin violet borders.

## Final statistics

- Contract: **PASS**, no failed checks or missing required nodes.
- Triangles: **7,760**; mesh objects: **15**; materials: **6**.
- Dimensions XYZ: **1.069 × 0.535 × 0.686 m**; lowest point **z = 0.147 m**.
- 4 generated **1024 × 1024** packed images: ivory ceramic, satin gold, violet enamel, rose-violet crystal. All 15 mesh primitives have UVs; consistent 0.48m material projection density is used for the hardware and dedicated aperture projection for the crystal.
- GLB: **1,842,036 bytes**, all images and buffers embedded, no external references.
- Advisory triangle target exceeded by 2,760. Tessellation is spent on smooth concentric gimbal rims, rounded optical housing, swivel joints and bevelled ceramic fin edges. Other advisory budgets are met. Performance was not measured.

## Exported rigid animation audit

`audit_glb.py` parses the actual binary export and writes `export_audit.json`; it ran successfully after the final evaluation.

| Clip | Duration | Actual animated parts | Endpoint return |
| --- | --- | --- | --- |
| Idle | 2.0 s | Fin_L, Fin_R, Gimbal rotations | Exact |
| Walk | 1.333 s | Fin_L, Fin_R, Gimbal rotations | Exact |
| Swim | 1.6 s | Fin_L, Fin_R, Gimbal rotations | Exact |
| Attack | 0.8 s | Fin_L, Fin_R, Gimbal rotations; RearEmitter scale | Exact |

Satellite root and Body have **no animation channels**. All clips start in neutral/rest pose and return to it. Idle, Walk and Swim are periodic sequences. Required Body, Fin_L and Fin_R empties each carry their own meshes; Muzzle is a bare empty under Body at the forward aperture. No skeleton/armature is present. Attack is intended as a one-shot. Clip loop flags and Godot playback still need the parent integration pass.

## Remaining differences and judgment

The reference is the parent conductor, so this deliberately follows the independent satellite design specified by the brief: no crown, arms, boss torso or leg-like supports. The unseen rear is invented as a shallow violet dome with a tiny emitter. The crystal is opaque, polished and physically faceted, with a procedural rose-violet mosaic; it lacks the reference's warm translucent depth and caustics. The ceramic and gold surfaces use clean, restrained base-colour textures rather than dedicated roughness/normal maps. The small panel variation is subtle at gameplay distance. There is no baked AO. The fins are angular paddles with bevelled edges rather than fully organic sculpted surfaces.

Honest self-score: **8/10** for the brief's independent support asset. The lens, ring structure, palette and separated fins read clearly, with a valid compact stationary-root export. Godot playback and game-camera judgment are delegated to the parent; no game files were touched.

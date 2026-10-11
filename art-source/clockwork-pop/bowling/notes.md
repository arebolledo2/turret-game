# Clockwork bowling candidate — frozen iteration 5

Built from the supplied single reference using scripted Blender geometry. Five harness runs used; final iteration passes the local contract and the explicit bowling marker audit. Only this run folder was written.

Final asset: `cp_bowling.glb`; packed editable source: `cp_bowling.blend`; rebuild source: `build_cp_bowling.py`. Frozen hashes and counts are in `freeze.json`. Reviewed contact sheet: `renders/iter05/compare.png`.

## Final measurements

- 11,588 triangles; 12 mesh objects; 8 used materials.
- Bounds: 1.217 m wide × 2.190 m deep × 1.420 m tall; lowest point z = 0.000 m.
- No image textures, armature, animations, cameras, or lights in export.
- Identity `Aim` pivot at the centered base axis. Entire housing, side fittings, ball and continuous ramp belong to Aim; coral plinth is static.
- `LoadedBall` is one independent mesh with three actual drilled finger bores, dark bore walls, and glossy resin exterior.
- Bare `Muzzle` is nested under Aim, identity forward +Y, at Blender (0.000, 1.500, 0.240) m, near the ramp's forward bound y = 1.541 m.

## Iteration findings

1. Initial construction had the recognizable arched teal return, brass lane, coral base and concentric purple side lenses. The generic checker failed muzzle height because it hardcodes z > 0.3 m, conflicting with the bowling brief's approximately 0.2 m launch. Initial detail was 15,630 triangles.
2. Parent approved a local contract exception: disable the generic muzzle flag and explicitly audit the approved 0.15–0.30 m launch range, forward exit, bare marker, hierarchy, base origin and identity aim rotation. Darkened turquoise, enlarged base around its axis, added rounded swept opening cheeks, and simplified hidden/small fittings. Passed at 11,536 triangles.
3. Tested a union of housing, cheeks and rear cap. Contract passed but overlapping bevel constraints flattened the outer moulded edges, worsening appearance.
4. Tested bevel cleanup with unclamped overlap. This created exaggerated concave edge geometry below ground, failing height and ground checks. Rejected.
5. Restored the clean rounded assembled shell and cheek construction, enlarged drilled finger holes and darkened their internal surfaces. Final image reviewed; contract and explicit imported-GLB audit both pass.

## Budget and remaining limitations

The 5K triangle count is an advisory target. Smooth ball curvature and physical bores, rounded enamel surfaces, lens domes and concentric fittings justify the extra geometry for this visual candidate. Mesh/material counts remain below targets. No crowd performance claim has been made.

Fidelity self-score: **7.7/10**. The main silhouette, colors and moving-part contract are present. The assembled cheek panels and rear shell retain visible seams compared with the reference's more continuous moulding. The reference has warmer, richer studio reflections and subtly mottled bowling resin; the candidate uses solid materials. The ball protrudes somewhat farther from the opening, and the unseen rear service hatch and mirrored second lens are plausible inventions. Finger holes become small at a distant camera; the larger physical bores improve readability. Godot visual/gameplay review is handled by the parent task after promotion.

## Validator exception

`contract.json` intentionally sets `muzzle_forward: false` because the shared generic validator requires z > 0.3 m. It retains all other common checks and `origin_node: Aim` for the genuinely asymmetric ramp footprint. `audit_bowling.py` imports the actual exported GLB and checks the stronger bowling-specific facts; its passing output and exact export/builder SHA-256 hashes are saved in `bowling_contract_audit.json`. This is an explicit approved launch-height exception, not an unchecked marker.

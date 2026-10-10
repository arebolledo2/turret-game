# Skipper Moth — frozen candidate

Final export: `cp_fast.glb`; packed source: `cp_fast.blend`; deterministic standalone builder: `build_cp_fast.py`.
Final inspected comparison: `renders/iter04/compare.png`. Parent visually accepted iteration 4.

## Validation and complexity

- Four harness iterations. Final iteration 4 passes every contract check.
- 9,192 triangles, nine mesh objects, seven materials, four embedded 1024×1024 images, zero animation clips/tracks.
- Imported rest dimensions: 1.338 × 0.906 × 1.023 m. Lowest point z = 0.167 m.
- Root `SkipperMoth` stays at ground origin. `Body` is at z = 0.635 m and carries five joined body meshes plus `Wing_L` and `Wing_R` hinges.
- Each wing hinge carries two meshes: one forewing and one hindwing. Both hinges have identity rest rotation and unit scale. Geometry encodes the rest silhouette; no mesh object rotation is needed on those wing children.
- Above the 5K advisory target to retain round head/optic, brass details and rounded solid wing outlines. Within the requested 5–10K provisional polish range and below mesh/material advisory targets.

## Wing contract and measured clearance

`Wing_L` is the +X wing: local Body position `(0.102, -0.070, 0)` in Blender coordinates. `Wing_R` is the -X wing: `(-0.102, -0.070, 0)`. These labels describe screen-left/right in the harness front view. Both are parented to `Body`.

Flap about **Blender local Y**, which becomes **glTF/Godot local Z** with `export_yup=True`; model forward becomes Godot -Z. Opposite signed angles produce symmetric wing motion. The membranes are mostly in the XZ plane at rest, with slight rear sweep, so the motion sweeps their radial silhouette.

Read-only import/sweep audit: `audit_cp_fast.py` and `export_audit.json`. Sampling mirrored hinge motion from -25° to +25° in 1° steps gives:

- Both wings stay above z = **0.320786 m**; the body/tail remain the lowest part at z = 0.167 m.
- Swept outer width can reach **1.653692 m**, versus the rest width of 1.338 m. The supplied contract validates the rest pose. Integration should choose amplitude with crowd spacing in mind.
- Swept wing maximum z = 1.357634 m. Wing root position remains fixed throughout.
- This is a geometric ground/extent audit, not collision detection against the body. Near-root overlap within brass bearings is intentional.

## Appearance and surfaces

Coral head and swept segmented abdomen, large violet convex optic, brass belly/bands/feelers, small top rivets and dark split tail. Paired large mint forewings and smaller cream-edged hindwings have rounded silhouettes and 14 mm real thickness. Simple body geometry is joined by material.

All four images are generated in the builder with seeded numpy operations, saved beside it, packed in the Blend, and embedded in the GLB. Body finishes share an atlas. Dedicated forewing/hindwing images supply pale borders, teal root-to-tip variation and fine fan veins. The optical image supplies violet colour bands and painted highlights. Every mesh has UVs.

Wings use opaque pearl materials for clear silhouettes against the game background and to avoid overlapping alpha layers. They suggest the concept's milky translucency through colour, but do not transmit the background. No smoke trails.

## Iterations and fixes

1. Passed contract at 8,952 triangles. Wing centers showed unwanted loop-like shading artifacts despite clean generated images.
2. Corrected the global winding from each outline's signed area and added brass wing-root bearings, reaching 9,192 triangles. Artifacts persisted.
3. Flattened membrane surfaces, removed specular glare and deepened the violet optic. Artifacts persisted, demonstrating they were not painted or caused by reflections.
4. Found the actual defect: radial ring quads were oriented opposite to the center fan triangles. Corrected quad ordering for both wing surfaces and the optic. Inspected every view: loops are gone, with clean subtle vein shading. Parent accepted this version.

## Limitations

- Forewing shapes are smoother and simpler than the painting's asymmetric lobes. The model is symmetric; perspective produces the expected apparent asymmetry.
- Opaque wing treatment replaces real translucency. Wings are thin from a strict side or top view; gameplay readability and motion remain parent integration checks.
- Body and eye appear softer/paler under the harness lighting than in the illustration.
- No baked ambient occlusion, normal/roughness maps or animation clips. Parent owns Godot import, flap/hover controller, collisions and crowd review.
- No game files were touched.

Self-score: **8/10**. Recognisable four-wing moth silhouette, palette and mechanical details with an efficient three-pivot structure.

Frozen GLB SHA-256: `c2a03c39e7d109d6f1faa252e6c2697b576cf8e8938024706d574d5635d88107`.

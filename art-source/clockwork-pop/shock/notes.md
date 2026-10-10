# Resonance Bell — frozen candidate

Final model is frozen at **iteration 3 of 8 allowed**. All three harness iterations passed the contract. Final front, three-quarter, right side, back and top renders were inspected against the selected concept.

## Files

- `build_cp_shock.py`: deterministic standalone Blender Python source, factory-empty startup, procedural geometry and generated image pixels.
- `cp_shock.blend`: editable packed source containing all images.
- `cp_shock.glb`: self-contained final export, metre scale, Y-up glTF export from Blender Z-up construction.
- `bell_color_atlas.png`, `bell_orm_atlas.png`, `bell_micro_normal.png`, `bell_amber_fire.png`: the four generated 1024×1024 images.
- `renders/iter03/compare.png`: final reference plus five-view comparison; individual full renders are adjacent.
- `renders/iter03/validate.json`: passing final contract report.
- `build_stats.json`, `export_manifest.json`: exact geometry counts, pivot positions, file sizes/hashes and self-contained GLB integrity.

## Final counts and transforms

- **9,078 triangles / 11 mesh objects / 8 materials / four embedded 1024×1024 images.**
- Bounds **1.054 × 1.054 × 1.204 metres**, minimum Z **0.015m**; bounds horizontally centred at **(0,0)**.
- `Aim`: bare empty at **(0,0,0.18)m**, identity rotation and scale, pivot on the turret vertical axis. All upper bell/crown structure is parented below Aim.
- `Muzzle`: bare empty nested directly under Aim, local position **(0,0,1.01)m**, world position **(0,0,1.19)m**, identity rotation and scale. This is the central crown marker for radial discharge, not a directional muzzle.
- Static foundation and three feet remain outside Aim. No armature, skeletal deformation, animation clips, pulse mesh, cameras or lights in the export.
- The parent corrected the initial subject contract's directional `muzzle_forward` check to false to match the radial central-crown requirement. This agent made no harness/config/game changes.
- Triangle count exceeds the advisory 5,000 target. The larger count supports clean circular silhouettes, a real hollow bell interior/clapper, two smoothly shaped enamel sections, rounded torus trims, crown socket and three rounded brass feet. Iteration 2 selectively reduced rotational tessellation from 10,634 to 9,078 triangles. Mesh/material/texture targets are met.

## Iterations and fixes

1. Complete bell, static base, support feet, brass/coral collar, faceted crystal, crown socket and runtime pivots. Contract passed at 10,634 triangles. Render showed two accents sitting inside adjacent surfaces: the lower brass trim was buried in the bell mouth, and socket plum panels were mostly buried. Crystal appeared too small and dull under checker lighting.
2. Exposed the lower brass trim and socket panels, enlarged crystal width/height, softened enamel roughness, reduced circular tessellation and opened the hollow bell underside properly. Contract passed at 9,078 triangles. The crown was clearer, but retained an overly uniform pale peach appearance.
3. Added explicit cylindrical crystal UVs and a vertical golden-heart/deep-orange-tip texture/emission gradient, retaining two sparse cream glint facets. Contract passed with unchanged geometry counts. Final renders were inspected and accepted locally.

## Surface treatment

Clean teal porcelain enamel, coral lacquer, warm brass brushing and dark slate/plum base match the concept's material regions. Procedural colour, metallic/roughness, micro-normal and amber emission images are generated from a fixed seed and embedded by glTF. Colourspace is assigned before pixel upload. Existing active primitive UV maps are reused, every mesh has UVs, all box projections use the same metre-to-UV density and padded material atlas cells; the jewel receives a deliberate cylindrical projection to control its fire gradient. No downloaded images, external models, generic grime or baked Cycles textures are used.

The bell underside is dark and recessed with a brass clapper. Unseen rear/underside construction is invented sensibly from the single concept view. Parent owns Godot import, runtime pivot animation and final in-engine appearance verification.

## Limitations and self-score

The amber crown is a stylized opaque faceted gemstone with a luminous golden heart; it does not reproduce the concept's complex clear-glass refraction. Its silhouette is more regular than the illustrated irregular crystal. Checker lighting makes the teal/brass finish smoother and less painterly than the selected concept. Brass trims are geometrically clean, while the concept has richer broad warm highlight bands. Three support feet were inferred from the visible reference. Fine procedural brushing is subtle at gameplay distance. No in-engine or frame-time claims are made by this agent.

Honest self-score: **7.7/10** for reference fidelity. Strong recognizable bell/crown silhouette and palette, proper playable pivots, self-contained textures and efficient rigid grouping; the crystal optics remain the main visual gap.

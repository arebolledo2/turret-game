# Prism Conductor candidate

Final export: `eco_prism.glb`; reproducible source: `build_eco_prism.py`; editable packed source: `eco_prism.blend`.
Final reviewed comparison: `renders/iter04/compare.png`; contract report: `renders/iter04/validate.json`.
Binary-level audit source/result: `audit_glb.py` / `animation_audit.json`.

## Iterations and fixes

Four harness evaluations used (maximum eight). Iteration 1 passed the contract at 59,914 triangles, eight meshes and 15 materials. The first gem/eye material assignment was visually too busy, side eyes and claw pads too small, gold too bronze, and small components used too much tessellation. Iteration 2 broadened and brightened the gem, increased lens/mitten/crown sizes, reduced ring/sphere/bevel tessellation, corrected consistent outward crystal normals, and reduced used materials to 14. Iteration 3 failed before construction due to an indentation error in the final deliberate facet-color assignment. Corrected the indentation and checked Python compilation before evaluation 4. Evaluation 4 passed every contract check; final concept/front/three-quarter/right/back/top comparison inspected directly.

## Final counts and dimensions

- 37,694 triangles; eight rigid mesh assemblies; 14 used materials.
- 1.539 x 0.877 x 1.463 metres in Blender X/Y/Z; lowest point Z=0.155m.
- Body stationary at the origin; forward Blender +Y. Lens_L, Lens_R, Crown and Muzzle present, with Muzzle a bare marker. Claw_L/R and Thruster_L/R are extra rigid pivots.
- Four 1024 x 1024 procedural atlases: `prism_surface.png`, `prism_orm.png`, `prism_normal.png`, `prism_emission.png`. Surface/roughness/metallic/normal/emission maps are wired to exported Principled materials; every primitive has TEXCOORD_0, every image is embedded, and the GLB has no image URI dependencies.
- GLB 2,661,572 bytes. No skins or skeletons. Eight mesh assemblies deliberately consolidate geometry that moves together.
- Advisory triangle target exceeded by 17,694. Polished rounded gold housings, sphere silhouette, numerous ceramic/gold bevels and retaining rings account for the extra geometry. Other advisory targets met. Boss-candidate appearance was prioritized; no crowd/performance claim is made.

## Animation audit

Idle 4.0s / eight transform channels; Walk 1.2s / eight; Swim 2.0s / eight; Attack 1.2s / ten. All have actual changing rigid transforms. Binary accessor inspection verifies endpoint agreement within 1e-5 for every channel, and no animation channel targets the stationary Body root. Attack returns to rest. Idle/Walk/Swim have seamless endpoints; glTF does not encode playback loop behavior, so runtime should loop those and play Attack once. Walk is a hover glide with claw/thruster motion, not a legged gait.

## Visual limitations and judgment

Self-score: 7.8/10. The large peach optic, white metal/ceramic rim, round lavender shell, gold satellite lenses, violet three-point crown and lower claw pods read clearly. The unseen back is an invented restrained service hatch with radial cooling slots. The front gem is a stylized solid faceted optical crystal rather than physically accurate refractive glass. Side optics likewise use a glossy blue optical coating rather than expensive overlapping transparency. Crown facets are sharper and claw pads more mechanical than the softly sculpted reference; no sculpted imperfections or baked ambient occlusion were added. Gold and violet are cleaner and less painterly than the image. The fixed checker camera leaves more padding around this broad hovering model than the concept illustration.

No game files were read beyond the explicitly allowed helper source; no game files were modified or launched. Godot import/playback and gameplay-distance preview remain for the parent task, as stated in the brief. No performance tests conducted.

# Fanmouth Scattergun — cp_scatter-v1

Final accepted and frozen iteration: **04**. Four harness iterations used out of eight.

## Construction and usability

Generated from scratch in Blender 5.2.1. The broad teal receiver has a separate raised center roof panel, rounded turquoise side rails, recessed blue teal side plates, and a chamfered coral mounting casting. The two machined brass barrels have continuous physical bore walls, recessed dark caps, heavier breech collars, center bands and beveled muzzle rims. Each barrel angles outward by 4 degrees (8 degrees included spread). Symmetrical coral side ports, brass recessed sockets, a graphite rear service cap, short rear vents and restrained rounded bolts complete the invented unseen side.

The static floor plate is centered at XY origin and rests at Z=0. Aim is an identity-rotation empty at (0,0,0.61), carrying the complete rotating head. Muzzle is a bare Aim child at world (0,1.04,0.935), facing +Y. Barrel_L and Barrel_R are separate mesh objects with origins at their respective breeches, suitable for recoil translation. No armature, animation, external images, or image textures. All 10 PBR materials are embedded in the GLB.

## Iteration record

1. Contract passed; 20,232 triangles / 14 mesh objects / 10 materials. Visual inspection caught a Blender transform update issue: the cylinder rotation had not refreshed before parent-preserving matrix capture, so side ports and front bolt pockets appeared horizontal. The top seams were too faint, enamel pale, barrels short.
2. Contract passed; 13,508 triangles / 14 objects / 10 materials. Updated transforms before parenting, introduced the separate center roof to expose longitudinal grooves, lengthened barrels, strengthened enamel colors and reduced small-part cylinder/sphere tessellation. Circular details now align correctly.
3. Contract passed; 12,484 triangles / 14 objects / 10 materials. Added heavier breech collars, split sharp barrel-ring normals to prevent smeared highlights, strengthened coral/teal saturation and simplified minor fasteners further.
4. Contract passed; same visual geometry and counts. Set both barrel object origins at their breeches for useful independent recoil; exported and personally reviewed final compare.png across all five views.

## Final measurements

- 12,484 triangles, 14 mesh objects, 10 used materials.
- Overall bounds: 1.140 m X × 1.824 m Y × 1.357 m Z.
- Ground minimum: 0.000 m. Bounds XY center: (0.000,0.118) m. Static base and Aim axis at XY=(0,0).
- All automated contract checks pass. No textures and no animation clips.
- Advisory triangle target exceeded: 12,484 versus 5,000. Extra triangles retain rounded rail/casting bevels, physical deep bores and collar contours, and broad smooth circular floor ears/ports. Objects and materials remain within their advisory targets. This is a visual acceptance candidate; crowd performance has not been measured.

## Remaining limitations and self-score

**Self-score: 8/10.** The silhouette, main colors, chunky bevels, hollow twin barrels and pedestal match the concept well. The checker illumination gives paint and gold a more muted look than the saturated painterly reference. Main barrel highlights are simpler, the side inset is more rectangular, and the front casting is a cleaner octagon. The original's hand-painted brush variation and localized highlight dots are not reproduced. The single concept view does not establish rear geometry, so the rear cap/vents and mirrored side ports are sensible inventions. No ambient-occlusion bake. No Godot import/playback or gameplay-distance review was performed, as this task prohibits game edits.

## Frozen artifacts

- frozen/iter04/build_cp_scatter.py: reproducible source.
- frozen/iter04/cp_scatter.blend: editable Blender source.
- frozen/iter04/cp_scatter.glb: final self-contained export.
- frozen/iter04/validate.json and subject.json: measured contract and specification.
- frozen/iter04/sha256.json: source/export hashes.
- renders/iter04/compare.png: personally reviewed concept + five-view comparison.

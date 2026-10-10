# Keepsake Cache — final candidate

Final export frozen at harness **iteration 4 of 8 allowed**. Every iteration passed the size/pivot/texture contract; iteration 1's material appearance was unacceptable and was corrected before acceptance.

## Deliverables

- `build_cp_dropbox.py`: standalone deterministic Blender 5.2 build; starts from factory-empty scene, generates all texture pixels, builds the closed model, saves packed source and exports GLB beside the script.
- `cp_dropbox.glb`: self-contained final model, +Y front / Blender +Z up, metre units, export Y-up.
- `cp_dropbox.blend`: packed source containing every material image.
- Four generated 1024×1024 PNG atlases: base colour, ORM, micro-normal and restrained amber emission.
- `renders/iter04/compare.png` and the five individual views: inspected final geometry, palette, seam and unseen faces.
- `renders/iter04/validate.json`: final harness contract report.
- `export_manifest.json`: frozen exact file sizes, hashes and export integrity inspection.

## Final measurements

- **12,524 triangles, 11 mesh objects, 8 used materials, 4 embedded 1024×1024 images.**
- Bounding dimensions: **1.215 × 1.111 × 1.035 metres**. Lowest geometry **z=0.025m**. Bounds centre XY **(-0.030, 0.031)m**.
- Empty `Body` is at **(0, 0, 0.53)m**, parenting every rigid assembly. Its transform remains unrotated. File origin remains the ground-centred coordinate origin.
- No armature or animation. Lid, latch, carry handle and optic remain separate rigid mesh assemblies; all currently belong under Body. Runtime use can reparent the assembly that needs motion.
- Triangle target of 5,000 is advisory and exceeded. Compared to iteration 1's 19,176 triangles, small rivets, raw-profile edge bevels and cylinder edges were reduced. Remaining triangles preserve smooth enamel corners/lips, solid shaped brass wraps/crowns, dome rivets, rounded optic seating and rectangular carry handle edges. Object/material/texture targets are met.

## Iteration record

1. Built complete model and textures; contract passed at 19,176 triangles. Render revealed incorrect cube atlas sampling and displaced sampling on raw custom geometry. Blender stock primitives retained an existing active UV layer while the projected layer was newly created and inactive; the wrong UV set reached glTF. Raw-geometry UVs also needed bounding-centre normalization.
2. Reused the active UV layer, centred custom-mesh projection before atlas placement, and recalculated mirrored corner normals. Full palette was correct; contract passed. The brass top wraps still looked like open hooks and detail tessellation was excessive.
3. Added solid shaped gold crowns to all four upper corners, strengthened teal/coral saturation and reduced minor-edge tessellation. Contract passed at 11,964 triangles. The all-edge body bevel still exposed too much dark gasket around the seam.
4. Replaced the primary solid body, gasket and lid with rounded-rectangle extrusions and controlled shallow horizontal bevels. This keeps the round vertical silhouette while tightening the seam. Final contract passes at 12,524 triangles; front, three-quarter, side, rear and top were inspected.

## Appearance and remaining limitations

Reference identifiers preserved: rounded teal enamel chest, **solid closed cream inset lid**, continuous dark seam, eight brass corner wraps, coral button latch with teardrop tongue, purple recessed amber optic, coral/brass side carry handle, small domed rivets. Rear hinges and underside are sensible invented details from the single provided view. A full closed cream slab occupies the lid inset, so this is not an open bin or a tray with a missing floor.

Every mesh has box-projected UVs with the same metre-to-UV density, placed in padded per-material atlas cells. Clean enamel/lacquer gets faint broad tonal and roughness variation; brass receives restrained fine brushing. No imported imagery and no generic dirt/grime. Metallic/roughness, normal and jewel-emissive maps export as glTF textures. The atlas borders remain intentionally padded to avoid material bleeding.

The final checker is less saturated and painterly than the reference's illustrative lighting. Brass crowns are flatter/more machined than the concept's broad organic bulges. Amber reads as a jewel dome with restrained emissive fire and sculpted glints; it does not reproduce the reference's intricate amber optical refractions. Front latch/side handle are recognisable at the checker scale; fine brushing will be subtle at gameplay distance. A single-view reference means unseen sides are necessarily invented. No game integration or in-engine appearance was tested by this agent; the parent owns that stage.

Honest self-score: **7.8/10** for concept fidelity; clean completed asset, with strong palette/silhouette/detail identifiers and remaining differences in sculptural brass curvature and jewel optics.

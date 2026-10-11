# Clockwork Crossfire — cp_crossfire-v1

Final candidate: iteration 3. Three of the eight allowed harness runs were used; all three passed the required contract. The final comparison image and every final view were personally inspected before freezing the export.

## Iteration changes

1. Constructed the rounded teal housing, four coral collars, four genuinely hollow brass tubes, ivory square bezel, broad mint crystal facets, pedestal and circular foot. All four barrels move together under an identity-rotation Aim. Added bare Muzzle, Muzzle_1, Muzzle_2 and Muzzle_3 with outward headings at the corresponding tips. The initial render was too pale and used 16,382 triangles.
2. Deepened teal/coral/brass colors, widened the brass tubes and muzzle rims, reduced circular and fastener tessellation, and welded profile axis vertices. Contract passed at 11,190 triangles. No contract check failed in either iteration.
3. Added the reference's darker inset face panels around the sockets while retaining the rounded teal edge frame. Contract passed at 11,814 triangles. Reviewed all five views and accepted the candidate.

## Final measurements

- Triangles: 11,814.
- Mesh objects: 15, within the advisory target of 16.
- Used materials: 10, within the advisory target of 10.
- Dimensions: 2.024 × 2.024 × 1.331 metres. Lowest point: z = 0.
- Export: cp_crossfire.glb, 299,432 bytes; packed source scene: cp_crossfire.blend.
- Textures: none. Animations: none. Rigid separate static base/pedestal and rotating Aim assembly.
- All four muzzle markers are bare empties directly under Aim. Blender headings are +Y, +X, -Y, -X. The glTF audit in metrics.json records their exported positions and orientations.
- All required contract checks passed. The sole advisory overrun is triangles versus the approximate 5,000 target. Extra tessellation supports the rounded enamel housing, four open tube interiors and beveled rims, rounded coral sockets, and smooth circular pedestal. Hidden profile and fastener detail was reduced without flattening these silhouettes; further optimization should follow visual acceptance.

## Fidelity and remaining limitations

The silhouette, four-way arrangement, hollow muzzles, mint faceted top window and teal/coral/gold palette reproduce the concept recognizably. The model has clean, uniform materials rather than the illustration's painterly color variation and soft worn specular highlights. Checker lighting still makes the colors somewhat lighter than the concept. Coral socket studs are simplified and repeated consistently on invented sides. The faceted mint window uses opaque reflective materials rather than simulated glass depth. Lettering was intentionally omitted as instructed. Gameplay import and inspection are handled by the integrating parent agent; this run does not claim an in-engine check.

Honest self-score: **8/10**.

## Frozen artifacts

The final build script, GLB, blend, validation report and comparison image are hashed in frozen_export.json. The source/export have not been modified after that audit.

GLB SHA-256: `94bd93d9ed70889632ae353e44a97b88fe54d87b6bea16bf89461e4da1ff2eba`.

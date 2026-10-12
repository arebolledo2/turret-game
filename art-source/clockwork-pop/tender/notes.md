# Brood Tender / eco_tender-v1

Final candidate: `eco_tender.glb`, generated from `build_eco_tender.py`; packed authoring source is `eco_tender.blend`.

Five harness iterations used (maximum allowed: eight). Final iteration 05 passes every contract check. All five comparison views were inspected after each completed iteration.

## Construction and iteration

- Rounded plum enamel barrel, pistachio front/side plates, cream lens, apricot shoulder rings and fasteners, four separate articulated plum legs, two graphite manipulator claws, and an opening mechanical delivery hatch.
- Three large pale mint translucent egg capsules in plum cradles, with mint guard ribs and small cream reflection strips. The supplied single-view concept visibly contains four capsules; the explicit brief requests three, so this candidate uses three.
- Iteration 1 passed the numerical contract but showed stale transforms on custom lathe objects and torus rotations, plus UV coordinates crossing atlas tile boundaries. Iteration 2 fixed dependency-graph updates before parenting and isolated each material atlas tile.
- Iteration 3 reduced small bevel/curve/sphere tessellation from 38,268 to 33,044 triangles and corrected the hatch opening direction to swing outward.
- Iteration 4 used an egg latitude profile for smoother rounded capsule ends. Iteration 5 standardized atlas mapping to 230.4 texels/metre in each UV axis, with no tile spill.

## Final audit

- Triangles: **33,044**. Mesh objects: **10**. Used materials: **9**.
- Bounds: **1.350 x 1.014 x 1.291 m**; lowest point **z=0.000 m**. Front faces Blender +Y; Blender +Z is up.
- Required empty pivots `Body`, `Leg_L_0`, `Leg_L_1`, `Leg_R_0`, `Leg_R_1`, `Arm_L`, `Arm_R`, and `Hatch` are all present and each owns descendant mesh geometry.
- Three generated and embedded 1024 x 1024 images: enamel base-color atlas, packed occlusion/roughness/metalness atlas, tangent normal atlas. No external model/image inputs or armature. GLB size: **1,884,140 bytes**.
- Rigid clips: **Idle** (2.4333 s), **Walk** (1.2333 s), **Swim** (1.6333 s), **Attack** (1.2333 s). Direct exported-accessor audit lives in `animation_audit.json`. Idle, Walk and Swim endpoints match to floating-point tolerance; Attack also returns exactly to rest. `Body` has no animation channels; cosmetic hull bob lives on child `Carriage`.
- Attack rotates `Hatch` outward **71.62 degrees** at its peak. The hatch hinges at the upper edge, below the cream lens. Arm/leg pivots move independently. Gameplay translation remains the caller's responsibility.
- Advisory triangle target is exceeded to preserve the smooth broad front/side plates, glass capsule silhouettes, rounded feet, shoulders and rings. Small ornament is joined to its moving carrier, keeping mesh and material counts below their advisory targets. No performance claim has been measured.

## Remaining visual limitations

The unseen rear service cover, vents and underside are invented. The carrier's crown is simpler and flatter than the concept's scalloped rim. The capsule transparency exhibits dither grain in the Eevee checker; verify it in the parent's Godot preview. Specular enamel shading is more physically glossy than the painted reference, and the legs are more regular/symmetric. The three-capsule count follows the brief rather than the image's four. Godot playback and gameplay-scale review are delegated to the parent; this run does not write game files.

Honest self-score: **8 / 10** for silhouette, color blocking, readable articulation and complete textured animation deliverable.

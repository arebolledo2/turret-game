# Bulwark Hermit — frozen candidate

Final candidate frozen at **iteration 3 of 8 allowed**, with the contract passing and final front, three-quarter, side, back and top views inspected against the selected concept. Parent reviewed iteration 3 and accepted it for game integration.

## Deliverables

- `build_cp_tank.py`: deterministic standalone Blender source, factory-empty startup, code-generated geometry and textures.
- `cp_tank.blend`: editable packed source with all image maps embedded.
- `cp_tank.glb`: self-contained final export, metres, Blender Z-up construction exported Y-up glTF.
- Four 1024×1024 generated PNG atlases: `bulwark_color_atlas`, `bulwark_orm_atlas`, `bulwark_micro_normal`, `bulwark_optic_fire`.
- `renders/iter03/compare.png`, five individual views and `validate.json`: final inspected views and passing contract.
- `audit_rig.py`, `rig_audit.json`: re-imported export hierarchy/lift/bob checks.
- `build_stats.json`, `export_manifest.json`: exact counts, pivot positions, file sizes/hashes and GLB integrity.

## Final model

**13,438 triangles / 15 mesh objects / 8 used materials / four embedded 1024×1024 images.** Bounding size **1.163 × 0.989 × 0.978m**, lowest geometry **z=0.011m**, horizontally centred at the ground origin. No animations, armatures, cameras, lights or external file references.

Recognizable reference features preserved: heavy domed teal helmet, broad front-to-back brass crown strap, thick horizontal brass belt, small steel/brass rivets, fine dark helmet panel seams, sapphire forehead jewel, coral status jewel, lower armoured teal face with amber eyes, two short steel mandibles, dark undercarriage, six gold-cuffed teal calves and slate supporting hooves. Hidden layout is deliberately **three legs per side**. Main surfaces are clean enamel and brushed metal, without generic dirt or weathering.

## Rig contract and leg axes

All seven required empties have **identity rotation and scale** in rest pose. `Body` and the six hip empties are root-level siblings so shell bob can be independent of grounded feet. Body carries every shell/face/armour mesh. Each leg empty carries exactly one merged rigid multi-material `Limb_*` mesh.

| Pivot | Blender world position | Moving mesh | Lift around Blender Y | Lift around Godot Z | Forward stride around Blender Z / Godot Y |
| --- | --- | --- | --- | --- | --- |
| `Body` | `(0,0,0.520)` | Nine main-body assemblies | — | — | — |
| `Leg_L_0` | `(-0.330,+0.240,0.315)` | `Limb_L_0` | positive | negative | negative |
| `Leg_L_1` | `(-0.330,0,0.315)` | `Limb_L_1` | positive | negative | negative |
| `Leg_L_2` | `(-0.330,-0.240,0.315)` | `Limb_L_2` | positive | negative | negative |
| `Leg_R_0` | `(+0.330,+0.240,0.315)` | `Limb_R_0` | negative | positive | positive |
| `Leg_R_1` | `(+0.330,0,0.315)` | `Limb_R_1` | negative | positive | positive |
| `Leg_R_2` | `(+0.330,-0.240,0.315)` | `Limb_R_2` | negative | positive | positive |

Forward is **Blender +Y**. Hip hardware axle is Blender **Y**, mapping to **Godot -Z** after glTF Y-up conversion. The lateral calves naturally rise with mirrored rotation around this axle. Fore/aft stride is a small yaw around Blender **Z**, mapping to Godot **Y**, with opposite sign by side. Index 0 is the front pair; index 2 is the rear pair. A tripod phase grouping can alternate L0/L2/R1 versus R0/R2/L1; gait phase/timing remain the parent's runtime responsibility.

Exported GLB was re-imported for a meaningful physical articulation check:

- Every hip is an empty, root-level, identity at rest, with its own required mesh descendant.
- Mirrored **0.16rad** lift increases each hoof's minimum Z from approximately **0.011m to 0.043560m**, consistently on both sides.
- Rotating any leg leaves every main-body vertex unchanged.
- Raising Body by **0.02m** leaves every leg vertex unchanged.
- No animation is baked into the source or export; the audit only changes an in-memory imported scene.

## Iteration record

1. Complete helmet, six hips/limbs, material atlases and optics rendered at 20,318 triangles / 17 meshes / 9 imported materials. The limbs appeared too horizontal with small ball-like feet. The merged leg mesh names collided with their pivot basenames (`Leg_L_0.001` versus `Leg_L_0`); validator basename lookup selected the meshes, falsely reporting the required empties as empty. The hierarchy itself already carried the leg geometry.
2. Renamed rigid limb meshes distinctly to `Limb_*`, reshaped the calves into chunky downward guards and taller armour hooves, added real hoof panels, reduced dome and minor detail tessellation, and combined main-body optics. Replaced vertex-tinted seams with the shared dark material to avoid an extra exported material. Contract passed at 17,174 triangles / 15 meshes / 8 materials.
3. Selectively reduced calf/hoof rings, small hinge circles, tiny rivets, optic caps and seam cross-sections. Major shell and limb silhouette retained; final contract passes at 13,438 triangles / 15 meshes / 8 materials. Final views inspected; export articulation audit passes.

## Textures and advisory budget

Four atlases provide generated base colour, ORM, micro-normal and restrained emissive optics. All meshes have active padded atlas UVs with the same metre-based box projection density. Primitive UV layers are reused; custom geometry is centred before projection. Image colourspace is assigned before pixels are uploaded, images are saved locally and packed, and glTF embeds all four images. No external imagery/model source or Cycles baking.

The 5,000 triangle target is advisory and exceeded to retain the large smooth helmet silhouette, compound brass bands, three jewel families and **six separate thick articulated limb assemblies**. Triangle count was reduced about 34% from iteration 1. Object/material/texture targets are met. Parent owns Godot import, runtime gait/controller, gameplay readability and any future measured optimization.

## Remaining limitations

Checker shading is less saturated and painterly than the reference. Calves and hooves are more regular rounded manufactured shapes; the concept has richer asymmetric armour shaping and more pointed hoof facets. The lower face is more symmetric and simplified. The six-leg hidden layout is intentionally resolved from the single view; it cannot be proven from unseen concept sides. Optical jewels are stylized opaque domes with small luminous/glint detail rather than refractive glass. Fine brushing and seam lines may be subtle at gameplay distance. A single rigid hip controls each whole leg; knees are not independently articulated because the required runtime contract has only six hip pivots.

Honest self-score: **7.9/10** for reference fidelity, with a clear heavy helmet silhouette, recognizable palette/details and verified six-leg physical articulation.

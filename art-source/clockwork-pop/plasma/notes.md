# Kilnheart Lobber — frozen iteration 5

Final deliverables: `build_cp_plasma.py`, `cp_plasma.glb`, and the packed editable `cp_plasma.blend`. Final appearance comparison is `renders/iter05/compare.png`, with five individual views in the same directory. The standalone builder starts factory-empty, seeds all texture generation, and exports no animations, cameras, or lights. It does not depend on another run or any external image/model.

## Final counts and contract

- **10,102 triangles, 12 mesh objects, 8 materials.** This is about 10K, slightly above the upper end of the advisory 5–10K polished crowd range; the preserved bevels, coral armor segmentation, rounded drum, jewel rims, and open barrel justify the small excess. The initial 5K target is advisory. Mesh, material and texture targets are met.
- Four procedurally generated 1024 x 1024 atlases: enamel/brass/jewel albedo; roughness and metallic channels; subtle normal surface finish; restrained jewel emission. They are packed in the `.blend` and embedded in the GLB. No external image URIs. All exported mesh primitives contain UVs.
- Size: **0.734 X x 0.890 Y x 1.131 Z metres**. Feet touch z = 0.0. No skeleton or deforming geometry.
- `Aim`: identity rotation, unit scale, Blender world (0, 0, 0.355), centered on the fixed bearing. Eight merged upper meshes carry the complete pressure vessel, muzzle, optics, decorative bands, and rotating saddle.
- `Muzzle`: bare empty directly under `Aim`, identity rotation, Blender world **(0, 0.566, 0.722)**, on the single bore's forward mouth. Blender +Y corresponds to glTF/Godot -Z.
- Four merged meshes under the root contain the feet, leg struts, hinges, support foundation, and fixed outer bearing. These remain fixed during yaw; runtime owns yaw/recoil. No baked animation clips.
- Final harness checks all pass. `verify_export.py` also checks the rest transforms, static/rotating hierarchy, marker, UV presence, embedded images and absent animations, recording a frozen SHA256 in `export_verified.json`.

## Five harness iterations

1. Built the reference silhouette with a bulging teal drum, short wide brass mouth, eight coral face petals, purple rim/dome and side optics, gold binding bands, and four supports. Texture colorspaces were set before pixels and active primitive UV layers were reused, avoiding the previous atlas issues. Bounds failed height/ground checks because a joined mesh retained the first angled leg's rotation, inflating its transformed bounding box; rendered feet were planted. Initial triangles: 11,854.
2. Applied rigid mesh rotations before grouping and compacted accessories while retaining the drum silhouette. Passed at 9,992 triangles with correct bounds. Flattened bore cap normals, but its shallow back still read as a plug in the straight front view.
3. Deepened the dark liner into the cannon body. The front view exposed a gold closed rear face blocking that deeper liner. Contract passed.
4. Removed the muzzle's blocking rear disc by making its rear profile annular. Another solid reinforcement disc still blocked the front view. Contract passed at 10,018 triangles.
5. Replaced that reinforcement disc with a properly open brass hoop. The bore now reads as a recessed cavity in front and three-quarter views. Final contract passes at 10,102 triangles. Export frozen after reviewing all views.

## Appearance and limitations

Selected reference's compact heavy teal pressure vessel, segmented coral armor, brass mouth, purple focusing ring, jewel crown, ivory optic sockets, gold bands and plum support legs are preserved. The central yaw bearing is deliberately clearer and taller than the concept so the planted supports stay static while the whole weapon turns. Hidden rear geometry is invented as a brass/teal service hatch with small fasteners; side optics are mirrored to the unseen side.

The model's base and legs are slightly taller/slimmer than the reference. Coral armor joints and ring highlights show some visible faceting. The studio checker gives brass more uniform highlights and the optics use opaque polished jewel surfaces rather than physical translucent glass. There is no baked ambient occlusion. The straight front view can catch a muted reflection on the deep throat closure, while the three-quarter bore reads dark. These are remaining visual differences, not claimed performance issues.

Game import, runtime aiming/recoil, and gameplay-camera verification belong to the parent integration pass. This agent changed no game files and did not launch Godot or benchmark performance. Only this run directory was written; prior frozen Ion files remain untouched.

Honest self-score: **8/10**. Token usage is not available to this agent.

# Clockwork gatling cp_gatling-v1

Frozen final: iteration 3. Three actual harness runs; all three comparison sheets were inspected. The source and export SHA-256 hashes are recorded in final_manifest.json. No external models, textures, services or generated images were used.

## Iteration history

1. Built the capsule receiver, coral curved cover, brass pedestal, six lavender barrels with mint collars and brass hollow tips, ivory buttons and segmented side drive belts. The six barrel assembly is carried by Rotor, with its rotation axis along Blender +Y. Aim rotates the entire head; base meshes remain static. The only contract failure was origin_xy_centred: asymmetric forward barrels put the bounds centre at Y=0.179 m. The real base centre was already at the origin. Initial cost was 24,020 triangles, 16 meshes and 9 materials. Bore backs appeared lavender because the barrel cap was visible through the hollow brass lip.
2. Preserved the base centre and used a run-local copy of the subject contract with origin_node="Aim", as authorized for this asymmetric turret. Enlarged the pedestal foot, broadened and shortened the pedestal, lowered the entire head 6 cm, strengthened the pastel colours, made lavender barrel tubes hollow and placed the dark bore back beyond their former cap. Muzzle is a bare child of Aim at the top barrel's forward bore: Blender (0,0.98,1.204), forward +Y. Reduced decorative bevel and sphere tessellation. Contract passed at 18,316 triangles.
3. Thickened the coral cover to match the raised reference cover and simplified small fasteners and belts after visual review. Inspected the five rendered views; open bores, sixfold cluster, collars, head silhouette and base remain clean. Contract passed; frozen here.

## Final audit

- 16,856 triangles, 16 mesh objects, 9 materials.
- Bounds: X 0.958 m, Y 1.602 m, Z 1.428 m; lowest point Z=0.012 m.
- Required Aim/Muzzle contract passes. Rotor is a separate empty under Aim, identity rotation, axis Blender +Y (Godot -Z). Its six lavender barrels, mint collars, brass tips, sockets, central spindle and face rotate together.
- Muzzle is a bare empty under Aim, has no mesh or children, and sits at the top barrel's forward lip. Aim also has identity rotation. Actual base origin remains X=Y=0.
- No textures or exported animation clips. Parent task handles native game import and runtime verification.
- Advisory triangle target exceeded to preserve six actual hollow barrel tips, physical bore interiors, smooth large rings/capsule surfaces, raised ceramic collars and beveled mechanical details. Mesh and material targets met. Cosmetic detail topology was reduced after appearance review. This is a fidelity candidate, not a demonstrated performance optimum.

## Remaining fidelity limitations and self-score

The concept depicts two larger barrels; the required genuine six-barrel correction necessarily changes the front silhouette. The reference has richer painterly shading, especially warm gold edges and subtle casing seams; this model uses clean PBR material regions without texture/AO detail. The unseen rear hatch and mirrored drive belts are sensible inventions. The receiver is a little more regular/cylindrical and the side winding controls flatter than the concept. The belt reads mostly as decoration and has no separate articulation; it remains part of Aim. Final self-score: 7.5/10.

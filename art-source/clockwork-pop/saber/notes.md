# Prism Saber — cp_saber-v1

Frozen accepted iteration: **04**. Four harness runs used, all contract checks passed in every iteration. I inspected the concept first and personally reviewed compare.png after iterations 01, 02, 03 and 04.

## Construction and runtime use

Rounded teal shoulder motor with coral bearing rings, a violet convex optical cap, gold actuator with pink axle jewel, an ivory ceramic forearm and three curled fingers plus an opposing thumb, midnight hilt, oval brass guard, hexagonal blade collar, and a solid mint prism blade with luminous bevels. The blade has a genuine single pointed tip and closed base. The pedestal is a turned stepped circular shape with an accent rim; the column is thicker than the concept for strength/readability.

Static objects are Pedestal, Pedestal_Trim and Static_Brass. All moving weapon/head geometry is carried by identity-rotation Aim at Blender (0,0,1.015). The bare Muzzle empty sits under Aim at world (-0.34,0.925,0.75), with identity rotation and +Y forward. Hand geometry touches only the dark grip. Blade lies horizontally along +Y; yaw moves the complete shoulder/hand/sword assembly. No skeleton, external resources, textures or exported animations. Origin is at the centre of the pedestal, with its underside 0.012 m above zero. The asymmetric blade/hilt bounds still satisfy the supplied bounds-centre check without relocating the real pedestal pivot.

## Iterations and fixes

1. Initial complete geometry and grouping: contract passed; 14,404 triangles, 15 mesh objects, 10 materials. Render showed pale material response under the checker lighting and blade face normals needed correction.
2. Darkened/saturated material colours, corrected blade outward winding, widened the broad blade face, and changed the blade collar to a rounded hexagon. Contract passed; 14,188 triangles.
3. Adjusted teal enamel and mint energy materials; reduced small lathe/cylinder/sphere tessellation while retaining bevels and clean major silhouettes. Contract passed; 12,116 triangles.
4. Replaced the blade's flattened terminal cross-section with one convergent pointed vertex and triangle fan, eliminating degenerate tip geometry. Final contract passed; 12,106 triangles. Personally reviewed final front, three-quarter, right side, back and top comparison.

## Final measured result

- 12,106 triangles; 15 mesh objects; 10 materials.
- Bounding size XYZ: 0.810 × 1.602 × 1.478 m. Lowest point: 0.012 m.
- All required nodes present; Muzzle under Aim, raised and forward; identity yaw/orientation; ground, dimensions and origin checks pass.
- Triangle advisory target exceeded by 7,106. Smooth cast circular housings, convex polished lens, machined edge bevels, ceramic finger forms and stepped round pedestal account for the extra geometry. Mesh and material targets are met. Visual acceptance took priority; no crowd-performance claim.

## Remaining limitations and self-score

**Self-score: 8/10.** Recognisable silhouette, functional hilt grip and strongly separated materials; clean enough to use as a candidate. The checker still produces paler and flatter teal/mint values than the painted concept and does not reproduce the concept's atmospheric glow halo. The head's rounded box shape is more regular than the image's hand-shaped facets, the support is thicker, and the palm/fingers are deliberately simplified mechanical forms. The single-view concept's unseen back/underside are sensible invented surfaces. Emissive edges are present in the GLB but bloom depends on runtime settings. This run was restricted to its folder, so Godot import/gameplay verification was not performed and there were no game edits.

## Frozen review artifacts

Canonical source: build_cp_saber.py. Native editable Blender scene: cp_saber.blend. Export: cp_saber.glb. Immutable-by-convention copies, the exact source contract, reference, validation and SHA-256 manifest are in frozen_iter04/. Reviewed comparison: renders/iter04/compare.png.

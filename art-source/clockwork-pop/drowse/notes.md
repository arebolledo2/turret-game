# Drowse Beetle candidate

Final export: `eco_drowse.glb`; rebuild source: `build_eco_drowse.py`; editable source: `eco_drowse.blend`.
Three harness iterations were used, with all contract checks passing in every iteration. Final visual review is `renders/iter03/compare.png`, final contract report is `renders/iter03/validate.json`.

Iteration 1 established rounded segmented shell plates, dark interior seams, bronze abdomen, soft face, six separate rigid feet and two articulated antennae. The render was too desaturated, the head/eyes were too small, and the belly too dark.
Iteration 2 increased green saturation and bronze value, enlarged the head/eyes, filled out the bronze abdomen and widened the upper cap gaps. Explicit hard-edge bevel limits were added; they did not reduce the triangle count because Blender already behaved that way by default.
Iteration 3 added lowered sleepy eyelids, flush bronze side ports and subtle segmented equator lines. The resulting face is visibly more relaxed. All five final views were inspected.

Final imported counts: **30,072 triangles, 16 mesh objects, 9 materials**. Height 0.803 m; footprint 1.252 x 1.289 m; lowest point z=0.017 m. Body and all six Leg_L/R_0..2 empties are root pivots, with shell parented to Body and foot geometry to hip pivots. Forward is Blender +Y. No skeleton.

The triangle target is advisory and exceeded. The doubled curved shell surfaces with rounded thickness, smooth head and optics, rounded rigid shin/shoulder/toe groups, and narrow curved rim/seam hardware account for the extra geometry. The count was retained for this appearance pass; meaningful future optimization can reduce tessellation in hidden shell interiors and small fittings. Mesh-object and material targets are met.

Four generated 1024 x 1024 color textures are embedded in the GLB: lime enamel, warm bronze, dark olive rubber and an optic/fastener atlas. Every mesh has UVs; there are no external image URIs. The texture finish is pristine satin with broad gentle green/moss patches and small bronze grain, without generic dirt. Roughness/metallic remain material constants; no normal map is present.

Clips: **Idle 4.0 s, Walk 1.333 s, Swim 2.0 s, Attack 1.0 s**. Actual exported transform channels verified in `animation_audit.json`: 4 Idle channels and 9 in each other clip. Idle/Walk/Swim are periodic and Attack returns to rest; endpoint errors are below 5e-17. No clip exports translation channels. Idle breathes/rocks the Body and gently waves the antennae; Walk cycles six rigid feet; Swim provides a broader paddling variant; Attack pitches forward with front-foot/antenna motion. No root translation.

Known limitations: the reference has hand-painted comic contour lines and sharper stylized highlights, while this candidate uses physical satin highlights. The body is more symmetric and the broad upper cap more circular than the illustration. Hidden rear/underside are invented. Feet articulate rigidly at hips rather than bending at knees, and lowered eyelids remain static. The sheen and texture are verified in Blender checker renders; Godot playback/import review is delegated to the parent and was not performed here because the brief forbids game edits.

Honest visual self-score: **7.5 / 10**. It is recognisable, clean and expressive, with the largest remaining gap being the illustration's unusually sculpted shell silhouette and painted lighting.

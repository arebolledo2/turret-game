# Crownwheel Colossus v1

Final iteration: 3 of a maximum of 8. All contract checks passed in every iteration.

This is a single upright armored green wheel with a real open annulus, ivory sidewall rims, two inset bronze gear crowns, a recessed graphite ring gear, a copper axle, a long offset gold suspension strut and a forward-facing amber optic. Model front is Blender +Y; the wheel rolls around Blender X. Wheel is a root-level sibling of Body, so the strut and optical crown remain upright while the tire and driven gear rotate. The Optic child can pitch independently.

Iteration 1 established silhouette, mechanism depth and the required hierarchy. It passed at 48,156 triangles. Visual review found excess bevel tessellation and brass that was too brown. Iteration 2 reduced bevel segments, ring subdivisions and lens tessellation while brightening the gold atlas, giving 30,860 triangles with the same silhouette. Iteration 3 made wheel rotation linear under Blender 5.2's layered action API and saved the source with its NLA tracks available. Geometry was unchanged from iteration 2. Each final comparison image was inspected.

Final exported statistics: 30,860 triangles; 26 mesh objects; 8 materials; 4 embedded 1024 x 1024 texture images. Bounds are 0.953 x 1.800 x 2.109 m in Blender X/Y/Z; lowest vertex is z=0.005 m. Four generated atlases supply emerald/deep jade/graphite enamel, brass/bronze/copper, warm ivory, and amber. All mesh UVs are unwrapped and the colored atlas regions are embedded; there are no external image URIs.

The triangle target of 18,000 is advisory. The 30,860 result retains rounded tread armor, continuous hollow sidewall profiles, rounded tooth crowns and substantial optical geometry. The object and material targets are met. No runtime performance claims were made.

Exported rigid-part clips: Idle (2 seconds), Walk (2 seconds), Swim (2 seconds), Attack (1 second). Idle, Walk and Swim return to matching endpoint poses. Walk and Swim rotate Wheel exactly -360 degrees per loop around X; no other quaternion axis receives wheel rotation. Attack rocks the wheel, recoils the body and pitches the optic, then returns to rest. The animation_audit.json records decoded exported transform samples, duration, endpoint orientations and axle rotation. glTF itself does not encode a looping playback policy: the importing engine must enable loop playback for Idle/Walk/Swim and one-shot playback for Attack.

Remaining visual differences: the optic faces forward in the agreed travel direction, which changes the reference's single-view presentation; the invented reverse side has a matching recessed gear and spokes. The shell is somewhat more mechanical and reflective than the soft painted concept, and the brass strut is less cream-colored. Subtle texture variation is intentionally clean, with no dirt or generic damage. No baked ambient occlusion, alpha transmission, skeletal deformation, ground locomotion translation, or in-engine validation was added. The parent task handles Godot import and playback inspection.

Self-score: 8/10 for recognizable silhouette, clean open mechanism, material separation and stable rolling hierarchy.

Deliverables: build_cp_crownwheel_colossus.py; cp_crownwheel_colossus.glb; cp_crownwheel_colossus.blend; four texture PNGs; audit_animation.py; animation_audit.json; renders/iter03/compare.png; renders/iter03/validate.json.

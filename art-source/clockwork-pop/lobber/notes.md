# Eco lobber v1 — final candidate

Final source: `build_eco_lobber.py`; packed source: `eco_lobber.blend`; self-contained export: `eco_lobber.glb`.
Final review: `renders/iter03/compare.png`; contract: `renders/iter03/validate.json`; binary animation/image audit: `glb_audit.json`.

## Result

Three harness iterations used (maximum eight); the final contract passes every check.
31,828 triangles, 10 rigid mesh assemblies, 10 used materials. Bounds 1.147 × 1.089 × 1.262 metres; lowest geometry z=0.007 m.
Required pivots Body, Leg_0, Leg_1, Leg_2, Aim, Muzzle are present. Aim is neutral at rest; Muzzle is a bare empty directly under Aim, at the bore centre facing Blender +Y (Godot -Z after conversion). Each leg has an additional rigid child Knee_i.

Four generated 1024 × 1024 PNG atlases are embedded: kiln_colour, kiln_orm, kiln_normal, kiln_emission. Every mesh has UVs. Materials have gentle coherent painted variation, brushed metal detail, roughness variation and subtle tangent normals, rather than generic dirt. Standalone PNGs are retained for review and packed inside the Blender source.

## Animation

- Idle: 2.0 seconds; Body breathing and Aim settling; 2 exported changing transform channels.
- Walk: 1.0 second; three phased upper legs and knees, subtle Body bob/roll and barrel motion; 9 changing transform channels.
- Swim: 1.0 second; same tripod cycle as Walk, supplied to satisfy the brief's legacy clip contract; 9 changing transform channels.
- Attack: 0.8 seconds; anticipation, recoil, damped return, slight shell/shutter reaction; 8 changing transform channels.

All exported channels have exactly matching first/last poses; Attack ends at its resting pose. Root Kiln_Lobber has no animation channels or translation. There is no skeleton or material-only animation. glTF has no standard playback loop flag, so Godot preview/integration should mark Idle, Walk and Swim as looping and Attack as a one-shot. The wrapper should play one clip at a time.

## Iterations and fixes

1. All automated contract checks passed. Visual inspection found a furnace-shell intersection inside the bore and an almost hidden heat slit. Initial bevel-heavy model was 38,888 triangles.
2. Raised receiver, barrel and shutters 0.05 m; repositioned the lower furnace band/window, saturated orange enamel and simplified small bevels. Heat slit became readable and triangle count fell to 31,752. A narrow orange overlap remained on the inside bore wall.
3. Recessed a separate opaque dark bore terminus and narrowed the liner to clear the orange jacket. Centred Muzzle precisely on the bore axis. Corrected leg-cycle starting offsets so every loop has an exact matching endpoint. Final 31,828 triangles; all contract checks pass. Inspected every final harness view and separately audited the actual GLB for embedded textures, clip durations, changing channels, seamless endpoints and bare Muzzle.

## Remaining limitations

- Self-score: **8/10**. The favorite orange/copper mortar silhouette, open dark bore, chunky framed shutters, teal badges, furnace slit and tripod are recognizable. The concept has richer hand-painted highlights and a slightly softer/cushier stance; the procedural finish remains more uniform and reflective under the checker lights.
- Rear cap/radiator and underside were invented sensibly from a single-view reference.
- The walk cycle is stylized rigid motion without planted-foot IK; some foot sliding is expected. Swim is a compatibility alias of the gait rather than a distinct swimming action.
- Yellow emission looks pale in the checker. Engine appearance and animation playback still need the parent's Godot candidate review; no game files were edited.
- The 10K triangle target is advisory and exceeded to retain the smooth large bore/receiver silhouettes, rounded enamel frames, copper feet and articulated circular bearings. Small bevels were simplified once. Draw-object and material targets remain satisfied. No crowd/performance claim is made.

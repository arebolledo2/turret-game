# Crucible Crab v1

Final candidate: `cp_crucible_crab.glb`, built entirely from `build_cp_crucible_crab.py`.
Packed editable source: `cp_crucible_crab.blend`.
All work was confined to this run; no game files or other runs were modified.

## Iteration record

Four harness iterations, all passed the required contract.

1. Established orange hemispherical pressure vessel, dark underbody, recessed octagonal firebox, concentric side drums, four jointed legs, two multi-part claws and capped hollow chimneys. 45,448 triangles. The hooks were visually too short and the furnace emission washed out its core.
2. Extended pincer hooks and separated their dark copper tips; increased readable orange/brass contrast; added a generated flame field, deep brick walls and a distinct three-dimensional molten core. 45,466 triangles. The reference still wanted a more angular armoured brow and the assembly carried too many metal bevel subdivisions.
3. Added the cast armoured brow and its fastenings, differentiated the lower jaw enamel, gently splayed the claw assemblies, and reduced bevel subdivisions around small metal details. 35,822 triangles.
4. Moved the pincer hinge hardware to the outer sides and corrected the walk/swim/attack claw yaw animation to preserve the neutral pose. Final 35,710 triangles. Inspected `renders/iter04/compare.png` directly against the reference.

## Final contract and complexity

- 35,710 triangles, 19 mesh objects, 8 shared materials.
- Dimensions: 3.036 x 2.417 x 2.111 metres; minimum Z 0.016 metres. Horizontally centred overall bounds.
- Required Body, Claw_L/R, Leg_L/R_0/1 empty pivots have descendant geometry. Each leg also has Knee and Foot pivots; each claw has Top and Bottom jaw pivots.
- Four generated 1024 x 1024 packed/embedded images: enamel colour, metallic/roughness finish, micro-normal, and heat/flame atlas. No external texture dependency in the GLB.
- Triangle target exceeded to retain the rounded boss carapace and palm silhouettes, layered bevelled pressure drums, cast recessed hatch, caps/collars, and small visible fastenings. Objects and material counts remain below their advisory targets. No performance claim or crowd benchmark was attempted.

## Animation

`animation_audit.json` reads the final binary GLB, rather than trusting Blender actions. Export contains:

| Clip | Duration | Moving transform channels | Endpoints |
| --- | --- | --- | --- |
| Idle | 3.0 s | 7 | Match to floating-point precision |
| Walk | 1.6 s | 16 | Match to floating-point precision |
| Swim | 2.4 s | 16 | Match to floating-point precision |
| Attack | 1.4 s | 8 | Exactly return to resting transform |

Walk/Swim animate hips, knees and ankles with a diagonal alternating gait, plus body sway and arms. Idle breathes subtly and flexes the pincers. Attack anticipates, opens both articulated jaws, lunges/snaps, and returns. Loop flags must be enabled for Idle/Walk/Swim after import because glTF does not encode playback looping.

Source animation previews: `preview_attack.gif` and `preview_walk.gif`. These are rendered from the saved packed Blender source; the independent binary animation audit verifies the actual GLB tracks. Godot import/playback verification is left to the parent agent, as the task explicitly forbids edits to the game.

## Fidelity and remaining limitations

Self-score: **7.5 / 10**. Reads clearly as the orange furnace crab, with the essential rounded shell, graphite underside, two substantial working pincers, four articulated legs, brass hardware, dual short stacks and a physically recessed heat chamber. The reference has more sculpted overlapping cheek/pincer armour and more intricate paint reflections. This candidate's shell is smoother, the claws are more tubular, and the underbody is relatively simple. Rear/underside details were invented from the single view. Emission is contained in the recess, but the checker still makes the hot core pale; its final appearance should be reviewed under the game's lighting. The four furnace texture atlases provide variation rather than bespoke hand-painted edge shading, and there is no baked ambient occlusion.

No measured token count was available to the asset agent.

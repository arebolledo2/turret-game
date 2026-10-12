# Tether Anchor — eco_anchor-v1

Completed in **2 of the maximum 8 harness iterations**. Final contract: **PASS** (`renders/iter02/validate.json`). Final five-view comparison was opened and inspected after the second harness run.

The supplied image is the parent humanoid marionettist rather than a picture of the deployed pylon. In accordance with the task, I used that image as a palette and finish reference and independently constructed the brief's three-toed ground anchor. The pylon has a plum chassis, three ivory inset shoes, a raised circular cable socket, an open tapered six-stanchion cage, a prominent faceted magenta crystal, and a gold/ivory cap with amber finial. It contains no humanoid limbs or borrowed image/model resources.

## Iterations and fixes

1. Geometry, UVs, procedural textures, rigid Cage clips, and self-contained GLB export passed every contract check. The first comparison showed the plum and gold too dark and the crystal closer to crimson than magenta.
2. Brightened the generated ivory, plum and gold maps and shifted the generated crystal map toward magenta. Final comparison preserves clean value separation and makes the rose weapon light distinct from the parent's friendly cyan.

No failed contract checks occurred. No other run folder was read or changed; no game files or harness files were edited or game builder executed.

## Final artifact and measured counts

- `eco_anchor.glb`: 3,033,884 bytes; fully self-contained.
- `build_eco_anchor.py`: scratch build script, first operation resets Blender to an empty factory scene.
- `eco_anchor.blend`: editable packed construction file.
- `ivory_porcelain.png`, `plum_lacquer.png`, `brushed_gold.png`, `crystal_rose.png`: four generated 1024 × 1024 base-color maps, packed into Blender and embedded in the GLB.
- `renders/iter02/compare.png`, five individual views and `validate.json`: final harness evidence.
- `audit_glb.py` and `glb_audit.json`: binary-level image and animation inspection.
- **11,390 triangles / 10 mesh objects / 8 materials**. Height **0.856 m**, width/depth **0.647 × 0.617 m**, minimum Z **0.008 m**. Required `Body` and `Cage` empties each have descendant geometry. `Body` is at the ground-centred origin.
- Triangle count exceeds the advisory 5,000 target because beveled toes, sockets, collars, slim rounded cage rods and small round rivets catch the polished highlights. Mesh objects and materials stay within advisory targets. The soft budget allows this; simplify small ring/rivet tessellation after visual acceptance if performance requires it.

## Animation verification

`Idle` (~2.967 s), `Walk` (~1.967 s), `Swim` (~3.967 s), and `Attack` (~0.767 s) are exported as named rigid transform clips. Only `Cage` has channels: rotation in every clip and scale additionally in Attack. `Body`, base, and root do not animate. The three ambient clips use modest oscillation and all endpoints match exactly; Attack winds the cage and expands it by approximately four percent before returning to the exact rest pose. Audit confirmed actual nonzero motion, zero endpoint error, four embedded image buffers with no image URI references, and zero skins. Godot import/playback and the parent's animated preview remain parent-owned verification steps; this run did not edit the game.

## Limitations and self-score

**8/10** as an independently designed support pylon in the reference family. The single supplied image does not establish a pylon silhouette, so this is a deliberate interpretation of the written goal. At gameplay distance the small rivets and procedural satin variation may disappear; the large three-toed base, open cage and bright cut crystal remain clear. The crystal is an opaque polished gemstone with restrained emission, rather than physically refractive glass. Gold appears somewhat pale under the checker’s bright studio lighting. Texture maps contain controlled subtle surface variation rather than elaborate painted wear, matching the pristine parent design. No crowd performance or Godot playback claims are made.

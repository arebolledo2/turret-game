# Pip the Lantern Keeper — frozen iteration 3

Deliverables: `build_cp_hero.py`, `cp_hero.glb`, and packed editable `cp_hero.blend`. The source builds from factory-empty Blender, generates its own deterministically seeded textures, and uses no external models/images or other runs. Final views reviewed: `renders/iter03/compare.png` and each individual view beside it.

## Final geometry and surface counts

- **11,130 triangles, 6 mesh objects, 9 materials.** Rounded helmet, explicit curved visor outline, smooth eyes/ear jewels, chest lantern, finger/grip details and articulated boot forms justify the triangle count above the initial 5K advisory target and modestly above the 5–10K crowd starting range. Pip is a hero asset; six rigidly grouped meshes keep node overhead small. The ninth material makes only the amber eyes/lantern flame emissive instead of making ordinary brass glow.
- Four generated and packed **1024 x 1024** atlases: albedo, roughness/metallic, restrained surface normal, lantern emission. Amethyst/amber share two halves of the final atlas tile. GLB images are embedded with no external URI references. Every exported primitive has UVs.
- Size **X 0.616 m, Y 0.700 m, Z 1.137 m**, soles at **z = 0.0**. Grounded biped; no hovering gap, skeleton, skin weights or baked clips. Transparent cyan lantern shell uses exported BLEND over a contained amber core; jewels on the helmet remain opaque.
- All final harness checks pass. `verify_export.py` additionally verifies hierarchy, all rest rotations, UVs, self-contained images, transparency, no clips/skins, and exact muzzle placement. `export_verified.json` records the frozen SHA256 and both Blender world and glTF local pivot positions.

## Authored rest hierarchy and pivots

All empty pivots have identity rotation and unit scale. Coordinates below are **Blender world metres**; +Y is character/weapon forward and glTF/Godot -Z. Character anatomical right is X negative when facing +Y.

| Pivot | Parent | World position | Geometry responsibility |
|---|---|---|---|
| `Body` | `Pip_Lantern_Keeper` | (0, 0, 0.328) | Ivory torso, backpack, waist/neck joint, chest lantern; carries all upper pivots |
| `Head` | `Body` | (0, 0, 0.668) | Helmet, rounded visor, amber eyes, purple ear optics, upper neck collar |
| `Arm_L` | `Body` | (0.179, 0, 0.594) | Utility shoulder/arm/cuff/hand hanging at rest |
| `Arm_R` | `Body` | (-0.179, 0, 0.594) | Weapon shoulder/arm/hand and forward gold pistol |
| `Leg_L` | Root | (0.082, 0, 0.323) | Left hip, thigh and planted boot |
| `Leg_R` | Root | (-0.082, 0, 0.323) | Right hip, thigh and planted boot |
| `Muzzle` | `Arm_R` | (-0.267, 0.452, 0.609) | **Bare empty**, precisely at forward pistol bore mouth, +Y forward |

Each of the six articulated non-marker pivots owns one merged rigid mesh. Body yaw turns the torso/head/arms/pistol without rotating the legs. No shoulder or torso aiming rotation is baked into the authored rest pose; geometry itself is built facing +Y. `Arm_R` rest identity permits the parent's backwards recoil translation along Godot local +Z. Legs remain direct root children for independent locomotion.

## Three harness iterations

1. Built the complete friendly helmet/face, ivory torso, coral pack, chest lantern, utility hand, forward pistol and planted legs. Passed at 11,808 triangles. View review showed primitive bevel clamping made the thin visor too square and boots too rectangular.
2. Replaced visor plates with explicit rounded outlines, increased eye size/readability, darkened visor reflections, and replaced boot blocks with cylindrical shin armor/rounded soles. Compacted rigid geometry slightly. Passed at 10,952 triangles. The helmet still read too square and eyes shared pale brass coloring.
3. Increased helmet corner radius, added a dedicated warmer amber atlas sub-tile for eyes/flame, and lowered visor specular strength while retaining the rounded glossy read. Passed at 11,130 triangles. Final render views reviewed, export frozen.

## Appearance and honest limitations

Oversized teal helmet, two readable amber oval eyes, dark visor, purple/gold ears, ivory chest/arm armor, central cyan/gold lantern, coral backpack, warm brass boots/shoulders, slate joints and forward pistol preserve the reference's recognizable design. Unseen pack panel/straps are invented sensibly; utility fingers and weapon grip are simplified rigid details. Weapon is held forward at rest as requested for parent runtime aiming.

Compared with the concept, the helmet/visor remain somewhat squarer and the front visor catches a broad studio reflection. Shoulder armor uses simplified rounded caps and the lantern cage uses straight thin struts. Boots are a little taller, body stance is more neutral, and surface colors/glow look softer in the checker. No baked ambient occlusion, facial animation, elbow/knee pivots or baked locomotion clips. Only the named six rigid articulation pivots are intended for runtime motion. No game import, edits, launch or benchmark occurred here; parent handles gameplay/motion verification.

Honest self-score: **8/10** for a readable faithful playable rigid character, with stated silhouette/style differences. Token usage is not available to this agent.

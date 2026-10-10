# Ramjet Beetle — final, iteration 3

Frozen export: `cp_charger.glb`, 2,843,816 bytes, SHA-256 `88bac45c697b10a5cff0c76747a508bc8a7948b58bf64160b61e1ae4576006d8`.

The final build has **10,202 triangles, 5 rigid mesh objects, 8 materials and 4 embedded 1024 × 1024 textures**. It has no armature, skin or animation clips. Blender dimensions after reimport are **0.801 × 1.055 × 0.850 m**, lowest point **Z 0.001 m**. Contract passes. This modest overrun of the provisional 5–10K triangle range preserves the rounded enamel shell, broad curved brass tusks, smooth forward helmet and separately articulated leg armor. Materials remain within the eight-material target; all parts that move together are merged by pivot.

## Fidelity and iteration history

1. First construction established four coral carapace plates, purple crest, teal helmet, irregular mint visor, dark jaw mask, rising brass ram tusks, brass rear ports and four independently pivoted feet. Contract passed, but 20,352 triangles was unnecessarily dense and leg armor was too slight.
2. Reduced sphere and patch tessellation, widened the visor and thickened the teal leg armor. Contract passed at 13,072 triangles. The larger shields obscured the original brass hip lens placement.
3. Exposed the brass hip lenses, replaced the partly intersecting spherical gold belly with a controlled skirt profile, flattened toe caps and selectively reduced the grouped meshes. Contract passed at 10,202 triangles. Parent visually accepted this iteration for integration.

The reference's single view is reproduced with the large coral dome, purple central stripe, teal armored face, mint visor, paired brass tusks, circular hip optics and split slate toes. The rear shell, underside and rear ports are inferred. The legs and helmet remain smoother and more rounded than the concept's planar painted shapes; the head is more uniformly domed. Small seam/rivet details will be less visible at game distance. No ambient-occlusion bake is present. Glow, game camera readability and locomotion are to be checked by the integrating parent in Godot. Self-score **8/10** for the standalone asset.

The brief's inherited “hovering model with no legs” line conflicts with its explicit four-leg goal and the parent's instruction. The delivered model is grounded and uses the required four-leg contract.

## Rest hierarchy and runtime axes

`Ramjet_Beetle` is the identity root. `Body`, `Leg_L_0`, `Leg_L_1`, `Leg_R_0` and `Leg_R_1` are root siblings; each carries exactly one rigid mesh. Body contains the full beetle chassis, helmet, tusks and rear ports. Each leg carries its armor, joints, hip optics and planted toes. Every required pivot has identity rest rotation and unit scale.

| Pivot | Blender world position X, Y, Z (m) | glTF/Godot local position X, Y, Z (m) |
|---|---|---|
| Body | (0, -0.050, 0.460) | (0, 0.460, 0.050) |
| Leg_L_0 | (-0.221, 0.165, 0.334) | (-0.221, 0.334, -0.165) |
| Leg_L_1 | (-0.221, -0.182, 0.334) | (-0.221, 0.334, 0.182) |
| Leg_R_0 | (0.221, 0.165, 0.334) | (0.221, 0.334, -0.165) |
| Leg_R_1 | (0.221, -0.182, 0.334) | (0.221, 0.334, 0.182) |

Forward is **Blender +Y / Godot -Z**. L legs are negative Blender X; R legs positive Blender X. Index 0 is fore (+Y), index 1 aft (-Y). Lift L around positive Blender Y (Godot negative Z); lift R around negative Blender Y (Godot positive Z). Fore/aft sweep rotates around Blender Z (Godot Y). Body motion does not inherit to leg pivots. No baked motions compete with the runtime controller.

## Export audit and reproducibility

`build_cp_charger.py` starts from factory-empty Blender, builds every mesh, generates four seeded texture atlases, packs all images into `cp_charger.blend`, and exports the self-contained GLB. Textures carry subtle enamel grain, brass brushing, roughness/metalness variation, a subtle normal map and mint visor emission. Texture colorspaces are assigned before writing image pixels. Each mesh has one active UV layer; all exported material primitives were checked for finite UV coordinates within their correct atlas tile.

`verify_export.py` checks GLB structure, root/pivot hierarchy, rest transforms, embedded images, triangle count, UV tile allocation and absence of clips/skins/cameras. It saves `export_verified.json`. `audit_packed.py` checks packed Blender images, colorspaces, UV layer count and no actions, saving `packed_verified.json`. Final visual comparison: `renders/iter03/compare.png`. No game files or other asset runs were edited.

# Pepperbox Watchman — frozen iteration 4

Standalone source: `build_cp_ion.py`. Final model: `cp_ion.glb`. Packed editable source: `cp_ion.blend`. The builder starts from factory-empty Blender, seeds its generated textures, and exports without animations, cameras, or lights. All files were written only to this run folder. Final appearance review: `renders/iter04/compare.png` and individual views alongside it.

## Final counts and contract

- 9,702 triangles, 12 mesh objects, 8 materials.
- Four generated and packed 1024 x 1024 images: albedo, roughness/metallic atlas, restrained normal finish, and optic emission. Embedded GLB images have no external URI dependencies. Every exported mesh carries UVs.
- Size: X 0.622 m, Y 0.916 m, Z 1.203 m. Ground contact z = 0.0 m.
- `Aim` has identity rest rotation and unit scale at Blender (0, 0, 0.43), on the pedestal yaw axis. Nine merged rigid upper meshes are its children. The three merged pedestal meshes stay under the root.
- Bare `Muzzle` is directly under `Aim`, with identity rotation, at Blender world (-0.112, 0.540, 0.706), the left forward bore mouth. Blender +Y becomes glTF/Godot -Z. No baked yaw, recoil, or other animation clips.
- All harness contract checks pass. The 5K initial advisory triangle target is exceeded to preserve rounded reels, beveled enamel, deep hollow barrels, and recognisable brass mechanical details; the result fits the 5–10K polished crowd starting range. Mesh/material/texture advisory targets are met.

## Four harness iterations

1. Built the silhouette and pivot hierarchy. Contract passed. Initial construction was over-tessellated (28,104 triangles), and assigning image colorspace after writing pixels unexpectedly cleared those generated pixel buffers, leaving the surfaces black.
2. Assigned colorspace before pixels; reduced accessory tessellation, welded duplicate lathe vertices, and compacted rigid meshes. Contract passed at 10,578 triangles. View review showed pre-existing primitive UV layers being used instead of the new atlas UV layer.
3. Reused and populated each primitive's active UV layer, retained more tessellation around the large reel contours, and compacted small accessories further. Contract passed at 9,702 triangles. View review caught an overlong axle obscuring the optic faces.
4. Shortened the reel axles within their housings. Contract passed at 9,702 triangles. The turquoise jewel and cream/coral optic are now visible. Final export frozen.

## Appearance and remaining limitations

Clean teal enamel film-camera body, unequal fore/aft reels, warm brass open cannon barrels, coral accents, plum recesses, lilac screws, turquoise jewel, and broad static pedestal preserve the selected reference's design. Generated surface variation stays subtle and clean, with no generic grime. Front barrel panel and sensible rear panel/vents/ports were invented from the single reference. Reel optics and winding details are mirrored onto the unseen side for readable yaw poses.

Compared with the reference, the upper body has a slightly squarer construction; the highlights are more uniform under the checker lights and some bevel highlights around the reels remain faceted. Fine brass dial ribs and small fasteners are mainly visible in closer views. There is no baked ambient occlusion. Opaque jewel optics replace physical translucent lenses. No game rendering/performance claims: parent integrates and verifies in Godot. No game files were read beyond the permitted builder reference, changed, or launched.

Honest self-score: **8/10** for faithful polished playable construction, with lighting/style and minor silhouette differences remaining. Token usage is not available to this agent.

# Bramble Wisp — frozen candidate

Final export: `cp_basic.glb`; packed source: `cp_basic.blend`; deterministic standalone builder: `build_cp_basic.py`.
Final inspected comparison: `renders/iter06/compare.png`.

## Validation and complexity

- Six harness attempts used, including one failed build. Final iteration 6 passes every contract check.
- 9,324 triangles, seven mesh objects, seven materials, three embedded 1024×1024 generated images, zero animation clips/tracks.
- Imported dimensions: 1.137 × 0.810 × 1.195 m; lowest point z = 0.185 m; horizontally centred within the required tolerance.
- Root `BrambleWisp` stays at ground origin. The `Body` empty at z = 0.77 m carries all seven rigid mesh objects. Parent integration can animate that single pivot for hover/tilt.
- The 5K advisory target is exceeded to retain the rounded orb/lens, broad leaf silhouette, smooth circular frame, and bevelled fittings. It remains within the requested 5–10K provisional polish range; mesh/material counts are below advisory targets.

## Appearance and procedural surfaces

Ten broad, curved teal enamel leaves surround a rounded orb, with a larger bent crown leaf. The front has a dark teal dome, warm brass frame, coral lower bezel/medallion, sapphire fasteners, and a prominent cream-ringed emerald optic. Leaf roots have real thickness; leaves and orb share one material/mesh after joining.

All images are generated in the builder from seeded numpy operations, saved alongside it, packed in the Blend, and embedded in the GLB. The enamel image supplies subtle fired-enamel tone/grain. A five-band finish atlas serves brass, coral, dark glass, sapphire and ivory. A dedicated optical texture supplies the cream sclera, emerald radial fibres, pupil and painted highlight. Every mesh has a UV map. Surface detail stays clean rather than weathered. Materials are opaque; there are no stacked transparent shells.

## Iterations and fixes

1. Build failed because joining removed objects retained in a Python list. Fixed selection by reading the current scene per material.
2. Passed contract, but original primitive UV maps displaced the intended finish atlas in the GLB. The face and hardware showed obvious incorrect colour bands. Triangle count was 11,772.
3. Cleared primitive UV maps before assigning the consistent atlas projections; enlarged the eye and reduced bevel tessellation on small fittings. Corrected colour regions and reached 9,324 triangles.
4. Corrected the convex eye face winding, matched the concept eye offset/crown bend, and reduced iris glare.
5. Thickened leaf roots and made the eye finish more diffuse so the emerald texture and dark pupil remain legible under the harness lighting. Inspected all five rendered views and accepted this version.
6. Parent-authorized winding-only repair after the Skipper Moth investigation identified polar ring quads wound opposite to center fan triangles. Corrected the eye surface winding; its unwanted center ring shading is gone. Geometry positions, material setup, texture images, triangle counts and dimensions are unchanged. Inspected every view and passed the contract again.

The previous accepted GLB is preserved as `cp_basic_pre_winding_fix.glb`. Current GLB SHA-256: `6047f074f8012b6c60e736b6c0ad9147d0689de2cede6d967ec089f08d0ebee6`. Previous SHA-256: `07d686573bed829f4b527a6e4a93b515bb9a455219890f1eb0eee45b1007c995`. `winding_fix_audit.json` confirms three embedded images, seven meshes and zero animations. Parent owns review/re-promotion of the repaired export.

## Remaining limitations

- The unseen rear is invented as a coral/brass service cap; the concept provides no back view.
- The modelling is rounder and smoother than the illustrated facets/highlight shapes. Leaves remain slimmer from a strict side view than their broad front silhouette.
- The face dome is uniformly dark teal rather than reproducing the illustration's painted patches. Fine iris fibres and enamel grain are subtle at game distance.
- No baked ambient occlusion, normals/roughness textures, or animation clips. Game lighting, hover movement, and crowd verification are owned by the parent integration task.
- Blender harness validation is complete. No game files were touched, and Godot import/playback was intentionally delegated to the parent.

Honest visual self-score: **8/10**. The recognisable bramble orb, palette, eye, and frame are present with a compact rigid structure; it is a polished interpretation rather than an exact reproduction of the painting.

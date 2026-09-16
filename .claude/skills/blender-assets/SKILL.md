---
name: blender-assets
description: Rebuild and validate the scripted Blender models for the Godot 3D migration slice.
---

# Scripted Blender assets

Use for changes to `tools/blender/build_slice_assets.py` or the turret/drone/player model family. This workflow uses Blender geometry, not raster image generation.

1. Inspect the reference images listed in `assets/models/slice/manifest.json` and the current Godot model wrappers before editing geometry.
2. Run the checked-in builder with Blender's bundled Python:
   `& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python tools/blender/build_slice_assets.py`
   Use an explicit installed version/path if different. The builder overwrites this family's source `.blend` and exported `.glb` files. Append `-- --only plasma_turret charger_drone player_bot` (or other asset IDs) to rebuild a subset while preserving the other manifest entries and binaries.
3. Maintain the metre scale and ground-centred origin. Blender +Y exports to Godot -Z. Preserve `Aim`, `Muzzle`, and the six `Leg_L/R_0/1/2` nodes; gameplay wrappers depend on them. Aiming and walking are runtime rigid-part animation, not exported skeleton clips.
4. Run `./run_tests.ps1 -Import -filter 3d_`. The import tests verify pivots and muzzle orientation. Inspect the generated manifest's geometry/material counts and version changes.
5. Render the capture scene using the normal GPU driver: `godot --path . --resolution 1280x720 res://tools/capture_3d_slice.tscn`. Add `-- --shop`, `-- --combat-demo`, or `-- --stress` for refit, a frozen warning/impact, or a live mixed crowd. Do not use `--headless` for screenshots. Output is in `.test-results/`. Review the PNG and both stdout/stderr. A successful exit alone does not establish a clean render.
6. Keep approved sources, GLBs, import sidecars, manifest, and scripts together. Git LFS tracks `.blend` and `.glb`; CI must fetch LFS objects. `art-source/.gdignore` prevents duplicate Godot import of source files. Ignore Blender backups, temporary captures, caches, and model weights.

Use the existing full GUT gate for changes to gameplay contracts. Do not claim the crowd sample establishes performance on minimum hardware or with fully migrated effects.

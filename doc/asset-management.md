# Asset management

## Native 3D assets

Approved game models and their provenance manifest live in `assets/models/game/`. Editable Blender files live in `art-source/blender/`; `art-source/.gdignore` prevents duplicate Godot import. Git LFS tracks `.blend` and `.glb`, and CI checks out LFS content.

`tools/blender/build_assets.py` generates the turret/drone/player family plus the `scrap_shard` pickup (which is centred on its own origin, not the ground) and five static terrain zone props (`zone_*`, merged to one mesh per material, no 2D reference, so their manifest `reference` is empty). Follow the [Blender asset skill](../.claude/skills/blender-assets/SKILL.md) when modifying it: inspect reference images, build with Blender's Python, preserve metre scale and pivots, import, run tests, and inspect native-rendered captures. Models use rigid-part runtime animation, not exported skeleton clips.

`build_assets.py` bevels hard edges (angle-limited, smoothed by angle) and bakes ambient occlusion into a per-corner vertex colour (`COLOR_0`, fixed RNG seed, rest pose). Non-emissive materials also multiply in a seamless 4x4 panel texture (`art-source/blender/textures/panel_detail.png`, generated and cached by the script, one repeat per 0.5 m, cylindrical or box UVs for constant density). Godot extracts it beside each GLB as `<model>_panel_detail.png` on import. `tools/import_vertex_ao.gd` is the import post-script on each `.glb.import` that enables `vertex_color_use_as_albedo`; new model imports need the same `import_script/path`.

The contract is a ground-centred origin, `Aim` and `Muzzle` nodes for weapons, and six `Leg_L/R_0/1/2` pivots for drones. Blender +Y exports to Godot -Z. Geometry/material budgets and reference/source/model paths are recorded in the manifest. `tools/audit_game_resources.py` checks resource and model-record links.

The arena floor is one `PlaneMesh` with `WorldGeometry.floor_material(area, theme)`: a seamless 6.4 m tile per theme from `assets/textures/floor/<theme>/` (`foundry` plates, `concrete` slabs, `grating` wet deck plating). Each `ArenaLayouts` entry names its `theme`, and `ArenaStage.set_floor_theme` swaps it at the start of a run (rim glow too). Regenerate with `python tools/build_floor_textures.py [theme|all] [--preview]` (numpy and Pillow); keep `FLOOR_TILE_METRES` in sync with the script, and keep mipmaps on and `compress/normal_map=1` in the `.import` files. Per-theme metallic lives in `WorldGeometry.FLOOR_METALLIC`. New themes must avoid orange stripes (reserved for the no-build zone) and keep albedo dark and low contrast. Check them with `tools/preview_floor_theme.tscn`.

`FloorDecals` (floor-only render layer) adds a big blotch and seeded stains per theme to hide the tile repeat, plus scorch marks from explosions (24, recycled, cleared each run). `ArenaStage.set_floor_wave` tints the seam lights warmer as waves climb and magenta on boss waves.

## Preserved 2D references and storage

2D artwork remains useful for concept and silhouette references. The separate image-generation web app is unchanged. Image generation can supply reference images for scripted Blender work; this cutover does not add a web-to-3D generation service.

The 2D-era asset configuration stack (`AssetConfigService`, `CollisionProfile`, asset presets) was removed; it remains at the `prototype-2d-final` tag. Collision shapes are built in code (`CombatActor`, `WorldGeometry`).

The former in-game Asset Studio, Sprite2D renderers and live-apply entity adapters were retired with the 2D runtime. Historical workflows can be retrieved from `prototype-2d-final`; they are not supported game UI. User preset files are not deleted or migrated by this change.

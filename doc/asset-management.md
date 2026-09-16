# Asset management

## Native 3D assets

Approved game models and their provenance manifest live in `assets/models/game/`. Editable Blender files live in `art-source/blender/`; `art-source/.gdignore` prevents duplicate Godot import. Git LFS tracks `.blend` and `.glb`, and CI checks out LFS content.

`tools/blender/build_assets.py` generates the six-model turret/drone/player family. Follow the [Blender asset skill](../.claude/skills/blender-assets/SKILL.md) when modifying it: inspect reference images, build with Blender's Python, preserve metre scale and pivots, import, run tests, and inspect native-rendered captures. Models use rigid-part runtime animation, not exported skeleton clips.

The contract is a ground-centred origin, `Aim` and `Muzzle` nodes for weapons, and six `Leg_L/R_0/1/2` pivots for drones. Blender +Y exports to Godot -Z. Geometry/material budgets and reference/source/model paths are recorded in the manifest. `tools/audit_game_resources.py` checks resource and model-record links.

## Preserved 2D references and storage

2D artwork remains useful for concept and silhouette references. The separate image-generation web app is unchanged. Image generation can supply reference images for scripted Blender work; this cutover does not add a web-to-3D generation service.

Typed `AssetVisualConfig`, `AssetCollisionConfig` and `EntityAssetConfig` resources, built-in presets under `resources/asset_presets/`, collision profiles, and `AssetConfigService` storage/resolution/validation remain covered by tests. These are reference-data facilities. They do not configure current CharacterBody3D collision or replace current GLBs.

The former in-game Asset Studio, Sprite2D renderers and live-apply entity adapters were retired with the 2D runtime. Historical workflows can be retrieved from `prototype-2d-final`; they are not supported game UI. User preset files are not deleted or migrated by this change.

# Asset Management

## Overview

The game now uses a unified, data-driven asset system for enemy, turret, and player visuals/collision. This is the backend foundation for future in-game asset customization UI.

Scope in this phase:
- Typed asset config resources
- Built-in named presets in `res://resources/asset_presets/`
- User overrides in `user://asset_presets/`
- Runtime live-apply for spawned entities

Out of scope in this phase:
- In-game preset editor UI
- Turret collision runtime customization (schema exists, runtime deferred)

## Data Model

Typed resources live in `scripts/resources/assets/`.

### AssetVisualConfig
File: `scripts/resources/assets/asset_visual_config.gd`

Defines visual behavior and presentation:
- `sprite_kind`: `STATIC`, `DIRECTIONAL_TEXTURES`, `ANIMATED`
- `orientation_mode`: `FIXED`, `FLIP_X_BY_VELOCITY`, `TEXTURE_LEFT_RIGHT`, `TEXTURE_8_DIR`, `ANIMATED_LEFT_RIGHT`
- `texture_paths`, `sprite_frames_path`, `animation_map`, `animation_speed_fps`
- `scale`, `modulate`, `position_offset`, `anchor_bottom`
- Idle bounce settings (`idle_bounce_enabled`, etc.)

### AssetCollisionConfig
File: `scripts/resources/assets/asset_collision_config.gd`

Defines collision profile wiring:
- `enabled`
- `collision_profile_path`
- `live_apply`

### EntityAssetConfig
File: `scripts/resources/assets/entity_asset_config.gd`

Top-level config for a single asset:
- `entity_kind`: `ENEMY`, `TURRET`, `PLAYER`
- `asset_id`
- `display_name`
- `visual: AssetVisualConfig`
- `collision: AssetCollisionConfig`

## Presets and Overrides

### Built-in presets (`res://`)

Default preset layout:
- `resources/asset_presets/default/enemies/*.tres`
- `resources/asset_presets/default/turrets/*.tres`
- `resources/asset_presets/default/player/main.tres`

Additional built-in presets are sibling folders under:
- `resources/asset_presets/{preset_name}/...`

### User presets (`user://`)

Overrides are stored as config files:
- `user://asset_presets/{preset_name}.cfg`

Sections:
- `[enemy:basic]`
- `[turret:normal]`
- `[player:main]`

Merge precedence:
1. Built-in `default`
2. Active built-in preset (if not `default`)
3. Active user override entries

## AssetConfigService

Autoload file:
- `scripts/autoload/asset_config_service.gd`

Responsibilities:
- Discover and load built-in presets
- Load/save user overrides
- Merge and validate resolved configs
- Provide read/write APIs for runtime and future UI
- Emit live-update events

Core API:
- `get_enemy_config(type_id: String) -> EntityAssetConfig`
- `get_turret_config(type_id: String) -> EntityAssetConfig`
- `get_player_config() -> EntityAssetConfig`
- `list_presets() -> Array[String]`
- `set_active_preset(name: String) -> void`
- `get_active_preset() -> String`
- `upsert_override(entity_kind: int, asset_id: String, patch: Dictionary) -> void`
- `clear_override(entity_kind: int, asset_id: String) -> void`
- `create_user_preset(name: String, clone_from: String = "default") -> void`
- `delete_user_preset(name: String) -> void`

Validation rules:
- Texture/sprite paths must be under `res://assets/`
- Invalid/missing texture paths fall back to base preset values
- Collision profile path must resolve to `CollisionProfile`
- Invalid collision profile falls back to base profile; if none is valid, collision override is disabled

## Events and Live Apply

Signals in `scripts/autoload/events.gd`:
- `asset_preset_changed(preset_name: String)`
- `asset_config_changed(entity_kind: int, asset_id: String)`

Live behavior:
- Enemies refresh visuals/collision when relevant config changes
- Turrets refresh visuals when relevant config changes
- Player refreshes visuals/collision when player config changes

## Runtime Integration Notes

- `EnemyVisuals`, `TurretVisuals`, and `PlayerVisuals` now consume `EntityAssetConfig`.
- `PlayerMovement` is movement-only; visual orientation moved to `PlayerVisuals`.
- `CollisionManager` is now the canonical profile application path for player/enemy collision overrides.
- Registries (`EnemyRegistry`, `TurretRegistry`) remain source of truth for gameplay metadata/stats/spawn behavior, with adapter methods for color/sprite lookups.

## Test Coverage

Primary unit tests:
- `tests/unit/test_asset_config_service.gd`
- `tests/unit/test_asset_config_validation.gd`

Regression coverage includes:
- Registry adaptation (`tests/unit/test_enemy_registry.gd`)
- Existing unit/integration suites for enemy/turret/player runtime behavior

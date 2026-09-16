# Services Reference

This document provides a detailed reference for autoload singletons in `scripts/autoload/`. Group them by domain with file paths and descriptions.

## Overview

The game uses service-oriented architecture with focused autoload singletons. Each service manages a specific domain concern. Services are accessed directly; `SettingsService` exposes compatibility properties for older settings callers, while new runtime gates belong to `FeatureFlagService`. Cross-service communication goes through the `Events` signal bus.

## Core Game State

### DifficultyService
**File:** `scripts/autoload/difficulty_service.gd`
Manages difficulty configuration and multipliers. Stores the selected difficulty level and provides scaling factors for enemy health, damage, scrap rewards, and spawn rates.

### GameStateService
**File:** `scripts/autoload/game_state_service.gd`
Tracks core game state: current wave number, total scrap, kill count, elapsed time, and player level. Central source of truth for game progression data.

### GameStateMachine
**File:** `scripts/autoload/game_state_machine.gd`
Manages game state transitions with validation. 10 states: IDLE, DIFFICULTY_SELECT, GAME_MODE_SELECT, WAVE_ANNOUNCEMENT, COMBAT, WAVE_END, LOOT_REVIEW, SHOP, VICTORY, GAME_OVER. Enforces valid transition paths. See [game-modes.md](game-modes.md) for state flow details.

### GameModeService
**File:** `scripts/autoload/game_mode_service.gd`
Manages the active mode in each registry group and provides mode-specific logic hooks. Modes are validated against `GameModeRegistry` and can only change before an active run. The registry's feature flags control which modes appear in selection screens.

### FeatureFlagService
**File:** `scripts/autoload/feature_flag_service.gd`
Central source of truth for named runtime gates. It exposes defaults, scopes, `is_enabled`, `set_enabled`, `toggle`, and change signals. Existing `SettingsService` properties remain compatibility facades over the corresponding flags. System flags include enemy spawning, tech drops, shop, Asset Studio, reduced motion, and tunneling alert escalation.

## Economy & Progression

### EconomyService
**File:** `scripts/autoload/economy_service.gd`
Manages the scrap economy: earning from kills and wave bonuses, shop offer generation (65% items / 35% turrets), rerolls, and purchases. Handles shop pricing and availability.

`calculate_turret_price(base_price, wave)` owns the shared turret-pricing policy: wave scaling, purchase penalty, item price modifiers, and Quantity Discount. Both `ShopManager` and the [3D proving ground](3d-slice.md) call it.

### ItemTrackingService
**File:** `scripts/autoload/item_tracking_service.gd`
Tracks collected items across the game session. Maintains the player's item inventory and provides lookup capabilities.

### LootService
**File:** `scripts/autoload/loot_service.gd`
Manages item drops from wave completion and the loot review phase. Controls tech drop spawning and item selection based on rarity weights.

## Player & Combat

### PlayerStatsService
**File:** `scripts/autoload/player_stats_service.gd`
Manages player stats: health (with regeneration), movement speed, luck, and critical hit stats. Provides calculated values that incorporate base stats plus modifier bonuses.

### TurretStatsService
**File:** `scripts/autoload/turret_stats_service.gd`
Manages turret counts, type diversity tracking, stat calculation that incorporates modifiers and buffs, and purchase price penalties for multiple turrets of the same type.

### ModifierService
**File:** `scripts/autoload/modifier_service.gd`
Autoload wrapper for ModifierSystem. Manages permanent stat modifications applied by items and tech upgrades. See [combat.md](combat.md) for modifier system details.

### AssetConfigService
**File:** `scripts/autoload/asset_config_service.gd`
Unified asset configuration service for enemy/turret/player visuals and collision profiles. Loads built-in presets from `res://resources/asset_presets/`, merges user overrides from `user://asset_presets/`, validates paths, and emits live update events. See [asset-management.md](asset-management.md) for data model and API details.

## Progression & Tech

### TechTreeService
**File:** `scripts/autoload/tech_tree_service.gd`
Manages research points, tech tree unlock progression, turret type unlocks, and shop modifiers. Supports 6 tech paths: turret_offense, turret_utility, turret_unlock, player_combat, player_defense, economy.

## Environment & Presentation

### ArenaBoundsService
**File:** `scripts/autoload/arena_bounds_service.gd`
Handles arena geometry for both rectangular and isometric diamond bounds. Provides boundary checking for movement clamping and spawn zone placement.

### SettingsService
**File:** `scripts/autoload/settings_service.gd`
Manages runtime settings and debug flags. Provides configuration for game options and developer tools.

### FontSizes
**File:** `scripts/autoload/font_sizes.gd`
Centralized font size management with dynamic theme updates. Provides semantic font sizes used by Theme Variations across the UI system. See [ui.md](ui.md) for font system details.

### UIScaler
**File:** `scripts/autoload/ui_scaler.gd`
Dynamic UI scaling engine that coordinates with FontSizes to maintain consistent UI proportions across different resolutions and screen sizes.

### OffScreenIndicatorService
**File:** `scripts/autoload/off_screen_indicator_service.gd`
Manages off-screen indicators for enemies, objectives, and other tracked entities. Provides directional arrows pointing to off-screen objects of interest.

### AudioService
**File:** `scripts/autoload/audio_service.gd`
Sound effect playback with object pooling for performance. Includes hit sound variations and manages concurrent audio streams.

## Development

### DebugService
**File:** `scripts/autoload/debug_service.gd`
Compile-time debug output management with 7 category flags (ENTITY, COMBAT, AI, ARENA, UI, SYSTEMS, VALIDATION). Zero runtime overhead — disabled categories are optimized away by the GDScript compiler. See [development.md](development.md) for usage details.

### Events
**File:** `scripts/autoload/events.gd`
Signal bus for all cross-system communication. Defines signals covering: Game State, Waves, Combat, Turrets, Pickups, Tech Drops, Economy, Shop, Items, Loot, UI, Defense Mode, and Player Progression. No direct service-to-service calls — everything routes through Events.

## Special Systems

### SpecialEffectService
**File:** `scripts/autoload/special_effect_service.gd`
Handles complex item effects that span multiple systems, including proximity-based turret logic and conditional triggers.

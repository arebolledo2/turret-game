# Turret Game - AI Agent Instructions

Wave-based survival tower defense game built in **Godot 4.5** using GDScript. Player dodges enemies while turrets provide primary damage. Purchase turrets and items between waves using scrap earned from kills.

## Quick Reference

- **Engine**: Godot 4.5
- **Language**: GDScript with static typing
- **Architecture**: Service-oriented with event bus pattern
- **Key Pattern**: Signal bus (`Events`) for all cross-system communication
- **Tests**: GUT framework - run with `.\run_tests.ps1`
- **Launch**: `.\launch.ps1`
- **Commit Style**: Single emoji prefix (e.g., `✨ Add feature`, `🐛 Fix bug`)

## Architecture

### Service-Oriented Architecture
Game logic split into **focused service singletons** in `scripts/autoload/`:

**Core Game State:**
- **DifficultyService** - Difficulty config and multipliers
- **GameStateService** - Wave number, scrap, kills, time, level
- **GameStateMachine** - State transitions with validation
- **GameModeService** - Active game mode and mode-specific logic hooks

**Economy & Progression:**
- **EconomyService** - Scrap, shop offers, rerolls, purchases
- **ItemTrackingService** - Item collection tracking
- **LootService** - Manages item drops and loot review

**Player & Combat:**
- **PlayerStatsService** - Player health (with regen), speed, luck, and crit stats
- **TurretStatsService** - Turret counts, diversity, stat calculation with modifiers, and purchase penalties
- **ModifierService** - Active modifiers management (uses ModifierSystem class)

**Progression & Tech:**
- **TechTreeService** - Research points, tech tree unlocks, turret type unlocks, and shop modifiers

**Environment & Presentation:**
- **ArenaBoundsService** - Arena geometry (rectangular vs isometric bounds)
- **SettingsService** - Runtime settings and debug flags
- **FontSizes** - Centralized font size management with dynamic theme updates
- **UIScaler** - Dynamic UI scaling engine coordinating with FontSizes
- **OffScreenIndicatorService** - Off-screen enemy and object indicators
- **AudioService** - Sound effects with object pooling and hit sound variations

**Development:**
- **DebugService** - Compile-time debug output management with category flags
- **Events** - Signal bus for cross-system communication

**Special Systems:**
- **SpecialEffectService** - Complex item effects and proximity-based turret logic

All code uses services directly. No facade pattern.

### Signal Bus Pattern
**All cross-system communication** uses the `Events` autoload (`scripts/autoload/events.gd`). The signal bus covers Game State, Waves, Combat, Turrets, Pickups, Tech Drops, Economy, Shop, Items, Loot, UI, Defense Mode, and Player Progression with signals for all major game events.

### Registry Pattern
Type definitions stored in **static registry classes**:

- **EnemyRegistry** (`scripts/registries/enemy_registry.gd`) - Enemy type definitions (basic, tank, lazy_wanderer, charger, lazy_shooter)
- **TurretRegistry** (`scripts/registries/turret_registry.gd`) - Turret type definitions (normal, sniper, fire, plasma, shock, tesla, melee, mine)
- **ItemRegistry** (`scripts/registries/item_registry.gd`) - Item definitions across 5 rarity tiers
- **TechRegistry** (`scripts/registries/tech_registry.gd`) - Tech tree definitions across 6 paths (turret_offense, turret_utility, turret_unlock, player_combat, player_defense, economy)
- **GameModeRegistry** (`scripts/registries/game_mode_registry.gd`) - Game mode definitions and categories

### Component-Based Player System
Player (`scripts/player.gd`) delegates to **behavior components** (plus PlayerHurtbox for damage receipt):

- **PlayerMovement** - Input, speed, and arena bounds clamping
- **PlayerCombat** - Auto-fire targeting and projectile spawning
- **PlayerTurretHandler** - Turret pickup, carry, and placement logic
- **PlayerHurtbox** - Damage receipt from enemy hurtboxes with collision validation

### Modifier & Buff Systems
- **ModifierService**: Autoload wrapper for ModifierSystem. Manages permanent stat modifications.
- **ModifierSystem** (`scripts/systems/modifier_system.gd`): Core modifier logic using PoE-style stacking (add/increase/more operations) with filter support (turret_type, damage_type, attack_style, entity_type).
- **BuffSystem** (`scripts/systems/buff_system.gd`): Manages temporary, stackable, time-based buffs per turret instance.

### Entity Component Systems
**Enemy Components** (in `scripts/components/`):
- **EnemyMovement** - Movement patterns with behavior system integration
- **EnemyCombat** - Projectile and ranged attack handling
- **EnemyStatusEffects** - DoT, slow, and other status effect tracking
- **EnemyVisuals** - Sprite animation, damage flash, and death effects
- **EnemyHurtbox** - Collision and damage receipt validation

**Turret Components**:
- **TurretCombat** (`scripts/components/turret_combat.gd`) - All attack logic (projectile, instant, AOE, chain, melee, deployable)
- **TurretVisuals** (`scripts/components/turret_visuals.gd`) - Sprite animation, rotation, and visual effects

**Enemy Behaviors** (in `scripts/components/behaviors/`):
- **EnemyBehavior** - Base class for enemy AI behaviors
- **ChaseBehavior** - Direct pursuit of player
- **WanderBehavior** - Random wandering movement
- **ChargeBehavior** - Wander until player is close, then charge aggressively

### Modular Item System
Items organized by rarity in `scripts/registries/items/`:
- **Common** (`common_items.gd`)
- **Uncommon** (`uncommon_items.gd`)
- **Rare** (`rare_items.gd`)
- **Epic** (`epic_items.gd`)
- **Legendary** (`legendary_items.gd`)

### Core Coordinators
Key manager scripts that coordinate between services:

- **WaveController** (`scripts/wave_controller.gd`) - Orchestrates wave timing, progression, and spawning coordination
- **GameModeEntitySpawner** (`scripts/game_mode_entity_spawner.gd`) - Spawns game-mode-specific entities
- **ArenaSetup** (`scripts/arena_setup.gd`) - Arena configuration and initialization
- **CameraSetup** (`scripts/camera_setup.gd`) - Camera system with gamepad zoom support

### Key Gameplay Entities
Core game entities spawned during gameplay:

- **DefenseTarget** (`scripts/defense_target.gd`) - Core entity for Tech Defense and Escort modes with barrier mechanics, reflection damage, and healing
- **TunnelDoor** (`scripts/tunnel_door.gd`) - Breachable door entity for Tunneling game mode
- **ScrapDrop** (`scripts/scrap_drop.gd`) - Scrap pickups with magnet-based collection
- **TechDrop** (`scripts/tech_drop.gd`) - Item drops from wave completion with loot review
- **ItemPickup** (`scripts/item_pickup.gd`) - Collectible item drops

### Combat & Visual Systems
- **Projectile System** - Supports pierce, AOE, DoT, knockback, and chain damage mechanics
- **Crit System** - Player combat includes critical hit calculations with visual feedback
- **Status Effects** - Component-based status effect handling on enemies
- **Barrier System** - DefenseTarget barrier with activation, cooldown, and visual representation
- **Range Indicators** (`scripts/range_indicator.gd`) - Visual turret range display (togglable)
- **Damage Numbers** (`scripts/damage_number.gd`) - Floating damage text with centralized font scaling
- **Off-Screen Indicators** - UI system for tracking off-screen enemies and objectives

### UI Architecture
UI components organized by function:

**Core HUD**: HUDGameDisplay (health, wave, scrap), HUDMenuManager (menu states)

**Screens**: StartSettings, GameModeSelect, DifficultySelect, WaveAnnouncement, PauseMenu, GameOverScreen, SettingsMenu, LootReviewScreen

**Shop Components**: ShopOffersPanel, TechTreePanel, TechNodeButton, EconomyTab, PlayerTab, ItemsTab, TurretsTab

**Display Panels**: TurretDisplayUI, ItemDisplayUI, BuildDisplayUI, DefenseTargetHP, TunnelDoorProgress

**Utilities**: UIHelpers, ScalableUIPanel (dynamic scaling), InventoryPanel, StatsPanel, OffScreenIndicators

**Font System**: Centralized system using `FontSizes` service. UI components use semantic **Theme Variations** (`Header1`-`Header4`, `Body`, `BodySmall`, `ButtonLarge`, etc.) instead of manual size overrides.

## Core Systems

### Game State Machine
Game flow is managed by **GameStateMachine** (`scripts/autoload/game_state_machine.gd`) with **10 states**:
IDLE, DIFFICULTY_SELECT, GAME_MODE_SELECT, WAVE_ANNOUNCEMENT, COMBAT, WAVE_END, LOOT_REVIEW, SHOP, VICTORY, GAME_OVER.

### Wave Cycle & Progression
1. **WAVE_ANNOUNCEMENT**: Brief wave number display.
2. **COMBAT**: Enemy and tech drop spawning based on wave scaling.
3. **WAVE_END**: Spawning stops, wave bonus awarded.
4. **LOOT_REVIEW**: Review and collect items from tech drops.
5. **SHOP**: Purchase turrets and items between waves.

### Economy & Combat
- **Economy**: Scrap from kills, wave bonuses, and tech drops. Shop offers are weighted (65% items, 35% turrets).
- **Combat**: Nearest-neighbor targeting for player/turrets. Includes status effects (DoT, slow), area-of-effect damage, and chain lightning.
- **Arena Bounds**: `ArenaBoundsService` handles both rectangular and isometric diamond bounds for movement and spawning.

### Game Mode Features
The game supports multiple game modes with unique mechanics:

**Escort Mode**: DefenseTarget follows curve-based paths with proximity movement constraints. Completion triggered by `escort_reached_destination` event when target reaches destination.

**Tech Defense**: DefenseTarget with barrier mechanics (activation, cooldown, healing) and reflection damage. Protect the target from enemy attacks while it remains stationary.

**Tunneling Mode**: TunnelDoor entities must be damaged by turrets to breach and complete waves. Doors have progressive health that must be depleted.

## Development Workflow

### File Guide
- **Balance**: `scripts/data/game_constants.gd`, `GameConstants.DIFFICULTY_CONFIG`
- **Logic**: `scripts/autoload/` (Services), `scripts/registries/` (Definitions)
- **Behaviors**: `scripts/turret.gd`, `scripts/enemy.gd`, `scripts/components/`
- **UI**: `scripts/hud.gd`, `scripts/ui/`
- **Tests**: `tests/unit/`, `tests/integration/` (using GUT)
- **Debug**: `scripts/autoload/debug_service.gd` (Compile-time debug output management)

### Debug Output Management
**DebugService** provides compile-time debug output control with 7 categories:

- **ENTITY** - Entity lifecycle (enemies, turrets, defense targets)
- **COMBAT** - Combat mechanics (damage, collisions, projectiles)
- **AI** - Enemy AI and movement
- **ARENA** - Arena setup and configuration
- **UI** - User interface systems
- **SYSTEMS** - Core game systems (state machine, spawning)
- **VALIDATION** - Warnings and errors (default: enabled)

**Usage:**
```gdscript
DebugService.log(DebugService.ENTITY, "Enemy spawned at: ", position)
DebugService.warn(DebugService.VALIDATION, "Missing component")
DebugService.error(DebugService.VALIDATION, "Invalid state")
```

**Control output** by editing const flags in `scripts/autoload/debug_service.gd`:
```gdscript
const ENABLED: bool = true      # Master switch
const ENTITY: bool = true       # Enable/disable ENTITY logs
const COMBAT: bool = false      # Enable/disable COMBAT logs
# ... etc
```

Zero runtime overhead - disabled categories are optimized away by the GDScript compiler.

### Commands
- **Launch**: `.\launch.ps1`
- **Test**: `.\run_tests.ps1` (supports `-unit`, `-integration`, `-filter`)

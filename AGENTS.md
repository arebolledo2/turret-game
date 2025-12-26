# Turret Game - AI Agent Instructions

Wave-based survival tower defense game built in **Godot 4.5** using GDScript. Player dodges enemies while turrets provide primary damage. Purchase turrets and items between waves using gold earned from kills.

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
Game logic split into **11 focused service singletons** in `scripts/autoload/`:

1. **DifficultyService** - Difficulty config and multipliers
2. **GameStateService** - Wave number, XP, kills, time, level
3. **EconomyService** - Gold, shop offers, rerolls, purchases
4. **PlayerStatsService** - Player health, speed, luck
5. **TurretStatsService** - Turret counts, stat calculation
6. **ItemTrackingService** - Item collection tracking
7. **ModifierService** - Active modifiers management
8. **GameModeService** - Active game mode and mode-specific logic hooks
9. **ArenaBoundsService** - Arena geometry (rectangular vs isometric bounds)
10. **LootService** - Manages item drops and loot review
11. **UIScaler** - Dynamic UI scaling and layout adjustments

**Globals as Facade**: `scripts/autoload/globals.gd` provides a compatibility layer delegating to services. Use services directly for new code.

### Signal Bus Pattern
**All cross-system communication** uses the `Events` autoload (`scripts/autoload/events.gd`). Approximately **48 signals** cover Game State, Waves, Combat, Turrets, Pickups, Tech Drops, Economy, Shop, Items, Loot, UI, and Player Progression.

### Registry Pattern
Type definitions stored in **static registry classes**:

- **EnemyRegistry** (`scripts/registries/enemy_registry.gd`) - 7 enemy types (basic, fast, tank, exploder, lazy_wanderer, charger, neon_drone)
- **TurretRegistry** (`scripts/registries/turret_registry.gd`) - 6 turret types (normal, sniper, fire, plasma, shock, tesla)
- **ItemRegistry** (`scripts/registries/item_registry.gd`) - 53 items total across 5 rarity tiers
- **GameModeRegistry** (`scripts/registries/game_mode_registry.gd`) - Game mode definitions and categories

### Component-Based Player System
Player (`scripts/player.gd`) delegates to **4 component nodes**:

1. **PlayerMovement** - Input, speed, and arena bounds clamping
2. **PlayerCombat** - Auto-fire targeting and projectile spawning
3. **PlayerMeleeCombat** - Melee attack with windup, arc damage, and knockback
4. **PlayerTurretHandler** - Turret pickup, carry, and placement logic

### Modifier & Buff Systems
- **ModifierService**: Manages permanent stat modifications (add/multiply) with filter support (turret_type, damage_type, etc.).
- **BuffSystem** (`scripts/systems/buff_system.gd`): Manages temporary, stackable, time-based buffs per turret instance.

### Modular Item System
Items organized by rarity in `scripts/registries/items/`:
- **Common**: 16 items
- **Uncommon**: 10 items
- **Rare**: 14 items
- **Epic**: 9 items
- **Legendary**: 4 items

## Core Systems

### Game State Machine
Game flow is managed by **GameState理论基础Machine** (`scripts/autoload/game_state_machine.gd`) with **10 states**:
IDLE, DIFFICULTY_SELECT, GAME_MODE_SELECT, WAVE_ANNOUNCEMENT, COMBAT, WAVE_END, LOOT_REVIEW, SHOP, VICTORY, GAME_OVER.

### Wave Cycle & Progression
1. **WAVE_ANNOUNCEMENT**: Brief wave number display.
2. **COMBAT**: Enemy and tech drop spawning based on wave scaling.
3. **WAVE_END**: Spawning stops, wave bonus awarded.
4. **LOOT_REVIEW**: Review and collect items from tech drops.
5. **SHOP**: Purchase turrets and items between waves.

### Economy & Combat
- **Economy**: Gold from kills, wave bonuses, and tech drops. Shop offers are weighted (65% items, 35% turrets).
- **Combat**: Nearest-neighbor targeting for player/turrets. Includes status effects (DoT, slow), area-of-effect damage, and chain lightning.
- **Arena Bounds**: `ArenaBoundsService` handles both rectangular and isometric diamond bounds for movement and spawning.

## Development Workflow

### File Guide
- **Balance**: `scripts/data/game_constants.gd`, `GameConstants.DIFFICULTY_CONFIG`
- **Logic**: `scripts/autoload/` (Services), `scripts/registries/` (Definitions)
- **Behaviors**: `scripts/turret.gd`, `scripts/enemy.gd`, `scripts/components/`
- **UI**: `scripts/hud.gd`, `scripts/ui/`
- **Tests**: `tests/unit/`, `tests/integration/` (using GUT)

### Commands
- **Launch**: `.\launch.ps1`
- **Test**: `.\run_tests.ps1` (supports `-unit`, `-integration`, `-filter`)

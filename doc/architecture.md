# Architecture

This document covers the high-level architectural patterns used in the game.

## Overview

Game logic is split into focused service singletons (autoloads), with all cross-system communication using the Events signal bus. Type definitions live in static registries. Player, enemy, and turret entities use component-based architecture. No facade pattern — code accesses services directly.

## Service-Oriented Architecture

Game logic split into **focused service singletons** in `scripts/autoload/`. Grouped by domain:

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

> **Note:** All code uses services directly. No facade pattern. See [services.md](services.md) for detailed service documentation.

## Signal Bus Pattern

**All cross-system communication** uses the `Events` autoload (`scripts/autoload/events.gd`). No direct service-to-service calls for cross-cutting concerns.

Signal categories: Game State, Waves, Combat, Turrets, Pickups, Tech Drops, Economy, Shop, Items, Loot, UI, Defense Mode, Player Progression.

## Registry Pattern

Type definitions stored in **static registry classes** in `scripts/registries/`:

- **EnemyRegistry** (`enemy_registry.gd`) - Enemy type definitions (basic, fast, tank, lazy_wanderer, charger, neon_drone, lazy_shooter)
- **TurretRegistry** (`turret_registry.gd`) - Turret type definitions (normal, sniper, fire, plasma, shock, tesla, melee, mine)
- **ItemRegistry** (`item_registry.gd`) - Item definitions across 5 rarity tiers, delegating to `items/` subdirectory
- **TechRegistry** (`tech_registry.gd`) - Tech tree definitions across 6 paths, delegating to `techs/` subdirectory
- **GameModeRegistry** (`game_mode_registry.gd`) - Game mode definitions and categories

## Component-Based Player System

Player (`scripts/player.gd`) delegates to **behavior components** (plus PlayerHurtbox for damage receipt):

- **PlayerMovement** (`scripts/components/player_movement.gd`) - Input, speed, and arena bounds clamping
- **PlayerCombat** (`scripts/components/player_combat.gd`) - Auto-fire targeting and projectile spawning
- **PlayerTurretHandler** (`scripts/components/player_turret_handler.gd`) - Turret pickup, carry, and placement logic
- **PlayerHurtbox** (`scripts/components/player_hurtbox.gd`) - Damage receipt from enemy hurtboxes with collision validation

## Core Coordinators

Key manager scripts that coordinate between services:

- **GameManager** (`scripts/game_manager.gd`) - Top-level orchestrator; creates and wires WaveController, EnemySpawner, and GameModeEntitySpawner
- **WaveController** (`scripts/wave_controller.gd`) - Orchestrates wave timing, progression, and spawning coordination
- **EnemySpawner** (`scripts/enemy_spawner.gd`) - Spawn zones, queues, and wave-based enemy spawning
- **TurretManager** (`scripts/turret_manager.gd`) - Turret spawning, placement constraints, and stat updates
- **ShopManager** (`scripts/shop_manager.gd`) - Shop offer generation, locked offers, and session dedup
- **GameModeEntitySpawner** (`scripts/game_mode_entity_spawner.gd`) - Spawns game-mode-specific entities
- **ArenaSetup** (`scripts/arena_setup.gd`) - Arena configuration and initialization
- **CameraSetup** (`scripts/camera_setup.gd`) - Camera system with gamepad zoom support

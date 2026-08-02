# Game State & Modes

## Overview

The game uses a state machine with 10 states to manage flow from menus through combat waves and shop phases. Game modes are grouped into spawn location, win condition, and arena type selections. Core coordinators (managers) orchestrate spawning, wave progression, and entity lifecycle.

## Game State Machine

**File:** `scripts/autoload/game_state_machine.gd`

Game flow managed by GameStateMachine with **10 states**:

```
IDLE → DIFFICULTY_SELECT → GAME_MODE_SELECT → WAVE_ANNOUNCEMENT → COMBAT → WAVE_END → LOOT_REVIEW → SHOP → (loop back to WAVE_ANNOUNCEMENT or → VICTORY/GAME_OVER)
```

| State | Description |
| --- | --- |
| IDLE | Initial state, main menu |
| DIFFICULTY_SELECT | Player chooses difficulty level |
| GAME_MODE_SELECT | Player chooses game mode |
| WAVE_ANNOUNCEMENT | Brief wave number display before combat |
| COMBAT | Active gameplay — enemies spawn, player and turrets fight |
| WAVE_END | All enemies defeated, wave bonus awarded |
| LOOT_REVIEW | Review and collect items from tech drops |
| SHOP | Purchase turrets and items between waves |
| VICTORY | All waves completed successfully |
| GAME_OVER | Player health depleted or defense target destroyed |

State transitions are validated — only allowed transitions are permitted.

## Wave Cycle

Each wave follows a 5-step cycle:

1. **WAVE_ANNOUNCEMENT** — Brief wave number display
2. **COMBAT** — Enemy and tech drop spawning based on wave scaling
3. **WAVE_END** — Spawning stops, wave bonus awarded
4. **LOOT_REVIEW** — Review and collect items from tech drops
5. **SHOP** — Purchase turrets and items between waves

After the shop phase, the cycle repeats with the next wave announcement until all waves are completed (VICTORY) or the player dies (GAME_OVER).

## Game Modes

### Escort Mode

DefenseTarget follows **curve-based paths** with proximity movement constraints. The target only advances when the player is nearby. Completion triggered by `escort_reached_destination` event when the target reaches its destination. Failure if the DefenseTarget is destroyed.

### Tech Defense

DefenseTarget with **barrier mechanics** remains stationary. Barrier features:

- Activation when enemies approach
- Cooldown between activations
- Healing over time
- Reflection damage against attackers

Protect the target from enemy attacks. Failure if the DefenseTarget is destroyed.

### Tunneling Mode

**TunnelDoor** entities must be damaged by turrets to breach and complete the wave. Doors have progressive health that must be fully depleted before the wave timer expires; surviving the timer without a breach is a loss. Alert mode additionally accelerates enemy spawn intervals every configured escalation interval, controlled by the `tunneling_alert_escalation` feature flag.

The registry currently exposes two spawn-location modes, five win-condition modes, and two arena modes. Each mode has a feature flag and is selected before a run begins. Runtime mode changes during combat are rejected because entity lifecycle and win-condition setup are run-scoped. Game modes are defined in **GameModeRegistry** (`scripts/registries/game_mode_registry.gd`) and managed by **GameModeService** (`scripts/autoload/game_mode_service.gd`).

## Core Coordinators

Key manager scripts that coordinate between services during gameplay:

### GameManager

**File:** `scripts/game_manager.gd`

Top-level orchestrator. Creates and wires WaveController, EnemySpawner, and GameModeEntitySpawner. Entry point for gameplay initialization.

### WaveController

**File:** `scripts/wave_controller.gd`

Orchestrates wave timing, progression, and spawning coordination. Manages the transition between wave phases and scales difficulty based on wave number.

### EnemySpawner

**File:** `scripts/enemy_spawner.gd`

Manages spawn zones, spawn queues, and wave-based enemy spawning. Determines which enemy types spawn per wave and at what rate.

### TurretManager

**File:** `scripts/turret_manager.gd`

Handles turret spawning, placement constraint validation, and stat update propagation when modifiers change.

### ShopManager

**File:** `scripts/shop_manager.gd`

Generates shop offers with weighted randomization (65% items / 35% turrets). Manages locked offers and session deduplication to avoid repeat offers.

### GameModeEntitySpawner

**File:** `scripts/game_mode_entity_spawner.gd`

Spawns game-mode-specific entities (DefenseTarget for Escort and Tech Defense, TunnelDoor for Tunneling).

### ArenaSetup

**File:** `scripts/arena_setup.gd`

Configures and initializes the arena, including boundary geometry.

### CameraSetup

**File:** `scripts/camera_setup.gd`

Camera system with gamepad zoom support and arena-relative positioning.

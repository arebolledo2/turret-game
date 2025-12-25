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

### Service-Oriented Architecture (Dec 2025 Refactor)

Game logic split into **8 focused service singletons** in `scripts/autoload/`:

1. **DifficultyService** - Difficulty config and multipliers
2. **GameStateService** - Wave number, XP, kills, time, level
3. **EconomyService** - Gold, shop offers, rerolls, purchases
4. **PlayerStatsService** - Player health, speed, luck (with modifier support)
5. **TurretStatsService** - Turret counts, stat calculation
6. **ItemTrackingService** - Item collection tracking
7. **ModifierService** - Active modifiers management
8. **GameModeService** - Active game mode and mode-specific logic hooks

**Globals as Facade**: `scripts/autoload/globals.gd` provides compatibility layer that delegates to services. Use services directly for new code, Globals for legacy compatibility.

```gdscript
# Preferred (direct service access)
var wave = GameStateService.current_wave
var gold = EconomyService.gold
var config = DifficultyService.get_config()

# Legacy (still works - delegates to services)
var wave = Globals.current_wave
var gold = Globals.gold
```

### Signal Bus Pattern (Event-Driven)

**All cross-system communication** uses `Events` autoload (`scripts/autoload/events.gd`). **Never** use direct node references.

```gdscript
# Emitting events
Events.enemy_killed.emit(enemy, global_position)
Events.gold_collected.emit(amount)

# Subscribing in _ready()
Events.player_damaged.connect(_on_player_damaged)
```

**37 signals across 9 categories**: Game State, Waves, Combat, Turrets, Pickups, Tech Drops, Economy, Shop, UI, Progression

### Registry Pattern

Type definitions stored in **static registry classes** (extends RefCounted):

- **EnemyRegistry** (`scripts/registries/enemy_registry.gd`) - 7 enemy types with behaviors, stats, spawn rules
- **TurretRegistry** (`scripts/registries/turret_registry.gd`) - 6 turret types with attack styles, damage types, stats
- **ItemRegistry** (`scripts/registries/item_registry.gd`) - 54 items across 5 rarity tiers (see Modular Item System)
- **GameModeRegistry** (`scripts/registries/game_mode_registry.gd`) - Game mode definitions grouped by category (e.g., spawn_location)

```gdscript
# Get type definitions
var enemy_def = EnemyRegistry.get_type("neon_drone")
var turret_def = TurretRegistry.get_type("plasma")
var item = ItemRegistry.get_item("plasma_accelerator")

# Get stats (wave-scaled for enemies)
var enemy_stats = EnemyRegistry.get_stats_for_wave("neon_drone", wave, difficulty_config)
var turret_stats = TurretRegistry.get_base_stats("fire")
var price = TurretRegistry.get_base_price("sniper")
```

### Component-Based Player System

Player (`scripts/player.gd`) delegates to **4 component nodes**:

1. **PlayerMovement** - WASD/gamepad input, speed, arena bounds clamping
2. **PlayerCombat** - Auto-fire targeting, projectile spawning, weapon stats
3. **PlayerMeleeCombat** - Melee attack with windup, arc damage, knockback
4. **PlayerTurretHandler** - Turret pickup, carry, placement logic

Components initialized via dependency injection:
```gdscript
# In player.gd _ready()
movement_component.initialize(self)
combat_component.initialize(self)
```

### Modifier System

**Permanent stat modifications** managed by `ModifierService` (`scripts/autoload/modifier_service.gd`):

- **Filter-based**: Apply to specific turret_type, damage_type, or attack_style
- **Operations**: "add" and "multiply"
- **Application order**: All adds first, then all multipliers
- **Special effects**: Dynamic modifiers based on game state (proximity, diversity, turret count)

```gdscript
# Add modifier from item
ModifierService.add_modifier({
    "stat": "damage",
    "operation": "multiply",
    "value": 1.15,
    "filters": {"damage_type": GameEnums.DamageType.FIRE},
    "source": "item_name"
})

# Get modified stats
var stats = TurretStatsService.get_turret_stats(turret_type)  # Includes modifiers
```

### Buff System (Temporary Modifiers)

**Time-based buffs** managed by `BuffSystem` (`scripts/systems/buff_system.gd`):

- **Instance-based**: Track buffs per turret_id
- **Stacking support**: Max stacks per buff type (e.g., Chain Reaction: 5 stacks)
- **Duration**: Auto-expire when timer reaches zero

```gdscript
# Apply buff (e.g., from Chain Reaction item)
BuffSystem.apply_buff(turret_id, "chain_reaction_fire_rate", {
    "stat": "fire_rate",
    "operation": "multiply",
    "value": 1.05,
    "duration": 3.0,
    "max_stacks": 5
})
```

### Modular Item System

Items split across **5 rarity-tier files** in `scripts/registries/items/`:

- `common_items.gd` - 17 items
- `uncommon_items.gd` - 10 items
- `rare_items.gd` - 14 items
- `epic_items.gd` - 9 items
- `legendary_items.gd` - 4 items

**Item base class**: `items/item_base.gd` (extends Resource)

```gdscript
# Item structure
{
    "name": "Plasma Accelerator",
    "description": "Plasma turrets fire 15% faster",
    "rarity": GameEnums.ItemRarity.UNCOMMON,
    "icon": "res://path/to/icon.png",
    "modifiers": [{
        "stat": "fire_rate",
        "operation": "multiply",
        "value": 1.15,
        "filters": {"turret_type": "plasma"}
    }]
}
```

**Special effect categories**: Proximity (range-based), Diversity (unique types bonus), Turret count scaling, Shop discounts

## Core Systems

### Game State Machine

`GameManager` (`scripts/game_manager.gd`) controls flow via enum:

```
IDLE → DIFFICULTY_SELECT → GAME_MODE_SELECT → WAVE_ANNOUNCEMENT → COMBAT → WAVE_END → SHOP → (loop or VICTORY/GAME_OVER)
```

**Startup Flow**:
1. `show_difficulty_select()` - Player chooses Easy/Medium/Hard
2. `show_game_mode_select()` - Player chooses game mode (e.g., Sentinel/Invasion)
3. `start_game()` - Resets stats, spawns free starting turret
4. Proceeds directly to wave 1 announcement

**Wave Cycle**:
1. `WAVE_ANNOUNCEMENT` (1.5s) - Shows wave number
2. `COMBAT` - Enemy spawning with visual alerts, wave timer
3. `WAVE_END` - Stops spawning, awards wave bonus gold
4. `SHOP` - Show shop UI (appears after wave 1+, not before wave 1)
5. Player closes shop → Spawn purchased turrets → Next wave

**Victory/Loss**:
- Victory: Complete wave 10
- Game Over: Player health reaches 0

**Wave Scaling**:
```gdscript
# Wave duration
duration = 25 + (wave - 1) * 4  # seconds

# Enemy count
count = (10 + (wave - 1) * 4) * difficulty_mult * item_mult

# Spawn interval
interval = duration / count
```

### Economy System

**Gold sources**:
- Enemy kills: Base XP value per enemy type
- Wave completion bonus: Scales with wave number
- Tech drops: Destructible pickups (20% spawn chance every 5s during combat)

**Shop system** (`scripts/shop_manager.gd`):
- **Offer mix**: 65% items, 35% turrets (configurable via `GameConstants.SHOP_ITEM_CHANCE`)
- **Offer count**: Configurable (default: 4-5 offers)
- **Reroll system**: Base cost + increment per reroll, max 5 per wave
- **Price scaling**: Wave-based + turret ownership penalty

```gdscript
# Shop signals
Events.shop_opened.emit()
Events.shop_purchase_made.emit(offer_type, offer_data)
Events.shop_rerolled.emit(cost)
Events.shop_closed.emit()
```

### Combat Systems

**Player Auto-Fire**:
- Targets nearest enemy within weapon range
- Fires projectiles automatically
- Configurable: damage, fire_rate, range, projectile_speed (see `GameConstants.PLAYER_WEAPON_*`)

**Player Melee Attack**:
- Windup animation with target lock
- Arc-based damage cone (configurable angle)
- Knockback effect on hit enemies
- Cooldown-based (configurable duration)
- Useful for crowd control and defense

**Turret Targeting**:
- Default: Nearest enemy
- Special: "farthest" (Sniper), "cluster" (AOE turrets)
- Auto-rotation toward target

**Status Effects** (`scripts/status_effect.gd`):
```gdscript
# Apply DoT
enemy.apply_status_effect("fire", dot_damage, duration)

# Check status
if enemy.has_status_effect("fire"):
    # Enemy is burning
```
**Stacking rule**: Strongest DoT per type wins, duration refreshes

**Defensive Pulse**:
- Triggers on player damage taken
- Knockback radius: 120px, force: 250
- Visual: Golden ring effect

### Difficulty System

Three levels with multipliers defined in `GameConstants.DIFFICULTY_CONFIG`:

- **Easy**: Lower enemy stats, higher player/turret stats
- **Medium**: Balanced baseline
- **Hard**: Higher enemy stats, lower player/turret stats

Access via `DifficultyService.get_config()` or `Globals.get_difficulty_config()`

### Scene Tree Structure

```
Main (main.tscn)
├── Player, EnemySpawner, TurretManager, ShopManager, GameManager
├── TurretContainer/  (turrets added here)
├── EnemyContainer/   (enemies spawned here)
└── HUD (CanvasLayer)
    └── UI components (orchestrated by hud.gd)
```

**Entity Groups** (for querying):
```gdscript
var enemies = get_tree().get_nodes_in_group("enemies")
var player = get_tree().get_first_node_in_group("player")
var turrets = get_tree().get_nodes_in_group("turrets")
```

## Task-Based File Guide

### Modifying Game Balance
| What | Files |
|------|-------|
| Constants (health, damage, gold, etc.) | `scripts/data/game_constants.gd` |
| Arena bounds (width/height) | `GameConstants.ARENA_WIDTH/HEIGHT` (auto-applied) |
| Difficulty multipliers | `GameConstants.DIFFICULTY_CONFIG` |
| Wave duration/enemy count formulas | `scripts/game_manager.gd` (see `start_combat()`) |

### Adding/Modifying Entity Types
| What | Files |
|------|-------|
| Enemy types and stats | `scripts/registries/enemy_registry.gd` |
| Turret types and stats | `scripts/registries/turret_registry.gd` |
| Items (by rarity) | `scripts/registries/items/[rarity]_items.gd` |
| Enum types | `scripts/data/game_enums.gd` |

### Modifying Core Systems
| What | Files |
|------|-------|
| Modifier logic | `scripts/autoload/modifier_service.gd` |
| Buff logic | `scripts/autoload/buff_system.gd` |
| Game state (wave, XP, kills) | `scripts/autoload/game_state_service.gd` |
| Economy (gold, shop) | `scripts/autoload/economy_service.gd` |
| Player stats (health, speed) | `scripts/autoload/player_stats_service.gd` |
| Turret stats | `scripts/autoload/turret_stats_service.gd` |

### Modifying Behavior
| What | Files |
|------|-------|
| Turret behavior (targeting, firing) | `scripts/turret.gd` |
| Enemy behavior (movement, attacks) | `scripts/enemy.gd` |
| Player movement | `scripts/components/player_movement.gd` |
| Player combat | `scripts/components/player_combat.gd` |
| Player melee | `scripts/components/player_melee_combat.gd` |
| Turret pickup | `scripts/components/player_turret_handler.gd` |

### Modifying UI
| What | Files |
|------|-------|
| HUD orchestration | `scripts/hud.gd` |
| Shop screen | `scripts/ui/shop/*.gd` |
| Pause menu | `scripts/ui/pause_menu.gd` |
| Game over screen | `scripts/ui/game_over_screen.gd` |
| Settings menu | `scripts/ui/settings_menu.gd` |
| Wave announcement | `scripts/ui/wave_announcement.gd` |

### Modifying Game Flow
| What | Files |
|------|-------|
| State machine transitions | `scripts/game_manager.gd` |
| Wave spawning logic | `scripts/enemy_spawner.gd` |
| Game Mode logic hooks | `scripts/autoload/game_mode_service.gd` |
| Game Mode definitions | `scripts/registries/game_mode_registry.gd` |
| Shop system | `scripts/shop_manager.gd` |
| Turret spawning/placement | `scripts/turret_manager.gd` |

### Adding Tests
| What | Files |
|------|-------|
| Unit tests (pure logic) | `tests/unit/test_*.gd` |
| Integration tests (scenes) | `tests/integration/test_*.gd` |
| Test utilities | `tests/README.md` |

## Development Workflow

### Running the Game
```powershell
.\launch.ps1   # or launch.bat
```

### Running Tests
```powershell
.\run_tests.ps1              # All tests
.\run_tests.ps1 -unit        # Unit tests only (fast)
.\run_tests.ps1 -integration # Integration tests only
.\run_tests.ps1 -filter "enemy"  # Filter by name
```

**Test structure**:
- `tests/unit/` - Pure logic tests (no scenes)
- `tests/integration/` - Scene-based tests

**Writing tests**:
```gdscript
extends GutTest

func before_each() -> void:
    GameStateService.reset()  # Always reset state
    DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)

func test_example():
    var duration = GameStateService.get_wave_duration(1)
    assert_eq(duration, 25.0)

func test_signals():
    watch_signals(Events)
    Events.game_started.emit()
    assert_signal_emitted(Events, "game_started")
```

Use `add_child_autofree()` for nodes that need cleanup. See `tests/README.md` for full documentation.

### Git Commits

Concise, one-line commits with single emoji prefix. Agents may commit frequently.

```
🎉 Initial MVP
✨ Add feature
🐛 Fix bug
♻️ Refactor code
🎨 Improve UI
🧪 Add tests
📝 Update docs
```

## Code Patterns & Conventions

### GDScript Conventions

- Use `@export` for inspector-exposed properties
- Use `@onready` for node references
- Explicit types: `var config: Dictionary = get_config()`
- Check `is_instance_valid()` before accessing dynamic nodes
- Prefer `call_deferred()` for physics changes during callbacks

### Key Patterns

**Projectile Setup** (requires explicit initialization):
```gdscript
var projectile = projectile_scene.instantiate()
get_tree().current_scene.add_child(projectile)
projectile.setup(direction, speed, damage, is_player_projectile)
```

**Timer Pattern** (fire rate, cooldowns):
```gdscript
fire_timer = Timer.new()
fire_timer.one_shot = true
fire_timer.wait_time = 1.0 / fire_rate
fire_timer.timeout.connect(_on_fire_timer_timeout)
add_child(fire_timer)
```

**Wave Initialization** (enemies must be initialized):
```gdscript
if enemy.has_method("initialize"):
    enemy.initialize(current_wave)
```

**Death Effects**:
```gdscript
var tween = create_tween()
tween.set_parallel(true)
tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
tween.tween_property(self, "modulate:a", 0.0, 0.3)
tween.finished.connect(queue_free)
```

### Arena Bounds

**Always use constants** - never hardcode dimensions:
```gdscript
var bounds_x = GameConstants.ARENA_WIDTH
var bounds_y = GameConstants.ARENA_HEIGHT
```

Auto-configured systems:
- `arena_setup.gd` - Visual bounds
- `camera_setup.gd` - Camera limits
- `player.gd` - Movement clamping

### Settings & Debug Toggles

Runtime toggles available via Globals:
- `show_damage_numbers: bool` - Damage number popups
- `show_turret_ranges: bool` - Turret range indicators
- Granular hitbox visualization (physics, player hurtbox, enemy hurtbox, player attack)

Access: `Globals.show_damage_numbers`, etc.

### Collision Layers

- Layer 1: Player
- Layer 2: Enemy
- Layer 3: Projectile
- Layer 4: Turret (for pickup interaction)

### Input Actions

| Action | Default Keys | Gamepad |
|--------|-------------|---------|
| `move_up/down/left/right` | WASD, Arrows | Left stick |
| `pause` | Escape | Start |
| `pickup_turret` | Configurable | Configurable |
| `melee_attack` | Configurable | Configurable |

Defined in `project.godot`, customizable in Project Settings.

## Visual Style & Assets

- **Theme**: Sci-fi space survival, cute futuristic aesthetic
- **Perspective**: Side-view 2D (like Binding of Isaac/Brotato)
- **Mood**: Futuristic, cute, elegant, sleek with cool colors (blues, cyans, silvers)
- **Detail**: High detail with single-color black outlines, medium shading
- **Animation**: 2-frame directional sprites for efficiency

**Asset organization**:
```
assets/sprites/
├── enemy_tiny/          # 8 directional sprites per enemy
├── player/              # Directional animation frames
├── turrets/             # Base + weapon layer designs
└── UI/                  # Icons, panels, overlays
```

See `doc/StyleMatrix.md` for detailed visual guidelines.

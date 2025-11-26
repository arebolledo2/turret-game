# Turret Survivor - AI Coding Agent Instructions

## Project Overview
A wave-based survival game built in **Godot 4.5** using GDScript. The player dodges enemies while auto-spawning turrets provide primary damage. The MVP scope is defined in `doc/00-MVP-IMPLEMENTATION-SPEC.md` (single source of truth for values/constants).

## Architecture

### Signal Bus Pattern (Event-Driven)
All cross-system communication uses the `Events` autoload (`scripts/autoload/events.gd`):
```gdscript
# Emitting events
Events.enemy_killed.emit(self, global_position)
Events.xp_dropped.emit(global_position, xp_value)

# Subscribing in _ready()
Events.player_damaged.connect(_on_player_damaged)
```
**Never** use direct node references for cross-system communication. Use signals.

### Global Constants (`scripts/autoload/globals.gd`)
All game constants and wave scaling formulas live here. **Always** read values from `Globals`:
```gdscript
max_health = Globals.PLAYER_MAX_HEALTH
var enemy_hp = Globals.get_enemy_health(wave)  # Use helper functions for scaled values
```

### Scene Tree Structure
```
Main (main.tscn)
├── Player, EnemySpawner, TurretManager, DropSpawner, GameManager
├── TurretContainer/  (turrets added here)
├── EnemyContainer/   (enemies spawned here)
├── DropContainer/    (XP drops spawned here)
└── HUD (CanvasLayer)
```

### Key Patterns

**Entity Groups**: All entities use groups for querying:
- `"player"`, `"enemies"`, `"turrets"`, `"pickups"`
```gdscript
var enemies = get_tree().get_nodes_in_group("enemies")
var player = get_tree().get_first_node_in_group("player")
```

**Projectile Setup**: Projectiles require explicit initialization after instantiation:
```gdscript
var projectile = projectile_scene.instantiate()
get_tree().current_scene.add_child(projectile)
projectile.setup(direction, speed, damage, is_player_projectile)
```

**Timer Pattern**: Fire rate and cooldowns use Timer nodes created in `_ready()`:
```gdscript
fire_timer = Timer.new()
fire_timer.one_shot = true
fire_timer.wait_time = 1.0 / fire_rate
fire_timer.timeout.connect(_on_fire_timer_timeout)
add_child(fire_timer)
```

**Wave Initialization**: Enemies must be initialized with wave number for scaling:
```gdscript
if enemy.has_method("initialize"):
    enemy.initialize(current_wave)
```

## Game State Flow
`GameManager` controls state via enum: `IDLE → DIFFICULTY_SELECT → WAVE_ANNOUNCEMENT → COMBAT → WAVE_END → (loop or VICTORY/GAME_OVER)`

Game startup:
1. `show_difficulty_select()` - Player chooses Easy/Medium/Hard
2. `_on_difficulty_selected()` - Sets `Globals.current_difficulty`, starts game

Wave progression:
1. `start_wave_announcement()` - Shows UI, spawns turret
2. `start_combat()` - Starts enemy spawning, wave timer
3. `end_wave()` - Stops spawning, checks victory (wave 10)

### Difficulty System
Difficulty is configured via `DIFFICULTY_CONFIG` dictionary in `globals.gd`. Each difficulty defines multipliers for enemy stats, player health, turret damage, and wave scaling. To add a new difficulty:
```gdscript
# In globals.gd DIFFICULTY_CONFIG
Difficulty.NIGHTMARE: {
    "name": "Nightmare",
    "enemy_health_mult": 2.0,
    "enemy_speed_mult": 1.3,
    # ... other multipliers
}
```

## Developer Workflow

### Running the Game
```powershell
.\launch.ps1   # or launch.bat
```

### Running Tests
The project uses [GUT (Godot Unit Test)](https://github.com/bitwes/Gut) for automated testing. Tests are in `tests/`:
```powershell
.\run_tests.ps1              # Run all tests
.\run_tests.ps1 -unit        # Unit tests only (fast, no scenes)
.\run_tests.ps1 -integration # Integration tests only
.\run_tests.ps1 -filter "enemy"  # Filter by test name
```

**Test structure:**
- `tests/unit/` — Pure logic tests for `globals.gd` (wave scaling, difficulty config)
- `tests/integration/` — Scene-based tests (enemy behavior, turret targeting, game state)

**Writing tests:**
```gdscript
extends GutTest

func before_each() -> void:
    Globals.reset_stats()  # Always reset state

func test_example():
    assert_eq(Globals.get_wave_duration(1), 20.0)

func test_signals():
    watch_signals(Events)
    Events.game_started.emit()
    assert_signal_emitted(Events, "game_started")
```

Use `add_child_autofree()` for nodes that need cleanup. See `tests/README.md` for full documentation.

### Git Commits
Commits should be concise, one-line, and begin with a single emoji. Agents may commit frequently.
```
🎉 Initial MVP
✨ Add player auto-fire targeting
🐛 Fix turret rotation jitter
♻️ Refactor wave scaling logic
```

### Key Files to Modify
| Feature | Files |
|---------|-------|
| Game balance | `scripts/autoload/globals.gd`, `doc/00-MVP-IMPLEMENTATION-SPEC.md` |
| New enemy types | `scripts/enemy.gd`, `scenes/enemy.tscn` |
| New turret types | `scripts/turret.gd`, `scenes/turret.tscn` |
| UI changes | `scripts/hud.gd`, `scenes/ui/hud.tscn` |
| Wave behavior | `scripts/game_manager.gd`, `scripts/enemy_spawner.gd` |

### Collision Layers
- Layer 1: Player
- Layer 2: Enemies  
- Layer 4: Projectiles

## Code Conventions

- Use `@export` for inspector-exposed properties, initialize from `Globals` in `_ready()`
- Use `@onready` for node references
- Check `is_instance_valid()` before accessing dynamic nodes
- Prefer `call_deferred()` for physics-related changes during callbacks
- Death effects: Scale to zero + fade alpha, then `queue_free()` via tween callback

## Asset Conventions
Assets are not yet implemented. When adding sprites, audio, or fonts, follow this structure:
```
assets/
├── sprites/    # PNG files, use snake_case (e.g., turret_base.png)
├── audio/      # WAV for SFX, OGG for music
└── fonts/      # TTF/OTF files
```
Import settings are auto-generated in `.import` files—do not edit these manually.

## Post-MVP Reference
Documents `01-04` in `/doc` contain the broader vision (shop system, multiple turret types, upgrades). These are **not** in scope for MVP implementation.

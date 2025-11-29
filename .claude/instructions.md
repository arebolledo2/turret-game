# Turret Survivor - Claude Instructions

## Project Overview
A wave-based survival game built in **Godot 4.5** using GDScript. The player dodges enemies while auto-spawning turrets provide primary damage. The MVP scope is defined in [doc/00-MVP-IMPLEMENTATION-SPEC.md](doc/00-MVP-IMPLEMENTATION-SPEC.md) (single source of truth for values/constants).

## Architecture

### Signal Bus Pattern (Event-Driven)
All cross-system communication uses the `Events` autoload ([scripts/autoload/events.gd](scripts/autoload/events.gd)):
```gdscript
# Emitting events
Events.enemy_killed.emit(self, global_position)
Events.xp_dropped.emit(global_position, xp_value)

# Subscribing in _ready()
Events.player_damaged.connect(_on_player_damaged)
```
**Never** use direct node references for cross-system communication. Use signals.

### Global Constants ([scripts/autoload/globals.gd](scripts/autoload/globals.gd))
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

**Settings Flags**: Runtime toggles in `Globals`:
- `show_damage_numbers: bool` — Toggle damage number popups
- `player_auto_attack_enabled: bool` — Player weapon (disabled by default)

## Game State Flow
`GameManager` controls state via enum: `IDLE → DIFFICULTY_SELECT → WAVE_ANNOUNCEMENT → COMBAT → WAVE_END → (loop or VICTORY/GAME_OVER)`

Game startup:
1. `show_difficulty_select()` - Player chooses Easy/Medium/Hard
2. `_on_difficulty_selected()` - Sets `Globals.current_difficulty`, starts game

Wave progression:
1. `start_wave_announcement()` - Shows UI, spawns turret
2. `start_combat()` - Starts enemy spawning, wave timer
3. `end_wave()` - Stops spawning, checks victory (wave 10)

### Turret Pickup System
Players can pick up and reposition turrets:
- Press **F** (or gamepad A) near a turret to pick it up
- Carried turret follows player with a speed penalty (30%)
- Press **F** again to place the turret at current position
- Relevant constants: `TURRET_PICKUP_RANGE`, `TURRET_CARRY_SPEED_PENALTY`

### Difficulty System
Difficulty is configured via `DIFFICULTY_CONFIG` dictionary in [globals.gd](scripts/autoload/globals.gd). Each difficulty defines multipliers for enemy stats, player health, turret damage, and wave scaling. To add a new difficulty:
```gdscript
# In globals.gd DIFFICULTY_CONFIG
Difficulty.NIGHTMARE: {
    "name": "Nightmare",
    "enemy_health_mult": 2.0,
    "enemy_speed_mult": 1.3,
    # ... other multipliers
}
```

### Turret Type System
Turrets use a **dual-tag architecture** separating attack style from damage type. See [doc/TurretTypes.md](doc/TurretTypes.md) for full design spec.

**Attack Styles** (`Globals.AttackStyle`):
- `PROJECTILE` — Fires visible projectile
- `INSTANT` — Hitscan/immediate damage
- `AOE` — Area damage (pulse or explosion)
- `CHAIN` — Damage jumps between enemies

**Damage Types** (`Globals.DamageType`):
- `PHYSICAL`, `FIRE`, `ELECTRIC`, `PLASMA`

**Turret Types** (defined in `TURRET_TYPES` dictionary):
| Type | Attack Style | Damage Type | Special |
|------|--------------|-------------|--------|
| `normal` | projectile | physical | Standard turret |
| `sniper` | instant | physical | Long range, high damage |
| `fire` | projectile | fire | DoT, high pierce |
| `plasma` | projectile, aoe | plasma | Explodes on impact |
| `shock` | aoe | electric | Pulses damage around turret |
| `tesla` | instant, chain | electric | Chain lightning |

**Working with turret types:**
```gdscript
# Get turret stats (with modifiers applied)
var stats = Globals.get_turret_stats("fire")

# Check turret capabilities
if Globals.turret_has_attack_style("tesla", Globals.AttackStyle.CHAIN):
    # Tesla can chain

# Set turret type on instantiation
var turret = turret_scene.instantiate()
turret.turret_type = "plasma"
```

### Modifier System
Items modify turret stats via filters. Modifiers are stored in `Globals.active_modifiers`:
```gdscript
# Add a modifier (+20% fire damage)
Globals.add_modifier({
    "id": "fire_boost_1",
    "stat": "damage",
    "operation": "multiply",  # or "add"
    "value": 1.2,
    "filter": {
        "damage_type": [Globals.DamageType.FIRE]
    }
})

# Remove by ID
Globals.remove_modifier("fire_boost_1")

# Clear all
Globals.clear_modifiers()
```

Filter options: `damage_type`, `attack_style`, `turret_type` (arrays, OR logic).

### Status Effect System
DoT effects are tracked on enemies via [scripts/status_effect.gd](scripts/status_effect.gd):
```gdscript
# Apply burning to an enemy
enemy.apply_status_effect(Globals.DamageType.FIRE, dot_damage, duration, tick_rate)

# Check if enemy has effect
if enemy.has_status_effect(Globals.DamageType.FIRE):
    # Enemy is burning
```
Stacking rule: Strongest DoT per damage type wins, duration refreshes.

## Developer Workflow

### Running the Game
```powershell
.\launch.ps1   # or launch.bat
```

### Running Tests
The project uses [GUT (Godot Unit Test)](https://github.com/bitwes/Gut) for automated testing. Tests are in [tests/](tests/):
```powershell
.\run_tests.ps1              # Run all tests
.\run_tests.ps1 -unit        # Unit tests only (fast, no scenes)
.\run_tests.ps1 -integration # Integration tests only
.\run_tests.ps1 -filter "enemy"  # Filter by test name
```

**Test structure:**
- [tests/unit/](tests/unit/) — Pure logic tests for [globals.gd](scripts/autoload/globals.gd) (wave scaling, difficulty config)
- [tests/integration/](tests/integration/) — Scene-based tests (enemy behavior, turret targeting, game state)

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

Use `add_child_autofree()` for nodes that need cleanup. See [tests/README.md](tests/README.md) for full documentation.

### Git Commits
When creating commits, use concise, one-line messages that begin with a single emoji:
```
🎉 Initial MVP
✨ Add player auto-fire targeting
🐛 Fix turret rotation jitter
♻️ Refactor wave scaling logic
```

### Key Files to Modify
| Feature | Files |
|---------|-------|
| Game balance | [scripts/autoload/globals.gd](scripts/autoload/globals.gd), [doc/00-MVP-IMPLEMENTATION-SPEC.md](doc/00-MVP-IMPLEMENTATION-SPEC.md) |
| Turret types/stats | [scripts/autoload/globals.gd](scripts/autoload/globals.gd) (`TURRET_TYPES`), [doc/TurretTypes.md](doc/TurretTypes.md) |
| New enemy types | [scripts/enemy.gd](scripts/enemy.gd), [scenes/enemy.tscn](scenes/enemy.tscn) |
| Turret behavior | [scripts/turret.gd](scripts/turret.gd), [scenes/turret.tscn](scenes/turret.tscn) |
| Status effects/DoT | [scripts/status_effect.gd](scripts/status_effect.gd), [scripts/enemy.gd](scripts/enemy.gd) |
| Projectiles | [scripts/projectile.gd](scripts/projectile.gd) (pierce, AoE, DoT application) |
| UI changes | [scripts/hud.gd](scripts/hud.gd), [scenes/ui/hud.tscn](scenes/ui/hud.tscn) |
| Wave behavior | [scripts/game_manager.gd](scripts/game_manager.gd), [scripts/enemy_spawner.gd](scripts/enemy_spawner.gd) |

### Collision Layers
- Layer 1: Player
- Layer 2: Enemy
- Layer 3: Projectile
- Layer 4: Pickup

### Input Actions
| Action | Keys | Gamepad |
|--------|------|---------|  
| `move_up/down/left/right` | WASD, Arrow keys | Left stick |
| `pause` | Escape | Start |
| `pickup_turret` | F | A button |

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

## Claude-Specific Guidelines

### File References
When referencing files or code locations, always use clickable markdown links:
- For files: [filename.gd](scripts/filename.gd)
- For specific lines: [filename.gd:42](scripts/filename.gd#L42)
- For a range of lines: [filename.gd:42-51](scripts/filename.gd#L42-L51)

### Before Making Changes
1. **Always read files first** before proposing changes
2. Use the Explore agent for broad codebase exploration (e.g., "where are enemies handled?")
3. Use direct Read/Grep for specific lookups (e.g., "read player.gd")

### Making Changes
1. **Avoid over-engineering**: Only make requested changes
2. **Don't add extras**: No unsolicited refactoring, comments, or "improvements"
3. **Keep it simple**: Three similar lines > premature abstraction
4. **Security**: Watch for command injection, XSS, or other vulnerabilities
5. **Test your changes**: Run tests after significant changes

### Task Management
Use the TodoWrite tool for multi-step tasks to track progress and give visibility:
- Break down complex features into specific steps
- Mark tasks as in_progress before starting, completed when done
- Update the todo list as you discover new requirements

## Post-MVP Reference
Documents `01-04` in [/doc](doc/) contain the broader vision (shop system, multiple turret types, upgrades). These are **not** in scope for MVP implementation.

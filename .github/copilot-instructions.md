# Turret Game - AI Coding Agent Instructions

## Project Overview
A wave-based survival tower defense game built in **Godot 4.5** using GDScript. The player dodges enemies in an arena while turrets provide primary damage. Purchase turrets between waves using gold earned from kills.

## Architecture

### Signal Bus Pattern (Event-Driven)
All cross-system communication uses the `Events` autoload (`scripts/events.gd`):
```gdscript
# Emitting events
Events.enemy_killed.emit(enemy, global_position)
Events.gold_collected.emit(amount)

# Subscribing in _ready()
Events.player_damaged.connect(_on_player_damaged)
```
**Never** use direct node references for cross-system communication. Use signals.

### Global Constants (`scripts/globals.gd`)
All game constants and wave scaling formulas live here. **Always** read values from `Globals`:
```gdscript
max_health = Globals.PLAYER_MAX_HEALTH
var stats = Globals.get_turret_stats("fire")  # Use helper functions for stats
```

### Scene Tree Structure
```
Main (main.tscn)
├── Player, EnemySpawner, TurretManager, ShopManager, GameManager
├── TurretContainer/  (turrets added here)
├── EnemyContainer/   (enemies spawned here)
└── HUD (CanvasLayer with DifficultySelect, ShopUI, WaveAnnouncement)
```

### Key Patterns

**Entity Groups**: All entities use groups for querying:
- `"player"`, `"enemies"`, `"turrets"`
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

**Settings**: Runtime toggles in `Globals`:
- `show_damage_numbers: bool` — Toggle damage number popups
- `show_turret_ranges: bool` — Toggle turret range indicators

## Game State Flow
`GameManager` controls state via enum: `IDLE → DIFFICULTY_SELECT → SHOP → WAVE_ANNOUNCEMENT → COMBAT → WAVE_END → (loop or VICTORY/GAME_OVER)`

Game startup:
1. `show_difficulty_select()` - Player chooses Easy/Medium/Hard
2. `_on_difficulty_selected()` - Sets `Globals.current_difficulty`, starts game

Wave cycle:
1. `start_shop()` - Show shop UI, player purchases turrets
2. `start_wave_announcement()` - Shows wave number (1.5s)
3. `start_combat()` - Spawns purchased turrets, starts enemy spawning with alerts, wave timer
4. `end_wave()` - Stops spawning, awards wave bonus gold, checks victory (wave 10)

### Turret Pickup System
Players can pick up and reposition turrets:
- Press **F** (or gamepad A) near a turret to pick it up
- Carried turret follows player with a speed penalty (30%)
- Press **F** again to place the turret at current position
- Relevant constants: `TURRET_PICKUP_RANGE`, `TURRET_CARRY_SPEED_PENALTY`

### Shop & Economy System
Gold-based economy for purchasing turrets:
- **Starting Gold**: 120 (buy one turret)
- **Gold per Kill**: 1 gold per enemy
- **Wave Bonus**: 20 + (wave × 5) gold
- **Shop Offers**: 4 random turret offers per wave
- **Reroll**: Costs 5 gold, increments +3 per reroll (max 5 rerolls)
- **Price Scaling**: Base price × (1 + 0.15 × wave)

Shop manager emits signals: `shop_opened`, `shop_purchase_made`, `shop_rerolled`, `shop_closed`

### Difficulty System
Three difficulty levels with multipliers for enemy/player/turret stats and wave scaling. Configured in `DIFFICULTY_CONFIG` dictionary in `globals.gd`.

### Turret Type System
Six turret types defined in `TURRET_TYPES` dictionary (`globals.gd`):

| Type | Damage | Range | Fire Rate | Price | Special |
|------|--------|-------|-----------|-------|---------|
| `normal` | 10 | 300 | 1.0/s | 80 | Standard projectile |
| `sniper` | 25 | 500 | 0.5/s | 120 | Instant hit, long range |
| `fire` | 8 | 250 | 1.2/s | 100 | DoT, pierce 3 |
| `plasma` | 15 | 350 | 0.8/s | 140 | Explosive AOE |
| `shock` | 6 | 200 | 2.0/s | 90 | AOE pulse around self |
| `tesla` | 12 | 400 | 1.0/s | 130 | Chain lightning (3 targets) |

**Working with turret types:**
```gdscript
# Get turret stats (with modifiers applied)
var stats = Globals.get_turret_stats("fire")
# Returns: {damage, range, fire_rate, projectile_speed, price, shop_weight, ...}

# Set turret type on instantiation
var turret = turret_scene.instantiate()
turret.turret_type = "plasma"
```

### Enemy Type System
Seven enemy types defined in `ENEMY_TYPES` dictionary (`globals.gd`):

| Type | Base HP | Speed | Damage | Min Wave | Special |
|------|---------|-------|--------|----------|---------|
| `tiny_bot` | 15 | 180 | 10 | 1 | Small, spawn in pairs |
| `robot_grunt` | 30 | 150 | 10 | 1 | Standard enemy |
| `scout_bot` | 20 | 220 | 8 | 2 | Fast, fragile |
| `heavy_bot` | 80 | 80 | 20 | 3 | Slow, tanky |
| `boom_bot` | 25 | 140 | 15 | 4 | Explodes on death |
| `mini_bot` | 10 | 160 | 8 | 2 | Tiny, spawn in groups of 3 |
| `swarm` | varies | varies | varies | varies | Multiple variants |

Enemy stats scale per wave: +10% HP, +3% speed. Enemy spawner shows visual alerts before spawning.

### Status Effect System
DoT effects (from fire turrets) are tracked on enemies via `scripts/status_effect.gd`:
```gdscript
# Apply burning to an enemy
enemy.apply_status_effect("fire", dot_damage, duration)

# Check if enemy has effect
if enemy.has_status_effect("fire"):
    # Enemy is burning
```
Stacking rule: Strongest DoT per type wins, duration refreshes.

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
| Game balance | `scripts/globals.gd` (constants and type dictionaries) |
| Turret types/stats | `scripts/globals.gd` (`TURRET_TYPES`) |
| Enemy types/stats | `scripts/globals.gd` (`ENEMY_TYPES`) |
| Turret behavior | `scripts/turret.gd`, `scenes/turret.tscn` |
| Enemy behavior | `scripts/enemy.gd`, `scenes/enemy.tscn` |
| Shop system | `scripts/shop_manager.gd`, `scenes/ui/shop_ui.tscn` |
| Wave spawning | `scripts/game_manager.gd`, `scripts/enemy_spawner.gd` |
| Projectiles | `scripts/projectile.gd` (pierce, AOE, DoT) |
| UI changes | `scripts/hud.gd`, `scenes/ui/` |

### Collision Layers
- Layer 1: Player
- Layer 2: Enemy
- Layer 3: Projectile
- Layer 4: Turret (for pickup interaction)

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

## Visual Style
- **Theme**: Sci-fi space survival, cute futuristic aesthetic
- **Perspective**: Side-view 2D (like Binding of Isaac/Brotato)
- **Mood**: Futuristic, cute, elegant, sleek with cool colors (blues, cyans, silvers)
- **Detail**: High detail with single-color black outlines, medium shading
- **Animation**: 2-frame directional sprites for efficiency

Asset organization:
```
assets/sprites/
├── enemy_tiny/          # 8 directional sprites per enemy
├── player/              # Directional animation frames
├── turrets/             # Base + weapon layer designs
└── UI/                  # Icons, panels, overlays
```

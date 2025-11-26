# Technical Implementation Guide

> 📋 **POST-MVP VISION DOCUMENT**  
> This describes the full technical architecture. For MVP implementation, see `00-MVP-IMPLEMENTATION-SPEC.md`

## Project Setup

### Godot Version
- **Target:** Godot 4.2+ (latest stable)
- **Renderer:** Forward+ or Mobile (2D game, either works)

### Project Structure
```
res://
├── scenes/
│   ├── main.tscn (root scene)
│   ├── player/
│   │   └── player.tscn
│   ├── turrets/
│   │   ├── turret_base.tscn (inherited by all turrets)
│   │   ├── gun_turret.tscn
│   │   ├── cannon_turret.tscn
│   │   └── rapid_fire_turret.tscn
│   ├── enemies/
│   │   └── basic_enemy.tscn
│   ├── arena/
│   │   └── arena.tscn
│   └── ui/
│       ├── hud.tscn
│       ├── shop.tscn
│       └── game_over.tscn
├── scripts/
│   ├── managers/
│   │   ├── game_manager.gd
│   │   ├── turret_manager.gd
│   │   ├── enemy_spawner.gd
│   │   └── economy_manager.gd
│   ├── player.gd
│   ├── turret_base.gd
│   ├── enemy_base.gd
│   └── resource_drop.gd
├── resources/
│   ├── turret_data/
│   │   ├── gun_turret_data.tres
│   │   └── [other turret data]
│   └── wave_data/
│       ├── wave_config.tres
│       └── [wave configurations]
├── assets/
│   ├── sprites/
│   ├── audio/
│   └── fonts/
└── autoload/
    ├── events.gd (signal bus)
    └── globals.gd (game state)
```

## Core Systems Architecture

### Scene Tree Structure
```
Main (Node2D)
├── Arena (Node2D)
│   └── [Visual elements]
├── TurretContainer (Node2D)
│   └── [Turrets added dynamically]
├── EnemyContainer (Node2D)
│   └── [Enemies spawned here]
├── Player (CharacterBody2D)
├── DropContainer (Node2D)
│   └── [Gold/XP drops]
├── GameManager (Node)
├── TurretManager (Node)
├── EnemySpawner (Node)
├── EconomyManager (Node)
└── UILayer (CanvasLayer)
    ├── HUD
    ├── Shop
    └── GameOver
```

## Key Systems Implementation

### 1. Game Manager (Singleton/Autoload recommended)

**Responsibilities:**
- Manage game state (menu, combat, shop, game_over)
- Track current wave
- Coordinate transitions between phases
- Win/loss condition checking

**Key Signals:**
```gdscript
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal shop_phase_started()
signal game_over()
signal game_won()
```

**Core State Machine:**
```gdscript
enum GameState {
    MENU,
    COMBAT,
    SHOP,
    GAME_OVER,
    VICTORY
}
```

### 2. Player Controller

**Node Type:** `CharacterBody2D`

**Components:**
- Sprite2D
- CollisionShape2D
- Weapon (Node2D or custom class)
- HitboxArea2D (for taking damage)

**Key Properties:**
```gdscript
@export var speed: float = 300.0
@export var max_health: float = 100.0
@export var weapon_damage: float = 5.0
@export var weapon_fire_rate: float = 2.0 # shots per second

var current_health: float
```

**Movement Implementation:**
- Use `Input.get_vector()` for 8-directional movement
- Normalize diagonal movement
- Use `move_and_slide()` for collision handling

**Combat Implementation:**
- Option A: Auto-fire at nearest enemy
- Option B: Shoot toward mouse position on click/hold
- Raycast or Area2D for detection
- Timer for fire rate limiting

### 3. Turret System

#### Base Turret Class

**Node Type:** `Node2D` with child nodes

**Components:**
```
TurretBase (Node2D)
├── Sprite2D (turret body)
├── WeaponSprite (Sprite2D, rotates toward target)
├── DetectionArea (Area2D)
│   └── CollisionShape2D (circle, defines range)
├── ShootPoint (Marker2D, projectile spawn point)
└── FireRateTimer (Timer)
```

**Key Properties:**
```gdscript
@export var turret_name: String
@export var damage: float
@export var fire_rate: float # shots per second
@export var detection_range: float
@export var projectile_speed: float
@export var cost: int

var current_target: Node2D = null
var enemies_in_range: Array[Node2D] = []
```

**Targeting Logic:**
```gdscript
func _process(delta):
    if current_target == null or not is_instance_valid(current_target):
        acquire_target()
    
    if current_target:
        aim_at_target()
        fire_if_ready()

func acquire_target():
    enemies_in_range = detection_area.get_overlapping_bodies()
    if enemies_in_range.is_empty():
        current_target = null
        return
    
    # Find nearest enemy
    var nearest = null
    var min_distance = INF
    for enemy in enemies_in_range:
        var dist = global_position.distance_to(enemy.global_position)
        if dist < min_distance:
            min_distance = dist
            nearest = enemy
    
    current_target = nearest
```

#### Turret Data Resource

**Create custom Resource:**
```gdscript
# turret_data.gd
class_name TurretData extends Resource

@export var turret_name: String
@export var damage: float
@export var fire_rate: float
@export var detection_range: float
@export var projectile_speed: float
@export var cost: int
@export var turret_scene: PackedScene
@export var icon: Texture2D
@export var description: String
```

### 4. Enemy System

**Node Type:** `CharacterBody2D`

**Components:**
```
Enemy (CharacterBody2D)
├── Sprite2D
├── CollisionShape2D
├── HitboxArea (Area2D, for taking damage)
├── AttackArea (Area2D, for dealing damage to player)
└── HealthBar (optional, ProgressBar or custom)
```

**Key Properties:**
```gdscript
@export var max_health: float = 50.0
@export var speed: float = 150.0
@export var contact_damage: float = 10.0
@export var gold_drop_amount: int = 10
@export var xp_drop_amount: int = 15

var current_health: float
var player_reference: Node2D
```

**AI Logic:**
```gdscript
func _physics_process(delta):
    if player_reference:
        var direction = (player_reference.global_position - global_position).normalized()
        velocity = direction * speed
        move_and_slide()
```

**Death Handling:**
```gdscript
func die():
    spawn_drops()
    Events.enemy_died.emit(self)
    queue_free()

func spawn_drops():
    # Spawn gold drop
    var gold_drop = GoldDrop.instantiate()
    gold_drop.amount = gold_drop_amount
    gold_drop.global_position = global_position
    get_tree().current_scene.get_node("DropContainer").add_child(gold_drop)
    
    # Spawn XP drop
    # Similar logic
```

### 5. Enemy Spawner

**Responsibilities:**
- Manage wave configuration
- Spawn enemies over time during wave
- Track enemies alive
- Signal when wave is complete

**Wave Configuration Resource:**
```gdscript
class_name WaveData extends Resource

@export var wave_number: int
@export var total_enemies: int
@export var enemy_health_multiplier: float = 1.0
@export var enemy_speed_multiplier: float = 1.0
@export var spawn_duration: float = 45.0 # seconds
```

**Spawning Logic:**
```gdscript
var enemies_to_spawn: int
var spawn_timer: float = 0.0
var spawn_interval: float

func start_wave(wave_data: WaveData):
    enemies_to_spawn = wave_data.total_enemies
    spawn_interval = wave_data.spawn_duration / enemies_to_spawn
    spawn_timer = 0.0

func _process(delta):
    if enemies_to_spawn > 0:
        spawn_timer += delta
        if spawn_timer >= spawn_interval:
            spawn_enemy()
            enemies_to_spawn -= 1
            spawn_timer = 0.0
    
    check_wave_complete()
```

### 6. Economy Manager

**Responsibilities:**
- Track gold and XP
- Handle purchases
- Validate turret purchases
- Emit signals on changes

**Key Properties:**
```gdscript
var current_gold: int = 100
var current_xp: int = 0

signal gold_changed(new_amount: int)
signal xp_changed(new_amount: int)
```

**Methods:**
```gdscript
func add_gold(amount: int):
    current_gold += amount
    gold_changed.emit(current_gold)

func can_afford(cost: int) -> bool:
    return current_gold >= cost

func purchase_turret(cost: int) -> bool:
    if can_afford(cost):
        current_gold -= cost
        gold_changed.emit(current_gold)
        return true
    return false
```

### 7. Turret Manager

**Responsibilities:**
- Handle turret placement
- Track placed turrets
- Validate placement positions
- Interface between shop and game world

**Placement Mode:**
```gdscript
var placement_mode_active: bool = false
var turret_to_place: TurretData = null
var placement_preview: Node2D = null

func enter_placement_mode(turret_data: TurretData):
    if not economy_manager.can_afford(turret_data.cost):
        return
    
    placement_mode_active = true
    turret_to_place = turret_data
    create_placement_preview()

func _process(delta):
    if placement_mode_active:
        update_preview_position()
        check_placement_validity()
        
        if Input.is_action_just_pressed("place_turret"): # Left click
            try_place_turret()
        
        if Input.is_action_just_pressed("cancel_placement"): # ESC or Right click
            cancel_placement()
```

### 8. Resource Drops

**Node Type:** `Area2D`

**Components:**
```
ResourceDrop (Area2D)
├── Sprite2D
├── CollisionShape2D
└── AnimationPlayer (optional, bob/pulse animation)
```

**Pickup Logic:**
```gdscript
func _on_body_entered(body: Node2D):
    if body.is_in_group("player"):
        collect(body)

func collect(player: Node2D):
    # Gold drop
    economy_manager.add_gold(amount)
    # Play sound/particles
    queue_free()
```

## UI Implementation

### HUD

**Node Type:** `Control` (CanvasLayer child)

**Components:**
- Gold label
- XP label
- Wave number label
- Health bar
- Wave progress indicator

**Updates via signals:**
```gdscript
func _ready():
    Events.gold_changed.connect(_on_gold_changed)
    Events.xp_changed.connect(_on_xp_changed)
    Events.wave_started.connect(_on_wave_started)
    # etc.
```

### Shop UI

**Node Type:** `Control`

**Layout:**
- Grid or list of turret cards
- Each card shows:
  - Icon
  - Name
  - Stats
  - Cost
  - Purchase button
- "Start Wave" button

**Purchase Flow:**
```gdscript
func _on_turret_card_pressed(turret_data: TurretData):
    if economy_manager.can_afford(turret_data.cost):
        turret_manager.enter_placement_mode(turret_data)
        hide() # Hide shop during placement
```

## Signal Bus (Autoload: Events)

**Centralized event system:**
```gdscript
# events.gd
extends Node

# Game flow
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal shop_phase_started()
signal game_over()
signal game_won()

# Economy
signal gold_changed(new_amount: int)
signal xp_changed(new_amount: int)

# Combat
signal enemy_died(enemy: Node2D)
signal player_damaged(damage: float)
signal turret_placed(turret: Node2D)
```

## Development Roadmap

### Phase 1: Basic Movement & Arena
1. Create arena scene with boundaries
2. Implement player movement
3. Add camera follow player
4. Test movement feel

### Phase 2: Single Turret Type
1. Create base turret scene
2. Implement targeting and shooting
3. Create simple projectile
4. Test turret behavior

### Phase 3: Basic Enemy
1. Create enemy scene
2. Implement chase player AI
3. Implement contact damage
4. Test enemy behavior

### Phase 4: Wave Spawning
1. Create enemy spawner
2. Implement wave configuration
3. Test spawning patterns
4. Add wave transitions

### Phase 5: Economy System
1. Implement gold drops
2. Implement XP drops
3. Create economy manager
4. Add collection radius to player

### Phase 6: Shop & Placement
1. Create shop UI
2. Implement turret purchasing
3. Implement placement preview
4. Implement placement validation
5. Connect economy to shop

### Phase 7: Additional Turrets
1. Implement 2-3 more turret types
2. Balance damage/cost/fire rate
3. Test variety and strategy

### Phase 8: Difficulty Scaling
1. Implement wave progression
2. Scale enemy stats
3. Balance economy with difficulty
4. Test full game loop

### Phase 9: Polish
1. Add juice (particles, screen shake)
2. Add sound effects
3. Add UI polish
4. Add win/loss screens

## Performance Considerations

### Object Pooling (Optional but recommended)
- Pool projectiles (avoid constant instantiation)
- Pool resource drops
- Pool enemies (if spawning hundreds)

### Optimization Tips
- Use `Area2D` overlap checking sparingly
- Cache frequently accessed nodes
- Use groups for quick lookups (`get_tree().get_nodes_in_group()`)
- Disable processing on inactive objects
- Use `process_mode` to pause enemies during shop phase

## Testing Checklist

- [ ] Player can move smoothly in all directions
- [ ] Turrets target nearest enemy correctly
- [ ] Turrets deal appropriate damage
- [ ] Enemies chase player correctly
- [ ] Enemies die and drop resources
- [ ] Player can collect resources
- [ ] Shop shows correct prices
- [ ] Cannot purchase unaffordable turrets
- [ ] Placement preview works correctly
- [ ] Cannot place turrets on invalid positions
- [ ] Waves progress correctly
- [ ] Difficulty scales appropriately
- [ ] Win condition triggers
- [ ] Loss condition triggers
- [ ] UI updates correctly

## Common Godot Patterns for This Project

### Getting References
```gdscript
# Via autoload
var game_manager = GameManager

# Via get_node
var player = get_tree().get_first_node_in_group("player")

# Via signal injection
var player_ref: Node2D
func set_player(player: Node2D):
    player_ref = player
```

### Damage System
```gdscript
# On enemy (receives damage)
func take_damage(amount: float):
    current_health -= amount
    if current_health <= 0:
        die()

# On turret (deals damage via projectile)
func _on_projectile_hit(body: Node2D):
    if body.has_method("take_damage"):
        body.take_damage(damage)
```

### Separation of Concerns
- **Managers** handle coordination and state
- **Entities** (player, enemies, turrets) handle their own behavior
- **UI** reacts to signals from managers
- **Events** (signal bus) keep systems decoupled

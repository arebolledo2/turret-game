extends CharacterBody2D

const StatusEffect = preload("res://scripts/status_effect.gd")

# =============================================================================
# ENEMY TYPE CONFIGURATION
# =============================================================================
@export var enemy_type: String = "basic"

# Base stats (set from type or wave initialization)
var max_health: float = 30.0
var speed: float = 150.0
var contact_damage: float = 33.0
var xp_value: int = 10
var base_scale: float = 1.0
var color_tint: Color = Color.WHITE

# Type-specific stats (for special abilities)
var explosion_radius: float = 0.0
var explosion_damage: float = 0.0

# Knockback and slow mechanics
var mass: float = 1.0  # Resistance to knockback
var knockback_velocity: Vector2 = Vector2.ZERO  # Current knockback impulse

# Directional sprite textures (loaded dynamically from type)
var sprite_south: Texture2D
var sprite_north: Texture2D
var sprite_east: Texture2D
var sprite_west: Texture2D
var sprite_south_east: Texture2D
var sprite_south_west: Texture2D
var sprite_north_east: Texture2D
var sprite_north_west: Texture2D

var current_health: float
var player: Node2D = null

# Status effects - keyed by DamageType, only strongest of each type is active
var active_effects: Dictionary = {}  # DamageType -> StatusEffect
var is_dying: bool = false
var is_initialized: bool = false

# Behavior system state
var current_behavior: Globals.EnemyBehavior = Globals.EnemyBehavior.CHASE
var behavior_params: Dictionary = {}

# WANDER behavior state
var wander_target: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var is_wandering: bool = false  # true = moving, false = paused

# CHARGE behavior state
enum ChargeState { IDLE, ALERT, CHARGING, COOLDOWN }
var charge_state: ChargeState = ChargeState.IDLE
var charge_timer: float = 0.0
var charge_target_pos: Vector2 = Vector2.ZERO
var charge_direction: Vector2 = Vector2.ZERO
var charge_alert_indicator: Node2D = null

# Default behavior parameters
const DEFAULT_BEHAVIOR_PARAMS: Dictionary = {
	"wander_pause_min": 1.5,
	"wander_pause_max": 3.0,
	"wander_move_min": 2.0,
	"wander_move_max": 4.0,
	"charge_detect_radius": 200.0,
	"charge_alert_duration": 0.9,
	"charge_speed_multiplier": 3.0,
	"charge_duration": 1.5,
	"charge_cooldown": 2.5,
}

func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	
	# If not initialized by spawner, initialize with defaults
	if not is_initialized:
		_apply_type_config(enemy_type)
		current_health = max_health

func _apply_type_config(type_id: String) -> void:
	"""Load configuration from EnemyRegistry and apply to this enemy."""
	enemy_type = type_id
	var type_def: Dictionary = EnemyRegistry.get_type(type_id)
	var base_stats: Dictionary = type_def.get("base_stats", {})

	# Load base stats
	max_health = base_stats.get("health", 30.0)
	speed = base_stats.get("speed", 150.0)
	contact_damage = base_stats.get("contact_damage", 33.0)
	xp_value = base_stats.get("xp_value", 10)
	base_scale = base_stats.get("scale", 1.0)

	# Load special ability stats
	explosion_radius = base_stats.get("explosion_radius", 0.0)
	explosion_damage = base_stats.get("explosion_damage", 0.0)

	# Load knockback resistance
	mass = base_stats.get("mass", 1.0)

	# Load color tint
	color_tint = type_def.get("color_tint", Color.WHITE)

	# Load behavior_params
	behavior_params = type_def.get("behavior_params", {})

	# Determine primary behavior
	var behaviors: Array = type_def.get("behaviors", [Globals.EnemyBehavior.CHASE])
	if behaviors.is_empty():
		current_behavior = Globals.EnemyBehavior.CHASE
	else:
		# Priority: CHARGE > WANDER > CHASE
		if Globals.EnemyBehavior.CHARGE in behaviors:
			current_behavior = Globals.EnemyBehavior.CHARGE
		elif Globals.EnemyBehavior.WANDER in behaviors:
			current_behavior = Globals.EnemyBehavior.WANDER
		else:
			current_behavior = behaviors[0]

	# Load sprites from sprite folder (only for non-animated enemies)
	if type_def.has("sprite_folder") and has_node("Sprite2D"):
		var sprite_folder: String = type_def.get("sprite_folder", "res://assets/sprites/enemy_tiny")
		_load_sprites(sprite_folder)

	# Apply visual configuration
	_apply_visuals()

func _load_sprites(folder_path: String) -> void:
	"""Load directional sprites from the specified folder."""
	sprite_south = load(folder_path + "/enemy_south.png")
	sprite_north = load(folder_path + "/enemy_north.png")
	sprite_east = load(folder_path + "/enemy_east.png")
	sprite_west = load(folder_path + "/enemy_west.png")
	sprite_south_east = load(folder_path + "/enemy_south_east.png")
	sprite_south_west = load(folder_path + "/enemy_south_west.png")
	sprite_north_east = load(folder_path + "/enemy_north_east.png")
	sprite_north_west = load(folder_path + "/enemy_north_west.png")

func _apply_visuals() -> void:
	"""Apply scale and color tint to the sprite."""
	if has_node("Sprite2D"):
		var sprite = $Sprite2D
		sprite.scale = Vector2(base_scale, base_scale)
		sprite.modulate = color_tint
		# Set initial texture
		if sprite_south:
			sprite.texture = sprite_south
	elif has_node("AnimatedSprite2D"):
		var anim_sprite = $AnimatedSprite2D
		anim_sprite.scale = Vector2(base_scale, base_scale)
		anim_sprite.modulate = color_tint
		# AnimatedSprite2D uses sprite_frames, not individual textures

func _physics_process(delta: float) -> void:
	if is_dying:
		return

	# Process status effects
	_process_status_effects(delta)

	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return

	# Execute behavior to get movement direction
	var movement_direction: Vector2 = _execute_current_behavior(delta)

	# Apply knockback first (overrides AI movement temporarily)
	if knockback_velocity.length() > Globals.KNOCKBACK_MIN_VELOCITY:
		velocity = knockback_velocity
		knockback_velocity *= (1.0 - Globals.KNOCKBACK_DECAY_RATE * delta)
	else:
		knockback_velocity = Vector2.ZERO
		# Normal AI movement with behavior-based direction
		var effective_speed: float = speed * get_movement_speed_multiplier()

		# Apply charge speed boost if charging
		if current_behavior == Globals.EnemyBehavior.CHARGE and charge_state == ChargeState.CHARGING:
			var charge_mult: float = behavior_params.get("charge_speed_multiplier", DEFAULT_BEHAVIOR_PARAMS["charge_speed_multiplier"])
			effective_speed *= charge_mult

		velocity = movement_direction.normalized() * effective_speed

	move_and_slide()

	# Update sprite based on velocity (works for all behaviors)
	if velocity.length() > 0:
		_update_direction_sprite(velocity.normalized())
	
	# Check for collision with player
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider = collision.get_collider()
		if collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(contact_damage)

func _update_direction_sprite(direction: Vector2) -> void:
	# AnimatedSprite2D enemies use left/right animations only
	if has_node("AnimatedSprite2D"):
		var anim_sprite = $AnimatedSprite2D
		if direction.x < 0:
			anim_sprite.play("move_left")
		else:
			anim_sprite.play("move_right")
		return

	# Sprite2D enemies use 8-directional sprites
	if not has_node("Sprite2D"):
		return

	# Get angle and convert to 8-direction
	var angle := direction.angle()
	var sprite := $Sprite2D

	# Normalize angle to 0-2PI range
	if angle < 0:
		angle += TAU

	# Divide into 8 segments (each 45 degrees = PI/4)
	# Offset by 22.5 degrees (PI/8) to center segments
	var segment := int((angle + PI / 8) / (PI / 4)) % 8

	# Map segment to sprite (0 = east, going counter-clockwise)
	match segment:
		0: sprite.texture = sprite_east
		1: sprite.texture = sprite_north_east
		2: sprite.texture = sprite_north
		3: sprite.texture = sprite_north_west
		4: sprite.texture = sprite_west
		5: sprite.texture = sprite_south_west
		6: sprite.texture = sprite_south
		7: sprite.texture = sprite_south_east

# =============================================================================
# BEHAVIOR SYSTEM
# =============================================================================

func _execute_current_behavior(delta: float) -> Vector2:
	"""Execute the current behavior and return movement direction."""
	match current_behavior:
		Globals.EnemyBehavior.CHASE:
			return _behavior_chase()
		Globals.EnemyBehavior.WANDER:
			return _behavior_wander()
		Globals.EnemyBehavior.CHARGE:
			return _behavior_charge(delta)
		_:
			return _behavior_chase()

func _behavior_chase() -> Vector2:
	"""Chase behavior - move directly toward player."""
	if player and is_instance_valid(player):
		return global_position.direction_to(player.global_position)
	return Vector2.ZERO

func _behavior_wander() -> Vector2:
	"""Wander behavior - randomly move anywhere in arena with pauses."""
	var pause_min: float = behavior_params.get("wander_pause_min", DEFAULT_BEHAVIOR_PARAMS["wander_pause_min"])
	var pause_max: float = behavior_params.get("wander_pause_max", DEFAULT_BEHAVIOR_PARAMS["wander_pause_max"])
	var move_min: float = behavior_params.get("wander_move_min", DEFAULT_BEHAVIOR_PARAMS["wander_move_min"])
	var move_max: float = behavior_params.get("wander_move_max", DEFAULT_BEHAVIOR_PARAMS["wander_move_max"])

	# Initialize on first call
	if wander_timer == 0:
		wander_timer = randf_range(pause_min, pause_max)
		is_wandering = false

	wander_timer -= get_process_delta_time()

	if wander_timer <= 0:
		is_wandering = not is_wandering

		if is_wandering:
			# Pick random target anywhere in arena
			wander_target = _get_random_arena_position()
			wander_timer = randf_range(move_min, move_max)
		else:
			wander_timer = randf_range(pause_min, pause_max)

	# Check if reached target (within 20 pixels)
	if is_wandering and global_position.distance_to(wander_target) < 20.0:
		# Reached target early - switch to pause
		is_wandering = false
		wander_timer = randf_range(pause_min, pause_max)

	if is_wandering:
		return global_position.direction_to(wander_target)
	else:
		return Vector2.ZERO

func _get_random_arena_position() -> Vector2:
	"""Get a random position within the arena bounds."""
	# Get arena bounds from Globals
	var arena_width := Globals.ARENA_WIDTH
	var arena_height := Globals.ARENA_HEIGHT

	# Add padding to avoid edges (50 pixels from edge)
	var padding := 50.0
	var min_x := -arena_width / 2.0 + padding
	var max_x := arena_width / 2.0 - padding
	var min_y := -arena_height / 2.0 + padding
	var max_y := arena_height / 2.0 - padding

	return Vector2(
		randf_range(min_x, max_x),
		randf_range(min_y, max_y)
	)

func _behavior_charge(delta: float) -> Vector2:
	"""Charge behavior - wander until player is close, then charge in straight line."""
	var detect_radius: float = behavior_params.get("charge_detect_radius", DEFAULT_BEHAVIOR_PARAMS["charge_detect_radius"])

	charge_timer -= delta

	match charge_state:
		ChargeState.IDLE:
			if player and is_instance_valid(player):
				var dist := global_position.distance_to(player.global_position)
				if dist <= detect_radius:
					_charge_enter_alert_state()
			return _behavior_wander()

		ChargeState.ALERT:
			if charge_timer <= 0:
				_charge_enter_charging_state()
			if player and is_instance_valid(player):
				return global_position.direction_to(player.global_position) * 0.0
			return Vector2.ZERO

		ChargeState.CHARGING:
			if charge_timer <= 0:
				_charge_enter_cooldown_state()
			return charge_direction

		ChargeState.COOLDOWN:
			if charge_timer <= 0:
				charge_state = ChargeState.IDLE
			return _behavior_wander()

	return Vector2.ZERO

func _charge_enter_alert_state() -> void:
	"""Enter alert state - show visual indicator above head."""
	charge_state = ChargeState.ALERT
	charge_timer = behavior_params.get("charge_alert_duration", DEFAULT_BEHAVIOR_PARAMS["charge_alert_duration"])
	_spawn_charge_alert_indicator()

func _charge_enter_charging_state() -> void:
	"""Enter charging state - lock direction toward player position."""
	charge_state = ChargeState.CHARGING
	charge_timer = behavior_params.get("charge_duration", DEFAULT_BEHAVIOR_PARAMS["charge_duration"])

	if player and is_instance_valid(player):
		charge_target_pos = player.global_position
		charge_direction = global_position.direction_to(charge_target_pos)
	else:
		charge_direction = Vector2.RIGHT.rotated(randf() * TAU)

	if charge_alert_indicator:
		charge_alert_indicator.queue_free()
		charge_alert_indicator = null

func _charge_enter_cooldown_state() -> void:
	"""Enter cooldown state before returning to idle."""
	charge_state = ChargeState.COOLDOWN
	charge_timer = behavior_params.get("charge_cooldown", DEFAULT_BEHAVIOR_PARAMS["charge_cooldown"])

func _spawn_charge_alert_indicator() -> void:
	"""Create visual alert indicator above enemy head."""
	var alert_scene := preload("res://scenes/spawn_alert.tscn")
	charge_alert_indicator = alert_scene.instantiate()
	charge_alert_indicator.position = Vector2(0, -40)

	# Yellow/orange color for charge alert
	if charge_alert_indicator.has_node("OuterCircle"):
		charge_alert_indicator.get_node("OuterCircle").color = Color(1.0, 0.8, 0.0)
	if charge_alert_indicator.has_node("InnerCircle"):
		charge_alert_indicator.get_node("InnerCircle").color = Color(1.0, 0.9, 0.3)

	add_child(charge_alert_indicator)

func initialize(wave: int, type_id: String = "basic") -> void:
	"""Initialize enemy with type and wave-scaled stats."""
	is_initialized = true
	
	# Apply base type configuration
	_apply_type_config(type_id)
	
	# Get wave-scaled stats from Globals
	var scaled_stats := Globals.get_enemy_stats_for_wave(type_id, wave)
	max_health = scaled_stats.get("health", max_health)
	speed = scaled_stats.get("speed", speed)
	contact_damage = scaled_stats.get("contact_damage", contact_damage)
	
	current_health = max_health

func take_damage(amount: float) -> void:
	current_health -= amount
	
	# Emit damage event for damage numbers
	Events.damage_dealt.emit(global_position, amount)
	
	# Visual feedback - flash white then return to base tint
	var sprite_node = get_node_or_null("Sprite2D") if has_node("Sprite2D") else get_node_or_null("AnimatedSprite2D")
	if sprite_node:
		sprite_node.modulate = Color.WHITE
		var tween = create_tween()
		tween.tween_property(sprite_node, "modulate", color_tint, 0.1)
	
	if current_health <= 0:
		die()

func die() -> void:
	if is_dying:
		return
	is_dying = true
	
	# Clear status effects
	active_effects.clear()

	# Clean up charge alert indicator if active
	if charge_alert_indicator:
		charge_alert_indicator.queue_free()
		charge_alert_indicator = null

	# Handle explosive behavior
	if Globals.enemy_has_behavior(enemy_type, Globals.EnemyBehavior.EXPLOSIVE):
		_explode()
	
	# Emit signals for XP drop and kill tracking
	Events.enemy_killed.emit(self, global_position)
	Events.xp_dropped.emit(global_position, xp_value)
	Globals.total_kills += 1
	
	# Death effect (scale down and fade)
	var sprite_node = get_node_or_null("Sprite2D") if has_node("Sprite2D") else get_node_or_null("AnimatedSprite2D")
	if sprite_node:
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite_node, "scale", Vector2.ZERO, 0.15)
		tween.tween_property(sprite_node, "modulate:a", 0.0, 0.15)
		tween.chain().tween_callback(queue_free)
	else:
		queue_free()

func _explode() -> void:
	"""Handle explosion on death for EXPLOSIVE behavior enemies."""
	if explosion_radius <= 0 or explosion_damage <= 0:
		return
	
	Events.enemy_exploded.emit(global_position, explosion_radius, explosion_damage)
	
	# Damage player if in range
	if player and is_instance_valid(player):
		var dist := global_position.distance_to(player.global_position)
		if dist <= explosion_radius and player.has_method("take_damage"):
			player.take_damage(explosion_damage)
	
	# Damage other enemies in range (chain reaction potential)
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist <= explosion_radius and enemy.has_method("take_damage"):
			enemy.take_damage(explosion_damage * 0.5)  # Half damage to other enemies

# =============================================================================
# STATUS EFFECT SYSTEM
# =============================================================================

func _process_status_effects(delta: float) -> void:
	var expired_types: Array = []
	var total_dot_damage: float = 0.0
	
	for dtype in active_effects:
		var effect: StatusEffect = active_effects[dtype]
		var tick_damage: float = effect.process(delta)
		if tick_damage > 0:
			total_dot_damage += tick_damage
		if effect.is_expired():
			expired_types.append(dtype)
	
	# Apply accumulated DoT damage
	if total_dot_damage > 0:
		take_dot_damage(total_dot_damage)
	
	# Remove expired effects
	for dtype in expired_types:
		active_effects.erase(dtype)
		_update_status_visual()

## Apply a status effect (DoT and/or slow). Uses strongest-per-damage-type logic.
func apply_status_effect(damage_type: Globals.DamageType, dot_damage: float, dot_duration: float, dot_tick_rate: float = 1.0, slow_intensity: float = 0.0) -> void:
	if is_dying or (dot_damage <= 0 and slow_intensity <= 0) or dot_duration <= 0:
		return

	var new_effect := StatusEffect.new(damage_type, dot_damage, dot_duration, dot_tick_rate, slow_intensity)

	if active_effects.has(damage_type):
		var existing: StatusEffect = active_effects[damage_type]
		# Refresh with potentially stronger damage/slow
		existing.refresh(dot_damage, dot_duration, slow_intensity)
	else:
		active_effects[damage_type] = new_effect
		Events.status_effect_applied.emit(self, damage_type)

	_update_status_visual()

## Get movement speed multiplier from status effects (slow)
func get_movement_speed_multiplier() -> float:
	var multiplier: float = 1.0

	# Apply strongest slow effect
	var strongest_slow: float = 0.0
	for effect in active_effects.values():
		if effect.slow_intensity > strongest_slow:
			strongest_slow = effect.slow_intensity

	# Slow intensity reduces speed: 0.3 slow = 0.7x speed
	if strongest_slow > 0:
		multiplier *= (1.0 - strongest_slow)

	return multiplier

## Apply knockback impulse
func apply_knockback(force: float, direction: Vector2) -> void:
	if is_dying or mass <= 0:
		return

	# F = ma → a = F/m → velocity (instant impulse)
	var knockback_magnitude: float = force / mass
	knockback_velocity = direction.normalized() * knockback_magnitude

## Take DoT damage (separate from regular damage for potential future differentiation)
func take_dot_damage(amount: float) -> void:
	if is_dying:
		return

	current_health -= amount

	# Emit damage event for damage numbers (could use different color for DoT)
	Events.dot_damage_dealt.emit(global_position, amount)

	if current_health <= 0:
		die()

## Update visual tint based on active status effects
func _update_status_visual() -> void:
	var sprite_node = get_node_or_null("Sprite2D") if has_node("Sprite2D") else get_node_or_null("AnimatedSprite2D")
	if not sprite_node:
		return
	
	if active_effects.is_empty():
		# Reset to base color tint
		sprite_node.modulate = color_tint
		return
	
	# Start with base tint and blend status effect colors
	var final_color := color_tint
	
	if active_effects.has(Globals.DamageType.FIRE):
		final_color = final_color.lerp(Color(1.0, 0.5, 0.2, 1), 0.4)  # Orange tint
	if active_effects.has(Globals.DamageType.ELECTRIC):
		final_color = final_color.lerp(Color(0.5, 0.8, 1.0, 1), 0.4)  # Blue tint
	if active_effects.has(Globals.DamageType.PLASMA):
		final_color = final_color.lerp(Color(0.8, 0.4, 1.0, 1), 0.4)  # Purple tint
	
	sprite_node.modulate = final_color

## Check if enemy has a specific status effect
func has_status_effect(damage_type: Globals.DamageType) -> bool:
	return active_effects.has(damage_type)

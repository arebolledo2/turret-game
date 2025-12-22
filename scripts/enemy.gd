extends CharacterBody2D

# Behavior classes are globally available via class_name declarations
# - ChaseBehavior: res://scripts/components/behaviors/chase_behavior.gd
# - WanderBehavior: res://scripts/components/behaviors/wander_behavior.gd
# - ChargeBehavior: res://scripts/components/behaviors/charge_behavior.gd

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

# Behavior system - using strategy pattern
var current_behavior_type: GameEnums.EnemyBehavior = GameEnums.EnemyBehavior.CHASE
var behavior_params: Dictionary = {}
var behavior_instance: EnemyBehavior = null  # Current active behavior strategy

func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")

	# Connect to debug toggle event
	Events.hitbox_debug_toggled.connect(_on_debug_toggled)

	# If not initialized by spawner, initialize with defaults
	if not is_initialized:
		_apply_type_config(enemy_type)
		current_health = max_health

	# Initialize behavior instance
	_create_behavior_instance()

func _on_debug_toggled(type: int, _enabled: bool) -> void:
	if type == GameEnums.HitboxType.PHYSICS:
		queue_redraw()

func _draw() -> void:
	if not Globals.debug_hitbox_flags[GameEnums.HitboxType.PHYSICS]:
		return
	
	if has_node("CollisionShape2D"):
		var col_shape = $CollisionShape2D
		if col_shape.shape:
			var shape = col_shape.shape
			var offset = col_shape.position
			var color = Color(1.0, 1.0, 1.0, 0.4) # White for physics
			var outline_color = Color(1.0, 1.0, 1.0, 0.8)

			if shape is CircleShape2D:
				draw_circle(offset, shape.radius, color)
				draw_arc(offset, shape.radius, 0, TAU, 32, outline_color, 1.0)
			elif shape is RectangleShape2D:
				var rect = Rect2(offset - shape.size / 2.0, shape.size)
				draw_rect(rect, color, true)
				draw_rect(rect, outline_color, false, 1.0)
			elif shape is CapsuleShape2D:
				# Simple approximation for capsule drawing in debug
				var radius = shape.radius
				var height = shape.height
				draw_circle(offset + Vector2(0, -height/2 + radius), radius, color)
				draw_circle(offset + Vector2(0, height/2 - radius), radius, color)
				draw_rect(Rect2(offset + Vector2(-radius, -height/2 + radius), Vector2(radius * 2, height - radius * 2)), color, true)

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
	var behaviors: Array = type_def.get("behaviors", [GameEnums.EnemyBehavior.CHASE])
	if behaviors.is_empty():
		current_behavior_type = GameEnums.EnemyBehavior.CHASE
	else:
		# Priority: CHARGE > WANDER > CHASE
		if GameEnums.EnemyBehavior.CHARGE in behaviors:
			current_behavior_type = GameEnums.EnemyBehavior.CHARGE
		elif GameEnums.EnemyBehavior.WANDER in behaviors:
			current_behavior_type = GameEnums.EnemyBehavior.WANDER
		else:
			current_behavior_type = behaviors[0]

	# Load sprites from sprite folder (only for non-animated enemies)
	if type_def.has("sprite_folder") and has_node("Sprite2D"):
		var sprite_folder: String = type_def.get("sprite_folder", "res://assets/sprites/enemy_tiny")
		_load_sprites(sprite_folder)

	# Apply visual configuration
	_apply_visuals()

	# Configure hitboxes if available
	_configure_hitboxes(type_def)

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
		sprite.scale *= base_scale
		sprite.modulate = color_tint
		# Set initial texture
		if sprite_south:
			sprite.texture = sprite_south
	elif has_node("AnimatedSprite2D"):
		var anim_sprite = $AnimatedSprite2D
		anim_sprite.scale *= base_scale
		anim_sprite.modulate = color_tint
		# AnimatedSprite2D uses sprite_frames, not individual textures

func _configure_hitboxes(type_def: Dictionary) -> void:
	"""Configure unified hurtbox from type definition.
	The hurtbox now handles both receiving AND dealing damage (no separate DamageZone)."""
	# Configure unified hurtbox (for both receiving and dealing damage)
	if has_node("Hurtbox"):
		var hurtbox = $Hurtbox
		if hurtbox.has_node("CollisionShape2D"):
			hurtbox.get_node("CollisionShape2D").debug_color = Color(1.0, 0.5, 0.0, 0.4) # Orange for hurtbox
			
		if type_def.has("hurtbox") and hurtbox.has_method("configure"):
			var hurtbox_config: Dictionary = type_def.get("hurtbox", {})
			var shape_type: String = hurtbox_config.get("type", "circle")
			var size: Vector2 = hurtbox_config.get("size", Vector2(24, 24))
			hurtbox.configure(shape_type, size)

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
		if current_behavior_type == GameEnums.EnemyBehavior.CHARGE and behavior_instance is ChargeBehavior:
			var charge_behavior := behavior_instance as ChargeBehavior
			effective_speed *= charge_behavior.get_speed_multiplier()

		velocity = movement_direction.normalized() * effective_speed

	move_and_slide()

	# Update sprite based on velocity (works for all behaviors)
	if velocity.length() > 0:
		_update_direction_sprite(velocity.normalized())

	# Contact damage now handled by EnemyHurtbox component

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
# BEHAVIOR SYSTEM - Strategy Pattern
# =============================================================================

## Create behavior instance based on current behavior type
func _create_behavior_instance() -> void:
	# Clean up old behavior
	if behavior_instance:
		behavior_instance.exit()
		behavior_instance = null

	# Create new behavior instance
	match current_behavior_type:
		GameEnums.EnemyBehavior.CHASE:
			behavior_instance = ChaseBehavior.new(self, behavior_params)
		GameEnums.EnemyBehavior.WANDER:
			behavior_instance = WanderBehavior.new(self, behavior_params)
		GameEnums.EnemyBehavior.CHARGE:
			behavior_instance = ChargeBehavior.new(self, behavior_params)
		_:
			behavior_instance = ChaseBehavior.new(self, behavior_params)

	# Call enter() to initialize behavior state
	if behavior_instance:
		behavior_instance.enter()

## Execute the current behavior and return movement direction
func _execute_current_behavior(delta: float) -> Vector2:
	if not behavior_instance:
		_create_behavior_instance()

	if behavior_instance:
		return behavior_instance.execute(delta)

	return Vector2.ZERO

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

	# Clean up behavior instance (handles charge alert cleanup if needed)
	if behavior_instance:
		behavior_instance.exit()
		behavior_instance = null

	# Handle explosive behavior
	if Globals.enemy_has_behavior(enemy_type, GameEnums.EnemyBehavior.EXPLOSIVE):
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
		var effect: StatusEffect = active_effects[dtype] as StatusEffect
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
func apply_status_effect(damage_type: GameEnums.DamageType, dot_damage: float, dot_duration: float, dot_tick_rate: float = 1.0, slow_intensity: float = 0.0) -> void:
	if is_dying or (dot_damage <= 0 and slow_intensity <= 0) or dot_duration <= 0:
		return

	var new_effect := StatusEffect.new(damage_type, dot_damage, dot_duration, dot_tick_rate, slow_intensity)

	if active_effects.has(damage_type):
		var existing: StatusEffect = active_effects[damage_type] as StatusEffect
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
	
	if active_effects.has(GameEnums.DamageType.FIRE):
		final_color = final_color.lerp(Color(1.0, 0.5, 0.2, 1), 0.4)  # Orange tint
	if active_effects.has(GameEnums.DamageType.ELECTRIC):
		final_color = final_color.lerp(Color(0.5, 0.8, 1.0, 1), 0.4)  # Blue tint
	if active_effects.has(GameEnums.DamageType.PLASMA):
		final_color = final_color.lerp(Color(0.8, 0.4, 1.0, 1), 0.4)  # Purple tint
	
	sprite_node.modulate = final_color

## Check if enemy has a specific status effect
func has_status_effect(damage_type: GameEnums.DamageType) -> bool:
	return active_effects.has(damage_type)

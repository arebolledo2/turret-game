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

func _ready() -> void:
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	
	# If not initialized by spawner, initialize with defaults
	if not is_initialized:
		_apply_type_config(enemy_type)
		current_health = max_health

func _apply_type_config(type_id: String) -> void:
	"""Load configuration from ENEMY_TYPES and apply to this enemy."""
	enemy_type = type_id
	var type_def: Dictionary = Globals.ENEMY_TYPES.get(type_id, Globals.ENEMY_TYPES["basic"])
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
	
	# Load color tint
	color_tint = type_def.get("color_tint", Color.WHITE)
	
	# Load sprites from sprite folder
	var sprite_folder: String = type_def.get("sprite_folder", "res://assets/sprites/enemy")
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
	if $Sprite2D:
		$Sprite2D.scale = Vector2(base_scale, base_scale)
		$Sprite2D.modulate = color_tint
		# Set initial texture
		if sprite_south:
			$Sprite2D.texture = sprite_south

func _physics_process(delta: float) -> void:
	if is_dying:
		return
		
	# Process status effects
	_process_status_effects(delta)
	
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return
	
	# Move towards player (simple chase AI)
	var direction := global_position.direction_to(player.global_position)
	velocity = direction * speed
	move_and_slide()
	
	# Update sprite based on movement direction
	_update_direction_sprite(direction)
	
	# Check for collision with player
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider = collision.get_collider()
		if collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(contact_damage)

func _update_direction_sprite(direction: Vector2) -> void:
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
	$Sprite2D.modulate = Color.WHITE
	var tween = create_tween()
	tween.tween_property($Sprite2D, "modulate", color_tint, 0.1)
	
	if current_health <= 0:
		die()

func die() -> void:
	if is_dying:
		return
	is_dying = true
	
	# Clear status effects
	active_effects.clear()
	
	# Handle explosive behavior
	if Globals.enemy_has_behavior(enemy_type, Globals.EnemyBehavior.EXPLOSIVE):
		_explode()
	
	# Emit signals for XP drop and kill tracking
	Events.enemy_killed.emit(self, global_position)
	Events.xp_dropped.emit(global_position, xp_value)
	Globals.total_kills += 1
	
	# Death effect (scale down and fade)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property($Sprite2D, "scale", Vector2.ZERO, 0.15)
	tween.tween_property($Sprite2D, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)

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

## Apply a status effect (DoT). Uses strongest-per-damage-type logic.
func apply_status_effect(damage_type: Globals.DamageType, dot_damage: float, dot_duration: float, dot_tick_rate: float = 1.0) -> void:
	if is_dying or dot_damage <= 0 or dot_duration <= 0:
		return
	
	var new_effect := StatusEffect.new(damage_type, dot_damage, dot_duration, dot_tick_rate)
	
	if active_effects.has(damage_type):
		var existing: StatusEffect = active_effects[damage_type]
		# Refresh with potentially stronger damage
		existing.refresh(dot_damage, dot_duration)
	else:
		active_effects[damage_type] = new_effect
		Events.status_effect_applied.emit(self, damage_type)
	
	_update_status_visual()

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
	if active_effects.is_empty():
		# Reset to base color tint
		$Sprite2D.modulate = color_tint
		return
	
	# Start with base tint and blend status effect colors
	var final_color := color_tint
	
	if active_effects.has(Globals.DamageType.FIRE):
		final_color = final_color.lerp(Color(1.0, 0.5, 0.2, 1), 0.4)  # Orange tint
	if active_effects.has(Globals.DamageType.ELECTRIC):
		final_color = final_color.lerp(Color(0.5, 0.8, 1.0, 1), 0.4)  # Blue tint
	if active_effects.has(Globals.DamageType.PLASMA):
		final_color = final_color.lerp(Color(0.8, 0.4, 1.0, 1), 0.4)  # Purple tint
	
	$Sprite2D.modulate = final_color

## Check if enemy has a specific status effect
func has_status_effect(damage_type: Globals.DamageType) -> bool:
	return active_effects.has(damage_type)


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
var mass: float = 1.0 # Resistance to knockback

var current_health: float
var player: Node2D = null

var is_dying: bool = false
var is_initialized: bool = false

# Behavior system - using strategy pattern (managed by EnemyMovement)
var current_behavior_type: GameEnums.EnemyBehavior = GameEnums.EnemyBehavior.CHASE
var behavior_params: Dictionary = {}

# Components
@onready var movement: EnemyMovement = $Components/EnemyMovement
@onready var visuals: EnemyVisuals = $Components/EnemyVisuals
@onready var status_effects: EnemyStatusEffects = $Components/EnemyStatusEffects

func _ready() -> void:
	print("DEBUG Enemy: _ready() START")
	add_to_group("enemies")
	
	print("DEBUG Enemy: Checking game mode for targeting...")
	# In Tech Defense mode, target the defense target instead of player
	if GameModeService.should_spawn_defense_target():
		print("DEBUG Enemy: Tech Defense mode - looking for defense target")
		var defense_target = get_tree().get_first_node_in_group("defense_targets")
		if defense_target:
			player = defense_target
			print("DEBUG Enemy: Defense target found!")
		else:
			# Fallback to player if defense target doesn't exist yet
			player = get_tree().get_first_node_in_group("player")
			print("DEBUG Enemy: Defense target NOT found, using player")
	else:
		player = get_tree().get_first_node_in_group("player")
		print("DEBUG Enemy: Normal mode - using player")

	print("DEBUG Enemy: About to connect debug toggle...")
	# Connect to debug toggle event
	if not Events.hitbox_debug_toggled.is_connected(_on_debug_toggled):
		Events.hitbox_debug_toggled.connect(_on_debug_toggled)
	print("DEBUG Enemy: Debug toggle connected")

	print("DEBUG Enemy: Checking if components already initialized...")
	# Components must be initialized in _ready (when @onready vars are available)
	# Even if enemy stats were initialized by spawner, we still need to init components
	if movement != null and movement.enemy != null:
		print("DEBUG Enemy: Components already initialized, skipping")
		return
	
	print("DEBUG Enemy: About to initialize components...")
	# Initialize components (must be done in _ready when @onready vars are available)
	_initialize_components()
	
	print("DEBUG Enemy _ready complete: player target = ", player)

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
				draw_circle(offset + Vector2(0, -height / 2 + radius), radius, color)
				draw_circle(offset + Vector2(0, height / 2 - radius), radius, color)
				draw_rect(Rect2(offset + Vector2(-radius, -height / 2 + radius), Vector2(radius * 2, height - radius * 2)), color, true)

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

	# Note: Sprite loading and visual configuration now handled by EnemyVisuals component

	# Configure hitboxes if available
	_configure_hitboxes(type_def)

func _initialize_components() -> void:
	"""Initialize all components with their dependencies."""
	# Safety check - ensure components are loaded
	if not movement or not visuals or not status_effects:
		push_error("Enemy components not found! Ensure Components node structure exists in scene.")
		return

	# Initialize movement component
	movement.initialize(self, speed, mass, current_behavior_type, behavior_params)

	# Initialize visuals component (with sprite folder if applicable)
	var sprite_folder := ""
	var type_def := EnemyRegistry.get_type(enemy_type)
	if type_def.has("sprite_folder"):
		sprite_folder = type_def.get("sprite_folder", "")
	visuals.initialize(self, base_scale, color_tint, sprite_folder)

	# Initialize status effects component
	status_effects.initialize(self)

	# Connect status effect visual updates
	status_effects.status_visual_changed.connect(_on_status_visual_changed)

func _on_status_visual_changed(effects: Dictionary) -> void:
	"""Handle status effect visual updates from component."""
	visuals.update_status_visual(effects)

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

	# Process status effects and get DoT damage
	var dot_damage: float = status_effects.process(delta)
	if dot_damage > 0:
		take_dot_damage(dot_damage)

	if player == null or not is_instance_valid(player):
		# Re-acquire target (defense target in Tech Defense, otherwise player)
		if GameModeService.should_spawn_defense_target():
			player = get_tree().get_first_node_in_group("defense_targets")
		if player == null: # Fallback to player if no defense target
			player = get_tree().get_first_node_in_group("player")
		if player == null:
			return

	# Get movement velocity from component (includes knockback, AI, and speed modifiers)
	var speed_multiplier: float = status_effects.get_movement_speed_multiplier()
	velocity = movement.process(delta, speed_multiplier)

	move_and_slide()

	# Update sprite based on velocity (works for all behaviors)
	if velocity.length() > 0:
		visuals.update_direction_sprite(velocity.normalized())

	# Contact damage now handled by EnemyHurtbox component

func take_damage(amount: float, is_crit: bool = false) -> void:
	current_health -= amount

	# Emit damage event for damage numbers with crit flag
	Events.damage_dealt.emit(global_position, amount, is_crit)

	# Visual feedback - flash white
	visuals.apply_damage_flash()

	if current_health <= 0:
		die()

func die() -> void:
	if is_dying:
		return
	is_dying = true

	# Clear status effects
	status_effects.clear_all_effects()

	# Clean up behavior instance (handles charge alert cleanup if needed)
	movement.cleanup()

	# Handle explosive behavior
	if Globals.enemy_has_behavior(enemy_type, GameEnums.EnemyBehavior.EXPLOSIVE):
		_explode()

	# Emit signals for XP drop and kill tracking
	Events.enemy_killed.emit(self, global_position)
	Events.xp_dropped.emit(global_position, xp_value)
	Globals.total_kills += 1

	# Death effect (scale down and fade)
	visuals.play_death_animation(queue_free)

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
			enemy.take_damage(explosion_damage * 0.5) # Half damage to other enemies

# =============================================================================
# DELEGATED METHODS - Facades for components (test compatibility)
# =============================================================================

func apply_status_effect(damage_type: GameEnums.DamageType, dot_damage: float, dot_duration: float, dot_tick_rate: float = 1.0, slow_intensity: float = 0.0) -> void:
	"""Apply a status effect via component."""
	if is_dying:
		return
	status_effects.apply_status_effect(damage_type, dot_damage, dot_duration, dot_tick_rate, slow_intensity)

func apply_knockback(force: float, direction: Vector2) -> void:
	"""Apply knockback via movement component."""
	if is_dying:
		return
	movement.apply_knockback(force, direction)

func take_dot_damage(amount: float) -> void:
	"""Take DoT damage (separate from regular damage for potential future differentiation)."""
	if is_dying:
		return

	current_health -= amount

	# Emit damage event for damage numbers (could use different color for DoT)
	Events.dot_damage_dealt.emit(global_position, amount)

	if current_health <= 0:
		die()

func get_health_percent() -> float:
	"""Get current health as a percentage (0.0 to 1.0)."""
	if max_health <= 0:
		return 0.0
	return current_health / max_health

func has_status_effect(damage_type: GameEnums.DamageType) -> bool:
	"""Check if enemy has a specific status effect."""
	return status_effects.has_status_effect(damage_type)

# Property facades for test compatibility
var active_effects: Dictionary:
	get:
		return status_effects.get_active_effects() if status_effects else {}

var knockback_velocity: Vector2:
	get:
		return movement.knockback_velocity if movement else Vector2.ZERO
	set(value):
		if movement:
			movement.knockback_velocity = value

var behavior_instance: EnemyBehavior:
	get:
		return movement.behavior_instance if movement else null

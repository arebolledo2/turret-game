extends Node
class_name EnemyMovement

## Handles enemy AI behavior and movement logic.
##
## Responsibilities:
## - Manage behavior instances (Chase, Wander, Charge)
## - Execute behavior strategy to get movement direction
## - Apply knockback physics
## - Calculate effective speed with modifiers

# State
var knockback_velocity: Vector2 = Vector2.ZERO
var current_behavior_type: GameEnums.EnemyBehavior = GameEnums.EnemyBehavior.CHASE
var behavior_params: Dictionary = {}
var behavior_instance: EnemyBehavior = null # Current active behavior strategy

# Dependencies (set via initialize)
var enemy: CharacterBody2D = null
var player: Node2D = null

# Config
var speed: float = 150.0
var mass: float = 1.0 # Resistance to knockback

func initialize(p_enemy: CharacterBody2D, p_speed: float, p_mass: float, p_behavior_type: GameEnums.EnemyBehavior, p_behavior_params: Dictionary) -> void:
	"""Initialize component with required references."""
	enemy = p_enemy
	speed = p_speed
	mass = p_mass
	current_behavior_type = p_behavior_type
	behavior_params = p_behavior_params
	assert(enemy != null, "EnemyMovement: enemy reference required")

	# Get player reference (or defense target in Tech Defense mode)
	if enemy and is_instance_valid(enemy):
		if GameModeService.should_spawn_defense_target():
			player = enemy.get_tree().get_first_node_in_group("defense_targets")
		if player == null: # Fallback to player
			player = enemy.get_tree().get_first_node_in_group("player")
	
	print("DEBUG EnemyMovement: Target = ", player, " at pos ", player.global_position if player else "null")
	
	# Create behavior instance
	_create_behavior_instance()

func process(delta: float, speed_multiplier: float) -> Vector2:
	"""Main update function - returns velocity for move_and_slide."""
	# Find player/target if not valid
	if player == null or not is_instance_valid(player):
		if enemy == null or not is_instance_valid(enemy):
			return Vector2.ZERO
		
		# Re-acquire target (defense target in Tech Defense, otherwise player)
		if GameModeService.should_spawn_defense_target():
			player = enemy.get_tree().get_first_node_in_group("defense_targets")
		if player == null: # Fallback to player
			player = enemy.get_tree().get_first_node_in_group("player")
		if player == null:
			return Vector2.ZERO

	# Execute behavior to get movement direction
	var movement_direction: Vector2 = _execute_current_behavior(delta)

	# Apply knockback first (overrides AI movement temporarily)
	if knockback_velocity.length() > Globals.KNOCKBACK_MIN_VELOCITY:
		var velocity := knockback_velocity
		knockback_velocity *= (1.0 - Globals.KNOCKBACK_DECAY_RATE * delta)
		return velocity
	else:
		knockback_velocity = Vector2.ZERO
		# Normal AI movement with behavior-based direction
		var effective_speed: float = speed * speed_multiplier

		# Apply charge speed boost if charging
		if current_behavior_type == GameEnums.EnemyBehavior.CHARGE and behavior_instance is ChargeBehavior:
			var charge_behavior := behavior_instance as ChargeBehavior
			effective_speed *= charge_behavior.get_speed_multiplier()

		return movement_direction.normalized() * effective_speed

func apply_knockback(force: float, direction: Vector2) -> void:
	"""Apply knockback impulse."""
	if mass <= 0:
		return

	# F = ma → a = F/m → velocity (instant impulse)
	var knockback_magnitude: float = force / mass
	knockback_velocity = direction.normalized() * knockback_magnitude

# =============================================================================
# BEHAVIOR SYSTEM - Strategy Pattern
# =============================================================================

func _create_behavior_instance() -> void:
	"""Create behavior instance based on current behavior type."""
	# Clean up old behavior
	if behavior_instance:
		behavior_instance.exit()
		behavior_instance = null

	# Create new behavior instance
	match current_behavior_type:
		GameEnums.EnemyBehavior.CHASE:
			behavior_instance = ChaseBehavior.new(enemy, behavior_params)
		GameEnums.EnemyBehavior.WANDER:
			behavior_instance = WanderBehavior.new(enemy, behavior_params)
		GameEnums.EnemyBehavior.CHARGE:
			behavior_instance = ChargeBehavior.new(enemy, behavior_params)
		_:
			behavior_instance = ChaseBehavior.new(enemy, behavior_params)

	# Call enter() to initialize behavior state
	if behavior_instance:
		behavior_instance.enter()

func _execute_current_behavior(delta: float) -> Vector2:
	"""Execute the current behavior and return movement direction."""
	if not behavior_instance:
		_create_behavior_instance()

	if behavior_instance:
		return behavior_instance.execute(delta)

	return Vector2.ZERO

func cleanup() -> void:
	"""Clean up behavior instance on enemy death."""
	if behavior_instance:
		behavior_instance.exit()
		behavior_instance = null

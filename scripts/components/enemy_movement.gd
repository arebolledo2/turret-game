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
var player: Node2D = null # Current target (can be player or defense target)
var player_character: Node2D = null # Always the actual player (for aggro checks)
var defense_target: Node2D = null # Defense target reference in defense mode
var is_in_defense_mode: bool = false # Track if we're in defense mode

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

	# Get player and defense target references
	if enemy and is_instance_valid(enemy):
		player_character = enemy.get_tree().get_first_node_in_group("player")
		is_in_defense_mode = GameModeService.should_spawn_defense_target()
		
		if is_in_defense_mode:
			defense_target = enemy.get_tree().get_first_node_in_group("defense_targets")
			# Start targeting defense target in defense mode
			player = defense_target if defense_target else player_character
		else:
			# Normal mode - always target player
			player = player_character

	var pos_str = str(player.global_position) if player else "null"
	DebugService.log(DebugService.AI, "EnemyMovement: Target = %s at pos %s" % [player, pos_str])
	
	# Create behavior instance
	_create_behavior_instance()

func process(delta: float, speed_multiplier: float) -> Vector2:
	"""Main update function - returns velocity for move_and_slide."""
	# Find player/target if not valid
	if player == null or not is_instance_valid(player):
		if enemy == null or not is_instance_valid(enemy):
			return Vector2.ZERO
		
		# Re-acquire references
		player_character = enemy.get_tree().get_first_node_in_group("player")
		if is_in_defense_mode:
			defense_target = enemy.get_tree().get_first_node_in_group("defense_targets")
			player = defense_target if defense_target else player_character
		else:
			player = player_character
		if player == null:
			return Vector2.ZERO
	
	# Defense mode: Check player proximity for target switching
	_check_defense_mode_aggro()

	# Execute behavior to get movement direction
	var movement_direction: Vector2 = _execute_current_behavior(delta)

	# Apply knockback first (overrides AI movement temporarily)
	if knockback_velocity.length() > GameConstants.KNOCKBACK_MIN_VELOCITY:
		var velocity := knockback_velocity
		# Decay knockback over time
		knockback_velocity *= (1.0 - GameConstants.KNOCKBACK_DECAY_RATE * delta)
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

# =============================================================================
# DEFENSE MODE AGGRO SYSTEM
# =============================================================================

func _check_defense_mode_aggro() -> void:
	"""Check if enemy should switch targets based on player proximity in defense mode."""
	if not is_in_defense_mode:
		return
	
	if not enemy or not is_instance_valid(enemy):
		return
	
	# Re-acquire player_character if null (may not have been available at init time)
	if not player_character or not is_instance_valid(player_character):
		player_character = enemy.get_tree().get_first_node_in_group("player")
		if not player_character:
			return
	
	var distance_to_player: float = enemy.global_position.distance_to(player_character.global_position)
	var is_targeting_player: bool = (player == player_character)
	
	# Debug output
	if randf() < 0.01: # Only print 1% of the time to avoid spam
		DebugService.log(DebugService.AI, "Aggro Check: dist=%s targeting_player=%s aggro_range=%s" % [distance_to_player, is_targeting_player, GameConstants.DEFENSE_MODE_PLAYER_AGGRO_RANGE])
	
	if is_targeting_player:
		# Currently targeting player - check if should switch back to defense target
		if distance_to_player > GameConstants.DEFENSE_MODE_PLAYER_DEAGGRO_RANGE:
			DebugService.log(DebugService.AI, "Switching to defense target (player too far: %s)" % distance_to_player)
			if defense_target and is_instance_valid(defense_target):
				player = defense_target
				# IMPORTANT: Update enemy.player so ChaseBehavior follows correct target
				enemy.player = defense_target
	else:
		# Currently targeting defense target - check if should switch to player
		if distance_to_player <= GameConstants.DEFENSE_MODE_PLAYER_AGGRO_RANGE:
			DebugService.log(DebugService.AI, "Switching to player (within range: %s)" % distance_to_player)
			player = player_character
			# IMPORTANT: Update enemy.player so ChaseBehavior follows correct target
			enemy.player = player_character

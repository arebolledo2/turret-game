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
		is_in_defense_mode = GameModeService.is_defense_target_mode()
		
		if is_in_defense_mode:
			defense_target = enemy.get_tree().get_first_node_in_group("defense_targets")
			# Start targeting defense target in defense/escort mode
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
		var current_knockback := knockback_velocity
		# Exponential-style drag with a clamped move_toward keeps the impulse
		# smooth while remaining stable if a frame takes unusually long.
		var decay_fraction := clampf(GameConstants.KNOCKBACK_DECAY_RATE * maxf(delta, 0.0), 0.0, 1.0)
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, current_knockback.length() * decay_fraction)
		if knockback_velocity.length() <= GameConstants.KNOCKBACK_MIN_VELOCITY:
			knockback_velocity = Vector2.ZERO
		return current_knockback
	else:
		knockback_velocity = Vector2.ZERO
		# Normal AI movement with behavior-based direction
		var effective_speed: float = speed * speed_multiplier

		# Apply charge speed boost if charging
		if current_behavior_type == GameEnums.EnemyBehavior.CHARGE and behavior_instance is ChargeBehavior:
			var charge_behavior := behavior_instance as ChargeBehavior
			effective_speed *= charge_behavior.get_speed_multiplier()

		# Keep enemies readable as a group without enabling enemy-enemy body
		# collisions, which can make a wave lock up against itself.
		var desired_direction := movement_direction.normalized()
		var separation_direction := _get_separation_direction()
		if separation_direction.length_squared() > 0.0:
			desired_direction = (desired_direction + separation_direction * GameConstants.ENEMY_SEPARATION_STRENGTH).normalized()

		return desired_direction * effective_speed

func apply_knockback(force: float, direction: Vector2) -> void:
	"""Apply knockback impulse."""
	if mass <= 0:
		return

	# F = ma → a = F/m → velocity (instant impulse)
	var knockback_direction := direction.normalized()
	if knockback_direction == Vector2.ZERO:
		return

	var knockback_magnitude: float = force / mass
	# Treat each hit as an impulse so rapid hits build naturally, but cap the
	# result to keep large explosions from producing unplayable launches.
	knockback_velocity = (knockback_velocity + knockback_direction * knockback_magnitude).limit_length(GameConstants.KNOCKBACK_MAX_VELOCITY)


func _get_separation_direction() -> Vector2:
	"""Return a normalized steering vector away from nearby living enemies."""
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return Vector2.ZERO

	var separation := Vector2.ZERO
	var radius := GameConstants.ENEMY_SEPARATION_RADIUS
	var radius_squared := radius * radius
	var enemies := EnemyQuery.get_enemies(enemy.get_tree())

	for other in enemies:
		if other == enemy or not is_instance_valid(other):
			continue
		# Tech drops share the enemies group for targeting, but should not push
		# combatants around while they are being collected or destroyed.
		if not other.has_method("apply_knockback") or other.get("is_dying") == true:
			continue

		var other_node := other as Node2D
		if other_node == null:
			continue

		var offset := enemy.global_position - other_node.global_position
		var distance_squared := offset.length_squared()
		if distance_squared >= radius_squared:
			continue

		if distance_squared <= 0.0001:
			# Give perfectly overlapping enemies a deterministic nudge so they can
			# separate instead of remaining locked at the same position.
			var angle := float(enemy.get_instance_id() % 16) * TAU / 16.0
			offset = Vector2.from_angle(angle)
			distance_squared = 1.0

		var distance := sqrt(distance_squared)
		var weight := 1.0 - distance / radius
		separation += offset / distance * weight

	return separation.normalized()

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

class_name WanderBehavior
extends EnemyBehavior

## Wander behavior - enemy randomly moves around the arena with pauses
## Alternates between moving to random targets and standing still

## Wander state
var wander_target: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var is_wandering: bool = false  # true = moving, false = paused

## Get default parameters for wander behavior
static func get_default_params() -> Dictionary:
	return {
		"wander_pause_min": 1.5,
		"wander_pause_max": 3.0,
		"wander_move_min": 2.0,
		"wander_move_max": 4.0,
		"arrival_distance": 20.0,  # How close to target before picking new one
		"arena_padding": 50.0,     # Padding from arena edges
	}

## Called when behavior is activated
func enter() -> void:
	# Initialize with pause state
	var pause_min: float = params.get("wander_pause_min", get_default_params()["wander_pause_min"])
	var pause_max: float = params.get("wander_pause_max", get_default_params()["wander_pause_max"])
	wander_timer = GameRandom.gameplay.randf_range(pause_min, pause_max)
	is_wandering = false

## Execute wander behavior
func execute(delta: float) -> Vector2:
	var pause_min: float = params.get("wander_pause_min", get_default_params()["wander_pause_min"])
	var pause_max: float = params.get("wander_pause_max", get_default_params()["wander_pause_max"])
	var move_min: float = params.get("wander_move_min", get_default_params()["wander_move_min"])
	var move_max: float = params.get("wander_move_max", get_default_params()["wander_move_max"])
	var arrival_distance: float = params.get("arrival_distance", get_default_params()["arrival_distance"])

	# Update timer
	wander_timer -= delta

	# Switch between wandering and pausing
	if wander_timer <= 0:
		is_wandering = not is_wandering

		if is_wandering:
			# Pick random target anywhere in arena
			wander_target = _get_random_arena_position()
			wander_timer = GameRandom.gameplay.randf_range(move_min, move_max)
		else:
			# Pause
			wander_timer = GameRandom.gameplay.randf_range(pause_min, pause_max)

	# Check if reached target (within arrival distance)
	if is_wandering and enemy.global_position.distance_to(wander_target) < arrival_distance:
		# Reached target early - switch to pause
		is_wandering = false
		wander_timer = GameRandom.gameplay.randf_range(pause_min, pause_max)

	# Return movement direction
	if is_wandering:
		return enemy.global_position.direction_to(wander_target)
	else:
		return Vector2.ZERO

## Get a random position within the arena bounds
func _get_random_arena_position() -> Vector2:
	var arena_width := GameConstants.ARENA_WIDTH
	var arena_height := GameConstants.ARENA_HEIGHT
	var padding: float = params.get("arena_padding", get_default_params()["arena_padding"])

	var min_x := -arena_width / 2.0 + padding
	var max_x := arena_width / 2.0 - padding
	var min_y := -arena_height / 2.0 + padding
	var max_y := arena_height / 2.0 - padding

	return Vector2(
		GameRandom.gameplay.randf_range(min_x, max_x),
		GameRandom.gameplay.randf_range(min_y, max_y)
	)

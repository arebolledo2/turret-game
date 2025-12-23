extends Node

## Service for managing active game modes and their logic

# Currently active modes: { group_id: mode_id }
var active_modes: Dictionary = {}

func _ready() -> void:
	# Initialize default modes
	_initialize_defaults()

func _initialize_defaults() -> void:
	# For each group in registry, set the default mode
	# For now we only have one group: spawn_location
	var spawn_mode = GameModeRegistry.get_default_mode_for_group("spawn_location")
	if spawn_mode != -1:
		active_modes["spawn_location"] = spawn_mode

func set_mode(mode_id: GameEnums.GameMode) -> void:
	var config = GameModeRegistry.get_mode_config(mode_id)
	if config.is_empty():
		return
		
	var group = config.get("group")
	active_modes[group] = mode_id
	
	print("Game Mode Set: ", config.get("name"), " (Group: ", group, ")")

func is_mode_active(mode_id: GameEnums.GameMode) -> bool:
	for group in active_modes:
		if active_modes[group] == mode_id:
			return true
	return false

func reset_state() -> void:
	active_modes.clear()
	_initialize_defaults()

# =============================================================================
# GAME MODE LOGIC HOOKS
# =============================================================================

func get_random_spawn_position(spawn_zones: Array[Rect2]) -> Vector2:
	"""
	Calculates a random spawn position based on the active spawn_location mode.
	"""
	var mode = active_modes.get("spawn_location", GameEnums.GameMode.SENTINEL)
	
	match mode:
		GameEnums.GameMode.SENTINEL:
			# Original behavior: pick from edge zones
			if spawn_zones.is_empty():
				return Vector2.ZERO
			var zone := spawn_zones[randi() % spawn_zones.size()]
			return Vector2(
				zone.position.x + randf() * zone.size.x,
				zone.position.y + randf() * zone.size.y
			)
			
		GameEnums.GameMode.INVASION:
			# New behavior: pick anywhere in the arena
			var half_width := GameConstants.ARENA_WIDTH / 2.0
			var half_height := GameConstants.ARENA_HEIGHT / 2.0
			var inset := 40.0 # Keep slightly away from the absolute walls
			
			return Vector2(
				randf_range(-half_width + inset, half_width - inset),
				randf_range(-half_height + inset, half_height - inset)
			)
			
	return Vector2.ZERO

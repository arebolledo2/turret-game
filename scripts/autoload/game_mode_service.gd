extends Node

## Service for managing active game modes and their logic

# Currently active modes: { group_id: mode_id }
var active_modes: Dictionary = {}

func _ready() -> void:
	# Initialize default modes
	_initialize_defaults()

func _initialize_defaults() -> void:
	# For each group in registry, set the default mode
	var spawn_mode = GameModeRegistry.get_default_mode_for_group("spawn_location")
	if spawn_mode != -1:
		active_modes["spawn_location"] = spawn_mode
	
	var win_mode = GameModeRegistry.get_default_mode_for_group("win_condition")
	if win_mode != -1:
		active_modes["win_condition"] = win_mode

func set_mode(mode_id: GameEnums.GameMode) -> void:
	var config = GameModeRegistry.get_mode_config(mode_id)
	if config.is_empty():
		print("ERROR: Game mode config not found for ID: ", mode_id)
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

# =============================================================================
# WIN CONDITION MODE HOOKS
# =============================================================================

func get_win_condition_mode() -> GameEnums.GameMode:
	"""
	Returns the active win condition mode.
	"""
	return active_modes.get("win_condition", GameEnums.GameMode.SURVIVAL)

func should_spawn_defense_target() -> bool:
	"""
	Returns true if the TECH_DEFENSE mode is active and requires a defense target.
	"""
	return is_mode_active(GameEnums.GameMode.TECH_DEFENSE)

func should_spawn_tunnel_door() -> bool:
	"""
	Returns true if any tunneling mode is active and requires a door entity.
	"""
	return is_mode_active(GameEnums.GameMode.TUNNELING_TIMED) or is_mode_active(GameEnums.GameMode.TUNNELING_ALERT)

func is_alert_mode_active() -> bool:
	"""
	Returns true if TUNNELING_ALERT mode is active (spawn escalation behavior).
	"""
	return is_mode_active(GameEnums.GameMode.TUNNELING_ALERT)

func get_spawn_rate_multiplier(time_since_alert: float) -> float:
	"""
	Calculates spawn rate multiplier for TUNNELING_ALERT mode.
	User decision: More aggressive than +20% every 10s.
	Implementation: +30% every 8 seconds after alert starts.
	
	Args:
		time_since_alert: Seconds since alert mode activated (soft timer expired)
	
	Returns:
		Multiplier for spawn rate (1.0 = normal, 1.3 = 30% faster, etc.)
	"""
	if not is_alert_mode_active():
		return 1.0
	
	if time_since_alert <= 0:
		return 1.0
	
	# +30% every 8 seconds
	var intervals_passed = floor(time_since_alert / 8.0)
	return 1.0 + (intervals_passed * 0.3)

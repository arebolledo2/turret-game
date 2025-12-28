extends Node

## Service for managing active game modes and their logic

# Currently active modes: { group_id: mode_id }
var active_modes: Dictionary = {}

func _ready() -> void:
	# Initialize default modes
	_initialize_defaults()

func _initialize_defaults() -> void:
	# For each group in registry, set the default mode
	var spawn_mode: int = GameModeRegistry.get_default_mode_for_group("spawn_location")
	if spawn_mode != -1:
		active_modes["spawn_location"] = spawn_mode
	
	var win_mode: int = GameModeRegistry.get_default_mode_for_group("win_condition")
	if win_mode != -1:
		active_modes["win_condition"] = win_mode
	
	var arena_mode: int = GameModeRegistry.get_default_mode_for_group("arena_type")
	if arena_mode != -1:
		active_modes["arena_type"] = arena_mode
		_update_arena_bounds()

func set_mode(mode_id: GameEnums.GameMode) -> void:
	var config: Dictionary = GameModeRegistry.get_mode_config(mode_id)
	if config.is_empty():
		DebugService.error(DebugService.SYSTEMS, "Game mode config not found for ID: %s" % mode_id)
		return

	var group: String = config.get("group")
	active_modes[group] = mode_id

	# Update arena bounds if arena type changed
	if group == "arena_type":
		_update_arena_bounds()

	DebugService.log(DebugService.SYSTEMS, "Game Mode Set: %s (Group: %s)" % [config.get("name"), group])

func _update_arena_bounds() -> void:
	"""Synchronize ArenaBoundsService with selected arena type mode."""
	var mode: int = active_modes.get("arena_type", GameEnums.GameMode.ARENA_RECTANGULAR)
	match mode:
		GameEnums.GameMode.ARENA_ISOMETRIC:
			ArenaBoundsService.set_arena_type(GameEnums.ArenaType.ISOMETRIC)
		_:
			ArenaBoundsService.set_arena_type(GameEnums.ArenaType.RECTANGULAR)

func is_mode_active(mode_id: GameEnums.GameMode) -> bool:
	for group in active_modes:
		if active_modes[group] == mode_id:
			return true
	return false

func get_arena_type_mode() -> GameEnums.GameMode:
	"""Returns the active arena type mode."""
	return active_modes.get("arena_type", GameEnums.GameMode.ARENA_RECTANGULAR)

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
	var mode: int = active_modes.get("spawn_location", GameEnums.GameMode.SENTINEL)
	
	match mode:
		GameEnums.GameMode.SENTINEL:
			# Original behavior: pick from edge zones (uses ArenaBoundsService for isometric)
			if ArenaBoundsService.is_isometric():
				return ArenaBoundsService.get_random_edge_spawn_position()
			# Rectangular: use legacy zones
			if spawn_zones.is_empty():
				return Vector2.ZERO
			var zone := spawn_zones[randi() % spawn_zones.size()]
			return Vector2(
				zone.position.x + randf() * zone.size.x,
				zone.position.y + randf() * zone.size.y
			)
			
		GameEnums.GameMode.INVASION:
			# Spawn anywhere in the arena
			return ArenaBoundsService.get_random_arena_position()
			
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

func is_escort_mode_active() -> bool:
	"""
	Returns true if ESCORT mode is active.
	"""
	return is_mode_active(GameEnums.GameMode.ESCORT)

func generate_escort_path() -> Array[Vector2]:
	"""
	Generates a random path for the escort mode.
	Two random points on opposite sides, with a somewhat random route.
	"""
	var points: Array[Vector2] = []
	
	# Determine sides (0: Top, 1: Bottom, 2: Left, 3: Right)
	var start_side = randi() % 4
	var end_side = (start_side + 1 + (randi() % 2)) % 4 # Ensure it's not the same side or adjacent?
	# Let's just say "opposite enough"
	if start_side == 0: end_side = 1 # Top -> Bottom
	elif start_side == 1: end_side = 0 # Bottom -> Top
	elif start_side == 2: end_side = 3 # Left -> Right
	elif start_side == 3: end_side = 2 # Right -> Left
	
	var start_pos = _get_random_point_on_side(start_side)
	var end_pos = _get_random_point_on_side(end_side)
	
	points.append(start_pos)
	
	# Add 1-2 middle points for "somewhat random route"
	var middle_points_count = randi_range(1, 2)
	for i in range(middle_points_count):
		# Interpolate and add noise
		var t = float(i + 1) / (middle_points_count + 1)
		var lerp_pos = start_pos.lerp(end_pos, t)
		var offset = Vector2(randf_range(-200, 200), randf_range(-200, 200))
		points.append(lerp_pos + offset)
		
	points.append(end_pos)
	return points

func _get_random_point_on_side(side: int) -> Vector2:
	var hw = GameConstants.ARENA_WIDTH / 2.5 # Inset a bit
	var hh = GameConstants.ARENA_HEIGHT / 2.5
	
	match side:
		0: # Top
			return Vector2(randf_range(-hw, hw), -hh)
		1: # Bottom
			return Vector2(randf_range(-hw, hw), hh)
		2: # Left
			return Vector2(-hw, randf_range(-hh, hh))
		3: # Right
			return Vector2(hw, randf_range(-hh, hh))
	return Vector2.ZERO

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
	var intervals_passed: int = int(floor(time_since_alert / 8.0))
	return 1.0 + (intervals_passed * 0.3)

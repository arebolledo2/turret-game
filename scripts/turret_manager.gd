extends Node

# Manages turret spawning with constraints

var turret_scene: PackedScene
var turrets: Array[Node2D] = []

func _ready() -> void:
	turret_scene = preload("res://scenes/turret.tscn")

func spawn_turret() -> void:
	if turret_scene == null:
		push_error("Turret scene not loaded!")
		return
	
	var player = get_tree().get_first_node_in_group("player")
	var spawn_pos := find_valid_spawn_position(player)
	
	if spawn_pos == Vector2.INF:
		push_warning("Could not find valid turret spawn position!")
		return
	
	# Create turret
	var turret := turret_scene.instantiate()
	turret.global_position = spawn_pos
	
	# Add to container or scene
	var turret_container = get_node_or_null("../TurretContainer")
	if turret_container:
		turret_container.add_child(turret)
	else:
		get_parent().add_child(turret)
	
	turrets.append(turret)
	Globals.turrets_spawned += 1
	
	# Track count by type (default to basic for MVP)
	var type = "basic"
	if not Globals.turret_counts.has(type):
		Globals.turret_counts[type] = 0
	Globals.turret_counts[type] += 1
	
	Events.turret_spawned.emit(turret, spawn_pos)

func find_valid_spawn_position(player: Node2D, max_attempts: int = 50) -> Vector2:
	var half_width := Globals.ARENA_WIDTH / 2.0
	var half_height := Globals.ARENA_HEIGHT / 2.0
	var margin := 50.0  # Keep away from edges
	
	for i in max_attempts:
		# Random position within arena
		var pos := Vector2(
			randf_range(-half_width + margin, half_width - margin),
			randf_range(-half_height + margin, half_height - margin)
		)
		
		if is_position_valid(pos, player):
			return pos
	
	return Vector2.INF  # Failed to find valid position

func is_position_valid(pos: Vector2, player: Node2D) -> bool:
	# Check distance from player
	if player and pos.distance_to(player.global_position) < Globals.TURRET_PLAYER_EXCLUSION:
		return false

	# Check distance from other turrets (modified by Personal Space item)
	var min_distance = Globals.get_turret_min_distance()
	for turret in turrets:
		if is_instance_valid(turret):
			if pos.distance_to(turret.global_position) < min_distance:
				return false

	return true

func get_turret_count() -> int:
	# Clean up invalid references and return count
	turrets = turrets.filter(func(t): return is_instance_valid(t))
	return turrets.size()

func reposition_all_turrets() -> void:
	"""Randomly reposition all existing turrets at the start of a new wave"""
	turrets = turrets.filter(func(t): return is_instance_valid(t))
	var player = get_tree().get_first_node_in_group("player")
	
	# Temporarily clear positions to avoid collision checking against old positions
	var new_positions: Array[Vector2] = []
	
	for turret in turrets:
		var new_pos := find_valid_spawn_position_excluding(player, new_positions)
		if new_pos != Vector2.INF:
			turret.global_position = new_pos
			new_positions.append(new_pos)

func find_valid_spawn_position_excluding(player: Node2D, existing_positions: Array[Vector2], max_attempts: int = 50) -> Vector2:
	"""Find a valid position that doesn't conflict with player or provided positions"""
	var half_width := Globals.ARENA_WIDTH / 2.0
	var half_height := Globals.ARENA_HEIGHT / 2.0
	var margin := 50.0
	
	for i in max_attempts:
		var pos := Vector2(
			randf_range(-half_width + margin, half_width - margin),
			randf_range(-half_height + margin, half_height - margin)
		)

		# Check distance from player
		if player and pos.distance_to(player.global_position) < Globals.TURRET_PLAYER_EXCLUSION:
			continue

		# Check distance from existing positions (modified by Personal Space item)
		var min_distance = Globals.get_turret_min_distance()
		var valid := true
		for existing_pos in existing_positions:
			if pos.distance_to(existing_pos) < min_distance:
				valid = false
				break

		if valid:
			return pos
	
	return Vector2.INF

func spawn_starting_turret() -> void:
	"""Spawn a free Normal turret at arena center at game start"""
	if turret_scene == null:
		push_error("Turret scene not loaded!")
		return
	
	# Spawn at arena center (0, 0)
	var spawn_pos := Vector2.ZERO
	
	var turret := turret_scene.instantiate()
	turret.global_position = spawn_pos
	turret.turret_type = "normal"
	
	var turret_container = get_node_or_null("../TurretContainer")
	if turret_container:
		turret_container.add_child(turret)
	else:
		get_parent().add_child(turret)
	
	turrets.append(turret)
	Globals.turrets_spawned += 1
	
	if not Globals.turret_counts.has("normal"):
		Globals.turret_counts["normal"] = 0
	Globals.turret_counts["normal"] += 1
	
	Events.turret_spawned.emit(turret, spawn_pos)

func spawn_pending_turrets() -> void:
	"""Spawn all turrets from pending purchases queue"""
	for turret_id in Globals.pending_turret_purchases:
		spawn_turret_type(turret_id)
	Globals.pending_turret_purchases.clear()

func spawn_turret_type(turret_id: String) -> void:
	if turret_scene == null:
		push_error("Turret scene not loaded!")
		return

	if not TurretRegistry.TYPES.has(turret_id):
		push_error("Invalid turret type: " + turret_id)
		return

	var player = get_tree().get_first_node_in_group("player")
	var spawn_pos: Vector2

	# First turret of the game spawns next to player
	if Globals.turrets_spawned == 0 and player:
		spawn_pos = player.global_position + Vector2(80, 0)  # 80 pixels to the right
	else:
		spawn_pos = find_valid_spawn_position(player)

	if spawn_pos == Vector2.INF:
		push_warning("Could not find valid turret spawn position!")
		return

	var turret := turret_scene.instantiate()
	turret.global_position = spawn_pos
	turret.turret_type = turret_id

	var turret_container = get_node_or_null("../TurretContainer")
	if turret_container:
		turret_container.add_child(turret)
	else:
		get_parent().add_child(turret)

	turrets.append(turret)
	Globals.turrets_spawned += 1

	if not Globals.turret_counts.has(turret_id):
		Globals.turret_counts[turret_id] = 0
	Globals.turret_counts[turret_id] += 1

	Events.turret_spawned.emit(turret, spawn_pos)

## Get all turrets within radius of a position (excluding self if position matches a turret)
func get_turrets_within_radius(position: Vector2, radius: float) -> Array[Node2D]:
	var nearby: Array[Node2D] = []
	for turret in turrets:
		if not is_instance_valid(turret):
			continue
		var distance := position.distance_to(turret.global_position)
		if distance <= radius and distance > 0.1:  # Exclude self (small epsilon for floating point)
			nearby.append(turret)
	return nearby

## Check if a turret is isolated (no other turrets within radius)
func is_turret_isolated(turret_position: Vector2, radius: float) -> bool:
	return get_turrets_within_radius(turret_position, radius).is_empty()

extends Node

# Manages turret spawning with constraints

var turret_scene: PackedScene
var turrets: Array[Node2D] = []

func _ready() -> void:
	turret_scene = preload("res://scenes/turret.tscn")
	Events.modifiers_changed.connect(_on_modifiers_changed)
	Events.turret_placed.connect(_on_turret_placed)
	Events.turret_picked_up.connect(_on_turret_picked_up)

func _on_modifiers_changed() -> void:
	"""Called when items are purchased and modifiers change"""
	update_all_turret_stats()

func _on_turret_placed(_turret: Node2D, _pos: Vector2) -> void:
	"""Called when a carried turret is placed"""
	update_all_turret_stats()

func _on_turret_picked_up(_turret: Node2D) -> void:
	"""Called when a turret is picked up"""
	update_all_turret_stats()

func update_all_turret_stats() -> void:
	"""Force all active turrets to recalculate their stats"""
	for turret in turrets:
		if is_instance_valid(turret) and turret.has_method("update_stats"):
			turret.update_stats()

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
	GameStateService.turrets_spawned += 1
	
	# Track count by type (default to basic for MVP)
	var type = "basic"
	if not TurretStatsService.turret_counts.has(type):
		TurretStatsService.turret_counts[type] = 0
	TurretStatsService.turret_counts[type] += 1
	
	Events.turret_spawned.emit(turret, spawn_pos)

func find_valid_spawn_position(player: Node2D, max_attempts: int = 50) -> Vector2:
	var margin := 50.0 # Keep away from edges

	for i in max_attempts:
		# Random position within arena (handles both rectangular and isometric modes)
		var pos := ArenaBoundsService.get_random_arena_position(margin)

		if is_position_valid(pos, player):
			return pos

	return Vector2.INF # Failed to find valid position

func is_position_valid(pos: Vector2, player: Node2D) -> bool:
	# Check distance from player
	if player and pos.distance_to(player.global_position) < GameConstants.TURRET_PLAYER_EXCLUSION:
		return false

	# Check distance from other turrets (modified by Personal Space item)
	var min_distance = TurretStatsService.get_turret_min_distance(ItemTrackingService.item_counts)
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

	# Update stats for all turrets to refresh proximity-based bonuses
	for turret in turrets:
		if turret.has_method("update_stats"):
			turret.update_stats()

func find_valid_spawn_position_excluding(player: Node2D, existing_positions: Array[Vector2], max_attempts: int = 50) -> Vector2:
	"""Find a valid position that doesn't conflict with player or provided positions"""
	var margin := 50.0

	for i in max_attempts:
		# Random position within arena (handles both rectangular and isometric modes)
		var pos := ArenaBoundsService.get_random_arena_position(margin)

		# Check distance from player
		if player and pos.distance_to(player.global_position) < GameConstants.TURRET_PLAYER_EXCLUSION:
			continue

		# Check distance from existing positions (modified by Personal Space item)
		var min_distance = TurretStatsService.get_turret_min_distance(ItemTrackingService.item_counts)
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
	
	# Prevent double spawning
	if not turrets.is_empty():
		for t in turrets:
			if is_instance_valid(t):
				t.queue_free()
		turrets.clear()
		TurretStatsService.turret_counts.clear()
		GameStateService.turrets_spawned = 0
	
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
	GameStateService.turrets_spawned += 1
	
	if not TurretStatsService.turret_counts.has("normal"):
		TurretStatsService.turret_counts["normal"] = 0
	TurretStatsService.turret_counts["normal"] += 1
	
	Events.turret_spawned.emit(turret, spawn_pos)

func spawn_pending_turrets() -> void:
	"""Spawn all turrets from pending purchases queue"""
	for turret_id in EconomyService.pending_turret_purchases:
		spawn_turret_type(turret_id)
	EconomyService.pending_turret_purchases.clear()

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
	if GameStateService.turrets_spawned == 0 and player:
		spawn_pos = player.global_position + Vector2(80, 0) # 80 pixels to the right
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
	GameStateService.turrets_spawned += 1

	if not TurretStatsService.turret_counts.has(turret_id):
		TurretStatsService.turret_counts[turret_id] = 0
	TurretStatsService.turret_counts[turret_id] += 1

	Events.turret_spawned.emit(turret, spawn_pos)

	# Update stats for all existing turrets to refresh proximity-based bonuses
	for existing_turret in turrets:
		if existing_turret != turret and is_instance_valid(existing_turret) and existing_turret.has_method("update_stats"):
			existing_turret.update_stats()

## Get all turrets within radius of a position (excluding self if position matches a turret)
func get_turrets_within_radius(position: Vector2, radius: float) -> Array[Node2D]:
	var nearby: Array[Node2D] = []
	for turret in turrets:
		if not is_instance_valid(turret):
			continue
		var distance := position.distance_to(turret.global_position)
		if distance <= radius and distance > 0.1: # Exclude self (small epsilon for floating point)
			nearby.append(turret)
	return nearby

## Check if a turret is isolated (no other turrets within radius)
func is_turret_isolated(turret_position: Vector2, radius: float) -> bool:
	return get_turrets_within_radius(turret_position, radius).is_empty()

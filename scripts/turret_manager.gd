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
	
	# Check distance from other turrets
	for turret in turrets:
		if is_instance_valid(turret):
			if pos.distance_to(turret.global_position) < Globals.TURRET_MIN_DISTANCE:
				return false
	
	return true

func get_turret_count() -> int:
	# Clean up invalid references and return count
	turrets = turrets.filter(func(t): return is_instance_valid(t))
	return turrets.size()

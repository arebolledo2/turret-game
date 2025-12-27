extends Node

## Game Mode Entity Spawner
## Handles spawning of game-mode-specific entities like defense targets and tunnel doors

var defense_target_scene = preload("res://scenes/defense_target.tscn")
var tunnel_door_scene = preload("res://scenes/tunnel_door.tscn")

var current_defense_target: Node2D = null
var current_tunnel_door: Node2D = null


# =============================================================================
# ENTITY SPAWNING
# =============================================================================

func spawn_game_mode_entities() -> void:
	"""Spawn entities based on the active win_condition game mode."""
	var difficulty_config = DifficultyService.get_difficulty_config()
	var current_wave = GameStateService.current_wave

	# Tech Defense Mode - spawn defense target
	if GameModeService.should_spawn_defense_target():
		_spawn_defense_target(current_wave, difficulty_config)

	# Tunneling Modes - spawn door
	if GameModeService.should_spawn_tunnel_door():
		_spawn_tunnel_door(current_wave, difficulty_config)


func _spawn_defense_target(wave: int, difficulty_config: Dictionary) -> void:
	current_defense_target = defense_target_scene.instantiate()
	# Use current_scene if available, otherwise add to self (for tests)
	var parent = get_tree().current_scene if get_tree().current_scene else get_parent()
	if parent:
		parent.add_child(current_defense_target)
	else:
		push_warning("No valid parent for defense target spawn")
		current_defense_target.queue_free()
		current_defense_target = null
		return
	current_defense_target.global_position = Vector2.ZERO # Center of arena
	current_defense_target.initialize(wave, difficulty_config)
	Events.defense_target_spawned.emit(current_defense_target, Vector2.ZERO)


func _spawn_tunnel_door(wave: int, difficulty_config: Dictionary) -> void:
	current_tunnel_door = tunnel_door_scene.instantiate()
	# Use current_scene if available, otherwise add to parent (for tests)
	var parent = get_tree().current_scene if get_tree().current_scene else get_parent()
	if parent:
		parent.add_child(current_tunnel_door)
	else:
		push_warning("No valid parent for tunnel door spawn")
		current_tunnel_door.queue_free()
		current_tunnel_door = null
		return
	# Position door at right edge of arena
	var door_x = GameConstants.ARENA_WIDTH / 2.0 - 100
	current_tunnel_door.global_position = Vector2(door_x, 0)
	current_tunnel_door.initialize(wave, difficulty_config)


# =============================================================================
# ENTITY CLEANUP
# =============================================================================

func cleanup_entities() -> void:
	"""Remove any spawned game mode entities."""
	if is_instance_valid(current_defense_target):
		current_defense_target.queue_free()
		current_defense_target = null

	if is_instance_valid(current_tunnel_door):
		current_tunnel_door.queue_free()
		current_tunnel_door = null


# =============================================================================
# ENTITY QUERIES
# =============================================================================

func has_defense_target() -> bool:
	return is_instance_valid(current_defense_target)


func has_tunnel_door() -> bool:
	return is_instance_valid(current_tunnel_door)


func get_defense_target() -> Node2D:
	return current_defense_target


func get_tunnel_door() -> Node2D:
	return current_tunnel_door

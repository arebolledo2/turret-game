extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_alert_scene: PackedScene

const SPAWN_ALERT_TIME: float = 1.5

# Spawn zones (4 fixed zones, one per edge)
var spawn_zones: Array[Rect2] = []
var spawn_timer: Timer
var current_wave: int = 0
var is_spawning: bool = false

# Enemy type spawning stats
var enemies_spawned_by_type: Dictionary = {} # Track spawns per type

# Queued spawns (waiting for alert to finish)
var queued_spawns: Array[Dictionary] = [] # {enemy_type: String, spawn_pos: Vector2, time_remaining: float}

func _ready() -> void:
	# Setup spawn zones on arena edges
	setup_spawn_zones()

	# Create spawn timer
	spawn_timer = Timer.new()
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

func setup_spawn_zones() -> void:
	var half_width := GameConstants.ARENA_WIDTH / 2.0
	var half_height := GameConstants.ARENA_HEIGHT / 2.0
	var zone_depth := 200.0 # How far from edge enemies can spawn (allows spawning closer to middle)
	var inset := 20.0 # Small inset from the very edge

	# Top edge (full width, spawn inside arena near top)
	spawn_zones.append(Rect2(
		- half_width + inset, -half_height + inset,
		GameConstants.ARENA_WIDTH - (inset * 2), zone_depth
	))

	# Bottom edge (full width, spawn inside arena near bottom)
	spawn_zones.append(Rect2(
		- half_width + inset, half_height - inset - zone_depth,
		GameConstants.ARENA_WIDTH - (inset * 2), zone_depth
	))

	# Left edge (full height, spawn inside arena near left)
	spawn_zones.append(Rect2(
		- half_width + inset, -half_height + inset,
		zone_depth, GameConstants.ARENA_HEIGHT - (inset * 2)
	))

	# Right edge (full height, spawn inside arena near right)
	spawn_zones.append(Rect2(
		half_width - inset - zone_depth, -half_height + inset,
		zone_depth, GameConstants.ARENA_HEIGHT - (inset * 2)
	))

func start_spawning(wave: int) -> void:
	current_wave = wave
	enemies_spawned_by_type.clear()
	is_spawning = true

	# Set constant spawn interval for the wave
	_update_spawn_interval()
	spawn_timer.start()

	# Spawn first enemy immediately
	_spawn_random_enemy()

func stop_spawning() -> void:
	is_spawning = false
	spawn_timer.stop()
	queued_spawns.clear()

func _update_spawn_interval() -> void:
	"""Set a constant spawn interval for the current wave with some randomness."""
	# Calculate base interval based on wave (faster each wave)
	# Wave 1: ~2.5s, Wave 10: ~1.0s (adjust as needed for balance)
	var base_interval := lerpf(2.5, 0.8, clampf((current_wave - 1) / 9.0, 0.0, 1.0))
	
	# Add randomness (e.g. +/- 20%)
	var random_factor := randf_range(0.8, 1.2)
	spawn_timer.wait_time = base_interval * random_factor

func _process(delta: float) -> void:
	# Process queued spawns
	var i := 0
	while i < queued_spawns.size():
		queued_spawns[i].time_remaining -= delta

		if queued_spawns[i].time_remaining <= 0:
			# Time to spawn the enemy
			_spawn_enemy_immediate(queued_spawns[i].enemy_type, queued_spawns[i].spawn_pos)
			queued_spawns.remove_at(i)
		else:
			i += 1

func _on_spawn_timer_timeout() -> void:
	if not is_spawning:
		return

	_spawn_random_enemy()
	
	# Re-randomize next spawn interval to keep it feeling natural
	_update_spawn_interval()

func _spawn_random_enemy() -> void:
	"""Select a random enemy type and spawn it (possibly multiple for swarm types)."""
	# Select random enemy type based on wave and weights
	var enemy_type := EnemyRegistry.select_random_type(current_wave)
	var spawn_count := EnemyRegistry.get_spawn_count(enemy_type)

	# Get a base position for the swarm cluster
	var base_pos := _get_random_spawn_position()

	# Spawn the enemy (or multiple for swarm types)
	for i in range(spawn_count):
		_queue_spawn_with_alert_at_position(enemy_type, base_pos, i)

		# Track spawn counts
		enemies_spawned_by_type[enemy_type] = enemies_spawned_by_type.get(enemy_type, 0) + 1

func _get_random_spawn_position() -> Vector2:
	"""Get a random spawn position from the game mode service."""
	return GameModeService.get_random_spawn_position(spawn_zones)

func _queue_spawn_with_alert(enemy_type: String) -> void:
	"""Queue an enemy spawn with a visual alert indicator at a random position."""
	var spawn_pos := _get_random_spawn_position()
	_queue_spawn_with_alert_at_position(enemy_type, spawn_pos, 0)

func _queue_spawn_with_alert_at_position(enemy_type: String, base_pos: Vector2, swarm_index: int) -> void:
	"""Queue an enemy spawn with a visual alert indicator near a base position."""
	# For swarm spawns, offset slightly from base position to create a cluster
	const SWARM_SPREAD := 60.0 # How far apart swarm members spawn
	var spawn_pos := base_pos
	if swarm_index > 0:
		# Offset subsequent enemies in a circular pattern around the base
		var angle := (swarm_index * TAU / 5.0) + randf() * 0.5 # Slight randomness
		var distance := SWARM_SPREAD * (0.7 + randf() * 0.6) # 42-78 pixels from center
		spawn_pos = base_pos + Vector2(cos(angle), sin(angle)) * distance

	# Create spawn alert indicator
	if spawn_alert_scene:
		var alert := spawn_alert_scene.instantiate()
		alert.global_position = spawn_pos
		get_parent().add_child(alert)

	# Queue the spawn
	queued_spawns.append({
		"enemy_type": enemy_type,
		"spawn_pos": spawn_pos,
		"time_remaining": SPAWN_ALERT_TIME
	})

func _spawn_enemy_immediate(enemy_type: String, spawn_pos: Vector2) -> void:
	"""Immediately spawn an enemy at the given position (called after alert finishes)."""
	# Check if enemy type has custom scene path
	var type_def := EnemyRegistry.get_type(enemy_type)
	var scene_to_use: PackedScene

	if type_def.has("scene_path"):
		scene_to_use = load(type_def["scene_path"])
	else:
		scene_to_use = enemy_scene

	if scene_to_use == null:
		DebugService.error(DebugService.VALIDATION, "Enemy scene not set in EnemySpawner!")
		return

	# Create enemy
	var enemy := scene_to_use.instantiate()
	enemy.global_position = spawn_pos

	# Initialize with type and wave-scaled stats
	if enemy.has_method("initialize"):
		enemy.initialize(current_wave, enemy_type)

	# Add to scene
	var enemy_container = get_node_or_null("../EnemyContainer")
	if enemy_container:
		enemy_container.add_child(enemy)
	else:
		get_parent().add_child(enemy)

	Events.enemy_spawned.emit(enemy)

func spawn_enemy(enemy_type: String = "basic") -> void:
	"""Public method to spawn enemy without alert (for testing/manual spawns)."""
	_queue_spawn_with_alert(enemy_type)

extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_alert_scene: PackedScene

const SPAWN_ALERT_TIME: float = 1.5

# Spawn zones (4 fixed zones, one per edge)
var spawn_zones: Array[Rect2] = []
var spawn_timer: Timer
var enemies_to_spawn: int = 0
var enemies_spawned: int = 0
var current_wave: int = 0
var is_spawning: bool = false
var wave_duration: float = 0.0

# Enemy type spawning stats
var enemies_spawned_by_type: Dictionary = {}  # Track spawns per type

# Queued spawns (waiting for alert to finish)
var queued_spawns: Array[Dictionary] = []  # {enemy_type: String, spawn_pos: Vector2, time_remaining: float}

func _ready() -> void:
	# Setup spawn zones on arena edges
	setup_spawn_zones()

	# Create spawn timer
	spawn_timer = Timer.new()
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

func setup_spawn_zones() -> void:
	var half_width := Globals.ARENA_WIDTH / 2.0
	var half_height := Globals.ARENA_HEIGHT / 2.0
	var zone_depth := 80.0  # How far from edge enemies can spawn
	var inset := 20.0  # Small inset from the very edge

	# Top edge (full width, spawn inside arena near top)
	spawn_zones.append(Rect2(
		-half_width + inset, -half_height + inset,
		Globals.ARENA_WIDTH - (inset * 2), zone_depth
	))

	# Bottom edge (full width, spawn inside arena near bottom)
	spawn_zones.append(Rect2(
		-half_width + inset, half_height - inset - zone_depth,
		Globals.ARENA_WIDTH - (inset * 2), zone_depth
	))

	# Left edge (full height, spawn inside arena near left)
	spawn_zones.append(Rect2(
		-half_width + inset, -half_height + inset,
		zone_depth, Globals.ARENA_HEIGHT - (inset * 2)
	))

	# Right edge (full height, spawn inside arena near right)
	spawn_zones.append(Rect2(
		half_width - inset - zone_depth, -half_height + inset,
		zone_depth, Globals.ARENA_HEIGHT - (inset * 2)
	))

func start_spawning(wave: int) -> void:
	current_wave = wave
	enemies_to_spawn = Globals.get_wave_enemy_count(wave)
	enemies_spawned = 0
	wave_duration = Globals.get_wave_duration(wave)
	enemies_spawned_by_type.clear()
	is_spawning = true

	# Start with initial spawn interval (will dynamically adjust)
	_update_spawn_interval()
	spawn_timer.start()

	# Spawn first enemy immediately
	_spawn_random_enemy()

func stop_spawning() -> void:
	is_spawning = false
	spawn_timer.stop()
	enemies_to_spawn = 0
	queued_spawns.clear()

func update_spawn_rate(wave_time_remaining: float) -> void:
	"""Called by game manager to update spawn rate based on wave progress."""
	if not is_spawning or wave_duration <= 0:
		return

	# Calculate progress: starts at 0 (beginning) and goes to 1 (end)
	var wave_elapsed := wave_duration - wave_time_remaining
	var progress := clampf(wave_elapsed / wave_duration, 0.0, 1.0)

	# Ramping spawn rate: starts slow, ends fast
	# At progress 0: spawn slower (3.0s interval)
	# At progress 1: spawn faster (0.15s interval)
	# Linear interpolation from slow to fast
	var spawn_interval: float = lerpf(3.0, 0.15, progress)

	# Update the spawn timer
	spawn_timer.wait_time = spawn_interval

func _update_spawn_interval() -> void:
	"""Initialize spawn interval at wave start."""
	spawn_timer.wait_time = 3.0  # Start slow

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

func _spawn_random_enemy() -> void:
	"""Select a random enemy type and spawn it (possibly multiple for swarm types)."""
	# Select random enemy type based on wave and weights
	var enemy_type := Globals.select_random_enemy_type(current_wave)
	var spawn_count := Globals.get_enemy_spawn_count(enemy_type)

	# Spawn the enemy (or multiple for swarm types)
	for i in range(spawn_count):
		_queue_spawn_with_alert(enemy_type)
		enemies_spawned += 1

		# Track spawn counts
		enemies_spawned_by_type[enemy_type] = enemies_spawned_by_type.get(enemy_type, 0) + 1

func _queue_spawn_with_alert(enemy_type: String) -> void:
	"""Queue an enemy spawn with a visual alert indicator."""
	# Pick a random spawn zone
	var zone := spawn_zones[randi() % spawn_zones.size()]

	# Random position within the zone
	var spawn_pos := Vector2(
		zone.position.x + randf() * zone.size.x,
		zone.position.y + randf() * zone.size.y
	)

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
	if enemy_scene == null:
		push_error("Enemy scene not set in EnemySpawner!")
		return

	# Create enemy
	var enemy := enemy_scene.instantiate()
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

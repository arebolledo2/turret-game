extends Node2D

@export var enemy_scene: PackedScene

# Spawn zones (4 fixed zones, one per edge)
var spawn_zones: Array[Rect2] = []
var spawn_timer: Timer
var enemies_to_spawn: int = 0
var enemies_spawned: int = 0
var current_wave: int = 0
var is_spawning: bool = false
var wave_duration: float = 0.0
var wave_elapsed: float = 0.0

# Enemy type spawning stats
var enemies_spawned_by_type: Dictionary = {}  # Track spawns per type

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
	wave_elapsed = 0.0
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
	wave_elapsed = 0.0

func _process(delta: float) -> void:
	if is_spawning:
		wave_elapsed += delta
		# Dynamically update spawn interval as wave progresses
		_update_spawn_interval()

func _update_spawn_interval() -> void:
	if wave_duration <= 0:
		return

	var remaining_enemies: int = enemies_to_spawn - enemies_spawned
	if remaining_enemies <= 0:
		return

	# Progress from 0 to 1 throughout the wave
	var progress := clampf(wave_elapsed / wave_duration, 0.0, 1.0)

	# Ramping spawn rate: starts slow, ends fast
	# At progress 0: spawn at 0.5x the "even" rate (slower start)
	# At progress 1: spawn at 2.0x the "even" rate (fast finish)
	var rate_multiplier := 0.5 + (progress * 1.5)

	# Calculate the "even" interval to spawn all enemies over the full wave duration
	# This gives us a baseline - if we spawned evenly, each enemy gets this much time
	var even_interval: float = wave_duration / float(enemies_to_spawn)

	# Apply the ramping multiplier
	var adjusted_interval := even_interval / rate_multiplier

	# Safety: as we approach the end, spawn faster to ensure completion
	var remaining_time: float = wave_duration - wave_elapsed
	if remaining_time > 0 and remaining_enemies > 0:
		# Calculate the max interval we can use to finish on time (with 10% buffer)
		var max_safe_interval := (remaining_time * 0.9) / float(remaining_enemies)
		adjusted_interval = minf(adjusted_interval, max_safe_interval)

	# Clamp to reasonable values (min 0.15s, max 3.0s)
	spawn_timer.wait_time = clampf(adjusted_interval, 0.15, 3.0)

func _on_spawn_timer_timeout() -> void:
	if not is_spawning or enemies_to_spawn <= 0 or enemies_spawned >= enemies_to_spawn:
		return

	_spawn_random_enemy()

func _spawn_random_enemy() -> void:
	"""Select a random enemy type and spawn it (possibly multiple for swarm types)."""
	if enemies_spawned >= enemies_to_spawn:
		return

	# Select random enemy type based on wave and weights
	var enemy_type := Globals.select_random_enemy_type(current_wave)
	var spawn_count := Globals.get_enemy_spawn_count(enemy_type)

	# Spawn the enemy (or multiple for swarm types)
	for i in range(spawn_count):
		if enemies_spawned >= enemies_to_spawn:
			break
		spawn_enemy(enemy_type)
		enemies_spawned += 1

		# Track spawn counts
		enemies_spawned_by_type[enemy_type] = enemies_spawned_by_type.get(enemy_type, 0) + 1

func spawn_enemy(enemy_type: String = "basic") -> void:
	if enemy_scene == null:
		push_error("Enemy scene not set in EnemySpawner!")
		return
	
	# Pick a random spawn zone
	var zone := spawn_zones[randi() % spawn_zones.size()]
	
	# Random position within the zone
	var spawn_pos := Vector2(
		zone.position.x + randf() * zone.size.x,
		zone.position.y + randf() * zone.size.y
	)
	
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

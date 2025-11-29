extends Node2D

@export var enemy_scene: PackedScene

# Spawn zones (4 fixed zones, one per edge)
var spawn_zones: Array[Rect2] = []
var spawn_timer: Timer
var enemies_to_spawn: int = 0
var current_wave: int = 0
var is_spawning: bool = false

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
	var zone_width := 200.0
	var zone_depth := 50.0
	var offset := 30.0  # Spawn slightly outside arena
	
	# Top edge (centered)
	spawn_zones.append(Rect2(
		-zone_width / 2, -half_height - offset - zone_depth,
		zone_width, zone_depth
	))
	
	# Bottom edge (centered)
	spawn_zones.append(Rect2(
		-zone_width / 2, half_height + offset,
		zone_width, zone_depth
	))
	
	# Left edge (centered)
	spawn_zones.append(Rect2(
		-half_width - offset - zone_depth, -zone_width / 2,
		zone_depth, zone_width
	))
	
	# Right edge (centered)
	spawn_zones.append(Rect2(
		half_width + offset, -zone_width / 2,
		zone_depth, zone_width
	))

func start_spawning(wave: int) -> void:
	current_wave = wave
	enemies_to_spawn = Globals.get_wave_enemy_count(wave)
	enemies_spawned_by_type.clear()
	is_spawning = true
	
	# Calculate spawn interval
	var spawn_interval := Globals.get_spawn_interval(wave)
	spawn_timer.wait_time = spawn_interval
	spawn_timer.start()
	
	# Spawn first enemy immediately
	_spawn_random_enemy()

func stop_spawning() -> void:
	is_spawning = false
	spawn_timer.stop()
	enemies_to_spawn = 0

func _on_spawn_timer_timeout() -> void:
	if not is_spawning or enemies_to_spawn <= 0:
		spawn_timer.stop()
		return
	
	_spawn_random_enemy()

func _spawn_random_enemy() -> void:
	"""Select a random enemy type and spawn it (possibly multiple for swarm types)."""
	if enemies_to_spawn <= 0:
		return
	
	# Select random enemy type based on wave and weights
	var enemy_type := Globals.select_random_enemy_type(current_wave)
	var spawn_count := Globals.get_enemy_spawn_count(enemy_type)
	
	# Spawn the enemy (or multiple for swarm types)
	for i in range(spawn_count):
		if enemies_to_spawn <= 0:
			break
		spawn_enemy(enemy_type)
		enemies_to_spawn -= 1
		
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

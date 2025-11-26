extends Node2D

@export var enemy_scene: PackedScene

# Spawn zones (4 fixed zones, one per edge)
var spawn_zones: Array[Rect2] = []
var spawn_timer: Timer
var enemies_to_spawn: int = 0
var current_wave: int = 0
var is_spawning: bool = false

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
	is_spawning = true
	
	# Calculate spawn interval
	var spawn_interval := Globals.get_spawn_interval(wave)
	spawn_timer.wait_time = spawn_interval
	spawn_timer.start()
	
	# Spawn first enemy immediately
	spawn_enemy()
	enemies_to_spawn -= 1

func stop_spawning() -> void:
	is_spawning = false
	spawn_timer.stop()
	enemies_to_spawn = 0

func _on_spawn_timer_timeout() -> void:
	if not is_spawning or enemies_to_spawn <= 0:
		spawn_timer.stop()
		return
	
	spawn_enemy()
	enemies_to_spawn -= 1

func spawn_enemy() -> void:
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
	
	# Initialize with wave-scaled stats
	if enemy.has_method("initialize"):
		enemy.initialize(current_wave)
	
	# Add to scene
	var enemy_container = get_node_or_null("../EnemyContainer")
	if enemy_container:
		enemy_container.add_child(enemy)
	else:
		get_parent().add_child(enemy)
	
	Events.enemy_spawned.emit(enemy)


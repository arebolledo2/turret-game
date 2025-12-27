extends Node2D

var spawn_timer: Timer
var active_tech_drops: Array[Node2D] = [] # Track for cleanup only
var is_active: bool = false
var tech_drop_scene: PackedScene
var current_wave: int = 1

# Queue for spawns with alerts
var queued_spawns: Array[Dictionary] = []
const SPAWN_ALERT_TIME: float = 1.5

func _ready() -> void:
	# Load tech drop scene
	tech_drop_scene = preload("res://scenes/tech_drop.tscn")

	# Setup spawn timer
	spawn_timer = Timer.new()
	spawn_timer.one_shot = false
	spawn_timer.wait_time = GameConstants.TECH_DROP_SPAWN_INTERVAL
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)

func _process(delta: float) -> void:
	# Process queued spawns (after alert period)
	for i in range(queued_spawns.size() - 1, -1, -1):
		var spawn = queued_spawns[i]
		spawn.time_remaining -= delta

		if spawn.time_remaining <= 0:
			_spawn_tech_drop_immediate(spawn.spawn_pos)
			queued_spawns.remove_at(i)

func start_spawning(wave: int) -> void:
	"""Start spawning tech drops for the given wave."""
	current_wave = wave
	is_active = true
	spawn_timer.start()

func stop_spawning() -> void:
	"""Stop spawning tech drops."""
	is_active = false
	spawn_timer.stop()

func clear_all_drops() -> void:
	"""Despawn all active tech drops (wave cleanup)."""
	var tech_drops = get_tree().get_nodes_in_group("tech_drops")
	for drop in tech_drops:
		if is_instance_valid(drop) and drop.has_method("despawn"):
			drop.despawn()

	active_tech_drops.clear()
	queued_spawns.clear()

func _on_spawn_timer_timeout() -> void:
	"""Check if we should spawn a tech drop."""
	if not is_active:
		return

	# Clean up invalid references
	active_tech_drops = active_tech_drops.filter(func(d): return is_instance_valid(d))

	# 20% chance to spawn (no max limit)
	if randf() < GameConstants.TECH_DROP_SPAWN_CHANCE:
		attempt_spawn()

func attempt_spawn() -> void:
	"""Attempt to spawn a tech drop at a valid position."""
	var spawn_pos = find_valid_spawn_position()

	if spawn_pos == Vector2.INF:
		return # Failed to find valid position

	# Queue spawn with alert
	_queue_spawn_with_alert(spawn_pos)

func find_valid_spawn_position() -> Vector2:
	"""Find a valid spawn position in the arena (supports isometric bounds)."""
	var margin = 100.0 # Keep away from edges
	
	for i in 30: # Max 30 attempts
		# Use ArenaBoundsService for isometric-aware position
		var pos := ArenaBoundsService.get_random_arena_position(margin)
		
		# Check distance from other tech drops (min 150 units apart)
		var valid = true
		for drop in active_tech_drops:
			if is_instance_valid(drop) and pos.distance_to(drop.global_position) < 150.0:
				valid = false
				break
		
		if valid:
			return pos
	
	return Vector2.INF # Failed to find valid position

func _queue_spawn_with_alert(spawn_pos: Vector2) -> void:
	"""Queue a spawn with a visual alert."""
	# Create alert
	var alert = create_tech_drop_alert(spawn_pos)
	get_parent().add_child(alert)

	# Queue the spawn
	queued_spawns.append({
		"spawn_pos": spawn_pos,
		"time_remaining": SPAWN_ALERT_TIME
	})

func create_tech_drop_alert(pos: Vector2) -> Node2D:
	"""Create a cyan-colored spawn alert circle."""
	var alert = Node2D.new()
	alert.global_position = pos

	# Outer circle (cyan)
	var outer = Polygon2D.new()
	outer.color = Color(0.3, 0.8, 1.0, 0.5) # Cyan with transparency
	var outer_points = PackedVector2Array()
	for i in range(32):
		var angle = i * TAU / 32.0
		outer_points.append(Vector2(cos(angle), sin(angle)) * 40.0)
	outer.polygon = outer_points
	alert.add_child(outer)

	# Inner circle (brighter cyan)
	var inner = Polygon2D.new()
	inner.color = Color(0.5, 0.9, 1.0, 0.7)
	var inner_points = PackedVector2Array()
	for i in range(32):
		var angle = i * TAU / 32.0
		inner_points.append(Vector2(cos(angle), sin(angle)) * 25.0)
	inner.polygon = inner_points
	alert.add_child(inner)

	# Pulsing animation
	var tween = alert.create_tween()
	tween.set_loops()
	tween.tween_property(outer, "scale", Vector2.ONE * 1.2, 0.5)
	tween.tween_property(outer, "scale", Vector2.ONE, 0.5)

	# Fade out and destroy after alert time
	var fade_tween = alert.create_tween()
	fade_tween.tween_interval(SPAWN_ALERT_TIME)
	fade_tween.tween_property(alert, "modulate:a", 0.0, 0.2)
	fade_tween.tween_callback(alert.queue_free)

	return alert

func _spawn_tech_drop_immediate(spawn_pos: Vector2) -> void:
	"""Spawn a tech drop immediately at the given position."""
	if not tech_drop_scene:
		return

	var tech_drop = tech_drop_scene.instantiate()

	# Find tech drop container
	var container = get_node_or_null("../TechDropContainer")
	if not container:
		container = get_parent()

	container.add_child(tech_drop)
	tech_drop.global_position = spawn_pos

	# Initialize with current wave
	if tech_drop.has_method("initialize"):
		tech_drop.initialize(current_wave)

	# Track it
	active_tech_drops.append(tech_drop)

	# Emit signal
	Events.tech_drop_spawned.emit(tech_drop, spawn_pos)

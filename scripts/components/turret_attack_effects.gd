class_name TurretAttackEffects
extends RefCounted

## Presentation only. Inject another instance to record or omit effects in tests.
var turret: Node2D
var turret_type: String
var stats: Dictionary

func draw_tracer(end_pos: Vector2) -> void:
	"""Draw instant hitscan tracer line."""
	var line = Line2D.new()
	line.width = 2.0
	line.default_color = TurretRegistry.get_color(turret_type)
	line.add_point(Vector2.ZERO) # Local space
	line.add_point(turret.to_local(end_pos))
	turret.add_child(line)

	var tween = turret.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.2)
	tween.tween_callback(line.queue_free)

func draw_lightning_arc(start_pos: Vector2, end_pos: Vector2) -> void:
	"""Draw chain lightning arc effect with jagged segments and glow."""
	var main_line = Line2D.new()
	var glow_line = Line2D.new()
	
	main_line.width = 2.5
	main_line.default_color = Color(0.8, 0.9, 1.0, 1.0) # Bright core
	
	glow_line.width = 6.0
	glow_line.default_color = Color(0.2, 0.5, 1.0, 0.4) # Blue glow
	
	var segments = 6
	var points = PackedVector2Array()
	points.append(start_pos)
	
	var direction = (end_pos - start_pos).normalized()
	var distance = start_pos.distance_to(end_pos)
	var segment_length = distance / segments
	
	for i in range(1, segments):
		var base_pos = start_pos + direction * (i * segment_length)
		# Add perpendicular offset for jaggedness
		var perp = Vector2(-direction.y, direction.x)
		var offset = perp * GameRandom.cosmetic.randf_range(-15.0, 15.0)
		points.append(base_pos + offset)
	
	points.append(end_pos)
	
	main_line.points = points
	glow_line.points = points
	
	var parent = turret.get_tree().current_scene if turret.get_tree().current_scene else turret.get_tree().root
	parent.add_child(glow_line)
	parent.add_child(main_line)
	
	# Branching arcs (30% chance per segment)
	for i in range(1, points.size() - 1):
		if GameRandom.cosmetic.randf() < 0.3:
			draw_lightning_branch(points[i], direction)
	
	var tween = turret.create_tween()
	tween.set_parallel(true)
	tween.tween_property(main_line, "width", 0.0, 0.25)
	tween.tween_property(glow_line, "width", 0.0, 0.35)
	tween.tween_property(main_line, "modulate:a", 0.0, 0.25)
	tween.tween_property(glow_line, "modulate:a", 0.0, 0.35)
	tween.set_parallel(false)
	tween.tween_callback(main_line.queue_free)
	tween.tween_callback(glow_line.queue_free)

func draw_lightning_branch(start_pos: Vector2, direction: Vector2) -> void:
	"""Draw a small branching arc from a lightning point."""
	var branch = Line2D.new()
	branch.width = 1.5
	branch.default_color = Color(0.4, 0.7, 1.0, 0.6)
	
	var points = PackedVector2Array()
	points.append(start_pos)
	
	var branch_dir = direction.rotated(GameRandom.cosmetic.randf_range(-PI / 3, PI / 3))
	var branch_len = GameRandom.cosmetic.randf_range(20.0, 40.0)
	
	points.append(start_pos + branch_dir * branch_len * 0.5 + Vector2(GameRandom.cosmetic.randf_range(-5, 5), GameRandom.cosmetic.randf_range(-5, 5)))
	points.append(start_pos + branch_dir * branch_len)
	
	branch.points = points
	var parent = turret.get_tree().current_scene if turret.get_tree().current_scene else turret.get_tree().root
	parent.add_child(branch)
	
	var tween = turret.create_tween()
	tween.tween_property(branch, "width", 0.0, 0.2)
	tween.tween_callback(branch.queue_free)

func spawn_pulse_effect() -> void:
	"""Spawn AOE pulse visual effect."""
	var current_range: float = stats.get("range", 250.0)
	var viz = Polygon2D.new()

	# Create circle polygon
	var points = PackedVector2Array()
	for i in range(32):
		var angle = i * TAU / 32.0
		points.append(Vector2(cos(angle), sin(angle)) * current_range)
	viz.polygon = points
	viz.color = TurretRegistry.get_color(turret_type)
	viz.color.a = 0.3

	turret.add_child(viz)
	viz.scale = Vector2.ZERO

	var tween = turret.create_tween()
	tween.tween_property(viz, "scale", Vector2.ONE, 0.2)
	tween.parallel().tween_property(viz, "modulate:a", 0.0, 0.2)
	tween.tween_callback(viz.queue_free)


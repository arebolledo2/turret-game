extends Area2D

# Debug visualization constants (white for physics)
const DEBUG_COLOR: Color = Color(1.0, 1.0, 1.0, 0.4)
const DEBUG_OUTLINE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.8)
const DEBUG_OUTLINE_WIDTH: float = 2.0

func _ready() -> void:
	# Connect to debug toggle event
	Events.hitbox_debug_toggled.connect(_on_debug_toggled)

	# If debug is already enabled, trigger initial draw
	if SettingsService.debug_hitbox_flags[GameEnums.HitboxType.PHYSICS]:
		queue_redraw()

func _on_debug_toggled(type: int, _enabled: bool) -> void:
	if type == GameEnums.HitboxType.PHYSICS:
		queue_redraw()

func _draw() -> void:
	# Early return if debug is disabled
	if not SettingsService.debug_hitbox_flags[GameEnums.HitboxType.PHYSICS]:
		return

	# Get the CollisionShape2D child
	var collision_shape: CollisionShape2D = null
	for child in get_children():
		if child is CollisionShape2D:
			collision_shape = child
			break

	if not collision_shape or not collision_shape.shape:
		return

	# Draw the rectangular swing hitbox
	var shape = collision_shape.shape
	var offset = collision_shape.position

	if shape is RectangleShape2D:
		var rect: RectangleShape2D = shape
		var half_size = rect.size / 2.0
		var points = PackedVector2Array([
			offset + Vector2(-half_size.x, -half_size.y),
			offset + Vector2(half_size.x, -half_size.y),
			offset + Vector2(half_size.x, half_size.y),
			offset + Vector2(-half_size.x, half_size.y)
		])

		# Draw filled polygon
		draw_colored_polygon(points, DEBUG_COLOR)

		# Draw outline
		for i in range(4):
			var p1 = points[i]
			var p2 = points[(i + 1) % 4]
			draw_line(p1, p2, DEBUG_OUTLINE_COLOR, DEBUG_OUTLINE_WIDTH)

extends Area2D
class_name EnemyHurtbox

## Enemy hurtbox component for receiving damage
## This Area2D detects incoming damage from projectiles and melee attacks
## and forwards it to the parent enemy.

## Debug visualization colors
const DEBUG_COLOR: Color = Color(1.0, 0.5, 0.0, 0.3)  # Orange, semi-transparent
const DEBUG_OUTLINE_COLOR: Color = Color(1.0, 0.5, 0.0, 0.8)  # Orange, opaque
const DEBUG_OUTLINE_WIDTH: float = 2.0

@export var shape_type: String = "circle"  # circle, rectangle, capsule
@export var shape_size: Vector2 = Vector2(24, 24)  # For circle: x = radius, for rectangle/capsule: x = width, y = height

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Set collision layer and mask
	collision_layer = 32  # Layer 6 (enemy_hurtbox = 2^5 = 32)
	collision_mask = 0  # Don't detect anything, just be detected

	# Connect signals for damage detection
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Configure collision shape if it doesn't exist
	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		add_child(collision_shape)

	_configure_shape()

	# Connect to debug toggle event
	Events.hitbox_debug_toggled.connect(_on_debug_toggled)
	if Globals.show_debug_hitboxes:
		queue_redraw()

func _configure_shape() -> void:
	"""Configure the collision shape based on shape_type and shape_size."""
	# If we already have a shape and didn't provide specific config, keep it
	if collision_shape and collision_shape.shape and shape_type == "circle" and shape_size == Vector2(24, 24):
		return

	var shape: Shape2D

	match shape_type:
		"circle":
			var circle = CircleShape2D.new()
			circle.radius = shape_size.x
			shape = circle
		"rectangle":
			var rect = RectangleShape2D.new()
			rect.size = shape_size
			shape = rect
		"capsule":
			var capsule = CapsuleShape2D.new()
			capsule.radius = shape_size.y / 2.0
			capsule.height = shape_size.x
			shape = capsule
			# Auto-rotate to horizontal if height > radius and it's a capsule
			collision_shape.rotation = PI/2
		_:
			push_error("Unknown shape_type: %s" % shape_type)
			return

	collision_shape.shape = shape

func configure(new_shape_type: String, new_size: Vector2) -> void:
	"""Dynamically configure the hurtbox shape."""
	# If called with basic defaults, ignore to preserve scene settings
	if new_shape_type == "circle" and new_size == Vector2(24, 24):
		return
		
	shape_type = new_shape_type
	shape_size = new_size
	if collision_shape:
		_configure_shape()
	if Globals.show_debug_hitboxes:
		queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	"""Handle body collision (e.g., projectiles that are bodies instead of areas)."""
	# This shouldn't happen with our current setup, but included for completeness
	pass

func _on_area_entered(area: Area2D) -> void:
	"""Handle area collision (melee attacks, projectiles)."""
	# Projectiles and melee attacks will handle damage themselves
	# This hurtbox just needs to be detectable
	pass


func _draw() -> void:
	if not Globals.show_debug_hitboxes:
		return

	if not collision_shape or not collision_shape.shape:
		return

	var shape = collision_shape.shape
	var offset = collision_shape.position

	if shape is CircleShape2D:
		var circle: CircleShape2D = shape
		var radius = circle.radius
		draw_circle(offset, radius, DEBUG_COLOR)
		draw_arc(offset, radius, 0, TAU, 64, DEBUG_OUTLINE_COLOR, DEBUG_OUTLINE_WIDTH)

	elif shape is RectangleShape2D:
		var rect: RectangleShape2D = shape
		var half_size = rect.size / 2.0
		var points = PackedVector2Array([
			offset + Vector2(-half_size.x, -half_size.y),
			offset + Vector2(half_size.x, -half_size.y),
			offset + Vector2(half_size.x, half_size.y),
			offset + Vector2(-half_size.x, half_size.y)
		])
		draw_colored_polygon(points, DEBUG_COLOR)
		for i in range(4):
			var p1 = points[i]
			var p2 = points[(i + 1) % 4]
			draw_line(p1, p2, DEBUG_OUTLINE_COLOR, DEBUG_OUTLINE_WIDTH)

	elif shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape
		var radius = capsule.radius
		var height = capsule.height
		var top_center = offset + Vector2(0, -height/2)
		var bottom_center = offset + Vector2(0, height/2)

		draw_arc(top_center, radius, 0, TAU, 32, DEBUG_COLOR, -1, true)
		draw_arc(bottom_center, radius, 0, TAU, 32, DEBUG_COLOR, -1, true)

		var rect_points = PackedVector2Array([
			top_center + Vector2(-radius, 0),
			top_center + Vector2(radius, 0),
			bottom_center + Vector2(radius, 0),
			bottom_center + Vector2(-radius, 0)
		])
		draw_colored_polygon(rect_points, DEBUG_COLOR)

		draw_arc(top_center, radius, 0, TAU, 32, DEBUG_OUTLINE_COLOR, DEBUG_OUTLINE_WIDTH)
		draw_arc(bottom_center, radius, 0, TAU, 32, DEBUG_OUTLINE_COLOR, DEBUG_OUTLINE_WIDTH)
		draw_line(top_center + Vector2(-radius, 0), bottom_center + Vector2(-radius, 0), DEBUG_OUTLINE_COLOR, DEBUG_OUTLINE_WIDTH)
		draw_line(top_center + Vector2(radius, 0), bottom_center + Vector2(radius, 0), DEBUG_OUTLINE_COLOR, DEBUG_OUTLINE_WIDTH)


func _on_debug_toggled(_show: bool) -> void:
	queue_redraw()

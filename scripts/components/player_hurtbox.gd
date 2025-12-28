extends Area2D
class_name PlayerHurtbox

## Unified player hurtbox component for receiving damage
## This Area2D:
## - Receives damage from enemy hurtboxes via contact (detected by layer 5)
## - Is detected by enemy hurtboxes for contact damage
##
## The actual damage dealing is handled by EnemyHurtbox when it detects this area.

## Debug visualization colors
const DEBUG_COLOR: Color = Color(0.0, 1.0, 0.0, 0.3) # Green, semi-transparent
const DEBUG_OUTLINE_COLOR: Color = Color(0.0, 1.0, 0.0, 0.8) # Green, opaque
const DEBUG_OUTLINE_WIDTH: float = 2.0

## Shape configuration
@export var shape_type: String = "circle"
@export var shape_size: Vector2 = Vector2(14, 14) # For circle: x = radius

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	# Set collision layer and mask
	# Layer 5 (player_hurtbox = 2^4 = 16) - be detected by enemy hurtboxes
	# No mask needed - we don't detect anything, we're just detectable
	collision_layer = 16
	collision_mask = 0
	monitoring = false # Don't need to detect anything
	monitorable = true # Allow detection by enemy hurtboxes

	# Add to group for identification
	add_to_group("player_hurtbox")

	# Configure collision shape if it doesn't exist
	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		add_child(collision_shape)

	_configure_shape()

	# Connect to debug toggle event
	Events.hitbox_debug_toggled.connect(_on_debug_toggled)
	if SettingsService.debug_hitbox_flags[GameEnums.HitboxType.PLAYER_HURTBOX]:
		queue_redraw()


func _configure_shape() -> void:
	"""Configure the collision shape based on shape_type and shape_size."""
	if not collision_shape:
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
			collision_shape.rotation = PI / 2
		_:
			DebugService.error(DebugService.VALIDATION, "Unknown shape_type: %s" % shape_type)
			return

	collision_shape.shape = shape


func configure(new_shape_type: String, new_size: Vector2) -> void:
	"""Dynamically configure the hurtbox shape."""
	shape_type = new_shape_type
	shape_size = new_size
	if collision_shape:
		_configure_shape()
	if SettingsService.debug_hitbox_flags[GameEnums.HitboxType.PLAYER_HURTBOX]:
		queue_redraw()


func configure_from_profile(profile: CollisionProfile) -> void:
	"""Configure from a CollisionProfile resource."""
	match profile.hurtbox_shape_type:
		CollisionProfile.ShapeType.CIRCLE:
			shape_type = "circle"
		CollisionProfile.ShapeType.RECTANGLE:
			shape_type = "rectangle"
		CollisionProfile.ShapeType.CAPSULE:
			shape_type = "capsule"
	
	shape_size = profile.hurtbox_size
	_configure_shape()
	
	if SettingsService.debug_hitbox_flags[GameEnums.HitboxType.PLAYER_HURTBOX]:
		queue_redraw()


func _draw() -> void:
	if not SettingsService.debug_hitbox_flags[GameEnums.HitboxType.PLAYER_HURTBOX]:
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
		var top_center = offset + Vector2(0, -height / 2)
		var bottom_center = offset + Vector2(0, height / 2)

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


func _on_debug_toggled(type: int, _show: bool) -> void:
	if type == GameEnums.HitboxType.PLAYER_HURTBOX:
		queue_redraw()

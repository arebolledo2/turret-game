extends Area2D
class_name EnemyDamageZone

## Enemy damage zone component for dealing contact damage to player
## This Area2D is smaller than the hurtbox, creating a "safety zone"
## where the player can get close without taking damage.

## Debug visualization colors
const DEBUG_COLOR: Color = Color(1.0, 0.0, 0.0, 0.3)  # Red, semi-transparent
const DEBUG_OUTLINE_COLOR: Color = Color(1.0, 0.0, 0.0, 0.8)  # Red, opaque
const DEBUG_OUTLINE_WIDTH: float = 2.0

@export var shape_type: String = "circle"  # circle, rectangle, capsule
@export var shape_size: float = 18.0  # For circle: radius. For others, adapt as needed
@export var damage_cooldown: float = 0.5  # Time between damage ticks

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var can_damage := true
var damage_timer: Timer

func _ready() -> void:
	# Set collision layer and mask
	collision_layer = 64  # Layer 7 (enemy_damage_zone = 2^6 = 64)
	collision_mask = 16  # Layer 5 (player_hurtbox = 2^4 = 16)
	monitoring = true  # Explicit enable
	monitorable = true  # Allow detection

	# Connect signals
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	# Setup damage cooldown timer
	damage_timer = Timer.new()
	damage_timer.one_shot = true
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	add_child(damage_timer)

	# Only configure shape if not already set in scene
	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		add_child(collision_shape)
		_configure_shape()
	elif not collision_shape.shape:
		_configure_shape()

	# Connect to debug toggle event
	Events.hitbox_debug_toggled.connect(_on_debug_toggled)
	if Globals.show_debug_hitboxes:
		queue_redraw()

func _configure_shape() -> void:
	"""Configure the collision shape based on shape_type and shape_size."""
	var shape: Shape2D

	match shape_type:
		"circle":
			var circle = CircleShape2D.new()
			circle.radius = shape_size
			shape = circle
		"rectangle":
			# For rectangle, shape_size represents radius, convert to size
			var rect = RectangleShape2D.new()
			rect.size = Vector2(shape_size * 2, shape_size * 2)
			shape = rect
		"capsule":
			var capsule = CapsuleShape2D.new()
			capsule.radius = shape_size / 2.0
			capsule.height = shape_size
			shape = capsule
		_:
			push_error("Unknown shape_type: %s" % shape_type)
			return

	collision_shape.shape = shape

func configure(new_shape_type: String, new_size: float, offset: Vector2 = Vector2.ZERO) -> void:
	"""Dynamically configure the damage zone shape and position."""
	shape_type = new_shape_type
	shape_size = new_size
	position = offset
	if collision_shape:
		_configure_shape()
	if Globals.show_debug_hitboxes:
		queue_redraw()

func _on_area_entered(area: Area2D) -> void:
	"""When player hurtbox enters, deal damage."""
	if not can_damage:
		return

	# Check if this is the player hurtbox
	if not area.is_in_group("player_hurtbox"):
		return

	# Get the player from the hurtbox's parent
	var player = area.get_parent()
	if not player:
		push_warning("[EnemyDamageZone] PlayerHurtbox has no parent")
		return
	
	if not player.is_in_group("player"):
		push_warning("[EnemyDamageZone] Hurtbox parent not in player group: %s" % player.name)
		return
	
	if not player.has_method("take_damage"):
		push_warning("[EnemyDamageZone] Player missing take_damage method")
		return

	# Deal contact damage
	var enemy = get_parent()
	if not enemy:
		push_warning("[EnemyDamageZone] DamageZone has no parent enemy")
		return
	
	if not "contact_damage" in enemy:
		push_warning("[EnemyDamageZone] Parent enemy missing contact_damage property")
		return
	
	player.take_damage(enemy.contact_damage)

	# Start cooldown
	can_damage = false
	damage_timer.wait_time = damage_cooldown
	damage_timer.start()

func _on_area_exited(area: Area2D) -> void:
	"""When player hurtbox exits, reset damage cooldown."""
	# Reset damage ability when player leaves
	if area.is_in_group("player_hurtbox"):
		can_damage = true
		if damage_timer.time_left > 0:
			damage_timer.stop()

func _on_damage_timer_timeout() -> void:
	"""Reset damage capability after cooldown."""
	can_damage = true


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

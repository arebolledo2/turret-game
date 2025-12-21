extends Area2D
class_name EnemyHurtbox

const CollisionProfileClass = preload("res://scripts/components/collision_profile.gd")

## Unified enemy hurtbox component for receiving AND dealing damage
## This Area2D:
## - Receives damage from projectiles and melee attacks (detected by layer 6)
## - Deals contact damage to the player (detects layer 5)
##
## This replaces the old separate Hurtbox + DamageZone system.

## Debug visualization colors
const DEBUG_COLOR_HURTBOX: Color = Color(1.0, 0.5, 0.0, 0.3)  # Orange, semi-transparent
const DEBUG_OUTLINE_COLOR: Color = Color(1.0, 0.5, 0.0, 0.8)  # Orange, opaque
const DEBUG_OUTLINE_WIDTH: float = 2.0

## Shape configuration
@export var shape_type: String = "circle"  # circle, rectangle, capsule
@export var shape_size: Vector2 = Vector2(24, 24)  # For circle: x = radius, for rectangle/capsule: x = width, y = height

## Contact damage configuration
@export var deals_contact_damage: bool = true
@export var damage_cooldown: float = 0.5  # Time between damage ticks

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

## Internal state
var can_damage := true
var damage_timer: Timer
var overlapping_player_hurtbox: Area2D = null  # Track if player is inside

func _ready() -> void:
	# Set collision layer and mask for unified hurtbox
	# Layer 6 (enemy_hurtbox = 2^5 = 32) - be detected by projectiles/melee
	# Mask 5 (player_hurtbox = 2^4 = 16) - detect player for contact damage
	collision_layer = 32
	collision_mask = 16 if deals_contact_damage else 0
	monitoring = deals_contact_damage
	monitorable = true

	# Add to group for identification
	add_to_group("enemy_hurtbox")

	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	# Setup damage cooldown timer
	damage_timer = Timer.new()
	damage_timer.one_shot = true
	damage_timer.timeout.connect(_on_damage_timer_timeout)
	add_child(damage_timer)

	# Configure collision shape if it doesn't exist
	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		add_child(collision_shape)

	_configure_shape()

	# Connect to debug toggle event
	Events.hitbox_debug_toggled.connect(_on_debug_toggled)
	if Globals.debug_hitbox_flags[Globals.HitboxType.ENEMY_HURTBOX]:
		queue_redraw()


func _configure_shape() -> void:
	"""Configure the collision shape based on shape_type and shape_size."""
	if not collision_shape:
		return
	
	# Always apply configuration - no more "ignore defaults" logic
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
			# Auto-rotate to horizontal for capsule
			collision_shape.rotation = PI / 2
		_:
			push_error("Unknown shape_type: %s" % shape_type)
			return

	collision_shape.shape = shape


func configure(new_shape_type: String, new_size: Vector2) -> void:
	"""Dynamically configure the hurtbox shape."""
	shape_type = new_shape_type
	shape_size = new_size
	if collision_shape:
		_configure_shape()
	if Globals.debug_hitbox_flags[Globals.HitboxType.ENEMY_HURTBOX]:
		queue_redraw()


func configure_from_profile(collision_profile: Resource) -> void:
	"""Configure from a CollisionProfile resource."""
	# Map shape type enum to string
	match collision_profile.hurtbox_shape_type:
		CollisionProfileClass.ShapeType.CIRCLE:
			shape_type = "circle"
		CollisionProfileClass.ShapeType.RECTANGLE:
			shape_type = "rectangle"
		CollisionProfileClass.ShapeType.CAPSULE:
			shape_type = "capsule"
	
	shape_size = collision_profile.hurtbox_size
	deals_contact_damage = collision_profile.deals_contact_damage
	damage_cooldown = collision_profile.damage_cooldown
	
	# Update collision mask based on whether we deal contact damage
	collision_mask = 16 if deals_contact_damage else 0
	monitoring = deals_contact_damage
	
	_configure_shape()
	
	if Globals.debug_hitbox_flags[Globals.HitboxType.ENEMY_HURTBOX]:
		queue_redraw()


func _on_body_entered(_body: Node2D) -> void:
	"""Handle body collision - projectiles now use area_entered instead."""
	pass


func _on_area_entered(area: Area2D) -> void:
	"""Handle area collision - player hurtbox for contact damage."""
	if not deals_contact_damage:
		return
	
	if not can_damage:
		return

	# Check if this is the player hurtbox
	if not area.is_in_group("player_hurtbox"):
		return

	overlapping_player_hurtbox = area
	_deal_contact_damage()


func _on_area_exited(area: Area2D) -> void:
	"""When player hurtbox exits, reset damage cooldown."""
	if area.is_in_group("player_hurtbox"):
		overlapping_player_hurtbox = null
		can_damage = true
		if damage_timer.time_left > 0:
			damage_timer.stop()


func _deal_contact_damage() -> void:
	"""Deal contact damage to the overlapping player."""
	if not overlapping_player_hurtbox or not is_instance_valid(overlapping_player_hurtbox):
		return
	
	# Get the player from the hurtbox's parent
	var player = overlapping_player_hurtbox.get_parent()
	if not player:
		push_warning("[EnemyHurtbox] PlayerHurtbox has no parent")
		return
	
	if not player.is_in_group("player"):
		push_warning("[EnemyHurtbox] Hurtbox parent not in player group: %s" % player.name)
		return
	
	if not player.has_method("take_damage"):
		push_warning("[EnemyHurtbox] Player missing take_damage method")
		return

	# Get contact damage from parent enemy
	var enemy = get_parent()
	if not enemy:
		push_warning("[EnemyHurtbox] Hurtbox has no parent enemy")
		return
	
	if not "contact_damage" in enemy:
		push_warning("[EnemyHurtbox] Parent enemy missing contact_damage property")
		return
	
	player.take_damage(enemy.contact_damage)

	# Start cooldown
	can_damage = false
	damage_timer.wait_time = damage_cooldown
	damage_timer.start()


func _on_damage_timer_timeout() -> void:
	"""Reset damage capability after cooldown, deal damage again if still overlapping."""
	can_damage = true
	
	# If player is still overlapping, deal damage again
	if overlapping_player_hurtbox and is_instance_valid(overlapping_player_hurtbox):
		_deal_contact_damage()


func _draw() -> void:
	if not Globals.debug_hitbox_flags[Globals.HitboxType.ENEMY_HURTBOX]:
		return

	if not collision_shape or not collision_shape.shape:
		return

	var shape = collision_shape.shape
	var offset = collision_shape.position

	if shape is CircleShape2D:
		var circle: CircleShape2D = shape
		var radius = circle.radius
		draw_circle(offset, radius, DEBUG_COLOR_HURTBOX)
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
		draw_colored_polygon(points, DEBUG_COLOR_HURTBOX)
		for i in range(4):
			var p1 = points[i]
			var p2 = points[(i + 1) % 4]
			draw_line(p1, p2, DEBUG_OUTLINE_COLOR, DEBUG_OUTLINE_WIDTH)

	elif shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape
		var radius = capsule.radius
		var height = capsule.height
		
		# If the node is rotated 90 degrees, we need to draw it rotated as well
		# since draw_* functions are in local space.
		# However, it's easier to just draw it using the node's transform if we're not
		# already handling rotation in the draw calls.
		
		draw_set_transform(offset, collision_shape.rotation, Vector2.ONE)
		
		var top_center = Vector2(0, -height / 2 + radius)
		var bottom_center = Vector2(0, height / 2 - radius)

		draw_arc(top_center, radius, 0, TAU, 32, DEBUG_COLOR_HURTBOX, -1, true)
		draw_arc(bottom_center, radius, 0, TAU, 32, DEBUG_COLOR_HURTBOX, -1, true)

		var rect_points = PackedVector2Array([
			top_center + Vector2(-radius, 0),
			top_center + Vector2(radius, 0),
			bottom_center + Vector2(radius, 0),
			bottom_center + Vector2(-radius, 0)
		])
		draw_colored_polygon(rect_points, DEBUG_COLOR_HURTBOX)

		draw_arc(top_center, radius, 0, TAU, 32, DEBUG_OUTLINE_COLOR, DEBUG_OUTLINE_WIDTH)
		draw_arc(bottom_center, radius, 0, TAU, 32, DEBUG_OUTLINE_COLOR, DEBUG_OUTLINE_WIDTH)
		draw_line(top_center + Vector2(-radius, 0), bottom_center + Vector2(-radius, 0), DEBUG_OUTLINE_COLOR, DEBUG_OUTLINE_WIDTH)
		draw_line(top_center + Vector2(radius, 0), bottom_center + Vector2(radius, 0), DEBUG_OUTLINE_COLOR, DEBUG_OUTLINE_WIDTH)
		
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


func _on_debug_toggled(type: int, _show: bool) -> void:
	if type == Globals.HitboxType.ENEMY_HURTBOX:
		queue_redraw()

extends Area2D
class_name PlayerHurtbox

## Player hurtbox component for receiving damage
## This Area2D detects incoming damage from enemy damage zones
## and forwards it to the parent player while respecting invincibility.

## Debug visualization colors
const DEBUG_COLOR: Color = Color(0.0, 1.0, 0.0, 0.3)  # Green, semi-transparent
const DEBUG_OUTLINE_COLOR: Color = Color(0.0, 1.0, 0.0, 0.8)  # Green, opaque
const DEBUG_OUTLINE_WIDTH: float = 2.0

func _ready() -> void:
	# Set collision layer and mask
	collision_layer = 16  # Layer 5 (player_hurtbox = 2^4 = 16)
	collision_mask = 64  # Layer 7 (enemy_damage_zone = 2^6 = 64)
	monitoring = true  # Detect damage zones
	monitorable = true  # Allow detection by damage zones

	# Add to group for identification
	add_to_group("player_hurtbox")

	# Connect signals - damage is handled by enemy_damage_zone
	# This hurtbox just needs to be detectable
	area_entered.connect(_on_area_entered)

	# Connect to debug toggle event
	Events.hitbox_debug_toggled.connect(_on_debug_toggled)
	if Globals.show_debug_hitboxes:
		queue_redraw()

func _on_area_entered(area: Area2D) -> void:
	"""Handle incoming damage from enemy damage zones."""
	# The EnemyDamageZone handles damage application
	# This is here for potential future use or debugging
	pass


func _draw() -> void:
	if not Globals.show_debug_hitboxes:
		return

	var collision_shape = get_node_or_null("CollisionShape2D")
	if not collision_shape or not collision_shape.shape:
		return

	if collision_shape.shape is CircleShape2D:
		var circle: CircleShape2D = collision_shape.shape
		var radius = circle.radius
		draw_circle(collision_shape.position, radius, DEBUG_COLOR)
		draw_arc(collision_shape.position, radius, 0, TAU, 64, DEBUG_OUTLINE_COLOR, DEBUG_OUTLINE_WIDTH)


func _on_debug_toggled(_show: bool) -> void:
	queue_redraw()

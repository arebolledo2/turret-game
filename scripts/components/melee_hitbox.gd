extends Area2D
class_name MeleeHitbox

## Melee attack hitbox with expanding cone animation
## This Area2D uses a CollisionPolygon2D to create a cone-shaped hitbox
## that expands from the player during the melee attack animation.

signal enemy_hit(enemy: Node2D)

@export var arc_degrees: float = 120.0
@export var max_range: float = 80.0
@export var segments: int = 10

@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D

var base_polygon_points: PackedVector2Array
var expansion_tween: Tween
var is_active := false

func _ready() -> void:
	# Set collision layer and mask
	collision_layer = 128  # Layer 8 (melee_attack = 2^7 = 128)
	collision_mask = 32  # Layer 6 (enemy_hurtbox = 2^5 = 32)

	# Connect signals
	area_entered.connect(_on_area_entered)

	# Create collision polygon if it doesn't exist
	if not collision_polygon:
		collision_polygon = CollisionPolygon2D.new()
		add_child(collision_polygon)

	# Generate base cone shape
	base_polygon_points = _generate_cone_points(arc_degrees, max_range, segments)
	collision_polygon.polygon = base_polygon_points

	# Start disabled
	disable_hitbox()

func _generate_cone_points(arc_deg: float, range: float, seg_count: int) -> PackedVector2Array:
	"""Generate a fan-shaped cone polygon for the melee hitbox."""
	var points = PackedVector2Array()
	points.append(Vector2.ZERO)  # Origin point at player position

	var half_arc = deg_to_rad(arc_deg / 2.0)

	# Generate points along the arc
	for i in range(seg_count + 1):
		var t = float(i) / float(seg_count)
		var angle = -half_arc + (t * 2.0 * half_arc)
		var point = Vector2(cos(angle), sin(angle)) * range
		points.append(point)

	return points

func enable_hitbox() -> void:
	"""Enable collision detection for the melee hitbox."""
	collision_polygon.disabled = false
	is_active = true

func disable_hitbox() -> void:
	"""Disable collision detection for the melee hitbox."""
	collision_polygon.disabled = true
	is_active = false

func animate_expansion(duration: float, start_scale: float = 0.3) -> void:
	"""Animate the cone expanding from start_scale to full size."""
	# Stop any existing tween
	if expansion_tween and expansion_tween.is_running():
		expansion_tween.kill()

	# Create new tween for expansion
	expansion_tween = create_tween()
	expansion_tween.set_ease(Tween.EASE_OUT)
	expansion_tween.set_trans(Tween.TRANS_QUAD)

	# Animate scale from start_scale to 1.0
	scale = Vector2(start_scale, start_scale)
	expansion_tween.tween_property(self, "scale", Vector2.ONE, duration)

func update_direction(direction: Vector2) -> void:
	"""Update the cone's rotation to face the specified direction."""
	if direction.length() > 0:
		rotation = direction.angle()

func _on_area_entered(area: Area2D) -> void:
	"""Handle collision with enemy hurtbox."""
	if not is_active:
		return

	# Check if this is an enemy hurtbox
	if not area is EnemyHurtbox:
		return

	# Get the enemy from the hurtbox's parent
	var enemy = area.get_parent()
	if enemy and enemy.is_in_group("enemies"):
		enemy_hit.emit(enemy)

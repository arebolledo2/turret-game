extends Area2D
class_name EnemyHurtbox

## Enemy hurtbox component for receiving damage
## This Area2D detects incoming damage from projectiles and melee attacks
## and forwards it to the parent enemy.

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

func _configure_shape() -> void:
	"""Configure the collision shape based on shape_type and shape_size."""
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

func _on_body_entered(body: Node2D) -> void:
	"""Handle body collision (e.g., projectiles that are bodies instead of areas)."""
	# This shouldn't happen with our current setup, but included for completeness
	pass

func _on_area_entered(area: Area2D) -> void:
	"""Handle area collision (melee attacks, projectiles)."""
	# Projectiles and melee attacks will handle damage themselves
	# This hurtbox just needs to be detectable
	pass

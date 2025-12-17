extends Area2D
class_name EnemyDamageZone

## Enemy damage zone component for dealing contact damage to player
## This Area2D is smaller than the hurtbox, creating a "safety zone"
## where the player can get close without taking damage.

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

	# Connect signals
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

func _on_area_entered(area: Area2D) -> void:
	"""When player hurtbox enters, deal damage."""
	if not can_damage:
		return

	# Check if this is the player hurtbox
	if not area.is_in_group("player_hurtbox"):
		return

	# Get the player from the hurtbox's parent
	var player = area.get_parent()
	if not player or not player.has_method("take_damage"):
		return

	# Deal contact damage
	var enemy = get_parent()
	if enemy and "contact_damage" in enemy:
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

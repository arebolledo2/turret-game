extends Node
class_name CollisionManager

const CollisionProfileClass = preload("res://scripts/components/collision_profile.gd")

## Manages collision shapes for an entity from a single CollisionProfile source
## This component synchronizes the physics collision shape and hurtbox shape
## from one source of truth, ensuring consistent sizing relationships.
##
## Attach this to an enemy or player entity and assign a CollisionProfile resource.

## The collision profile defining both shapes
@export var profile: Resource  # CollisionProfile

## Node paths for the collision shapes to configure
@export var physics_collision_path: NodePath = "CollisionShape2D"
@export var hurtbox_path: NodePath = "Hurtbox"

var physics_collision: CollisionShape2D
var hurtbox: Area2D


func _ready() -> void:
	# Get references to collision nodes
	physics_collision = get_node_or_null(physics_collision_path) as CollisionShape2D
	hurtbox = get_node_or_null(hurtbox_path) as Area2D
	
	# Apply profile if set
	if profile:
		apply_profile(profile)


func apply_profile(new_profile: Resource) -> void:
	"""Apply a collision profile to both physics and hurtbox shapes."""
	profile = new_profile
	
	if not profile:
		DebugService.warn(DebugService.VALIDATION, "[CollisionManager] No profile set")
		return

	# Validate the profile
	if not profile.validate():
		DebugService.warn(DebugService.VALIDATION, "[CollisionManager] Profile validation failed - physics shape larger than hurtbox!")

	# Configure physics collision shape
	if physics_collision:
		_apply_physics_shape()
	else:
		DebugService.warn(DebugService.VALIDATION, "[CollisionManager] No physics collision shape found at path: %s" % physics_collision_path)

	# Configure hurtbox
	if hurtbox:
		_apply_hurtbox_shape()
	else:
		DebugService.warn(DebugService.VALIDATION, "[CollisionManager] No hurtbox found at path: %s" % hurtbox_path)


func _apply_physics_shape() -> void:
	"""Apply physics shape from profile."""
	if not profile or not physics_collision:
		return
	
	physics_collision.shape = profile.create_physics_shape()
	
	# Handle rotation for capsule shapes
	if profile.physics_needs_rotation():
		physics_collision.rotation = PI / 2
	else:
		physics_collision.rotation = 0


func _apply_hurtbox_shape() -> void:
	"""Apply hurtbox shape from profile."""
	if not profile or not hurtbox:
		return
	
	# If hurtbox has configure_from_profile method, use it
	if hurtbox.has_method("configure_from_profile"):
		hurtbox.configure_from_profile(profile)
	elif hurtbox.has_method("configure"):
		# Fallback to legacy configure method
		var shape_type_str: String
		match profile.hurtbox_shape_type:
			CollisionProfileClass.ShapeType.CIRCLE:
				shape_type_str = "circle"
			CollisionProfileClass.ShapeType.RECTANGLE:
				shape_type_str = "rectangle"
			CollisionProfileClass.ShapeType.CAPSULE:
				shape_type_str = "capsule"
		hurtbox.configure(shape_type_str, profile.hurtbox_size)
	else:
		# Direct shape assignment
		var hurtbox_collision = hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if hurtbox_collision:
			hurtbox_collision.shape = profile.create_hurtbox_shape()
			if profile.hurtbox_needs_rotation():
				hurtbox_collision.rotation = PI / 2
			else:
				hurtbox_collision.rotation = 0


## Create and apply a profile from legacy configuration
func apply_from_legacy(hurtbox_config: Dictionary, physics_radius: float = 16.0) -> void:
	"""Create a profile from legacy config and apply it."""
	var new_profile = CollisionProfileClass.from_legacy_config(hurtbox_config, {}, physics_radius)
	apply_profile(new_profile)


## Get the current physics shape radius (for circle shapes)
func get_physics_radius() -> float:
	if profile and profile.physics_shape_type == CollisionProfileClass.ShapeType.CIRCLE:
		return profile.physics_size.x
	return 16.0


## Get the current hurtbox radius (for circle shapes)
func get_hurtbox_radius() -> float:
	if profile and profile.hurtbox_shape_type == CollisionProfileClass.ShapeType.CIRCLE:
		return profile.hurtbox_size.x
	return 24.0

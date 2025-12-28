extends Resource
class_name CollisionProfile

## Unified collision profile for entities (enemies, player, etc.)
## Defines physics and hurtbox shapes with enforced size relationships:
## - physics_size <= hurtbox_size (entity is hittable before physical collision)
##
## This resource is the single source of truth for all collision shapes,
## eliminating mismatches and side effects when tweaking hitboxes.

## Shape types
enum ShapeType { CIRCLE, RECTANGLE, CAPSULE }

## Physics shape configuration (CharacterBody2D collision)
@export_group("Physics Shape")
@export var physics_shape_type: ShapeType = ShapeType.CIRCLE
@export var physics_size: Vector2 = Vector2(16, 16)  ## For circle: x = radius. For rect/capsule: x = width, y = height

## Hurtbox shape configuration (unified damage giving/receiving)
@export_group("Hurtbox Shape")
@export var hurtbox_shape_type: ShapeType = ShapeType.CIRCLE
@export var hurtbox_size: Vector2 = Vector2(24, 24)  ## For circle: x = radius. For rect/capsule: x = width, y = height

## Contact damage configuration
@export_group("Contact Damage")
@export var deals_contact_damage: bool = true
@export var damage_cooldown: float = 0.5  ## Time between contact damage ticks


## Validate the collision profile constraints
func validate() -> bool:
	var physics_area := _get_approximate_area(physics_shape_type, physics_size)
	var hurtbox_area := _get_approximate_area(hurtbox_shape_type, hurtbox_size)
	
	if physics_area > hurtbox_area:
		DebugService.warn(DebugService.VALIDATION, "[CollisionProfile] Physics shape is larger than hurtbox! This will cause hit detection issues.")
		return false
	
	return true


## Get approximate area for size comparison
func _get_approximate_area(shape_type: ShapeType, size: Vector2) -> float:
	match shape_type:
		ShapeType.CIRCLE:
			return PI * size.x * size.x  # radius squared
		ShapeType.RECTANGLE:
			return size.x * size.y
		ShapeType.CAPSULE:
			# Approximate: rectangle + two semicircles
			# For CapsuleShape2D, height is the total length including caps
			# and radius is the width / 2.
			var radius: float = size.y / 2.0
			var circle_area: float = PI * radius * radius
			var rect_height: float = max(0.0, size.x - 2.0 * radius)
			var rect_area: float = rect_height * (2.0 * radius)
			return rect_area + circle_area
	return 0.0


## Create physics Shape2D from configuration
func create_physics_shape() -> Shape2D:
	return _create_shape(physics_shape_type, physics_size)


## Create hurtbox Shape2D from configuration
func create_hurtbox_shape() -> Shape2D:
	return _create_shape(hurtbox_shape_type, hurtbox_size)


## Internal: create a Shape2D from type and size
func _create_shape(shape_type: ShapeType, size: Vector2) -> Shape2D:
	match shape_type:
		ShapeType.CIRCLE:
			var circle := CircleShape2D.new()
			circle.radius = size.x
			return circle
		ShapeType.RECTANGLE:
			var rect := RectangleShape2D.new()
			rect.size = size
			return rect
		ShapeType.CAPSULE:
			var capsule := CapsuleShape2D.new()
			# CapsuleShape2D is vertical (Y-axis aligned).
			# We want a horizontal capsule, so we swap X and Y for the shape itself,
			# then rotate the node that uses it.
			capsule.radius = size.y / 2.0
			# Ensure height is at least twice the radius to avoid circle behavior
			capsule.height = max(size.x, size.y)
			return capsule
	return null


## Check if capsule shapes need rotation (horizontal orientation)
func physics_needs_rotation() -> bool:
	return physics_shape_type == ShapeType.CAPSULE


func hurtbox_needs_rotation() -> bool:
	return hurtbox_shape_type == ShapeType.CAPSULE


## Create a profile from legacy configuration dictionaries
static func from_legacy_config(hurtbox_config: Dictionary, _damage_zone_config: Dictionary, physics_radius: float = 16.0) -> CollisionProfile:
	var new_profile := CollisionProfile.new()
	
	# Physics shape (default circle)
	new_profile.physics_shape_type = ShapeType.CIRCLE
	new_profile.physics_size = Vector2(physics_radius, physics_radius)
	
	# Hurtbox from legacy config (use hurtbox config, not damage_zone since we're unifying)
	var hurtbox_type_str: String = hurtbox_config.get("type", "circle")
	new_profile.hurtbox_shape_type = _string_to_shape_type(hurtbox_type_str)
	
	var legacy_hurtbox_size = hurtbox_config.get("size", Vector2(24, 24))
	if legacy_hurtbox_size is float:
		new_profile.hurtbox_size = Vector2(legacy_hurtbox_size, legacy_hurtbox_size)
	else:
		new_profile.hurtbox_size = legacy_hurtbox_size
	
	# Contact damage settings
	new_profile.deals_contact_damage = true
	new_profile.damage_cooldown = 0.5
	
	return new_profile


static func _string_to_shape_type(type_str: String) -> ShapeType:
	match type_str.to_lower():
		"circle":
			return ShapeType.CIRCLE
		"rectangle", "rect":
			return ShapeType.RECTANGLE
		"capsule":
			return ShapeType.CAPSULE
	return ShapeType.CIRCLE

extends Node
class_name EnemyVisuals

## Handles enemy sprite management and visual effects.
##
## Responsibilities:
## - Load directional sprites
## - Update sprite based on movement direction
## - Apply color tints and scale
## - Handle status effect visual overlays
## - Handle status effect particle effects

# Directional sprite textures
var sprite_south: Texture2D
var sprite_north: Texture2D
var sprite_east: Texture2D
var sprite_west: Texture2D
var sprite_south_east: Texture2D
var sprite_south_west: Texture2D
var sprite_north_east: Texture2D
var sprite_north_west: Texture2D

# Dependencies (set via initialize)
var enemy: CharacterBody2D = null
var sprite_node: Node = null # Sprite2D or AnimatedSprite2D
var is_animated: bool = false

# Config
var base_scale: float = 1.0
var color_tint: Color = Color.WHITE

# Status effect particles
var fire_particles: GPUParticles2D = null

func initialize(p_enemy: CharacterBody2D, p_base_scale: float, p_color_tint: Color, sprite_folder: String = "") -> void:
	"""Initialize component with required references."""
	enemy = p_enemy
	base_scale = p_base_scale
	color_tint = p_color_tint
	assert(enemy != null, "EnemyVisuals: enemy reference required")

	# Determine sprite type
	if enemy.has_node("AnimatedSprite2D"):
		sprite_node = enemy.get_node("AnimatedSprite2D")
		is_animated = true
	elif enemy.has_node("Sprite2D"):
		sprite_node = enemy.get_node("Sprite2D")
		is_animated = false

	# Load sprites for non-animated enemies
	if not is_animated and sprite_folder != "":
		_load_sprites(sprite_folder)

	# Apply initial visuals
	_apply_visuals()

func _load_sprites(folder_path: String) -> void:
	"""Load directional sprites from the specified folder."""
	# Try to load left/right sprites first (simpler setup)
	var left_path = folder_path + "/spider_drone_left.png"
	var right_path = folder_path + "/spider_drone_right.png"
	
	if ResourceLoader.exists(left_path) and ResourceLoader.exists(right_path):
		# Simple left/right sprite mode
		sprite_west = load(left_path)
		sprite_east = load(right_path)
		# Use the same sprite for all other directions (will be handled in update_direction_sprite)
		sprite_south = sprite_east
		sprite_north = sprite_east
		sprite_south_east = sprite_east
		sprite_south_west = sprite_west
		sprite_north_east = sprite_east
		sprite_north_west = sprite_west
		return
	
	# Fallback to 8-directional sprites
	sprite_south = load(folder_path + "/enemy_south.png")
	sprite_north = load(folder_path + "/enemy_north.png")
	sprite_east = load(folder_path + "/enemy_east.png")
	sprite_west = load(folder_path + "/enemy_west.png")
	sprite_south_east = load(folder_path + "/enemy_south_east.png")
	sprite_south_west = load(folder_path + "/enemy_south_west.png")
	sprite_north_east = load(folder_path + "/enemy_north_east.png")
	sprite_north_west = load(folder_path + "/enemy_north_west.png")

func _apply_visuals() -> void:
	"""Apply scale and color tint to the sprite."""
	if not sprite_node:
		return

	sprite_node.scale *= base_scale
	sprite_node.modulate = color_tint

	# Set initial texture for Sprite2D
	if not is_animated and sprite_south:
		sprite_node.texture = sprite_south

func update_direction_sprite(direction: Vector2) -> void:
	"""Update sprite based on movement direction."""
	if not sprite_node or direction.length() == 0:
		return

	# AnimatedSprite2D enemies use left/right animations only
	if is_animated:
		if direction.x < 0:
			sprite_node.play("move_left")
		else:
			sprite_node.play("move_right")
		return

	# Sprite2D enemies use 8-directional sprites
	# Get angle and convert to 8-direction
	var angle := direction.angle()

	# Normalize angle to 0-2PI range
	if angle < 0:
		angle += TAU

	# Divide into 8 segments (each 45 degrees = PI/4)
	# Offset by 22.5 degrees (PI/8) to center segments
	var segment := int((angle + PI / 8) / (PI / 4)) % 8

	# Map segment to sprite (0 = east, going counter-clockwise)
	match segment:
		0: sprite_node.texture = sprite_east
		1: sprite_node.texture = sprite_north_east
		2: sprite_node.texture = sprite_north
		3: sprite_node.texture = sprite_north_west
		4: sprite_node.texture = sprite_west
		5: sprite_node.texture = sprite_south_west
		6: sprite_node.texture = sprite_south
		7: sprite_node.texture = sprite_south_east

func apply_damage_flash() -> void:
	"""Flash white briefly to indicate damage."""
	if not sprite_node:
		return

	sprite_node.modulate = Color.WHITE
	var tween = enemy.create_tween()
	tween.tween_property(sprite_node, "modulate", color_tint, 0.1)

func update_status_visual(active_effects: Dictionary) -> void:
	"""Update visual tint and particle effects based on active status effects."""
	if not sprite_node:
		return

	if active_effects.is_empty():
		# Reset to base color tint
		sprite_node.modulate = color_tint
		_clear_fire_particles()
		return

	# Start with base tint and blend status effect colors
	var final_color := color_tint

	if active_effects.has(GameEnums.DamageType.FIRE):
		final_color = final_color.lerp(Color(1.0, 0.5, 0.2, 1), 0.4) # Orange tint
		_show_fire_particles()
	if active_effects.has(GameEnums.DamageType.ELECTRIC):
		final_color = final_color.lerp(Color(0.5, 0.8, 1.0, 1), 0.4) # Blue tint
	if active_effects.has(GameEnums.DamageType.PLASMA):
		final_color = final_color.lerp(Color(0.8, 0.4, 1.0, 1), 0.4) # Purple tint

	sprite_node.modulate = final_color
	
	# Clear fire particles if not burning
	if not active_effects.has(GameEnums.DamageType.FIRE):
		_clear_fire_particles()

func play_death_animation(callback: Callable) -> void:
	"""Animate death effect - scale down and fade."""
	if not sprite_node:
		callback.call()
		return

	# Clear fire particles on death
	_clear_fire_particles()

	var tween = enemy.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite_node, "scale", Vector2.ZERO, 0.15)
	tween.tween_property(sprite_node, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(callback)


# =============================================================================
# STATUS EFFECT PARTICLES
# =============================================================================

func _show_fire_particles() -> void:
	"""Show fire particles around the enemy."""
	if fire_particles != null:
		return # Already showing
	
	fire_particles = GPUParticles2D.new()
	
	# Configure fire particle system
	fire_particles.emitting = true
	fire_particles.amount = 20
	fire_particles.lifetime = 0.8
	fire_particles.process_material = _create_fire_particle_material()
	
	# Position particles around the enemy
	fire_particles.position = Vector2.ZERO
	
	enemy.add_child(fire_particles)


func _clear_fire_particles() -> void:
	"""Remove fire particles if they exist."""
	if fire_particles != null:
		fire_particles.queue_free()
		fire_particles = null


func _create_fire_particle_material() -> ParticleProcessMaterial:
	"""Create a simple fire particle material."""
	var material = ParticleProcessMaterial.new()
	
	# Emission shape - emit from a circle around the enemy
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 15.0
	
	# Particle direction - upward with some spread
	material.direction = Vector3(0, -1, 0)
	material.spread = 0.5
	
	# Initial velocity
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 40.0
	
	# Gravity - particles float upward
	material.gravity = Vector3(0, -30.0, 0)
	
	# Scale - particles start small and grow
	material.scale_min = 0.3
	material.scale_max = 0.6
	
	# Color gradient - orange to red to transparent
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.8, 0.3, 1.0)) # Yellow-orange
	gradient.add_point(0.3, Color(1.0, 0.5, 0.1, 0.8)) # Orange
	gradient.add_point(0.7, Color(0.8, 0.2, 0.0, 0.4)) # Red-orange
	gradient.add_point(1.0, Color(0.5, 0.1, 0.0, 0.0)) # Dark red, transparent
	material.color_ramp = gradient
	
	return material

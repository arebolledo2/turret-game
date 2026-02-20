extends Node
class_name EnemyVisuals

## Handles enemy sprite visuals from EntityAssetConfig.

var enemy: CharacterBody2D = null
var sprite_node: Node = null # Sprite2D or AnimatedSprite2D
var is_animated: bool = false
var visual_config: AssetVisualConfig = null

var _base_sprite_scale: Vector2 = Vector2.ONE
var _base_sprite_position: Vector2 = Vector2.ZERO

var _textures: Dictionary = {}
var _last_direction_key: String = ""

var fire_particles: GPUParticles2D = null
var idle_tween: Tween = null


func initialize(p_enemy: CharacterBody2D, asset_config: EntityAssetConfig) -> void:
	enemy = p_enemy
	assert(enemy != null, "EnemyVisuals: enemy reference required")

	if enemy.has_node("AnimatedSprite2D"):
		sprite_node = enemy.get_node("AnimatedSprite2D")
		is_animated = true
	elif enemy.has_node("Sprite2D"):
		sprite_node = enemy.get_node("Sprite2D")
		is_animated = false

	if sprite_node:
		_base_sprite_scale = sprite_node.scale
		_base_sprite_position = sprite_node.position

	apply_asset_config(asset_config)


func apply_asset_config(asset_config: EntityAssetConfig) -> void:
	if asset_config == null or asset_config.visual == null:
		return

	visual_config = asset_config.visual
	_load_visual_resources()
	_apply_visual_base_state()

	if visual_config.idle_bounce_enabled and not is_animated:
		_start_idle_bounce()
	else:
		_stop_idle_bounce()


func update_direction_sprite(direction: Vector2) -> void:
	if not sprite_node or visual_config == null or direction.length() == 0:
		return

	match visual_config.orientation_mode:
		AssetVisualConfig.OrientationMode.FIXED:
			pass
		AssetVisualConfig.OrientationMode.FLIP_X_BY_VELOCITY:
			if sprite_node is Sprite2D:
				var sprite: Sprite2D = sprite_node
				if direction.x < 0:
					sprite.flip_h = true
				elif direction.x > 0:
					sprite.flip_h = false
		AssetVisualConfig.OrientationMode.TEXTURE_LEFT_RIGHT:
			_apply_left_right_sprite(direction)
		AssetVisualConfig.OrientationMode.TEXTURE_8_DIR:
			_apply_8dir_sprite(direction)
		AssetVisualConfig.OrientationMode.ANIMATED_LEFT_RIGHT:
			_apply_left_right_animation(direction)


func apply_damage_flash() -> void:
	if not sprite_node:
		return

	var target_color := _get_visual_modulate()
	sprite_node.modulate = Color.WHITE
	var tween = enemy.create_tween()
	tween.tween_property(sprite_node, "modulate", target_color, 0.1)


func update_status_visual(active_effects: Dictionary) -> void:
	if not sprite_node:
		return

	var base_color := _get_visual_modulate()
	if active_effects.is_empty():
		sprite_node.modulate = base_color
		_clear_fire_particles()
		return

	var final_color := base_color

	if active_effects.has(GameEnums.DamageType.FIRE):
		final_color = final_color.lerp(Color(1.0, 0.5, 0.2, 1.0), 0.4)
		_show_fire_particles()

	if active_effects.has(GameEnums.DamageType.ELECTRIC):
		final_color = final_color.lerp(Color(0.5, 0.8, 1.0, 1.0), 0.4)

	if active_effects.has(GameEnums.DamageType.PLASMA):
		final_color = final_color.lerp(Color(0.8, 0.4, 1.0, 1.0), 0.4)

	sprite_node.modulate = final_color

	if not active_effects.has(GameEnums.DamageType.FIRE):
		_clear_fire_particles()


func play_death_animation(callback: Callable) -> void:
	if not sprite_node:
		callback.call()
		return

	_clear_fire_particles()
	_stop_idle_bounce()

	var tween = enemy.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite_node, "scale", Vector2.ZERO, 0.15)
	tween.tween_property(sprite_node, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(callback)


func _load_visual_resources() -> void:
	_textures.clear()
	for key in visual_config.texture_paths.keys():
		var path = visual_config.texture_paths[key]
		if path is String and ResourceLoader.exists(path):
			_textures[key] = load(path)

	if is_animated and visual_config.sprite_frames_path != "" and sprite_node is AnimatedSprite2D and ResourceLoader.exists(visual_config.sprite_frames_path):
		var sprite_frames = load(visual_config.sprite_frames_path)
		if sprite_frames is SpriteFrames:
			var animated: AnimatedSprite2D = sprite_node
			animated.sprite_frames = sprite_frames


func _apply_visual_base_state() -> void:
	if not sprite_node:
		return

	sprite_node.position = _base_sprite_position + visual_config.position_offset
	sprite_node.scale = Vector2(_base_sprite_scale.x * visual_config.scale.x, _base_sprite_scale.y * visual_config.scale.y)
	sprite_node.modulate = visual_config.modulate

	if sprite_node is Sprite2D:
		var sprite: Sprite2D = sprite_node
		if visual_config.anchor_bottom and sprite.texture:
			sprite.offset = Vector2(0, -sprite.texture.get_height() / 2.0)
		else:
			sprite.offset = Vector2.ZERO

	if is_animated and sprite_node is AnimatedSprite2D:
		var animated: AnimatedSprite2D = sprite_node
		var speed_scale := 1.0
		if visual_config.animation_speed_fps > 0.0:
			speed_scale = visual_config.animation_speed_fps / 12.0
		animated.speed_scale = speed_scale
		_apply_left_right_animation(Vector2.RIGHT)
	else:
		match visual_config.orientation_mode:
			AssetVisualConfig.OrientationMode.TEXTURE_LEFT_RIGHT:
				_apply_left_right_sprite(Vector2.RIGHT)
			AssetVisualConfig.OrientationMode.TEXTURE_8_DIR:
				_apply_8dir_sprite(Vector2.DOWN)
			_:
				var tex: Texture2D = _textures.get("default", null)
				if tex and sprite_node is Sprite2D:
					(sprite_node as Sprite2D).texture = tex


func _apply_left_right_sprite(direction: Vector2) -> void:
	if not (sprite_node is Sprite2D):
		return

	var key := "right" if direction.x >= 0 else "left"
	var tex: Texture2D = _textures.get(key, null)
	if tex:
		var sprite: Sprite2D = sprite_node
		sprite.texture = tex
		_last_direction_key = key


func _apply_8dir_sprite(direction: Vector2) -> void:
	if not (sprite_node is Sprite2D):
		return

	var key := _direction_key_from_vector(direction)
	var tex: Texture2D = _textures.get(key, null)
	if tex:
		var sprite: Sprite2D = sprite_node
		sprite.texture = tex
		_last_direction_key = key


func _apply_left_right_animation(direction: Vector2) -> void:
	if not (sprite_node is AnimatedSprite2D):
		return

	var side_key := "right" if direction.x >= 0 else "left"
	var animation_name := str(visual_config.animation_map.get(side_key, ""))
	if animation_name.is_empty():
		animation_name = "move_right" if side_key == "right" else "move_left"

	var animated: AnimatedSprite2D = sprite_node
	if animated.sprite_frames and animated.sprite_frames.has_animation(animation_name):
		animated.play(animation_name)
		_last_direction_key = side_key


func _direction_key_from_vector(direction: Vector2) -> String:
	var angle := direction.angle()
	if angle < 0:
		angle += TAU
	var segment := int((angle + PI / 8.0) / (PI / 4.0)) % 8

	match segment:
		0:
			return "east"
		1:
			return "north_east"
		2:
			return "north"
		3:
			return "north_west"
		4:
			return "west"
		5:
			return "south_west"
		6:
			return "south"
		7:
			return "south_east"
	return "south"


func _get_visual_modulate() -> Color:
	if visual_config:
		return visual_config.modulate
	return Color.WHITE


func _show_fire_particles() -> void:
	if fire_particles != null:
		return

	fire_particles = GPUParticles2D.new()
	fire_particles.emitting = true
	fire_particles.amount = 20
	fire_particles.lifetime = 0.8
	fire_particles.process_material = _create_fire_particle_material()
	fire_particles.position = Vector2.ZERO
	enemy.add_child(fire_particles)


func _clear_fire_particles() -> void:
	if fire_particles != null:
		fire_particles.queue_free()
		fire_particles = null


func _create_fire_particle_material() -> ParticleProcessMaterial:
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 15.0
	material.direction = Vector3(0, -1, 0)
	material.spread = 0.5
	material.initial_velocity_min = 20.0
	material.initial_velocity_max = 40.0
	material.gravity = Vector3(0, -30.0, 0)
	material.scale_min = 0.3
	material.scale_max = 0.6

	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.8, 0.3, 1.0))
	gradient.add_point(0.3, Color(1.0, 0.5, 0.1, 0.8))
	gradient.add_point(0.7, Color(0.8, 0.2, 0.0, 0.4))
	gradient.add_point(1.0, Color(0.5, 0.1, 0.0, 0.0))
	material.color_ramp = gradient
	return material


func _start_idle_bounce() -> void:
	if not sprite_node:
		return

	_stop_idle_bounce()

	var min_scale := clampf(visual_config.idle_bounce_min_y_scale, 0.1, 1.0)
	var cycle := maxf(0.05, visual_config.idle_bounce_cycle_seconds)
	var half_cycle := cycle

	var base_scale: Vector2 = sprite_node.scale
	var scale_x: float = base_scale.x
	var scale_y_down: float = base_scale.y * min_scale
	var scale_y_up: float = base_scale.y

	idle_tween = enemy.create_tween()
	idle_tween.set_loops()
	idle_tween.set_ease(Tween.EASE_IN_OUT)
	idle_tween.set_trans(Tween.TRANS_SINE)

	if randf() > 0.5:
		idle_tween.tween_property(sprite_node, "scale", Vector2(scale_x, scale_y_down), half_cycle)
		idle_tween.tween_property(sprite_node, "scale", Vector2(scale_x, scale_y_up), half_cycle)
	else:
		idle_tween.tween_property(sprite_node, "scale", Vector2(scale_x, scale_y_up), half_cycle)
		idle_tween.tween_property(sprite_node, "scale", Vector2(scale_x, scale_y_down), half_cycle)


func _stop_idle_bounce() -> void:
	if idle_tween and idle_tween.is_valid():
		idle_tween.kill()
	idle_tween = null

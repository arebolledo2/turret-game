extends Node
class_name EnemyVisuals

## Handles enemy sprite visuals from EntityAssetConfig.

var enemy: CharacterBody2D = null
var sprite_node: Node = null # Sprite2D or AnimatedSprite2D
var is_animated: bool = false
var visual_config: AssetVisualConfig = null

var _base_sprite_scale: Vector2 = Vector2.ONE
var _base_sprite_position: Vector2 = Vector2.ZERO
var _base_visual_scale: Vector2 = Vector2.ONE

var _textures: Dictionary = {}
var _last_direction_key: String = ""

var fire_particles: GPUParticles2D = null
var idle_tween: Tween = null
var damage_flash_tween: Tween = null
var impact_tween: Tween = null


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


func apply_damage_flash(is_crit: bool = false) -> void:
	if not sprite_node:
		return

	if damage_flash_tween and damage_flash_tween.is_valid():
		damage_flash_tween.kill()

	var target_color := _get_visual_modulate()
	sprite_node.modulate = Color.WHITE
	damage_flash_tween = enemy.create_tween()
	damage_flash_tween.tween_property(sprite_node, "modulate", target_color, 0.08 if is_crit else 0.1)

	_play_hit_reaction(is_crit)
	_spawn_hit_burst(is_crit)


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
	if damage_flash_tween and damage_flash_tween.is_valid():
		damage_flash_tween.kill()
	if impact_tween and impact_tween.is_valid():
		impact_tween.kill()

	var tween = enemy.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(sprite_node, "scale", _base_visual_scale * 1.18, 0.04)
	tween.parallel().tween_property(sprite_node, "modulate", Color.WHITE, 0.04)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(sprite_node, "scale", Vector2.ZERO, 0.12)
	tween.parallel().tween_property(sprite_node, "modulate:a", 0.0, 0.12)
	tween.tween_callback(callback)


func play_explosion_animation(radius: float) -> void:
	"""Show a world-space burst for explosive enemies before they disappear."""
	var parent := _get_effect_parent()
	if parent == null or enemy == null:
		return

	var effect_radius := maxf(radius, 24.0)
	var ring := Line2D.new()
	ring.points = _create_circle_points(effect_radius, 32)
	ring.width = maxf(3.0, effect_radius * 0.035)
	ring.default_color = Color(1.0, 0.45, 0.08, 0.9)
	ring.z_index = 10
	ring.scale = Vector2.ONE * 0.2
	parent.add_child(ring)
	ring.global_position = enemy.global_position

	var ring_tween := ring.create_tween()
	ring_tween.set_ease(Tween.EASE_OUT)
	ring_tween.set_trans(Tween.TRANS_QUAD)
	ring_tween.tween_property(ring, "scale", Vector2.ONE, 0.22)
	ring_tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.22)
	ring_tween.tween_callback(ring.queue_free)

	var core := Polygon2D.new()
	core.polygon = _create_circle_points(effect_radius * 0.22, 24)
	core.color = Color(1.0, 0.85, 0.35, 0.65)
	core.z_index = 9
	core.scale = Vector2.ONE * 0.2
	parent.add_child(core)
	core.global_position = enemy.global_position

	var core_tween := core.create_tween()
	core_tween.set_ease(Tween.EASE_OUT)
	core_tween.set_trans(Tween.TRANS_QUAD)
	core_tween.tween_property(core, "scale", Vector2.ONE * 1.4, 0.1)
	core_tween.parallel().tween_property(core, "modulate:a", 0.0, 0.1)
	core_tween.tween_callback(core.queue_free)


func _play_hit_reaction(is_crit: bool) -> void:
	if not sprite_node:
		return

	var idle_was_active := idle_tween != null and idle_tween.is_valid()
	if idle_was_active:
		idle_tween.pause()

	if impact_tween and impact_tween.is_valid():
		impact_tween.kill()

	var punch_scale := _base_visual_scale * Vector2(1.16, 0.86) if is_crit else _base_visual_scale * Vector2(1.09, 0.92)
	var duration := 0.14 if is_crit else 0.1
	impact_tween = enemy.create_tween()
	impact_tween.set_ease(Tween.EASE_OUT)
	impact_tween.set_trans(Tween.TRANS_QUAD)
	impact_tween.tween_property(sprite_node, "scale", punch_scale, 0.035)
	impact_tween.set_ease(Tween.EASE_IN)
	impact_tween.tween_property(sprite_node, "scale", _base_visual_scale, duration)
	if idle_was_active:
		impact_tween.tween_callback(_resume_idle_bounce)


func _resume_idle_bounce() -> void:
	if idle_tween and idle_tween.is_valid():
		idle_tween.play()


func _spawn_hit_burst(is_crit: bool) -> void:
	var parent := _get_effect_parent()
	if parent == null or enemy == null:
		return

	var radius := 13.0 if is_crit else 8.0
	var ring := Line2D.new()
	ring.points = _create_circle_points(radius, 16)
	ring.width = 2.8 if is_crit else 1.6
	ring.default_color = Color(1.0, 0.85, 0.25, 0.95) if is_crit else Color(1.0, 1.0, 1.0, 0.8)
	ring.z_index = 8
	ring.scale = Vector2.ONE * 0.35
	parent.add_child(ring)
	ring.global_position = enemy.global_position

	var duration := 0.18 if is_crit else 0.12
	var tween := ring.create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ring, "scale", Vector2.ONE * (1.2 if is_crit else 1.0), duration)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, duration)
	tween.tween_callback(ring.queue_free)


func _get_effect_parent() -> Node:
	if enemy == null or not is_instance_valid(enemy):
		return null

	var tree := enemy.get_tree()
	if tree == null:
		return null
	return tree.current_scene if tree.current_scene else tree.root


func _create_circle_points(radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments + 1):
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points


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
	_base_visual_scale = sprite_node.scale
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

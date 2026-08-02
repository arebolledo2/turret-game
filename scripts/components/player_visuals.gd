extends Node
class_name PlayerVisuals

## Handles player sprite visuals from AssetConfigService data.
## PlayerMovement owns movement/facing state; this component applies visual policy.

var player: CharacterBody2D = null
var movement: PlayerMovement = null
var sprite: Sprite2D = null
var animated_sprite: AnimatedSprite2D = null
var visual_config: AssetVisualConfig = null
var _is_animated: bool = false

var _base_scale: Vector2 = Vector2.ONE
var _base_position: Vector2 = Vector2.ZERO
var _base_visual_position: Vector2 = Vector2.ZERO
var _base_modulate: Color = Color.WHITE
var _base_visual_scale: Vector2 = Vector2.ONE
var _textures: Dictionary = {}
var damage_reaction_tween: Tween = null
var _animation_phase: float = 0.0
var _visual_bob: float = 0.0
var _visual_rotation: float = 0.0


func initialize(p_player: CharacterBody2D, p_movement: PlayerMovement, p_sprite: Sprite2D) -> void:
	player = p_player
	movement = p_movement
	sprite = p_sprite
	animated_sprite = player.get_node_or_null("AnimatedSprite2D")

	assert(player != null, "PlayerVisuals: player reference required")
	assert(movement != null, "PlayerVisuals: movement reference required")
	assert(sprite != null, "PlayerVisuals: sprite reference required")

	_base_scale = sprite.scale
	_base_position = sprite.position
	_base_modulate = sprite.modulate

	if not Events.asset_preset_changed.is_connected(_on_asset_preset_changed):
		Events.asset_preset_changed.connect(_on_asset_preset_changed)
	if not Events.asset_config_changed.is_connected(_on_asset_config_changed):
		Events.asset_config_changed.connect(_on_asset_config_changed)

	apply_asset_config(AssetConfigService.get_player_config())


func process(delta: float) -> void:
	if not sprite or visual_config == null:
		return

	_update_movement_animation(delta)

	match visual_config.orientation_mode:
		AssetVisualConfig.OrientationMode.FIXED:
			pass
		AssetVisualConfig.OrientationMode.FLIP_X_BY_VELOCITY:
			_apply_flip_x_orientation()
		AssetVisualConfig.OrientationMode.TEXTURE_LEFT_RIGHT:
			_apply_left_right_orientation()
		AssetVisualConfig.OrientationMode.TEXTURE_8_DIR:
			_apply_8dir_orientation()
		AssetVisualConfig.OrientationMode.ANIMATED_LEFT_RIGHT:
			_apply_left_right_orientation()


func _update_movement_animation(delta: float) -> void:
	if not movement:
		return
	if FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
		_visual_bob = 0.0
		_visual_rotation = 0.0
		var reduced_visual := get_visual_node()
		if reduced_visual:
			reduced_visual.position = _base_visual_position
			reduced_visual.rotation = 0.0
		return

	var speed_limit := maxf(movement.effective_speed, 1.0)
	var speed_ratio := clampf(movement.velocity.length() / speed_limit, 0.0, 1.0)
	var is_moving := speed_ratio > GameConstants.PLAYER_MOVEMENT_DEADZONE
	var bob_frequency := GameConstants.PLAYER_MOVEMENT_BOB_FREQUENCY if is_moving else GameConstants.PLAYER_IDLE_BOB_FREQUENCY
	var bob_amplitude := lerpf(GameConstants.PLAYER_IDLE_BOB_AMPLITUDE, GameConstants.PLAYER_MOVEMENT_BOB_AMPLITUDE, speed_ratio)

	# Asset presets can disable idle motion while retaining the movement bob.
	if not is_moving and not visual_config.idle_bounce_enabled:
		bob_amplitude = 0.0

	_animation_phase = fmod(_animation_phase + delta * bob_frequency, TAU)
	var target_bob := sin(_animation_phase) * bob_amplitude
	_visual_bob = lerpf(_visual_bob, target_bob, clampf(delta * 14.0, 0.0, 1.0))

	var horizontal_ratio := clampf(movement.velocity.x / speed_limit, -1.0, 1.0)
	var target_rotation := deg_to_rad(GameConstants.PLAYER_MOVEMENT_LEAN_DEGREES) * horizontal_ratio
	_visual_rotation = lerpf(_visual_rotation, target_rotation, clampf(delta * 12.0, 0.0, 1.0))

	var visual_node := get_visual_node()
	if visual_node:
		visual_node.position = _base_visual_position + Vector2(0.0, -_visual_bob)
		visual_node.rotation = _visual_rotation


func apply_asset_config(asset_config: EntityAssetConfig) -> void:
	if asset_config == null or asset_config.visual == null:
		return

	visual_config = asset_config.visual
	_ensure_renderer_for_config()
	_load_textures()
	_load_sprite_frames()

	if not _is_animated:
		if visual_config.texture_paths.has("default"):
			var tex: Texture2D = _textures.get("default", null)
			if tex:
				sprite.texture = tex
		elif visual_config.texture_paths.has("left"):
			var left_tex: Texture2D = _textures.get("left", null)
			if left_tex:
				sprite.texture = left_tex
		elif visual_config.texture_paths.has("right"):
			var right_tex: Texture2D = _textures.get("right", null)
			if right_tex:
				sprite.texture = right_tex

	_apply_base_visuals()
	process(0.0)


func get_base_modulate() -> Color:
	return _base_modulate


func get_visual_node() -> Node2D:
	if _is_animated and animated_sprite:
		return animated_sprite
	return sprite


func play_damage_reaction(is_crit: bool = false) -> void:
	"""Give the player a short squash-and-recover reaction when hit."""
	var visual_node := get_visual_node()
	if not visual_node or FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION):
		return

	if damage_reaction_tween and damage_reaction_tween.is_valid():
		damage_reaction_tween.kill()

	var punch_scale := _base_visual_scale * Vector2(1.14, 0.86) if is_crit else _base_visual_scale * Vector2(1.08, 0.92)
	damage_reaction_tween = player.create_tween()
	damage_reaction_tween.set_ease(Tween.EASE_OUT)
	damage_reaction_tween.set_trans(Tween.TRANS_QUAD)
	damage_reaction_tween.tween_property(visual_node, "scale", punch_scale, 0.04)
	damage_reaction_tween.set_ease(Tween.EASE_IN)
	damage_reaction_tween.tween_property(visual_node, "scale", _base_visual_scale, 0.12 if is_crit else 0.1)


func _load_textures() -> void:
	_textures.clear()
	for key in visual_config.texture_paths.keys():
		var path = visual_config.texture_paths[key]
		if path is String and ResourceLoader.exists(path):
			_textures[key] = load(path)


func _load_sprite_frames() -> void:
	if not _is_animated or not animated_sprite or visual_config.sprite_frames_path.is_empty():
		return
	if not ResourceLoader.exists(visual_config.sprite_frames_path):
		return
	var frames = load(visual_config.sprite_frames_path)
	if frames is SpriteFrames:
		animated_sprite.sprite_frames = frames


func _apply_base_visuals() -> void:
	var visual_node := get_visual_node()
	if not visual_node:
		return

	visual_node.scale = Vector2(_base_scale.x * visual_config.scale.x, _base_scale.y * visual_config.scale.y)
	_base_visual_scale = visual_node.scale
	_base_visual_position = _base_position + visual_config.position_offset
	visual_node.position = _base_visual_position
	visual_node.rotation = 0.0
	_animation_phase = 0.0
	_visual_bob = 0.0
	_visual_rotation = 0.0
	_base_modulate = visual_config.modulate
	visual_node.modulate = _base_modulate
	if visual_node is Sprite2D:
		(visual_node as Sprite2D).flip_h = false
	if visual_node is AnimatedSprite2D:
		var animated := visual_node as AnimatedSprite2D
		if visual_config.animation_speed_fps > 0.0:
			animated.speed_scale = visual_config.animation_speed_fps / 12.0
		if visual_config.orientation_mode == AssetVisualConfig.OrientationMode.ANIMATED_LEFT_RIGHT:
			_play_left_right_animation(Vector2.RIGHT)
		else:
			_play_default_animation()


func _ensure_renderer_for_config() -> void:
	var wants_animation := visual_config.sprite_kind == AssetVisualConfig.SpriteKind.ANIMATED \
		or visual_config.orientation_mode == AssetVisualConfig.OrientationMode.ANIMATED_LEFT_RIGHT
	if wants_animation and animated_sprite == null:
		animated_sprite = AnimatedSprite2D.new()
		animated_sprite.name = "AnimatedSprite2D_Runtime"
		animated_sprite.position = _base_position
		animated_sprite.scale = _base_scale
		player.add_child(animated_sprite)

	var has_frames_path := not visual_config.sprite_frames_path.is_empty() and ResourceLoader.exists(visual_config.sprite_frames_path)
	var has_existing_frames := animated_sprite != null and animated_sprite.sprite_frames != null and not animated_sprite.sprite_frames.get_animation_names().is_empty()
	_is_animated = wants_animation and animated_sprite != null and (has_frames_path or has_existing_frames)
	if sprite:
		sprite.visible = not _is_animated
	if animated_sprite:
		animated_sprite.visible = _is_animated


func _apply_flip_x_orientation() -> void:
	if not movement:
		return

	var facing := movement.get_facing_direction()
	var visual_node := get_visual_node()
	if not visual_node:
		return
	if facing in [2, 3, 1]:
		if visual_node is Sprite2D:
			(visual_node as Sprite2D).flip_h = true
		elif visual_node is AnimatedSprite2D:
			(visual_node as AnimatedSprite2D).flip_h = true
	elif facing in [6, 5, 7]:
		if visual_node is Sprite2D:
			(visual_node as Sprite2D).flip_h = false
		elif visual_node is AnimatedSprite2D:
			(visual_node as AnimatedSprite2D).flip_h = false


func _apply_left_right_orientation() -> void:
	if not movement:
		return
	if _is_animated:
		_play_left_right_animation(Vector2.LEFT if movement.get_facing_direction() in [2, 3, 1] else Vector2.RIGHT)
		return

	var facing := movement.get_facing_direction()
	if facing in [2, 3, 1]:
		var left_tex: Texture2D = _textures.get("left", null)
		if left_tex:
			sprite.texture = left_tex
	elif facing in [6, 5, 7]:
		var right_tex: Texture2D = _textures.get("right", null)
		if right_tex:
			sprite.texture = right_tex


func _play_left_right_animation(direction: Vector2) -> void:
	if not _is_animated or not animated_sprite or animated_sprite.sprite_frames == null:
		return
	var side_key := "right" if direction.x >= 0.0 else "left"
	var animation_name := str(visual_config.animation_map.get(side_key, ""))
	if animation_name.is_empty():
		animation_name = "move_right" if side_key == "right" else "move_left"
	if animated_sprite.sprite_frames.has_animation(animation_name):
		animated_sprite.play(animation_name)


func _play_default_animation() -> void:
	if not _is_animated or not animated_sprite or animated_sprite.sprite_frames == null:
		return
	var animation_name := str(visual_config.animation_map.get("default", ""))
	if animation_name.is_empty() or not animated_sprite.sprite_frames.has_animation(animation_name):
		var animation_names := animated_sprite.sprite_frames.get_animation_names()
		if animation_names.is_empty():
			return
		animation_name = animation_names[0]
	animated_sprite.play(animation_name)


func _apply_8dir_orientation() -> void:
	if not movement:
		return

	var direction := movement.get_facing_direction()
	var key := "south"

	match direction:
		0:
			key = "south"
		1:
			key = "south_west"
		2:
			key = "west"
		3:
			key = "north_west"
		4:
			key = "north"
		5:
			key = "north_east"
		6:
			key = "east"
		7:
			key = "south_east"

	var tex: Texture2D = _textures.get(key, null)
	if tex and not _is_animated:
		sprite.texture = tex


func _on_asset_preset_changed(_preset_name: String) -> void:
	apply_asset_config(AssetConfigService.get_player_config())


func _on_asset_config_changed(entity_kind: int, asset_id: String) -> void:
	if entity_kind == EntityAssetConfig.EntityKind.PLAYER and asset_id == "main":
		apply_asset_config(AssetConfigService.get_player_config())

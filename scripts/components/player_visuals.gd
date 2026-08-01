extends Node
class_name PlayerVisuals

## Handles player sprite visuals from AssetConfigService data.
## PlayerMovement owns movement/facing state; this component applies visual policy.

var player: CharacterBody2D = null
var movement: PlayerMovement = null
var sprite: Sprite2D = null
var visual_config: AssetVisualConfig = null

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

	sprite.position = _base_visual_position + Vector2(0.0, -_visual_bob)
	sprite.rotation = _visual_rotation


func apply_asset_config(asset_config: EntityAssetConfig) -> void:
	if asset_config == null or asset_config.visual == null:
		return

	visual_config = asset_config.visual
	_load_textures()

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


func play_damage_reaction(is_crit: bool = false) -> void:
	"""Give the player a short squash-and-recover reaction when hit."""
	if not sprite:
		return

	if damage_reaction_tween and damage_reaction_tween.is_valid():
		damage_reaction_tween.kill()

	var punch_scale := _base_visual_scale * Vector2(1.14, 0.86) if is_crit else _base_visual_scale * Vector2(1.08, 0.92)
	damage_reaction_tween = player.create_tween()
	damage_reaction_tween.set_ease(Tween.EASE_OUT)
	damage_reaction_tween.set_trans(Tween.TRANS_QUAD)
	damage_reaction_tween.tween_property(sprite, "scale", punch_scale, 0.04)
	damage_reaction_tween.set_ease(Tween.EASE_IN)
	damage_reaction_tween.tween_property(sprite, "scale", _base_visual_scale, 0.12 if is_crit else 0.1)


func _load_textures() -> void:
	_textures.clear()
	for key in visual_config.texture_paths.keys():
		var path = visual_config.texture_paths[key]
		if path is String and ResourceLoader.exists(path):
			_textures[key] = load(path)


func _apply_base_visuals() -> void:
	if not sprite:
		return

	sprite.scale = Vector2(_base_scale.x * visual_config.scale.x, _base_scale.y * visual_config.scale.y)
	_base_visual_scale = sprite.scale
	_base_visual_position = _base_position + visual_config.position_offset
	sprite.position = _base_visual_position
	sprite.rotation = 0.0
	_animation_phase = 0.0
	_visual_bob = 0.0
	_visual_rotation = 0.0
	_base_modulate = visual_config.modulate
	sprite.modulate = _base_modulate
	sprite.flip_h = false


func _apply_flip_x_orientation() -> void:
	if not movement:
		return

	var facing := movement.get_facing_direction()
	if facing in [2, 3, 1]:
		sprite.flip_h = true
	elif facing in [6, 5, 7]:
		sprite.flip_h = false


func _apply_left_right_orientation() -> void:
	if not movement:
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
	if tex:
		sprite.texture = tex


func _on_asset_preset_changed(_preset_name: String) -> void:
	apply_asset_config(AssetConfigService.get_player_config())


func _on_asset_config_changed(entity_kind: int, asset_id: String) -> void:
	if entity_kind == EntityAssetConfig.EntityKind.PLAYER and asset_id == "main":
		apply_asset_config(AssetConfigService.get_player_config())

extends Control
class_name AssetStudioPreview

const CollisionProfileClass = preload("res://scripts/components/collision_profile.gd")

@onready var info_label: Label = $InfoLabel

var _entity_kind: int = EntityAssetConfig.EntityKind.ENEMY
var _asset_id: String = ""
var _config: EntityAssetConfig = null
var _collision_profile: CollisionProfileClass = null
var _time: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func set_preview_config(entity_kind: int, asset_id: String, config: EntityAssetConfig) -> void:
	_entity_kind = entity_kind
	_asset_id = asset_id
	_config = config
	_collision_profile = null
	if _config and _config.collision and _config.collision.enabled:
		var profile_path := _config.collision.collision_profile_path
		if not profile_path.is_empty() and _is_collision_profile_path_valid(profile_path):
			var loaded = ResourceLoader.load(profile_path)
			if loaded is CollisionProfileClass:
				_collision_profile = loaded
	_update_info_label()
	queue_redraw()


func _is_collision_profile_path_valid(path: String) -> bool:
	if path.begins_with("user://"):
		return FileAccess.file_exists(path)
	return ResourceLoader.exists(path)


func _update_info_label() -> void:
	if info_label == null:
		return

	var kind_name := "Enemy"
	match _entity_kind:
		EntityAssetConfig.EntityKind.TURRET:
			kind_name = "Turret"
		EntityAssetConfig.EntityKind.PLAYER:
			kind_name = "Player"

	if _config == null or _config.visual == null:
		info_label.text = "%s: %s\nNo preview data" % [kind_name, _asset_id]
		return

	info_label.text = "%s: %s\nSprite=%d  Orientation=%d" % [
		kind_name,
		_asset_id,
		_config.visual.sprite_kind,
		_config.visual.orientation_mode,
	]


func _draw() -> void:
	var bg_rect := Rect2(Vector2.ZERO, size)
	draw_rect(bg_rect, Color(0.08, 0.09, 0.11, 1.0), true)

	var checker_size := 20.0
	var rows := int(size.y / checker_size) + 1
	var cols := int(size.x / checker_size) + 1
	for y in range(rows):
		for x in range(cols):
			if int((x + y) % 2) == 0:
				continue
			var rect := Rect2(Vector2(x * checker_size, y * checker_size), Vector2(checker_size, checker_size))
			draw_rect(rect, Color(0.12, 0.13, 0.16, 1.0), true)

	var center := Vector2(size.x * 0.5, size.y * 0.55)
	draw_line(Vector2(center.x - 80.0, center.y), Vector2(center.x + 80.0, center.y), Color(0.3, 0.3, 0.35, 1.0), 1.0)
	draw_line(Vector2(center.x, center.y - 80.0), Vector2(center.x, center.y + 80.0), Color(0.3, 0.3, 0.35, 1.0), 1.0)

	_draw_entity_sprite(center)
	_draw_collision_preview(center)


func _draw_entity_sprite(center: Vector2) -> void:
	if _config == null or _config.visual == null:
		return

	var visual := _config.visual
	var texture_path := _resolve_preview_texture_path(visual)
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return

	var texture := ResourceLoader.load(texture_path) as Texture2D
	if texture == null:
		return

	var base_size := texture.get_size()
	if base_size.x <= 0.0 or base_size.y <= 0.0:
		return

	var display_scale := 0.35
	var final_scale := Vector2(visual.scale.x, visual.scale.y) * display_scale
	var draw_size := Vector2(base_size.x * final_scale.x, base_size.y * final_scale.y)
	var pos := center + visual.position_offset - (draw_size * 0.5)
	draw_texture_rect(texture, Rect2(pos, draw_size), false, visual.modulate)


func _resolve_preview_texture_path(visual: AssetVisualConfig) -> String:
	var tex := visual.texture_paths
	match visual.orientation_mode:
		AssetVisualConfig.OrientationMode.FIXED, AssetVisualConfig.OrientationMode.FLIP_X_BY_VELOCITY:
			return _first_existing_path([str(tex.get("default", "")), str(tex.get("right", "")), str(tex.get("left", ""))])
		AssetVisualConfig.OrientationMode.TEXTURE_LEFT_RIGHT, AssetVisualConfig.OrientationMode.ANIMATED_LEFT_RIGHT:
			var side := "right" if sin(_time * 2.0) >= 0.0 else "left"
			return _first_existing_path([str(tex.get(side, "")), str(tex.get("default", "")), str(tex.get("right", "")), str(tex.get("left", ""))])
		AssetVisualConfig.OrientationMode.TEXTURE_8_DIR:
			var keys := ["north", "north_east", "east", "south_east", "south", "south_west", "west", "north_west"]
			var idx := int(absf(sin(_time * 1.3)) * 7.0)
			var primary := str(tex.get(keys[idx], ""))
			return _first_existing_path([primary, str(tex.get("south", "")), str(tex.get("default", ""))])
	return _first_existing_path([str(tex.get("default", ""))])


func _first_existing_path(candidates: Array[String]) -> String:
	for p in candidates:
		if p.is_empty():
			continue
		if ResourceLoader.exists(p):
			return p
	return ""


func _draw_collision_preview(center: Vector2) -> void:
	if _collision_profile == null:
		return

	_draw_profile_shape(center, _collision_profile.hurtbox_shape_type, _collision_profile.hurtbox_size, Color(1.0, 0.55, 0.2, 0.2), Color(1.0, 0.55, 0.2, 0.8))
	_draw_profile_shape(center, _collision_profile.physics_shape_type, _collision_profile.physics_size, Color(0.85, 0.9, 1.0, 0.15), Color(0.85, 0.9, 1.0, 0.9))


func _draw_profile_shape(center: Vector2, shape_type: int, shape_size: Vector2, fill_color: Color, line_color: Color) -> void:
	var scale := 1.8
	match shape_type:
		CollisionProfile.ShapeType.CIRCLE:
			var radius := maxf(1.0, shape_size.x * scale)
			draw_circle(center, radius, fill_color)
			draw_arc(center, radius, 0.0, TAU, 48, line_color, 2.0)
		CollisionProfile.ShapeType.RECTANGLE:
			var size_px := Vector2(maxf(2.0, shape_size.x * scale), maxf(2.0, shape_size.y * scale))
			var rect := Rect2(center - (size_px * 0.5), size_px)
			draw_rect(rect, fill_color, true)
			draw_rect(rect, line_color, false, 2.0)
		CollisionProfile.ShapeType.CAPSULE:
			_draw_capsule(center, shape_size, scale, fill_color, line_color)


func _draw_capsule(center: Vector2, capsule_size: Vector2, scale: float, fill_color: Color, line_color: Color) -> void:
	var length := maxf(2.0, capsule_size.x * scale)
	var thickness := maxf(2.0, capsule_size.y * scale)
	var radius := thickness * 0.5
	var body_length := maxf(0.0, length - (radius * 2.0))

	var left_center := center + Vector2(-body_length * 0.5, 0.0)
	var right_center := center + Vector2(body_length * 0.5, 0.0)
	var body_rect := Rect2(
		Vector2(center.x - body_length * 0.5, center.y - radius),
		Vector2(body_length, thickness)
	)
	draw_rect(body_rect, fill_color, true)
	draw_rect(body_rect, line_color, false, 2.0)
	draw_circle(left_center, radius, fill_color)
	draw_arc(left_center, radius, 0.0, TAU, 24, line_color, 2.0)
	draw_circle(right_center, radius, fill_color)
	draw_arc(right_center, radius, 0.0, TAU, 24, line_color, 2.0)

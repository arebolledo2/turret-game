class_name AssetConfigResolver
extends RefCounted

## Merges copies, preserving immutable built-in resources and override dictionaries.
const CollisionProfileClass = preload("res://scripts/components/collision_profile.gd")
const EntityAssetConfigClass = preload("res://scripts/resources/assets/entity_asset_config.gd")
const KIND_ENEMY = "enemy"
const KIND_TURRET = "turret"
const KIND_PLAYER = "player"

var validator: AssetConfigValidator = AssetConfigValidator.new()

func resolve(base: EntityAssetConfig, patch: Dictionary) -> EntityAssetConfig:
	if base == null:
		return null
	var resolved := base.duplicate(true) as EntityAssetConfig
	_apply_patch(resolved, patch)
	validator._validate_resolved_config(resolved, base)
	return resolved

func _apply_patch(config: EntityAssetConfig, patch: Dictionary) -> void:
	for key in patch.keys():
		var value = patch[key]
		if key is String and key.find(".") >= 0:
			_apply_patch_path(config, key.split("."), value)
			continue

		if key == "visual" and value is Dictionary:
			_apply_visual_patch(config, value)
		elif key == "collision" and value is Dictionary:
			_apply_collision_patch(config, value)
		elif key == "display_name":
			config.display_name = str(value)
		elif key == "asset_id":
			config.asset_id = str(value)


func _apply_collision_profile_patch(profile: CollisionProfileClass, patch: Dictionary) -> void:
	for key in patch.keys():
		var normalized_key := str(key)
		if normalized_key.find(".") >= 0:
			var split := normalized_key.split(".")
			if split.size() > 0:
				normalized_key = str(split[split.size() - 1])
		var value = patch[key]

		match normalized_key:
			"physics_shape_type":
				profile.physics_shape_type = int(value)
			"physics_size":
				profile.physics_size = _coerce_vector2(value, profile.physics_size)
			"hurtbox_shape_type":
				profile.hurtbox_shape_type = int(value)
			"hurtbox_size":
				profile.hurtbox_size = _coerce_vector2(value, profile.hurtbox_size)
			"deals_contact_damage":
				profile.deals_contact_damage = bool(value)
			"damage_cooldown":
				profile.damage_cooldown = float(value)


func _coerce_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


func _apply_patch_path(config: EntityAssetConfig, path: Array, value: Variant) -> void:
	if path.is_empty():
		return

	match path[0]:
		"visual":
			_apply_visual_patch_path(config, path.slice(1), value)
		"collision":
			_apply_collision_patch_path(config, path.slice(1), value)
		"display_name":
			config.display_name = str(value)
		"asset_id":
			config.asset_id = str(value)


func _apply_visual_patch(config: EntityAssetConfig, patch: Dictionary) -> void:
	for key in patch.keys():
		var value = patch[key]
		if key is String and key.find(".") >= 0:
			_apply_visual_patch_path(config, key.split("."), value)
		else:
			_apply_visual_patch_path(config, [str(key)], value)


func _apply_visual_patch_path(config: EntityAssetConfig, path: Array, value: Variant) -> void:
	if config.visual == null:
		return
	if path.is_empty():
		return

	var field: String = str(path[0])
	match field:
		"sprite_kind":
			config.visual.sprite_kind = int(value)
		"orientation_mode":
			config.visual.orientation_mode = int(value)
		"texture_paths":
			if path.size() == 1 and value is Dictionary:
				config.visual.texture_paths = value.duplicate(true)
			elif path.size() > 1:
				config.visual.texture_paths[path[1]] = value
		"sprite_frames_path":
			config.visual.sprite_frames_path = str(value)
		"animation_map":
			if path.size() == 1 and value is Dictionary:
				config.visual.animation_map = value.duplicate(true)
			elif path.size() > 1:
				config.visual.animation_map[path[1]] = value
		"animation_speed_fps":
			config.visual.animation_speed_fps = float(value)
		"scale":
			if value is Vector2:
				config.visual.scale = value
		"modulate":
			if value is Color:
				config.visual.modulate = value
		"position_offset":
			if value is Vector2:
				config.visual.position_offset = value
		"anchor_bottom":
			config.visual.anchor_bottom = bool(value)
		"idle_bounce_enabled":
			config.visual.idle_bounce_enabled = bool(value)
		"idle_bounce_min_y_scale":
			config.visual.idle_bounce_min_y_scale = float(value)
		"idle_bounce_cycle_seconds":
			config.visual.idle_bounce_cycle_seconds = float(value)


func _apply_collision_patch(config: EntityAssetConfig, patch: Dictionary) -> void:
	for key in patch.keys():
		var value = patch[key]
		if key is String and key.find(".") >= 0:
			_apply_collision_patch_path(config, key.split("."), value)
		else:
			_apply_collision_patch_path(config, [str(key)], value)


func _apply_collision_patch_path(config: EntityAssetConfig, path: Array, value: Variant) -> void:
	if config.collision == null:
		return
	if path.is_empty():
		return

	match path[0]:
		"enabled":
			config.collision.enabled = bool(value)
		"collision_profile_path":
			config.collision.collision_profile_path = str(value)
		"live_apply":
			config.collision.live_apply = bool(value)



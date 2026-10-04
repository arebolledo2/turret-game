class_name AssetConfigValidator
extends RefCounted

const CollisionProfileClass = preload("res://scripts/components/collision_profile.gd")
const EntityAssetConfigClass = preload("res://scripts/resources/assets/entity_asset_config.gd")
const KIND_ENEMY = "enemy"
const KIND_TURRET = "turret"
const KIND_PLAYER = "player"

func _validate_resolved_config(resolved: EntityAssetConfig, base_cfg: EntityAssetConfig) -> void:
	if resolved == null or base_cfg == null:
		return

	_validate_visual_config(resolved, base_cfg)
	_validate_collision_config(resolved, base_cfg)


func _validate_visual_config(resolved: EntityAssetConfig, base_cfg: EntityAssetConfig) -> void:
	if resolved.visual == null:
		resolved.visual = base_cfg.visual.duplicate(true)
		return
	if base_cfg.visual == null:
		return

	var cleaned_textures := resolved.visual.texture_paths.duplicate(true)
	for key in cleaned_textures.keys():
		var value: Variant = cleaned_textures[key]
		if value is String and not _is_valid_asset_path(value):
			var fallback: Variant = base_cfg.visual.texture_paths.get(key, "")
			DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Invalid texture path '%s' for %s:%s. Using fallback." % [value, _kind_to_key(resolved.entity_kind), resolved.asset_id])
			if fallback is String and _is_valid_asset_path(fallback):
				cleaned_textures[key] = fallback
			else:
				cleaned_textures.erase(key)
	resolved.visual.texture_paths = cleaned_textures

	if not resolved.visual.sprite_frames_path.is_empty() and not _is_valid_asset_path(resolved.visual.sprite_frames_path):
		var fallback_frames := base_cfg.visual.sprite_frames_path
		if _is_valid_asset_path(fallback_frames):
			resolved.visual.sprite_frames_path = fallback_frames
		else:
			DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Invalid sprite_frames_path '%s' for %s:%s" % [resolved.visual.sprite_frames_path, _kind_to_key(resolved.entity_kind), resolved.asset_id])
			resolved.visual.sprite_frames_path = ""


func _validate_collision_config(resolved: EntityAssetConfig, base_cfg: EntityAssetConfig) -> void:
	if resolved.collision == null:
		resolved.collision = base_cfg.collision.duplicate(true)
		return
	if base_cfg.collision == null:
		return

	if not resolved.collision.enabled:
		return

	var path := resolved.collision.collision_profile_path
	if _is_valid_collision_profile(path):
		return

	var fallback_path := base_cfg.collision.collision_profile_path
	if _is_valid_collision_profile(fallback_path):
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Invalid collision profile '%s' for %s:%s. Using fallback." % [path, _kind_to_key(resolved.entity_kind), resolved.asset_id])
		resolved.collision.collision_profile_path = fallback_path
		return

	DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Invalid collision profile '%s' with no fallback for %s:%s. Disabling collision override." % [path, _kind_to_key(resolved.entity_kind), resolved.asset_id])
	resolved.collision.enabled = false
	resolved.collision.collision_profile_path = ""


func _is_valid_collision_profile(path: String) -> bool:
	if path.is_empty():
		return false
	if path.begins_with("user://"):
		if not FileAccess.file_exists(path):
			return false
	elif not ResourceLoader.exists(path):
		return false
	var res: Resource = ResourceLoader.load(path)
	return res is CollisionProfileClass


func _is_valid_asset_path(path: String) -> bool:
	if path.is_empty():
		return false
	if not path.begins_with("res://assets/"):
		return false
	return ResourceLoader.exists(path)


func _kind_to_key(entity_kind: int) -> String:
	match entity_kind:
		EntityAssetConfigClass.EntityKind.ENEMY:
			return KIND_ENEMY
		EntityAssetConfigClass.EntityKind.TURRET:
			return KIND_TURRET
		EntityAssetConfigClass.EntityKind.PLAYER:
			return KIND_PLAYER
	return ""



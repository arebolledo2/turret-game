extends Node

const CollisionProfileClass = preload("res://scripts/components/collision_profile.gd")
const EntityAssetConfigClass = preload("res://scripts/resources/assets/entity_asset_config.gd")

const BUILTIN_PRESET_DIR: String = "res://resources/asset_presets"
const USER_PRESET_DIR: String = "user://asset_presets"
const USER_PRESET_SUFFIX: String = ".cfg"

const KIND_ENEMY: String = "enemy"
const KIND_TURRET: String = "turret"
const KIND_PLAYER: String = "player"

var _active_preset: String = "default"

# preset_name -> {enemy:{id:EntityAssetConfig}, turret:{id:EntityAssetConfig}, player:{id:EntityAssetConfig}}
var _builtin_presets: Dictionary = {}

# user preset name -> base built-in preset name
var _user_preset_bases: Dictionary = {}

# user preset name -> section_name -> patch dictionary
var _user_overrides: Dictionary = {}


func _ready() -> void:
	reload_all()


func reload_all() -> void:
	_load_builtin_presets()
	_load_user_presets()

	if not _preset_exists(_active_preset):
		_active_preset = "default"


func reset_state() -> void:
	_active_preset = "default"
	reload_all()


func get_enemy_config(type_id: String) -> EntityAssetConfig:
	return _get_resolved_config(EntityAssetConfigClass.EntityKind.ENEMY, type_id)


func get_turret_config(type_id: String) -> EntityAssetConfig:
	return _get_resolved_config(EntityAssetConfigClass.EntityKind.TURRET, type_id)


func get_player_config() -> EntityAssetConfig:
	return _get_resolved_config(EntityAssetConfigClass.EntityKind.PLAYER, "main")


func list_presets() -> Array[String]:
	var all: Array[String] = []

	for key in _builtin_presets.keys():
		all.append(str(key))

	for key in _user_preset_bases.keys():
		var k := str(key)
		if k not in all:
			all.append(k)

	all.sort()
	return all


func set_active_preset(name: String) -> void:
	var target := name.strip_edges()
	if target.is_empty():
		target = "default"
	if not _preset_exists(target):
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Unknown preset '%s', falling back to default" % target)
		target = "default"

	if _active_preset == target:
		return

	_active_preset = target
	Events.asset_preset_changed.emit(_active_preset)


func get_active_preset() -> String:
	return _active_preset


func upsert_override(entity_kind: int, asset_id: String, patch: Dictionary) -> void:
	if patch.is_empty():
		return

	var preset_name := _active_preset
	if preset_name in _builtin_presets and not preset_name in _user_preset_bases:
		_ensure_user_preset_state(preset_name, preset_name)

	var section := _section_name(entity_kind, asset_id)
	if section.is_empty():
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Invalid override section for kind=%s id=%s" % [entity_kind, asset_id])
		return

	if not _user_overrides.has(preset_name):
		_user_overrides[preset_name] = {}

	var existing: Dictionary = _user_overrides[preset_name].get(section, {}).duplicate(true)
	for key in patch.keys():
		existing[key] = patch[key]
	_user_overrides[preset_name][section] = existing

	_save_user_preset(preset_name)
	Events.asset_config_changed.emit(entity_kind, asset_id)


func clear_override(entity_kind: int, asset_id: String) -> void:
	var preset_name := _active_preset
	if not _user_overrides.has(preset_name):
		return

	var section := _section_name(entity_kind, asset_id)
	if section.is_empty():
		return

	if _user_overrides[preset_name].has(section):
		_user_overrides[preset_name].erase(section)
		_save_user_preset(preset_name)
		Events.asset_config_changed.emit(entity_kind, asset_id)


func create_user_preset(name: String, clone_from: String = "default") -> void:
	var preset_name := name.strip_edges()
	if preset_name.is_empty():
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Cannot create user preset with empty name")
		return

	if preset_name.find(":") >= 0:
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Preset names cannot contain ':'")
		return

	if _preset_exists(preset_name):
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Preset '%s' already exists" % preset_name)
		return

	var base_name := clone_from
	if not _builtin_presets.has(base_name):
		base_name = "default"

	_ensure_user_preset_state(preset_name, base_name)
	_save_user_preset(preset_name)
	reload_all()


func delete_user_preset(name: String) -> void:
	if _builtin_presets.has(name):
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Cannot delete built-in preset '%s'" % name)
		return

	var user_path := _user_preset_path(name)
	if FileAccess.file_exists(user_path):
		var abs := ProjectSettings.globalize_path(user_path)
		var err := DirAccess.remove_absolute(abs)
		if err != OK:
			DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Failed deleting preset file '%s' (err=%s)" % [abs, err])

	_user_preset_bases.erase(name)
	_user_overrides.erase(name)

	if _active_preset == name:
		set_active_preset("default")

	reload_all()


func _get_resolved_config(entity_kind: int, asset_id: String) -> EntityAssetConfig:
	var base_cfg := _resolve_base_config(entity_kind, asset_id)
	if base_cfg == null:
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Missing base config for kind=%s id=%s" % [entity_kind, asset_id])
		return null

	var resolved := base_cfg.duplicate(true) as EntityAssetConfig
	if resolved == null:
		return null

	var patch := _get_active_override_patch(entity_kind, asset_id)
	if not patch.is_empty():
		_apply_patch(resolved, patch)

	_validate_resolved_config(resolved, base_cfg)
	return resolved


func _resolve_base_config(entity_kind: int, asset_id: String) -> EntityAssetConfig:
	var kind_key := _kind_to_key(entity_kind)
	if kind_key.is_empty():
		return null

	var active_builtin := _get_builtin_for_active_preset()
	var default_builtin: Dictionary = _builtin_presets.get("default", {})

	var active_map: Dictionary = active_builtin.get(kind_key, {})
	if active_map.has(asset_id):
		return active_map[asset_id]

	var default_map: Dictionary = default_builtin.get(kind_key, {})
	if default_map.has(asset_id):
		return default_map[asset_id]

	# fallback to first known config for the kind
	for cfg in default_map.values():
		return cfg
	return null


func _get_builtin_for_active_preset() -> Dictionary:
	if _builtin_presets.has(_active_preset):
		return _builtin_presets[_active_preset]

	var base_name: String = str(_user_preset_bases.get(_active_preset, "default"))
	return _builtin_presets.get(base_name, _builtin_presets.get("default", {}))


func _get_active_override_patch(entity_kind: int, asset_id: String) -> Dictionary:
	if not _user_overrides.has(_active_preset):
		return {}

	var section := _section_name(entity_kind, asset_id)
	if section.is_empty():
		return {}

	return _user_overrides[_active_preset].get(section, {}).duplicate(true)


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
		var value = cleaned_textures[key]
		if value is String and not _is_valid_asset_path(value):
			var fallback = base_cfg.visual.texture_paths.get(key, "")
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
	if not ResourceLoader.exists(path):
		return false
	var res = load(path)
	return res is CollisionProfileClass


func _is_valid_asset_path(path: String) -> bool:
	if path.is_empty():
		return false
	if not path.begins_with("res://assets/"):
		return false
	return ResourceLoader.exists(path)


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


func _load_builtin_presets() -> void:
	_builtin_presets.clear()

	var root := DirAccess.open(BUILTIN_PRESET_DIR)
	if root == null:
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Missing built-in preset directory: %s" % BUILTIN_PRESET_DIR)
		return

	root.list_dir_begin()
	var entry := root.get_next()
	while not entry.is_empty():
		if root.current_is_dir() and not entry.begins_with("."):
			_builtin_presets[entry] = _load_builtin_preset(entry)
		entry = root.get_next()
	root.list_dir_end()


func _load_builtin_preset(preset_name: String) -> Dictionary:
	var preset := {
		KIND_ENEMY: {},
		KIND_TURRET: {},
		KIND_PLAYER: {},
	}

	_load_kind_resources(preset_name, "enemies", KIND_ENEMY, preset)
	_load_kind_resources(preset_name, "turrets", KIND_TURRET, preset)
	_load_kind_resources(preset_name, "player", KIND_PLAYER, preset)
	return preset


func _load_kind_resources(preset_name: String, folder_name: String, kind_key: String, out_preset: Dictionary) -> void:
	var dir_path := "%s/%s/%s" % [BUILTIN_PRESET_DIR, preset_name, folder_name]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			var full_path := "%s/%s/%s/%s" % [BUILTIN_PRESET_DIR, preset_name, folder_name, entry]
			var res = load(full_path)
			if res is EntityAssetConfigClass:
				var cfg: EntityAssetConfig = res
				if cfg.asset_id.is_empty():
					cfg.asset_id = entry.trim_suffix(".tres")
				out_preset[kind_key][cfg.asset_id] = cfg
		entry = dir.get_next()
	dir.list_dir_end()


func _load_user_presets() -> void:
	_user_preset_bases.clear()
	_user_overrides.clear()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_PRESET_DIR))
	var dir := DirAccess.open(USER_PRESET_DIR)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.ends_with(USER_PRESET_SUFFIX):
			var preset_name := entry.trim_suffix(USER_PRESET_SUFFIX)
			_load_user_preset_file(preset_name)
		entry = dir.get_next()
	dir.list_dir_end()


func _load_user_preset_file(preset_name: String) -> void:
	var cfg := ConfigFile.new()
	var path := _user_preset_path(preset_name)
	var err := cfg.load(path)
	if err != OK:
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Failed to load user preset '%s' (%s)" % [preset_name, err])
		return

	var base_name := str(cfg.get_value("meta", "base_preset", "default"))
	_user_preset_bases[preset_name] = base_name

	var overrides_for_preset := {}
	for section in cfg.get_sections():
		if section == "meta":
			continue
		var patch := {}
		for key in cfg.get_section_keys(section):
			patch[key] = cfg.get_value(section, key)
		overrides_for_preset[section] = patch
	_user_overrides[preset_name] = overrides_for_preset


func _save_user_preset(preset_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_PRESET_DIR))

	var cfg := ConfigFile.new()
	var base_name := str(_user_preset_bases.get(preset_name, "default"))
	cfg.set_value("meta", "base_preset", base_name)

	var sections: Dictionary = _user_overrides.get(preset_name, {})
	for section in sections.keys():
		var patch: Dictionary = sections[section]
		for key in patch.keys():
			cfg.set_value(section, str(key), patch[key])

	var path := _user_preset_path(preset_name)
	var err := cfg.save(path)
	if err != OK:
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Failed saving user preset '%s' (%s)" % [preset_name, err])


func _ensure_user_preset_state(preset_name: String, base_name: String) -> void:
	if not _user_preset_bases.has(preset_name):
		_user_preset_bases[preset_name] = base_name
	if not _user_overrides.has(preset_name):
		_user_overrides[preset_name] = {}


func _user_preset_path(preset_name: String) -> String:
	return "%s/%s%s" % [USER_PRESET_DIR, preset_name, USER_PRESET_SUFFIX]


func _preset_exists(name: String) -> bool:
	return _builtin_presets.has(name) or _user_preset_bases.has(name)


func _kind_to_key(entity_kind: int) -> String:
	match entity_kind:
		EntityAssetConfigClass.EntityKind.ENEMY:
			return KIND_ENEMY
		EntityAssetConfigClass.EntityKind.TURRET:
			return KIND_TURRET
		EntityAssetConfigClass.EntityKind.PLAYER:
			return KIND_PLAYER
	return ""


func _section_name(entity_kind: int, asset_id: String) -> String:
	var kind_key := _kind_to_key(entity_kind)
	if kind_key.is_empty():
		return ""
	return "%s:%s" % [kind_key, asset_id]

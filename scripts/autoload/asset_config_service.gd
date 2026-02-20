extends Node

const CollisionProfileClass = preload("res://scripts/components/collision_profile.gd")
const EntityAssetConfigClass = preload("res://scripts/resources/assets/entity_asset_config.gd")

const BUILTIN_PRESET_DIR: String = "res://resources/asset_presets"
const USER_PRESET_DIR: String = "user://asset_presets"
const USER_PRESET_SUFFIX: String = ".cfg"
const ACTIVE_PRESET_STATE_FILE: String = "user://asset_presets/state.cfg"
const ACTIVE_PRESET_STATE_SECTION: String = "meta"
const ACTIVE_PRESET_STATE_KEY: String = "active_preset"
const USER_COLLISION_PROFILE_DIR: String = "user://collision_profiles"

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
	_load_active_preset_state()

	if not _preset_exists(_active_preset):
		_active_preset = "default"
	_save_active_preset_state()


func reset_state() -> void:
	_active_preset = "default"
	reload_all()


func get_enemy_config(type_id: String) -> EntityAssetConfig:
	return _get_resolved_config(EntityAssetConfigClass.EntityKind.ENEMY, type_id)


func get_turret_config(type_id: String) -> EntityAssetConfig:
	return _get_resolved_config(EntityAssetConfigClass.EntityKind.TURRET, type_id)


func get_player_config() -> EntityAssetConfig:
	return _get_resolved_config(EntityAssetConfigClass.EntityKind.PLAYER, "main")


func get_asset_config(entity_kind: int, asset_id: String) -> EntityAssetConfig:
	return _get_resolved_config(entity_kind, asset_id)


func list_asset_ids(entity_kind: int) -> Array[String]:
	var ids: Array[String] = []

	match entity_kind:
		EntityAssetConfigClass.EntityKind.ENEMY:
			var enemy_ids = EnemyRegistry.get_all_type_ids()
			for id in enemy_ids:
				_append_unique_string(ids, str(id))
		EntityAssetConfigClass.EntityKind.TURRET:
			var turret_ids = TurretRegistry.get_all_type_ids()
			for id in turret_ids:
				_append_unique_string(ids, str(id))
		EntityAssetConfigClass.EntityKind.PLAYER:
			_append_unique_string(ids, "main")

	_append_asset_ids_from_presets(entity_kind, ids)
	_append_asset_ids_from_active_overrides(entity_kind, ids)
	ids.sort()
	return ids


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


func get_preset_origin(name: String) -> String:
	if _builtin_presets.has(name):
		return "builtin"
	if _user_preset_bases.has(name):
		return "user"
	return ""


func get_user_preset_base(name: String) -> String:
	return str(_user_preset_bases.get(name, "default"))


func list_collision_profiles(include_user: bool = true) -> Array[String]:
	var profile_paths: Array[String] = []
	_collect_collision_profiles("res://resources/collision_profiles", profile_paths)
	if include_user:
		_collect_collision_profiles(USER_COLLISION_PROFILE_DIR, profile_paths)
	profile_paths.sort()
	return profile_paths


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
	_save_active_preset_state()
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


func upsert_collision_profile_override(entity_kind: int, asset_id: String, profile_patch: Dictionary) -> String:
	if profile_patch.is_empty():
		return ""

	var clean_asset_id := asset_id.strip_edges()
	if clean_asset_id.is_empty():
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Cannot patch collision profile with empty asset_id")
		return ""

	var kind_key := _kind_to_key(entity_kind)
	if kind_key.is_empty():
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Cannot patch collision profile for unknown entity kind %s" % entity_kind)
		return ""

	var current_config := _get_resolved_config(entity_kind, clean_asset_id)
	var profile_path := ""
	if current_config and current_config.collision:
		profile_path = current_config.collision.collision_profile_path

	var base_profile := _load_collision_profile(profile_path)
	var editable_profile: CollisionProfileClass = null
	if base_profile:
		editable_profile = base_profile.duplicate(true)
	if editable_profile == null:
		editable_profile = CollisionProfileClass.new()

	_apply_collision_profile_patch(editable_profile, profile_patch)
	if not editable_profile.validate():
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Rejected invalid collision profile patch for %s:%s" % [kind_key, clean_asset_id])
		return ""

	var preset_name := _active_preset
	if preset_name in _builtin_presets and not preset_name in _user_preset_bases:
		_ensure_user_preset_state(preset_name, preset_name)

	var target_profile_path := _user_collision_profile_path(preset_name, kind_key, clean_asset_id)
	var abs_dir := ProjectSettings.globalize_path(target_profile_path.get_base_dir())
	DirAccess.make_dir_recursive_absolute(abs_dir)

	var save_err := ResourceSaver.save(editable_profile, target_profile_path)
	if save_err != OK:
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Failed saving collision profile '%s' (err=%s)" % [target_profile_path, save_err])
		return ""

	upsert_override(entity_kind, clean_asset_id, {
		"collision.enabled": true,
		"collision.collision_profile_path": target_profile_path,
		"collision.live_apply": true,
	})

	return target_profile_path


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

	var collision_dir := "%s/%s" % [USER_COLLISION_PROFILE_DIR, name]
	_delete_directory_recursive(collision_dir)

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
	if path.begins_with("user://"):
		if not FileAccess.file_exists(path):
			return false
	elif not ResourceLoader.exists(path):
		return false
	var res = ResourceLoader.load(path)
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


func _load_active_preset_state() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(ACTIVE_PRESET_STATE_FILE)
	if err != OK:
		return
	var saved := str(cfg.get_value(ACTIVE_PRESET_STATE_SECTION, ACTIVE_PRESET_STATE_KEY, _active_preset)).strip_edges()
	if not saved.is_empty():
		_active_preset = saved


func _save_active_preset_state() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_PRESET_DIR))
	var cfg := ConfigFile.new()
	cfg.set_value(ACTIVE_PRESET_STATE_SECTION, ACTIVE_PRESET_STATE_KEY, _active_preset)
	var err := cfg.save(ACTIVE_PRESET_STATE_FILE)
	if err != OK:
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Failed saving active preset state (%s)" % err)


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


func _user_collision_profile_path(preset_name: String, kind_key: String, asset_id: String) -> String:
	var file_name := "%s_%s.tres" % [kind_key, _sanitize_file_component(asset_id)]
	return "%s/%s/%s" % [USER_COLLISION_PROFILE_DIR, preset_name, file_name]


func _preset_exists(name: String) -> bool:
	return _builtin_presets.has(name) or _user_preset_bases.has(name)


func _append_unique_string(target: Array[String], value: String) -> void:
	if value.is_empty():
		return
	if value not in target:
		target.append(value)


func _append_asset_ids_from_presets(entity_kind: int, out_ids: Array[String]) -> void:
	var kind_key := _kind_to_key(entity_kind)
	if kind_key.is_empty():
		return

	var active_builtin := _get_builtin_for_active_preset()
	var default_builtin: Dictionary = _builtin_presets.get("default", {})

	var active_map: Dictionary = active_builtin.get(kind_key, {})
	for id in active_map.keys():
		_append_unique_string(out_ids, str(id))

	var default_map: Dictionary = default_builtin.get(kind_key, {})
	for id in default_map.keys():
		_append_unique_string(out_ids, str(id))


func _append_asset_ids_from_active_overrides(entity_kind: int, out_ids: Array[String]) -> void:
	if not _user_overrides.has(_active_preset):
		return
	var kind_key := _kind_to_key(entity_kind)
	if kind_key.is_empty():
		return
	var prefix := "%s:" % kind_key
	for section_name in _user_overrides[_active_preset].keys():
		var section := str(section_name)
		if section.begins_with(prefix):
			var id := section.trim_prefix(prefix)
			_append_unique_string(out_ids, id)


func _collect_collision_profiles(dir_path: String, out_paths: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = dir.get_next()
			continue

		var full_path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			_collect_collision_profiles(full_path, out_paths)
		elif entry.ends_with(".tres"):
			_append_unique_string(out_paths, full_path)
		entry = dir.get_next()
	dir.list_dir_end()


func _load_collision_profile(path: String) -> CollisionProfileClass:
	if path.is_empty():
		return null
	if not _is_valid_collision_profile(path):
		return null
	var res = ResourceLoader.load(path)
	if res is CollisionProfileClass:
		return res
	return null


func _sanitize_file_component(value: String) -> String:
	var sanitized := value.strip_edges()
	if sanitized.is_empty():
		return "asset"
	sanitized = sanitized.replace("/", "_")
	sanitized = sanitized.replace("\\", "_")
	sanitized = sanitized.replace(":", "_")
	sanitized = sanitized.replace(".", "_")
	sanitized = sanitized.replace(" ", "_")
	return sanitized


func _delete_directory_recursive(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry.begins_with("."):
			entry = dir.get_next()
			continue
		var child_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			_delete_directory_recursive(child_path)
		else:
			var file_abs := ProjectSettings.globalize_path(child_path)
			var file_err := DirAccess.remove_absolute(file_abs)
			if file_err != OK:
				DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Failed deleting file '%s' (err=%s)" % [file_abs, file_err])
		entry = dir.get_next()
	dir.list_dir_end()

	var abs_dir := ProjectSettings.globalize_path(path)
	var err := DirAccess.remove_absolute(abs_dir)
	if err != OK:
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Failed deleting directory '%s' (err=%s)" % [abs_dir, err])


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

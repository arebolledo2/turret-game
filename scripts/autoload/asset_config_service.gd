extends Node

const CollisionProfileClass = preload("res://scripts/components/collision_profile.gd")
const EntityAssetConfigClass = preload("res://scripts/resources/assets/entity_asset_config.gd")

const BUILTIN_PRESET_DIR: String = "res://resources/asset_presets"
const USER_PRESET_SUFFIX: String = ".cfg"
const ACTIVE_PRESET_STATE_SECTION: String = "meta"
const ACTIVE_PRESET_STATE_KEY: String = "active_preset"

const KIND_ENEMY: String = "enemy"
const KIND_TURRET: String = "turret"
const KIND_PLAYER: String = "player"

var store: AssetPresetStore = AssetPresetStore.new()
var resolver: AssetConfigResolver = AssetConfigResolver.new()
var _active_preset: String:
	get: return store.active_preset
	set(value): store.active_preset = value
var _builtin_presets: Dictionary:
	get: return store.builtin_presets
var _user_preset_bases: Dictionary:
	get: return store.user_preset_bases
var _user_overrides: Dictionary:
	get: return store.user_overrides


## Call before adding a service instance to the tree for isolated persistence.
func configure_storage(storage_root: String) -> void:
	store = AssetPresetStore.new(storage_root)


func _ready() -> void:
	reload_all()


func reload_all() -> void:
	store.load_builtin_presets()
	store.load_user_presets()
	store.load_active_preset_state()

	if not _preset_exists(_active_preset):
		_active_preset = "default"
	store.save_active_preset_state()


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
			var enemy_ids: Array = EnemyRegistry.get_all_type_ids()
			for id in enemy_ids:
				_append_unique_string(ids, str(id))
		EntityAssetConfigClass.EntityKind.TURRET:
			var turret_ids: Array = TurretRegistry.get_all_type_ids()
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
		_collect_collision_profiles(store.user_collision_profile_dir, profile_paths)
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
	store.save_active_preset_state()
	Events.asset_preset_changed.emit(_active_preset)


func get_active_preset() -> String:
	return _active_preset


func upsert_override(entity_kind: int, asset_id: String, patch: Dictionary) -> void:
	if patch.is_empty():
		return

	var preset_name := _active_preset
	if preset_name in _builtin_presets and not preset_name in _user_preset_bases:
		store.ensure_user_preset_state(preset_name, preset_name)

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

	store.save_user_preset(preset_name)
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

	resolver._apply_collision_profile_patch(editable_profile, profile_patch)
	if not editable_profile.validate():
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Rejected invalid collision profile patch for %s:%s" % [kind_key, clean_asset_id])
		return ""

	var preset_name := _active_preset
	if preset_name in _builtin_presets and not preset_name in _user_preset_bases:
		store.ensure_user_preset_state(preset_name, preset_name)

	var target_profile_path := store.user_collision_profile_path(preset_name, kind_key, clean_asset_id)
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
		store.save_user_preset(preset_name)
		Events.asset_config_changed.emit(entity_kind, asset_id)


func create_user_preset(name: String, clone_from: String = "default") -> void:
	var preset_name := name.strip_edges()
	if preset_name.is_empty():
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Cannot create user preset with empty name")
		return

	if not AssetPresetStore.is_valid_name(preset_name):
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Invalid preset name")
		return

	if _preset_exists(preset_name):
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Preset '%s' already exists" % preset_name)
		return

	var base_name := clone_from
	if not _builtin_presets.has(base_name):
		base_name = "default"

	store.ensure_user_preset_state(preset_name, base_name)
	store.save_user_preset(preset_name)
	reload_all()


func delete_user_preset(name: String) -> void:
	if not AssetPresetStore.is_valid_name(name):
		return
	if _builtin_presets.has(name):
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Cannot delete built-in preset '%s'" % name)
		return

	var user_path := store.user_preset_path(name)
	if FileAccess.file_exists(user_path):
		var abs := ProjectSettings.globalize_path(user_path)
		var err := DirAccess.remove_absolute(abs)
		if err != OK:
			DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Failed deleting preset file '%s' (err=%s)" % [abs, err])

	var collision_dir := "%s/%s" % [store.user_collision_profile_dir, name]
	store.delete_directory_recursive(collision_dir)

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

	return resolver.resolve(base_cfg, _get_active_override_patch(entity_kind, asset_id))


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
	if not resolver.validator._is_valid_collision_profile(path):
		return null
	var res: Resource = ResourceLoader.load(path)
	if res is CollisionProfileClass:
		return res
	return null


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

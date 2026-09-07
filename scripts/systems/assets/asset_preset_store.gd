class_name AssetPresetStore
extends RefCounted

## Owns preset files and loaded data. Inject a root before loading; no I/O in init.
const CollisionProfileClass = preload("res://scripts/components/collision_profile.gd")
const EntityAssetConfigClass = preload("res://scripts/resources/assets/entity_asset_config.gd")
const KIND_ENEMY = "enemy"
const KIND_TURRET = "turret"
const KIND_PLAYER = "player"
const BUILTIN_PRESET_DIR = "res://resources/asset_presets"
const USER_PRESET_SUFFIX = ".cfg"
const ACTIVE_PRESET_STATE_SECTION = "meta"
const ACTIVE_PRESET_STATE_KEY = "active_preset"
var user_preset_dir: String
var active_preset_state_file: String
var user_collision_profile_dir: String
var builtin_presets: Dictionary = {}
var user_preset_bases: Dictionary = {}
var user_overrides: Dictionary = {}
var active_preset: String = "default"

func _init(storage_root: String = "user://") -> void:
	user_preset_dir = storage_root.path_join("asset_presets")
	active_preset_state_file = user_preset_dir.path_join("state.cfg")
	user_collision_profile_dir = storage_root.path_join("collision_profiles")

static func is_valid_name(value: String) -> bool:
	return not value.is_empty() and value != "state" and not value.begins_with(".") and value == value.validate_filename() and not "/" in value and not "\\" in value

func load_builtin_presets() -> void:
	builtin_presets.clear()

	var root := DirAccess.open(BUILTIN_PRESET_DIR)
	if root == null:
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Missing built-in preset directory: %s" % BUILTIN_PRESET_DIR)
		return

	root.list_dir_begin()
	var entry := root.get_next()
	while not entry.is_empty():
		if root.current_is_dir() and not entry.begins_with("."):
			builtin_presets[entry] = load_builtin_preset(entry)
		entry = root.get_next()
	root.list_dir_end()


func load_builtin_preset(preset_name: String) -> Dictionary:
	var preset := {
		KIND_ENEMY: {},
		KIND_TURRET: {},
		KIND_PLAYER: {},
	}

	load_kind_resources(preset_name, "enemies", KIND_ENEMY, preset)
	load_kind_resources(preset_name, "turrets", KIND_TURRET, preset)
	load_kind_resources(preset_name, "player", KIND_PLAYER, preset)
	return preset


func load_kind_resources(preset_name: String, folder_name: String, kind_key: String, out_preset: Dictionary) -> void:
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


func load_user_presets() -> void:
	user_preset_bases.clear()
	user_overrides.clear()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(user_preset_dir))
	var dir := DirAccess.open(user_preset_dir)
	if dir == null:
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.ends_with(USER_PRESET_SUFFIX) and is_valid_name(entry.trim_suffix(USER_PRESET_SUFFIX)):
			var preset_name := entry.trim_suffix(USER_PRESET_SUFFIX)
			load_user_preset_file(preset_name)
		entry = dir.get_next()
	dir.list_dir_end()


func load_active_preset_state() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(active_preset_state_file)
	if err != OK:
		return
	var saved := str(cfg.get_value(ACTIVE_PRESET_STATE_SECTION, ACTIVE_PRESET_STATE_KEY, active_preset)).strip_edges()
	if not saved.is_empty():
		active_preset = saved


func save_active_preset_state() -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(user_preset_dir))
	var cfg := ConfigFile.new()
	cfg.set_value(ACTIVE_PRESET_STATE_SECTION, ACTIVE_PRESET_STATE_KEY, active_preset)
	var err := cfg.save(active_preset_state_file)
	if err != OK:
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Failed saving active preset state (%s)" % err)
	return err



func load_user_preset_file(preset_name: String) -> void:
	var cfg := ConfigFile.new()
	var path := user_preset_path(preset_name)
	var err := cfg.load(path)
	if err != OK:
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Failed to load user preset '%s' (%s)" % [preset_name, err])
		return

	var base_name := str(cfg.get_value("meta", "base_preset", "default"))
	user_preset_bases[preset_name] = base_name

	var overrides_for_preset := {}
	for section in cfg.get_sections():
		if section == "meta":
			continue
		var patch := {}
		for key in cfg.get_section_keys(section):
			patch[key] = cfg.get_value(section, key)
		overrides_for_preset[section] = patch
	user_overrides[preset_name] = overrides_for_preset


func save_user_preset(preset_name: String) -> Error:
	if not is_valid_name(preset_name):
		return ERR_INVALID_PARAMETER
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(user_preset_dir))

	var cfg := ConfigFile.new()
	var base_name := str(user_preset_bases.get(preset_name, "default"))
	cfg.set_value("meta", "base_preset", base_name)

	var sections: Dictionary = user_overrides.get(preset_name, {})
	for section in sections.keys():
		var patch: Dictionary = sections[section]
		for key in patch.keys():
			cfg.set_value(section, str(key), patch[key])

	var path := user_preset_path(preset_name)
	var err := cfg.save(path)
	if err != OK:
		DebugService.warn(DebugService.VALIDATION, "[AssetConfigService] Failed saving user preset '%s' (%s)" % [preset_name, err])
	return err



func ensure_user_preset_state(preset_name: String, base_name: String) -> void:
	if not user_preset_bases.has(preset_name):
		user_preset_bases[preset_name] = base_name
	if not user_overrides.has(preset_name):
		user_overrides[preset_name] = {}


func user_preset_path(preset_name: String) -> String:
	return "%s/%s%s" % [user_preset_dir, preset_name, USER_PRESET_SUFFIX]


func user_collision_profile_path(preset_name: String, kind_key: String, asset_id: String) -> String:
	var file_name := "%s_%s.tres" % [kind_key, sanitize_file_component(asset_id)]
	return "%s/%s/%s" % [user_collision_profile_dir, preset_name, file_name]


func sanitize_file_component(value: String) -> String:
	var sanitized := value.strip_edges()
	if sanitized.is_empty():
		return "asset"
	sanitized = sanitized.replace("/", "_")
	sanitized = sanitized.replace("\\", "_")
	sanitized = sanitized.replace(":", "_")
	sanitized = sanitized.replace(".", "_")
	sanitized = sanitized.replace(" ", "_")
	return sanitized


func delete_directory_recursive(path: String) -> void:
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
			delete_directory_recursive(child_path)
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



extends GutTest

const ServiceScript = preload("res://scripts/autoload/asset_config_service.gd")
var service: ServiceScript
var storage_root: String

var _created_presets: Array[String] = []



func after_each() -> void:
	for preset_name in _created_presets:
		service.delete_user_preset(preset_name)
	_created_presets.clear()
	_delete_file(service.store.active_preset_state_file)
	service.set_active_preset("default")
	service.reload_all()
	service.store.delete_directory_recursive(storage_root)



func _delete_file(path: String) -> void:
	if FileAccess.file_exists(path):
		var abs := ProjectSettings.globalize_path(path)
		DirAccess.remove_absolute(abs)


func test_list_presets_includes_default():
	var presets := service.list_presets()
	assert_has(presets, "default", "Default preset should always exist")


func test_get_enemy_config_returns_entity_asset_config():
	var config := service.get_enemy_config("basic")
	assert_not_null(config, "Should return config for basic enemy")
	assert_eq(config.asset_id, "basic")
	assert_eq(config.entity_kind, EntityAssetConfig.EntityKind.ENEMY)
	assert_not_null(config.visual, "Config should include visual data")
	assert_not_null(config.collision, "Config should include collision data")


func test_user_override_merge_precedence():
	var preset_name := "unit_override_precedence"
	_created_presets.append(preset_name)
	service.create_user_preset(preset_name, "default")
	service.set_active_preset(preset_name)

	var override_color := Color(0.22, 0.33, 0.44, 1.0)
	service.upsert_override(
		EntityAssetConfig.EntityKind.ENEMY,
		"basic",
		{"visual.modulate": override_color}
	)

	var config := service.get_enemy_config("basic")
	assert_eq(config.visual.modulate, override_color, "Override color should win over base config")

	service.set_active_preset("default")
	var default_config := service.get_enemy_config("basic")
	assert_ne(default_config.visual.modulate, override_color, "Default preset should remain unchanged")


func test_override_persists_after_reload():
	var preset_name := "unit_override_persist"
	_created_presets.append(preset_name)
	service.create_user_preset(preset_name, "default")
	service.set_active_preset(preset_name)

	var override_scale := Vector2(1.7, 1.8)
	service.upsert_override(
		EntityAssetConfig.EntityKind.TURRET,
		"normal",
		{"visual.scale": override_scale}
	)

	service.reload_all()
	service.set_active_preset(preset_name)
	var config := service.get_turret_config("normal")
	assert_eq(config.visual.scale, override_scale, "Override should persist to user preset file")


func test_create_select_delete_user_preset():
	var preset_name := "unit_preset_lifecycle"
	service.create_user_preset(preset_name, "default")

	var presets := service.list_presets()
	assert_has(presets, preset_name, "Created user preset should be listed")

	service.set_active_preset(preset_name)
	assert_eq(service.get_active_preset(), preset_name)

	service.delete_user_preset(preset_name)
	_created_presets.erase(preset_name)

	var updated_presets := service.list_presets()
	assert_does_not_have(updated_presets, preset_name, "Deleted preset should be removed")
	assert_eq(service.get_active_preset(), "default", "Active preset should fall back to default after delete")


func test_get_preset_origin_for_builtin_and_user():
	assert_eq(service.get_preset_origin("default"), "builtin")

	var preset_name := "unit_origin_user"
	_created_presets.append(preset_name)
	service.create_user_preset(preset_name, "default")
	assert_eq(service.get_preset_origin(preset_name), "user")


func test_active_preset_persists_after_reload():
	var preset_name := "unit_active_persist"
	_created_presets.append(preset_name)
	service.create_user_preset(preset_name, "default")
	service.set_active_preset(preset_name)

	service.reload_all()
	assert_eq(service.get_active_preset(), preset_name, "Active preset should persist via state file")


func test_invalid_saved_active_preset_falls_back_to_default():
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "active_preset", "nonexistent_preset")
	cfg.save(service.store.active_preset_state_file)

	service.reload_all()
	assert_eq(service.get_active_preset(), "default", "Invalid saved preset should fall back to default")


func test_upsert_collision_profile_override_creates_and_applies_user_profile():
	var preset_name := "unit_collision_override"
	_created_presets.append(preset_name)
	service.create_user_preset(preset_name, "default")
	service.set_active_preset(preset_name)

	var written_path := service.upsert_collision_profile_override(
		EntityAssetConfig.EntityKind.ENEMY,
		"basic",
		{
			"physics_shape_type": CollisionProfile.ShapeType.RECTANGLE,
			"physics_size": Vector2(20, 12),
			"hurtbox_shape_type": CollisionProfile.ShapeType.RECTANGLE,
			"hurtbox_size": Vector2(24, 16),
		}
	)

	assert_true(written_path.begins_with(service.store.user_collision_profile_dir.path_join(preset_name) + "/"), "Should write collision profile under preset-specific user directory")

	var config := service.get_enemy_config("basic")
	assert_eq(config.collision.collision_profile_path, written_path, "Enemy config should reference written user collision profile")


func before_each() -> void:
	TestHelpers.reset_all_services()
	storage_root = "user://asset_service_tests/%s" % Time.get_ticks_usec()
	service = ServiceScript.new()
	service.configure_storage(storage_root)
	add_child_autofree(service)

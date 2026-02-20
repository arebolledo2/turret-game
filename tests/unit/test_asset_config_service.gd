extends GutTest

var _created_presets: Array[String] = []


func after_each() -> void:
	for preset_name in _created_presets:
		AssetConfigService.delete_user_preset(preset_name)
	_created_presets.clear()
	AssetConfigService.set_active_preset("default")
	AssetConfigService.reload_all()


func test_list_presets_includes_default():
	var presets := AssetConfigService.list_presets()
	assert_has(presets, "default", "Default preset should always exist")


func test_get_enemy_config_returns_entity_asset_config():
	var config := AssetConfigService.get_enemy_config("basic")
	assert_not_null(config, "Should return config for basic enemy")
	assert_eq(config.asset_id, "basic")
	assert_eq(config.entity_kind, EntityAssetConfig.EntityKind.ENEMY)
	assert_not_null(config.visual, "Config should include visual data")
	assert_not_null(config.collision, "Config should include collision data")


func test_user_override_merge_precedence():
	var preset_name := "unit_override_precedence"
	_created_presets.append(preset_name)
	AssetConfigService.create_user_preset(preset_name, "default")
	AssetConfigService.set_active_preset(preset_name)

	var override_color := Color(0.22, 0.33, 0.44, 1.0)
	AssetConfigService.upsert_override(
		EntityAssetConfig.EntityKind.ENEMY,
		"basic",
		{"visual.modulate": override_color}
	)

	var config := AssetConfigService.get_enemy_config("basic")
	assert_eq(config.visual.modulate, override_color, "Override color should win over base config")

	AssetConfigService.set_active_preset("default")
	var default_config := AssetConfigService.get_enemy_config("basic")
	assert_ne(default_config.visual.modulate, override_color, "Default preset should remain unchanged")


func test_override_persists_after_reload():
	var preset_name := "unit_override_persist"
	_created_presets.append(preset_name)
	AssetConfigService.create_user_preset(preset_name, "default")
	AssetConfigService.set_active_preset(preset_name)

	var override_scale := Vector2(1.7, 1.8)
	AssetConfigService.upsert_override(
		EntityAssetConfig.EntityKind.TURRET,
		"normal",
		{"visual.scale": override_scale}
	)

	AssetConfigService.reload_all()
	AssetConfigService.set_active_preset(preset_name)
	var config := AssetConfigService.get_turret_config("normal")
	assert_eq(config.visual.scale, override_scale, "Override should persist to user preset file")


func test_create_select_delete_user_preset():
	var preset_name := "unit_preset_lifecycle"
	AssetConfigService.create_user_preset(preset_name, "default")

	var presets := AssetConfigService.list_presets()
	assert_has(presets, preset_name, "Created user preset should be listed")

	AssetConfigService.set_active_preset(preset_name)
	assert_eq(AssetConfigService.get_active_preset(), preset_name)

	AssetConfigService.delete_user_preset(preset_name)
	_created_presets.erase(preset_name)

	var updated_presets := AssetConfigService.list_presets()
	assert_does_not_have(updated_presets, preset_name, "Deleted preset should be removed")
	assert_eq(AssetConfigService.get_active_preset(), "default", "Active preset should fall back to default after delete")


extends GutTest

var _preset_name: String = "unit_validation_preset"


func before_each() -> void:
	AssetConfigService.delete_user_preset(_preset_name)
	AssetConfigService.create_user_preset(_preset_name, "default")
	AssetConfigService.set_active_preset(_preset_name)


func after_each() -> void:
	AssetConfigService.set_active_preset("default")
	AssetConfigService.delete_user_preset(_preset_name)
	AssetConfigService.reload_all()


func test_rejects_non_assets_texture_path():
	AssetConfigService.upsert_override(
		EntityAssetConfig.EntityKind.PLAYER,
		"main",
		{"visual.texture_paths.left": "res://scripts/player.gd"}
	)

	var config := AssetConfigService.get_player_config()
	var left_path := str(config.visual.texture_paths.get("left", ""))
	assert_true(left_path.begins_with("res://assets/"), "Invalid texture path should be replaced by fallback asset path")


func test_rejects_invalid_collision_profile_path():
	AssetConfigService.upsert_override(
		EntityAssetConfig.EntityKind.ENEMY,
		"basic",
		{"collision.collision_profile_path": "res://resources/ui_theme.tres"}
	)

	var config := AssetConfigService.get_enemy_config("basic")
	assert_eq(config.collision.collision_profile_path, "res://resources/collision_profiles/spider_enemy.tres",
		"Invalid collision profile should fall back to base profile")


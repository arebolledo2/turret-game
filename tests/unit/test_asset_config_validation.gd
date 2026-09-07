extends GutTest

var _preset_name: String = "unit_validation_preset"


func before_each() -> void:
	TestHelpers.reset_all_services()
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


func test_rejects_invalid_collision_profile_patch_and_preserves_previous():
	var valid_path := AssetConfigService.upsert_collision_profile_override(
		EntityAssetConfig.EntityKind.ENEMY,
		"basic",
		{
			"physics_shape_type": CollisionProfile.ShapeType.CIRCLE,
			"physics_size": Vector2(10, 10),
			"hurtbox_shape_type": CollisionProfile.ShapeType.CIRCLE,
			"hurtbox_size": Vector2(14, 14),
		}
	)
	assert_false(valid_path.is_empty(), "Valid profile patch should write user collision profile")

	var rejected_path := AssetConfigService.upsert_collision_profile_override(
		EntityAssetConfig.EntityKind.ENEMY,
		"basic",
		{
			"physics_shape_type": CollisionProfile.ShapeType.RECTANGLE,
			"physics_size": Vector2(80, 80),
			"hurtbox_shape_type": CollisionProfile.ShapeType.RECTANGLE,
			"hurtbox_size": Vector2(8, 8),
		}
	)
	assert_eq(rejected_path, "", "Invalid profile patch should be rejected")

	var config := AssetConfigService.get_enemy_config("basic")
	assert_eq(config.collision.collision_profile_path, valid_path,
		"Rejected patch should preserve last valid collision profile path")

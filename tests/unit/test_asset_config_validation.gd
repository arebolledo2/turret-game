extends GutTest

const ServiceScript = preload("res://scripts/autoload/asset_config_service.gd")
var service: ServiceScript
var storage_root: String

var _preset_name: String = "unit_validation_preset"


func before_each() -> void:
	TestHelpers.reset_all_services()
	storage_root = "user://asset_service_tests/%s" % Time.get_ticks_usec()
	service = ServiceScript.new()
	service.configure_storage(storage_root)
	add_child_autofree(service)
	service.delete_user_preset(_preset_name)
	service.create_user_preset(_preset_name, "default")
	service.set_active_preset(_preset_name)


func after_each() -> void:
	service.set_active_preset("default")
	service.delete_user_preset(_preset_name)
	service.reload_all()
	service.store.delete_directory_recursive(storage_root)



func test_rejects_non_assets_texture_path():
	service.upsert_override(
		EntityAssetConfig.EntityKind.PLAYER,
		"main",
		{"visual.texture_paths.left": "res://scripts/game/combat_actor.gd"}
	)

	var config := service.get_player_config()
	var left_path := str(config.visual.texture_paths.get("left", ""))
	assert_true(left_path.begins_with("res://assets/"), "Invalid texture path should be replaced by fallback asset path")


func test_rejects_invalid_collision_profile_path():
	service.upsert_override(
		EntityAssetConfig.EntityKind.ENEMY,
		"basic",
		{"collision.collision_profile_path": "res://resources/ui_theme.tres"}
	)

	var config := service.get_enemy_config("basic")
	assert_eq(config.collision.collision_profile_path, "res://resources/collision_profiles/spider_enemy.tres",
		"Invalid collision profile should fall back to base profile")


func test_rejects_invalid_collision_profile_patch_and_preserves_previous():
	var valid_path := service.upsert_collision_profile_override(
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

	var rejected_path := service.upsert_collision_profile_override(
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

	var config := service.get_enemy_config("basic")
	assert_eq(config.collision.collision_profile_path, valid_path,
		"Rejected patch should preserve last valid collision profile path")

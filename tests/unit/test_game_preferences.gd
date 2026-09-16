extends GutTest

func before_each() -> void:
	TestHelpers.reset_all_services()

func test_preferences_round_trip_and_reject_invalid_types() -> void:
	var service := preload("res://scripts/autoload/settings_service.gd").new()
	service.preferences_path = "user://preferences_%d.cfg" % Time.get_ticks_usec()
	add_child_autofree(service)
	service.set_fullscreen(true, false)
	service.set_vsync(false, false)
	service.set_reduced_motion(true, false)
	assert_eq(service.save_preferences(), OK)
	service.set_fullscreen(false, false)
	service.set_vsync(true, false)
	service.set_reduced_motion(false, false)
	service.load_preferences()
	assert_true(service.fullscreen)
	assert_false(service.vsync)
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
	var config := ConfigFile.new()
	config.set_value("display", "fullscreen", "bad")
	config.save(service.preferences_path)
	service.load_preferences()
	assert_true(service.fullscreen, "Malformed values must not overwrite valid preferences")
	DirAccess.remove_absolute(service.preferences_path)
	SettingsService.apply_display_preferences()
	SettingsService.set_reduced_motion(false, false)

func test_shop_price_policies_remain_independent_of_retired_scene_manager() -> void:
	EconomyService.turrets_purchased = 2
	assert_eq(EconomyService.calculate_turret_price(10, 5), 40)
	assert_eq(EconomyService.calculate_item_price(20, 1), 24)
	assert_eq(EconomyService.calculate_item_price(20, 5), 40)
	ModifierService.add_modifier({"id": "discount", "stat": "shop_price_mult", "operation": "increase", "value": -.25})
	assert_eq(EconomyService.calculate_item_price(20, 5), 30)
	assert_eq(EconomyService.calculate_turret_price(10, 5), 30)

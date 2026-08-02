extends GutTest

## Unit coverage for the centralized feature-flag contract.

func before_each() -> void:
	FeatureFlagService.reset_state()
	GameStateService.reset_state()
	GameModeService.reset_state()


func after_each() -> void:
	FeatureFlagService.reset_state()
	GameStateService.reset_state()
	GameModeService.reset_state()


func test_default_flags_are_available() -> void:
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.ENEMY_SPAWNING))
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.TECH_DROPS))
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.SHOP))
	assert_false(FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))


func test_flags_can_be_toggled_and_reset() -> void:
	assert_true(FeatureFlagService.set_enabled(FeatureFlagService.SHOP, false))
	assert_false(FeatureFlagService.is_enabled(FeatureFlagService.SHOP))
	assert_true(FeatureFlagService.toggle(FeatureFlagService.SHOP))
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.SHOP))

	FeatureFlagService.set_enabled(FeatureFlagService.SHOP, false)
	FeatureFlagService.reset_state()
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.SHOP))


func test_unknown_flag_is_rejected() -> void:
	assert_false(FeatureFlagService.is_known_flag("missing_flag"))
	assert_false(FeatureFlagService.set_enabled("missing_flag", true))
	assert_false(FeatureFlagService.is_enabled("missing_flag"))


func test_settings_facade_uses_feature_flags() -> void:
	SettingsService.show_damage_numbers = false
	assert_false(FeatureFlagService.is_enabled(FeatureFlagService.SHOW_DAMAGE_NUMBERS))

	SettingsService.player_auto_attack_enabled = false
	assert_false(FeatureFlagService.is_enabled(FeatureFlagService.PLAYER_AUTO_ATTACK))

	SettingsService.reset_state()
	assert_true(SettingsService.show_damage_numbers)
	assert_true(SettingsService.player_auto_attack_enabled)


func test_mode_flags_control_registry_availability() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.MODE_ESCORT, false)
	var modes := GameModeRegistry.get_modes_in_group("win_condition")
	assert_does_not_have(modes, GameEnums.GameMode.ESCORT)
	assert_false(GameModeRegistry.is_mode_enabled(GameEnums.GameMode.ESCORT))
	assert_false(GameModeService.set_mode(GameEnums.GameMode.ESCORT))


func test_active_mode_cannot_change_during_run() -> void:
	assert_true(GameModeService.set_mode(GameEnums.GameMode.SURVIVAL))
	GameStateService.is_game_active = true

	assert_false(GameModeService.set_mode(GameEnums.GameMode.TUNNELING_TIMED))
	assert_true(GameModeService.is_mode_active(GameEnums.GameMode.SURVIVAL))
	assert_false(FeatureFlagService.set_enabled(FeatureFlagService.MODE_ESCORT, false))
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.MODE_ESCORT))

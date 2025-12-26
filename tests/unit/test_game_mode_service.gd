extends GutTest

## Unit tests for GameModeService

func before_each() -> void:
	# Reset service state before each test
	GameModeService.reset_state()

func test_default_modes_initialized() -> void:
	# Both groups should have defaults set
	assert_true(GameModeService.is_mode_active(GameEnums.GameMode.SENTINEL), "spawn_location should default to SENTINEL")
	assert_true(GameModeService.is_mode_active(GameEnums.GameMode.TECH_DEFENSE), "win_condition should default to TECH_DEFENSE")

func test_mode_group_exclusivity() -> void:
	# Setting TECH_DEFENSE should not affect spawn_location
	GameModeService.set_mode(GameEnums.GameMode.TECH_DEFENSE)
	assert_true(GameModeService.is_mode_active(GameEnums.GameMode.TECH_DEFENSE), "TECH_DEFENSE should be active")
	assert_true(GameModeService.is_mode_active(GameEnums.GameMode.SENTINEL), "SENTINEL should still be active")
	assert_false(GameModeService.is_mode_active(GameEnums.GameMode.SURVIVAL), "SURVIVAL should be replaced")

func test_win_condition_mutual_exclusivity() -> void:
	# Only one win_condition mode can be active at a time
	GameModeService.set_mode(GameEnums.GameMode.TUNNELING_TIMED)
	assert_true(GameModeService.is_mode_active(GameEnums.GameMode.TUNNELING_TIMED))
	assert_false(GameModeService.is_mode_active(GameEnums.GameMode.SURVIVAL))
	assert_false(GameModeService.is_mode_active(GameEnums.GameMode.TECH_DEFENSE))
	
	GameModeService.set_mode(GameEnums.GameMode.TECH_DEFENSE)
	assert_true(GameModeService.is_mode_active(GameEnums.GameMode.TECH_DEFENSE))
	assert_false(GameModeService.is_mode_active(GameEnums.GameMode.TUNNELING_TIMED))

func test_spawn_location_mutual_exclusivity() -> void:
	# Only one spawn_location mode can be active at a time
	GameModeService.set_mode(GameEnums.GameMode.INVASION)
	assert_true(GameModeService.is_mode_active(GameEnums.GameMode.INVASION))
	assert_false(GameModeService.is_mode_active(GameEnums.GameMode.SENTINEL))

func test_get_win_condition_mode() -> void:
	assert_eq(GameModeService.get_win_condition_mode(), GameEnums.GameMode.TECH_DEFENSE, "Should default to TECH_DEFENSE")
	
	GameModeService.set_mode(GameEnums.GameMode.SURVIVAL)
	assert_eq(GameModeService.get_win_condition_mode(), GameEnums.GameMode.SURVIVAL)

func test_should_spawn_defense_target() -> void:
	assert_true(GameModeService.should_spawn_defense_target(), "TECH_DEFENSE mode (default) should spawn target")
	
	GameModeService.set_mode(GameEnums.GameMode.SURVIVAL)
	assert_false(GameModeService.should_spawn_defense_target(), "SURVIVAL should not spawn target")

func test_should_spawn_tunnel_door() -> void:
	assert_false(GameModeService.should_spawn_tunnel_door(), "SURVIVAL mode should not spawn door")
	
	GameModeService.set_mode(GameEnums.GameMode.TUNNELING_TIMED)
	assert_true(GameModeService.should_spawn_tunnel_door(), "TUNNELING_TIMED should spawn door")
	
	GameModeService.set_mode(GameEnums.GameMode.TUNNELING_ALERT)
	assert_true(GameModeService.should_spawn_tunnel_door(), "TUNNELING_ALERT should spawn door")

func test_is_alert_mode_active() -> void:
	assert_false(GameModeService.is_alert_mode_active(), "SURVIVAL mode is not alert mode")
	
	GameModeService.set_mode(GameEnums.GameMode.TUNNELING_TIMED)
	assert_false(GameModeService.is_alert_mode_active(), "TUNNELING_TIMED is not alert mode")
	
	GameModeService.set_mode(GameEnums.GameMode.TUNNELING_ALERT)
	assert_true(GameModeService.is_alert_mode_active(), "TUNNELING_ALERT is alert mode")

func test_spawn_rate_multiplier_non_alert_mode() -> void:
	# Non-alert modes should always return 1.0
	var multiplier = GameModeService.get_spawn_rate_multiplier(100.0)
	assert_eq(multiplier, 1.0, "Non-alert mode should not escalate")

func test_spawn_rate_multiplier_alert_mode() -> void:
	GameModeService.set_mode(GameEnums.GameMode.TUNNELING_ALERT)
	
	# Before alert starts (time <= 0)
	assert_eq(GameModeService.get_spawn_rate_multiplier(0.0), 1.0, "No escalation at t=0")
	assert_eq(GameModeService.get_spawn_rate_multiplier(-5.0), 1.0, "No escalation at negative time")
	
	# +30% every 8 seconds
	assert_eq(GameModeService.get_spawn_rate_multiplier(4.0), 1.0, "No escalation before first interval")
	assert_eq(GameModeService.get_spawn_rate_multiplier(8.0), 1.3, "First interval: +30%")
	assert_eq(GameModeService.get_spawn_rate_multiplier(16.0), 1.6, "Second interval: +60%")
	assert_eq(GameModeService.get_spawn_rate_multiplier(24.0), 1.9, "Third interval: +90%")
	
	# Partial intervals should floor
	assert_eq(GameModeService.get_spawn_rate_multiplier(15.9), 1.3, "Partial second interval should be 1.3")

func test_reset_state_restores_defaults() -> void:
	# Change modes away from defaults
	GameModeService.set_mode(GameEnums.GameMode.INVASION)
	GameModeService.set_mode(GameEnums.GameMode.SURVIVAL) # Change away from default TECH_DEFENSE
	
	# Reset
	GameModeService.reset_state()
	
	# Should be back to defaults (SENTINEL for spawn_location, TECH_DEFENSE for win_condition)
	assert_true(GameModeService.is_mode_active(GameEnums.GameMode.SENTINEL), "Default spawn_location should be SENTINEL")
	assert_true(GameModeService.is_mode_active(GameEnums.GameMode.TECH_DEFENSE), "Default win_condition should be TECH_DEFENSE")
	assert_false(GameModeService.is_mode_active(GameEnums.GameMode.INVASION), "INVASION should not be active after reset")
	assert_false(GameModeService.is_mode_active(GameEnums.GameMode.SURVIVAL), "SURVIVAL should not be active after reset")

extends GutTest

# =============================================================================
# Unit tests for WaveController
# Tests wave timing, duration calculations, and phase transitions
# =============================================================================

var wave_controller: Node = null


func before_each() -> void:
	TestHelpers.reset_all_services()
	# Reset game state
	GameStateService.reset_state()
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)

	# Create a fresh WaveController instance
	wave_controller = preload("res://scripts/wave_controller.gd").new()
	add_child_autofree(wave_controller)


# =============================================================================
# WAVE DURATION CALCULATIONS
# =============================================================================

func test_get_wave_duration_wave_1():
	var duration = wave_controller.get_wave_duration(1)
	var expected = GameConstants.WAVE_DURATION_BASE  # Base wave duration

	assert_eq(duration, expected, "Wave 1 duration should be base duration")


func test_get_wave_duration_scales_with_wave():
	var wave_1_duration = wave_controller.get_wave_duration(1)
	var wave_5_duration = wave_controller.get_wave_duration(5)

	assert_gt(wave_5_duration, wave_1_duration,
		"Wave 5 should have longer duration than wave 1")


func test_get_wave_duration_respects_cap():
	# Late waves should hit the cap
	var wave_10_duration = wave_controller.get_wave_duration(10)

	assert_eq(wave_10_duration, GameConstants.WAVE_DURATION_CAP,
		"Late waves should be capped at WAVE_DURATION_CAP")


# =============================================================================
# WAVE ANNOUNCEMENT
# =============================================================================

func test_start_wave_announcement_increments_wave():
	GameStateService.current_wave = 0
	wave_controller.start_wave_announcement()

	assert_eq(GameStateService.current_wave, 1, "Wave should increment after announcement starts")


func test_process_announcement_returns_false_during_timer():
	wave_controller.start_wave_announcement()

	# Process for half the announcement time
	var half_time = GameConstants.WAVE_ANNOUNCEMENT_TIME / 2.0
	var done = wave_controller.process_announcement(half_time)

	assert_false(done, "Should return false while announcement timer is running")


func test_process_announcement_returns_true_when_complete():
	wave_controller.start_wave_announcement()

	# Process for full announcement time
	var done = wave_controller.process_announcement(GameConstants.WAVE_ANNOUNCEMENT_TIME + 0.1)

	assert_true(done, "Should return true when announcement timer expires")


# =============================================================================
# COMBAT PHASE
# =============================================================================

func test_start_combat_sets_wave_timer():
	GameStateService.current_wave = 1
	wave_controller.start_combat()

	# After start_combat, wave_timer should be set
	assert_gt(wave_controller.wave_timer, 0.0, "Wave timer should be set after start_combat")


func test_process_combat_returns_false_during_wave():
	GameStateService.current_wave = 1
	wave_controller.start_combat()

	# Process for a small amount of time
	var done = wave_controller.process_combat(1.0)

	assert_false(done, "Should return false while wave timer is running")


func test_process_combat_returns_true_when_time_up():
	GameStateService.current_wave = 1
	wave_controller.start_combat()

	# Process for more than wave duration
	var wave_duration = wave_controller.get_wave_duration(1)
	var done = wave_controller.process_combat(wave_duration + 1.0)

	assert_true(done, "Should return true when wave timer expires")


# =============================================================================
# WAVE END
# =============================================================================

func test_end_wave_sets_pause_timer():
	wave_controller.end_wave()

	assert_gt(wave_controller.pause_timer, 0.0, "Pause timer should be set after end_wave")


func test_process_wave_end_returns_false_during_pause():
	wave_controller.end_wave()

	# Process for half the pause time
	var half_time = GameConstants.BETWEEN_WAVE_PAUSE / 2.0
	var done = wave_controller.process_wave_end(half_time)

	assert_false(done, "Should return false while pause timer is running")


func test_process_wave_end_returns_true_when_complete():
	wave_controller.end_wave()

	# Process for full pause time
	var done = wave_controller.process_wave_end(GameConstants.BETWEEN_WAVE_PAUSE + 0.1)

	assert_true(done, "Should return true when pause timer expires")


# =============================================================================
# FINAL WAVE CHECK
# =============================================================================

func test_is_final_wave_returns_false_on_wave_1():
	GameStateService.current_wave = 1
	assert_false(wave_controller.is_final_wave())


func test_is_final_wave_returns_true_on_max_wave():
	GameStateService.current_wave = GameConstants.MAX_WAVES
	assert_true(wave_controller.is_final_wave())


func test_is_final_wave_returns_false_before_max():
	GameStateService.current_wave = GameConstants.MAX_WAVES - 1
	assert_false(wave_controller.is_final_wave())


# =============================================================================
# GET CURRENT WAVE
# =============================================================================

func test_get_current_wave_returns_game_state_wave():
	GameStateService.current_wave = 5
	assert_eq(wave_controller.get_current_wave(), 5)

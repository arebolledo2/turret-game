extends GutTest

# =============================================================================
# Integration tests for the Events signal bus
# Verifies that signals flow correctly between systems
# =============================================================================


func before_each() -> void:
	TestHelpers.reset_all_services()
	GameStateService.reset_state()
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)


# =============================================================================
# SIGNAL DEFINITION TESTS
# =============================================================================

func test_events_singleton_exists():
	assert_not_null(Events, "Events autoload should exist")


func test_game_state_signals_exist():
	assert_has_signal(Events, "game_started")
	assert_has_signal(Events, "game_paused")
	assert_has_signal(Events, "game_resumed")
	assert_has_signal(Events, "game_over")


func test_wave_signals_exist():
	assert_has_signal(Events, "wave_announcement_started")
	assert_has_signal(Events, "wave_started")
	assert_has_signal(Events, "wave_ended")
	assert_has_signal(Events, "wave_timer_updated")


func test_combat_signals_exist():
	assert_has_signal(Events, "enemy_killed")
	assert_has_signal(Events, "enemy_spawned")
	assert_has_signal(Events, "player_damaged")
	assert_has_signal(Events, "player_died")


func test_turret_signals_exist():
	assert_has_signal(Events, "turret_spawned")
	assert_has_signal(Events, "turret_fired")
	assert_has_signal(Events, "turret_picked_up")
	assert_has_signal(Events, "turret_placed")
	assert_has_signal(Events, "turret_dropped")


func test_pickup_signals_exist():
	assert_has_signal(Events, "scrap_dropped")
	assert_has_signal(Events, "scrap_collected")


func test_ui_signals_exist():
	assert_has_signal(Events, "show_wave_announcement")
	assert_has_signal(Events, "hide_wave_announcement")
	assert_has_signal(Events, "show_difficulty_select")
	assert_has_signal(Events, "difficulty_selected")
	assert_has_signal(Events, "update_hud")


# =============================================================================
# SIGNAL EMISSION TESTS
# =============================================================================

func test_can_emit_game_started():
	watch_signals(Events)
	Events.game_started.emit()
	assert_signal_emitted(Events, "game_started")


func test_can_emit_game_over_with_victory():
	watch_signals(Events)
	Events.game_over.emit(true)
	assert_signal_emitted_with_parameters(Events, "game_over", [true])


func test_can_emit_game_over_with_defeat():
	watch_signals(Events)
	Events.game_over.emit(false)
	assert_signal_emitted_with_parameters(Events, "game_over", [false])


func test_can_emit_wave_announcement_started():
	watch_signals(Events)
	Events.wave_announcement_started.emit(3)
	assert_signal_emitted_with_parameters(Events, "wave_announcement_started", [3])


func test_can_emit_player_damaged():
	watch_signals(Events)
	Events.player_damaged.emit(50.0, 100.0)
	assert_signal_emitted_with_parameters(Events, "player_damaged", [50.0, 100.0])


func test_can_emit_scrap_collected():
	watch_signals(Events)
	Events.scrap_collected.emit(10, 100)
	assert_signal_emitted_with_parameters(Events, "scrap_collected", [10, 100])


# =============================================================================
# SIGNAL CONNECTION TESTS
# =============================================================================

var _signal_received := false
var _signal_value: int = 0

func _wave_callback(wave: int) -> void:
	_signal_received = true
	_signal_value = wave


func test_signal_can_be_connected_and_received():
	_signal_received = false
	_signal_value = 0
	
	Events.wave_started.connect(_wave_callback)
	Events.wave_started.emit(5)
	
	assert_true(_signal_received, "Callback should have been called")
	assert_eq(_signal_value, 5, "Should receive wave number")
	
	# Cleanup
	Events.wave_started.disconnect(_wave_callback)

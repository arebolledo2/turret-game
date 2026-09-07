extends GutTest

# =============================================================================
# Integration tests for game_manager.gd
# Tests game state transitions and flow
# =============================================================================

var main_scene: PackedScene
var main: Node
var game_manager: Node


func before_all() -> void:
	main_scene = load("res://scenes/main.tscn")


func before_each() -> void:
	TestHelpers.reset_all_services()
	GameStateService.reset_state()
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	FeatureFlagService.reset_state()

	main = main_scene.instantiate()
	add_child_autofree(main)
	game_manager = main.get_node("GameManager")

	# Wait for scene to be ready
	await get_tree().process_frame


# Helper to start game with the new consolidated settings flow
func _start_game_with_settings(difficulty := GameEnums.Difficulty.EASY) -> void:
	Events.start_settings_applied.emit(
		difficulty,
		GameEnums.GameMode.SENTINEL,
		GameEnums.GameMode.TECH_DEFENSE,
		GameEnums.GameMode.ARENA_ISOMETRIC,
		0  # bg_index
	)
	await get_tree().process_frame


# =============================================================================
# INITIAL STATE TESTS
# =============================================================================

func test_game_starts_in_difficulty_select():
	# After _ready + call_deferred, should be in difficulty select
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.DIFFICULTY_SELECT,
		"Game should start in DIFFICULTY_SELECT state")


func test_game_not_active_initially():
	assert_false(GameStateService.is_game_active, "Game should not be active at start")


# =============================================================================
# DIFFICULTY SELECTION TESTS
# =============================================================================

func test_start_settings_applied_starts_game():
	watch_signals(Events)
	
	Events.start_settings_applied.emit(
		GameEnums.Difficulty.MEDIUM,
		GameEnums.GameMode.SENTINEL,
		GameEnums.GameMode.TECH_DEFENSE,
		GameEnums.GameMode.ARENA_ISOMETRIC,
		0  # bg_index
	)
	await get_tree().process_frame
	
	assert_eq(DifficultyService.current_difficulty, GameEnums.Difficulty.MEDIUM,
		"Difficulty should be set to MEDIUM")
	assert_signal_emitted(Events, "game_started", "Should emit game_started signal after settings applied")
	assert_true(GameStateService.is_game_active, "Game should be active after settings applied")
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_ANNOUNCEMENT,
		"Game should be in WAVE_ANNOUNCEMENT state after settings applied")


# Removed multi-step selection tests as they are now consolidated


func test_wave_starts_at_1_after_selection():
	await _start_game_with_settings()

	# Wave is set to 1 when wave announcement starts (incremented in start_wave_announcement)
	assert_eq(GameStateService.current_wave, 1, "Wave should be 1 after game starts")


# =============================================================================
# SHOP PHASE TESTS (Shop V2: Shop only appears AFTER wave 1)
# =============================================================================

func test_game_enters_wave_announcement_after_mode_select():
	await _start_game_with_settings()

	# Game goes directly to wave announcement after settings applied
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_ANNOUNCEMENT,
		"Should enter WAVE_ANNOUNCEMENT after settings applied")


func test_wave_announcement_signal_emitted_on_start():
	watch_signals(Events)

	await _start_game_with_settings()

	# Wave announcement emitted immediately after game starts
	assert_signal_emitted(Events, "wave_announcement_started")


# =============================================================================
# WAVE ANNOUNCEMENT TESTS (Shop V2: starts immediately after difficulty select)
# =============================================================================

func test_game_enters_wave_announcement_after_shop():
	await _start_game_with_settings()

	# We should be in WAVE_ANNOUNCEMENT after game starts
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_ANNOUNCEMENT,
		"Should be in WAVE_ANNOUNCEMENT after settings applied")


func test_wave_announcement_signal_emitted_after_shop():
	watch_signals(Events)

	await _start_game_with_settings()

	# Wave announcement signals emitted when game starts
	assert_signal_emitted(Events, "wave_announcement_started")
	assert_signal_emitted(Events, "show_wave_announcement")


func test_tunneling_mode_spawns_door_during_announcement():
	Events.start_settings_applied.emit(
		GameEnums.Difficulty.EASY,
		GameEnums.GameMode.SENTINEL,
		GameEnums.GameMode.TUNNELING_TIMED,
		GameEnums.GameMode.ARENA_ISOMETRIC,
		0
	)
	await get_tree().process_frame

	assert_true(GameModeService.is_mode_active(GameEnums.GameMode.TUNNELING_TIMED))
	assert_true(game_manager.entity_spawner.has_tunnel_door(), "Tunneling should spawn its door before combat")


# =============================================================================
# COMBAT STATE TESTS
# =============================================================================

func test_combat_starts_after_announcement():
	await _start_game_with_settings()

	# Wait for announcement timer to finish (uses GameConstants.WAVE_ANNOUNCEMENT_TIME)
	var start_time = Time.get_ticks_msec()
	var max_wait_ms = int((GameConstants.WAVE_ANNOUNCEMENT_TIME + 1.0) * 1000)

	while GameStateMachine.current_state == GameStateMachine.GameState.WAVE_ANNOUNCEMENT:
		await get_tree().process_frame
		if Time.get_ticks_msec() - start_time > max_wait_ms:
			break

	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.COMBAT,
		"Should enter COMBAT after announcement timer")


func test_wave_started_signal_emitted_during_combat():
	watch_signals(Events)

	await _start_game_with_settings()

	# Wait for combat to start
	var start_time = Time.get_ticks_msec()
	var max_wait_ms = int((GameConstants.WAVE_ANNOUNCEMENT_TIME + 1.0) * 1000)

	while GameStateMachine.current_state != GameStateMachine.GameState.COMBAT:
		await get_tree().process_frame
		if Time.get_ticks_msec() - start_time > max_wait_ms:
			break

	assert_signal_emitted(Events, "wave_started", "wave_started should be emitted when combat begins")


# =============================================================================
# GAME OVER TESTS
# =============================================================================

func test_player_death_triggers_game_over():
	watch_signals(Events)

	await _start_game_with_settings()

	# Game is already active after _start_game_with_settings

	Events.player_died.emit()
	await get_tree().process_frame

	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.GAME_OVER,
		"Should be in GAME_OVER after player death")
	assert_signal_emitted(Events, "game_over")


func test_game_deactivates_on_player_death():
	await _start_game_with_settings()

	Events.player_died.emit()
	await get_tree().process_frame

	assert_false(GameStateService.is_game_active, "Game should be inactive after death")


# =============================================================================
# TIME TRACKING TESTS
# =============================================================================

func test_time_survived_increments():
	await _start_game_with_settings()

	GameStateService.time_survived = 0.0

	# Process some frames while game is active
	for i in range(10):
		await get_tree().process_frame

	assert_gt(GameStateService.time_survived, 0.0, "Time survived should increment during game")


func _finish_first_wave(shop_enabled: bool, with_loot: bool) -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.SHOP, shop_enabled)
	await _start_game_with_settings()
	game_manager.set_process(false)
	game_manager._process(GameConstants.WAVE_ANNOUNCEMENT_TIME + 0.1)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.COMBAT)
	if with_loot:
		LootService.add_found_item("scrap_magnet")
	var balance := EconomyService.total_scrap
	watch_signals(Events)
	game_manager._process(game_manager.wave_controller.wave_timer + 0.1)
	game_manager._process(GameConstants.BETWEEN_WAVE_PAUSE + 0.1)
	assert_eq(EconomyService.total_scrap - balance, EconomyService.get_wave_scrap_bonus(1, 1.0))
	assert_signal_emit_count(Events, "scrap_collected", 1)
	if with_loot:
		assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.LOOT_REVIEW)
		main.get_node("HUD")._loot_review._on_discard_pressed()
	if shop_enabled:
		assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)
		game_manager.end_shop_phase()
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_ANNOUNCEMENT)
	assert_eq(GameStateService.current_wave, 2)
	# Duplicate completion notifications must not award or advance again.
	game_manager._finish_wave_end()
	Events.loot_review_completed.emit()
	assert_eq(GameStateService.current_wave, 2)
	assert_signal_emit_count(Events, "scrap_collected", 1)
	game_manager._process(GameConstants.WAVE_ANNOUNCEMENT_TIME + 0.1)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.COMBAT)


func test_shop_enabled_without_loot() -> void:
	await _finish_first_wave(true, false)


func test_shop_enabled_with_loot() -> void:
	await _finish_first_wave(true, true)


func test_shop_disabled_without_loot() -> void:
	await _finish_first_wave(false, false)


func test_shop_disabled_with_loot() -> void:
	await _finish_first_wave(false, true)


func test_restart_drops_pending_loot_and_buffs() -> void:
	await _start_game_with_settings()
	LootService.add_found_item("previous_run_item")
	BuffSystem.active_buffs[123] = []
	Events.player_died.emit()
	main.free()
	main = main_scene.instantiate()
	add_child_autofree(main)
	game_manager = main.get_node("GameManager")
	await get_tree().process_frame
	await _start_game_with_settings()
	assert_false(LootService.has_pending_loot())
	assert_true(BuffSystem.active_buffs.is_empty())
	assert_eq(GameStateService.current_wave, 1)


func test_rejected_announcement_has_no_side_effects() -> void:
	await _start_game_with_settings()
	game_manager.set_process(false)
	var wave := GameStateService.current_wave
	watch_signals(Events)
	game_manager._start_wave_announcement()
	assert_eq(GameStateService.current_wave, wave)
	assert_signal_not_emitted(Events, "wave_announcement_started")

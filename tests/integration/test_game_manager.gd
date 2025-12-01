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
	Globals.reset_stats()
	Globals.current_difficulty = Globals.Difficulty.EASY
	
	main = main_scene.instantiate()
	add_child_autofree(main)
	game_manager = main.get_node("GameManager")
	
	# Wait for scene to be ready
	await get_tree().process_frame


# =============================================================================
# INITIAL STATE TESTS
# =============================================================================

func test_game_starts_in_difficulty_select():
	# After _ready + call_deferred, should be in difficulty select
	await get_tree().process_frame
	await get_tree().process_frame
	
	assert_eq(game_manager.current_state, game_manager.GameState.DIFFICULTY_SELECT,
		"Game should start in DIFFICULTY_SELECT state")


func test_game_not_active_initially():
	assert_false(Globals.is_game_active, "Game should not be active at start")


# =============================================================================
# DIFFICULTY SELECTION TESTS
# =============================================================================

func test_difficulty_selection_starts_game():
	watch_signals(Events)
	
	Events.difficulty_selected.emit(Globals.Difficulty.MEDIUM)
	await get_tree().process_frame
	
	assert_eq(Globals.current_difficulty, Globals.Difficulty.MEDIUM,
		"Difficulty should be set to MEDIUM")
	assert_signal_emitted(Events, "game_started", "Should emit game_started signal")


func test_difficulty_selection_activates_game():
	Events.difficulty_selected.emit(Globals.Difficulty.EASY)
	await get_tree().process_frame
	
	assert_true(Globals.is_game_active, "Game should be active after difficulty selected")


func test_wave_starts_at_1_after_selection():
	Events.difficulty_selected.emit(Globals.Difficulty.EASY)
	await get_tree().process_frame
	
	# Wave starts at 0, increments to 1 when wave announcement starts (after shop)
	# At this point we're in shop phase, wave is still 0
	assert_eq(Globals.current_wave, 0, "Wave should be 0 during initial shop phase")


# =============================================================================
# SHOP PHASE TESTS
# =============================================================================

func test_game_enters_shop_after_difficulty():
	Events.difficulty_selected.emit(Globals.Difficulty.EASY)
	await get_tree().process_frame
	
	assert_eq(game_manager.current_state, game_manager.GameState.SHOP,
		"Should enter SHOP after difficulty selected")


func test_shop_opened_signal_emitted():
	watch_signals(Events)
	
	Events.difficulty_selected.emit(Globals.Difficulty.EASY)
	await get_tree().process_frame
	
	assert_signal_emitted(Events, "shop_opened")


# =============================================================================
# WAVE ANNOUNCEMENT TESTS (after shop closes)
# =============================================================================

func test_game_enters_wave_announcement_after_shop():
	Events.difficulty_selected.emit(Globals.Difficulty.EASY)
	await get_tree().process_frame
	
	# Verify we're in shop state
	assert_eq(game_manager.current_state, game_manager.GameState.SHOP,
		"Should be in SHOP after difficulty selected")
	
	# Close shop to proceed to wave announcement (call method directly like shop_screen does)
	game_manager.end_shop_phase()
	
	# State should be WAVE_ANNOUNCEMENT immediately after calling end_shop_phase
	assert_eq(game_manager.current_state, game_manager.GameState.WAVE_ANNOUNCEMENT,
		"Should enter WAVE_ANNOUNCEMENT after shop closed")


func test_wave_announcement_signal_emitted_after_shop():
	watch_signals(Events)
	
	Events.difficulty_selected.emit(Globals.Difficulty.EASY)
	await get_tree().process_frame
	
	# Close shop to trigger wave announcement
	game_manager.end_shop_phase()
	await get_tree().process_frame
	
	assert_signal_emitted(Events, "wave_announcement_started")
	assert_signal_emitted(Events, "show_wave_announcement")


# =============================================================================
# COMBAT STATE TESTS
# =============================================================================

func test_combat_starts_after_announcement():
	Events.difficulty_selected.emit(Globals.Difficulty.EASY)
	await get_tree().process_frame
	
	# Close shop to proceed to wave announcement
	game_manager.end_shop_phase()
	await get_tree().process_frame
	
	# Wait for announcement timer to finish (1.5 seconds + buffer)
	var start_time = Time.get_ticks_msec()
	var max_wait_ms = 3000  # 3 seconds max
	
	while game_manager.current_state == game_manager.GameState.WAVE_ANNOUNCEMENT:
		await get_tree().process_frame
		if Time.get_ticks_msec() - start_time > max_wait_ms:
			break
	
	assert_eq(game_manager.current_state, game_manager.GameState.COMBAT,
		"Should enter COMBAT after announcement timer")


func test_wave_started_signal_emitted_during_combat():
	watch_signals(Events)
	
	Events.difficulty_selected.emit(Globals.Difficulty.EASY)
	await get_tree().process_frame
	
	# Close shop to proceed
	game_manager.end_shop_phase()
	
	# Wait for combat to start
	var start_time = Time.get_ticks_msec()
	var max_wait_ms = 3000
	
	while game_manager.current_state != game_manager.GameState.COMBAT:
		await get_tree().process_frame
		if Time.get_ticks_msec() - start_time > max_wait_ms:
			break
	
	assert_signal_emitted(Events, "wave_started", "wave_started should be emitted when combat begins")


# =============================================================================
# GAME OVER TESTS
# =============================================================================

func test_player_death_triggers_game_over():
	watch_signals(Events)
	
	Events.difficulty_selected.emit(Globals.Difficulty.EASY)
	await get_tree().process_frame
	Globals.is_game_active = true
	
	Events.player_died.emit()
	await get_tree().process_frame
	
	assert_eq(game_manager.current_state, game_manager.GameState.GAME_OVER,
		"Should be GAME_OVER after player death")
	assert_signal_emitted(Events, "game_over")


func test_game_deactivates_on_player_death():
	Events.difficulty_selected.emit(Globals.Difficulty.EASY)
	await get_tree().process_frame
	
	Events.player_died.emit()
	await get_tree().process_frame
	
	assert_false(Globals.is_game_active, "Game should be inactive after death")


# =============================================================================
# TIME TRACKING TESTS
# =============================================================================

func test_time_survived_increments():
	Events.difficulty_selected.emit(Globals.Difficulty.EASY)
	await get_tree().process_frame
	
	# Close shop to start the game properly
	game_manager.end_shop_phase()
	await get_tree().process_frame
	
	Globals.time_survived = 0.0
	
	# Process some frames while game is active
	for i in range(10):
		await get_tree().process_frame
	
	assert_gt(Globals.time_survived, 0.0, "Time survived should increment during game")

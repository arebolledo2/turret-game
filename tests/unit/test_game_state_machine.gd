extends GutTest

# =============================================================================
# Unit tests for GameStateMachine
# Tests state transitions, validation, and state queries
# =============================================================================


func before_each() -> void:
	TestHelpers.reset_all_services()
	GameStateMachine.reset()


# =============================================================================
# INITIAL STATE
# =============================================================================

func test_initial_state_is_idle():
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.IDLE,
		"Initial state should be IDLE")


# =============================================================================
# VALID TRANSITIONS
# =============================================================================

func test_idle_to_difficulty_select():
	GameStateMachine.reset()
	var result = GameStateMachine.transition_to(GameStateMachine.GameState.DIFFICULTY_SELECT)

	assert_true(result, "IDLE -> DIFFICULTY_SELECT should be valid")
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.DIFFICULTY_SELECT)


func test_difficulty_select_to_game_mode_select():
	GameStateMachine.force_transition(GameStateMachine.GameState.DIFFICULTY_SELECT)
	var result = GameStateMachine.transition_to(GameStateMachine.GameState.GAME_MODE_SELECT)

	assert_true(result, "DIFFICULTY_SELECT -> GAME_MODE_SELECT should be valid")
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.GAME_MODE_SELECT)


func test_game_mode_select_to_wave_announcement():
	GameStateMachine.force_transition(GameStateMachine.GameState.GAME_MODE_SELECT)
	var result = GameStateMachine.transition_to(GameStateMachine.GameState.WAVE_ANNOUNCEMENT)

	assert_true(result, "GAME_MODE_SELECT -> WAVE_ANNOUNCEMENT should be valid")
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_ANNOUNCEMENT)


func test_wave_announcement_to_combat():
	GameStateMachine.force_transition(GameStateMachine.GameState.WAVE_ANNOUNCEMENT)
	var result = GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)

	assert_true(result, "WAVE_ANNOUNCEMENT -> COMBAT should be valid")
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.COMBAT)


func test_combat_to_wave_end():
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	var result = GameStateMachine.transition_to(GameStateMachine.GameState.WAVE_END)

	assert_true(result, "COMBAT -> WAVE_END should be valid")
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_END)


func test_combat_to_victory():
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	var result = GameStateMachine.transition_to(GameStateMachine.GameState.VICTORY)

	assert_true(result, "COMBAT -> VICTORY should be valid")
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.VICTORY)


func test_combat_to_game_over():
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	var result = GameStateMachine.transition_to(GameStateMachine.GameState.GAME_OVER)

	assert_true(result, "COMBAT -> GAME_OVER should be valid")
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.GAME_OVER)


func test_wave_end_to_shop():
	GameStateMachine.force_transition(GameStateMachine.GameState.WAVE_END)
	var result = GameStateMachine.transition_to(GameStateMachine.GameState.SHOP)

	assert_true(result, "WAVE_END -> SHOP should be valid")
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)


func test_shop_to_wave_announcement():
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	var result = GameStateMachine.transition_to(GameStateMachine.GameState.WAVE_ANNOUNCEMENT)

	assert_true(result, "SHOP -> WAVE_ANNOUNCEMENT should be valid")
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_ANNOUNCEMENT)


# =============================================================================
# INVALID TRANSITIONS
# =============================================================================

func test_idle_to_combat_invalid():
	GameStateMachine.reset()
	var result = GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)

	assert_false(result, "IDLE -> COMBAT should be invalid")
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.IDLE,
		"State should not change on invalid transition")


func test_shop_to_combat_invalid():
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	var result = GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)

	assert_false(result, "SHOP -> COMBAT should be invalid")
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)


func test_wave_announcement_to_shop_invalid():
	GameStateMachine.force_transition(GameStateMachine.GameState.WAVE_ANNOUNCEMENT)
	var result = GameStateMachine.transition_to(GameStateMachine.GameState.SHOP)

	assert_false(result, "WAVE_ANNOUNCEMENT -> SHOP should be invalid")
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_ANNOUNCEMENT)


# =============================================================================
# FORCE TRANSITION
# =============================================================================

func test_force_transition_bypasses_validation():
	GameStateMachine.reset()
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)

	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.COMBAT,
		"force_transition should bypass validation")


# =============================================================================
# SIGNAL EMISSION
# =============================================================================

func test_transition_emits_state_changed_signal():
	GameStateMachine.reset()
	watch_signals(GameStateMachine)

	GameStateMachine.transition_to(GameStateMachine.GameState.DIFFICULTY_SELECT)

	assert_signal_emitted(GameStateMachine, "state_changed")


func test_force_transition_emits_state_changed_signal():
	GameStateMachine.reset()
	watch_signals(GameStateMachine)

	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)

	assert_signal_emitted(GameStateMachine, "state_changed")


func test_invalid_transition_does_not_emit_signal():
	GameStateMachine.reset()
	watch_signals(GameStateMachine)

	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)  # Invalid

	assert_signal_not_emitted(GameStateMachine, "state_changed")


# =============================================================================
# STATE QUERIES
# =============================================================================

func test_is_playing_during_wave_announcement():
	GameStateMachine.force_transition(GameStateMachine.GameState.WAVE_ANNOUNCEMENT)
	assert_true(GameStateMachine.is_playing())


func test_is_playing_during_combat():
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	assert_true(GameStateMachine.is_playing())


func test_is_playing_during_wave_end():
	GameStateMachine.force_transition(GameStateMachine.GameState.WAVE_END)
	assert_true(GameStateMachine.is_playing())


func test_is_playing_during_shop():
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	assert_true(GameStateMachine.is_playing())


func test_is_not_playing_during_idle():
	GameStateMachine.reset()
	assert_false(GameStateMachine.is_playing())


func test_is_not_playing_during_game_over():
	GameStateMachine.force_transition(GameStateMachine.GameState.GAME_OVER)
	assert_false(GameStateMachine.is_playing())


func test_is_in_combat():
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	assert_true(GameStateMachine.is_in_combat())


func test_is_not_in_combat_when_idle():
	GameStateMachine.reset()
	assert_false(GameStateMachine.is_in_combat())


func test_is_game_over():
	GameStateMachine.force_transition(GameStateMachine.GameState.GAME_OVER)
	assert_true(GameStateMachine.is_game_over())


func test_is_victory():
	GameStateMachine.force_transition(GameStateMachine.GameState.VICTORY)
	assert_true(GameStateMachine.is_victory())


func test_is_in_menu_during_idle():
	GameStateMachine.reset()
	assert_true(GameStateMachine.is_in_menu())


func test_is_in_menu_during_difficulty_select():
	GameStateMachine.force_transition(GameStateMachine.GameState.DIFFICULTY_SELECT)
	assert_true(GameStateMachine.is_in_menu())


func test_is_not_in_menu_during_combat():
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	assert_false(GameStateMachine.is_in_menu())


# =============================================================================
# GET STATE NAME
# =============================================================================

func test_get_state_name_idle():
	assert_eq(GameStateMachine.get_state_name(GameStateMachine.GameState.IDLE), "IDLE")


func test_get_state_name_combat():
	assert_eq(GameStateMachine.get_state_name(GameStateMachine.GameState.COMBAT), "COMBAT")


func test_get_state_name_game_over():
	assert_eq(GameStateMachine.get_state_name(GameStateMachine.GameState.GAME_OVER), "GAME_OVER")

extends GutTest

var app: GameApp

func before_each() -> void:
	TestHelpers.reset_all_services()
	app = preload("res://scenes/main.tscn").instantiate()
	add_child_autofree(app)

func press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await wait_process_frames(1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await wait_process_frames(1)

func press_button(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await wait_process_frames(1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await wait_process_frames(1)

func test_fresh_launch_waits_for_play_and_keyboard_starts_the_default_game() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/main.tscn")
	assert_null(app.arena)
	assert_true(app.menu.visible)
	assert_false(GameStateService.is_game_active)
	assert_same(get_viewport().gui_get_focus_owner(), app.play_button)
	await press_key(KEY_ENTER)
	assert_not_null(app.arena)
	assert_false(app.menu.visible)
	assert_eq(GameStateService.current_wave, 1)
	assert_eq(app.arena.wave_limit, GameConstants.RUN_DEFAULT_WAVE_LIMIT)
	assert_eq(GameConstants.RUN_DEFAULT_WAVE_LIMIT, 20)
	assert_eq(app.arena.turrets.size(), 1)
	assert_true(app.arena.difficulty_config == DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY])

func test_controller_menu_settings_back_play_and_pause() -> void:
	await press_button(JOY_BUTTON_DPAD_DOWN)
	assert_same(get_viewport().gui_get_focus_owner(), app.settings_button)
	await press_button(JOY_BUTTON_A)
	assert_true(app.options.visible)
	assert_false(app.home.visible)
	await press_button(JOY_BUTTON_B)
	assert_true(app.home.visible)
	await press_button(JOY_BUTTON_A)
	assert_not_null(app.arena)
	assert_null(app.arena.carried_turret, "The Play press must not also pick up a turret")
	await press_button(JOY_BUTTON_START)
	assert_true(app.arena.paused)
	await press_button(JOY_BUTTON_START)
	assert_false(app.arena.paused)

func test_pause_menu_detaches_the_run_and_repeated_play_is_fresh() -> void:
	for cycle in range(3):
		app.start_game()
		var arena := app.arena
		app.start_game()
		assert_same(app.arena, arena, "No duplicate game roots")
		arena.set_physics_process(false)
		EconomyService.total_scrap = 999
		var old_state := arena.session.state
		arena.toggle_pause()
		arena.hud._process(0)
		assert_true(arena.hud.menu_button.visible)
		arena.hud.menu_button.pressed.emit()
		assert_null(app.arena)
		assert_true(app.menu.visible)
		assert_ne(GameStateService.state, old_state)
		assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.IDLE)
		assert_false(GameStateService.is_game_active)
		await wait_process_frames(2)
	app.start_game()
	assert_eq(EconomyService.total_scrap, GameConstants.STARTING_SCRAP)
	assert_eq(app.arena.enemies.size(), 0)
	assert_eq(app.arena.turrets.size(), 1)

func test_victory_defeat_restart_and_main_menu_paths() -> void:
	app.start_game()
	var arena := app.arena
	arena.set_physics_process(false)
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	arena.player.take_damage(1000)
	arena.hud._process(0)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.GAME_OVER)
	assert_true(arena.hud.restart_button.visible)
	arena.hud.restart_button.pressed.emit()
	assert_eq(GameStateService.current_wave, 1)
	assert_false(arena.player.dead)
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	GameStateService.current_wave = arena.wave_limit
	arena.finish_wave()
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.VICTORY)
	arena.request_menu()
	assert_null(app.arena)
	app.start_game()
	assert_eq(GameStateService.current_wave, 1)
	assert_true(ItemTrackingService.item_counts.is_empty())

func test_reduced_motion_survives_runs_and_preserves_warning_and_pulse_information() -> void:
	SettingsService.set_reduced_motion(true, false)
	app.start_game()
	var arena := app.arena
	arena.set_physics_process(false)
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	var charger := arena.spawn_enemy(Vector3.ZERO, "charger")
	charger.set_physics_process(false)
	charger.flash_time = .14
	charger._physics_process(.01)
	assert_true(charger.visual.visible)
	assert_eq(charger.visual.position.y, 0.0)
	assert_true(charger.warning.visible)
	for leg in charger.legs:
		assert_eq(leg.rotation.y, 0.0)
		assert_eq(leg.rotation.z, 0.0)
	arena.effects.show_shock(Vector3.ZERO, 2.4)
	assert_almost_eq(arena.effects.pulses[0].scale.x, 2.4, .001, "The shader boundary stays at the full effect radius")
	arena.toggle_pause()
	arena.request_menu()
	app.start_game()
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION))
	SettingsService.set_reduced_motion(false, false)

func test_home_screen_chooses_difficulty_and_mode_for_the_next_run() -> void:
	app.difficulty_option.select(app.difficulty_option.get_item_index(GameEnums.Difficulty.HARD))
	app.difficulty_option.item_selected.emit(app.difficulty_option.selected)
	app.mode_option.select(1)
	app.mode_option.item_selected.emit(1)
	assert_eq(app.run_config.difficulty, GameEnums.Difficulty.HARD)
	assert_eq(app.run_config.mode, RunConfig.MODE_CORE)
	assert_string_contains(app.home_summary.text, "Protect the core")
	app.start_game()
	assert_true(app.arena.core_mode)
	assert_not_null(app.arena.core)

func test_mode_selector_hides_when_the_flag_is_off() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.MODE_PROTECT_CORE, false)
	FeatureFlagService.set_enabled(FeatureFlagService.MODE_CONVOY, false)
	app.run_config.mode = RunConfig.MODE_CORE
	app.show_home()
	assert_false(app.mode_option.visible)
	assert_eq(app.run_config.mode, RunConfig.MODE_SURVIVE)
	TestHelpers.reset_flags()

func test_each_mode_is_offered_only_while_its_flag_is_on() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.MODE_CONVOY, false)
	app.run_config.mode = RunConfig.MODE_CONVOY
	app.show_home()
	assert_true(app.mode_option.visible, "core mode keeps the selector")
	assert_true(app.mode_option.is_item_disabled(RunConfig.MODES.find(RunConfig.MODE_CONVOY)))
	assert_false(app.mode_option.is_item_disabled(RunConfig.MODES.find(RunConfig.MODE_CORE)))
	assert_eq(app.run_config.mode, RunConfig.MODE_SURVIVE)
	TestHelpers.reset_flags()
	app.show_home()
	assert_false(app.mode_option.is_item_disabled(RunConfig.MODES.find(RunConfig.MODE_CONVOY)))

func test_run_choices_survive_return_to_menu_and_new_app() -> void:
	app.difficulty_option.item_selected.emit(app.difficulty_option.get_item_index(GameEnums.Difficulty.HARD))
	app.mode_option.item_selected.emit(RunConfig.MODES.find(RunConfig.MODE_CORE))
	app.start_game()
	app.return_to_menu()
	assert_eq(app.run_config.difficulty, GameEnums.Difficulty.HARD)
	assert_eq(app.run_config.mode, RunConfig.MODE_CORE)
	var reopened := preload("res://scenes/main.tscn").instantiate() as GameApp
	add_child_autofree(reopened)
	assert_eq(reopened.difficulty_option.get_selected_id(), GameEnums.Difficulty.HARD)
	assert_eq(reopened.mode_option.selected, RunConfig.MODES.find(RunConfig.MODE_CORE))
	FeatureFlagService.set_enabled(FeatureFlagService.MODE_PROTECT_CORE, false)
	reopened.show_home()
	assert_eq(reopened.run_config.mode, RunConfig.MODE_SURVIVE)
	assert_eq(SettingsService.run_mode, RunConfig.MODE_CORE, "Unavailable mode does not erase preference")

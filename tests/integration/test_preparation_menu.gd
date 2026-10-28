extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_flags()
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.auto_start = false
	world.run_config = RunConfig.new()
	world.run_config.mode = RunConfig.MODE_CONVOY
	add_child_autofree(world)
	world.start_run()
	world.set_physics_process(false)
	world.preparation.set_physics_process(false)
	await wait_process_frames(2)

func after_each() -> void:
	SettingsService.auto_prepare_mode = 0

func pad(button: JoyButton) -> bool:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.button_index = button
	return world.preparation.handle_input(event)

func test_dpad_down_opens_layouts_on_active_mode_and_up_returns_to_map() -> void:
	var prep := world.preparation
	assert_not_null(prep.layer)
	assert_false(prep.menu_focused())
	FeatureFlagService.set_enabled(FeatureFlagService.AUTO_DEPLOY, true)
	assert_true(pad(JOY_BUTTON_DPAD_DOWN))
	assert_true(prep.menu_focused())
	assert_eq(get_viewport().gui_get_focus_owner(), prep.layout_buttons[SettingsService.auto_prepare_mode])
	assert_true(pad(JOY_BUTTON_DPAD_UP))
	assert_false(prep.menu_focused())

func test_b_steps_back_to_map_before_cancelling_a_move() -> void:
	var prep := world.preparation
	prep.interact()
	pad(JOY_BUTTON_DPAD_DOWN)
	assert_true(prep.moving)
	pad(JOY_BUTTON_B)
	assert_false(prep.menu_focused())
	assert_true(prep.moving, "first B only leaves the option bar")
	pad(JOY_BUTTON_B)
	assert_false(prep.moving)

func test_dpad_left_right_cycle_turrets_on_the_map() -> void:
	var second := world.add_turret(Vector3(5, 0, 0), "plasma")
	assert_true(pad(JOY_BUTTON_DPAD_RIGHT))
	assert_eq(world.preparation.selected, second)
	assert_true(pad(JOY_BUTTON_DPAD_LEFT))
	assert_eq(world.preparation.selected, world.turrets[0])

func test_layout_button_applies_layout_and_turns_auto_on() -> void:
	var prep := world.preparation
	FeatureFlagService.set_enabled(FeatureFlagService.AUTO_DEPLOY, false)
	prep.set_layout(3)
	assert_eq(SettingsService.auto_prepare_mode, 3)
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.AUTO_DEPLOY))
	assert_true(prep.layout_buttons[3].button_pressed)
	assert_false(prep.layout_buttons[0].button_pressed)

func test_saved_layout_is_unavailable_until_saved() -> void:
	var prep := world.preparation
	prep.set_layout(prep.SAVED)
	assert_ne(SettingsService.auto_prepare_mode, prep.SAVED)
	prep.save_layout()
	prep._refresh()
	assert_false(prep.layout_buttons[prep.SAVED].disabled)

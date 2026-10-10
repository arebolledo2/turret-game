extends GutTest

var world: ArenaWorld
var hud: CanvasLayer

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.run_config = RunConfig.slice()
	world.run_config.mode = RunConfig.MODE_CORE
	add_child_autofree(world)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	world.finish_wave()
	EconomyService.total_scrap = 100
	hud = world.hud
	hud._process(0)
	await wait_process_frames(2)

func press_direction(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await wait_process_frames(1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await wait_process_frames(1)

func test_bottom_row_reaches_deploy_and_returns_with_both_repairs_disabled() -> void:
	assert_true(hud.repair_button.disabled)
	assert_true(hud.core_repair_button.disabled)
	hud.reroll_button.grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)
	await press_direction(JOY_BUTTON_DPAD_LEFT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.reroll_button)

func test_enabled_repairs_follow_visual_order_and_update_after_healing() -> void:
	world.player.health -= 10
	world.core.take_hit(10)
	hud._process(0)
	hud.reroll_button.grab_focus()
	for expected: Button in [hud.repair_button, hud.core_repair_button, hud.continue_button]:
		await press_direction(JOY_BUTTON_DPAD_RIGHT)
		assert_same(get_viewport().gui_get_focus_owner(), expected)
	world.core.repair(10)
	hud._process(0)
	await press_direction(JOY_BUTTON_DPAD_LEFT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.repair_button)
	# A repair that becomes disabled while focused must still allow an exit to Deploy.
	world.player.health = world.player.max_health
	hud._process(0)
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)

func test_hidden_core_repair_is_skipped_in_survival() -> void:
	world.core.queue_free()
	world.core = null
	world.player.health -= 10
	hud._process(0)
	hud.repair_button.grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)
	await press_direction(JOY_BUTTON_DPAD_LEFT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.repair_button)

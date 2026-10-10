extends GutTest

var world: ArenaWorld
var hud: ShopScreen

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
	hud = world.hud.shop_screen
	hud.refresh()
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
	hud.refresh()
	hud.reroll_button.grab_focus()
	for expected: Button in [hud.repair_button, hud.core_repair_button, hud.continue_button]:
		await press_direction(JOY_BUTTON_DPAD_RIGHT)
		assert_same(get_viewport().gui_get_focus_owner(), expected)
	world.core.repair(10)
	hud.refresh()
	await press_direction(JOY_BUTTON_DPAD_LEFT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.repair_button)
	# A repair that becomes disabled while focused must still allow an exit to Deploy.
	world.player.health = world.player.max_health
	hud.refresh()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)

func test_hidden_core_repair_is_skipped_in_survival() -> void:
	world.core.queue_free()
	world.core = null
	world.player.health -= 10
	hud.refresh()
	hud.repair_button.grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)
	await press_direction(JOY_BUTTON_DPAD_LEFT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.repair_button)

func test_shop_is_opaque_hides_combat_and_restores_rendering_on_exit() -> void:
	world.hud._process(0)
	assert_true(hud.visible)
	assert_false(world.hud.combat_root.visible)
	assert_true(get_viewport().disable_3d)
	world.begin_next_wave()
	world.hud._process(0)
	assert_false(hud.visible)
	assert_true(world.hud.combat_root.visible)
	assert_false(get_viewport().disable_3d)

func test_purchase_retains_card_slot_and_hands_focus_to_available_offer() -> void:
	EconomyService.current_shop_offers.assign([ShopOffer.new("item", "polished_barrels", 10), ShopOffer.new("item", "capacitor_bank", 10)])
	hud.refresh()
	hud.offer_buttons[0].grab_focus()
	hud._purchase(0)
	assert_true(hud.offer_buttons[0].visible)
	assert_true(hud.offer_buttons[0].disabled)
	assert_same(get_viewport().gui_get_focus_owner(), hud.offer_buttons[1])
	hud._purchase(1)
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)

func test_controller_can_inspect_installed_items_and_return_to_deploy() -> void:
	world.shop.apply_item("polished_barrels")
	world.shop.apply_item("blast_charges")
	hud.refresh()
	hud.offer_buttons[-1].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.owned_buttons[0])
	assert_eq(hud.detail_title.text, "Polished Barrels")
	await press_direction(JOY_BUTTON_DPAD_DOWN)
	assert_same(get_viewport().gui_get_focus_owner(), hud.owned_buttons[1])
	await press_direction(JOY_BUTTON_DPAD_DOWN)
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)

func test_pause_and_dev_overlay_restore_shop_and_focus() -> void:
	world.toggle_pause()
	world.hud._process(0)
	assert_false(hud.visible)
	assert_false(get_viewport().disable_3d)
	world.toggle_pause()
	world.hud._process(0)
	assert_true(hud.visible)
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)
	world.dev_menu_open = true
	world.hud._process(0)
	assert_false(hud.visible)
	world.dev_menu_open = false
	world.hud._process(0)
	assert_true(hud.visible)

func test_installed_items_remain_reachable_after_every_offer_is_sold() -> void:
	world.shop.apply_item("polished_barrels")
	for offer: ShopOffer in EconomyService.current_shop_offers:
		offer.sold = true
	hud.refresh()
	hud.continue_button.grab_focus()
	await press_direction(JOY_BUTTON_DPAD_UP)
	assert_same(get_viewport().gui_get_focus_owner(), hud.owned_buttons[0])
	await press_direction(JOY_BUTTON_DPAD_DOWN)
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)

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
	assert_false(world.hud.combat_root.visible)
	assert_true(world.preparation.active)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.PREPARATION)
	assert_false(get_viewport().disable_3d)

func test_purchase_hides_card_and_hands_focus_to_available_offer() -> void:
	EconomyService.current_shop_offers.assign([ShopOffer.new("item", "polished_barrels", 10), ShopOffer.new("item", "capacitor_bank", 10)])
	hud.refresh()
	hud.offer_buttons[0].grab_focus()
	hud._purchase(0)
	assert_false(hud.offer_buttons[0].visible)
	assert_true(hud.offer_buttons[0].get_parent().visible, "bought slot stays so other cards do not shift")
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

func test_controller_reaches_evolutions_and_resolves_all_earned_stages() -> void:
	world.session.state.turret_progression_enabled = true
	var turret := world.turrets[0]
	turret.progression.award(1500)
	hud.switch_tab(1)
	assert_eq(hud.tabs[1].text, "TURRETS - 1 READY")
	var inspector := hud.turret_inspector
	assert_string_contains(inspector.buttons[0].text, "EVOLUTION READY")
	inspector.buttons[0].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(0))
	await press_direction(JOY_BUTTON_DPAD_DOWN)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(1))
	await press_direction(JOY_BUTTON_DPAD_LEFT)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.buttons[0])
	for stage in range(1, 4):
		await press_direction(JOY_BUTTON_DPAD_RIGHT)
		await press_direction(JOY_BUTTON_A)
		assert_true(inspector.evolution_preview.visible)
		assert_eq(turret.progression.evolution_stage, stage - 1)
		await press_direction(JOY_BUTTON_A)
		assert_eq(turret.progression.evolution_stage, stage)
		assert_same(get_viewport().gui_get_focus_owner(), inspector.buttons[0])
		assert_same(inspector.art.texture, ShopArt.turret("normal", "machine_gun", stage))
	assert_false("EVOLUTION READY" in inspector.buttons[0].text)
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)

func test_selecting_another_turret_rebuilds_evolution_focus_links() -> void:
	world.session.state.turret_progression_enabled = true
	world.turrets[0].progression.award(1500)
	world.add_turret(Vector3(2, 0, 2), "melee")
	hud.switch_tab(1)
	var inspector := hud.turret_inspector
	inspector.buttons[0].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_DOWN)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.buttons[1])
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)
	inspector.buttons[0].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(0))

func test_cancel_evolution_preview_keeps_growth_and_returns_to_roster() -> void:
	world.session.state.turret_progression_enabled = true
	var turret := world.turrets[0]
	turret.progression.award(1500)
	var snapshot := turret.progression.snapshot()
	var model := turret.model
	hud.switch_tab(1)
	var inspector := hud.turret_inspector
	inspector.buttons[0].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	await press_direction(JOY_BUTTON_A)
	assert_true(inspector.evolution_preview.visible)
	await press_direction(JOY_BUTTON_B)
	assert_false(inspector.evolution_preview.visible)
	assert_eq(turret.progression.snapshot(), snapshot)
	assert_same(turret.model, model)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.buttons[0])

func test_deploy_reminder_reviews_first_ready_turret_with_controller() -> void:
	world.session.state.turret_progression_enabled = true
	var turret := world.add_turret(Vector3(2, 0, 2), "melee")
	turret.progression.award(1500)
	hud.refresh()
	hud.continue_button.grab_focus()
	await press_direction(JOY_BUTTON_A)
	assert_true(hud.evolution_reminder.visible)
	assert_true(world.shop.is_open())
	await press_direction(JOY_BUTTON_A)
	assert_false(hud.evolution_reminder.visible)
	assert_eq(hud.active_tab, 1)
	assert_eq(hud.turret_inspector.selected_id, turret.turret_id)
	assert_same(get_viewport().gui_get_focus_owner(), hud.turret_inspector.buttons[1])

func test_deploy_reminder_back_and_skip_preserve_pending_evolution() -> void:
	world.session.state.turret_progression_enabled = true
	var turret := world.turrets[0]
	turret.progression.award(1500)
	var snapshot := turret.progression.snapshot()
	hud.continue_button.grab_focus()
	await press_direction(JOY_BUTTON_A)
	await press_direction(JOY_BUTTON_B)
	assert_false(hud.evolution_reminder.visible)
	assert_true(world.shop.is_open())
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)
	await press_direction(JOY_BUTTON_A)
	await press_direction(JOY_BUTTON_DPAD_LEFT)
	assert_same(hud.evolution_reminder.gui_get_focus_owner(), hud.evolution_reminder.deploy_button)
	await press_direction(JOY_BUTTON_A)
	assert_false(hud.evolution_reminder.visible)
	assert_false(world.shop.is_open())
	assert_eq(turret.progression.snapshot(), snapshot)
	assert_false(turret.available_evolutions().is_empty())

func test_deploy_without_ready_evolutions_does_not_interrupt() -> void:
	hud.continue_button.grab_focus()
	await press_direction(JOY_BUTTON_A)
	assert_false(hud.evolution_reminder.visible)
	assert_false(world.shop.is_open())

func test_controller_moves_between_card_lock_and_nearest_footer_action() -> void:
	hud.offer_buttons[0].grab_focus()
	var lock: Button = hud.offer_buttons[0].lock_button
	assert_true(lock.get_global_rect().position.y >= hud.offer_buttons[0].get_global_rect().end.y)
	await press_direction(JOY_BUTTON_DPAD_DOWN)
	assert_same(get_viewport().gui_get_focus_owner(), lock)
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.offer_buttons[1].lock_button)
	await press_direction(JOY_BUTTON_DPAD_LEFT)
	await press_direction(JOY_BUTTON_DPAD_UP)
	assert_same(get_viewport().gui_get_focus_owner(), hud.offer_buttons[0])
	# The last row leads to the nearest enabled footer action, not always Deploy.
	var bottom_index := 0 if hud.offers_grid.columns == 4 else 2
	hud.offer_buttons[bottom_index].lock_button.grab_focus()
	await press_direction(JOY_BUTTON_DPAD_DOWN)
	assert_same(get_viewport().gui_get_focus_owner(), hud.reroll_button)
	await press_direction(JOY_BUTTON_DPAD_UP)
	assert_same(get_viewport().gui_get_focus_owner(), hud.offer_buttons[bottom_index].lock_button)

func test_purchase_focus_advances_to_next_offer_instead_of_first() -> void:
	EconomyService.current_shop_offers.assign([ShopOffer.new("item", "polished_barrels", 10), ShopOffer.new("item", "capacitor_bank", 10), ShopOffer.new("item", "blast_charges", 10)])
	hud.refresh()
	hud.offer_buttons[1].grab_focus()
	hud._purchase(1)
	assert_same(get_viewport().gui_get_focus_owner(), hud.offer_buttons[2])

func test_turret_pages_keep_roster_visible_and_controller_reaches_next_page() -> void:
	for i in 7: world.add_turret(Vector3(i, 0, 5), "normal")
	hud.switch_tab(1)
	var inspector := hud.turret_inspector
	assert_eq(inspector.visible_buttons().size(), 6)
	assert_false(inspector.next_page.disabled)
	inspector.buttons[0].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_LEFT)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.next_page)
	await press_direction(JOY_BUTTON_A)
	assert_eq(inspector.page, 1)
	assert_eq(inspector.visible_buttons().size(), 2)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.buttons[6])
	assert_true(inspector.next_page.disabled)
	assert_false(inspector.previous_page.disabled)
	await press_direction(JOY_BUTTON_DPAD_DOWN)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.buttons[7])
	await press_direction(JOY_BUTTON_DPAD_DOWN)
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)
	assert_true(inspector.find_children("*", "ScrollContainer", true, false).is_empty())

func test_auto_repair_disables_paid_repairs_and_heals_at_next_wave() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.AUTO_REPAIR, true)
	world.player.health = 1
	world.core.health = 1
	var money := EconomyService.total_scrap
	hud.refresh()
	assert_true(hud.repair_button.disabled)
	assert_true(hud.core_repair_button.disabled)
	assert_false(world.repair())
	assert_false(world.repair_core())
	assert_eq(EconomyService.total_scrap, money)
	world.begin_next_wave()
	assert_eq(world.player.health, world.player.max_health)
	assert_eq(world.core.health, world.core.max_health)
	world.preparation.deploy()
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	world.player.health = 1
	world.core.health = 1
	world.finish_wave()
	assert_eq(world.player.health, world.player.max_health)
	assert_eq(world.core.health, world.core.max_health)
	FeatureFlagService.set_enabled(FeatureFlagService.AUTO_REPAIR, false)

func test_lock_row_exits_left_to_reroll_and_right_to_prepare() -> void:
	# Match the reported case: only the middle two offers remain available.
	EconomyService.current_shop_offers.assign([
		ShopOffer.new("item", "polished_barrels", 10), ShopOffer.new("item", "capacitor_bank", 10),
		ShopOffer.new("item", "blast_charges", 10), ShopOffer.new("item", "scrap_magnet", 10)])
	EconomyService.current_shop_offers[0].sold = true
	EconomyService.current_shop_offers[3].sold = true
	hud.refresh()
	await wait_process_frames(2)
	hud.offer_buttons[1].lock_button.grab_focus()
	await press_direction(JOY_BUTTON_DPAD_LEFT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.reroll_button)
	hud.offer_buttons[2].lock_button.grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)
	# An unaffordable reroll must not trap focus at the left edge either.
	EconomyService.total_scrap = 0
	hud.refresh()
	hud.offer_buttons[1].lock_button.grab_focus()
	await press_direction(JOY_BUTTON_DPAD_LEFT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)

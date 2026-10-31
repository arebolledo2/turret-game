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

func test_bottom_row_reaches_deploy_and_returns() -> void:
	hud.reroll_button.grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)
	await press_direction(JOY_BUTTON_DPAD_LEFT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.reroll_button)

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
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", "plasma", 10), ShopOffer.new("item", "capacitor_bank", 10),
		ShopOffer.new("item", "dense_rounds", 10), ShopOffer.new("item", "quick_loader", 10)])
	hud.refresh()
	hud.offer_buttons[3].grab_focus()
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
	assert_eq(inspector.evolution_choices.get_child_count(), 1, "Level 5 offers a single upgrade")
	inspector.buttons[0].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(0))
	await press_direction(JOY_BUTTON_DPAD_LEFT)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.buttons[0])
	var forms: Array[String] = ["machine_gun", "cyclone_gatling"]
	for stage in range(1, 3):
		await press_direction(JOY_BUTTON_DPAD_RIGHT)
		if stage == 2:
			assert_eq(inspector.evolution_choices.get_child_count(), 2, "Level 10 offers both finals")
			await press_direction(JOY_BUTTON_DPAD_DOWN)
			assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(1))
			await press_direction(JOY_BUTTON_DPAD_UP)
			assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(0))
		await press_direction(JOY_BUTTON_A)
		assert_true(inspector.evolution_preview.visible)
		assert_eq(turret.progression.evolution_stage, stage - 1)
		await press_direction(JOY_BUTTON_A)
		assert_eq(turret.progression.evolution_stage, stage)
		assert_eq(turret.progression.evolution_form, forms[stage - 1])
		assert_same(get_viewport().gui_get_focus_owner(), inspector.buttons[0])
		assert_same(inspector.art.texture, ShopArt.turret("normal", forms[stage - 1]))
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
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", "plasma", 10), ShopOffer.new("item", "capacitor_bank", 10),
		ShopOffer.new("item", "dense_rounds", 10), ShopOffer.new("item", "quick_loader", 10)])
	hud.refresh()
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

func test_core_and_hero_are_healed_between_waves() -> void:
	world.player.health = 1
	world.core.health = 1
	var money := EconomyService.total_scrap
	hud.refresh()
	world.begin_next_wave()
	assert_eq(world.player.health, world.player.max_health)
	assert_eq(world.core.health, world.core.max_health)
	assert_eq(EconomyService.total_scrap, money, "Healing is free")
	world.preparation.deploy()
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	world.player.health = 1
	world.core.health = 1
	world.finish_wave()
	assert_eq(world.player.health, world.player.max_health)
	assert_eq(world.core.health, world.core.max_health)

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

func test_controller_reaches_the_sniper_upgrade_and_overwatch_final() -> void:
	world.session.state.turret_progression_enabled = true
	var sniper := world.add_turret(Vector3(2, 0, 2), "sniper")
	sniper.progression.award(1500)
	hud.refresh()
	hud.switch_tab(1)
	var inspector := hud.turret_inspector
	inspector.select(sniper.turret_id)
	await wait_process_frames(2)
	var button_index := world.turrets.find(sniper)
	assert_string_contains(inspector.buttons[button_index].text, "EVOLUTION READY")
	assert_string_contains(inspector.detail.text, "Level 5  ·  Evolution ready")
	assert_eq(inspector.evolution_choices.get_child_count(), 1, "Level 5 offers the Piercer Rifle")
	assert_string_contains(inspector.evolution_choices.get_child(0).text, "Piercer Rifle")
	inspector.buttons[button_index].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(0))
	await press_direction(JOY_BUTTON_A)
	assert_true(inspector.evolution_preview.visible)
	await press_direction(JOY_BUTTON_A)
	assert_eq(sniper.progression.evolution_form, "piercer_rifle")
	inspector.select(sniper.turret_id)
	await wait_process_frames(2)
	assert_string_contains(inspector.detail.text, "Level 5  ·  Piercer Rifle")
	assert_string_contains(inspector.detail.text, "Level 10  ·  Evolution ready")
	assert_eq(inspector.evolution_choices.get_child_count(), 2, "Level 10 offers both finals")
	assert_string_contains(inspector.evolution_choices.get_child(0).text, "Horizon Piercer")
	assert_string_contains(inspector.evolution_choices.get_child(1).text, "Overwatch")
	inspector.buttons[button_index].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	await press_direction(JOY_BUTTON_DPAD_DOWN)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(1))
	await press_direction(JOY_BUTTON_A)
	assert_true(inspector.evolution_preview.visible)
	await press_direction(JOY_BUTTON_A)
	assert_eq(sniper.progression.evolution_form, "overwatch")
	assert_same(inspector.art.texture, ShopArt.turret("sniper", "overwatch"))
	assert_false("EVOLUTION READY" in inspector.buttons[button_index].text)

func test_controller_reaches_the_quake_upgrade_and_tectonic_final() -> void:
	world.session.state.turret_progression_enabled = true
	var quake := world.add_turret(Vector3(2, 0, 2), "quake")
	quake.progression.award(1500)
	hud.refresh()
	hud.switch_tab(1)
	var inspector := hud.turret_inspector
	inspector.select(quake.turret_id)
	await wait_process_frames(2)
	var button_index := world.turrets.find(quake)
	assert_string_contains(inspector.buttons[button_index].text, "EVOLUTION READY")
	assert_eq(inspector.evolution_choices.get_child_count(), 1, "Level 5 offers Aftershock")
	assert_string_contains(inspector.evolution_choices.get_child(0).text, "Aftershock")
	inspector.buttons[button_index].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(0))
	await press_direction(JOY_BUTTON_A)
	assert_true(inspector.evolution_preview.visible)
	await press_direction(JOY_BUTTON_A)
	assert_eq(quake.progression.evolution_form, "aftershock")
	inspector.select(quake.turret_id)
	await wait_process_frames(2)
	assert_string_contains(inspector.detail.text, "Level 5  ·  Aftershock")
	assert_eq(inspector.evolution_choices.get_child_count(), 2, "Level 10 offers both finals")
	assert_string_contains(inspector.evolution_choices.get_child(0).text, "Tectonic")
	assert_string_contains(inspector.evolution_choices.get_child(1).text, "Cataclysm")
	inspector.buttons[button_index].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	await press_direction(JOY_BUTTON_A)
	assert_true(inspector.evolution_preview.visible)
	await press_direction(JOY_BUTTON_A)
	assert_eq(quake.progression.evolution_form, "tectonic")
	assert_same(inspector.art.texture, ShopArt.turret("quake", "tectonic"))
	assert_false("EVOLUTION READY" in inspector.buttons[button_index].text)

func test_controller_reaches_the_decoy_upgrade_and_maelstrom_final() -> void:
	world.session.state.turret_progression_enabled = true
	var decoy := world.add_turret(Vector3(2, 0, 2), "decoy")
	decoy.progression.award(1500)
	hud.refresh()
	hud.switch_tab(1)
	var inspector := hud.turret_inspector
	inspector.select(decoy.turret_id)
	await wait_process_frames(2)
	var button_index := world.turrets.find(decoy)
	assert_string_contains(inspector.buttons[button_index].text, "EVOLUTION READY")
	assert_eq(inspector.evolution_choices.get_child_count(), 1, "Level 5 offers Bumper Post")
	assert_string_contains(inspector.evolution_choices.get_child(0).text, "Bumper Post")
	inspector.buttons[button_index].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(0))
	await press_direction(JOY_BUTTON_A)
	assert_true(inspector.evolution_preview.visible)
	assert_string_contains(inspector.evolution_preview.comparison.text, "Taunt radius")
	await press_direction(JOY_BUTTON_A)
	assert_eq(decoy.progression.evolution_form, "bumper_post")
	inspector.select(decoy.turret_id)
	await wait_process_frames(2)
	assert_string_contains(inspector.detail.text, "Level 5  ·  Bumper Post")
	assert_string_contains(inspector.detail.text, "Taunt radius")
	assert_eq(inspector.evolution_choices.get_child_count(), 2, "Level 10 offers both finals")
	assert_string_contains(inspector.evolution_choices.get_child(0).text, "Pile Driver")
	assert_string_contains(inspector.evolution_choices.get_child(1).text, "Maelstrom")
	inspector.buttons[button_index].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	await press_direction(JOY_BUTTON_DPAD_DOWN)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(1))
	await press_direction(JOY_BUTTON_A)
	assert_true(inspector.evolution_preview.visible)
	await press_direction(JOY_BUTTON_A)
	assert_eq(decoy.progression.evolution_form, "maelstrom")
	assert_same(inspector.art.texture, ShopArt.turret("decoy", "maelstrom"))
	assert_false("EVOLUTION READY" in inspector.buttons[button_index].text)

func test_controller_reaches_the_scrap_press_upgrade_and_academy_final() -> void:
	world.session.state.turret_progression_enabled = true
	var press := world.add_turret(Vector3(2, 0, 2), "scrap_press")
	press.progression.award(1500)
	hud.refresh()
	hud.switch_tab(1)
	var inspector := hud.turret_inspector
	inspector.select(press.turret_id)
	await wait_process_frames(2)
	var button_index := world.turrets.find(press)
	assert_string_contains(inspector.buttons[button_index].text, "EVOLUTION READY")
	assert_eq(inspector.evolution_choices.get_child_count(), 1, "Level 5 offers Coin Feeder")
	assert_string_contains(inspector.evolution_choices.get_child(0).text, "Coin Feeder")
	assert_string_contains(inspector.detail.text, "Does not attack")
	assert_false("Knockback" in inspector.detail.text, "A turret with no attack shows no combat lines")
	inspector.buttons[button_index].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(0))
	await press_direction(JOY_BUTTON_A)
	assert_true(inspector.evolution_preview.visible)
	assert_string_contains(inspector.evolution_preview.comparison.text, "Drop every")
	assert_string_contains(inspector.evolution_preview.comparison.text, "wallet")
	await press_direction(JOY_BUTTON_A)
	assert_eq(press.progression.evolution_form, "coin_feeder")
	inspector.select(press.turret_id)
	await wait_process_frames(2)
	assert_string_contains(inspector.detail.text, "Level 5  ·  Coin Feeder")
	assert_eq(inspector.evolution_choices.get_child_count(), 2, "Level 10 offers both finals")
	assert_string_contains(inspector.evolution_choices.get_child(0).text, "Treasury")
	assert_string_contains(inspector.evolution_choices.get_child(1).text, "Academy")
	inspector.buttons[button_index].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	await press_direction(JOY_BUTTON_DPAD_DOWN)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(1))
	await press_direction(JOY_BUTTON_A)
	assert_true(inspector.evolution_preview.visible)
	assert_string_contains(inspector.evolution_preview.comparison.text, "XP")
	await press_direction(JOY_BUTTON_A)
	assert_eq(press.progression.evolution_form, "academy")
	assert_same(inspector.art.texture, ShopArt.turret("scrap_press", "academy"))
	assert_false("EVOLUTION READY" in inspector.buttons[button_index].text)

func test_controller_reaches_the_mine_layer_upgrade_and_chain_reaction_final() -> void:
	world.session.state.turret_progression_enabled = true
	var layer := world.add_turret(Vector3(2, 0, 2), "mine_layer")
	layer.progression.award(1500)
	hud.refresh()
	hud.switch_tab(1)
	var inspector := hud.turret_inspector
	inspector.select(layer.turret_id)
	await wait_process_frames(2)
	var button_index := world.turrets.find(layer)
	assert_string_contains(inspector.buttons[button_index].text, "EVOLUTION READY")
	assert_eq(inspector.evolution_choices.get_child_count(), 1, "Level 5 offers Minefield")
	assert_string_contains(inspector.evolution_choices.get_child(0).text, "Minefield")
	assert_string_contains(inspector.detail.text, "Lays a mine every")
	inspector.buttons[button_index].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(0))
	await press_direction(JOY_BUTTON_A)
	assert_true(inspector.evolution_preview.visible)
	assert_string_contains(inspector.evolution_preview.comparison.text, "Mines out at once")
	await press_direction(JOY_BUTTON_A)
	assert_eq(layer.progression.evolution_form, "minefield")
	inspector.select(layer.turret_id)
	await wait_process_frames(2)
	assert_string_contains(inspector.detail.text, "Level 5  ·  Minefield")
	assert_eq(inspector.evolution_choices.get_child_count(), 2, "Level 10 offers both finals")
	assert_string_contains(inspector.evolution_choices.get_child(0).text, "Dead Zone")
	assert_string_contains(inspector.evolution_choices.get_child(1).text, "Chain Reaction")
	inspector.buttons[button_index].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	await press_direction(JOY_BUTTON_DPAD_DOWN)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(1))
	await press_direction(JOY_BUTTON_A)
	assert_true(inspector.evolution_preview.visible)
	assert_string_contains(inspector.evolution_preview.comparison.text, "Limpets out at once")
	await press_direction(JOY_BUTTON_A)
	assert_eq(layer.progression.evolution_form, "chain_reaction")
	assert_same(inspector.art.texture, ShopArt.turret("mine_layer", "chain_reaction"))
	assert_false("EVOLUTION READY" in inspector.buttons[button_index].text)

func test_controller_reaches_the_laser_upgrade_and_sunpiercer_final() -> void:
	world.session.state.turret_progression_enabled = true
	var laser := world.add_turret(Vector3(2, 0, 2), "laser")
	laser.progression.award(1500)
	hud.refresh()
	hud.switch_tab(1)
	var inspector := hud.turret_inspector
	inspector.select(laser.turret_id)
	await wait_process_frames(2)
	var button_index := world.turrets.find(laser)
	assert_string_contains(inspector.buttons[button_index].text, "EVOLUTION READY")
	assert_eq(inspector.evolution_choices.get_child_count(), 1, "Level 5 offers Focus Beam")
	assert_string_contains(inspector.evolution_choices.get_child(0).text, "Focus Beam")
	assert_string_contains(inspector.detail.text, "ticks/s")
	assert_string_contains(inspector.detail.text, "DPS")
	inspector.buttons[button_index].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(0))
	await press_direction(JOY_BUTTON_A)
	assert_true(inspector.evolution_preview.visible)
	assert_string_contains(inspector.evolution_preview.comparison.text, "Damage per tick")
	await press_direction(JOY_BUTTON_A)
	assert_eq(laser.progression.evolution_form, "focus_beam")
	inspector.select(laser.turret_id)
	await wait_process_frames(2)
	assert_string_contains(inspector.detail.text, "Level 5  ·  Focus Beam")
	assert_eq(inspector.evolution_choices.get_child_count(), 2, "Level 10 offers both finals")
	assert_string_contains(inspector.evolution_choices.get_child(0).text, "Halo Cutter")
	assert_string_contains(inspector.evolution_choices.get_child(1).text, "Sunpiercer")
	inspector.buttons[button_index].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	await press_direction(JOY_BUTTON_DPAD_DOWN)
	assert_same(get_viewport().gui_get_focus_owner(), inspector.evolution_choices.get_child(1))
	await press_direction(JOY_BUTTON_A)
	assert_true(inspector.evolution_preview.visible)
	assert_string_contains(inspector.evolution_preview.comparison.text, "flare")
	await press_direction(JOY_BUTTON_A)
	assert_eq(laser.progression.evolution_form, "sunpiercer")
	assert_same(inspector.art.texture, ShopArt.turret("laser", "sunpiercer"))
	assert_false("EVOLUTION READY" in inspector.buttons[button_index].text)

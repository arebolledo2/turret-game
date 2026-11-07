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

func test_reroll_reaches_prepare_and_prepare_climbs_to_the_squad() -> void:
	hud.reroll_button.grab_focus()
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.continue_button)
	await press_direction(JOY_BUTTON_DPAD_UP)
	assert_same(get_viewport().gui_get_focus_owner(), hud.squad_cards.back())

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
	await wait_process_frames(2)
	hud.squad_cards[0].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_DOWN)
	assert_has(hud.owned_buttons, get_viewport().gui_get_focus_owner(), "down from the squad reaches the items")
	hud.owned_buttons[0].grab_focus()
	await wait_process_frames(1)
	assert_eq(hud.detail_title.text, "Polished Barrels")
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
	assert_same(get_viewport().gui_get_focus_owner(), hud.owned_buttons[1])
	assert_eq(hud.detail_title.text, "Blast Charges")
	await press_direction(JOY_BUTTON_DPAD_RIGHT)
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
	# The last lock row leads down to the squad, and back up to the nearest lock.
	var bottom_index := 0 if hud.offers_grid.columns == 4 else 2
	hud.offer_buttons[bottom_index].lock_button.grab_focus()
	await press_direction(JOY_BUTTON_DPAD_DOWN)
	assert_same(get_viewport().gui_get_focus_owner(), hud.squad_cards[0])
	await press_direction(JOY_BUTTON_DPAD_UP)
	assert_same(get_viewport().gui_get_focus_owner(), hud.offer_buttons[bottom_index].lock_button)
	hud.offer_buttons[0].grab_focus()
	await press_direction(JOY_BUTTON_DPAD_UP)
	assert_same(get_viewport().gui_get_focus_owner(), hud.reroll_button)

func test_purchase_focus_advances_to_next_offer_instead_of_first() -> void:
	EconomyService.current_shop_offers.assign([ShopOffer.new("item", "polished_barrels", 10), ShopOffer.new("item", "capacitor_bank", 10), ShopOffer.new("item", "blast_charges", 10)])
	hud.refresh()
	hud.offer_buttons[1].grab_focus()
	hud._purchase(1)
	assert_same(get_viewport().gui_get_focus_owner(), hud.offer_buttons[2])

func test_turret_pages_keep_roster_visible_and_controller_reaches_next_page() -> void:
	for i in 7: world.add_turret(Vector3(i, 0, 5), "normal")
	hud.open_turret_details()
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
	assert_same(get_viewport().gui_get_focus_owner(), hud.details_modal.close_button)
	assert_true(inspector.find_children("*", "ScrollContainer", true, false).is_empty())
	await press_direction(JOY_BUTTON_B)
	assert_false(hud.details_modal.visible, "B closes the details")
	assert_true(get_viewport().gui_get_focus_owner() is SquadCard, "focus returns to the squad")

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


## Each row: base turret, upgrade, [finals], the final taken, a comparison line expected for the upgrade and for the final.
const EVOLUTION_PATHS: Array = [
	["sniper", "piercer_rifle", ["horizon_piercer", "overwatch"], "overwatch", "", ""],
	["quake", "aftershock", ["tectonic", "cataclysm"], "tectonic", "", ""],
	["decoy", "bumper_post", ["pile_driver", "maelstrom"], "maelstrom", "Taunt radius", ""],
	["scrap_press", "coin_feeder", ["treasury", "academy"], "academy", "Drop every", "XP"],
	["mine_layer", "minefield", ["dead_zone", "chain_reaction"], "chain_reaction", "Mines out at once", "Limpets out at once"],
	["laser", "focus_beam", ["halo_cutter", "sunpiercer"], "sunpiercer", "Damage per tick", "flare"],
	["drone_bay", "escort_drones", ["guardian_wing", "reaper_swarm"], "reaper_swarm", "Drones", "Kites"],
]

func test_each_evolution_path_offers_its_forms_and_the_inspector_shows_them() -> void:
	world.session.state.turret_progression_enabled = true
	hud.open_turret_details()
	var inspector := hud.turret_inspector
	for path: Array in EVOLUTION_PATHS:
		var turret := world.add_turret(Vector3(2, 0, 2), str(path[0]))
		turret.progression.award(1500)
		hud.refresh()
		inspector.select(turret.turret_id)
		await wait_process_frames(2)
		assert_eq(turret.available_evolutions(), [path[1]] as Array[String], "%s level 5 offers its upgrade" % path[0])
		assert_string_contains(inspector.detail.text, "Evolves after the wave")
		if str(path[4]) != "":
			assert_string_contains(EvolutionComparison.text(turret, path[1]), str(path[4]), "%s upgrade comparison" % path[0])
		assert_true(turret.evolve(path[1]))
		inspector.select(turret.turret_id)
		await wait_process_frames(2)
		assert_string_contains(inspector.detail.text, "Level 5  ·  %s" % TurretEvolution.form_name(path[1]))
		assert_eq(turret.available_evolutions(), path[2] as Array[String], "%s level 10 offers both finals" % path[0])
		if str(path[5]) != "":
			assert_string_contains(EvolutionComparison.text(turret, path[3]), str(path[5]), "%s final comparison" % path[0])
		assert_true(turret.evolve(path[3]))
		assert_eq(turret.progression.evolution_form, path[3])
		inspector.select(turret.turret_id)
		await wait_process_frames(2)
		assert_same(inspector.art.texture, ShopArt.turret(str(path[0]), str(path[3])))
		assert_true(turret.available_evolutions().is_empty())

func test_squad_cards_open_details_and_show_what_the_focused_offer_does() -> void:
	EconomyService.current_shop_offers.assign([ShopOffer.new("item", "rapid_coolant", 10), ShopOffer.new("item", "gamblers_crown", 10),
		ShopOffer.new("item", "blast_charges", 10), ShopOffer.new("item", "polished_barrels", 10)])
	hud.refresh()
	var card: SquadCard = hud.squad_cards[0]
	assert_eq(card.turret_id, world.turrets[0].turret_id)
	assert_false(card.impact_badge.visible, "no offer focused: no highlight")
	hud._select(0)
	assert_true(card.impact_badge.visible)
	assert_eq((card.get_theme_stylebox("normal") as StyleBoxFlat).border_color, UiPalette.GOOD)
	hud._select(1)
	assert_eq((card.get_theme_stylebox("normal") as StyleBoxFlat).border_color, UiPalette.BAD)
	hud._select(2)
	assert_false(card.impact_badge.visible, "an AoE item leaves the Ion alone")
	assert_lt(card.modulate.a, 1.0, "untouched turrets dim while an offer is focused")
	card.pressed.emit()
	assert_true(hud.details_modal.visible)
	assert_eq(hud.turret_inspector.selected_id, card.turret_id)
	hud.close_turret_details()
	assert_false(hud.details_modal.visible)

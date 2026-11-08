extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	add_child_autofree(world)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	world.finish_wave()
	EconomyService.total_scrap = 1000

func _offer(type_id: String, level: int, form: String = "") -> ShopOffer:
	var offer := ShopOffer.new("turret", type_id, 0, level, form)
	offer.price = world.shop.offer_price(offer)
	EconomyService.current_shop_offers.assign([offer])
	return offer

func _bought(type_id: String, level: int, form: String = "") -> TurretActor:
	_offer(type_id, level, form)
	assert_true(world.shop.purchase(0))
	return world.turrets.back()

func test_level_prices_grow_by_a_set_share_of_the_base_price_per_level() -> void:
	var base := world.turret_price("plasma")
	assert_eq(_offer("plasma", 1).price, base)
	assert_eq(_offer("plasma", 5).price, roundi(base * 2.4))
	assert_eq(_offer("plasma", 9).price, roundi(base * 3.8))

func test_buying_then_selling_loses_about_half() -> void:
	for level in [1, 3, 5, 9]:
		var offer := _offer("plasma", level)
		var before := EconomyService.total_scrap
		assert_true(world.shop.purchase(0))
		var turret: TurretActor = world.turrets.back()
		var paid := before - EconomyService.total_scrap
		assert_eq(paid, offer.price)
		var value := ArenaShop.sell_value(turret)
		assert_between(float(value) / paid, .4, .5, "Level %d sells for about half" % level)
		assert_true(world.shop.sell(turret.turret_id))
		assert_eq(EconomyService.total_scrap, before - paid + value)
	await wait_process_frames(2)

func test_a_turret_breaks_even_after_three_level_ups() -> void:
	var turret := _bought("plasma", 1)
	var paid := 1000 - EconomyService.total_scrap
	turret.progression.start_at(3, "")
	assert_lt(ArenaShop.sell_value(turret), paid)
	turret.progression.start_at(4, "")
	assert_gte(ArenaShop.sell_value(turret), paid - 1)
	turret.progression.start_at(9, "")
	assert_gt(ArenaShop.sell_value(turret), paid * 1.4)

func test_sale_value_ignores_later_price_changes() -> void:
	var turret := _bought("plasma", 5)
	var value := ArenaShop.sell_value(turret)
	GameStateService.current_wave = 20
	assert_eq(ArenaShop.sell_value(turret), value)

func test_sell_removes_the_turret_everywhere_and_lowers_the_surcharge() -> void:
	var acquired := world.session.state.additional_turrets_acquired
	var counted := int(TurretStatsService.turret_counts.get("plasma", 0))
	var turret := _bought("plasma", 1)
	var id := turret.turret_id
	assert_eq(world.session.state.additional_turrets_acquired, acquired + 1)
	assert_true(world.shop.sell(id))
	assert_does_not_have(world.turrets, turret)
	assert_false(world.session.state.turret_progression.has(id))
	assert_eq(int(TurretStatsService.turret_counts.get("plasma", 0)), counted)
	assert_eq(world.session.state.additional_turrets_acquired, acquired)
	assert_eq(GameStateService.turrets_spawned, world.turrets.size())
	await wait_process_frames(1)
	assert_false(is_instance_valid(turret))
	assert_false(world.shop.sell(id), "Already gone")

func test_starting_turret_sells_for_half_its_base_price_without_touching_the_surcharge() -> void:
	var starter := world.turrets[0]
	var acquired := world.session.state.additional_turrets_acquired
	assert_eq(ArenaShop.sell_value(starter), floori(TurretRegistry.get_base_price(starter.turret_type) * .5))
	assert_true(world.shop.sell(starter.turret_id))
	assert_eq(world.session.state.additional_turrets_acquired, acquired)
	await wait_process_frames(2)

func test_cannot_sell_outside_the_shop() -> void:
	var starter := world.turrets[0]
	world.begin_next_wave()
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	assert_false(world.shop.sell(starter.turret_id))
	assert_has(world.turrets, starter)

func test_evolved_purchase_arrives_evolved_and_levelled() -> void:
	var upgrade := TurretEvolution.options("plasma", 0)[0]
	var turret := _bought("plasma", 6, upgrade)
	assert_eq(turret.progression.level, 6)
	assert_eq(turret.progression.evolution_form, upgrade)
	assert_eq(turret.progression.evolution_stage, 1)
	assert_true(turret.progression.pending_evolutions.is_empty())
	assert_eq(turret.display_name(), TurretEvolution.form_name(upgrade))
	assert_gt(turret.progression.total_xp, 0)

func test_level_ten_offers_a_final_form_and_later_levels_still_progress() -> void:
	var finals := ArenaShop.obtainable_forms("plasma", 1)
	assert_false(finals.is_empty())
	var turret := _bought("plasma", 10, finals[0])
	assert_eq(turret.progression.evolution_stage, 2)
	assert_eq(turret.progression.evolution_form, finals[0])
	turret.progression.award(1000)
	assert_true(turret.progression.pending_evolutions.is_empty(), "No second evolution queued behind a bought one")

func test_rolled_levels_favour_low_levels_and_forms_match_levels() -> void:
	world.session.state.turret_progression_enabled = true
	world.session.state.current_wave = 30
	var counts := {}
	for i in 3000:
		var level := world.shop.roll_turret_level("plasma")
		counts[level] = int(counts.get(level, 0)) + 1
		var form := world.shop.roll_turret_form("plasma", level)
		assert_eq(form.is_empty(), level < 5, "Evolved from level 5 (level %d)" % level)
	assert_gt(counts[1], counts[2])
	assert_gt(counts[2], counts.get(4, 0))
	assert_between(float(counts[1]) / 3000.0, .48, .62)
	assert_lte(counts.keys().max(), ArenaShop.max_offer_level("plasma"))

func test_turrets_are_not_offered_past_a_milestone_they_cannot_evolve_through() -> void:
	assert_eq(ArenaShop.max_offer_level("tesla"), GameConstants.SHOP_TURRET_MAX_LEVEL, "Tesla has built forms at both milestones")
	for type_id in ArenaShop.TURRETS:
		var top := ArenaShop.max_offer_level(type_id)
		assert_gte(top, 4)
		if top >= 5:
			assert_false(ArenaShop.obtainable_forms(type_id, 0).is_empty())
		if top >= 10:
			assert_false(ArenaShop.obtainable_forms(type_id, 1).is_empty())

func test_levels_are_always_one_without_turret_growth() -> void:
	world.session.state.turret_progression_enabled = false
	for i in 50:
		assert_eq(world.shop.roll_turret_level("plasma"), 1)

func test_locked_leveled_offer_keeps_its_level_across_rerolls() -> void:
	var offer := _offer("plasma", 7, TurretEvolution.options("plasma", 0)[0])
	EconomyService.current_shop_offers.append(ShopOffer.new("item", "scrap_magnet", 1))
	assert_true(world.shop.toggle_lock(0))
	assert_true(world.shop.reroll())
	assert_has(EconomyService.current_shop_offers, offer)
	assert_eq(offer.level, 7)

func test_sell_button_arms_then_sells() -> void:
	var shop: ShopScreen = world.hud.shop_screen
	shop.open_turret_details()
	var inspector := shop.turret_inspector
	var starter := world.turrets[0]
	var before := EconomyService.total_scrap
	inspector.select(starter.turret_id)
	assert_true(inspector.sell_button.visible)
	assert_string_contains(inspector.sell_button.text, "SELL")
	inspector.sell_button.pressed.emit()
	assert_string_contains(inspector.sell_button.text, "CONFIRM")
	assert_has(world.turrets, starter, "First press only arms the sale")
	inspector.sell_button.pressed.emit()
	assert_does_not_have(world.turrets, starter)
	assert_eq(EconomyService.total_scrap, before + floori(TurretRegistry.get_base_price(starter.turret_type) * .5))
	await wait_process_frames(2)

func test_wave_caps_the_best_level_on_offer() -> void:
	world.session.state.turret_progression_enabled = true
	world.session.state.current_wave = 2
	for i in 2000:
		assert_lte(world.shop.roll_turret_level("plasma"), 3)

func test_luck_shifts_rolled_turret_levels() -> void:
	world.session.state.turret_progression_enabled = true
	world.session.state.current_wave = 30
	var average := func(points: int) -> float:
		PlayerStatsService.player_luck = points
		var total := 0.0
		for i in 2000:
			total += world.shop.roll_turret_level("plasma")
		return total / 2000.0
	var unlucky: float = average.call(-30)
	var neutral: float = average.call(0)
	var lucky: float = average.call(30)
	assert_lt(unlucky, neutral, "Negative luck lowers rolled levels")
	assert_gt(lucky, neutral, "Positive luck raises rolled levels")

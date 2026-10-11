extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child_autofree(world)
	world.start_run()
	_freeze()

func _freeze() -> void:
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	for turret in world.turrets:
		turret.set_physics_process(false)
	world.pickup_root.process_mode = Node.PROCESS_MODE_DISABLED
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)

func _scrap(amount: int, at: Vector3 = Vector3(10, 0, 8)) -> ScrapPickup:
	var pickup := ScrapPickup.new()
	pickup.world = world
	pickup.amount = amount
	pickup.position = at
	world.pickup_root.add_child(pickup)
	return pickup

func _settle_only() -> bool:
	GameStateMachine.force_transition(GameStateMachine.GameState.WAVE_END)
	return world.salvage.settle(GameStateService.current_wave)

func test_wave_end_awards_raw_xp_and_cash_bonus_once() -> void:
	var collected := _scrap(3)
	collected.collect()
	var deleted := _scrap(99)
	deleted.queue_free()
	var leftover := _scrap(903)
	var before := EconomyService.total_scrap
	assert_true(world.finish_wave())
	assert_eq(EconomyService.total_scrap, before + 5)
	assert_true(leftover.collected)
	assert_eq(world.turrets[0].progression.level, 15)
	assert_eq(world.turrets[0].progression.xp, 7)
	assert_eq(world.turrets[0].progression.pending_evolutions, [5, 10, 15])
	assert_eq(world.salvage.last_settlement.raw_scrap, 903)
	assert_eq(world.telemetry.total("turret_xp"), 903)
	assert_false(world.finish_wave())
	assert_false(_settle_only(), "Even direct re-entry cannot settle this wave twice")
	assert_eq(world.turrets[0].progression.total_xp, 903)
	assert_eq(EconomyService.total_scrap, before + 5)
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	assert_true(world.begin_next_wave())
	assert_eq(world.build_zones.bonus_slots, 0)
	assert_eq(world.build_zones.wave_tier, 0)

func test_carried_position_is_snapshotted_before_automatic_drop() -> void:
	var turret := world.turrets[0]
	world.placement.carried = turret
	turret.carried = true
	turret.position = Vector3(9, 2, 6)
	_scrap(20, turret.position)
	assert_true(world.finish_wave())
	var target: Dictionary = world.salvage.last_settlement.targets[0]
	assert_eq(target.position, Vector3(9, 2, 6))
	assert_true(target.carried)
	assert_false(turret.carried)
	assert_eq(turret.progression.level, 2)

func test_weighted_allocation_conserves_units_and_uses_independent_rng() -> void:
	world.turrets[0].position = Vector3.ZERO
	var distant := world.add_turret(Vector3(12, 0, 0))
	distant.set_physics_process(false)
	_scrap(10000, Vector3.ZERO)
	var random_before := GameRandom.gameplay.state
	assert_true(_settle_only())
	assert_eq(GameRandom.gameplay.state, random_before)
	var near_xp := world.turrets[0].progression.total_xp
	var far_xp := distant.progression.total_xp
	assert_eq(near_xp + far_xp, 10000)
	assert_between(near_xp, 7900, 8500, "Expected near share ~82%, with random variation")
	assert_gt(far_xp, 0)

func test_pickup_chunking_and_seed_are_reproducible() -> void:
	var other := world.add_turret(Vector3(6, 0, 0))
	other.set_physics_process(false)
	world.salvage.reset(1234)
	var bulk := _scrap(100)
	_settle_only()
	var allocations: Dictionary = world.salvage.last_settlement.pickups[0].allocations.duplicate()
	bulk.free()
	world.salvage.reset(1234)
	for unit in 100:
		_scrap(1)
	_settle_only()
	var actual := {}
	for entry: Dictionary in world.salvage.last_settlement.pickups:
		for id: int in entry.allocations:
			actual[id] = int(actual.get(id, 0)) + int(entry.allocations[id])
	assert_eq(actual, allocations)

func test_no_turrets_falls_back_to_normal_cash() -> void:
	world.turrets.clear()
	_scrap(20)
	var before := EconomyService.total_scrap
	assert_true(_settle_only())
	assert_eq(EconomyService.total_scrap, before + 20)
	assert_eq(world.salvage.last_settlement.fallback_cash, 20)
	assert_eq(world.salvage.last_settlement.xp_awarded, 0)

func test_earning_modifiers_apply_to_cash_but_never_salvage_xp() -> void:
	ModifierService.add_modifiers([Item.create_modifier("scrap_earn_mult", "increase", 1.0)])
	var before := EconomyService.total_scrap
	_scrap(10).collect()
	assert_eq(EconomyService.total_scrap, before + 20)
	_scrap(10)
	world.finish_wave()
	assert_eq(world.turrets[0].progression.total_xp, 10)
	assert_eq(EconomyService.total_scrap, before + 30, "Wave bonus still follows normal money multipliers")

func test_defeat_and_cleanup_do_not_award_and_restart_clears_growth() -> void:
	_scrap(100)
	world._end_run_in_defeat("test")
	assert_false(world.finish_wave())
	assert_false(_settle_only())
	assert_eq(world.turrets[0].progression.total_xp, 0)
	world.start_run()
	_freeze()
	assert_eq(world.pickup_root.get_child_count(), 0)
	assert_eq(world.session.state.additional_turrets_acquired, 0)
	_scrap(100)
	world.finish_wave()
	assert_gt(world.turrets[0].progression.level, 1)
	world.start_run()
	assert_eq(world.turrets[0].progression.level, 1)
	assert_true(world.salvage.settlements.is_empty())
	assert_eq(world.session.state.turret_progression.size(), 1)

func test_dev_jump_discards_scrap_without_growth() -> void:
	_scrap(500)
	assert_true(world.dev.jump_to_wave(7))
	assert_eq(world.turrets[0].progression.total_xp, 0)
	assert_true(world.salvage.settlements.is_empty())

func test_victory_settles_without_waiting_for_evolution_choices() -> void:
	world.wave_limit = 1
	_scrap(896)
	assert_true(world.finish_wave())
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.VICTORY)
	assert_eq(world.turrets[0].progression.level, 15)
	assert_false(GameStateService.is_game_active)

func test_run_latches_flag_and_off_preserves_legacy_banking() -> void:
	FeatureFlagService.request_enabled(FeatureFlagService.TURRET_PROGRESSION, false)
	_scrap(20)
	world.finish_wave()
	assert_eq(world.turrets[0].progression.level, 2)
	assert_true(world.session.state.turret_progression_enabled)
	world.start_run()
	_freeze()
	assert_false(world.session.state.turret_progression_enabled)
	_scrap(10)
	var before := EconomyService.total_scrap
	world.finish_wave()
	assert_eq(EconomyService.total_scrap, before + 15)
	assert_eq(world.turrets[0].progression.total_xp, 0)
	assert_true(world.salvage.settlements.is_empty())

func test_free_and_paid_frames_count_but_starter_and_levels_do_not() -> void:
	assert_eq(world.session.state.additional_turrets_acquired, 0)
	var free_turret := world.add_turret(Vector3(5, 0, 0))
	free_turret.set_physics_process(false)
	assert_eq(world.session.state.additional_turrets_acquired, 1)
	assert_eq(EconomyService.turrets_purchased, 0)
	world.finish_wave()
	EconomyService.total_scrap = 1000
	EconomyService.current_shop_offers.append(ShopOffer.new("turret", "normal", world.turret_price()))
	assert_true(world.shop.purchase(EconomyService.current_shop_offers.size() - 1))
	assert_eq(world.session.state.additional_turrets_acquired, 2)
	assert_eq(EconomyService.turrets_purchased, 1)
	free_turret.progression.award(2000)
	assert_eq(world.session.state.additional_turrets_acquired, 2)

func test_level_damage_is_individual_and_combines_with_items_once() -> void:
	var veteran := world.turrets[0]
	var rookie := world.add_turret(Vector3(8, 0, 0))
	rookie.set_physics_process(false)
	world.shop.apply_item("dense_rounds")
	var base_damage: float = veteran._current_stats(1.0).damage
	_scrap(0)
	veteran.progression.award(110)
	assert_almost_eq(float(veteran._current_stats(1.0).damage), base_damage * 1.09, .0001)
	assert_almost_eq(float(rookie._current_stats(1.0).damage), base_damage, .0001)
	assert_true(world.dev_panel.progression_text().contains("Lv 5"))
	assert_true(world.dev_panel.progression_text().contains("pending [5]"))

func test_shop_exposes_wave_award_individual_levels_and_damage_previews() -> void:
	_scrap(110)
	world.finish_wave()
	var rookie := world.add_turret(Vector3(8, 0, 0))
	rookie.set_physics_process(false)
	var screen := ShopScreen.new()
	screen.world = world
	add_child_autofree(screen)
	screen.refresh()
	assert_true(screen.growth_summary.text.contains("+110 XP"))
	assert_true(screen.growth_summary.text.contains("4 levels gained"))
	assert_true(screen.turret_text.text.contains("#1 · Lv 5"))
	assert_true(screen.turret_text.text.contains("#2 · Lv 1"))
	assert_true(screen.turret_text.text.contains("XP 0 / 41"))
	assert_true(screen.turret_text.text.contains("Lv 1 → 5"))
	var veteran_damage := world.turrets[0]._current_view(1.0).damage
	assert_true(screen.turret_text.text.contains("%.0f damage" % veteran_damage))
	var before := ShopViewData.build_data(world)
	var base: float = before.turrets[0].damage
	assert_almost_eq(float(before.dps), base * 2.09 * float(before.turrets[0].fire_rate), .001)
	var offer := ShopOffer.new("item", "dense_rounds", 1)
	EconomyService.current_shop_offers.assign([offer])
	screen._select(0)
	assert_true(screen.turret_text.text.contains("%.0f → %.0f damage" % [veteran_damage, veteran_damage * 1.1]))
	assert_eq(world.turrets[0].progression.level, 5, "Preview never changes progression")

func test_shop_explains_zero_xp_and_inactive_progression() -> void:
	world.finish_wave()
	var screen := ShopScreen.new()
	screen.world = world
	add_child_autofree(screen)
	screen.refresh()
	assert_true(screen.growth_summary.text.contains("+0 XP"))
	assert_true(screen.growth_summary.text.contains("no scrap was left"))
	FeatureFlagService.set_enabled(FeatureFlagService.TURRET_PROGRESSION, false)
	world.start_run()
	_freeze()
	world.finish_wave()
	screen.refresh()
	assert_true(screen.growth_summary.text.contains("OFF for this run"))

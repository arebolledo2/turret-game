extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.run_config = RunConfig.slice() # These tests cover the original six-wave loop.
	world.auto_start = false
	world.show_hud = false
	add_child_autofree(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.turrets[0].set_physics_process(false)
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	world.shop.rng = RandomNumberGenerator.new()
	world.shop.rng.seed = 42

func _offer_snapshot() -> Array:
	return EconomyService.current_shop_offers.map(func(offer: ShopOffer) -> Array: return [offer.kind, offer.asset_id, offer.price, offer.sold])

func stock(kind: String, id: String, cost: int = -1) -> int:
	var price := cost
	if price < 0:
		price = world.turret_price(id) if kind == "turret" else world.shop.item_price(id)
	EconomyService.current_shop_offers.append(ShopOffer.new(kind, id, price))
	return EconomyService.current_shop_offers.size() - 1

func enemy(at: Vector3, type_id: String = "basic") -> CombatActor:
	var actor := world.spawn_enemy(at, type_id)
	actor.set_physics_process(false)
	actor.max_health = 100
	actor.health = 100
	return actor

func slow_hit(intensity: float = .25, duration: float = .5) -> CombatHit3D:
	var hit := CombatHit3D.new(1, Vector3.ZERO, Vector3.ZERO, GameEnums.DamageType.ELECTRIC)
	hit.slow_intensity = intensity
	hit.slow_duration = duration
	return hit

func test_catalog_generates_unique_supported_offers_at_registry_prices() -> void:
	world.finish_wave()
	for roll in range(30):
		world.shop.generate()
		assert_eq(EconomyService.current_shop_offers.size(), 4)
		assert_eq(EconomyService.current_shop_offers.filter(func(o: ShopOffer) -> bool: return o.kind == "turret").size(), GameConstants.SHOP_TURRET_SLOTS)
		assert_eq(EconomyService.current_shop_offers.filter(func(o: ShopOffer) -> bool: return o.kind == "item").size(), GameConstants.SHOP_ITEM_SLOTS)
		var seen: Array[String] = []
		for offer in EconomyService.current_shop_offers:
			assert_false(offer.asset_id in seen)
			seen.append(offer.asset_id)
			if offer.kind == "turret":
				assert_true(offer.asset_id in ArenaShop.TURRETS)
				assert_eq(offer.price, world.turret_price(offer.asset_id))
			else:
				assert_true(offer.asset_id in ArenaShop.ITEMS)
				assert_eq(offer.price, world.shop.item_price(offer.asset_id))
				assert_lte(ItemRegistry.get_rarity(offer.asset_id), GameEnums.ItemRarity.UNCOMMON)
	assert_eq(world.shop.item_price("dense_rounds"), 21)

func test_purchase_is_atomic_and_rejects_sold_unsupported_maxed_and_unaffordable() -> void:
	world.finish_wave()
	EconomyService.total_scrap = 100
	var index := stock("item", "dense_rounds", 12)
	assert_true(world.shop.purchase(index))
	assert_false(world.shop.purchase(index))
	assert_eq(EconomyService.total_scrap, 88)
	assert_eq(ItemTrackingService.item_counts["dense_rounds"], 1)
	assert_false(world.shop.purchase(stock("turret", "sniper", 1)))
	assert_false(world.shop.purchase(stock("item", "nanite_injector", 1)))
	assert_false(world.shop.purchase(stock("item", "scrap_magnet", 999)))
	ItemTrackingService.item_counts["compact_design"] = 3
	assert_false(world.shop.purchase(stock("item", "compact_design", 1)))
	assert_eq(EconomyService.total_scrap, 88)

func test_turret_purchase_and_compact_design_reprice_unsold_offers() -> void:
	GameStateService.current_wave = 5
	world.finish_wave()
	EconomyService.total_scrap = 200
	EconomyService.current_shop_offers.clear()
	var normal := stock("turret", "normal")
	var plasma := stock("turret", "plasma")
	var compact := stock("item", "compact_design")
	var before: int = EconomyService.current_shop_offers[plasma].price
	assert_true(world.shop.purchase(normal))
	var after: int = EconomyService.current_shop_offers[plasma].price
	assert_gt(after, before)
	assert_eq(EconomyService.turrets_purchased, 1)
	assert_true(world.shop.purchase(compact))
	assert_lt(EconomyService.current_shop_offers[plasma].price, after)
	assert_eq(EconomyService.current_shop_offers[plasma].price, EconomyService.calculate_turret_price(16, 5))

func test_reroll_cost_pause_empty_wallet_free_refresh_and_wave_reset() -> void:
	world.finish_wave()
	EconomyService.total_scrap = 20
	var cost := world.shop.reroll_cost()
	assert_true(world.shop.reroll())
	assert_eq(EconomyService.total_scrap, 20 - cost)
	assert_gt(world.shop.reroll_cost(), cost)
	var offers := _offer_snapshot()
	world.toggle_pause()
	assert_false(world.shop.reroll())
	assert_false(world.shop.purchase(0))
	assert_false(world.repair())
	assert_eq(_offer_snapshot(), offers)
	world.toggle_pause()
	EconomyService.total_scrap = 0
	assert_false(world.shop.reroll())
	for offer in EconomyService.current_shop_offers:
		offer.sold = true
	assert_eq(world.shop.reroll_cost(), 0)
	assert_true(world.shop.reroll())
	world.begin_next_wave()
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	world.finish_wave()
	assert_eq(EconomyService.shop_reroll_count, 0)

func test_item_modifiers_affect_all_weapons_and_respect_filters() -> void:
	world.finish_wave()
	EconomyService.total_scrap = 1000
	assert_true(world.shop.purchase(stock("item", "dense_rounds")))
	assert_true(world.shop.purchase(stock("item", "rapid_coolant")))
	assert_true(world.shop.purchase(stock("item", "extended_barrel")))
	assert_true(world.shop.purchase(stock("item", "polished_barrels")))
	for type_id in ArenaShop.TURRETS:
		var base: Dictionary = TurretRegistry.TYPES[type_id]["base_stats"]
		var stats := TurretStatsService.get_turret_stats(type_id, 1.0)
		assert_almost_eq(float(stats["range"]), float(base["range"]) * 1.15, .001)
		assert_almost_eq(float(stats["damage"]), float(base["damage"]) * (1.2 if type_id in ["normal", "plasma", "bow", "bowling"] else 1.0), .001)
		assert_almost_eq(float(stats["fire_rate"]), float(base["fire_rate"]) * 1.15, .001)

func test_hull_speed_and_pickup_upgrades_apply_and_restart_clears_build() -> void:
	world.finish_wave()
	EconomyService.total_scrap = 100
	world.player.health = 20
	assert_true(world.shop.purchase(stock("item", "reinforced_hull")))
	assert_eq(world.player.max_health, 29.0)
	assert_eq(world.player.health, 20.0, "Capacity upgrades are not repairs")
	assert_almost_eq(PlayerStatsService.get_player_speed(), GameConstants.PLAYER_SPEED, .001)
	assert_true(world.shop.purchase(stock("item", "scrap_magnet")))
	assert_almost_eq(PlayerStatsService.get_pickup_radius(), GameConstants.PLAYER_PICKUP_RADIUS * 1.2, .001)
	assert_string_contains(world.shop.build_summary(), "Reinforced Hull")
	assert_string_contains(ArenaShop.item_description("reinforced_hull"), "Max hull +4")
	assert_true(world.repair())
	assert_eq(world.player.health, 29.0)
	world.start_run()
	assert_true(ItemTrackingService.item_counts.is_empty())
	assert_true(ModifierService.active_modifiers.is_empty())
	assert_true(EconomyService.current_shop_offers.is_empty())
	assert_eq(world.player.max_health, 25.0)
	assert_eq(world.wave_limit, 6)

func test_status_refresh_uses_strongest_slow_and_expires_without_multiplying() -> void:
	var actor := enemy(Vector3.ZERO)
	world.combat.apply_hit(actor, slow_hit(.4, 1))
	actor.statuses.advance(.7)
	world.combat.apply_hit(actor, slow_hit(.25, .5))
	assert_almost_eq(actor.statuses.speed_multiplier(), .6, .001)
	actor.statuses.advance(.4)
	assert_almost_eq(actor.statuses.speed_multiplier(), .6, .001)
	actor.statuses.advance(.11)
	assert_eq(actor.statuses.speed_multiplier(), 1.0)
	assert_true(actor.statuses.effects.is_empty())

func test_pickup_and_movement_use_purchased_stats_in_the_world() -> void:
	var pickup := ScrapPickup.new()
	pickup.world = world
	pickup.position = world.player.position + Vector3(1.05, 0, 0)
	world.pickup_root.add_child(pickup)
	var before := pickup.position
	pickup._physics_process(.01)
	assert_eq(pickup.position, before, "Outside the original magnet radius")
	world.finish_wave()
	EconomyService.total_scrap = 100
	assert_true(world.shop.purchase(stock("item", "scrap_magnet")))
	assert_true(world.shop.purchase(stock("item", "reinforced_hull")))
	world.begin_next_wave()
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	pickup = ScrapPickup.new()
	pickup.world = world
	pickup.position = before
	world.pickup_root.add_child(pickup)
	pickup._physics_process(.01)
	assert_lt(pickup.position.distance_to(world.player.position), 1.05)
	Input.action_press("move_right")
	world.player._physics_process(1)
	Input.action_release("move_right")
	assert_almost_eq(world.player.velocity.length(), GameConstants.PLAYER_SPEED * .01, .001)

func test_full_arena_rejects_purchase_without_spending_or_selling_offer() -> void:
	world.finish_wave()
	EconomyService.total_scrap = 100
	while world.find_placement() != Vector3.INF:
		world.add_turret(world.find_placement())
	var index := stock("turret", "shock")
	assert_false(world.shop.purchase(index))
	assert_eq(EconomyService.total_scrap, 100)
	assert_false(EconomyService.current_shop_offers[index].sold)

func test_shock_pulse_hits_each_in_range_enemy_and_applies_slow_without_projectiles() -> void:
	var shock := world.add_turret(Vector3.ZERO, "shock")
	shock.set_physics_process(false)
	var near := enemy(Vector3(1, 0, 0))
	var edge := enemy(Vector3(2.724, 0, 0))
	var far := enemy(Vector3(2.734, 0, 0))
	watch_signals(world.combat)
	shock._physics_process(.01)
	assert_eq(near.health, 96.0)
	assert_eq(edge.health, 96.0)
	assert_eq(far.health, 100.0)
	assert_eq(near.statuses.speed_multiplier(), .75)
	assert_true(near.slow_marker.visible)
	assert_signal_emit_count(world.combat, "shock_pulse", 1)
	assert_true(world.projectiles.is_empty())
	shock._physics_process(.01)
	assert_eq(near.health, 96.0, "Cooldown prevents repeat pulse")
	assert_not_null(shock.aim)
	assert_not_null(shock.muzzle)

func test_slow_changes_chaser_and_dash_velocity_without_retargeting() -> void:
	world.player.position = Vector3(3, 0, 0)
	for type_id in ["basic", "charger"]:
		var actor := enemy(Vector3.ZERO, type_id)
		if actor.charge:
			actor.charge.phase = ChargeController3D.Phase.DASH
			actor.charge.heading = Vector3.RIGHT
			actor.charge.remaining = 1
		world.combat.apply_hit(actor, slow_hit())
		actor._physics_process(.01)
		assert_almost_eq(actor.velocity.x, actor.speed * .75 * (3.0 if actor.charge else 1.0), .001)
		if actor.charge:
			assert_eq(actor.charge.heading, Vector3.RIGHT)
			assert_eq(actor.charge.phase, ChargeController3D.Phase.DASH)

func test_pause_carry_death_and_wave_end_clear_or_freeze_status_correctly() -> void:
	var actor := enemy(Vector3.ZERO)
	world.combat.apply_hit(actor, slow_hit())
	world.toggle_pause()
	actor._physics_process(1)
	assert_eq(actor.statuses.speed_multiplier(), .75)
	world.toggle_pause()
	var shock := world.add_turret(Vector3.ZERO, "shock")
	shock.set_physics_process(false)
	shock.carried = true
	shock._physics_process(1)
	assert_eq(actor.health, 95.0)
	actor.take_damage(1000)
	assert_true(actor.statuses.effects.is_empty())
	var second := enemy(Vector3.ZERO)
	world.combat.apply_hit(second, slow_hit())
	world.finish_wave()
	assert_true(second.statuses.effects.is_empty())
	assert_false(second.slow_marker.visible)

func test_six_wave_loop_supports_distinct_builds_and_only_ends_after_wave_six() -> void:
	# This regression scenario uses the original six-wave economy and purchase budget.
	FeatureFlagService.set_enabled(FeatureFlagService.TURRET_PROGRESSION, false)
	for route in ["normal", "plasma"]:
		world.start_run()
		world.set_physics_process(false)
		world.player.set_physics_process(false)
		for wave in range(1, 7):
			world.preparation.deploy()
			GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
			for kill in range(3):
				enemy(Vector3.ZERO).take_damage(1000)
			world.waves.time_left = .01
			world.waves.remaining_spawns = 0
			world._physics_process(.02)
			await get_tree().process_frame
			if wave == 6:
				assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.VICTORY)
				assert_false(world.shop.reroll())
				break
			assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)
			if wave == 1:
				assert_true(world.shop.purchase(stock("turret", route)))
			if wave == 3:
				assert_true(world.shop.purchase(stock("item", "quick_loader") if route == "normal" else stock("turret", "shock")))
			assert_true(world.begin_next_wave())
		if route == "normal":
			assert_eq(TurretStatsService.turret_counts["normal"], 2)
			assert_eq(ItemTrackingService.item_counts["quick_loader"], 1)
		else:
			assert_eq(TurretStatsService.turret_counts["plasma"], 1)
			assert_eq(TurretStatsService.turret_counts["shock"], 1)

func test_hud_shows_offers_build_and_terminal_summary() -> void:
	var hud := preload("res://scripts/game/game_hud.gd").new()
	hud.world = world
	world.add_child(hud)
	world.finish_wave()
	hud._process(0)
	assert_true(hud.shop_screen.visible)
	assert_eq(hud.shop_screen.offer_buttons.size(), 4)
	assert_true(hud.shop_screen.offer_buttons[0].visible, "offers show in the shop")
	assert_eq(hud.shop_screen.offer_buttons[0].shown_key.split(":")[1], EconomyService.current_shop_offers[0].asset_id)
	assert_false(hud.shop_screen.turret_text.text.is_empty(), "build is populated")
	assert_eq(ShopViewData.build_data(world)["turrets"][0]["name"], "Ion")
	world.player.health = 1
	world.begin_next_wave()
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	world.player.take_damage(100)
	hud._process(0)
	assert_true(hud.restart_button.visible)
	assert_false(hud.shop_screen.visible)
	assert_gt(hud.build_panel.get_child_count(), 0, "build still shown at game over")

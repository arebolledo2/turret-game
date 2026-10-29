extends GutTest

## Scrap Press line: stocking, the no-attack registry entry, the base press's timed floor drops, Coin Feeder's half deposit,
## Treasury's full deposit, faster output and wave-end interest, Academy's direct XP, stacking presses (60% and 40%), and the
## clean-up paths (wave end, pause, pickup, removal, evolution, run reset). The S5 rules it uses are in `test_scrap_income.gd`.

const GATE := "test_scrap_press_gate"
const STEP := 1.0 / 60.0

var rig: TurretTestRig
var world: ArenaWorld

func before_each() -> void:
	rig = TurretTestRig.start(self)
	rig.disable_crits()
	world = rig.world
	GameStateService.current_wave = 1
	EconomyService.total_scrap = 0
	# The run's starting turret would join every XP split; park it in a far corner.
	for starting in world.turrets:
		starting.position = Vector3(24, 0, 16)

func after_each() -> void:
	ShopCatalog.reset()
	TestHelpers.reset_flags()

func _press(form_path: Array[String] = [], at: Vector3 = Vector3.ZERO) -> TurretActor:
	return rig.turret("scrap_press", form_path, at)

func _feeder(at: Vector3 = Vector3.ZERO) -> TurretActor:
	return _press(["coin_feeder"], at)

func _treasury(at: Vector3 = Vector3.ZERO) -> TurretActor:
	return _press(["coin_feeder", "treasury"], at)

func _academy(at: Vector3 = Vector3.ZERO) -> TurretActor:
	return _press(["coin_feeder", "academy"], at)

func _run(turret: TurretActor, seconds: float) -> void:
	rig.run(turret, seconds, STEP)

func _form(turret: TurretActor) -> ScrapPressForm:
	return turret.form as ScrapPressForm

func _pickups() -> Array[ScrapPickup]:
	var result: Array[ScrapPickup] = []
	for node in world.pickup_root.get_children():
		if node is ScrapPickup and not node.is_queued_for_deletion():
			result.append(node)
	return result

func _floor_scrap() -> int:
	var total := 0
	for pickup in _pickups():
		total += pickup.amount
	return total

# --- Shop, registry and items ---

func test_scrap_press_is_stocked_at_its_registry_price_and_purchasable() -> void:
	assert_has(ArenaShop.TURRETS, "scrap_press")
	assert_has(ShopCatalog.available_ids("turret"), "scrap_press")
	assert_eq(TurretRegistry.get_base_price("scrap_press"), 14)
	var price := world.turret_price("scrap_press")
	assert_eq(price, EconomyService.calculate_turret_price(14, GameStateService.current_wave))
	EconomyService.total_scrap = 500
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", "scrap_press", price)])
	assert_true(world.shop.purchase(0))
	assert_eq(TurretStatsService.turret_counts.get("scrap_press", 0), 1)
	assert_eq(EconomyService.total_scrap, 500 - price)
	assert_eq(ArenaShop.offer_name(ShopOffer.new("turret", "scrap_press", 1)), "Scrap Press")
	assert_ne(ArenaShop.offer_description(ShopOffer.new("turret", "scrap_press", 1)), "")

func test_shop_rolls_the_press_among_the_weapons_and_a_flag_can_gate_it() -> void:
	world.shop.rng = RandomNumberGenerator.new()
	world.shop.rng.seed = 5
	var seen := false
	for roll in 300:
		world.shop.generate()
		for offer: ShopOffer in EconomyService.current_shop_offers:
			if offer.kind == "turret" and offer.asset_id == "scrap_press":
				seen = true
	assert_true(seen, "300 refreshes stock the Scrap Press at least once")
	FeatureFlagService.register_flag(GATE, {"name": "Gate", "scope": FeatureFlagService.SCOPE_EXPERIMENT})
	ShopCatalog.entries["turret"]["scrap_press"] = GATE
	assert_false(ShopCatalog.is_available("turret", "scrap_press"))
	EconomyService.total_scrap = 500
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", "scrap_press", 1)])
	assert_false(world.shop.purchase(0), "A gated turret cannot be bought")

func test_shop_view_data_dev_tools_and_art_know_the_press() -> void:
	_press()
	assert_gt(world.dev.add_turret("scrap_press"), 0)
	var data := ShopViewData.build_data(world)
	var row: Dictionary = {}
	for entry: Dictionary in data.turrets:
		if entry.id == "scrap_press":
			row = entry
	assert_false(row.is_empty())
	assert_eq(row.name, "Scrap Press")
	assert_true(row.utility, "The shop knows it does not attack")
	assert_almost_eq(float(row.interval), 4.0, .001)
	assert_same(ShopArt.turret("scrap_press"), load("res://assets/ui/turrets/scrap_press.png"))
	for form in ["scrap_press", "coin_feeder", "treasury", "academy"]:
		assert_true(ResourceLoader.exists("res://assets/ui/turrets/%s.png" % form), form)
	assert_not_null(UiIcons.turret("scrap_press"))
	assert_true(UiIconData.PATHS.has("turret_scrap_press"))

func test_registry_entry_is_a_no_attack_utility_with_no_family_and_no_attack_families() -> void:
	var base := TurretRegistry.get_base_stats("scrap_press")
	assert_eq(base.damage, 0.0)
	assert_almost_eq(float(base.fire_rate), .25, .0001, "One drop every 4 s")
	assert_eq(base.range, 150.0, "Drops land within 1.5 m")
	assert_eq(TurretRegistry.get_fire_mode("scrap_press"), TurretRegistry.FIRE_NONE)
	assert_true(TurretRegistry.is_no_attack("scrap_press"))
	assert_true(TurretRegistry.has_capability("scrap_press", "no_attack"))
	assert_eq(TurretRegistry.get_family("scrap_press"), "", "It is in no build family")
	assert_true(TurretRegistry.get_attack_families("scrap_press").is_empty())
	assert_eq(TurretRegistry.get_targeting("scrap_press"), "closest", "Unused: it never picks a target")
	for other: String in TurretRegistry.get_all_type_ids():
		if other != "scrap_press":
			assert_false(TurretRegistry.is_no_attack(other), other)

func test_item_rules_that_count_attackers_ignore_the_press() -> void:
	TurretStatsService.turret_counts = {"plasma": 1, "scrap_press": 3}
	assert_eq(TurretStatsService.get_attack_turret_count(), 1)
	assert_eq(TurretStatsService.get_total_turret_count(), 4, "The raw count includes it")
	TurretStatsService.turret_counts = {"plasma": 1, "shock": 1, "scrap_press": 3}
	assert_eq(TurretStatsService.shared_attack_families(), ["aoe"] as Array[String], "A press beside a focused build keeps Focused Arsenal")
	TurretStatsService.turret_counts = {"scrap_press": 2}
	assert_true(TurretStatsService.shared_attack_families().is_empty())
	assert_eq(TurretStatsService.get_family_diversity(), 0)

func test_a_family_damage_item_changes_nothing_for_a_turret_with_no_attack() -> void:
	ModifierService.add_modifier(Item.create_increase("damage", .5, Item.filter_family(["aggro"])))
	var press := _press()
	var stats := press.resolve_attack_view()
	assert_eq(stats.damage, 0.0, "A family item changes nothing about a turret with no attack")

# --- Base press ---

func test_the_base_press_lays_one_pickup_every_four_seconds_within_reach_and_never_attacks() -> void:
	var press := _press()
	var enemy := rig.enemy(Vector3(0, 0, -3), 100.0)
	rig.combat()
	_run(press, 3.9)
	assert_eq(_pickups().size(), 0)
	_run(press, .2)
	assert_eq(_pickups().size(), 1, "The first drop lands at 4 s")
	var pickup := _pickups()[0]
	assert_eq(pickup.amount, 1, "Wave 1 drops are worth 1")
	assert_lte(WorldGeometry.planar(pickup.position - press.position).length(), 1.5 + .001)
	assert_eq(EconomyService.total_scrap, 0, "Nothing is deposited by the plain press")
	_run(press, 4.0)
	assert_eq(_pickups().size(), 2)
	assert_eq(enemy.health, 100.0, "It never damages anything")
	assert_eq(world.projectiles.size(), 0)
	assert_null(press.target, "It never picks a target")
	assert_eq(_form(press).drops_made, 2)

func test_a_drop_is_worth_more_on_later_waves() -> void:
	GameStateService.current_wave = 6
	var press := _press()
	rig.combat()
	_run(press, 4.1)
	assert_eq(_floor_scrap(), 2)
	GameStateService.current_wave = 11
	_run(press, 4.0)
	assert_eq(_floor_scrap(), 2 + 3)

func test_leftover_press_scrap_becomes_xp_for_the_turrets_beside_it() -> void:
	var press := _press([], Vector3.ZERO)
	rig.turret("normal", [], Vector3(1.5, 0, 0))
	rig.combat()
	_run(press, 8.2)
	assert_eq(_floor_scrap(), 2)
	GameStateService.current_wave = 1
	GameStateMachine.force_transition(GameStateMachine.GameState.WAVE_END)
	assert_true(world.salvage.settle(1))
	assert_eq(world.salvage.last_settlement["raw_scrap"], 2, "The press's scrap is part of the wave's salvage like any other")
	var gained := 0
	for turret in world.turrets:
		gained += turret.progression.total_xp
	assert_eq(gained, 2, "Every unit of leftover press scrap became one XP for some turret")

func test_the_hero_can_still_pick_the_press_scrap_up_for_cash() -> void:
	var press := _press()
	rig.combat()
	_run(press, 4.1)
	var pickup := _pickups()[0]
	pickup.collect()
	assert_eq(EconomyService.total_scrap, 1)
	assert_eq(_pickups().size(), 0)

func test_the_unevolved_press_runs_through_its_form() -> void:
	var press := _press()
	assert_true(press.form is ScrapPressForm)
	assert_eq(_form(press).deposit_share(), 0.0)
	assert_false(_form(press).makes_xp())

# --- Coin Feeder ---

func test_coin_feeder_sends_half_of_each_drop_to_the_wallet_and_leaves_half_on_the_floor() -> void:
	GameStateService.current_wave = 6
	var press := _feeder()
	rig.combat()
	_run(press, 4.1)
	assert_eq(EconomyService.total_scrap, 1, "Half of a 2-scrap drop")
	assert_eq(_floor_scrap(), 1)
	_run(press, 4.0)
	assert_eq(EconomyService.total_scrap, 2)
	assert_eq(_floor_scrap(), 2)

func test_coin_feeder_alternates_on_a_one_scrap_drop_so_the_halves_add_up() -> void:
	var press := _feeder()
	rig.combat()
	_run(press, 16.2)
	assert_eq(_form(press).drops_made, 4)
	assert_eq(EconomyService.total_scrap, 2, "Half of four one-scrap drops reaches the wallet")
	assert_eq(_floor_scrap(), 2)
	assert_eq(EconomyService.total_scrap + _floor_scrap(), 4, "Nothing is lost to rounding")

func test_coin_feeder_keeps_the_press_output_the_same() -> void:
	var base := _press()
	var feeder := _feeder()
	assert_almost_eq(feeder.resolve_attack_view().fire_rate, base.resolve_attack_view().fire_rate * 1.1, .02, "Same rate before the level bonus (level 5 adds 10% speed)")

# --- Treasury ---

func test_treasury_deposits_every_drop_and_leaves_nothing_on_the_floor() -> void:
	var press := _treasury()
	rig.combat()
	_run(press, 12.9)
	assert_eq(_pickups().size(), 0)
	assert_eq(EconomyService.total_scrap, _form(press).drops_made)
	assert_gt(_form(press).drops_made, 3)

func test_treasury_makes_a_quarter_more_than_the_base_rate() -> void:
	var base := TurretEvolution.base_stats("scrap_press", "")
	var treasury := TurretEvolution.base_stats("scrap_press", "treasury")
	assert_almost_eq(float(treasury.fire_rate) / float(base.fire_rate), 1.25, .0001)
	var press := _treasury()
	rig.combat()
	_run(press, 40.0)
	# Level 10 adds 20% speed to the 0.3125 base (0.375 a second, 15 drops in 40 s), and Entrench up to 20% more once it has stood still.
	assert_between(_form(press).drops_made, 14, 17)

func test_treasury_pays_interest_when_a_wave_is_won_one_per_ten_held_up_to_five() -> void:
	var press := _treasury()
	rig.combat()
	EconomyService.total_scrap = 37
	assert_eq(press.form.wave_end_scrap(37), 3)
	assert_eq(press.form.wave_end_scrap(500), 5)
	assert_eq(press.form.wave_end_scrap(9), 0)
	assert_eq(world.scrap_income.pay_interest(), 3)
	assert_eq(EconomyService.total_scrap, 40)

func test_interest_is_paid_by_finish_wave_after_the_wave_bonus_and_reported() -> void:
	_treasury()
	rig.combat()
	EconomyService.total_scrap = 40
	GameStateService.current_wave = 2
	var bonus := EconomyService.get_wave_scrap_base(2)
	assert_true(world.finish_wave())
	# Held after the bonus is 40 + 10 = 50, so the capped five is paid.
	assert_eq(EconomyService.total_scrap, 40 + bonus + 5)
	assert_string_contains(world.message, "+5 interest")

func test_the_other_forms_pay_no_interest() -> void:
	for path: Array in [[], ["coin_feeder"], ["coin_feeder", "academy"]]:
		var forms: Array[String] = []
		forms.assign(path)
		var press := _press(forms, Vector3(float(path.size()) * 4.0, 0, 0))
		assert_eq(press.form.wave_end_scrap(500), 0)

func test_a_carried_treasury_pays_no_interest_and_makes_nothing() -> void:
	var press := _treasury()
	press.carried = true
	rig.combat()
	_run(press, 10.0)
	assert_eq(_form(press).drops_made, 0)
	assert_eq(world.scrap_income.pay_interest(), 0)

# --- Academy ---

func test_academy_gives_xp_to_every_turret_within_six_metres_in_full_and_pays_no_cash() -> void:
	GameStateService.current_wave = 6
	var press := _academy()
	var near_a := rig.turret("normal", [], Vector3(3, 0, 0))
	var near_b := rig.turret("bow", [], Vector3(0, 0, -5.5))
	var far := rig.turret("normal", [], Vector3(8, 0, 0))
	rig.combat()
	var before_press := press.progression.total_xp
	_run(press, 8.1)
	assert_eq(_form(press).drops_made, 1, "One drop every 8 s")
	assert_eq(near_a.progression.total_xp, 2, "A wave 6 drop is worth 2, in full")
	assert_eq(near_b.progression.total_xp, 2, "Each turret gets the whole drop")
	assert_eq(press.progression.total_xp - before_press, 2, "The press feeds itself too")
	assert_eq(far.progression.total_xp, 0, "Seven metres out is too far")
	assert_eq(EconomyService.total_scrap, 0, "No cash")
	assert_eq(_pickups().size(), 0, "No scrap on the floor either")
	assert_eq(_form(press).xp_given, 6)

func test_academy_xp_is_reported_with_the_waves_salvage() -> void:
	var press := _academy()
	var near := rig.turret("normal", [], Vector3(2, 0, 0))
	rig.combat()
	_run(press, 16.2)
	assert_eq(near.progression.total_xp, 2)
	GameStateMachine.force_transition(GameStateMachine.GameState.WAVE_END)
	assert_true(world.salvage.settle(1))
	var change: Dictionary = world.salvage.last_settlement["changes"][near.turret_id]
	assert_eq(change["xp_awarded"], 2)
	assert_eq(change["after"]["total_xp"] - change["before"]["total_xp"], 2)
	assert_gte(world.salvage.last_settlement["xp_awarded"], 4, "Two turrets got 2 each")

func test_academy_xp_can_level_a_turret_mid_wave() -> void:
	GameStateService.current_wave = 21
	var press := _academy()
	var near := rig.turret("normal", [], Vector3(2, 0, 0))
	rig.combat()
	for slice in 5:
		_run(press, 8.0)
	# Drops are worth 5 at wave 21; the first level needs 20 XP.
	assert_gte(near.progression.level, 2)
	assert_eq(near.progression.total_xp, 5 * _form(press).drops_made)

func test_academy_does_nothing_when_turret_progression_is_off() -> void:
	var press := _academy()
	var near := rig.turret("normal", [], Vector3(2, 0, 0))
	world.session.state.turret_progression_enabled = false
	rig.combat()
	_run(press, 16.2)
	assert_eq(near.progression.total_xp, 0)
	assert_true(world.salvage.direct.is_empty())
	assert_eq(EconomyService.total_scrap, 0)

# --- Stacking ---

func test_a_second_press_makes_sixty_percent_and_a_third_forty() -> void:
	var first := _press([], Vector3(-8, 0, 0))
	var second := _press([], Vector3(0, 0, 0))
	var third := _press([], Vector3(8, 0, 0))
	rig.combat()
	for turret in [first, second, third]:
		rig.step(turret, STEP)
	assert_eq(_form(first).current_yield(), 1.0)
	assert_eq(_form(second).current_yield(), .6)
	assert_eq(_form(third).current_yield(), .4)
	for turret in [first, second, third]:
		_run(turret, 100.5)
	# Entrench (standing still earns up to +20% fire rate) lifts all three alike, so compare shares, not exact counts.
	assert_between(_form(first).drops_made, 25, 30)
	assert_almost_eq(float(_form(second).drops_made) / float(_form(first).drops_made), .6, .04)
	assert_almost_eq(float(_form(third).drops_made) / float(_form(first).drops_made), .4, .04)

func test_removing_the_first_press_promotes_the_next_and_a_fourth_stays_at_forty() -> void:
	var first := _press([], Vector3(-8, 0, 0))
	var second := _press([], Vector3(0, 0, 0))
	var third := _press([], Vector3(8, 0, 0))
	var fourth := _press([], Vector3(8, 0, 6))
	rig.combat()
	for turret in [first, second, third, fourth]:
		rig.step(turret, STEP)
	assert_eq(_form(fourth).current_yield(), .4)
	first.carried = true
	for turret in [second, third, fourth]:
		turret.invalidate_stats()
		rig.step(turret, STEP)
	assert_eq(_form(second).current_yield(), 1.0, "A carried press does not count toward the rank")
	assert_eq(_form(third).current_yield(), .6)
	assert_eq(_form(fourth).current_yield(), .4)

func test_stacked_treasuries_scale_their_interest() -> void:
	var first := _treasury(Vector3(-8, 0, 0))
	var second := _treasury(Vector3(8, 0, 0))
	rig.combat()
	EconomyService.total_scrap = 500
	assert_eq(first.form.wave_end_scrap(500), 5)
	assert_eq(second.form.wave_end_scrap(500), 3, "60% of five, rounded")
	assert_eq(world.scrap_income.pay_interest(), 8)

func test_two_presses_keep_their_own_charge_and_change() -> void:
	var left := _feeder(Vector3(-8, 0, 0))
	var right := _press([], Vector3(8, 0, 0))
	rig.combat()
	rig.step(left, STEP)
	rig.step(right, STEP)
	_run(left, 4.0)
	assert_eq(_form(left).drops_made, 1)
	assert_eq(_form(right).drops_made, 0, "Stepping one press does not advance the other")
	_run(right, 2.0)
	_run(left, 1.0)
	assert_eq(_form(right).drops_made, 0)
	assert_ne(_form(left).charge, _form(right).charge)

func test_a_press_does_not_disturb_other_turrets_or_the_hero_economy() -> void:
	var gun := rig.turret("normal", [], Vector3(2, 0, 0))
	var press := _press([], Vector3(-2, 0, 0))
	var enemy := rig.enemy(Vector3(2, 0, -1.5), 100.0)
	rig.combat()
	rig.step(press, STEP)
	for tick in 120:
		rig.step(gun, STEP)
	assert_gt(world.projectiles.size(), 0, "A neighbouring gun still fires")
	assert_eq(enemy.health, 100.0, "...and the press next to it adds no damage of its own")
	assert_eq(EconomyService.total_scrap, 0)
	assert_eq(TurretStatsService.get_attack_turret_count(), TurretStatsService.turret_counts.get("normal", 0))

# --- Clean-up ---

func test_wave_end_forgets_the_half_made_drop() -> void:
	var press := _feeder()
	rig.combat()
	_run(press, 3.0)
	assert_gt(_form(press).charge, .5)
	rig.shop()
	rig.step(press, STEP)
	assert_eq(_form(press).charge, 0.0)
	assert_eq(_form(press).carry, 0.0)
	rig.combat()
	_run(press, 1.5)
	assert_eq(_form(press).drops_made, 0, "The next wave starts the drop over")

func test_pausing_stops_the_press_without_losing_the_run() -> void:
	var press := _press()
	rig.combat()
	_run(press, 2.0)
	world.paused = true
	_run(press, 10.0)
	assert_eq(_form(press).drops_made, 0, "No drops while paused")
	assert_eq(_form(press).charge, 0.0)
	world.paused = false
	_run(press, 4.1)
	assert_eq(_form(press).drops_made, 1)

func test_picking_the_press_up_stops_it_and_dropping_it_starts_over() -> void:
	var press := _feeder()
	rig.combat()
	_run(press, 3.0)
	press.carried = true
	_run(press, 10.0)
	assert_eq(_form(press).drops_made, 0)
	assert_eq(_form(press).charge, 0.0)
	press.carried = false
	_run(press, 3.0)
	assert_eq(_form(press).drops_made, 0)
	_run(press, 1.2)
	assert_eq(_form(press).drops_made, 1)

func test_a_removed_press_stops_and_leaves_nothing_running() -> void:
	var press := _treasury()
	var form := _form(press)
	rig.combat()
	_run(press, 2.0)
	assert_gt(form.charge, 0.0)
	EconomyService.total_scrap = 500
	world.turrets.erase(press)
	press.get_parent().remove_child(press)
	press.free()
	assert_eq(form.charge, 0.0, "Leaving the tree drops the half-made drop")
	assert_eq(form.carry, 0.0)
	assert_eq(world.scrap_income.pay_interest(), 0, "A removed Treasury pays no interest")

func test_evolving_starts_the_new_form_from_scratch() -> void:
	var press := _press()
	rig.combat()
	_run(press, 3.0)
	var first := _form(press)
	assert_gt(first.charge, 0.0)
	rig.shop()
	rig.level_to(press, 5)
	assert_true(press.evolve("coin_feeder"))
	assert_eq(first.charge, 0.0, "The old form let go")
	assert_not_same(press.form, first)
	assert_eq(_form(press).charge, 0.0)
	assert_eq(_form(press).deposit_share(), .5)

func test_a_run_reset_leaves_no_charge_or_tally() -> void:
	var press := _academy()
	var near := rig.turret("normal", [], Vector3(2, 0, 0))
	rig.combat()
	_run(press, 9.0)
	assert_false(world.salvage.direct.is_empty())
	world._clear_actors()
	world.salvage.reset(1)
	world.scrap_income.reset(1)
	assert_true(world.salvage.direct.is_empty())
	assert_eq(world.scrap_income.xp_awarded, 0)
	assert_not_null(near)

func test_finishing_the_wave_leaves_the_press_idle_and_its_floor_scrap_for_salvage() -> void:
	var press := _press()
	var neighbour := rig.turret("normal", [], Vector3(1.5, 0, 0))
	rig.combat()
	_run(press, 8.2)
	assert_eq(_floor_scrap(), 2)
	GameStateService.current_wave = 1
	assert_true(world.finish_wave())
	var gained := 0
	for turret in world.turrets:
		gained += turret.progression.total_xp
	assert_eq(gained, 2, "Salvage turned the press's two scrap into XP")
	assert_not_null(neighbour)
	rig.step(press, STEP)
	assert_eq(_form(press).charge, 0.0, "Not in combat: idle")

# --- Forms and tuning ---

func test_path_forms_tiers_and_chassis() -> void:
	assert_eq(TurretEvolution.options("scrap_press", 0), ["coin_feeder"])
	assert_eq(TurretEvolution.options("scrap_press", 1), ["treasury", "academy"])
	assert_eq(TurretEvolution.form_name("coin_feeder"), "Coin Feeder")
	assert_eq(TurretEvolution.form_name("treasury"), "Treasury")
	assert_eq(TurretEvolution.form_name("academy"), "Academy")
	for form in ["coin_feeder", "treasury", "academy"]:
		assert_true(TurretEvolution.is_implemented(form))
		assert_eq(TurretEvolution.model_key(form), "scrap_press", "Every form uses the real cp_scrap_press chassis")
		assert_true(ClockworkModels.available(TurretEvolution.model_key(form)))
		assert_false(TurretEvolution.description(form).is_empty())
	assert_true(TurretEvolution.behaviour_script("scrap_press", "").new() is ScrapPressForm)

func test_every_form_adds_visible_hardware_to_the_chassis() -> void:
	var counts: Dictionary = {}
	for form in ["", "coin_feeder", "treasury", "academy"]:
		var press := rig.turret("scrap_press", [], Vector3(20, 0, 0))
		if not form.is_empty():
			rig.level_to(press, 5)
			var path: Array[String] = ["coin_feeder"]
			if form != "coin_feeder":
				rig.level_to(press, 10)
				path.append(form)
			for step in path:
				assert_true(press.evolve(step), step)
		var meshes := press.model.find_children("*", "MeshInstance3D", true, false).size()
		counts[form] = meshes
	assert_gt(counts["coin_feeder"], counts[""], "Coin Feeder adds a hopper, chute and tray")
	assert_gt(counts["treasury"], counts[""], "Treasury adds ingot stacks and a vault dome")
	assert_gt(counts["academy"], counts[""], "Academy adds a mortarboard and books")
	assert_ne(counts["treasury"], counts["academy"])

func test_the_press_faces_the_camera_and_drops_from_its_coin_tray() -> void:
	var press := _press()
	assert_almost_eq(absf(press.model.rotation.y), PI, .001, "Turned half a circle so the tray faces +z, the game camera")
	var drop := _form(press).drop_point()
	assert_eq(drop, press.muzzle.global_position)
	assert_gt(drop.z - press.global_position.z, .5, "The tray is on the camera side of the press")
	assert_gt(drop.y, .3, "Above the floor, over the tray")
	var chassis_meshes := press.model.find_children("*", "MeshInstance3D", true, false).size()
	assert_eq(chassis_meshes, 16, "The real chassis: 16 mesh objects")

func test_form_hardware_stands_clear_of_the_chassis_body() -> void:
	# The funnel is the one chassis part the hardware attaches to (the collar and hopper rim meet it); everything else must not overlap.
	var chassis_names: Array[String] = ["Feet", "BasePlate", "BaseBlock", "Pedestals", "CoinTray", "Coins", "PistonBrass", "PistonRam", "Housing", "Knob", "RubberDetails"]
	var hardware_clear_of: Dictionary = {"coin_feeder": ["Hopper", "HopperRim", "HopperLeg", "Spout", "Tray", "Coin"], "treasury": ["Ingot"], "academy": ["Book", "Pages"]}
	# The coin ring is a floor ring, so its box is not a fair test; its inner radius must clear the feet's corner instead.
	var ring_radius := Vector2(ScrapPressEvolutionVisual.DEFAULT_HALF_X, ScrapPressEvolutionVisual.DEFAULT_HALF_Z).length()
	assert_gt(.93, ring_radius, "The coin ring (inner radius .93) encircles the feet")
	for form: String in hardware_clear_of:
		var press := _press()
		rig.level_to(press, 5)
		assert_true(press.evolve("coin_feeder"))
		if form != "coin_feeder":
			rig.level_to(press, 10)
			assert_true(press.evolve(form))
		var chassis: Array[AABB] = []
		for part_name in chassis_names:
			var part := press.model.find_child(part_name, true, false) as MeshInstance3D
			assert_not_null(part, part_name)
			chassis.append(_model_box(part, press.model))
		for part in press.model.get_children():
			var mesh_part := part as MeshInstance3D
			if not mesh_part:
				continue
			var base_name := String(mesh_part.name).rstrip("0123456789")
			if base_name not in hardware_clear_of[form]:
				continue
			var box := _model_box(mesh_part, press.model)
			for other in chassis:
				assert_false(box.grow(-.005).intersects(other), "%s: %s must not clip the chassis" % [form, mesh_part.name])
			assert_gte(box.position.y, -.001, "%s: %s does not sink under the floor" % [form, mesh_part.name])

func test_the_footprint_reads_the_real_chassis() -> void:
	var model := ClockworkModels.instantiate("scrap_press")
	autofree(model)
	var footprint := ScrapPressEvolutionVisual._footprint(model)
	assert_almost_eq(float(footprint.half_x), .57, .02)
	assert_almost_eq(float(footprint.half_z), .495, .02)
	assert_almost_eq(float(footprint.crown), 1.58, .02)
	assert_almost_eq(float(footprint.mouth_x), -.757, .02)
	assert_between(float(footprint.mouth_y), .9, 1.1)

## A part's box in the model's own space (the chassis meshes sit at identity rotation, the hardware at yaw only).
func _model_box(part: MeshInstance3D, model: Node3D) -> AABB:
	var transform := model.global_transform.affine_inverse() * part.global_transform
	return transform * part.mesh.get_aabb()

func test_the_hardware_builder_ignores_other_turrets() -> void:
	var model := Node3D.new()
	autofree(model)
	assert_null(ScrapPressEvolutionVisual.build(model, "bumper_post"))
	assert_null(ScrapPressEvolutionVisual.build(model, ""))
	assert_eq(model.get_child_count(), 0)

func test_pattern_text_describes_where_the_drops_go() -> void:
	assert_string_contains(TurretEvolution.scrap_press_pattern_text(""), "left at wave end")
	assert_string_contains(TurretEvolution.scrap_press_pattern_text("coin_feeder"), "50%")
	assert_string_contains(TurretEvolution.scrap_press_pattern_text("treasury"), "+1 scrap per 10 held, up to 5")
	assert_string_contains(TurretEvolution.scrap_press_pattern_text("academy"), "6 m")

func test_levelling_speeds_the_press_up() -> void:
	var press := _press()
	var base_interval := _form(press).drop_interval()
	rig.level_to(press, 6)
	press.invalidate_stats()
	assert_lt(_form(press).drop_interval(), base_interval, "Level speed bonuses shorten the drop interval")

## Simulated (not timed) income per form over a whole wave at a few waves, in scrap-equivalents: the wallet and floor scrap
## for the money forms, the XP given for Academy. The Treasury counts its interest with 50 scrap held. This is the number the
## finals' tuning rests on. The Treasury's figure is its ceiling (interest is 1 per 10 held, so it is lower when less is held, 3
## on 30 scrap), and both finals include their level-10 speed against the feeder's level 5 and Entrench.
func _income(form_path: Array[String], wave: int, seconds: float, neighbours: int = 0) -> Dictionary:
	rig.shop()
	GameStateService.current_wave = wave
	EconomyService.total_scrap = 0
	for pickup in _pickups():
		pickup.queue_free()
	var press := _press(form_path, Vector3(-3, 0, 0))
	var others: Array[TurretActor] = []
	for index in neighbours:
		others.append(rig.turret("normal", [], Vector3(float(index), 0, 2)))
	rig.combat()
	var xp_before := world.scrap_income.xp_awarded
	_run(press, seconds)
	var money := EconomyService.total_scrap + _floor_scrap()
	var interest := press.form.wave_end_scrap(50)
	var xp := world.scrap_income.xp_awarded - xp_before
	for turret in others + [press] as Array[TurretActor]:
		world.turrets.erase(turret)
		turret.get_parent().remove_child(turret)
		turret.free()
	return {"money": money, "interest": interest, "xp": xp, "drops": money + interest}

func test_finals_land_at_about_one_and_a_half_times_coin_feeders_output_over_a_wave() -> void:
	var feeder_path: Array[String] = ["coin_feeder"]
	var treasury_path: Array[String] = ["coin_feeder", "treasury"]
	var academy_path: Array[String] = ["coin_feeder", "academy"]
	var report: PackedStringArray = []
	for wave in [1, 3, 5, 8, 12]:
		var seconds := GameStateService.get_wave_duration(wave)
		var feeder := _income(feeder_path, wave, seconds)
		var treasury := _income(treasury_path, wave, seconds)
		var academy := _income(academy_path, wave, seconds, 2)
		var treasury_ratio := float(treasury.money + treasury.interest) / float(feeder.money)
		# Academy with the press plus two neighbours in reach (three turrets gaining the drop).
		var academy_ratio := float(academy.xp) / float(feeder.money)
		report.append("wave %d (%.0f s): feeder %d, treasury %d+%d (%.2fx), academy %d xp for 3 turrets (%.2fx)" % [wave, seconds, feeder.money, treasury.money, treasury.interest, treasury_ratio, academy.xp, academy_ratio])
		assert_between(treasury_ratio, 1.3, 1.95, "Treasury at wave %d" % wave)
		assert_between(academy_ratio, 1.4, 1.75, "Academy at wave %d" % wave)
	gut.p("\n".join(report))

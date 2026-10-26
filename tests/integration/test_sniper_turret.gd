extends GutTest

## Sniper line: stocking, the toughest-target hit-scan shot, the Piercer Rifle / Horizon Piercer line hits, and the
## Overwatch mark (marks three, jumps on death, +25% from every turret).

const GATE := "test_sniper_gate"

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child_autofree(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.session.state.turret_progression_enabled = true
	for turret in world.turrets:
		turret.set_physics_process(false)
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)

func after_each() -> void:
	ShopCatalog.reset()
	TestHelpers.reset_flags()

func _sniper(form_path: Array[String] = []) -> TurretActor:
	var turret := world.add_turret(Vector3(30, 0, 30), "sniper")
	turret.set_physics_process(false)
	turret.position = Vector3.ZERO
	if form_path.is_empty():
		return turret
	turret.progression.award(389 if form_path.size() > 1 else 110)
	for form in form_path:
		assert_true(turret.evolve(form), "%s evolves" % form)
	return turret

## An inert enemy (no AI, no ticking) with a fixed health.
func _enemy(at: Vector3, health: float = 100.0, type_id: String = "basic") -> CombatActor:
	var result := world.spawn_enemy(at, type_id)
	result.set_physics_process(false)
	result.health = health
	result.max_health = health
	return result

func _combat() -> void:
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	world.crowd.rebuild(world.enemies)

## One physics step of the real turret loop (targeting, cooldown, firing).
func _step(turret: TurretActor) -> void:
	world.crowd.rebuild(world.enemies)
	turret._physics_process(.016)

func _lost(enemy: CombatActor, start: float = 100.0) -> float:
	return start - enemy.health

# --- Shop ---

func test_sniper_is_stocked_at_its_registry_price_and_purchasable() -> void:
	assert_has(ArenaShop.TURRETS, "sniper")
	assert_has(ShopCatalog.available_ids("turret"), "sniper")
	assert_eq(TurretRegistry.get_base_price("sniper"), 18)
	var price := world.turret_price("sniper")
	assert_eq(price, EconomyService.calculate_turret_price(18, GameStateService.current_wave))
	EconomyService.total_scrap = 500
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", "sniper", price)])
	assert_true(world.shop.purchase(0))
	assert_eq(TurretStatsService.turret_counts.get("sniper", 0), 1)
	assert_eq(EconomyService.total_scrap, 500 - price)
	assert_gt(world.turret_price("sniper"), price, "Each additional turret raises the price")
	assert_eq(ArenaShop.offer_name(ShopOffer.new("turret", "sniper", 1)), "Sniper Turret")
	assert_ne(ArenaShop.offer_description(ShopOffer.new("turret", "sniper", 1)), "")

func test_shop_rolls_the_sniper_among_the_weapons() -> void:
	world.shop.rng = RandomNumberGenerator.new()
	world.shop.rng.seed = 7
	var seen := false
	for roll in 300:
		world.shop.generate()
		for offer: ShopOffer in EconomyService.current_shop_offers:
			if offer.kind == "turret" and offer.asset_id == "sniper":
				seen = true
				assert_eq(offer.price, world.turret_price("sniper"))
	assert_true(seen, "300 refreshes stock the Sniper at least once")

func test_flag_gating_removes_the_sniper_from_stock_and_purchase() -> void:
	FeatureFlagService.register_flag(GATE, {"name": "Gate", "scope": FeatureFlagService.SCOPE_EXPERIMENT})
	ShopCatalog.entries["turret"]["sniper"] = GATE
	assert_false(ShopCatalog.is_available("turret", "sniper"))
	assert_false("sniper" in ShopCatalog.available_ids("turret"))
	EconomyService.total_scrap = 500
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", "sniper", 1)])
	assert_false(world.shop.purchase(0), "A gated turret cannot be bought")
	world.shop.rng = RandomNumberGenerator.new()
	world.shop.rng.seed = 3
	for roll in 100:
		world.shop.generate()
		for offer: ShopOffer in EconomyService.current_shop_offers:
			assert_ne(offer.asset_id, "sniper")
	FeatureFlagService.set_enabled(GATE, true)
	assert_true(ShopCatalog.is_available("turret", "sniper"))

func test_shop_view_data_and_dev_tools_know_the_sniper() -> void:
	_sniper()
	assert_gt(world.dev.add_turret("sniper"), 0, "Dev panel adds any stocked type")
	var data := ShopViewData.build_data(world)
	var row: Dictionary = {}
	for entry: Dictionary in data.turrets:
		if entry.id == "sniper":
			row = entry
	assert_false(row.is_empty())
	assert_eq(row.name, "Sniper")
	assert_gt(float(data.dps), 0.0)
	assert_not_null(ShopArt.turret("sniper"))
	assert_true(ResourceLoader.exists("res://assets/ui/turrets/sniper.png"))

# --- Evolution gating, model and hardware ---

func test_sniper_milestones_offer_the_upgrade_then_both_finals() -> void:
	var turret := _sniper()
	turret.progression.award(389)
	assert_eq(turret.available_evolutions(), ["piercer_rifle"], "Level 5 offers exactly one upgrade")
	assert_false(turret.evolve("overwatch"), "A final cannot be taken first")
	assert_true(turret.evolve("piercer_rifle"))
	assert_eq(turret.available_evolutions(), ["horizon_piercer", "overwatch"], "Level 10 offers both finals")
	assert_true(turret.evolve("overwatch"))
	assert_eq(turret.display_name(), "Overwatch")
	assert_eq(turret.turret_type, "sniper")
	assert_true(turret.available_evolutions().is_empty())
	assert_false(turret.evolve("horizon_piercer"))

func test_every_sniper_form_uses_the_sniper_chassis_and_adds_visible_hardware() -> void:
	var turret := _sniper()
	assert_not_null(turret.model.find_child("CP_Sniper", true, false), "Base turret is the Sniper chassis")
	assert_null(turret.model.find_child("Pepperbox_Watchman", true, false), "No Ion placeholder")
	for part in ["RifleBarrel", "RifleBrake", "HorizonRail", "SpotterRing"]:
		assert_null(turret.model.find_child(part, true, false), "The base turret has no %s" % part)
	var base_tip := turret.muzzle.position
	turret.progression.award(389)
	assert_true(turret.evolve("piercer_rifle"))
	assert_not_null(turret.model.find_child("CP_Sniper", true, false), "Still the Sniper chassis")
	for part in ["RifleBarrel", "RifleBrake", "RifleCollar"]:
		assert_not_null(turret.model.find_child(part, true, false), part)
	assert_lt(turret.muzzle.position.z, base_tip.z - .3, "Shots leave from the end of the new barrel")
	assert_almost_eq(turret.muzzle.position.y, base_tip.y, .001, "The extension stays on the bore axis")
	var rifle_tip := turret.muzzle.position
	assert_true(turret.evolve("horizon_piercer"))
	assert_not_null(turret.model.find_child("CP_Sniper", true, false))
	assert_not_null(turret.model.find_child("HorizonRail", true, false))
	assert_null(turret.model.find_child("RifleBrake", true, false), "Horizon replaces the brake with its emitter")
	assert_not_null(turret.model.find_child("HorizonEmitter", true, false))
	assert_lt(turret.muzzle.position.z, rifle_tip.z, "The Horizon barrel is longer still")
	var other := _sniper(["piercer_rifle", "overwatch"])
	assert_not_null(other.model.find_child("CP_Sniper", true, false))
	assert_not_null(other.model.find_child("SpotterRing", true, false))
	assert_not_null(other.model.find_child("SpotterMast", true, false))
	assert_null(other.model.find_child("HorizonRail", true, false))
	assert_null(other.model.find_child("RifleBrake", true, false))
	assert_almost_eq(other.muzzle.position.z, base_tip.z, .001, "Overwatch keeps the chassis barrel and muzzle")
	assert_not_null(other.aim)
	assert_not_null(other.muzzle)

func test_shots_and_tracers_leave_from_the_extended_muzzle() -> void:
	var turret := _sniper(["piercer_rifle"])
	_combat()
	var target := _enemy(Vector3(0, 0, -5), 500.0)
	_step(turret)
	assert_lt(turret.muzzle.global_position.z, turret.aim.global_position.z - 1.0, "The muzzle sits well ahead of the swivel")
	assert_lt(target.health, 500.0, "The shot lands")

# --- Base shot ---

func test_sniper_hits_the_toughest_enemy_instantly_not_the_nearest() -> void:
	var turret := _sniper()
	_combat()
	var near := _enemy(Vector3(0, 0, -2), 30.0)
	var boss := _enemy(Vector3(2, 0, -5), 900.0, "broadside_baron")
	var tank := _enemy(Vector3(-3, 0, -4), 300.0, "tank")
	_step(turret)
	var damage := turret._current_view(0).damage
	assert_gt(damage, 0.0)
	assert_almost_eq(900.0 - boss.health, damage, .001)
	assert_eq(near.health, 30.0)
	assert_eq(tank.health, 300.0)
	for projectile in world.projectiles:
		assert_false(projectile.active, "Instant hit: no projectile flies")
	assert_almost_eq(turret.cooldown, 1.0 / .35, .01)
	_step(turret)
	assert_almost_eq(900.0 - boss.health, damage, .001, "Cooldown holds the second shot")

func test_sniper_ties_go_to_the_nearest_and_it_retargets_after_a_kill() -> void:
	var turret := _sniper()
	_combat()
	var far := _enemy(Vector3(0, 0, -6), 100.0)
	var near := _enemy(Vector3(0, 0, -2), 100.0)
	_step(turret)
	assert_lt(near.health, 100.0, "Equal health: the nearest")
	assert_eq(far.health, 100.0)
	near.health = 1.0
	turret.cooldown = 0.0
	_step(turret)
	assert_lt(far.health, 100.0, "Now the healthier one is the toughest")

func test_sniper_shoots_tech_drop_crates_when_they_are_toughest() -> void:
	var turret := _sniper()
	_combat()
	var crate := world.drops.spawn(Vector3(0, 0, -4))
	crate.set_physics_process(false)
	crate.health = 500.0
	crate.max_health = 500.0
	var grunt := _enemy(Vector3(0, 0, -2), 20.0)
	_step(turret)
	assert_lt(crate.health, 500.0)
	assert_eq(grunt.health, 20.0)

func test_base_sniper_does_not_pierce() -> void:
	var turret := _sniper()
	_combat()
	var front := _enemy(Vector3(0, 0, -3), 500.0)
	var behind := _enemy(Vector3(0, 0, -5), 100.0)
	_step(turret)
	assert_lt(front.health, 500.0)
	assert_eq(behind.health, 100.0)

func test_sniper_ignores_enemies_beyond_its_range() -> void:
	var turret := _sniper()
	_combat()
	var reach := turret.effective_range(turret._current_view(0))
	var out := _enemy(Vector3(0, 0, -(reach + 2.0)), 900.0)
	_step(turret)
	assert_eq(out.health, 900.0)
	assert_eq(turret.cooldown, 0.0, "Nothing in range: no shot spent")

func test_sniper_shot_counts_as_an_instant_hit_for_item_rules() -> void:
	var turret := _sniper()
	_combat()
	var seen: Array[CombatHit3D] = []
	world.combat.hit_applied.connect(func(_t: Node3D, hit: CombatHit3D, _a: float) -> void: seen.append(hit))
	_enemy(Vector3(0, 0, -3), 200.0)
	_step(turret)
	assert_eq(seen.size(), 1)
	assert_eq(seen[0].attack_families, ["instant"] as Array[String])
	assert_eq(seen[0].damage_type, GameEnums.DamageType.PHYSICAL)
	assert_eq(seen[0].source_id, turret.turret_id)

# --- Piercer Rifle ---

func test_piercer_rifle_passes_through_exactly_two_enemies_behind_the_target() -> void:
	var turret := _sniper(["piercer_rifle"])
	_combat()
	var target := _enemy(Vector3(0, 0, -2), 900.0)
	var one := _enemy(Vector3(0, 0, -3.2))
	var two := _enemy(Vector3(.1, 0, -4.4))
	var three := _enemy(Vector3(0, 0, -5.6))
	var beside := _enemy(Vector3(2.5, 0, -3.5))
	var in_front := _enemy(Vector3(0, 0, -1))
	in_front.health = 50.0
	_step(turret)
	var damage := turret._current_view(0).damage
	assert_almost_eq(900.0 - target.health, damage, .001)
	assert_almost_eq(_lost(one), damage, .001, "First enemy behind")
	assert_almost_eq(_lost(two), damage, .001, "Second enemy behind")
	assert_eq(three.health, 100.0, "A third enemy behind is spared")
	assert_eq(beside.health, 100.0, "Off the line")
	assert_eq(in_front.health, 50.0, "In front of the target")

func test_piercer_rifle_is_a_straight_improvement_over_the_base_shot() -> void:
	var base := _sniper()
	var rifle := _sniper(["piercer_rifle"])
	assert_gt(rifle._current_view(0).damage, base._current_view(0).damage)
	assert_gt(rifle._current_view(0).fire_rate, base._current_view(0).fire_rate)
	assert_gt(rifle._current_view(0).range_metres, base._current_view(0).range_metres)
	assert_eq(rifle._current_view(0).pierce, 2)

# --- Horizon Piercer ---

func test_horizon_piercer_hits_everything_on_the_line_to_full_range() -> void:
	var turret := _sniper(["piercer_rifle", "horizon_piercer"])
	_combat()
	var reach := turret.effective_range(turret._current_view(0))
	var front := _enemy(Vector3(0, 0, -1.5))
	var target := _enemy(Vector3(0, 0, -3), 900.0)
	var line: Array[CombatActor] = []
	for z in [-4.5, -6.0, -7.5, -(reach - .5)]:
		line.append(_enemy(Vector3(0, 0, z)))
	var beside := _enemy(Vector3(2.0, 0, -5))
	var beyond := _enemy(Vector3(0, 0, -(reach + 2.0)))
	_step(turret)
	var damage := turret._current_view(0).damage
	assert_almost_eq(900.0 - target.health, damage, .001)
	assert_almost_eq(_lost(front), damage, .001, "The whole line from the turret, in front of the target too")
	for enemy in line:
		assert_almost_eq(_lost(enemy), damage, .001)
	assert_eq(beside.health, 100.0)
	assert_eq(beyond.health, 100.0, "Past full range")

func test_horizon_piercer_outguns_the_piercer_rifle_single_target() -> void:
	var rifle := _sniper(["piercer_rifle"])
	rifle.progression.award(279) # same level 10 as the final, so only the form differs
	assert_eq(rifle.progression.level, 10)
	assert_eq(rifle._current_view(0).pierce, 2)
	var horizon := _sniper(["piercer_rifle", "horizon_piercer"])
	assert_gte(horizon._current_view(0).pierce, TurretEvolution.SNIPER_UNLIMITED_PIERCE)
	var ratio: float = (horizon._current_view(0).damage * horizon._current_view(0).fire_rate) / (rifle._current_view(0).damage * rifle._current_view(0).fire_rate)
	assert_between(ratio, 1.4, 1.6)

# --- Overwatch ---

func _overwatch_field() -> Dictionary:
	var turret := _sniper(["piercer_rifle", "overwatch"])
	_combat()
	return {
		"turret": turret,
		"first": _enemy(Vector3(0, 0, -3), 800.0, "tank"),
		"second": _enemy(Vector3(-3, 0, -3), 600.0, "tank"),
		"third": _enemy(Vector3(3, 0, -3), 400.0, "tank"),
		"fourth": _enemy(Vector3(0, 0, 4), 250.0),
		"fifth": _enemy(Vector3(-4, 0, 3), 90.0),
		"weak": _enemy(Vector3(4, 0, 3), 40.0),
	}

func test_overwatch_marks_the_three_toughest_enemies_in_range() -> void:
	var f := _overwatch_field()
	var turret: TurretActor = f.turret
	_step(turret)
	var marked: Array[CombatActor] = turret.form.marked_enemies()
	assert_eq(marked.size(), 3)
	for key in ["first", "second", "third"]:
		assert_true(f[key].statuses.is_marked(), key)
		assert_almost_eq(f[key].statuses.marked_remaining, TurretEvolution.OVERWATCH_MARK_SECONDS, .001)
	for key in ["fourth", "fifth", "weak"]:
		assert_false(f[key].statuses.is_marked(), key)

func test_overwatch_does_not_mark_enemies_out_of_range() -> void:
	var f := _overwatch_field()
	var turret: TurretActor = f.turret
	var reach := turret.effective_range(turret._current_view(0))
	var out := _enemy(Vector3(0, 0, -(reach + 3.0)), 5000.0, "tank")
	_step(turret)
	assert_false(out.statuses.is_marked())
	assert_true(f.first.statuses.is_marked())

func test_overwatch_shot_lands_on_the_target_it_just_marked() -> void:
	var f := _overwatch_field()
	var turret: TurretActor = f.turret
	_step(turret)
	var damage := turret._current_view(0).damage
	assert_almost_eq(800.0 - f.first.health, damage * 1.25, .01, "The shot is amplified by the mark it placed")

func test_marked_enemies_take_25_percent_more_from_other_turrets() -> void:
	var f := _overwatch_field()
	var turret: TurretActor = f.turret
	_step(turret)
	var ion := world.add_turret(Vector3(12, 0, 12), "normal")
	ion.set_physics_process(false)
	var marked: CombatActor = f.second
	var unmarked: CombatActor = f.fourth
	var before_marked := marked.health
	var before_unmarked := unmarked.health
	var from_ion := CombatHit3D.new(10.0)
	from_ion.source_id = ion.turret_id
	from_ion.attack_families = ["projectile"]
	world.combat.apply_hit(marked, from_ion)
	world.combat.apply_hit(unmarked, from_ion)
	assert_almost_eq(before_marked - marked.health, 12.5, .001, "+25% from a turret that is not the Sniper")
	assert_almost_eq(before_unmarked - unmarked.health, 10.0, .001)
	var hero := CombatHit3D.new(10.0)
	var health := marked.health
	world.combat.apply_hit(marked, hero)
	assert_almost_eq(health - marked.health, 10.0, .001, "Hits with no turret source are not amplified")

func test_mark_stacks_multiplicatively_with_exposed() -> void:
	var f := _overwatch_field()
	_step(f.turret)
	var enemy: CombatActor = f.second
	enemy.statuses.expose(5.0)
	var hit := CombatHit3D.new(10.0)
	hit.source_id = 99
	hit.attack_families = ["instant"]
	var before := enemy.health
	world.combat.apply_hit(enemy, hit)
	assert_almost_eq(before - enemy.health, 16.25, .001, "10 x 1.3 x 1.25")

func test_mark_jumps_to_the_next_toughest_unmarked_enemy_when_a_marked_one_dies() -> void:
	var f := _overwatch_field()
	var turret: TurretActor = f.turret
	_step(turret)
	for key in ["first", "second", "third"]:
		f[key].statuses.advance_mark(2.0)
	turret.form.tick(.016)
	var killed: CombatActor = f.second
	var hit := CombatHit3D.new(100000.0)
	hit.source_id = turret.turret_id
	world.combat.apply_hit(killed, hit)
	assert_true(killed.dead)
	assert_false(killed.statuses.is_marked(), "Death clears the status")
	turret.form.tick(.016)
	assert_true(f.fourth.statuses.is_marked(), "The 250-health enemy is the next toughest unmarked")
	assert_almost_eq(f.fourth.statuses.marked_remaining, 4.0, .05, "The mark keeps the time it had left")
	assert_false(f.fifth.statuses.is_marked())
	assert_eq(turret.form.marked_enemies().size(), 3)
	var before: float = f.fourth.health
	var amplified := CombatHit3D.new(10.0)
	amplified.source_id = 99
	world.combat.apply_hit(f.fourth, amplified)
	assert_almost_eq(before - f.fourth.health, 12.5, .001)

func test_mark_does_not_jump_when_it_expires_and_dies_with_nothing_left_to_mark() -> void:
	var f := _overwatch_field()
	var turret: TurretActor = f.turret
	_step(turret)
	for key in ["first", "second", "third"]:
		f[key].statuses.advance_mark(7.0)
	turret.form.tick(.016)
	assert_true(turret.form.marked_enemies().is_empty(), "Expired marks are dropped")
	assert_false(f.fourth.statuses.is_marked(), "Only deaths move a mark")
	turret.cooldown = 0.0
	_step(turret)
	for key in ["fourth", "fifth", "weak", "first", "third"]:
		world.combat.apply_hit(f[key], CombatHit3D.new(100000.0))
	turret.form.tick(.016)
	assert_true(f.second.statuses.is_marked())
	world.combat.apply_hit(f.second, CombatHit3D.new(100000.0))
	turret.form.tick(.016)
	assert_true(turret.form.marked_enemies().is_empty())

func test_overwatch_moves_marks_to_the_toughest_set_on_each_shot() -> void:
	var f := _overwatch_field()
	var turret: TurretActor = f.turret
	_step(turret)
	f.first.health = 10.0
	f.fourth.health = 700.0
	turret.cooldown = 0.0
	_step(turret)
	assert_false(f.first.statuses.is_marked(), "No longer among the three toughest")
	assert_true(f.fourth.statuses.is_marked())
	assert_eq(turret.form.marked_enemies().size(), 3)

func test_marks_clear_on_wave_end_pause_and_death() -> void:
	var f := _overwatch_field()
	var turret: TurretActor = f.turret
	_step(turret)
	assert_true(f.first.statuses.is_marked())
	world.toggle_pause()
	turret._physics_process(.016)
	for key in ["first", "second", "third"]:
		assert_false(f[key].statuses.is_marked(), "Pause: %s" % key)
	assert_true(turret.form.marked_enemies().is_empty())
	world.toggle_pause()
	turret.cooldown = 0.0
	_step(turret)
	assert_true(f.first.statuses.is_marked(), "Marking resumes with the next shot")
	f.second.clear_transients()
	assert_false(f.second.statuses.is_marked(), "Wave end clears transients")
	var survivor: CombatActor = f.first
	world.clear_field(false)
	assert_true(world.enemies.is_empty())
	assert_false(survivor.statuses.is_marked())

func test_mark_ring_shows_while_marked_and_stationary_enemies_lose_the_mark() -> void:
	var f := _overwatch_field()
	_step(f.turret)
	var crate := world.drops.spawn(Vector3(0, 0, -6))
	crate.set_physics_process(false)
	crate.statuses.mark(2.0)
	crate._tick_statuses(1.0)
	assert_not_null(crate.mark_marker)
	assert_true(crate.mark_marker.visible)
	assert_almost_eq(crate.statuses.marked_remaining, 1.0, .001)
	crate._tick_statuses(1.5)
	assert_false(crate.statuses.is_marked(), "A tech-drop crate mark expires too")
	assert_false(crate.mark_marker.visible)
	var marked: CombatActor = f.first
	marked._tick_statuses(.1)
	assert_true(marked.mark_marker.visible)
	marked.clear_transients()
	assert_false(marked.mark_marker.visible)

func test_a_second_overwatch_refreshes_rather_than_stacks_the_bonus() -> void:
	var second := _sniper(["piercer_rifle", "overwatch"])
	var f := _overwatch_field()
	_step(f.turret)
	_step(second)
	var enemy: CombatActor = f.first
	var before := enemy.health
	var hit := CombatHit3D.new(10.0)
	hit.source_id = 99
	world.combat.apply_hit(enemy, hit)
	assert_almost_eq(before - enemy.health, 12.5, .001, "Two Overwatches still give a single +25%")

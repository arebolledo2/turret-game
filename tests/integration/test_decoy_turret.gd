extends GutTest

## Decoy line: stocking, the light pulse, the S1 taunt it publishes, Bumper Post's harder shove, Pile Driver's fourth-pulse slam
## and Maelstrom's bounded hooks (cap, tick damage, clean-up on wave end, pause, reset, removal and pickup, and two Decoys
## never releasing each other's hooks). How enemies react to a taunt is in `test_taunt_targeting.gd`.

const GATE := "test_decoy_gate"
const STEP := 1.0 / 60.0

var rig: TurretTestRig
var world: ArenaWorld

func before_each() -> void:
	rig = TurretTestRig.start(self)
	rig.disable_crits()
	world = rig.world

func after_each() -> void:
	ShopCatalog.reset()
	TestHelpers.reset_flags()

func _decoy(form_path: Array[String] = [], at: Vector3 = Vector3.ZERO) -> TurretActor:
	return rig.turret("decoy", form_path, at)

func _enemy(at: Vector3, health: float = 1000.0, type_id: String = "basic") -> EnemyActor:
	return rig.enemy(at, health, type_id) as EnemyActor

func _combat() -> void:
	rig.combat()

func _step(turret: TurretActor) -> void:
	rig.step(turret, STEP)

func _run(turret: TurretActor, seconds: float) -> void:
	rig.run(turret, seconds, STEP)

func _lost(enemy: CombatActor, start: float = 1000.0) -> float:
	return start - enemy.health

## Records every turret hit as [enemy, damage] in order.
func _record_hits() -> Array:
	var log: Array = []
	world.combat.hit_applied.connect(func(target: Node3D, hit: CombatHit3D, applied: float) -> void:
		if hit.source_id > 0 and applied > 0.0 and not hit.is_dot:
			log.append([target, applied]))
	return log

func _maelstrom(at: Vector3 = Vector3.ZERO) -> TurretActor:
	return _decoy(["bumper_post", "maelstrom"], at)

# --- Shop, registry and items ---

func test_decoy_is_stocked_at_its_registry_price_and_purchasable() -> void:
	assert_has(ArenaShop.TURRETS, "decoy")
	assert_has(ShopCatalog.available_ids("turret"), "decoy")
	assert_eq(TurretRegistry.get_base_price("decoy"), 10)
	var price := world.turret_price("decoy")
	assert_eq(price, EconomyService.calculate_turret_price(10, GameStateService.current_wave))
	EconomyService.total_scrap = 500
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", "decoy", price)])
	assert_true(world.shop.purchase(0))
	assert_eq(TurretStatsService.turret_counts.get("decoy", 0), 1)
	assert_eq(EconomyService.total_scrap, 500 - price)
	assert_eq(ArenaShop.offer_name(ShopOffer.new("turret", "decoy", 1)), "Decoy Turret")
	assert_ne(ArenaShop.offer_description(ShopOffer.new("turret", "decoy", 1)), "")

func test_shop_rolls_the_decoy_among_the_weapons_and_a_flag_can_gate_it() -> void:
	world.shop.rng = RandomNumberGenerator.new()
	world.shop.rng.seed = 11
	var seen := false
	for roll in 300:
		world.shop.generate()
		for offer: ShopOffer in EconomyService.current_shop_offers:
			if offer.kind == "turret" and offer.asset_id == "decoy":
				seen = true
	assert_true(seen, "300 refreshes stock the Decoy at least once")
	FeatureFlagService.register_flag(GATE, {"name": "Gate", "scope": FeatureFlagService.SCOPE_EXPERIMENT})
	ShopCatalog.entries["turret"]["decoy"] = GATE
	assert_false(ShopCatalog.is_available("turret", "decoy"))
	EconomyService.total_scrap = 500
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", "decoy", 1)])
	assert_false(world.shop.purchase(0), "A gated turret cannot be bought")

func test_shop_view_data_dev_tools_and_art_know_the_decoy() -> void:
	_decoy()
	assert_gt(world.dev.add_turret("decoy"), 0)
	var data := ShopViewData.build_data(world)
	var row: Dictionary = {}
	for entry: Dictionary in data.turrets:
		if entry.id == "decoy":
			row = entry
	assert_false(row.is_empty())
	assert_eq(row.name, "Decoy")
	assert_same(ShopArt.turret("decoy"), load("res://assets/ui/turrets/decoy.png"), "The shop shows the portrait file, not the icon fallback")
	for form in ["decoy", "bumper_post", "pile_driver", "maelstrom"]:
		assert_true(ResourceLoader.exists("res://assets/ui/turrets/%s.png" % form), form)
	assert_not_null(UiIcons.turret("decoy"))
	assert_true(UiIconData.PATHS.has("turret_decoy"))

func test_registry_entry_is_a_light_kinetic_aoe_pulse_in_the_aggro_family() -> void:
	var base := TurretRegistry.get_base_stats("decoy")
	assert_eq(base.damage, 3.0)
	assert_almost_eq(float(base.fire_rate), 1.0 / 1.5, .0001, "One pulse every 1.5 s")
	assert_eq(base.range, 150.0)
	assert_eq(base.knockback_force, 150.0)
	assert_eq(base.taunt_range, 450.0)
	assert_eq(TurretRegistry.get_damage_type("decoy"), GameEnums.DamageType.PHYSICAL)
	assert_eq(TurretRegistry.get_fire_mode("decoy"), TurretRegistry.FIRE_PULSE)
	assert_eq(TurretRegistry.get_attack_families("decoy"), ["aoe", "kinetic"] as Array[String])
	assert_eq(TurretRegistry.get_family("decoy"), "aggro")
	assert_false(TurretRegistry.is_no_attack("decoy"), "It attacks, so the attack-counting item rules include it")
	assert_true(TurretRegistry.has_capability("decoy", "knockback"))

func test_kinetic_and_aoe_items_reach_the_decoy_and_area_also_widens_the_taunt() -> void:
	var turret := _decoy()
	var before := turret._current_view(0)
	ModifierService.add_modifier({"stat": "range", "operation": "increase", "value": .5, "filter": {"attack_family": ["kinetic"]}})
	ModifierService.add_modifier({"stat": "damage", "operation": "increase", "value": .5, "filter": {"attack_family": ["projectile"]}})
	turret.invalidate_stats()
	var after := turret._current_view(0)
	assert_almost_eq(after.range_metres, before.range_metres * 1.5, .001, "Kinetic reach grows the pulse radius")
	assert_eq(after.damage, before.damage, "A projectile item does nothing")
	assert_almost_eq(after.taunt_metres, before.taunt_metres, .001, "Plain reach does not move the taunt")
	ModifierService.clear_modifiers()
	ModifierService.add_modifier({"stat": "area_size", "operation": "increase", "value": .2, "filter": {"attack_family": ["aoe"]}})
	turret.invalidate_stats()
	var wide := turret._current_view(0)
	assert_almost_eq(turret.effective_range(wide), 1.5 * 1.2, .001, "AoE area bonuses widen the pulse")
	assert_almost_eq(wide.taunt_metres, 4.5 * 1.2, .001, "and the taunt")

func test_an_aggro_item_reaches_the_decoy_through_its_family() -> void:
	ModifierService.add_modifier(Item.create_increase("damage", .5, Item.filter_family(["aggro"])))
	var turret := _decoy()
	turret.invalidate_stats()
	assert_almost_eq(turret._current_view(0).damage, 3.0 * 1.5, .001)

# --- Evolution gating and hardware ---

func test_decoy_milestones_offer_the_upgrade_then_both_finals() -> void:
	var turret := _decoy()
	turret.progression.award(389)
	assert_eq(turret.available_evolutions(), ["bumper_post"], "Level 5 offers exactly one upgrade")
	assert_false(turret.evolve("maelstrom"), "A final cannot be taken first")
	assert_true(turret.evolve("bumper_post"))
	assert_eq(turret.available_evolutions(), ["pile_driver", "maelstrom"], "Level 10 offers both finals")
	assert_true(turret.evolve("pile_driver"))
	assert_eq(turret.display_name(), "Pile Driver")
	assert_eq(turret.turret_type, "decoy")
	assert_true(turret.available_evolutions().is_empty())

func test_every_decoy_form_adds_its_own_hardware_to_the_cp_decoy_chassis() -> void:
	var base := _decoy()
	assert_not_null(base.model.find_child("Lantern_Cage", true, false), "The cp_decoy chassis is the Decoy's model")
	assert_null(base.model.find_child("Bell shell", true, false), "and not the Shock bell")
	for part in ["BumperCore", "BumperRing", "PistonColumn", "AnvilHead", "HookMast", "HookArm", "LaneRing"]:
		assert_null(base.model.find_child(part, true, false), "The base turret has no %s" % part)
	var upgrade := _decoy(["bumper_post"])
	for part in ["BumperCore", "BumperPad", "BumperCap", "BumperRing"]:
		assert_not_null(upgrade.model.find_child(part, true, false), part)
	assert_null(upgrade.model.find_child("PistonColumn", true, false))
	var driver := _decoy(["bumper_post", "pile_driver"])
	for part in ["PistonColumn", "PistonCollar", "PistonRam", "AnvilStem", "AnvilHead"]:
		assert_not_null(driver.model.find_child(part, true, false), part)
	assert_null(driver.model.find_child("BumperCore", true, false))
	var maelstrom := _maelstrom()
	for part in ["HookMast", "HookArm", "HookTip", "LaneRing"]:
		assert_not_null(maelstrom.model.find_child(part, true, false), part)
	assert_null(maelstrom.model.find_child("PistonColumn", true, false))
	for turret in [base, upgrade, driver, maelstrom]:
		assert_not_null(turret.aim)
		assert_not_null(turret.muzzle)

func test_decoy_hardware_stands_clear_of_the_head_and_beside_the_base() -> void:
	var base_box := (_decoy().model.find_child("Base_Body", true, false) as MeshInstance3D).mesh.get_aabb()
	var ring_box := (_decoy().model.find_child("Bumper_Ring", true, false) as MeshInstance3D).mesh.get_aabb()
	var radius := minf(base_box.size.x, base_box.size.z) * .5
	var ring_radius := minf(ring_box.size.x, ring_box.size.z) * .5
	var posts := _decoy(["bumper_post"]).model.find_children("BumperCore*", "MeshInstance3D", true, false)
	assert_eq(posts.size(), 4)
	for post in posts:
		var at := (post as Node3D).position
		assert_gt(Vector2(at.x, at.z).length(), ring_radius, "A bumper post stands outside the model's bumper ring")
		assert_lt(Vector2(at.x, at.z).length(), radius + .2, "within reach of it")
		assert_gt(at.y + (post as MeshInstance3D).mesh.get_aabb().size.y * .5, base_box.end.y, "and rises above the base")
	var maelstrom := _maelstrom()
	var lanes := maelstrom.model.find_children("LaneRing*", "MeshInstance3D", true, false)
	assert_eq(lanes.size(), 2)
	for lane in lanes:
		var torus := (lane as MeshInstance3D).mesh as TorusMesh
		assert_gt(torus.inner_radius, radius, "The lane rings circle the base")
		assert_lt(torus.outer_radius, maelstrom._current_view(0).range_metres, "inside the pulse reach, so the pulse hits the orbit")

# --- Base pulse ---

func test_the_decoy_only_pulses_with_an_enemy_in_reach() -> void:
	var turret := _decoy()
	_combat()
	var far := _enemy(Vector3(0, 0, -3.5))
	_run(turret, 2.0)
	assert_eq(far.health, 1000.0, "Beyond the 1.5 m reach nothing is hit, even inside the taunt")
	assert_eq(turret.cooldown, 0.0, "and no pulse is spent")
	var near := _enemy(Vector3(0, 0, -1.2))
	_step(turret)
	assert_almost_eq(_lost(near), 3.0, .001, "3 damage")
	assert_eq(far.health, 1000.0)
	assert_almost_eq(turret.cooldown, 1.5, .03, "and the next pulse is 1.5 s away")

func test_the_pulse_hits_everything_in_reach_once_shoves_it_back_and_does_not_stagger() -> void:
	var turret := _decoy()
	_combat()
	var east := _enemy(Vector3(1.0, 0, 0))
	var north := _enemy(Vector3(0, 0, -1.0))
	var seen: Array[CombatHit3D] = []
	world.combat.hit_applied.connect(func(_t: Node3D, hit: CombatHit3D, _a: float) -> void: seen.append(hit))
	_step(turret)
	assert_eq(seen.size(), 2)
	assert_eq(seen[0].attack_families, ["aoe", "kinetic"] as Array[String])
	assert_eq(seen[0].damage_type, GameEnums.DamageType.PHYSICAL)
	assert_eq(seen[0].source_id, turret.turret_id)
	assert_almost_eq(seen[0].source_area_radius, 1.5, .001, "Area items read the pulse radius")
	assert_gt(east.knockback_velocity.x, .5, "Pushed east, away from the turret")
	assert_lt(north.knockback_velocity.z, -.5, "Pushed north")
	assert_almost_eq(east.knockback_velocity.length(), 1.5, .1, "Knockback 150 is 1.5 m/s for a body of mass 1")
	assert_false(east.statuses.is_staggered(), "A light pulse does not stagger")

func test_bumper_post_hits_harder_faster_and_shoves_half_again_as_far() -> void:
	var base := _decoy()
	var upgrade := _decoy(["bumper_post"], Vector3(20, 0, 0))
	var base_view := base._current_view(0)
	var view := upgrade._current_view(0)
	assert_almost_eq(view.damage / base_view.damage, 8.0 * 1.1 / 3.0, .01, "8 against 3, both with their level bonuses")
	assert_almost_eq(view.cooldown_seconds, 1.2 / 1.1, .01, "A pulse every 1.2 s before the level bonus")
	assert_almost_eq(view.knockback_metres, 2.25, .001, "Knockback x1.5")
	assert_almost_eq(view.taunt_metres, 4.5, .001, "The taunt is still 4.5 m")
	_combat()
	var target := _enemy(Vector3(20, 0, -1.0))
	_step(upgrade)
	assert_almost_eq(_lost(target), view.damage, .001)
	assert_almost_eq(target.knockback_velocity.length(), 2.25, .15)

# --- The taunt it publishes ---

func test_a_fighting_decoy_publishes_its_taunt_and_a_resting_one_does_not() -> void:
	var turret := _decoy()
	assert_false(world.taunts.has_posts(), "Nothing is published before combat")
	_combat()
	_step(turret)
	var post := world.taunts.post_of(turret.turret_id)
	assert_not_null(post)
	assert_almost_eq(post.radius, 4.5, .001, "450 units is 4.5 m")
	assert_false(post.ranged, "A plain Decoy does not draw ranged enemies")
	assert_same(post.turret, turret)
	rig.shop()
	_step(turret)
	assert_false(world.taunts.has_posts(), "Wave end withdraws the taunt")

func test_the_taunt_follows_the_decoy_and_stops_while_it_is_carried() -> void:
	var turret := _decoy()
	_combat()
	_step(turret)
	var enemy := _enemy(Vector3(0, 0, -3))
	assert_not_null(enemy.taunt_post())
	turret.carried = true
	assert_null(enemy.taunt_post(), "A Decoy on the hero's back draws nobody off the hero")
	turret.carried = false
	assert_not_null(enemy.taunt_post())

func test_pausing_withdraws_the_taunt_and_resuming_publishes_it_again() -> void:
	var turret := _decoy()
	_combat()
	_step(turret)
	world.paused = true
	_step(turret)
	assert_false(world.taunts.has_posts())
	world.paused = false
	_step(turret)
	assert_true(world.taunts.has_posts())

func test_a_removed_decoy_leaves_no_taunt_behind() -> void:
	var turret := _decoy()
	_combat()
	_step(turret)
	var enemy := _enemy(Vector3(0, 0, -3))
	assert_not_null(enemy.taunt_post())
	world.turrets.erase(turret)
	turret.get_parent().remove_child(turret)
	turret.free()
	assert_false(world.taunts.has_posts(), "Sold or removed: the taunt goes with the turret")
	assert_null(enemy.taunt_post())

func test_a_run_reset_leaves_no_taunt_behind() -> void:
	var turret := _decoy()
	_combat()
	_step(turret)
	world._clear_actors()
	assert_false(world.taunts.has_posts())

func test_evolving_swaps_the_taunt_for_the_new_forms() -> void:
	var turret := _decoy()
	_combat()
	_step(turret)
	var first := world.taunts.post_of(turret.turret_id)
	rig.shop()
	rig.level_to(turret, 5)
	assert_true(turret.evolve("bumper_post"))
	_combat()
	_step(turret)
	assert_eq(world.taunts.posts.size(), 1, "One post per Decoy, never two")
	assert_not_same(world.taunts.post_of(turret.turret_id), first)

func test_two_decoys_publish_separate_taunts() -> void:
	var left := _decoy([], Vector3(-6, 0, 0))
	var right := _decoy([], Vector3(6, 0, 0))
	_combat()
	_step(left)
	_step(right)
	assert_eq(world.taunts.posts.size(), 2)
	rig.shop()
	_step(left)
	assert_eq(world.taunts.posts.size(), 1, "One Decoy resting does not withdraw the other's")
	assert_not_null(world.taunts.post_of(right.turret_id))

# --- Pile Driver ---

func test_pile_driver_numbers_and_dps_estimate() -> void:
	var turret := _decoy(["bumper_post", "pile_driver"])
	var view := turret._current_view(0)
	assert_eq(turret.form.slam_every(), 4)
	var average := (3.0 + 3.0) / 4.0
	assert_almost_eq(turret.form.estimate_dps(view), view.damage * view.fire_rate * average, .001, "Three plain pulses and a triple slam")
	var upgrade := _decoy(["bumper_post"], Vector3(20, 0, 0))
	assert_gt(turret.form.estimate_dps(view), upgrade.form.estimate_dps(upgrade._current_view(0)), "The final out-damages the upgrade")

func test_every_fourth_pile_driver_pulse_is_a_slam_with_triple_damage_wider_reach_and_stagger() -> void:
	var turret := _decoy(["bumper_post", "pile_driver"])
	var view := turret._current_view(0)
	var reach := turret.effective_range(view)
	_combat()
	var inner := _enemy(Vector3(0, 0, -1.0))
	var rim := _enemy(Vector3(0, 0, -(reach * 1.25)))
	var log := _record_hits()
	for pulse in 8:
		inner.statuses.clear()
		rim.statuses.clear()
		turret.cooldown = 0.0
		_step(turret)
		var slam: bool = (pulse + 1) % 4 == 0
		var inner_hit := 0.0
		var rim_hit := 0.0
		for entry: Array in log:
			if entry[0] == inner:
				inner_hit = entry[1]
			elif entry[0] == rim:
				rim_hit = entry[1]
		log.clear()
		assert_almost_eq(inner_hit, view.damage * (3.0 if slam else 1.0), .001, "Pulse %d" % (pulse + 1))
		if slam:
			assert_almost_eq(rim_hit, view.damage * 3.0, .001, "The slam reaches 1.5 times as far")
			assert_true(inner.statuses.is_staggered(), "and staggers")
			assert_between(inner.statuses.staggered_remaining, .55, .61, "for 0.6 s")
			assert_true(rim.statuses.is_staggered())
		else:
			assert_eq(rim_hit, 0.0, "A plain pulse does not reach the rim")
			assert_false(inner.statuses.is_staggered(), "and does not stagger")
	assert_eq(turret.form.slams_released, 2)
	assert_eq(turret.form.pulses_released, 8)

func test_a_slam_never_staggers_a_boss_but_still_shoves_it() -> void:
	var turret := _decoy(["bumper_post", "pile_driver"])
	_combat()
	var boss := _enemy(Vector3(0, 0, -1.0), 1000.0, "brass_ram")
	for pulse in 4:
		turret.cooldown = 0.0
		_step(turret)
	assert_false(boss.statuses.is_staggered(), "Bosses resist stagger")
	assert_lt(boss.health, 1000.0)

# --- Maelstrom ---

func test_maelstrom_widens_the_taunt_to_seven_metres_and_draws_ranged_enemies() -> void:
	var turret := _maelstrom()
	_combat()
	_step(turret)
	var post := world.taunts.post_of(turret.turret_id)
	assert_almost_eq(post.radius, 7.0, .001)
	assert_true(post.ranged)
	var kite := _enemy(Vector3(0, 0, -6.0), 100.0, "kite")
	var lobber := _enemy(Vector3(5.0, 0, 0), 100.0, "lobber")
	var runner := _enemy(Vector3(-6.5, 0, 0))
	assert_same(kite.taunt_post(), post)
	assert_same(lobber.taunt_post(), post)
	assert_same(runner.taunt_post(), post)
	assert_null(_enemy(Vector3(0, 0, 7.5)).taunt_post(), "Beyond seven metres nobody answers")

func test_maelstrom_hooks_enemies_in_reach_including_ranged_ones_but_never_bosses_or_crates() -> void:
	var turret := _maelstrom()
	_combat()
	var runner := _enemy(Vector3(0, 0, -4.0))
	var kite := _enemy(Vector3(3.0, 0, 0), 100.0, "kite")
	var far := _enemy(Vector3(0, 0, 9.0))
	var boss := _enemy(Vector3(-3.0, 0, 0), 1000.0, "brass_ram")
	var crate := TechDropActor.new()
	crate.world = world
	world.enemies.append(crate)
	crate.position = Vector3(2.0, 0, 3.0)
	autofree(crate)
	_run(turret, .6)
	assert_true(runner.is_hooked())
	assert_true(kite.is_hooked(), "Ranged enemies are drawn into the hook")
	assert_false(far.is_hooked(), "Outside the taunt radius")
	assert_false(boss.is_hooked(), "Bosses are never hooked")
	assert_eq(turret.form.hooked.size(), 2)
	world.enemies.erase(crate)

func test_hooks_are_capped_nearest_first_and_a_free_slot_is_refilled() -> void:
	var turret := _maelstrom()
	_combat()
	var crowd: Array[EnemyActor] = []
	for index in 14:
		crowd.append(_enemy(Vector3(0, 0, -(2.5 + float(index) * .3))))
	_run(turret, 1.0)
	assert_eq(turret.form.hooked.size(), 10, "At most ten hooks")
	for index in 14:
		assert_eq(crowd[index].is_hooked(), index < 10, "The nearest ten are hooked (%d)" % index)
	world.combat.apply_hit(crowd[0], CombatHit3D.new(1.0e9, Vector3.ZERO))
	_run(turret, .6)
	assert_eq(turret.form.hooked.size(), 10, "A dead enemy frees its slot")
	assert_true(crowd[10].is_hooked(), "and the next nearest takes it")
	assert_false(crowd[0].is_hooked(), "A dead enemy holds no hook")

func test_hooks_last_until_the_enemy_dies_even_beyond_the_taunt_radius() -> void:
	var turret := _maelstrom()
	_combat()
	var enemy := _enemy(Vector3(0, 0, -4.0))
	_run(turret, .6)
	assert_true(enemy.is_hooked())
	enemy.position = Vector3(0, 0, -20.0)
	_run(turret, 2.0)
	assert_true(enemy.is_hooked(), "A hook is not lost by being flung out of reach")
	assert_eq(turret.form.hooked.size(), 1)

func test_hooked_enemies_take_a_light_tick_that_is_not_a_pulse() -> void:
	var turret := _maelstrom()
	var view := turret._current_view(0)
	_combat()
	var enemy := _enemy(Vector3(0, 0, -4.0))
	var seen: Array[CombatHit3D] = []
	world.combat.hit_applied.connect(func(_t: Node3D, hit: CombatHit3D, _a: float) -> void: seen.append(hit))
	_run(turret, 3.2)
	assert_gt(seen.size(), 4)
	var tick := seen[0]
	assert_true(tick.is_dot, "Item rules that watch ordinary hits skip it")
	assert_almost_eq(tick.damage, view.damage * .25, .001, "A quarter of the pulse damage")
	assert_eq(tick.attack_families, ["aoe"] as Array[String], "AoE, not kinetic: no shove and no slow riders")
	assert_true(tick.impulse.is_zero_approx())
	assert_eq(tick.source_id, turret.turret_id)
	assert_almost_eq(_lost(enemy), tick.damage * seen.size(), .01)

func test_wave_end_lets_go_of_every_hook() -> void:
	var turret := _maelstrom()
	_combat()
	var enemies: Array[EnemyActor] = []
	for index in 4:
		enemies.append(_enemy(Vector3(float(index) - 1.5, 0, -4.0)))
	_run(turret, .6)
	assert_eq(turret.form.hooked.size(), 4)
	rig.shop()
	_step(turret)
	assert_true(turret.form.hooked.is_empty())
	for enemy in enemies:
		assert_false(enemy.is_hooked())
	assert_false(world.taunts.has_posts())

func test_pausing_lets_go_of_the_hooks_and_resuming_hooks_again() -> void:
	var turret := _maelstrom()
	_combat()
	var enemy := _enemy(Vector3(0, 0, -4.0))
	_run(turret, .6)
	assert_true(enemy.is_hooked())
	world.paused = true
	_step(turret)
	assert_false(enemy.is_hooked())
	assert_true(turret.form.hooked.is_empty())
	world.paused = false
	_run(turret, .6)
	assert_true(enemy.is_hooked(), "and it takes hold again on resuming")

func test_removing_the_decoy_lets_go_of_its_hooks() -> void:
	var turret := _maelstrom()
	_combat()
	var enemy := _enemy(Vector3(0, 0, -4.0))
	_run(turret, .6)
	assert_true(enemy.is_hooked())
	world.turrets.erase(turret)
	turret.get_parent().remove_child(turret)
	turret.free()
	assert_false(enemy.is_hooked(), "Sold: the enemies are free the moment it leaves")
	assert_false(world.taunts.has_posts())

func test_a_run_reset_lets_go_of_the_hooks() -> void:
	var turret := _maelstrom()
	_combat()
	var enemy := _enemy(Vector3(0, 0, -4.0))
	_run(turret, .6)
	assert_true(enemy.is_hooked())
	world._clear_actors()
	assert_false(enemy.is_hooked())
	assert_true(turret.form.hooked.is_empty())
	assert_false(world.taunts.has_posts())

func test_picking_the_decoy_up_lets_go_of_its_hooks() -> void:
	var turret := _maelstrom()
	_combat()
	var enemy := _enemy(Vector3(0, 0, -4.0))
	_run(turret, .6)
	assert_true(enemy.is_hooked())
	turret.carried = true
	_step(turret)
	assert_false(enemy.is_hooked())
	_run(turret, 1.0)
	assert_false(enemy.is_hooked(), "A carried Decoy hooks nobody")
	assert_true(turret.form.hooked.is_empty())

func test_evolving_lets_go_of_the_old_forms_hooks() -> void:
	var turret := _maelstrom()
	_combat()
	var enemy := _enemy(Vector3(0, 0, -4.0))
	_run(turret, .6)
	assert_true(enemy.is_hooked())
	turret.form.removed()
	assert_false(enemy.is_hooked())

func test_two_decoys_never_clear_each_others_hooks() -> void:
	var left := _maelstrom(Vector3(-3, 0, 0))
	var right := _maelstrom(Vector3(3, 0, 0))
	_combat()
	var shared := _enemy(Vector3(0, 0, -3.0))
	var only_left := _enemy(Vector3(-8.0, 0, -2.0))
	_run(left, .6)
	_run(right, .6)
	assert_true(shared.is_hooked())
	assert_gt(shared.statuses.remaining_for_owner(TauntField.HOOKED, left.turret_id), 0.0)
	assert_gt(shared.statuses.remaining_for_owner(TauntField.HOOKED, right.turret_id), 0.0)
	assert_true(only_left.is_hooked())
	# The left Decoy is sold, paused or reset: only its own timers go.
	left.get_parent().remove_child(left)
	left.free()
	assert_true(shared.is_hooked(), "The right Decoy still holds the shared enemy")
	assert_gt(shared.statuses.remaining_for_owner(TauntField.HOOKED, right.turret_id), 0.0)
	assert_eq(right.form.hooked.size(), 1)
	assert_false(only_left.is_hooked(), "An enemy only the left Decoy held is free the moment it leaves")

func test_each_maelstrom_has_its_own_cap() -> void:
	var left := _maelstrom(Vector3(-2, 0, 0))
	var right := _maelstrom(Vector3(2, 0, 0))
	_combat()
	for index in 30:
		_enemy(Vector3(float(index % 10) * .6 - 2.7, 0, -3.0 - float(index / 10) * .8))
	_run(left, .6)
	_run(right, .6)
	assert_eq(left.form.hooked.size(), 10)
	assert_eq(right.form.hooked.size(), 10)

# --- Real physics: pulling, circling, and what is left of the hero's targeting ---

## Steps one turret and every live enemy through their own physics for `seconds`.
func _simulate(turret: TurretActor, enemies: Array, seconds: float) -> void:
	for tick in roundi(seconds / STEP):
		world.crowd.rebuild(world.enemies)
		turret._physics_process(STEP)
		for enemy: EnemyActor in enemies:
			if is_instance_valid(enemy) and not enemy.dead:
				enemy._physics_process(STEP)

func test_chasers_in_reach_gather_round_the_decoy_and_stay_off_the_hero() -> void:
	world.player.position = Vector3(0, 0, 14)
	var turret := _decoy()
	_combat()
	var crowd: Array[EnemyActor] = []
	for index in 6:
		crowd.append(_enemy(Vector3(float(index) - 2.5, 0, 3.5), 100000.0))
	_simulate(turret, crowd, 6.0)
	for enemy in crowd:
		assert_lt(WorldGeometry.planar(enemy.position - turret.position).length(), 2.6, "Gathered round the Decoy")
		assert_lt(enemy.position.z, 4.0, "and not heading for the hero at +z")

func test_the_decoy_cannot_be_walked_through_and_enemies_do_not_break_it() -> void:
	var turret := _decoy()
	_combat()
	var enemy := _enemy(Vector3(0, 0, 3.0), 100000.0)
	_simulate(turret, [enemy], 3.0)
	assert_true(is_instance_valid(turret))
	assert_false(enemy.dead)

func test_hooked_enemies_circle_the_maelstrom_instead_of_reaching_the_hero() -> void:
	world.player.position = Vector3(0, 0, 6)
	var turret := _maelstrom()
	_combat()
	var crowd: Array[EnemyActor] = []
	for index in 8:
		var angle := float(index) * TAU / 8.0
		crowd.append(_enemy(Vector3(cos(angle), 0, sin(angle)) * 5.0, 100000.0))
	var start := crowd.map(func(enemy: EnemyActor) -> float: return atan2(enemy.position.z, enemy.position.x))
	_simulate(turret, crowd, 8.0)
	var swept := 0.0
	for index in crowd.size():
		var enemy := crowd[index]
		assert_true(enemy.is_hooked())
		var distance := WorldGeometry.planar(enemy.position - turret.position).length()
		assert_between(distance, .9, 3.4, "On the rings round the Decoy")
		swept += absf(wrapf(atan2(enemy.position.z, enemy.position.x) - float(start[index]), -PI, PI))
		assert_gt(enemy.position.distance_to(world.player.position), 2.0, "Never on the hero")
	assert_gt(swept / float(crowd.size()), .3, "They keep moving round the ring")

func test_with_no_decoy_in_the_run_enemies_still_chase_the_hero() -> void:
	world.player.position = Vector3(0, 0, 8)
	var turret := rig.turret("normal", [], Vector3(40, 0, 40))
	_combat()
	var enemy := _enemy(Vector3(0, 0, 0), 100000.0)
	assert_false(world.taunts.has_posts())
	_simulate(turret, [enemy], 2.0)
	assert_gt(enemy.position.z, 2.0, "Straight at the hero")

func test_a_resting_decoy_does_not_pull_between_waves() -> void:
	world.player.position = Vector3(0, 0, 14)
	var turret := _decoy()
	_combat()
	_step(turret)
	var enemy := _enemy(Vector3(0, 0, 3.0), 100000.0)
	assert_not_null(enemy.taunt_post())
	rig.shop()
	_step(turret)
	assert_null(enemy.taunt_post())

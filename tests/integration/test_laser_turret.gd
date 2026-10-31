extends GutTest

## Laser line: stocking, the registry entry, the base beam (lock, ramp, tick timing, retarget, reach), damage rules shared with the
## other instant-hit turrets (crits, Exposed, Marked, items, Resonance Link), Focus Beam, Halo Cutter's cross, Sunpiercer's flare,
## two lasers side by side, every clean-up path (wave end, pause, pickup, removal, evolution, run reset) and the tuning of the
## finals against the upgrade. The S11 rules it uses are in `test_continuous_beam.gd`.

const GATE := "test_laser_gate"
const STEP := 1.0 / 60.0
const HUGE := 1.0e9

var rig: TurretTestRig
var world: ArenaWorld
var _credited: float = 0.0

func before_each() -> void:
	rig = TurretTestRig.start(self)
	rig.disable_crits()
	world = rig.world
	GameStateService.current_wave = 1
	# The run's starting turret and the hero stay out of the way unless a test moves them.
	for starting in world.turrets:
		starting.position = Vector3(24, 0, 16)

func after_each() -> void:
	ShopCatalog.reset()
	ModifierService.clear_modifiers()
	TestHelpers.reset_flags()

func _laser(form_path: Array[String] = [], at: Vector3 = Vector3.ZERO) -> TurretActor:
	return rig.turret("laser", form_path, at)

func _focus(at: Vector3 = Vector3.ZERO) -> TurretActor:
	return _laser(["focus_beam"], at)

func _halo(at: Vector3 = Vector3.ZERO) -> TurretActor:
	return _laser(["focus_beam", "halo_cutter"], at)

func _sun(at: Vector3 = Vector3.ZERO) -> TurretActor:
	return _laser(["focus_beam", "sunpiercer"], at)

func _form(turret: TurretActor) -> LaserForm:
	return turret.form as LaserForm

func _step(turret: TurretActor, delta: float = STEP) -> void:
	world.crowd.rebuild(world.enemies)
	turret._physics_process(delta)

func _run(turret: TurretActor, seconds: float) -> void:
	for i in roundi(seconds / STEP):
		_step(turret)

## Lets go of the target and looks again on the next step, so the next tick is a fresh x1 landing tick.
func _relock(turret: TurretActor) -> void:
	_form(turret).beam.release()
	_form(turret).search_clock = 0.0

## True once a node is freed or waiting to be (the frame has not ended yet).
func _gone(node: Variant) -> bool:
	return not is_instance_valid(node) or (node as Node).is_queued_for_deletion()

func _view_damage(turret: TurretActor) -> float:
	return turret.resolve_attack_view().damage

func _dummy(at: Vector3) -> CombatActor:
	return rig.enemy(at, HUGE)

func _dealt(enemy: CombatActor) -> float:
	return HUGE - enemy.health

# --- Shop, registry and items ---

func test_laser_is_stocked_at_its_registry_price_and_purchasable() -> void:
	assert_has(ArenaShop.TURRETS, "laser")
	assert_has(ShopCatalog.available_ids("turret"), "laser")
	assert_eq(TurretRegistry.get_base_price("laser"), 19)
	var price := world.turret_price("laser")
	EconomyService.total_scrap = 500
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", "laser", price)])
	assert_true(world.shop.purchase(0))
	assert_eq(TurretStatsService.turret_counts.get("laser", 0), 1)
	assert_eq(EconomyService.total_scrap, 500 - price)
	assert_eq(ArenaShop.offer_name(ShopOffer.new("turret", "laser", 1)), "Laser")
	assert_ne(ArenaShop.offer_description(ShopOffer.new("turret", "laser", 1)), "")

func test_shop_rolls_the_laser_and_a_flag_can_gate_it() -> void:
	world.shop.rng = RandomNumberGenerator.new()
	world.shop.rng.seed = 5
	var seen := false
	for roll in 300:
		world.shop.generate()
		for offer: ShopOffer in EconomyService.current_shop_offers:
			if offer.kind == "turret" and offer.asset_id == "laser":
				seen = true
	assert_true(seen, "300 refreshes stock the Laser at least once")
	FeatureFlagService.register_flag(GATE, {"name": "Gate", "scope": FeatureFlagService.SCOPE_EXPERIMENT})
	ShopCatalog.entries["turret"]["laser"] = GATE
	assert_false(ShopCatalog.is_available("turret", "laser"))
	EconomyService.total_scrap = 500
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", "laser", 1)])
	assert_false(world.shop.purchase(0), "A gated turret cannot be bought")

func test_shop_view_data_dev_tools_and_art_know_the_laser() -> void:
	_laser()
	assert_gt(world.dev.add_turret("laser"), 0)
	var data := ShopViewData.build_data(world)
	var row: Dictionary = {}
	for entry: Dictionary in data.turrets:
		if entry.id == "laser":
			row = entry
	assert_false(row.is_empty())
	assert_eq(row.name, "Laser")
	assert_true(row.beam, "The shop knows its rate is ticks per second")
	assert_false(row.deploys)
	assert_false(row.utility, "It attacks")
	assert_almost_eq(float(row.damage), 3.0, .001)
	assert_almost_eq(float(row.fire_rate), 10.0, .001)
	assert_same(ShopArt.turret("laser"), load("res://assets/ui/turrets/laser.png"))
	for form in ["laser", "focus_beam", "halo_cutter", "sunpiercer"]:
		assert_true(ResourceLoader.exists("res://assets/ui/turrets/%s.png" % form), form)
	assert_not_null(UiIcons.turret("laser"))
	assert_true(UiIconData.PATHS.has("turret_laser"))

func test_registry_entry_matches_the_card_and_counts_as_an_instant_turret() -> void:
	var base := TurretRegistry.get_base_stats("laser")
	assert_eq(base.damage, 3.0, "3 damage")
	assert_eq(base.fire_rate, 10.0, "ten times a second")
	assert_eq(base.range, 260.0)
	assert_eq(TurretRegistry.get_fire_mode("laser"), TurretRegistry.FIRE_BEAM)
	assert_eq(TurretRegistry.get_attack_families("laser"), ["instant"] as Array[String], "Instant, so Resonance Link counts it")
	assert_eq(TurretRegistry.get_damage_type("laser"), GameEnums.DamageType.PLASMA)
	assert_false(TurretRegistry.is_no_attack("laser"))
	assert_eq(TurretRegistry.get_family("laser"), "")
	assert_eq(TurretRegistry.get_targeting("laser"), "closest")

func test_an_instant_item_strengthens_the_beam_and_a_projectile_item_does_not() -> void:
	var laser := _laser()
	var enemy := _dummy(Vector3(0, 0, -2))
	rig.combat()
	ModifierService.add_modifier({"stat": "damage", "operation": "increase", "value": .5, "filter": {"attack_family": ["projectile"]}})
	laser.invalidate_stats()
	_step(laser)
	assert_almost_eq(_dealt(enemy), 3.0, .001, "A projectile item changes nothing")
	ModifierService.clear_modifiers()
	ModifierService.add_modifier({"stat": "damage", "operation": "increase", "value": .5, "filter": {"attack_family": ["instant"]}})
	laser.invalidate_stats()
	enemy.health = HUGE
	_relock(laser)
	_step(laser)
	assert_almost_eq(_dealt(enemy), 4.5, .001, "An Instant item reaches the beam")

func test_an_instant_attack_speed_item_quickens_the_ticks() -> void:
	var laser := _laser()
	var enemy := _dummy(Vector3(0, 0, -2))
	rig.combat()
	ModifierService.add_modifier({"stat": "attack_speed", "operation": "increase", "value": 1.0, "filter": {"attack_family": ["instant"]}})
	laser.invalidate_stats()
	_run(laser, 1.0)
	assert_eq(_form(laser).beam.ticks_dealt, 21, "20 ticks a second, and the one that lands with the beam")

func test_resonance_link_counts_the_laser_as_an_instant_turret() -> void:
	var laser := _laser([], Vector3.ZERO)
	var enemy := _dummy(Vector3(0, 0, -2))
	rig.combat()
	ModifierService.add_modifier({"stat": "storm_link_damage", "operation": "add", "value": .35, "filter": {}})
	laser.invalidate_stats()
	_step(laser)
	assert_almost_eq(_dealt(enemy), 3.0, .001, "Alone it is not linked")
	var partner := rig.turret("sniper", [], Vector3(3, 0, 0))
	laser.invalidate_stats()
	enemy.health = HUGE
	_relock(laser)
	_step(laser)
	assert_almost_eq(_dealt(enemy), 3.0 * 1.35, .001, "An Instant turret within 4 m links it")
	partner.position = Vector3(8, 0, 0)
	laser.invalidate_stats()
	enemy.health = HUGE
	_relock(laser)
	_step(laser)
	assert_almost_eq(_dealt(enemy), 3.0, .001, "Out of range again")
	var second := _laser([], Vector3(2, 0, 0))
	laser.invalidate_stats()
	assert_true(laser._has_instant_neighbour(), "Two lasers link each other")
	assert_true(second._has_instant_neighbour())

func test_crit_exposed_and_marked_apply_to_each_tick_like_a_sniper_shot() -> void:
	var laser := _laser()
	var enemy := _dummy(Vector3(0, 0, -2))
	rig.combat()
	_step(laser)
	assert_almost_eq(_dealt(enemy), 3.0, .001)
	enemy.statuses.expose(5.0)
	enemy.health = HUGE
	_relock(laser)
	_step(laser)
	assert_almost_eq(_dealt(enemy), 3.0 * 1.3, .001, "Exposed: +30% from Instant hits")
	enemy.statuses.mark(5.0)
	enemy.health = HUGE
	_relock(laser)
	_step(laser)
	assert_almost_eq(_dealt(enemy), 3.0 * 1.3 * 1.25, .001, "Marked multiplies with it")
	TestHelpers.force_crits()
	enemy.health = HUGE
	_relock(laser)
	_step(laser)
	assert_almost_eq(_dealt(enemy), 3.0 * 1.3 * 1.25 * TurretStatsService.get_turret_crit_multiplier(), .01, "Every tick rolls its own crit")

func test_a_tick_carries_the_turrets_id_families_and_damage_type_for_credit() -> void:
	var laser := _laser()
	var enemy := _dummy(Vector3(0, 0, -2))
	var seen: Array[CombatHit3D] = []
	world.combat.hit_applied.connect(func(_target: Node3D, hit: CombatHit3D, _amount: float) -> void: seen.append(hit))
	rig.combat()
	_step(laser)
	assert_eq(seen.size(), 1)
	assert_eq(seen[0].source_id, laser.turret_id)
	assert_has(seen[0].attack_families, "instant")
	assert_eq(seen[0].damage_type, GameEnums.DamageType.PLASMA)
	assert_true(seen[0].impulse.is_zero_approx(), "A beam does not shove")

# --- The base beam ---

func test_the_beam_lands_a_tick_at_once_and_the_ramp_climbs_to_three_times() -> void:
	var laser := _laser()
	var enemy := _dummy(Vector3(0, 0, -2))
	rig.combat()
	_step(laser)
	assert_almost_eq(_dealt(enemy), 3.0, .001, "The first tick lands with the beam, at x1")
	assert_true(_form(laser).is_beaming())
	assert_same(laser.target, enemy)
	var before := _dealt(enemy)
	_run(laser, 2.9)
	assert_between(_form(laser).ramp_now(), 2.9, 3.0)
	_run(laser, 0.5)
	assert_almost_eq(_form(laser).ramp_now(), 3.0, .0001, "Full ramp is x3")
	var full := _dealt(enemy)
	_run(laser, 1.0)
	assert_almost_eq(_dealt(enemy) - full, 90.0, 4.5, "30 damage a second becomes 90 at full ramp")
	assert_gt(full - before, 0.0)

func test_the_ramp_integral_over_the_first_three_seconds_matches_the_card() -> void:
	var laser := _laser()
	var enemy := _dummy(Vector3(0, 0, -2))
	rig.combat()
	_run(laser, 3.0)
	# Ten ticks a second for three seconds, the multiplier rising from 1 to 3: about 3 x 10 x 3 x 2 = 180 (plus the landing tick).
	assert_between(_dealt(enemy), 175.0, 195.0)

func test_ticks_per_second_do_not_depend_on_the_frame_rate() -> void:
	var results: Array[float] = []
	for delta: float in [1.0 / 30.0, 1.0 / 60.0, 1.0 / 120.0]:
		var local_rig := TurretTestRig.start(self)
		local_rig.disable_crits()
		for starting in local_rig.world.turrets:
			starting.position = Vector3(24, 0, 16)
		var turret := local_rig.turret("laser")
		var enemy := local_rig.enemy(Vector3(0, 0, -2), HUGE)
		local_rig.combat()
		for i in roundi(2.0 / delta):
			local_rig.step(turret, delta)
		results.append(HUGE - enemy.health)
	assert_almost_eq(results[0], results[1], results[1] * .08)
	assert_almost_eq(results[2], results[1], results[1] * .08)

func test_a_step_never_deals_more_than_the_tick_cap_however_fast_the_rate() -> void:
	var laser := _laser()
	var enemy := _dummy(Vector3(0, 0, -2))
	rig.combat()
	ModifierService.add_modifier({"stat": "attack_speed", "operation": "increase", "value": 500.0, "filter": {"attack_family": ["instant"]}})
	laser.invalidate_stats()
	_step(laser)
	assert_lte(_dealt(enemy), 3.0 * ContinuousBeam.MAX_TICKS_PER_STEP + .001)
	var before := _dealt(enemy)
	_step(laser, 5.0)
	assert_lte(_dealt(enemy) - before, 3.0 * ContinuousBeam.MAX_TICKS_PER_STEP * 3.0 + .001, "A stalled frame pays at most the cap at the current ramp")

func test_it_locks_the_nearest_enemy_and_keeps_it_when_a_closer_one_arrives() -> void:
	var laser := _laser()
	var far := _dummy(Vector3(0, 0, -2.4))
	var near := _dummy(Vector3(1.5, 0, 0))
	rig.combat()
	_step(laser)
	assert_same(laser.target, near)
	var closer := _dummy(Vector3(-1.0, 0, 0))
	_run(laser, 1.0)
	assert_same(laser.target, near, "Focus: a closer enemy does not steal the beam")
	assert_eq(_dealt(closer), 0.0)
	assert_eq(_dealt(far), 0.0)
	assert_gt(_dealt(near), 0.0)

func test_retargeting_resets_the_ramp_and_picks_up_the_next_enemy_at_once() -> void:
	var laser := _laser()
	var first := rig.enemy(Vector3(0, 0, -2), 4000.0)
	var second := _dummy(Vector3(2, 0, 0))
	rig.combat()
	_run(laser, 2.0)
	assert_gt(_form(laser).ramp_now(), 2.0)
	first.health = 1.0
	_run(laser, 0.2)
	assert_true(first.dead)
	assert_same(laser.target, second, "The next enemy is locked as the first one falls")
	assert_lt(_form(laser).ramp_now(), 1.2, "and the ramp starts over")
	assert_eq(_form(laser).beam.locks, 2)

func test_an_enemy_leaving_reach_drops_the_beam_and_it_relocks_on_return() -> void:
	var laser := _laser()
	var enemy := _dummy(Vector3(0, 0, -2))
	rig.combat()
	_run(laser, 1.0)
	enemy.position = Vector3(0, 0, -6)
	_run(laser, 0.1)
	assert_null(laser.target)
	assert_false(_form(laser).is_beaming())
	var gone := _dealt(enemy)
	_run(laser, 1.0)
	assert_eq(_dealt(enemy), gone, "Nothing out of reach is hit")
	enemy.position = Vector3(0, 0, -2)
	_run(laser, 0.5)
	assert_same(laser.target, enemy)
	assert_gt(_dealt(enemy), gone)
	assert_lt(_form(laser).ramp_now(), 2.0, "Back on it, the ramp began again")

func test_reach_is_two_point_six_metres_for_the_base_laser() -> void:
	var laser := _laser()
	var in_reach := _dummy(Vector3(0, 0, -2.8))
	var out_of_reach := _dummy(Vector3(3.6, 0, 0))
	rig.combat()
	_run(laser, 1.0)
	assert_gt(_dealt(in_reach), 0.0, "A body whose edge is inside 2.6 m is struck")
	assert_eq(_dealt(out_of_reach), 0.0)

func test_the_head_turns_to_face_the_target() -> void:
	var laser := _laser()
	_dummy(Vector3(2, 0, 0))
	rig.combat()
	_step(laser)
	assert_almost_eq(laser.aim.rotation.y, atan2(-2.0, 0.0), .05)

func test_the_beam_never_hits_the_hero_or_another_turret() -> void:
	var laser := _laser()
	world.player.position = Vector3(0, 0, -1.0)
	var bystander := rig.turret("normal", [], Vector3(0.3, 0, -1.4))
	var enemy := _dummy(Vector3(0, 0, -2.2))
	var hull := world.player.health
	rig.combat()
	_run(laser, 3.0)
	assert_gt(_dealt(enemy), 0.0)
	assert_eq(world.player.health, hull, "The hero standing in the beam takes nothing")
	assert_true(is_instance_valid(bystander))

func test_idle_laser_with_nothing_in_reach_does_no_work_and_has_no_beam_up() -> void:
	var laser := _laser()
	_dummy(Vector3(9, 0, 9))
	rig.combat()
	_run(laser, 2.0)
	assert_null(laser.target)
	assert_eq(_form(laser).beam.ticks_dealt, 0)
	assert_eq(_form(laser).lines.visible_count(), 0)

func test_the_beam_is_drawn_while_it_holds_and_hidden_when_it_lets_go() -> void:
	var laser := _laser()
	var enemy := rig.enemy(Vector3(0, 0, -2), 20.0)
	rig.combat()
	_step(laser)
	var lines := _form(laser).lines
	assert_eq(lines.visible_count(), 1)
	assert_almost_eq(lines.slots[0].scale.z, laser.muzzle.global_position.distance_to(Vector3(0, laser.muzzle.global_position.y, -2)), .05, "It reaches the target")
	_run(laser, 1.0)
	assert_true(enemy.dead)
	_run(laser, 0.1)
	assert_eq(lines.visible_count(), 0, "No target, no beam")

func test_the_drawn_beam_widens_with_the_ramp() -> void:
	var laser := _laser()
	_dummy(Vector3(0, 0, -2))
	rig.combat()
	_step(laser)
	var thin := _form(laser).lines.slots[0].scale.x
	_run(laser, 3.5)
	assert_gt(_form(laser).lines.slots[0].scale.x, thin * 2.0)

func test_beam_visuals_do_not_leak_nodes_over_a_long_fight() -> void:
	var laser := _laser()
	var enemies: Array[CombatActor] = []
	for i in 6:
		enemies.append(_dummy(Vector3(1.0 + float(i) * .3, 0, -1.0)))
	rig.combat()
	# Let the arena's own effect pools (hit sparks, numbers) fill to their caps first: they are not the beam's.
	_run(laser, 12.0)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var children := laser.get_child_count()
	# Drag the target out of reach every second so the beam retargets all through the fight.
	for round in 15:
		if laser.target:
			laser.target.position = Vector3(9, 0, 9)
		_run(laser, 1.0)
		for index in enemies.size():
			enemies[index].position = Vector3(1.0 + float(index) * .3, 0, -1.0)
	assert_gt(_form(laser).beam.locks, 6, "It retargeted many times")
	assert_eq(laser.get_child_count(), children, "The turret gained no children")
	assert_lte(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes + 2.0, "and the beam spawned no nodes of its own")

# --- Focus Beam ---

func test_focus_beam_hits_harder_ramps_faster_and_reaches_farther() -> void:
	var laser := _focus()
	var enemy := _dummy(Vector3(0, 0, -2.8))
	rig.combat()
	var damage := _view_damage(laser)
	assert_almost_eq(float(TurretEvolution.base_stats("laser", "focus_beam").damage), 4.0, .001, "4 damage a tick before level bonuses")
	assert_eq(TurretStats.new(TurretEvolution.base_stats("laser", "focus_beam")).range_metres, 3.0)
	_step(laser)
	assert_almost_eq(_dealt(enemy), damage, .001, "The landing tick is x1")
	_run(laser, 2.1)
	assert_almost_eq(_form(laser).ramp_now(), 3.0, .0001, "Full ramp after 2 seconds")
	var full := _dealt(enemy)
	_run(laser, 1.0)
	var view := laser.resolve_attack_view()
	assert_almost_eq(_dealt(enemy) - full, view.damage * 3.0 * view.fire_rate, view.damage * 3.0 * 1.5, "x3 at the level's tick rate (Entrench grows it a little)")

func test_focus_beam_has_its_hardware_and_a_moved_muzzle() -> void:
	var base := _laser()
	var focus := _focus(Vector3(5, 0, 0))
	assert_not_null(focus.model.find_child("LensSleeve", true, false))
	assert_null(base.model.find_child("LensSleeve", true, false))
	assert_lt(focus.muzzle.position.z, base.muzzle.position.z - .25, "The beam leaves from the lens")

# --- Halo Cutter ---

func test_halo_cutter_cuts_everything_on_its_four_arms_and_nothing_between_them() -> void:
	var laser := _halo()
	var on_arms: Array[CombatActor] = []
	for spot in [Vector3(0, 0, -2), Vector3(-2, 0, 0), Vector3(0, 0, 2), Vector3(2, 0, 0)]:
		on_arms.append(_dummy(spot))
	var between := _dummy(Vector3(1.5, 0, 1.5))
	rig.combat()
	_step(laser)
	for enemy in on_arms:
		assert_almost_eq(_dealt(enemy), _view_damage(laser), .001, "Each arm cuts its enemy once, with no ramp")
	assert_eq(_dealt(between), 0.0)
	assert_eq(_form(laser).lines.visible_count(), 4, "Four arms drawn")

func test_halo_cutter_turns_and_sweeps_the_gaps() -> void:
	var laser := _halo()
	var between := _dummy(Vector3(1.5, 0, 1.5))
	rig.combat()
	_run(laser, 3.0)
	assert_gt(_dealt(between), 0.0, "The cross comes round to it")
	assert_gt(_form(laser).spin, 0.0)
	assert_almost_eq(laser.aim.rotation.y, _form(laser).spin, .0001, "The head turns with the cross")
	assert_eq(_form(laser).ramp_now(), 1.0, "It never ramps")

func test_halo_cutter_hits_an_enemy_once_per_tick_even_with_two_arms_on_it() -> void:
	var laser := _halo()
	var enemy := _dummy(Vector3(0.3, 0, -0.3))
	rig.combat()
	_step(laser)
	assert_almost_eq(_dealt(enemy), _view_damage(laser), .001)

func test_halo_cutter_strikes_at_most_the_cap_per_tick_nearest_first() -> void:
	var laser := _halo()
	var list: Array[CombatActor] = []
	for i in 40:
		list.append(_dummy(Vector3(-0.05 + float(i % 2) * .1, 0, -0.9 - float(i) * .04)))
	rig.combat()
	_step(laser)
	var struck := 0
	for enemy in list:
		if _dealt(enemy) > 0.0:
			struck += 1
	assert_eq(struck, LaserForm.MAX_VICTIMS)
	assert_gt(_dealt(list[0]), 0.0, "The nearest are the ones struck")
	assert_eq(_dealt(list[39]), 0.0)

func test_halo_cutter_goes_quiet_with_nothing_in_reach_and_restarts_on_a_new_enemy() -> void:
	var laser := _halo()
	var enemy := rig.enemy(Vector3(0, 0, -2), 20.0)
	rig.combat()
	_run(laser, 1.0)
	assert_true(enemy.dead)
	_run(laser, 0.2)
	assert_false(_form(laser).is_beaming())
	assert_eq(_form(laser).lines.visible_count(), 0)
	var spin := _form(laser).spin
	_run(laser, 1.0)
	assert_eq(_form(laser).spin, spin, "It does not turn while idle")
	_dummy(Vector3(0, 0, -2))
	_run(laser, 0.1)
	assert_true(_form(laser).is_beaming())

func test_halo_cutter_never_hits_the_hero_or_a_turret_on_an_arm() -> void:
	var laser := _halo()
	world.player.position = Vector3(0, 0, -1.2)
	rig.turret("normal", [], Vector3(1.4, 0, 0))
	var enemy := _dummy(Vector3(-2, 0, 0))
	var hull := world.player.health
	rig.combat()
	_run(laser, 3.0)
	assert_gt(_dealt(enemy), 0.0)
	assert_eq(world.player.health, hull)

func test_halo_cutter_has_a_hoop_and_four_lenses() -> void:
	var laser := _halo()
	assert_not_null(laser.model.find_child("HaloHoop", true, false))
	assert_not_null(laser.model.find_child("HaloLens4", true, false))
	assert_eq(TurretStats.new(TurretEvolution.base_stats("laser", "halo_cutter")).range_metres, 3.0)

# --- Sunpiercer ---

func test_sunpiercer_ramps_to_six_times_over_four_seconds() -> void:
	var laser := _sun()
	var enemy := _dummy(Vector3(0, 0, -2))
	rig.combat()
	_run(laser, 2.0)
	assert_between(_form(laser).ramp_now(), 3.4, 3.6, "Halfway up: x3.5")
	_run(laser, 2.2)
	assert_almost_eq(_form(laser).ramp_now(), 6.0, .0001)

func test_sunpiercer_flares_the_whole_line_at_full_ramp_and_again_every_two_seconds() -> void:
	var laser := _sun()
	var target := _dummy(Vector3(0, 0, -1.5))
	var behind := _dummy(Vector3(0.05, 0, -3.0))
	var beside := _dummy(Vector3(1.6, 0, -1.6))
	rig.combat()
	_step(laser)
	assert_same(laser.target, target)
	# Arrives after the beam is locked, so it stands between the turret and the target.
	var in_front := _dummy(Vector3(-0.05, 0, -0.9))
	_run(laser, 3.9)
	assert_eq(_form(laser).flares, 0, "Not before full ramp")
	assert_eq(_dealt(behind), 0.0)
	_run(laser, 0.3)
	assert_eq(_form(laser).flares, 1, "The flare goes off at full ramp")
	var flare_damage := _view_damage(laser) * 6.0 * 6.0
	assert_almost_eq(_dealt(behind), flare_damage, .01, "Every enemy on the line takes 6 full-ramp ticks")
	assert_almost_eq(_dealt(in_front), flare_damage, .01, "in front of the target as well")
	assert_gt(_dealt(target), flare_damage, "The target takes the flare on top of its ticks")
	assert_eq(_dealt(beside), 0.0, "Off the line, nothing")
	assert_eq(_form(laser).lines.visible_count(), 2, "Beam and flare drawn")
	_run(laser, 0.3)
	assert_eq(_form(laser).lines.visible_count(), 1, "The flare is a brief flash")
	_run(laser, 2.0)
	assert_eq(_form(laser).flares, 2, "and again two seconds later")
	assert_almost_eq(_dealt(behind), flare_damage * 2.0, .01)

func test_sunpiercer_flare_ramp_starts_over_on_a_new_target() -> void:
	var laser := _sun()
	var first := rig.enemy(Vector3(0, 0, -2), HUGE)
	rig.combat()
	_run(laser, 4.3)
	assert_eq(_form(laser).flares, 1)
	first.health = 1.0
	var second := _dummy(Vector3(2, 0, 0))
	_run(laser, 0.3)
	assert_same(laser.target, second)
	_run(laser, 3.0)
	assert_eq(_form(laser).flares, 1, "No flare until the new target has been held for 4 seconds")

func test_sunpiercer_flare_does_not_hit_the_hero_or_turrets() -> void:
	var laser := _sun()
	world.player.position = Vector3(0, 0, -0.9)
	rig.turret("normal", [], Vector3(0.1, 0, -2.4))
	_dummy(Vector3(0, 0, -1.5))
	var hull := world.player.health
	rig.combat()
	_run(laser, 4.5)
	assert_eq(_form(laser).flares, 1)
	assert_eq(world.player.health, hull)

func test_sunpiercer_has_a_longer_reach_a_spire_and_rings() -> void:
	var laser := _sun()
	assert_eq(TurretStats.new(TurretEvolution.base_stats("laser", "sunpiercer")).range_metres, 3.4)
	assert_not_null(laser.model.find_child("SunSpire", true, false))
	assert_not_null(laser.model.find_child("SunRing2", true, false))

# --- Two lasers ---

func test_two_lasers_keep_their_own_targets_ramps_and_lines() -> void:
	var first := _laser([], Vector3(0, 0, 0))
	var second := _laser([], Vector3(12, 0, 0))
	var a := _dummy(Vector3(0, 0, -2))
	var b := rig.enemy(Vector3(12, 0, -2), 400.0)
	rig.combat()
	for i in roundi(2.0 / STEP):
		world.crowd.rebuild(world.enemies)
		first._physics_process(STEP)
		second._physics_process(STEP)
	assert_same(first.target, a)
	assert_same(second.target, b)
	var ramp := _form(first).ramp_now()
	assert_gt(ramp, 1.5)
	b.health = 1.0
	for i in 20:
		world.crowd.rebuild(world.enemies)
		first._physics_process(STEP)
		second._physics_process(STEP)
	assert_true(b.dead)
	assert_null(second.target)
	assert_gt(_form(first).ramp_now(), ramp, "The other laser's ramp carried on")
	assert_ne(_form(first).lines, _form(second).lines)

func test_two_lasers_on_one_enemy_each_deal_their_own_ticks() -> void:
	var first := _laser([], Vector3(0, 0, 0))
	var second := _laser([], Vector3(0, 0, -4))
	var enemy := _dummy(Vector3(0, 0, -2))
	rig.combat()
	for i in roundi(1.0 / STEP):
		world.crowd.rebuild(world.enemies)
		first._physics_process(STEP)
		second._physics_process(STEP)
	assert_gt(_form(first).strikes, 0)
	assert_gt(_form(second).strikes, 0)
	assert_gte(_dealt(enemy), 3.0 * float(_form(first).strikes + _form(second).strikes) - .01, "Both lasers' ticks landed")

func test_kill_credit_goes_to_the_laser_that_dealt_the_blow() -> void:
	var first := _laser([], Vector3(0, 0, 0))
	var second := _laser([], Vector3(9, 0, 0))
	var credited: Dictionary = {}
	world.combat.hit_applied.connect(func(_target: Node3D, hit: CombatHit3D, amount: float) -> void:
		credited[hit.source_id] = float(credited.get(hit.source_id, 0.0)) + amount)
	_dummy(Vector3(0, 0, -2))
	rig.combat()
	_run(first, 1.0)
	assert_gt(float(credited.get(first.turret_id, 0.0)), 0.0)
	assert_false(credited.has(second.turret_id))

# --- Clean-up ---

func test_wave_end_puts_the_beam_out_the_next_physics_step() -> void:
	var laser := _laser()
	var enemy := _dummy(Vector3(0, 0, -2))
	rig.combat()
	_run(laser, 2.0)
	assert_eq(_form(laser).lines.visible_count(), 1)
	rig.shop()
	laser._physics_process(STEP)
	assert_eq(_form(laser).lines.visible_count(), 0)
	assert_false(_form(laser).is_beaming())
	assert_null(laser.target)
	var health := enemy.health
	_run(laser, 2.0)
	assert_eq(enemy.health, health, "Nothing is dealt between waves")
	rig.combat()
	_run(laser, 0.5)
	assert_lt(_form(laser).ramp_now(), 1.5, "A new wave starts the ramp afresh")

func test_pausing_puts_the_beam_out_and_resuming_starts_afresh() -> void:
	var laser := _laser()
	var enemy := _dummy(Vector3(0, 0, -2))
	rig.combat()
	_run(laser, 2.0)
	world.paused = true
	_run(laser, 2.0)
	assert_eq(_form(laser).lines.visible_count(), 0)
	var health := enemy.health
	_run(laser, 3.0)
	assert_eq(enemy.health, health)
	world.paused = false
	_run(laser, 0.2)
	assert_true(_form(laser).is_beaming())
	assert_lt(_form(laser).ramp_now(), 1.3)

func test_a_carried_laser_keeps_beaming_from_the_hero_and_never_hurts_the_hero() -> void:
	var laser := _laser()
	var enemy := _dummy(Vector3(10, 0, 5))
	rig.combat()
	laser.carried = true
	world.player.position = Vector3(10, 0, 7)
	var hull := world.player.health
	_run(laser, 2.0)
	assert_eq(world.player.health, hull)
	assert_gt(_dealt(enemy), 0.0, "Carried, it beams what is near the hero")
	assert_true(_form(laser).is_beaming())
	laser.carried = false

func test_a_removed_laser_frees_its_lines_and_stops_dealing_damage() -> void:
	var laser := _laser()
	var other := _laser([], Vector3(12, 0, 0))
	_dummy(Vector3(0, 0, -2))
	var other_enemy := _dummy(Vector3(12, 0, -2))
	rig.combat()
	_run(laser, 1.0)
	_step(other)
	var lines := _form(laser).lines
	assert_true(is_instance_valid(lines))
	world.turrets.erase(laser)
	laser.get_parent().remove_child(laser)
	laser.free()
	assert_true(_gone(lines), "Its lines went with it")
	assert_true(_form(other).lines.visible_count() > 0, "The other laser's did not")
	_run(other, 0.5)
	assert_gt(_dealt(other_enemy), 0.0)

func test_evolving_frees_the_old_forms_lines_and_builds_new_ones() -> void:
	var laser := _laser()
	_dummy(Vector3(0, 0, -2))
	rig.combat()
	_run(laser, 1.0)
	var old_lines := _form(laser).lines
	rig.level_to(laser, 5)
	rig.shop()
	assert_true(laser.evolve("focus_beam"))
	assert_true(_gone(old_lines), "The old lines are on their way out")
	rig.combat()
	_run(laser, 0.5)
	assert_ne(_form(laser).lines, old_lines)
	assert_eq(_form(laser).lines.visible_count(), 1)
	rig.level_to(laser, 10)
	rig.shop()
	assert_true(laser.evolve("halo_cutter"))
	rig.combat()
	_run(laser, 0.5)
	assert_eq(_form(laser).lines.visible_count(), 4, "The cross has four arms")
	var count := 0
	for child in laser.get_children():
		if child is BeamLines and not child.is_queued_for_deletion():
			count += 1
	assert_eq(count, 1, "Only the current form's lines remain")

func test_a_run_reset_leaves_no_lines_or_laser() -> void:
	var laser := _laser()
	_dummy(Vector3(0, 0, -2))
	rig.combat()
	_run(laser, 1.0)
	var lines := _form(laser).lines
	world._clear_actors()
	assert_true(_gone(lines), "The lines went with the turret")
	assert_true(_gone(laser))

func test_finishing_the_wave_and_defeat_stop_the_beam() -> void:
	var laser := _laser()
	_dummy(Vector3(0, 0, -2))
	rig.combat()
	_run(laser, 1.0)
	world.clear_field(false)
	laser._physics_process(STEP)
	assert_false(_form(laser).is_beaming())
	world._end_run_in_defeat("test")
	laser._physics_process(STEP)
	assert_eq(_form(laser).lines.visible_count(), 0)

# --- Tuning (simulated game time, not the bench) ---

## Damage per second credited to a level 10 laser (Focus Beam, or the given final) over `seconds` of game time against walkers that
## never die: they cross its ground in straight lines at 1.3 m/s, so the beam loses a target only when one walks out of reach.
## `kind`: "boss" (one stationary enemy), "lane" (one walker per 1.5 s), "packs" (six walkers abreast per 3 s), "ring" (twelve
## stationary enemies round it). The walkers' bearings come from a seeded generator, so the figures repeat.
func _simulated_dps(final: String, kind: String, seconds: float, seed_value: int) -> float:
	_credited = 0.0
	if not world.combat.hit_applied.is_connected(_credit):
		world.combat.hit_applied.connect(_credit)
	for old in world.enemies.duplicate():
		old.free()
	world.enemies.clear()
	rig.shop()
	var path: Array[String] = ["focus_beam"]
	if not final.is_empty():
		path.append(final)
	var turret := rig.turret("laser", path)
	rig.level_to(turret, 10)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var walkers: Array = []
	rig.combat()
	var next_spawn := 0.0
	if kind == "boss":
		walkers.append([rig.enemy(Vector3(2, 0, 0), HUGE), Vector3.ZERO])
	elif kind == "ring":
		for k in 12:
			var angle := float(k) * TAU / 12.0 + .2
			walkers.append([rig.enemy(Vector3(cos(angle), 0, sin(angle)) * (1.3 + float(k % 3) * .5), HUGE), Vector3.ZERO])
	for step in roundi(seconds / STEP):
		if float(step) * STEP >= next_spawn and kind in ["lane", "packs"]:
			var bearing := rng.randf() * TAU
			var direction := Vector3(cos(bearing), 0, sin(bearing))
			var side := Vector3(-direction.z, 0, direction.x)
			var offset := (rng.randf() - .5) * 3.0
			for k in (1 if kind == "lane" else 6):
				var at := -direction * 7.0 + side * offset
				if kind == "packs":
					at += side * ((rng.randf() - .5) * 1.8) - direction * (rng.randf() * 1.2)
				walkers.append([rig.enemy(at, HUGE), direction * 1.3])
			next_spawn += 1.5 if kind == "lane" else 3.0
		for entry: Array in walkers:
			(entry[0] as CombatActor).position += (entry[1] as Vector3) * STEP
		world.crowd.rebuild(world.enemies)
		turret._physics_process(STEP)
		if step % 120 == 0:
			for entry: Array in walkers.duplicate():
				if (entry[0] as CombatActor).position.length() > 9.0:
					walkers.erase(entry)
					world.enemies.erase(entry[0])
					(entry[0] as CombatActor).free()
	return _credited / seconds

func _credit(_target: Node3D, hit: CombatHit3D, amount: float) -> void:
	if hit.source_id > 0:
		_credited += amount

func _ratio(final: String, kind: String) -> float:
	var upgrade := 0.0
	var form := 0.0
	for seed_value in [1, 2]:
		upgrade += _simulated_dps("", kind, 40.0, seed_value)
		form += _simulated_dps(final, kind, 40.0, seed_value)
	return form / upgrade

func test_halo_cutter_is_tuned_to_about_one_and_a_half_times_focus_beam_in_a_crowd() -> void:
	var packs := _ratio("halo_cutter", "packs")
	var ring := _ratio("halo_cutter", "ring")
	var boss := _ratio("halo_cutter", "boss")
	gut.p("Halo Cutter against Focus Beam: packs %.2fx, ring %.2fx, lone boss %.2fx" % [packs, ring, boss])
	assert_between(packs, 1.8, 2.6, "Packs")
	assert_between(ring, 1.5, 2.1, "A ring of stationary enemies")
	assert_lt(boss, .3, "A cross is a poor single-target weapon, and the card says so")

func test_sunpiercer_is_tuned_to_about_one_and_a_half_times_focus_beam_on_a_held_target() -> void:
	var boss := _ratio("sunpiercer", "boss")
	var lane := _ratio("sunpiercer", "lane")
	gut.p("Sunpiercer against Focus Beam: boss %.2fx, lane %.2fx (mean %.2fx)" % [boss, lane, (boss + lane) * .5])
	assert_between(boss, 1.4, 2.0, "A target held for the whole 40 seconds")
	assert_between(lane, .95, 1.4, "A walker held for the few seconds it is in reach")
	assert_between((boss + lane) * .5, 1.25, 1.7, "The two single-target cases together: about 1.5x")

# --- Existing behaviour is untouched ---

func test_other_turrets_make_no_beam_and_a_sniper_still_shoots() -> void:
	var gun := rig.turret("normal")
	assert_false(gun.form is LaserForm)
	for child in gun.get_children():
		assert_false(child is BeamLines)
	var sniper := rig.turret("sniper", [], Vector3(10, 0, 0))
	var enemy := rig.enemy(Vector3(10, 0, -4), 200.0)
	rig.combat()
	_step(sniper)
	assert_lt(enemy.health, 200.0, "The Sniper's hit-scan is unchanged")

func test_shop_and_inspector_report_a_ramp_averaged_dps() -> void:
	var laser := _laser()
	assert_almost_eq(TurretForm.dps_of(laser), 3.0 * 10.0 * 2.0, .001, "Base: 30 at x1, 90 at x3, 60 on average while ramping")
	var focus := _focus(Vector3(5, 0, 0))
	var view := focus.resolve_attack_view()
	assert_almost_eq(TurretForm.dps_of(focus), view.damage * view.fire_rate * 2.0, .001, "Focus Beam: x1 to x3, averaging x2")
	var sun := _sun(Vector3(10, 0, 0))
	view = sun.resolve_attack_view()
	assert_almost_eq(TurretForm.dps_of(sun), view.damage * view.fire_rate * 3.5, .001, "Sunpiercer: x1 to x6, averaging x3.5")
	var halo := _halo(Vector3(15, 0, 0))
	view = halo.resolve_attack_view()
	assert_almost_eq(TurretForm.dps_of(halo), view.damage * view.fire_rate, .001, "A cross has no ramp: one arm's worth on one enemy")

func test_pattern_text_describes_each_beam() -> void:
	assert_string_contains(TurretEvolution.laser_pattern_text(""), "x1 to x3 over 3 s")
	assert_string_contains(TurretEvolution.laser_pattern_text("focus_beam"), "over 2 s")
	assert_string_contains(TurretEvolution.laser_pattern_text("halo_cutter"), "4 beams")
	assert_string_contains(TurretEvolution.laser_pattern_text("sunpiercer"), "x6 over 4 s")
	assert_string_contains(TurretEvolution.laser_pattern_text("sunpiercer"), "flare")

func test_rows_chain_the_path_and_use_the_real_chassis() -> void:
	assert_eq(TurretEvolution.options("laser", 0), ["focus_beam"])
	assert_eq(TurretEvolution.options("laser", 1), ["halo_cutter", "sunpiercer"])
	for form in ["focus_beam", "halo_cutter", "sunpiercer"]:
		assert_true(TurretEvolution.is_implemented(form))
		assert_eq(TurretEvolution.model_key(form), "laser", "All forms use the real chassis")
	assert_true(TurretEvolution.behaviour_script("laser", "").new() is LaserForm)

## The real chassis: Aim carries the head and Muzzle is the nozzle tip in front of the bezel, where the beam starts. Each hardware
## piece hangs off Aim so it turns with the head, and the Halo hoop stands clear of the chassis (its widest part is 0.64 m out).
func test_all_four_stages_use_the_real_chassis_and_the_beam_leaves_the_nozzle() -> void:
	var paths: Array[Array] = [[], ["focus_beam"], ["focus_beam", "halo_cutter"], ["focus_beam", "sunpiercer"]]
	for path in paths:
		var typed: Array[String] = []
		typed.assign(path)
		var turret := _laser(typed)
		assert_not_null(turret.model.find_child("Aim_Crystal", true, false), "The cp_laser gem lens is there")
		assert_not_null(turret.aim)
		assert_not_null(turret.muzzle)
		assert_true(turret.muzzle.position.z <= -.79 + .001, "The muzzle is at or past the nozzle tip (%s)" % turret.progression.evolution_form)
		assert_almost_eq(turret.muzzle.position.y, .46, .001, "On the bore")
		turret.queue_free()

func test_the_hardware_rides_the_head_and_the_hoop_clears_the_chassis() -> void:
	var halo := _halo()
	var hoop := halo.aim.find_child("HaloHoop", true, false) as MeshInstance3D
	assert_not_null(hoop, "The hoop hangs off Aim")
	assert_gt((hoop.mesh as TorusMesh).inner_radius, .64 + .05, "Clear of the side knobs")
	assert_eq(LaserForm.ARM_START, LaserEvolutionVisual.ARM_RADIUS, "Arms are drawn from the hoop")
	var sun := _sun()
	var barrel := sun.aim.find_child("SunBarrel", true, false) as Node3D
	assert_not_null(barrel)
	assert_lt(sun.muzzle.position.z, barrel.position.z, "The muzzle sits at the barrel's tip")
	var spire := sun.aim.find_child("SunSpire", true, false) as MeshInstance3D
	assert_gte(spire.position.y - .275, .46 + .44 - .01, "The spire stands on the barrel's top, not inside it")

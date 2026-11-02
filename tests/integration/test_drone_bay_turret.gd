extends GutTest

## Drone Bay line: stocking, the registry entry, the base bay's sorties (launch, hover, shoot, return, dock), damage rules shared with
## the other turrets (crits, Marked, items, kill credit), Escort Drones' orbit round the hero, Guardian Wing's shoot-down of hostile
## bolts and shells aimed at the hero, Reaper Swarm's dive, bonus and kill-launched extras, drone wear and replacement, the per-bay and
## arena-wide caps, two bays side by side, every clean-up path (wave end, pause, pickup, removal, evolution, run reset, defeat) and the
## tuning of the finals against the upgrade. The S10 rules it uses are in `test_drones.gd`.

const GATE := "test_drone_bay_gate"
const STEP := 1.0 / 60.0
const HUGE := 1.0e9

var rig: TurretTestRig
var world: ArenaWorld
var swarm: Drones

func before_each() -> void:
	rig = TurretTestRig.start(self)
	rig.disable_crits()
	world = rig.world
	swarm = world.drones
	GameStateService.current_wave = 1
	# The run's starting turret stays out of the way unless a test moves it; the hero stands at the origin.
	for starting in world.turrets:
		starting.position = Vector3(24, 0, 16)
	world.player.position = Vector3.ZERO

func after_each() -> void:
	ShopCatalog.reset()
	ModifierService.clear_modifiers()
	TestHelpers.reset_flags()

func _bay(form_path: Array[String] = [], at: Vector3 = Vector3(3, 0, 0)) -> TurretActor:
	return rig.turret("drone_bay", form_path, at)

func _escort(at: Vector3 = Vector3(3, 0, 0)) -> TurretActor:
	return _bay(["escort_drones"], at)

func _guardian(at: Vector3 = Vector3(3, 0, 0)) -> TurretActor:
	return _bay(["escort_drones", "guardian_wing"], at)

func _reaper(at: Vector3 = Vector3(3, 0, 0)) -> TurretActor:
	return _bay(["escort_drones", "reaper_swarm"], at)

func _form(turret: TurretActor) -> DroneBayForm:
	return turret.form as DroneBayForm

func _step(turret: TurretActor, delta: float = STEP) -> void:
	world.crowd.rebuild(world.enemies)
	turret._physics_process(delta)
	swarm.tick(delta)

func _run(turret: TurretActor, seconds: float) -> void:
	for i in roundi(seconds / STEP):
		_step(turret)

func _dummy(at: Vector3, type_id: String = "basic") -> CombatActor:
	return rig.enemy(at, HUGE, type_id)

func _dealt(enemy: CombatActor) -> float:
	return HUGE - enemy.health

func _gap(a: Vector3, b: Vector3) -> float:
	return WorldGeometry.planar(a - b).length()

func _gone(node: Variant) -> bool:
	return not is_instance_valid(node) or (node as Node).is_queued_for_deletion()

# --- Shop, registry and items ---

func test_drone_bay_is_stocked_at_its_registry_price_and_purchasable() -> void:
	assert_has(ArenaShop.TURRETS, "drone_bay")
	assert_has(ShopCatalog.available_ids("turret"), "drone_bay")
	assert_eq(TurretRegistry.get_base_price("drone_bay"), 18)
	var price := world.turret_price("drone_bay")
	EconomyService.total_scrap = 500
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", "drone_bay", price)])
	assert_true(world.shop.purchase(0))
	assert_eq(TurretStatsService.turret_counts.get("drone_bay", 0), 1)
	assert_eq(EconomyService.total_scrap, 500 - price)
	assert_eq(ArenaShop.offer_name(ShopOffer.new("turret", "drone_bay", 1)), "Drone Bay")
	assert_ne(ArenaShop.offer_description(ShopOffer.new("turret", "drone_bay", 1)), "")

func test_shop_rolls_the_drone_bay_and_a_flag_can_gate_it() -> void:
	world.shop.rng = RandomNumberGenerator.new()
	world.shop.rng.seed = 5
	var seen := false
	for roll in 400:
		world.shop.generate()
		for offer: ShopOffer in EconomyService.current_shop_offers:
			if offer.kind == "turret" and offer.asset_id == "drone_bay":
				seen = true
	assert_true(seen, "400 refreshes stock the Drone Bay at least once")
	FeatureFlagService.register_flag(GATE, {"name": "Gate", "scope": FeatureFlagService.SCOPE_EXPERIMENT})
	ShopCatalog.entries["turret"]["drone_bay"] = GATE
	assert_false(ShopCatalog.is_available("turret", "drone_bay"))
	EconomyService.total_scrap = 500
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", "drone_bay", 1)])
	assert_false(world.shop.purchase(0), "A gated turret cannot be bought")

func test_shop_view_data_dev_tools_and_art_know_the_drone_bay() -> void:
	_bay()
	assert_gt(world.dev.add_turret("drone_bay"), 0)
	var data := ShopViewData.build_data(world)
	var row: Dictionary = {}
	for entry: Dictionary in data.turrets:
		if entry.id == "drone_bay":
			row = entry
	assert_false(row.is_empty())
	assert_eq(row.name, "Drone Bay")
	assert_eq(row.drones, 2, "The shop shows how many drones the damage and rate belong to")
	assert_false(row.beam)
	assert_false(row.deploys)
	assert_false(row.utility, "It attacks")
	assert_almost_eq(float(row.damage), 6.0, .001)
	assert_almost_eq(float(row.fire_rate), 1.6, .001)
	assert_same(ShopArt.turret("drone_bay"), load("res://assets/ui/turrets/drone_bay.png"))
	for form in ["drone_bay", "escort_drones", "guardian_wing", "reaper_swarm"]:
		assert_true(ResourceLoader.exists("res://assets/ui/turrets/%s.png" % form), form)
	assert_not_null(UiIcons.turret("drone_bay"))
	assert_true(UiIconData.PATHS.has("turret_drone_bay"))

func test_the_shops_team_figure_counts_every_drone() -> void:
	var without := float(ShopViewData.build_data(world).dps)
	TurretStatsService.turret_counts["drone_bay"] = 1
	var data := ShopViewData.build_data(world)
	assert_almost_eq(float(data.dps) - without, 6.0 * 1.6 * 2.0, .01, "Two drones shooting at once, 19.2")

func test_registry_entry_matches_the_card_and_counts_as_a_projectile_turret() -> void:
	var base := TurretRegistry.get_base_stats("drone_bay")
	assert_eq(base.damage, 6.0, "6 a hit")
	assert_eq(base.drone_count, 2, "2 drones")
	assert_eq(base.range, 500.0, "a 500 leash from the bay")
	assert_eq(TurretRegistry.get_fire_mode("drone_bay"), TurretRegistry.FIRE_DRONES)
	assert_eq(TurretRegistry.get_attack_families("drone_bay"), ["projectile"] as Array[String], "Projectile, Physical")
	assert_eq(TurretRegistry.get_damage_type("drone_bay"), GameEnums.DamageType.PHYSICAL)
	assert_false(TurretRegistry.is_no_attack("drone_bay"))
	assert_eq(TurretRegistry.get_family("drone_bay"), "")
	assert_eq(TurretRegistry.get_targeting("drone_bay"), "closest")

## The amount of the first hit a bay's drones land on `enemy` within three seconds (before Entrench stacks, which come every four).
func _first_hit(bay: TurretActor, enemy: CombatActor) -> float:
	var landed: Array[float] = []
	var listener := func(target: Node3D, hit: CombatHit3D, amount: float) -> void:
		if target == enemy and hit.source_id == bay.turret_id:
			landed.append(amount)
	world.combat.hit_applied.connect(listener)
	rig.combat()
	for i in 180:
		_step(bay)
		if not landed.is_empty():
			break
	world.combat.hit_applied.disconnect(listener)
	return landed[0] if not landed.is_empty() else -1.0

func _base_damage(bay: TurretActor) -> float:
	return bay.resolve_attack_view().damage

func test_a_projectile_item_strengthens_each_drone_shot_and_an_instant_item_does_not() -> void:
	var bay := _bay()
	var enemy := _dummy(Vector3(3, 0, -2))
	ModifierService.add_modifier({"stat": "damage", "operation": "increase", "value": .5, "filter": {"attack_family": ["instant"]}})
	bay.invalidate_stats()
	assert_almost_eq(_first_hit(bay, enemy), 6.0, .001, "An Instant item changes nothing")
	ModifierService.clear_modifiers()
	ModifierService.add_modifier({"stat": "damage", "operation": "increase", "value": .5, "filter": {"attack_family": ["projectile"]}})
	var second := _bay([], Vector3(-3, 0, 0))
	var other := _dummy(Vector3(-3, 0, -2))
	assert_almost_eq(_first_hit(second, other), 9.0, .001, "A Projectile item reaches the drones' shots")

func test_marked_applies_to_a_drone_shot_and_exposed_follows_the_instant_rule() -> void:
	var bay := _bay()
	var enemy := _dummy(Vector3(3, 0, -2))
	assert_almost_eq(_first_hit(bay, enemy), 6.0, .001)
	var marked_bay := _bay([], Vector3(-3, 0, 0))
	var marked := _dummy(Vector3(-3, 0, -2))
	marked.statuses.mark(30.0)
	assert_almost_eq(_first_hit(marked_bay, marked), 6.0 * 1.25, .001, "Marked: +25% from any turret hit")
	var exposed_bay := _bay([], Vector3(-3, 0, 6))
	var exposed := _dummy(Vector3(-3, 0, 4))
	exposed.statuses.expose(30.0)
	assert_almost_eq(_first_hit(exposed_bay, exposed), 6.0, .001, "Exposed is an Instant-hit bonus, and a drone's shot is a Projectile like Ion's")

func test_every_drone_shot_rolls_its_own_crit() -> void:
	var bay := _bay()
	var enemy := _dummy(Vector3(3, 0, -2))
	TestHelpers.force_crits()
	assert_almost_eq(_first_hit(bay, enemy), 6.0 * TurretStatsService.get_turret_crit_multiplier(), .01)

func test_a_shot_carries_the_turrets_id_families_and_damage_type_for_credit() -> void:
	var bay := _bay()
	_dummy(Vector3(3, 0, -2))
	var seen: Array[CombatHit3D] = []
	world.combat.hit_applied.connect(func(_target: Node3D, hit: CombatHit3D, _amount: float) -> void: seen.append(hit))
	rig.combat()
	_run(bay, 5.0)
	assert_gt(seen.size(), 0)
	assert_eq(seen[0].source_id, bay.turret_id)
	assert_has(seen[0].attack_families, "projectile")
	assert_eq(seen[0].damage_type, GameEnums.DamageType.PHYSICAL)
	assert_true(seen[0].impulse.is_zero_approx(), "A drone's bullet does not shove")

func test_a_drone_kill_is_credited_to_its_bay() -> void:
	var bay := _bay()
	var weak := rig.enemy(Vector3(3, 0, -2), 20.0)
	rig.combat()
	_run(bay, 8.0)
	assert_true(weak.dead, "A few shots finish it")
	assert_gt(_form(bay).kills, 0)

# --- The base bay: sorties ---

func test_drones_launch_one_after_another_and_wait_on_their_docks() -> void:
	var bay := _bay()
	rig.combat()
	_step(bay)
	assert_eq(swarm.count_of(bay.turret_id), 1, "The first leaves at once")
	_run(bay, .5)
	assert_eq(swarm.count_of(bay.turret_id), 2, "and the second a quarter second later")
	_run(bay, 2.0)
	assert_eq(swarm.count_of(bay.turret_id), 2, "Never more than the bay keeps")
	for drone in _form(bay).live_drones():
		assert_true(drone.is_docked(), "No enemy: they stay parked")
		var dock := DroneDock.dock_offset(DroneDock.perches(bay.model), drone.slot, 2)
		assert_almost_eq(_gap(drone.position, bay.position), Vector2(dock.x, dock.z).length(), .01, "on its parking dish")
		assert_almost_eq(drone.height(), dock.y, .01, "at the dish's height")
		assert_gt(dock.y, Drone.DOCK_HEIGHT + .2, "The dishes stand well above the floor")

func test_an_enemy_within_the_leash_sends_a_drone_out_to_shoot_and_it_hovers_beside_it() -> void:
	var bay := _bay()
	var enemy := _dummy(Vector3(3, 0, -4))
	rig.combat()
	_run(bay, 1.5)
	var out := false
	for drone in _form(bay).live_drones():
		out = out or drone.mode == Drone.Mode.HOLD
	assert_true(out, "A drone left the dock")
	_run(bay, 2.0)
	assert_gt(_dealt(enemy), 0.0, "and shot it")
	for drone in _form(bay).live_drones():
		if drone.has_target():
			assert_lt(_gap(drone.position, enemy.position), 1.0 + enemy.hurtbox_radius() + DroneBayForm.FIRE_SLACK + .3)

func test_each_drone_fires_at_the_bays_rate() -> void:
	var bay := _bay()
	var enemy := _dummy(Vector3(3, 0, -2))
	rig.combat()
	_run(bay, 3.0)
	var before := _dealt(enemy)
	_run(bay, 5.0)
	var rate := (_dealt(enemy) - before) / 5.0 / 6.0
	assert_between(rate, 1.2, 3.3, "Two drones at 1.6 shots a second: %.2f shots/s" % rate)

func test_an_enemy_beyond_the_leash_is_left_alone() -> void:
	var bay := _bay([], Vector3(0, 0, 0))
	var far := _dummy(Vector3(0, 0, -7.0))
	rig.combat()
	_run(bay, 3.0)
	assert_eq(_dealt(far), 0.0, "Out of the five-metre leash")
	for drone in _form(bay).live_drones():
		assert_true(drone.is_docked())

func test_the_leash_is_measured_from_the_bay_not_the_hero() -> void:
	var bay := _bay([], Vector3(6, 0, 0))
	var near_hero := _dummy(Vector3(-1, 0, 0))
	var near_bay := _dummy(Vector3(6, 0, -4))
	rig.combat()
	_run(bay, 4.0)
	assert_eq(_dealt(near_hero), 0.0)
	assert_gt(_dealt(near_bay), 0.0)

func test_a_sortie_ends_and_the_drone_flies_home_docks_and_rests_before_the_next() -> void:
	var bay := _bay()
	_dummy(Vector3(3, 0, -3))
	rig.combat()
	_run(bay, 1.0)
	var drone := _form(bay).slots[0]
	assert_eq(drone.mode, Drone.Mode.HOLD)
	var launched_at := 0.0
	var recalled := false
	var rested := false
	var again := false
	for i in 1500:
		_step(bay)
		if drone.mode == Drone.Mode.RETURN:
			recalled = true
		if recalled and drone.is_docked():
			rested = true
		if rested and drone.mode == Drone.Mode.HOLD:
			again = true
			break
	assert_true(recalled, "It was recalled when its sortie ran out")
	assert_true(rested, "It docked")
	assert_true(again, "and went out again after resting")
	assert_eq(launched_at, 0.0)

func test_when_its_enemy_dies_a_drone_takes_the_next_one_in_the_leash_else_goes_home() -> void:
	var bay := _bay()
	var first := rig.enemy(Vector3(3, 0, -3), 12.0)
	var second := _dummy(Vector3(4, 0, 1))
	rig.combat()
	_run(bay, 6.0)
	assert_true(first.dead)
	assert_gt(_dealt(second), 0.0, "The sortie went on to the next enemy")
	second.dead = true
	world.enemies.erase(second)
	_run(bay, 2.5)
	for drone in _form(bay).live_drones():
		assert_ne(drone.mode, Drone.Mode.HOLD, "Nothing left within the leash: home")

func test_two_drones_spread_over_two_enemies_before_doubling_up() -> void:
	var bay := _bay()
	var a := _dummy(Vector3(3, 0, -3))
	var b := _dummy(Vector3(5, 0, 1))
	rig.combat()
	_run(bay, 3.0)
	assert_gt(_dealt(a), 0.0)
	assert_gt(_dealt(b), 0.0)

func test_the_head_turns_toward_the_work() -> void:
	var bay := _bay()
	_dummy(Vector3(7, 0, -2))
	rig.combat()
	var before := bay.aim.rotation.y
	_run(bay, 3.0)
	assert_ne(bay.aim.rotation.y, before)

# --- Escort Drones ---

func test_escort_drones_orbit_the_hero_not_the_bay() -> void:
	var bay := _escort(Vector3(8, 0, 4))
	rig.combat()
	_run(bay, 4.0)
	assert_eq(swarm.count_of(bay.turret_id), 3)
	for drone in _form(bay).live_drones():
		assert_eq(drone.mode, Drone.Mode.ORBIT)
		assert_almost_eq(_gap(drone.position, world.player.position), _form(bay).orbit_radius(), .4, "Round the hero")

func test_escort_drones_follow_a_walking_hero() -> void:
	var bay := _escort(Vector3(8, 0, 4))
	rig.combat()
	_run(bay, 2.0)
	for i in 300:
		world.player.position += Vector3(.012, 0, -.008)
		_step(bay)
	for drone in _form(bay).live_drones():
		assert_lt(_gap(drone.position, world.player.position), 2.0, "Still with the hero")

func test_escort_drones_shoot_only_enemies_within_two_and_a_half_metres_of_the_hero() -> void:
	var bay := _escort(Vector3(8, 0, 4))
	var close := _dummy(Vector3(1.5, 0, 0))
	var far := _dummy(Vector3(-4.5, 0, 0))
	rig.combat()
	_run(bay, 5.0)
	assert_gt(_dealt(close), 0.0)
	assert_eq(_dealt(far), 0.0, "Out of the hero's two-and-a-half metre cover")

func test_escort_drones_cover_the_hero_wherever_the_bay_stands() -> void:
	var bay := _escort(Vector3(-8, 0, -5))
	var near_bay := _dummy(Vector3(-8, 0, -3))
	var near_hero := _dummy(Vector3(0, 0, 1.2))
	rig.combat()
	_run(bay, 5.0)
	assert_eq(_dealt(near_bay), 0.0, "Nothing is covered round the bay")
	assert_gt(_dealt(near_hero), 0.0)

func test_escort_drones_go_back_to_orbit_when_the_enemy_is_gone() -> void:
	var bay := _escort()
	var enemy := rig.enemy(Vector3(1.5, 0, 0), 10.0)
	rig.combat()
	_run(bay, 5.0)
	assert_true(enemy.dead)
	_run(bay, 1.0)
	for drone in _form(bay).live_drones():
		assert_eq(drone.mode, Drone.Mode.ORBIT)

func test_escort_drones_work_round_the_bay_when_the_hero_is_gone() -> void:
	var bay := _escort(Vector3(8, 0, 4))
	world.player.dead = true
	rig.combat()
	_run(bay, 3.0)
	for drone in _form(bay).live_drones():
		assert_almost_eq(_gap(drone.position, bay.position), _form(bay).orbit_radius(), .5)
	world.player.dead = false

# --- Guardian Wing ---

func _bolt(from: Vector3, toward: Vector3, to_core: bool = false) -> EnemyOrdnance:
	var shooter := _dummy(from + Vector3(0, 0, -3), "kite")
	var shot := EnemyOrdnance.launch(shooter, "bolt", from, toward, 5.0, to_core)
	shot.world = world
	world.add_child(shot)
	return shot

func _shell(at: Vector3, ground: bool = false) -> EnemyOrdnance:
	var shooter := _dummy(at + Vector3(0, 0, -6), "lobber")
	var shot := EnemyOrdnance.launch(shooter, "area", shooter.position, at, 5.0)
	shot.ground_strike = ground
	shot.world = world
	world.add_child(shot)
	return shot

func _fly_ordnance(turret: TurretActor, shots: Array[EnemyOrdnance], seconds: float) -> void:
	for i in roundi(seconds / STEP):
		for shot in shots:
			if is_instance_valid(shot) and not shot.is_queued_for_deletion():
				shot._physics_process(STEP)
		_step(turret)

func test_a_bolt_aimed_at_the_hero_hurts_the_hero_when_nothing_guards_it() -> void:
	var bay := _escort()
	var shot := _bolt(Vector3(0, 0, -6), Vector3.ZERO)
	rig.combat()
	var health: float = world.player.health
	_fly_ordnance(bay, [shot], 2.0)
	assert_lt(world.player.health, health, "The baseline: an escort does not shoot bolts")

func test_guardian_wing_shoots_down_a_bolt_aimed_at_the_hero() -> void:
	var wing := _guardian()
	var shot := _bolt(Vector3(0, 0, -6), Vector3.ZERO)
	rig.combat()
	var health: float = world.player.health
	_fly_ordnance(wing, [shot], 2.0)
	assert_eq(world.player.health, health, "Not a scratch")
	assert_true(_gone(shot))
	assert_eq(_form(wing).intercepts, 1)

func test_guardian_wing_shoots_down_a_shell_whose_blast_would_reach_the_hero() -> void:
	var wing := _guardian()
	var shell := _shell(Vector3(.5, 0, 0))
	rig.combat()
	var health: float = world.player.health
	_fly_ordnance(wing, [shell], 1.5)
	assert_true(_gone(shell), "Shot down before it landed")
	assert_eq(world.player.health, health)
	assert_eq(_form(wing).intercepts, 1)

func test_guardian_wing_leaves_alone_what_is_not_aimed_at_the_hero() -> void:
	var wing := _guardian()
	var wide_bolt := _bolt(Vector3(4, 0, -6), Vector3(4, 0, 0))
	var core_bolt := _bolt(Vector3(0, 0, -6), Vector3.ZERO, true)
	var far_shell := _shell(Vector3(4, 0, 4))
	var slam := _shell(Vector3(.2, 0, 0), true)
	rig.combat()
	_run(wing, 1.0)
	_fly_ordnance(wing, [wide_bolt, core_bolt, far_shell, slam], .3)
	assert_false(_gone(wide_bolt), "A bolt that passes 4 m from the hero")
	assert_false(_gone(core_bolt), "Aimed at the core: the hero is all it protects")
	assert_false(_gone(far_shell), "A shell that lands 5.6 m away")
	assert_false(_gone(slam), "A boss slam has no shell to shoot")
	assert_eq(_form(wing).intercepts, 0)

func test_guardian_wing_does_not_shoot_beams_or_far_off_bolts() -> void:
	var wing := _guardian()
	var shooter := _dummy(Vector3(0, 0, -8), "kite")
	var beam := EnemyOrdnance.launch(shooter, "beam", Vector3(0, 0, -8), Vector3.ZERO, 5.0)
	beam.world = world
	world.add_child(beam)
	var distant := _bolt(Vector3(0, 0, -9), Vector3.ZERO)
	rig.combat()
	_run(wing, 1.0)
	assert_false(_gone(beam))
	assert_false(_gone(distant), "More than 4.5 m from the hero is out of the wing's reach")

func test_each_guardian_drone_shoots_down_one_shot_per_cooldown() -> void:
	var wing := _guardian()
	rig.combat()
	_run(wing, 2.0)
	var shots: Array[EnemyOrdnance] = []
	for i in 8:
		var shot := _bolt(Vector3(-2.0 + float(i) * .5, 0, -3.5), Vector3.ZERO)
		shots.append(shot)
	_form(wing).guard.scan()
	for i in 20:
		_step(wing)
	var down := 0
	for shot in shots:
		if _gone(shot):
			down += 1
	assert_lte(down, 4, "Four drones, one each, inside the first cooldown: %d" % down)
	assert_gte(down, 1)
	assert_lte(_form(wing).intercepts, 4)

func test_guardian_wing_still_shoots_enemies_like_the_escort() -> void:
	var wing := _guardian()
	var enemy := _dummy(Vector3(1.5, 0, 0))
	rig.combat()
	_run(wing, 5.0)
	assert_gt(_dealt(enemy), 0.0)

func test_only_a_guardian_wing_shoots_shots_down() -> void:
	for forms: Array in [[], ["escort_drones"], ["escort_drones", "reaper_swarm"]]:
		var path: Array[String] = []
		path.assign(forms)
		var bay := _bay(path, Vector3(3, 0, 0))
		assert_false(_form(bay).can_intercept(), str(forms))
	assert_true(_form(_guardian()).can_intercept())

# --- Reaper Swarm ---

func test_reaper_swarm_dives_at_the_nearest_ranged_enemy_before_anything_else() -> void:
	var bay := _reaper()
	var melee := _dummy(Vector3(1.2, 0, 0))
	var kite := _dummy(Vector3(-4.0, 0, 0), "kite")
	var lobber := _dummy(Vector3(0, 0, 5.0), "lobber")
	rig.combat()
	_run(bay, 5.0)
	assert_gt(_dealt(kite), 0.0, "The nearer ranged enemy, 4 m out, is dived on")
	assert_gt(_dealt(kite), _dealt(lobber), "and before the farther one")
	assert_eq(_dealt(melee), 0.0, "No drone is left for the melee enemy while a Kite lives")

func test_reaper_swarm_hits_ranged_and_summoner_enemies_sixty_percent_harder() -> void:
	var bay := _reaper()
	var base := _base_damage(bay)
	assert_almost_eq(base, 4.2 * 1.25, .001, "Level 10 adds its own 25% to the row's 4.2")
	var amounts := {}
	world.combat.hit_applied.connect(func(target: Node3D, _h: CombatHit3D, amount: float) -> void:
		if not amounts.has(target):
			amounts[target] = amount)
	var kite := _dummy(Vector3(-3.0, 0, 0), "kite")
	rig.combat()
	_run(bay, 2.0)
	assert_almost_eq(float(amounts[kite]), base * 1.6, .001, "A Kite takes 60% more")
	kite.dead = true
	world.enemies.erase(kite)
	var tender := _dummy(Vector3(0, 0, 4.0), "tender")
	_run(bay, 2.0)
	assert_almost_eq(float(amounts[tender]), base * 1.6, .001, "so does a Tender")
	tender.dead = true
	world.enemies.erase(tender)
	var basic := _dummy(Vector3(0, 0, -1.0))
	_run(bay, 1.0)
	assert_almost_eq(float(amounts[basic]), _base_damage(bay), .001, "Nothing else does (the base moves a little as Entrench stacks)")

func test_reaper_swarm_ignores_a_ranged_enemy_beyond_its_reach() -> void:
	var bay := _reaper()
	var kite := _dummy(Vector3(-7.5, 0, 0), "kite")
	var melee := _dummy(Vector3(1.0, 0, 0))
	rig.combat()
	_run(bay, 4.0)
	assert_eq(_dealt(kite), 0.0, "Past six metres from the hero")
	assert_gt(_dealt(melee), 0.0, "so the drones go about their escort")

func test_a_reaper_kill_launches_an_extra_drone_for_four_seconds() -> void:
	var bay := _reaper()
	var kite := rig.enemy(Vector3(-3.0, 0, 0), 4000.0, "kite")
	rig.combat()
	_run(bay, 1.0)
	assert_eq(swarm.count_of(bay.turret_id), 5)
	var launched_before := _form(bay).extras_launched
	kite.health = 30.0
	for i in 600:
		_step(bay)
		if kite.dead:
			break
	assert_true(kite.dead)
	assert_eq(_form(bay).extras_launched, launched_before + 1)
	assert_eq(_form(bay).extras.size(), 1)
	assert_eq(swarm.count_of(bay.turret_id), 6)
	var extra := _form(bay).extras[0]
	assert_true(extra.temporary)
	assert_almost_eq(extra.life, 4.0, .001)
	_run(bay, 4.2)
	assert_true(extra.spent, "It is gone after its four seconds")
	assert_eq(swarm.count_of(bay.turret_id), 5, "and the five stay")
	assert_eq(_form(bay).extras.size(), 0)

func test_reaper_extras_are_capped_per_bay_and_by_the_arena() -> void:
	var bay := _reaper()
	rig.combat()
	_run(bay, 1.0)
	var killer := _form(bay).slots[0]
	for i in 12:
		_form(bay)._reward_kill(killer)
	assert_eq(_form(bay).extras.size(), 2, "Two extras at a time, however many kills")
	assert_eq(swarm.count_of(bay.turret_id), 7, "Five plus two")
	assert_lte(swarm.count_of(bay.turret_id), DroneBayForm.MAX_PER_BAY)
	# Fill the rest of the arena with another owner's drones: an extra is then refused, never made by recycling.
	for extra in _form(bay).extras.duplicate():
		swarm.destroy(extra)
	_form(bay)._prune_extras()
	for i in GameConstants.DRONE_MAX - swarm.count():
		var filler := Drone.new()
		filler.owner_id = 99
		swarm.launch(filler)
	assert_eq(swarm.count(), GameConstants.DRONE_MAX)
	var refused := _form(bay).extras_refused
	_form(bay)._reward_kill(killer)
	assert_eq(_form(bay).extras_refused, refused + 1)
	assert_eq(swarm.count(), GameConstants.DRONE_MAX)

func test_a_long_fight_never_grows_a_reaper_swarm_past_seven_drones() -> void:
	var bay := _reaper()
	rig.combat()
	var most := 0
	for second in 40:
		_dummy(Vector3(-3.0, 0, 0), "kite").health = 5.0
		_dummy(Vector3(1.0, 0, 0)).health = 5.0
		for i in 60:
			_step(bay)
			most = maxi(most, swarm.count_of(bay.turret_id))
	assert_lte(most, 5 + 2)
	assert_eq(most, 5 + 2, "and the extras do come")
	assert_gt(_form(bay).kills, 10, "It really was killing")

func test_other_forms_make_no_extras() -> void:
	var bay := _escort()
	rig.combat()
	_run(bay, 1.0)
	_form(bay)._reward_kill(_form(bay).slots[0])
	assert_eq(_form(bay).extras.size(), 0)

# --- Wear and replacement ---

func test_a_worn_out_drone_is_replaced_after_the_rebuild_time() -> void:
	var bay := _bay()
	rig.combat()
	_run(bay, 1.0)
	var lost := _form(bay).slots[0]
	swarm.destroy(lost, true)
	assert_eq(swarm.count_of(bay.turret_id), 1)
	_run(bay, 2.5)
	assert_eq(swarm.count_of(bay.turret_id), 1, "Not before three seconds")
	_run(bay, 1.0)
	assert_eq(swarm.count_of(bay.turret_id), 2)
	assert_ne(_form(bay).slots[0], lost)
	assert_eq(_form(bay).replaced, 1)

func test_drones_wear_out_after_their_airframe_and_the_bay_replaces_them_for_good() -> void:
	var bay := _bay()
	rig.combat()
	_run(bay, 1.0)
	var first := _form(bay).slots[0]
	assert_almost_eq(first.life, DroneBayForm.DEFAULT_AIRFRAME, 2.1)
	first.life = first.age + 2.0
	_run(bay, 1.5)
	assert_false(first.spent)
	_run(bay, .8)
	assert_true(first.spent)
	assert_eq(swarm.lost, 1)
	_run(bay, 3.5)
	assert_eq(swarm.count_of(bay.turret_id), 2, "Back to the bay's two")
	var second := _form(bay).slots[0]
	assert_ne(second, first)
	assert_almost_eq(second.life, DroneBayForm.DEFAULT_AIRFRAME, .001, "A fresh airframe")

func test_the_first_airframes_wear_out_a_couple_of_seconds_apart() -> void:
	var bay := _escort()
	rig.combat()
	_run(bay, 1.0)
	var lives: Array[float] = []
	for drone in _form(bay).slots:
		lives.append(drone.life)
	assert_lt(lives[0], lives[1])
	assert_lt(lives[1], lives[2])

func test_a_full_arena_delays_a_replacement_instead_of_recycling() -> void:
	var bay := _bay()
	rig.combat()
	_run(bay, 1.0)
	swarm.destroy(_form(bay).slots[0], true)
	for i in GameConstants.DRONE_MAX - swarm.count():
		var filler := Drone.new()
		filler.owner_id = 99
		swarm.launch(filler)
	_run(bay, 4.0)
	assert_eq(swarm.count_of(bay.turret_id), 1, "No room: the slot stays empty")
	assert_eq(swarm.count_of(99), GameConstants.DRONE_MAX - 1, "and nobody else lost a drone")
	swarm.clear_owner(99)
	_run(bay, 1.5)
	assert_eq(swarm.count_of(bay.turret_id), 2, "The slot fills when there is room")

# --- Caps ---

func test_many_bays_never_push_the_arena_past_the_cap_or_one_bay_past_its_own() -> void:
	var bays: Array[TurretActor] = []
	for i in 6:
		bays.append(_reaper(Vector3(float(i) * 2.0 - 5.0, 0, 5.0)))
	rig.combat()
	for second in 6:
		for i in 60:
			world.crowd.rebuild(world.enemies)
			for bay in bays:
				bay._physics_process(STEP)
			swarm.tick(STEP)
			assert_lte(swarm.count(), GameConstants.DRONE_MAX)
	assert_eq(swarm.count(), GameConstants.DRONE_MAX, "Six bays of five want thirty; twenty-four fly")
	for bay in bays:
		assert_lte(swarm.count_of(bay.turret_id), 5)
	assert_gt(swarm.count_of(bays[0].turret_id), 0)

func test_a_bays_slots_follow_the_drone_count_stat_and_stay_within_eight() -> void:
	var bay := _bay()
	rig.combat()
	_run(bay, 2.0)
	assert_eq(_form(bay).drone_count(), 2)
	bay.stats_view.values["drone_count"] = 99
	assert_eq(_form(bay).drone_count(), DroneBayForm.MAX_PER_BAY)

# --- Two bays ---

func test_two_bays_have_their_own_drones_kills_and_slots() -> void:
	var left := _bay([], Vector3(-4, 0, 0))
	var right := _bay([], Vector3(4, 0, 0))
	var a := _dummy(Vector3(-4, 0, -3))
	var b := _dummy(Vector3(4, 0, -3))
	rig.combat()
	for i in 360:
		world.crowd.rebuild(world.enemies)
		left._physics_process(STEP)
		right._physics_process(STEP)
		swarm.tick(STEP)
	assert_eq(swarm.count_of(left.turret_id), 2)
	assert_eq(swarm.count_of(right.turret_id), 2)
	assert_gt(_dealt(a), 0.0)
	assert_gt(_dealt(b), 0.0)
	assert_gt(_form(left).shots, 0)
	assert_gt(_form(right).shots, 0)
	for drone in _form(left).live_drones():
		assert_false(drone in _form(right).live_drones())

func test_removing_one_bay_leaves_the_other_flying() -> void:
	var left := _bay([], Vector3(-4, 0, 0))
	var right := _bay([], Vector3(4, 0, 0))
	rig.combat()
	for i in 120:
		world.crowd.rebuild(world.enemies)
		left._physics_process(STEP)
		right._physics_process(STEP)
		swarm.tick(STEP)
	var id := left.turret_id
	world.turrets.erase(left)
	left.get_parent().remove_child(left)
	left.free()
	assert_eq(swarm.count_of(id), 0, "Its drones went with it")
	assert_eq(swarm.count_of(right.turret_id), 2)

func test_two_guardian_wings_do_not_double_count_one_shot() -> void:
	var first := _guardian(Vector3(3, 0, 0))
	var second := _guardian(Vector3(-3, 0, 0))
	var shot := _bolt(Vector3(0, 0, -6), Vector3.ZERO)
	rig.combat()
	for i in 120:
		world.crowd.rebuild(world.enemies)
		first._physics_process(STEP)
		second._physics_process(STEP)
		swarm.tick(STEP)
		if is_instance_valid(shot) and not shot.is_queued_for_deletion():
			shot._physics_process(STEP)
	assert_true(_gone(shot))
	assert_eq(_form(first).intercepts + _form(second).intercepts, 1, "One shot, one shoot-down")

# --- Existing behaviour ---

func test_other_turrets_fire_as_before_with_a_bay_in_the_arena() -> void:
	var bay := _bay([], Vector3(8, 0, 4))
	var ion := rig.turret("normal", [], Vector3(0, 0, 1.5))
	var enemy := _dummy(Vector3(0, 0, 0))
	rig.combat()
	for i in 240:
		world.crowd.rebuild(world.enemies)
		bay._physics_process(STEP)
		ion._physics_process(STEP)
		swarm.tick(STEP)
		for projectile in world.projectiles:
			if projectile.active:
				projectile._physics_process(STEP)
	assert_gt(world.projectiles.size(), 0, "The Ion still shoots")
	assert_gt(_dealt(enemy), 0.0)

func test_the_bay_fires_no_projectiles_of_its_own() -> void:
	var bay := _bay()
	_dummy(Vector3(3, 0, -3))
	rig.combat()
	_run(bay, 4.0)
	assert_eq(world.projectiles.size(), 0)
	assert_gt(_form(bay).shots, 0)

func test_drones_never_hurt_the_hero_or_a_turret() -> void:
	var bay := _escort()
	var ion := rig.turret("normal", [], Vector3(1, 0, 0))
	_dummy(Vector3(1.2, 0, 0))
	rig.combat()
	var health: float = world.player.health
	_run(bay, 6.0)
	assert_eq(world.player.health, health)
	assert_not_null(ion)

# --- Shop and inspector figures ---

func test_the_dps_figure_counts_every_drone_for_each_form() -> void:
	for spec: Array in [[[], 2], [["escort_drones"], 3], [["escort_drones", "guardian_wing"], 4], [["escort_drones", "reaper_swarm"], 5]]:
		var path: Array[String] = []
		path.assign(spec[0])
		var bay := _bay(path, Vector3(float(spec[1]) * 3.0, 0, 20))
		var stats := bay.resolve_attack_view()
		assert_eq(int(stats.values.drone_count), int(spec[1]))
		assert_almost_eq(TurretForm.dps_of(bay), stats.damage * stats.fire_rate * float(spec[1]), .01, str(spec[0]))
	assert_almost_eq(TurretForm.dps_of(_bay([], Vector3(0, 0, 20))), 6.0 * 1.6 * 2.0, .01, "The base bay is the card's 6 x 2 drones")

func test_pattern_text_describes_each_form() -> void:
	assert_string_contains(TurretEvolution.drone_bay_pattern_text(""), "dock")
	assert_string_contains(TurretEvolution.drone_bay_pattern_text("escort_drones"), "orbit you")
	assert_string_contains(TurretEvolution.drone_bay_pattern_text("guardian_wing"), "shoot down")
	assert_string_contains(TurretEvolution.drone_bay_pattern_text("reaper_swarm"), "Kites")

# --- Clean-up ---

func _fly_a_while(bay: TurretActor) -> void:
	_dummy(Vector3(3, 0, -3))
	rig.combat()
	_run(bay, 1.5)
	assert_gt(swarm.count_of(bay.turret_id), 0)

func test_wave_end_and_combat_stopping_bring_the_drones_down_and_they_launch_again() -> void:
	var bay := _bay()
	_fly_a_while(bay)
	rig.shop()
	bay._physics_process(STEP)
	assert_eq(swarm.count_of(bay.turret_id), 0, "Gone the moment combat stops")
	assert_true(_form(bay).slots.is_empty())
	rig.combat()
	_run(bay, 1.5)
	assert_gt(swarm.count_of(bay.turret_id), 0, "The next wave sends them up again")

func test_pausing_brings_the_drones_down() -> void:
	var bay := _bay()
	_fly_a_while(bay)
	world.paused = true
	bay._physics_process(STEP)
	swarm._physics_process(STEP)
	assert_eq(swarm.count_of(bay.turret_id), 0)
	world.paused = false

func test_pausing_stops_a_bay_dealing_damage() -> void:
	var bay := _bay()
	var enemy := _dummy(Vector3(3, 0, -3))
	rig.combat()
	_run(bay, 3.0)
	var dealt := _dealt(enemy)
	world.paused = true
	for i in 120:
		_step(bay)
	assert_eq(_dealt(enemy), dealt)
	world.paused = false

func test_picking_a_bay_up_keeps_its_drones_and_they_follow_the_hero() -> void:
	var bay := _bay([], Vector3(6, 0, 3))
	_fly_a_while(bay)
	bay.carried = true
	world.player.position = Vector3(-4, 0, -2)
	_run(bay, 2.0)
	assert_eq(swarm.count_of(bay.turret_id), 2)
	for drone in _form(bay).live_drones():
		assert_lt(_gap(drone.position, world.player.position), 1.6, "The dock rides the hero")

func test_a_carried_escort_still_covers_the_hero() -> void:
	var bay := _escort()
	var enemy := _dummy(Vector3(1.2, 0, 0))
	bay.carried = true
	rig.combat()
	_run(bay, 4.0)
	assert_gt(_dealt(enemy), 0.0)

func test_removing_a_bay_takes_its_drones_with_it() -> void:
	var bay := _bay()
	_fly_a_while(bay)
	var id := bay.turret_id
	world.turrets.erase(bay)
	bay.get_parent().remove_child(bay)
	assert_eq(swarm.count_of(id), 0)
	bay.free()

func test_evolving_a_bay_takes_the_old_forms_drones_and_the_new_form_launches_its_own() -> void:
	var bay := _bay()
	_fly_a_while(bay)
	var old := _form(bay).live_drones()
	assert_eq(old.size(), 2)
	rig.level_to(bay, 5)
	rig.shop()
	assert_true(bay.evolve("escort_drones"))
	for drone in old:
		assert_true(drone.spent, "The old form's drones are gone")
	assert_eq(swarm.count_of(bay.turret_id), 0)
	rig.combat()
	_run(bay, 3.0)
	assert_eq(swarm.count_of(bay.turret_id), 3, "Three escorts now")

func test_evolving_to_a_final_takes_the_extras_and_the_escorts() -> void:
	var bay := _reaper()
	var other := _bay(["escort_drones"])
	rig.level_to(other, 10)
	rig.combat()
	_run(bay, 1.0)
	_form(bay)._reward_kill(_form(bay).slots[0])
	assert_eq(swarm.count_of(bay.turret_id), 6)
	rig.shop()
	assert_true(other.evolve("guardian_wing"))
	assert_eq(swarm.count_of(bay.turret_id), 6, "Another bay's evolving takes none of this one's")
	assert_eq(swarm.count_of(other.turret_id), 0)

func test_clear_field_drops_the_drones() -> void:
	var bay := _bay()
	_fly_a_while(bay)
	world.clear_field(false)
	assert_eq(swarm.count(), 0)
	assert_eq(swarm.count_of(bay.turret_id), 0)

func test_a_defeat_drops_the_drones() -> void:
	var bay := _bay()
	_fly_a_while(bay)
	world._end_run_in_defeat("test")
	assert_eq(swarm.count(), 0)

func test_a_new_run_drops_the_drones_and_frees_the_old_bay() -> void:
	var bay := _bay()
	_fly_a_while(bay)
	world.start_run()
	assert_eq(world.drones.count(), 0)
	await wait_process_frames(2)
	assert_false(is_instance_valid(bay), "The old bay left with the run")

func test_a_repeated_idle_clear_costs_nothing() -> void:
	var bay := _bay()
	_form(bay).clear()
	_form(bay).clear()
	_form(bay).removed()
	assert_eq(swarm.count(), 0)

func test_flying_and_clearing_leaks_no_nodes() -> void:
	var bay := _guardian()
	_fly_a_while(bay)
	var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for round in 5:
		rig.combat()
		_run(bay, 1.5)
		rig.shop()
		bay._physics_process(STEP)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), nodes, "Drones are buffer slots, not nodes")

# --- Looks ---

func test_all_four_stages_use_the_drone_bay_chassis_with_a_muzzle_and_a_head() -> void:
	for path: Array in [[], ["escort_drones"], ["escort_drones", "guardian_wing"], ["escort_drones", "reaper_swarm"]]:
		var forms: Array[String] = []
		forms.assign(path)
		var turret := _bay(forms, Vector3(float(forms.size()) * 3.0, 0, 20))
		assert_eq(turret._model_key(turret.progression.evolution_form), "drone_bay")
		assert_not_null(turret.aim, "%s has a head" % turret.display_name())
		assert_not_null(turret.muzzle)

func test_each_form_adds_pads_for_its_drones_and_hardware_to_the_chassis() -> void:
	var counts := {}
	for path: Array in [[], ["escort_drones"], ["escort_drones", "guardian_wing"], ["escort_drones", "reaper_swarm"]]:
		var forms: Array[String] = []
		forms.assign(path)
		var turret := _bay(forms, Vector3(float(counts.size()) * 3.0, 0, 20))
		counts[str(path)] = turret.model.find_children("*", "MeshInstance3D", true, false).size()
	var base_meshes: int = counts["[]"]
	for key in counts:
		if key != "[]":
			assert_gt(int(counts[key]), base_meshes, "%s adds hardware to the chassis" % key)
	var reaper := _reaper(Vector3(20, 0, 20))
	assert_eq(reaper.model.find_children("DockLight*", "MeshInstance3D", true, false).size(), 5, "A lit dock for each of the five drones")
	assert_eq(reaper.model.find_children("DockPad*", "MeshInstance3D", true, false).size(), 3, "Two ride the chassis's dishes, the other three get floor pads")

func test_the_chassis_parks_two_drones_that_the_real_ones_replace_while_they_hold_the_slots() -> void:
	var bay := _bay()
	assert_eq(DroneDock.perches(bay.model).size(), 2, "The model has two parking dishes")
	for index in 2:
		var parts := DroneDock.parked_drone(bay.model, index)
		assert_eq(parts.size(), 4, "Body, dome, glow and propellers")
		for node in parts:
			assert_true(node.visible, "In the shop the parked pair shows")
	rig.combat()
	_run(bay, 1.0)
	for index in 2:
		for node in DroneDock.parked_drone(bay.model, index):
			assert_false(node.visible, "A real drone holds the slot, so the parked one is hidden")
	for label in ["Drone_Wire", "Drone_Arm"]:
		assert_true((bay.model.find_child("%s_Brass" % label, true, false) as Node3D).visible, "The dish stays")
	rig.shop()
	bay._physics_process(STEP)
	for index in 2:
		for node in DroneDock.parked_drone(bay.model, index):
			assert_true(node.visible, "Back to the parked pair when combat stops")

func test_docks_past_the_dishes_are_floor_pads_in_the_front_arc_and_other_chassis_use_the_ring() -> void:
	var dishes := DroneDock.perches(_bay().model)
	var seen: Array[Vector2] = []
	for slot in 5:
		var dock := DroneDock.dock_offset(dishes, slot, 5)
		if slot >= 2:
			assert_almost_eq(Vector2(dock.x, dock.z).length(), DroneDock.PAD_RING, .001, "Floor pads sit on one ring")
			assert_gt(dock.z, 0.3, "in front of the tower, clear of the tunnel")
			assert_lt(dock.y, .4, "at the floor")
		for other in seen:
			assert_gt(Vector2(dock.x, dock.z).distance_to(other), .35, "No two docks overlap")
		seen.append(Vector2(dock.x, dock.z))
	for slot in 3:
		var ring := DroneDock.dock_offset([], slot, 3)
		assert_almost_eq(Vector2(ring.x, ring.z).length(), DroneDock.DOCK_RADIUS, .001, "No dishes: the plain ring")

func test_the_rotating_hardware_rides_the_head() -> void:
	var wing := _guardian(Vector3(0, 0, 20))
	assert_not_null(wing.aim.find_child("ShieldHoop", false, false))
	assert_not_null(wing.aim.find_child("WingFin", false, false))
	var escort := _escort(Vector3(4, 0, 20))
	assert_not_null(escort.aim.find_child("MastRing", false, false))
	assert_not_null(escort.model.find_child("DockPad", false, false), "The pads stay on the floor")

# --- Tuning ---

## One scenario of mortal enemies walking up to the stationary hero, simulated in game time (no GPU involved): the damage per second a
## bay at level 10 credits to itself. `kind` picks the traffic:
##   sparse    one enemy of 100 health every 1.4 s from a random side (about what the Escort Drones can kill: little spare for the rest)
##   stream    one of 150 health every 0.8 s (the drones never run dry)
##   packs     four of 100 health every 3 s, close together
##   harassed  the stream, but every fourth enemy is a 90 health Kite that stops 4.2 m from the hero and stays nine seconds
## Enemies walk at 1.3 m/s and stop 0.6 m from the hero (a Kite where it is); one that is not dead after nine seconds is taken away.
func _traffic(path: Array[String], kind: String, seconds: float) -> float:
	rig = TurretTestRig.start(self)
	rig.disable_crits()
	world = rig.world
	swarm = world.drones
	for starting in world.turrets:
		starting.position = Vector3(24, 0, 16)
	world.player.position = Vector3.ZERO
	var bay := _bay(path, Vector3(2.5, 0, 0))
	rig.level_to(bay, 10)
	rig.combat()
	var tally := {"damage": 0.0, "kills": 0}
	world.combat.hit_applied.connect(func(_t: Node3D, hit: CombatHit3D, amount: float) -> void:
		if hit.source_id == bay.turret_id:
			tally["damage"] += amount)
	var walkers: Array[Dictionary] = []
	var clock := 0.0
	var count := 0
	var spawn_rng := RandomNumberGenerator.new()
	spawn_rng.seed = 7
	for i in roundi(seconds / STEP):
		clock -= STEP
		if clock <= 0.0:
			var bearing := spawn_rng.randf() * TAU
			match kind:
				"sparse":
					clock += 1.4
					walkers.append(_walker(bearing, 7.0, "basic", 100.0))
				"stream":
					clock += .8
					walkers.append(_walker(bearing, 7.0, "basic", 150.0))
				"packs":
					clock += 3.0
					for k in 4:
						walkers.append(_walker(bearing + float(k) * .35, 7.0 + float(k) * .4, "basic", 100.0))
				"harassed":
					clock += .8
					if count % 4 == 3:
						walkers.append(_walker(bearing, 4.2, "kite", 90.0))
					else:
						walkers.append(_walker(bearing, 7.0, "basic", 150.0))
			count += 1
		for index in range(walkers.size() - 1, -1, -1):
			var walker := walkers[index]
			var enemy: CombatActor = walker.actor
			if enemy.dead:
				tally["kills"] += 1
				walkers.remove_at(index)
				continue
			walker.age = float(walker.age) + STEP
			var to_hero := WorldGeometry.planar(world.player.position - enemy.position)
			var stop := float(walker.stop)
			if to_hero.length() > stop:
				enemy.position += to_hero.normalized() * minf(1.3 * STEP, to_hero.length() - stop)
			if float(walker.age) > 9.0 + float(walker.travel):
				enemy.dead = true
				world.enemies.erase(enemy)
				enemy.queue_free()
				walkers.remove_at(index)
		bay._physics_process(STEP)
		world.crowd.rebuild(world.enemies)
		swarm.tick(STEP)
	var result := float(tally["damage"]) / seconds
	for walker in walkers:
		(walker.actor as CombatActor).dead = true
	swarm.clear()
	return result

func _walker(bearing: float, distance: float, type_id: String, health: float) -> Dictionary:
	var at := Vector3(cos(bearing), 0, sin(bearing)) * distance
	var enemy := rig.enemy(at, health, type_id)
	var stop := .6 if type_id == "basic" else distance
	return {"actor": enemy, "age": 0.0, "stop": stop, "travel": maxf(distance - stop, 0.0) / 1.3}

## The damage per second of each final against the Escort Drones in four kinds of traffic, all at level 10. The figure is what the
## drones deal; Guardian Wing's shoot-down (see the next test) is worth more on top and is not in it.
func test_the_finals_are_tuned_against_the_upgrade_in_simulated_traffic() -> void:
	var guardian_ratios: Array[float] = []
	var reaper_ratios: Array[float] = []
	for kind in ["sparse", "stream", "packs", "harassed"]:
		var upgrade := _traffic(["escort_drones"], kind, 60.0)
		var guardian := _traffic(["escort_drones", "guardian_wing"], kind, 60.0)
		var reaper := _traffic(["escort_drones", "reaper_swarm"], kind, 60.0)
		guardian_ratios.append(guardian / maxf(upgrade, .001))
		reaper_ratios.append(reaper / maxf(upgrade, .001))
		gut.p("%s: Escort %.1f, Guardian %.1f (%.2fx), Reaper %.1f (%.2fx)" % [kind, upgrade, guardian, guardian_ratios[-1], reaper, reaper_ratios[-1]])
		assert_gt(upgrade, 0.0, kind)
	var guardian_mean := (guardian_ratios[0] + guardian_ratios[1] + guardian_ratios[2] + guardian_ratios[3]) / 4.0
	var reaper_mean := (reaper_ratios[0] + reaper_ratios[1] + reaper_ratios[2] + reaper_ratios[3]) / 4.0
	gut.p("Means: Guardian Wing %.2fx, Reaper Swarm %.2fx" % [guardian_mean, reaper_mean])
	assert_between(guardian_mean, 1.3, 1.6, "Guardian Wing's damage, on average, is 1.4 to 1.6 times the upgrade's (shoot-down comes on top)")
	assert_between(reaper_mean, 1.3, 1.7, "Reaper Swarm, on average, is about 1.5 times the upgrade")
	for ratio in guardian_ratios + reaper_ratios:
		assert_between(ratio, 1.05, 2.0, "No scenario is far from the mean")

## Hero health lost to bolts from a Kite 4.5 m away (one every 1.5 s) over `seconds`, for a bay of this path with the hero standing still.
func _bolt_damage(path: Array[String], seconds: float) -> float:
	rig = TurretTestRig.start(self)
	rig.disable_crits()
	world = rig.world
	swarm = world.drones
	for starting in world.turrets:
		starting.position = Vector3(24, 0, 16)
	world.player.position = Vector3.ZERO
	var bay := _bay(path, Vector3(3, 0, 0))
	rig.level_to(bay, 10)
	var shooter := _dummy(Vector3(0, 0, -4.5), "kite")
	rig.combat()
	var health: float = world.player.health
	var clock := 0.0
	var shots: Array[EnemyOrdnance] = []
	for i in roundi(seconds / STEP):
		clock -= STEP
		if clock <= 0.0:
			clock += 1.5
			var shot := EnemyOrdnance.launch(shooter, "bolt", shooter.position, world.player.position, 5.0)
			shot.world = world
			world.add_child(shot)
			shots.append(shot)
		for shot in shots:
			if is_instance_valid(shot) and not shot.is_queued_for_deletion():
				shot._physics_process(STEP)
		world.player.invulnerability = 0.0
		_step(bay)
	var lost := health - world.player.health
	for shot in shots:
		if is_instance_valid(shot):
			shot.queue_free()
	swarm.clear()
	return lost

func test_guardian_wing_keeps_the_hero_clear_of_a_kites_bolts_where_the_escort_cannot() -> void:
	var escort := _bolt_damage(["escort_drones"], 24.0)
	var guardian := _bolt_damage(["escort_drones", "guardian_wing"], 24.0)
	gut.p("Hero health lost to sixteen bolts: Escort %.0f, Guardian %.0f" % [escort, guardian])
	assert_gt(escort, 10.0, "The escort lets them through")
	assert_lt(guardian, escort * .25, "The wing stops nearly all of them")

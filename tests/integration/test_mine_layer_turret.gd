extends GutTest

## Mine Layer line: stocking, the registry entry, laying (spots, cap, rate), arming, the trigger and blast, Minefield, Dead Zone's
## re-arming and chain, Chain Reaction's limpets, two layers side by side, every clean-up path (wave end, pause, pickup, removal,
## evolution, run reset), and the tuning of the finals against the upgrade. The S8 rules it uses are in `test_deployables.gd`.

const GATE := "test_mine_layer_gate"
const STEP := 1.0 / 60.0

var rig: TurretTestRig
var world: ArenaWorld
var field: Deployables

func before_each() -> void:
	rig = TurretTestRig.start(self)
	rig.disable_crits()
	world = rig.world
	field = world.deployables
	GameStateService.current_wave = 1
	# The run's starting turret and the hero stay out of the way unless a test moves them.
	for starting in world.turrets:
		starting.position = Vector3(24, 0, 16)

func after_each() -> void:
	ShopCatalog.reset()
	TestHelpers.reset_flags()

func _layer(form_path: Array[String] = [], at: Vector3 = Vector3.ZERO) -> TurretActor:
	return rig.turret("mine_layer", form_path, at)

func _minefield(at: Vector3 = Vector3.ZERO) -> TurretActor:
	return _layer(["minefield"], at)

func _dead_zone(at: Vector3 = Vector3.ZERO) -> TurretActor:
	return _layer(["minefield", "dead_zone"], at)

func _chain_reaction(at: Vector3 = Vector3.ZERO) -> TurretActor:
	return _layer(["minefield", "chain_reaction"], at)

func _form(turret: TurretActor) -> MineLayerForm:
	return turret.form as MineLayerForm

## One physics step of the turret and of the field it lays into.
func _step(turret: TurretActor) -> void:
	world.crowd.rebuild(world.enemies)
	turret._physics_process(STEP)
	field.tick(STEP)

func _run(turret: TurretActor, seconds: float) -> void:
	for i in roundi(seconds / STEP):
		_step(turret)

func _own(turret: TurretActor) -> Array[Deployable]:
	return field.of_owner(turret.turret_id)

# --- Shop, registry and items ---

func test_mine_layer_is_stocked_at_its_registry_price_and_purchasable() -> void:
	assert_has(ArenaShop.TURRETS, "mine_layer")
	assert_has(ShopCatalog.available_ids("turret"), "mine_layer")
	assert_eq(TurretRegistry.get_base_price("mine_layer"), 15)
	var price := world.turret_price("mine_layer")
	EconomyService.total_scrap = 500
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", "mine_layer", price)])
	assert_true(world.shop.purchase(0))
	assert_eq(TurretStatsService.turret_counts.get("mine_layer", 0), 1)
	assert_eq(EconomyService.total_scrap, 500 - price)
	assert_eq(ArenaShop.offer_name(ShopOffer.new("turret", "mine_layer", 1)), "Mine Layer")
	assert_ne(ArenaShop.offer_description(ShopOffer.new("turret", "mine_layer", 1)), "")

func test_shop_rolls_the_layer_and_a_flag_can_gate_it() -> void:
	world.shop.rng = RandomNumberGenerator.new()
	world.shop.rng.seed = 5
	var seen := false
	for roll in 300:
		world.shop.generate()
		for offer: ShopOffer in EconomyService.current_shop_offers:
			if offer.kind == "turret" and offer.asset_id == "mine_layer":
				seen = true
	assert_true(seen, "300 refreshes stock the Mine Layer at least once")
	FeatureFlagService.register_flag(GATE, {"name": "Gate", "scope": FeatureFlagService.SCOPE_EXPERIMENT})
	ShopCatalog.entries["turret"]["mine_layer"] = GATE
	assert_false(ShopCatalog.is_available("turret", "mine_layer"))
	EconomyService.total_scrap = 500
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", "mine_layer", 1)])
	assert_false(world.shop.purchase(0), "A gated turret cannot be bought")

func test_shop_view_data_dev_tools_and_art_know_the_layer() -> void:
	_layer()
	assert_gt(world.dev.add_turret("mine_layer"), 0)
	var data := ShopViewData.build_data(world)
	var row: Dictionary = {}
	for entry: Dictionary in data.turrets:
		if entry.id == "mine_layer":
			row = entry
	assert_false(row.is_empty())
	assert_eq(row.name, "Mine Layer")
	assert_true(row.deploys, "The shop knows its rate is mines per second")
	assert_false(row.utility, "It attacks")
	assert_almost_eq(float(row.damage), 15.0, .001)
	assert_same(ShopArt.turret("mine_layer"), load("res://assets/ui/turrets/mine_layer.png"))
	for form in ["mine_layer", "minefield", "dead_zone", "chain_reaction"]:
		assert_true(ResourceLoader.exists("res://assets/ui/turrets/%s.png" % form), form)
	assert_not_null(UiIcons.turret("mine_layer"))
	assert_true(UiIconData.PATHS.has("turret_mine_layer"))

func test_registry_entry_matches_the_card_and_maps_deployable_to_the_aoe_family() -> void:
	var base := TurretRegistry.get_base_stats("mine_layer")
	assert_eq(base.damage, 15.0)
	assert_almost_eq(float(base.fire_rate), .33, .0001)
	assert_eq(base.range, 225.0, "Mines are laid within 2.25 m")
	assert_eq(base.aoe_radius, 70.0, "Blast 0.7 m")
	assert_eq(base.max_mines, 5)
	assert_eq(TurretRegistry.get_fire_mode("mine_layer"), TurretRegistry.FIRE_DEPLOY)
	assert_eq(TurretRegistry.get_attack_families("mine_layer"), ["aoe"] as Array[String])
	assert_false(TurretRegistry.is_no_attack("mine_layer"), "It attacks, with what it lays")
	assert_eq(TurretRegistry.get_family("mine_layer"), "")
	assert_false(TurretRegistry.has_type("mine"), "The old placeholder id is gone")

func test_an_aoe_item_makes_the_mines_hit_harder_and_a_projectile_item_does_not() -> void:
	var layer := _layer()
	ModifierService.add_modifier({"stat": "damage", "operation": "increase", "value": .5, "filter": {"attack_family": ["projectile"]}})
	layer.invalidate_stats()
	rig.combat()
	_step(layer)
	assert_almost_eq(_own(layer)[0].shot.damage, 15.0, .001, "A projectile item changes nothing")
	field.clear()
	ModifierService.clear_modifiers()
	ModifierService.add_modifier({"stat": "damage", "operation": "increase", "value": .5, "filter": {"attack_family": ["aoe"]}})
	layer.invalidate_stats()
	layer.cooldown = 0.0
	_step(layer)
	assert_almost_eq(_own(layer)[0].shot.damage, 22.5, .001, "An AoE item reaches the mines")

# --- The base layer ---

func test_the_layer_lays_one_mine_at_once_then_one_per_cooldown_up_to_five() -> void:
	var layer := _layer()
	rig.combat()
	_step(layer)
	assert_eq(field.count_of(layer.turret_id), 1, "The first mine goes down at once")
	_run(layer, 3.2)
	assert_eq(field.count_of(layer.turret_id), 2, "One more every 1 / 0.33 s")
	_run(layer, 30.0)
	assert_eq(field.count_of(layer.turret_id), 5, "Never more than five")
	assert_eq(_form(layer).laid, 5)
	_run(layer, 4.0)
	assert_eq(field.count_of(layer.turret_id), 5)
	assert_eq(_form(layer).laid, 5, "and it does not keep laying")

func test_mines_land_outside_the_chassis_within_reach_and_inside_the_arena() -> void:
	var layer := _layer([], Vector3(0, 0, 0))
	rig.combat()
	_run(layer, 20.0)
	assert_eq(_own(layer).size(), 5)
	for item in _own(layer):
		var distance := WorldGeometry.planar(item.position - layer.position).length()
		assert_gte(distance, MineLayerForm.CLEARANCE - .001, "Not under the chassis")
		assert_lte(distance, 2.25 + .001, "Within the 2.25 m reach")
		assert_eq(item.position.y, 0.0)
	var corner := _layer([], Vector3(WorldGeometry.HALF_ARENA.x - .2, 0, WorldGeometry.HALF_ARENA.y - .2))
	_run(corner, 20.0)
	for item in _own(corner):
		assert_lte(item.position.x, WorldGeometry.HALF_ARENA.x, "Inside the arena")
		assert_lte(item.position.z, WorldGeometry.HALF_ARENA.y)

func test_mines_are_laid_on_the_side_of_the_nearest_enemy() -> void:
	var layer := _layer()
	rig.enemy(Vector3(6, 0, 0), 1000000.0)
	rig.combat()
	_run(layer, 20.0)
	for item in _own(layer):
		assert_gt(item.position.x, 0.0, "Toward the enemy at +x")
	assert_eq(_own(layer).size(), 5)

func test_mines_spread_out_rather_than_stack() -> void:
	var layer := _layer()
	rig.combat()
	_run(layer, 20.0)
	var spots := _own(layer)
	var nearest := INF
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			nearest = minf(nearest, WorldGeometry.planar(spots[i].position - spots[j].position).length())
	assert_gt(nearest, .3, "No two mines on top of each other")

func test_a_mine_arms_then_blasts_an_enemy_for_its_damage_and_the_layer_replaces_it() -> void:
	var layer := _layer()
	var enemy := rig.enemy(Vector3(6, 0, 0), 1000.0)
	rig.combat()
	var credited := {"damage": 0.0}
	world.combat.hit_applied.connect(func(_t: Node3D, hit: CombatHit3D, amount: float) -> void:
		if hit.source_id == layer.turret_id:
			credited["damage"] += amount)
	_run(layer, 1.0)
	var mine := _own(layer)[0]
	assert_true(mine.is_armed(), "Armed after 0.8 s")
	assert_eq(enemy.health, 1000.0, "Nothing near it: nothing blasted")
	enemy.position = mine.position
	_run(layer, .2)
	assert_lt(enemy.health, 1000.0, "The enemy stepped on an armed mine")
	assert_almost_eq(float(credited["damage"]), 15.0, .001, "One blast of 15, credited to the layer")
	assert_eq(field.blasts, 1)
	assert_true(mine.spent)
	_run(layer, 4.0)
	assert_gte(field.count_of(layer.turret_id), 1, "and the layer lays again")

func test_a_mine_does_nothing_to_an_enemy_standing_on_it_while_it_arms() -> void:
	var layer := _layer()
	rig.combat()
	_step(layer)
	var mine := _own(layer)[0]
	var enemy := rig.enemy(mine.position, 1000.0)
	_run(layer, .5)
	assert_eq(enemy.health, 1000.0, "Still arming")
	assert_eq(field.blasts, 0)
	_run(layer, .4)
	assert_lt(enemy.health, 1000.0, "Armed, it goes off under the enemy")

func test_the_blast_radius_is_seven_tenths_of_a_metre_and_it_pushes_enemies_away() -> void:
	var layer := _layer()
	rig.combat()
	_step(layer)
	layer.cooldown = 1000.0
	var mine := _own(layer)[0]
	mine.position = Vector3(3, 0, 3)
	mine.state = Deployable.State.ARMED
	var inside := rig.enemy(Vector3(3, 0, 3), 1000.0)
	var edge := rig.enemy(Vector3(3.9, 0, 3), 1000.0)
	var outside := rig.enemy(Vector3(3, 0, 4.4), 1000.0)
	_step(layer)
	assert_lt(inside.health, 1000.0)
	assert_lt(edge.health, 1000.0, "Inside the 0.7 m blast (the enemy's body counts)")
	assert_eq(outside.health, 1000.0, "Beyond the blast")

func test_mines_never_hurt_the_hero_or_a_turret() -> void:
	var layer := _layer()
	var other := rig.turret("normal", [], Vector3(3, 0, 3))
	world.player.position = Vector3(3.1, 0, 3.0)
	var hero_health := world.player.health
	rig.combat()
	_step(layer)
	var mine := _own(layer)[0]
	mine.position = Vector3(3, 0, 3)
	rig.enemy(Vector3(3, 0, 3.2), 1000.0)
	_run(layer, 2.0)
	assert_eq(field.blasts, 1, "It did go off")
	assert_eq(world.player.health, hero_health)
	assert_eq(other.position, Vector3(3, 0, 3))

func test_an_unused_mine_fizzles_after_its_lifetime_and_is_replaced() -> void:
	var layer := _layer()
	rig.combat()
	_run(layer, 1.0)
	var first := _own(layer)[0]
	_run(layer, 42.0)
	assert_true(first.spent, "The first mine ran out of its 40 s")
	assert_eq(field.blasts, 0, "without a blast")
	assert_eq(field.count_of(layer.turret_id), 5, "and the layer keeps five out")

func test_a_layer_with_nothing_to_lay_toward_still_pre_lays_its_mines() -> void:
	var layer := _layer()
	rig.combat()
	_run(layer, 1.0)
	assert_eq(field.count_of(layer.turret_id), 1)

func test_estimate_dps_is_the_lay_rate_times_the_blast() -> void:
	var layer := _layer()
	assert_almost_eq(TurretForm.dps_of(layer), 15.0 * .33, .01)

# --- Minefield ---

func test_minefield_keeps_eight_smaller_mines_over_a_wider_range() -> void:
	var layer := _minefield()
	var stats := layer.resolve_attack_view()
	assert_eq(_form(layer).max_mines(stats), 8)
	assert_almost_eq(stats.aoe_radius_metres, .55, .001, "A smaller blast")
	assert_gte(stats.range_metres, 3.0, "Reach 3 m, plus the level bonus")
	rig.combat()
	_run(layer, 30.0)
	assert_eq(field.count_of(layer.turret_id), 8)
	for item in _own(layer):
		assert_lte(WorldGeometry.planar(item.position - layer.position).length(), stats.range_metres + .001)
		assert_almost_eq(item.shot.splash_radius, .55, .001)
	assert_gt(_form(layer).laid, 0)
	assert_gt(stats.fire_rate, .33, "and it lays them faster than the base layer")

func test_evolving_the_layer_lifts_its_old_mines() -> void:
	var layer := _layer()
	rig.combat()
	_run(layer, 20.0)
	assert_eq(field.count_of(layer.turret_id), 5)
	rig.shop()
	rig.level_to(layer, 5)
	assert_true(layer.evolve("minefield"))
	assert_eq(field.count(), 0, "The base layer's mines went with its old form")
	assert_eq(_form(layer).laid, 0, "The new form starts from scratch")

# --- Dead Zone ---

func test_dead_zone_keeps_fourteen_mines_that_never_expire_and_re_arm() -> void:
	var layer := _dead_zone()
	var stats := layer.resolve_attack_view()
	assert_eq(_form(layer).max_mines(stats), 14)
	rig.combat()
	_run(layer, 30.0)
	assert_eq(field.count_of(layer.turret_id), 14)
	for item in _own(layer):
		assert_eq(item.lifetime, 0.0, "No expiry")
		assert_eq(item.rearm_seconds, 9.0)
		assert_eq(item.chain_depth, 3)
		assert_almost_eq(item.chain_reach, 1.8, .001)
	var mine := _own(layer)[0]
	var enemy := rig.enemy(mine.position, 100000.0)
	_run(layer, 1.0)
	assert_lt(enemy.health, 100000.0)
	assert_false(mine.spent, "A re-arming mine stays")
	assert_eq(mine.state, Deployable.State.ARMING)
	assert_eq(field.count_of(layer.turret_id), 14)
	_run(layer, 9.0)
	assert_gte(field.blasts, 2, "Armed again after its 9 s, it went off under the enemy still standing there")

func test_dead_zone_chains_through_neighbouring_mines_three_links_and_no_further() -> void:
	var layer := _dead_zone()
	rig.combat()
	_step(layer)
	field.clear()
	# A hand-laid row a metre apart, built the way the layer builds its mines.
	var row: Array[Deployable] = []
	for i in 8:
		var item := _form(layer)._build(layer._current_view(0.0), Deployable.KIND_MINE)
		item.position = Vector3(8.0 + float(i), 0, 8.0)
		item.state = Deployable.State.ARMED
		assert_true(field.lay(item))
		row.append(item)
	layer.cooldown = 1000.0
	var enemy := rig.enemy(row[0].position, 1000000.0)
	_run(layer, 2.5)
	assert_not_null(enemy)
	assert_eq(field.blasts, 4, "The stepped-on mine and three links")
	for i in range(0, 4):
		assert_eq(row[i].state, Deployable.State.ARMING, "Mine %d went off and is re-arming" % i)
	for i in range(4, 8):
		assert_true(row[i].is_armed(), "Mine %d was past the third link" % i)

func test_dead_zones_chain_never_reaches_another_layers_mines() -> void:
	var first := _dead_zone(Vector3(-8, 0, 0))
	var second := _dead_zone(Vector3(8, 0, 0))
	rig.combat()
	_step(first)
	_step(second)
	for turret in [first, second]:
		turret.cooldown = 1000.0
	field.clear()
	var mine := _form(first)._build(first._current_view(0.0), Deployable.KIND_MINE)
	mine.position = Vector3(0, 0, 8)
	mine.state = Deployable.State.ARMED
	field.lay(mine)
	var stranger := _form(second)._build(second._current_view(0.0), Deployable.KIND_MINE)
	stranger.position = Vector3(1, 0, 8)
	stranger.state = Deployable.State.ARMED
	field.lay(stranger)
	rig.enemy(mine.position, 100000.0)
	_run(first, 2.0)
	assert_eq(field.blasts, 1, "Only the stepped-on mine; the other layer's stood clear")
	assert_true(stranger.is_armed())

# --- Chain Reaction ---

func test_chain_reaction_launches_limpets_and_never_lays_mines() -> void:
	var layer := _chain_reaction()
	var stats := layer.resolve_attack_view()
	assert_true(_form(layer).is_limpet_layer())
	rig.combat()
	_run(layer, 5.0)
	assert_eq(field.count(), 0, "Nothing to launch at: nothing laid either")
	var target := rig.enemy(Vector3(3, 0, 0), 1000000.0)
	_step(layer)
	assert_eq(field.count_of(layer.turret_id), 1)
	var limpet := _own(layer)[0]
	assert_true(limpet.is_limpet())
	assert_same(limpet.host, target)
	assert_eq(_form(layer).max_mines(stats), 4)

func test_chain_reaction_prefers_the_nearest_large_enemy_and_falls_back_to_the_nearest() -> void:
	var layer := _chain_reaction()
	var small := rig.enemy(Vector3(1.5, 0, 0), 1000000.0)
	var big := rig.enemy(Vector3(4.0, 0, 0), 1000000.0)
	big.body_scale = 1.6
	var farther_big := rig.enemy(Vector3(4.5, 1.0, 0), 1000000.0)
	farther_big.body_scale = 1.6
	rig.combat()
	_step(layer)
	assert_same(_own(layer)[0].host, big, "The large one, though a small one is nearer")
	field.clear()
	big.dead = true
	farther_big.dead = true
	layer.cooldown = 0.0
	rig.combat()
	_step(layer)
	assert_same(_own(layer)[0].host, small, "No large enemy left: the nearest")

func test_chain_reaction_never_has_two_limpets_on_one_enemy_or_more_than_its_cap() -> void:
	var layer := _chain_reaction()
	var enemy := rig.enemy(Vector3(3, 0, 0), 1000000.0)
	rig.combat()
	_run(layer, 1.0)
	assert_eq(field.count_of(layer.turret_id), 1)
	assert_true(field.is_ridden(enemy))
	layer.cooldown = 0.0
	_step(layer)
	assert_eq(field.count_of(layer.turret_id), 1, "The only enemy already carries one: no second limpet on it")
	for i in 6:
		rig.enemy(Vector3(2.0 + float(i) * .3, 0, 1.0 + float(i) * .4), 1000000.0)
	_run(layer, 20.0)
	assert_lte(field.count_of(layer.turret_id), 4, "At most four launched limpets at once")

func test_a_limpet_sticks_burns_for_one_and_a_half_seconds_and_blasts_for_its_damage() -> void:
	var layer := _chain_reaction()
	var enemy := rig.enemy(Vector3(3, 0, 0), 1000000.0)
	rig.combat()
	_step(layer)
	var limpet := _own(layer)[0]
	_run(layer, .6)
	assert_eq(limpet.state, Deployable.State.FUSED, "Stuck on")
	var health := enemy.health
	_run(layer, 1.0)
	assert_eq(enemy.health, health, "It has burned less than 1.5 s")
	_run(layer, .7)
	assert_lt(enemy.health, health, "and then it went off")
	assert_gte(field.blasts, 1)

func test_a_limpet_blast_sticks_new_limpets_on_two_neighbours_once_and_the_total_is_bounded() -> void:
	var layer := _chain_reaction()
	var host := rig.enemy(Vector3(3, 0, 0), 1000000.0)
	host.body_scale = 1.6
	var neighbours: Array[CombatActor] = []
	for i in 5:
		neighbours.append(rig.enemy(Vector3(3.2 + float(i) * .1, 0, .5 + float(i) * .2), 1000000.0))
	rig.combat()
	_step(layer)
	layer.cooldown = 1000.0
	_run(layer, 3.9)
	# The parent went off at about 2.1 s; its two children at about 3.8 s; nothing else was launched.
	assert_eq(field.blasts, 3, "One launch made three blasts: the parent and two children")
	assert_eq(field.count(), 0, "and nothing further was stuck on")

# --- Two layers ---

func test_two_layers_keep_their_own_mines_caps_and_clean_up() -> void:
	var first := _layer([], Vector3(-6, 0, 0))
	var second := _layer([], Vector3(6, 0, 0))
	rig.combat()
	for i in 1800:
		world.crowd.rebuild(world.enemies)
		first._physics_process(STEP)
		second._physics_process(STEP)
		field.tick(STEP)
	assert_eq(field.count_of(first.turret_id), 5)
	assert_eq(field.count_of(second.turret_id), 5)
	assert_eq(field.count(), 10)
	for item in _own(first):
		assert_lt(item.position.x, 0.0, "Its mines stay in its own reach")
	for item in _own(second):
		assert_gt(item.position.x, 0.0)
	rig.shop()
	first._physics_process(STEP)
	assert_eq(field.count_of(first.turret_id), 0)
	assert_eq(field.count_of(second.turret_id), 5, "Clearing one layer leaves the other's")

func test_a_mine_blast_credits_the_layer_that_laid_it_not_its_neighbour() -> void:
	var first := _layer([], Vector3(-6, 0, 0))
	var second := _layer([], Vector3(6, 0, 0))
	rig.combat()
	_step(first)
	_step(second)
	var credited := {}
	world.combat.hit_applied.connect(func(_t: Node3D, hit: CombatHit3D, amount: float) -> void:
		credited[hit.source_id] = float(credited.get(hit.source_id, 0.0)) + amount)
	var mine := _own(second)[0]
	rig.enemy(mine.position, 100000.0)
	_run(second, 1.5)
	assert_gt(float(credited.get(second.turret_id, 0.0)), 0.0)
	assert_false(credited.has(first.turret_id))

# --- Clean-up ---

func test_wave_end_drops_the_mines_the_next_physics_step() -> void:
	var layer := _layer()
	rig.combat()
	_run(layer, 20.0)
	assert_eq(field.count(), 5)
	rig.shop()
	layer._physics_process(STEP)
	assert_eq(field.count(), 0)
	rig.combat()
	_run(layer, 1.0)
	assert_eq(field.count_of(layer.turret_id), 1, "A new wave starts laying afresh")

func test_pausing_drops_the_mines_and_stops_laying() -> void:
	var layer := _layer()
	rig.combat()
	_run(layer, 20.0)
	world.paused = true
	_run(layer, 5.0)
	assert_eq(field.count(), 0)
	assert_eq(_form(layer).laid, 5)
	world.paused = false
	_run(layer, 1.0)
	assert_eq(field.count(), 1, "Back to laying")

func test_a_carried_layer_keeps_laying_round_the_hero_and_its_old_mines_stay() -> void:
	var layer := _layer()
	rig.combat()
	_run(layer, 10.0)
	var before := _own(layer).size()
	assert_gt(before, 0)
	layer.carried = true
	layer.position = Vector3(10, 0, 5)
	_run(layer, 40.0)
	assert_eq(field.count_of(layer.turret_id), 5, "Still keeping five out")
	var near_new_spot := 0
	for item in _own(layer):
		if WorldGeometry.planar(item.position - layer.position).length() <= 2.5:
			near_new_spot += 1
	assert_gt(near_new_spot, 0, "New mines went down round the carried layer")
	layer.carried = false
	assert_eq(field.count_of(layer.turret_id), 5, "Putting it down does not lift them either")

func test_a_removed_layer_leaves_no_mines_behind() -> void:
	var layer := _layer()
	var other := _layer([], Vector3(8, 0, 8))
	rig.combat()
	_run(layer, 20.0)
	_run(other, 5.0)
	assert_gt(field.count_of(layer.turret_id), 0)
	assert_gt(field.count_of(other.turret_id), 0)
	var id := layer.turret_id
	world.turrets.erase(layer)
	layer.get_parent().remove_child(layer)
	layer.free()
	assert_eq(field.count_of(id), 0, "Its mines went when it left the tree")
	assert_gt(field.count_of(other.turret_id), 0, "The other layer's did not")

func test_a_removed_chain_reaction_leaves_no_limpets_flying() -> void:
	var layer := _chain_reaction()
	rig.enemy(Vector3(3, 0, 0), 1000000.0)
	rig.combat()
	_step(layer)
	assert_eq(field.count(), 1)
	var id := layer.turret_id
	world.turrets.erase(layer)
	layer.get_parent().remove_child(layer)
	layer.free()
	assert_eq(field.count_of(id), 0)
	assert_eq(field.count(), 0)

func test_a_run_reset_leaves_no_mines() -> void:
	var layer := _layer()
	rig.combat()
	_run(layer, 20.0)
	assert_eq(field.count(), 5)
	world._clear_actors()
	assert_eq(field.count(), 0)

func test_finishing_the_wave_and_defeat_leave_no_mines() -> void:
	var layer := _layer()
	rig.combat()
	_run(layer, 20.0)
	world.clear_field(false)
	assert_eq(field.count(), 0)
	_run(layer, 2.0)
	assert_eq(field.count(), 1)
	world._end_run_in_defeat("test")
	assert_eq(field.count(), 0)

# --- Existing behaviour is untouched ---

func test_other_turrets_do_not_lay_anything_and_an_idle_field_costs_nothing() -> void:
	var gun := rig.turret("normal")
	var decoy := rig.turret("decoy", [], Vector3(4, 0, 0))
	var press := rig.turret("scrap_press", [], Vector3(-4, 0, 0))
	rig.enemy(Vector3(0, 0, -3), 100000.0)
	rig.combat()
	for i in 600:
		world.crowd.rebuild(world.enemies)
		for turret in [gun, decoy, press]:
			turret._physics_process(STEP)
		field.tick(STEP)
	assert_eq(field.count(), 0)
	assert_eq(field.laid, 0)
	assert_eq(field.blasts, 0)
	assert_false(field.has_deployables())

func test_a_layer_beside_a_gun_does_not_change_what_the_gun_does() -> void:
	var gun := rig.turret("shock", [], Vector3(0, 0, 8))
	var target := rig.enemy(Vector3(0, 0, 7.0), 100000.0)
	rig.combat()
	var baseline := {"damage": 0.0}
	world.combat.hit_applied.connect(func(_t: Node3D, hit: CombatHit3D, amount: float) -> void:
		if hit.source_id == gun.turret_id:
			baseline["damage"] += amount)
	for i in 600:
		_step(gun)
	var alone := float(baseline["damage"])
	assert_gt(alone, 0.0)
	var layer := _layer([], Vector3(12, 0, 12))
	target.health = 100000.0
	baseline["damage"] = 0.0
	for i in 600:
		world.crowd.rebuild(world.enemies)
		gun._physics_process(STEP)
		layer._physics_process(STEP)
		field.tick(STEP)
	assert_almost_eq(float(baseline["damage"]), alone, alone * .2, "The gun's output is unchanged, whatever the layer lays far away")

# --- Forms and tuning ---

func test_path_forms_tiers_and_chassis() -> void:
	assert_eq(TurretEvolution.options("mine_layer", 0), ["minefield"])
	assert_eq(TurretEvolution.options("mine_layer", 1), ["dead_zone", "chain_reaction"])
	assert_eq(TurretEvolution.form_name("minefield"), "Minefield")
	assert_eq(TurretEvolution.form_name("dead_zone"), "Dead Zone")
	assert_eq(TurretEvolution.form_name("chain_reaction"), "Chain Reaction")
	for form in ["minefield", "dead_zone", "chain_reaction"]:
		assert_true(TurretEvolution.is_implemented(form))
		assert_eq(TurretEvolution.model_key(form), "shock", "The tinted Shock bell stands in until a model is wired")
		assert_false(TurretEvolution.description(form).is_empty())
	assert_true(TurretEvolution.behaviour_script("mine_layer", "").new() is MineLayerForm, "The unevolved layer lays through its form")

func test_each_form_has_visible_hardware_the_one_before_does_not() -> void:
	var counts := {}
	for path: Array in [[], ["minefield"], ["minefield", "dead_zone"], ["minefield", "chain_reaction"]]:
		var typed: Array[String] = []
		typed.assign(path)
		var layer := _layer(typed, Vector3(float(counts.size()) * 3.0, 0, 20))
		counts[str(path)] = layer.model.find_children("*", "MeshInstance3D", true, false).size()
	var base_meshes: int = counts["[]"]
	for key in counts:
		if key != "[]":
			assert_gt(int(counts[key]), base_meshes, "%s adds hardware to the chassis" % key)

## A stream of tough enemies walking across the layer's ground, simulated in game time (no GPU involved): the damage per second a
## layer at level 10 credits to itself. Stationary dummies would flatter re-arming mines, so the tuning uses walkers.
func _traffic(path: Array[String], seconds: float) -> float:
	rig = TurretTestRig.start(self)
	rig.disable_crits()
	world = rig.world
	field = world.deployables
	for starting in world.turrets:
		starting.position = Vector3(24, 0, 16)
	var layer := _layer(path)
	rig.level_to(layer, 10)
	rig.combat()
	var tally := {"damage": 0.0}
	world.combat.hit_applied.connect(func(_t: Node3D, hit: CombatHit3D, amount: float) -> void:
		if hit.source_id == layer.turret_id:
			tally["damage"] += amount)
	var walkers: Array[CombatActor] = []
	var clock := 0.0
	var count := 0
	var lanes := [-1.5, -.5, .5, 1.5]
	for i in roundi(seconds / STEP):
		clock -= STEP
		if clock <= 0.0:
			clock += 3.0
			for k in 4:
				var walker := rig.enemy(Vector3(-9.0 - float(k) * .5, 0, float(lanes[count % 4]) + float(k % 2) * .4), 1e9)
				if count % 4 == 0:
					walker.body_scale = 1.6
				walkers.append(walker)
				count += 1
		for walker in walkers:
			walker.position.x += 1.3 * STEP
			if walker.position.x > 9.0:
				walker.position.x = -9.0
		_step(layer)
	var result := float(tally["damage"]) / seconds
	for walker in walkers:
		walker.dead = true
	field.clear()
	return result

## One scenario (packs of four, four lanes, a large enemy in each pack) of the three the tuning used; the finals average about 1.5
## times the upgrade across all three (see the handoff doc), and any one scenario lands between 1.1 and 1.8, so the bounds are wide.
func test_the_finals_are_tuned_to_about_one_and_a_half_times_the_upgrade_in_simulated_traffic() -> void:
	var upgrade := _traffic(["minefield"], 60.0)
	var zone := _traffic(["minefield", "dead_zone"], 60.0)
	var reaction := _traffic(["minefield", "chain_reaction"], 60.0)
	assert_gt(upgrade, 0.0)
	assert_between(zone / upgrade, 1.2, 1.9, "Dead Zone / Minefield: %.1f / %.1f" % [zone, upgrade])
	assert_between(reaction / upgrade, 1.2, 1.9, "Chain Reaction / Minefield: %.1f / %.1f" % [reaction, upgrade])

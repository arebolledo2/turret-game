extends GutTest

## Engine piece S8, `Deployables`: laying, arming, the trigger, the blast, chaining, re-arming, limpets, lifetime, the caps and every
## clean-up path, driven without any turret (the Mine Layer that uses it is in `test_mine_layer_turret.gd`).

const STEP := 1.0 / 60.0

var rig: TurretTestRig
var world: ArenaWorld
var field: Deployables

func before_each() -> void:
	rig = TurretTestRig.start(self, true)
	rig.disable_crits()
	world = rig.world
	field = world.deployables
	# The run's starting turret and the hero stay out of the way unless a test moves them.
	for starting in world.turrets:
		starting.position = Vector3(24, 0, 16)

func after_each() -> void:
	TestHelpers.reset_flags()

func _shot(damage: float = 10.0, radius: float = 1.0) -> CombatShot3D:
	var shot := CombatShot3D.new()
	shot.damage = damage
	shot.splash_radius = radius
	shot.source_id = 7
	return shot

func _mine(at: Vector3, owner_id: int = 1, damage: float = 10.0, radius: float = 1.0) -> Deployable:
	var item := Deployable.new()
	item.owner_id = owner_id
	item.position = at
	item.shot = _shot(damage, radius)
	item.arm_seconds = .5
	item.trigger_radius = .4
	assert_true(field.lay(item), "The mine is laid")
	return item

func _limpet(host: CombatActor, owner_id: int = 1, sticks: int = 0) -> Deployable:
	var item := Deployable.new()
	item.kind = Deployable.KIND_LIMPET
	item.state = Deployable.State.FLYING
	item.owner_id = owner_id
	item.position = Vector3(host.position.x + 3.0, 0, host.position.z)
	item.shot = _shot(10.0, 1.2)
	item.host = host
	item.fuse_seconds = 1.5
	item.stick_count = sticks
	assert_true(field.lay(item))
	return item

func _tick(seconds: float) -> void:
	for i in roundi(seconds / STEP):
		world.crowd.rebuild(world.enemies)
		field.tick(STEP)

func _hp(enemy: CombatActor) -> float:
	return enemy.health

# --- Laying, arming, the trigger and the blast ---

func test_a_mine_is_harmless_while_it_arms_and_goes_off_once_armed() -> void:
	var enemy := rig.enemy(Vector3(2, 0, 2), 100.0)
	var mine := _mine(Vector3(2, 0, 2))
	assert_eq(mine.state, Deployable.State.ARMING)
	assert_eq(field.count_of(1), 1)
	_tick(.3)
	assert_eq(_hp(enemy), 100.0, "An arming mine does nothing")
	assert_eq(field.count(), 1)
	_tick(.4)
	assert_eq(_hp(enemy), 90.0, "Once armed it goes off under the enemy")
	assert_eq(field.count(), 0, "A one-shot mine is gone after its blast")
	assert_eq(field.count_of(1), 0)
	assert_eq(field.blasts, 1)

func test_an_enemy_outside_the_trigger_leaves_the_mine_alone() -> void:
	var enemy := rig.enemy(Vector3(2, 0, 2), 100.0)
	var mine := _mine(Vector3(2.0 + .4 + enemy.hurtbox_radius() + .3, 0, 2))
	_tick(1.0)
	assert_eq(mine.state, Deployable.State.ARMED, "Armed and waiting")
	assert_eq(_hp(enemy), 100.0)
	enemy.position.x += .5
	_tick(.1)
	assert_eq(_hp(enemy), 90.0, "Close enough: it goes off")

func test_the_blast_hits_enemies_in_its_radius_and_never_the_hero_or_turrets() -> void:
	var near := rig.enemy(Vector3(2.5, 0, 2), 100.0)
	var far := rig.enemy(Vector3(4.5, 0, 2), 100.0)
	var turret := rig.turret("normal", [], Vector3(2.6, 0, 2.2))
	world.player.position = Vector3(2.4, 0, 1.9)
	var hero_health := world.player.health
	var turret_at := turret.position
	_mine(Vector3(2, 0, 2), 1, 10.0, 1.0)
	_tick(1.0)
	assert_eq(_hp(near), 90.0)
	assert_eq(_hp(far), 100.0, "Outside the blast radius")
	assert_eq(world.player.health, hero_health, "A mine never hurts the hero")
	assert_true(is_instance_valid(turret))
	assert_eq(turret.position, turret_at, "A mine never touches a turret (no shove either)")

func test_a_blast_carries_the_laying_turrets_attribution() -> void:
	rig.enemy(Vector3(2, 0, 2), 100.0)
	var credited: Array[int] = []
	world.combat.hit_applied.connect(func(_target: Node3D, hit: CombatHit3D, _amount: float) -> void: credited.append(hit.source_id))
	_mine(Vector3(2, 0, 2))
	_tick(1.0)
	assert_eq(credited, [7] as Array[int])

# --- Lifetime and re-arming ---

func test_a_mine_that_outlives_its_lifetime_fizzles_without_a_blast() -> void:
	var enemy := rig.enemy(Vector3(9, 0, 9), 100.0)
	var mine := _mine(Vector3(2, 0, 2))
	mine.lifetime = 2.0
	_tick(1.9)
	assert_eq(field.count(), 1)
	_tick(.3)
	assert_eq(field.count(), 0, "It ran out")
	assert_eq(field.blasts, 0, "and did not go off")
	assert_eq(_hp(enemy), 100.0)

func test_a_re_arming_mine_stays_dark_then_goes_off_again() -> void:
	var enemy := rig.enemy(Vector3(2, 0, 2), 1000.0)
	var mine := _mine(Vector3(2, 0, 2))
	mine.rearm_seconds = 2.0
	_tick(.6)
	assert_eq(_hp(enemy), 990.0, "First blast")
	assert_eq(field.count(), 1, "It stays")
	assert_eq(mine.state, Deployable.State.ARMING)
	_tick(1.4)
	assert_eq(_hp(enemy), 990.0, "Dark while it re-arms")
	_tick(1.4)
	assert_eq(_hp(enemy), 980.0, "Armed again and the enemy is still on it")
	assert_eq(field.count_of(1), 1)

# --- Caps ---

func test_the_arena_wide_cap_refuses_a_mine_and_never_pushes_one_out() -> void:
	for i in GameConstants.DEPLOYABLE_MAX:
		_mine(Vector3(float(i % 12) - 6.0, 0, float(i / 12) * 1.5), 1 + i % 3)
	assert_eq(field.count(), GameConstants.DEPLOYABLE_MAX)
	var extra := Deployable.new()
	extra.shot = _shot()
	extra.owner_id = 9
	assert_false(field.lay(extra), "The arena is full")
	assert_eq(field.count(), GameConstants.DEPLOYABLE_MAX)
	assert_eq(field.count_of(9), 0)
	assert_lte(field.nodes.size(), GameConstants.DEPLOYABLE_MAX, "The pooled visuals never exceed the cap")
	field.clear_owner(1)
	assert_lt(field.count(), GameConstants.DEPLOYABLE_MAX)
	assert_true(field.lay(extra), "Room again")

func test_visuals_are_pooled_and_reused() -> void:
	for round in 3:
		for i in 6:
			_mine(Vector3(float(i), 0, 0))
		field.clear()
	assert_eq(field.nodes.size(), 6, "Six nodes built once and reused")
	for node in field.nodes:
		assert_false(node.visible, "Hidden when idle")

func test_counts_are_per_owner() -> void:
	_mine(Vector3(0, 0, 0), 1)
	_mine(Vector3(1, 0, 0), 1)
	_mine(Vector3(2, 0, 0), 2)
	assert_eq(field.count_of(1), 2)
	assert_eq(field.count_of(2), 1)
	assert_eq(field.of_owner(1).size(), 2)

# --- Chaining ---

func test_a_chain_passes_along_armed_mines_to_its_depth_and_stops() -> void:
	# Ten mines a metre apart; the enemy only stands on the first. Reach 1.2 m links neighbours, depth 3 allows 3 links.
	var enemy := rig.enemy(Vector3(0, 0, 0), 1000.0)
	var line: Array[Deployable] = []
	for i in 10:
		var item := _mine(Vector3(float(i), 0, 0), 1, 10.0, .5)
		item.chain_depth = 3
		item.chain_reach = 1.2
		line.append(item)
	_tick(.6)
	_tick(1.0)
	assert_eq(field.blasts, 4, "The first mine and three links, no more")
	assert_eq(field.count(), 6, "The rest are untouched")
	for i in range(4, 10):
		assert_true(line[i].is_armed(), "Mine %d was out of the chain" % i)
	assert_eq(_hp(enemy), 990.0)

func test_a_chain_ripples_over_time_instead_of_all_at_once() -> void:
	rig.enemy(Vector3(0, 0, 0), 1000.0)
	for i in 4:
		var item := _mine(Vector3(float(i), 0, 0), 1, 10.0, .5)
		item.chain_depth = 3
		item.chain_reach = 1.2
	_tick(.55)
	assert_eq(field.blasts, 1, "Only the stepped-on mine at first")
	_tick(STEP * 3.0)
	assert_eq(field.blasts, 1, "and still, inside the chain delay")
	_tick(.1)
	assert_eq(field.blasts, 2, "Then the next, a beat later")

func test_a_chain_never_crosses_to_another_layers_mines_or_through_unarmed_ones() -> void:
	rig.enemy(Vector3(0, 0, 0), 1000.0)
	var mine := _mine(Vector3(0, 0, 0), 1)
	mine.chain_depth = 3
	mine.chain_reach = 1.5
	var stranger := _mine(Vector3(1, 0, 0), 2)
	stranger.chain_depth = 3
	stranger.chain_reach = 1.5
	_tick(.5)
	var fresh := Deployable.new()
	fresh.owner_id = 1
	fresh.position = Vector3(-1, 0, 0)
	fresh.shot = _shot()
	fresh.arm_seconds = 5.0
	field.lay(fresh)
	_tick(1.0)
	assert_eq(field.blasts, 1, "Only the stepped-on mine; the other layer's and the unarmed one stood clear")
	assert_eq(field.count(), 2)

func test_a_crowded_chain_ends_and_never_exceeds_the_per_tick_blast_budget() -> void:
	rig.enemy(Vector3(0, 0, 0), 100000.0)
	for i in GameConstants.DEPLOYABLE_MAX:
		var item := _mine(Vector3(float(i % 8) * .5, 0, float(i / 8) * .5), 1, 1.0, .5)
		item.chain_depth = 3
		item.chain_reach = 3.0
	_tick(.45)
	var most := 0
	for i in 200:
		var before := field.blasts
		_tick(STEP)
		most = maxi(most, field.blasts - before)
	assert_lte(most, Deployables.MAX_BLASTS_PER_TICK, "No tick holds more blasts than the budget")
	assert_lte(field.blasts, GameConstants.DEPLOYABLE_MAX, "Every mine goes off at most once")
	assert_eq(field.blasts + field.count(), GameConstants.DEPLOYABLE_MAX, "Each mine either went off or is still standing")
	assert_gt(field.blasts, 1, "A tight pack does chain")
	var after := field.blasts
	_tick(3.0)
	assert_eq(field.blasts, after, "and the chain is over, nothing keeps going")

# --- Limpets ---

func test_a_limpet_flies_to_its_host_rides_it_and_goes_off_after_its_fuse() -> void:
	var host := rig.enemy(Vector3(5, 0, 5), 100.0)
	var limpet := _limpet(host)
	assert_eq(limpet.state, Deployable.State.FLYING)
	assert_true(field.is_ridden(host), "Riding is tracked from the moment it is laid")
	_tick(.5)
	assert_eq(limpet.state, Deployable.State.FUSED, "Stuck on")
	host.position = Vector3(6, 0, 5)
	_tick(.1)
	assert_almost_eq(limpet.position.x, 6.0, .001, "It rides its host")
	assert_eq(_hp(host), 100.0, "Not yet")
	_tick(1.5)
	assert_eq(_hp(host), 90.0, "After 1.5 s the limpet goes off")
	assert_eq(field.count(), 0)
	assert_false(field.is_ridden(host), "and no longer rides it")

func test_a_limpet_goes_off_at_once_when_its_host_dies() -> void:
	var host := rig.enemy(Vector3(5, 0, 5), 100.0)
	var bystander := rig.enemy(Vector3(5.5, 0, 5), 100.0)
	_limpet(host)
	_tick(.5)
	host.dead = true
	_tick(STEP * 2.0)
	assert_eq(field.count(), 0, "It does not wait out the fuse")
	assert_eq(_hp(bystander), 90.0, "and its blast still lands")

func test_a_limpet_blast_sticks_new_limpets_on_up_to_two_neighbours_once() -> void:
	var host := rig.enemy(Vector3(5, 0, 5), 1000.0)
	var a := rig.enemy(Vector3(5.5, 0, 5), 1000.0)
	var b := rig.enemy(Vector3(5, 0, 5.7), 1000.0)
	var c := rig.enemy(Vector3(4.2, 0, 5), 1000.0)
	_limpet(host, 1, 2)
	_tick(2.2)
	# The host's blast has gone: two limpets are on the nearest neighbours (a and b), c is not ridden.
	assert_eq(field.count(), 2, "Two new limpets")
	assert_eq(field.count_of(1), 0, "Children do not count toward the layer's cap")
	assert_true(field.is_ridden(a))
	assert_true(field.is_ridden(b))
	assert_false(field.is_ridden(c))
	var before := field.blasts
	_tick(3.0)
	assert_eq(field.blasts - before, 2, "They go off, and that is the end: they stick nothing further")
	assert_eq(field.count(), 0)
	assert_eq(field.blasts, 3, "One launch made three blasts at most")

# --- Clean-up ---

func test_clear_owner_drops_only_that_layers_deployables() -> void:
	_mine(Vector3(0, 0, 0), 1)
	_mine(Vector3(1, 0, 0), 2)
	field.clear_owner(1)
	assert_eq(field.count_of(1), 0)
	assert_eq(field.count_of(2), 1)
	field.clear_owner(1)
	field.clear_owner(99)
	assert_eq(field.count(), 1)

func test_combat_stopping_clears_the_field_on_the_next_physics_step() -> void:
	_mine(Vector3(0, 0, 0))
	rig.shop()
	field._physics_process(STEP)
	assert_eq(field.count(), 0)
	assert_eq(field.blasts, 0, "Dropped, not detonated")

func test_pausing_clears_the_field() -> void:
	_mine(Vector3(0, 0, 0))
	world.paused = true
	field._physics_process(STEP)
	assert_eq(field.count(), 0)

func test_clear_field_and_a_new_run_clear_the_field() -> void:
	_mine(Vector3(0, 0, 0))
	world.clear_field(false)
	assert_eq(field.count(), 0)
	_mine(Vector3(0, 0, 0))
	world.start_run()
	assert_eq(world.deployables.count(), 0)

func test_defeat_clears_the_field() -> void:
	_mine(Vector3(0, 0, 0))
	world._end_run_in_defeat("test")
	assert_eq(field.count(), 0)

func test_an_idle_field_costs_nothing_and_accepts_a_clear() -> void:
	field.tick(STEP)
	field.clear()
	field.clear_owner(3)
	assert_eq(field.count(), 0)

# --- The crowd grid queries it uses ---

func test_crowd_grid_any_within_reads_only_the_cells_round_the_circle() -> void:
	var near := rig.enemy(Vector3(2, 0, 2), 100.0)
	rig.enemy(Vector3(20, 0, 20), 100.0)
	world.crowd.rebuild(world.enemies)
	assert_true(world.crowd.any_within(Vector3(2.3, 0, 2), .3))
	assert_false(world.crowd.any_within(Vector3(10, 0, 10), .3), "Nothing near")
	assert_true(world.crowd.any_within(Vector3(20, 0, 20.5), .3))
	assert_false(world.crowd.any_within(Vector3(2.3 + near.hurtbox_radius() + .6, 0, 2), .3))
	near.dead = true
	assert_false(world.crowd.any_within(Vector3(2.3, 0, 2), .5), "A dead actor does not count")

extends GutTest

## S1 on the enemy side: who walks (or aims) at a Decoy's taunt and who keeps going for the hero, and how a hooked enemy
## circles its Decoy. The posts here are published by hand on an ordinary turret, so the engine piece is tested without the
## Decoy turret; `test_decoy_turret.gd` covers the Decoy publishing and hooking them itself.

const STEP := 1.0 / 60.0

var rig: TurretTestRig
var world: ArenaWorld

func before_each() -> void:
	rig = TurretTestRig.start(self, true)
	world = rig.world
	world.player.position = Vector3(0, 0, 10)

func after_each() -> void:
	TestHelpers.reset_flags()

## A turret at `at` that taunts (a post published by hand).
func _post(at: Vector3, radius: float = 4.5, ranged: bool = false) -> TauntPost:
	var turret := rig.turret("normal", [], at)
	var post := TauntPost.new(turret)
	post.radius = radius
	post.ranged = ranged
	post.hook_ring = 1.2
	world.taunts.publish(post)
	return post

## A live enemy whose own physics we drive by hand (the rig's `enemy` is inert; this one still runs `_physics_process`).
func _enemy(at: Vector3, type_id: String = "basic") -> EnemyActor:
	var enemy := rig.enemy(at, 1000.0, type_id) as EnemyActor
	rig.combat()
	return enemy

func _run(enemy: EnemyActor, seconds: float) -> void:
	for tick in roundi(seconds / STEP):
		world.crowd.rebuild(world.enemies)
		enemy._physics_process(STEP)

func _away(enemy: EnemyActor, from: Vector3) -> float:
	return WorldGeometry.planar(enemy.position - from).length()

# --- Chasers ---

func test_without_a_decoy_the_chaser_walks_at_the_hero() -> void:
	var enemy := _enemy(Vector3.ZERO)
	assert_null(enemy.taunt_post())
	assert_eq(enemy.chase_position(), world.player.position)
	_run(enemy, .5)
	assert_gt(enemy.position.z, .3, "Toward the hero at +z")

func test_a_chaser_in_reach_walks_at_the_decoy_instead_of_the_hero() -> void:
	var post := _post(Vector3(0, 0, -3))
	var enemy := _enemy(Vector3.ZERO)
	assert_same(enemy.taunt_post(), post)
	assert_eq(enemy.chase_position(), post.turret.position)
	assert_same(enemy.taunt_target, post)
	_run(enemy, .5)
	assert_lt(enemy.position.z, -.3, "Toward the Decoy at -z, away from the hero")

func test_a_chaser_beyond_the_taunt_radius_keeps_going_for_the_hero() -> void:
	_post(Vector3(0, 0, -6), 4.5)
	var enemy := _enemy(Vector3.ZERO)
	assert_null(enemy.taunt_post())
	_run(enemy, .5)
	assert_gt(enemy.position.z, .3)

func test_the_taunt_ends_when_the_enemy_is_pushed_out_of_reach() -> void:
	var post := _post(Vector3(0, 0, -3), 4.5)
	var enemy := _enemy(Vector3.ZERO)
	assert_same(enemy.taunt_post(), post)
	enemy.position = Vector3(0, 0, 3)
	assert_null(enemy.taunt_post(), "Seven metres from the Decoy: back to the hero")

func test_every_kind_of_chaser_answers_the_taunt() -> void:
	var post := _post(Vector3(0, 0, -3))
	for type_id in ["basic", "fast", "tank", "charger", "exploder", "hopper", "skitter", "drowse"]:
		var enemy := _enemy(Vector3.ZERO, type_id)
		assert_same(enemy.taunt_post(), post, type_id)

func test_a_charger_winds_up_and_dashes_at_the_decoy() -> void:
	var post := _post(Vector3(0, 0, -3), 4.5)
	var enemy := _enemy(Vector3(0, 0, 0), "charger")
	assert_not_null(enemy.charge)
	var dashed := false
	for tick in 240:
		world.crowd.rebuild(world.enemies)
		enemy._physics_process(STEP)
		if enemy.charge.phase == ChargeController3D.Phase.DASH:
			dashed = true
			assert_lt(enemy.charge.heading.z, -.5, "The dash is locked on the Decoy, not the hero")
			break
	assert_true(dashed, "The charger went through its wind-up and dashed")
	assert_same(enemy.taunt_target, post)

# --- Who never answers ---

func test_every_boss_ignores_the_taunt() -> void:
	_post(Vector3(0, 0, -1), 20.0, true)
	for boss_id in EnemyEcology.BOSS_IDS:
		assert_eq(EnemyEcology.taunt_kind(boss_id), EnemyEcology.Taunt.NONE, boss_id)
	var ram := _enemy(Vector3.ZERO, "brass_ram")
	assert_null(ram.taunt_post(), "The Brass Ram attacks the hero only")
	_run(ram, .5)
	assert_gt(ram.position.z, .05, "Still heading for the hero")

func test_boss_summons_and_crates_ignore_the_taunt() -> void:
	_post(Vector3(0, 0, -1), 20.0, true)
	for type_id in ["lens", "anchor", "puppet"]:
		assert_eq(EnemyEcology.taunt_kind(type_id), EnemyEcology.Taunt.NONE, type_id)
	var crate := world.spawn_enemy(Vector3.ZERO, "basic")
	crate.stationary = true
	assert_null(crate.taunt_post(), "A stationary body does not walk")

func test_core_seekers_keep_ignoring_everything_but_the_core() -> void:
	_post(Vector3(0, 0, -3))
	var seeker := _enemy(Vector3.ZERO)
	seeker.ignores_hero = true
	assert_null(seeker.taunt_post())

func test_a_sleeping_beetle_stays_asleep_and_an_awake_one_walks_at_the_decoy() -> void:
	_post(Vector3(0, 0, -6), 8.0)
	var beetle := _enemy(Vector3.ZERO, "drowse")
	_run(beetle, .5)
	assert_false(beetle.brain.awake, "The taunt does not wake a sleeper")
	beetle.brain.awake = true
	beetle.brain.state = EnemyBrain.State.CHASE
	var before := beetle.position
	_run(beetle, .5)
	assert_lt(beetle.position.z, before.z - .2, "An awake beetle goes for the Decoy at -z")

# --- Ranged enemies ---

func test_ranged_enemies_ignore_a_plain_taunt_and_answer_a_ranged_one() -> void:
	var plain := _post(Vector3(0, 0, -6), 8.0, false)
	for type_id in ["kite", "lobber", "tender"]:
		var enemy := _enemy(Vector3.ZERO, type_id)
		assert_null(enemy.taunt_post(), "%s ignores a plain Decoy" % type_id)
	world.taunts.withdraw(plain.owner_id)
	var wide := _post(Vector3(0, 0, -6), 8.0, true)
	for type_id in ["kite", "lobber", "tender"]:
		var enemy := _enemy(Vector3.ZERO, type_id)
		assert_same(enemy.taunt_post(), wide, "%s answers the Maelstrom" % type_id)

func test_a_kite_keeps_its_distance_from_the_decoy_it_aims_at() -> void:
	_post(Vector3(0, 0, -6), 8.0, true)
	var kite := _enemy(Vector3.ZERO, "kite")
	_run(kite, 1.0)
	assert_lt(kite.position.z, -.3, "The Kite closes on the Decoy at -z, not on the hero at +z")
	assert_same(kite.brain.actor, kite)

func test_a_ranged_enemy_without_a_ranged_taunt_still_goes_for_the_hero() -> void:
	_post(Vector3(0, 0, -6), 8.0, false)
	var kite := _enemy(Vector3.ZERO, "kite")
	_run(kite, 1.0)
	assert_gt(kite.position.z, .3)

# --- Lifecycle ---

func test_withdrawing_the_post_sends_the_enemy_back_to_the_hero() -> void:
	var post := _post(Vector3(0, 0, -3))
	var enemy := _enemy(Vector3.ZERO)
	assert_same(enemy.taunt_post(), post)
	world.taunts.withdraw(post.owner_id)
	assert_null(enemy.taunt_post())
	assert_eq(enemy.chase_position(), world.player.position)

func test_a_removed_decoy_stops_pulling() -> void:
	var post := _post(Vector3(0, 0, -3))
	var enemy := _enemy(Vector3.ZERO)
	post.turret.get_parent().remove_child(post.turret)
	post.turret.free()
	assert_null(enemy.taunt_post(), "A freed turret pulls nothing, and no error")
	assert_false(world.taunts.has_posts())

func test_a_run_reset_clears_the_taunts() -> void:
	_post(Vector3(0, 0, -3))
	world._clear_actors()
	assert_false(world.taunts.has_posts(), "The next run starts without the old Decoy's pull")

func test_a_carried_decoy_does_not_pull() -> void:
	var post := _post(Vector3(0, 0, -3))
	var enemy := _enemy(Vector3.ZERO)
	post.turret.carried = true
	assert_null(enemy.taunt_post())
	post.turret.carried = false
	assert_same(enemy.taunt_post(), post)

func test_the_nearest_of_two_decoys_wins() -> void:
	var left := _post(Vector3(-3, 0, 0))
	var right := _post(Vector3(2, 0, 0))
	var enemy := _enemy(Vector3.ZERO)
	assert_same(enemy.taunt_post(), right)
	enemy.position = Vector3(-2.5, 0, 0)
	assert_same(enemy.taunt_post(), left)

# --- Core mode ---

func test_in_core_mode_the_decoy_outranks_both_the_hero_and_the_core() -> void:
	var config := RunConfig.new()
	config.mode = RunConfig.MODE_CORE
	var arena := load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	arena.run_config = config
	add_child_autofree(arena)
	await wait_process_frames(2)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	var decoy := arena.add_turret(Vector3(8, 0, 8), "normal")
	decoy.set_physics_process(false)
	var post := TauntPost.new(decoy)
	post.radius = 4.5
	arena.taunts.publish(post)
	var enemy := arena.spawn_enemy(Vector3(8, 0, 6), "basic")
	enemy.set_physics_process(false)
	assert_eq(enemy.chase_position(), decoy.position)
	assert_same(enemy.taunt_target, post)
	arena.taunts.clear()
	assert_eq(enemy.chase_position(), arena.core.position, "Without the taunt the objective is the goal again")
	assert_null(enemy.taunt_target)

# --- Hooked enemies ---

func test_a_hooked_enemy_circles_its_decoy_on_a_lane() -> void:
	var post := _post(Vector3.ZERO, 7.0, true)
	var enemy := _enemy(Vector3(0, 0, -4))
	enemy.hook(post.owner_id)
	assert_true(enemy.is_hooked())
	var angle_before := atan2(enemy.position.z, enemy.position.x)
	_run(enemy, 6.0)
	var distance := _away(enemy, post.origin())
	assert_between(distance, post.hook_ring - .4, post.hook_ring + EnemyActor.HOOK_LANES * EnemyActor.HOOK_LANE_GAP + .6, "Settled on its lane")
	assert_gt(absf(wrapf(atan2(enemy.position.z, enemy.position.x) - angle_before, -PI, PI)), .5, "And walks round the Decoy")

func test_a_hooked_enemy_ignores_the_hero_and_its_decoys_radius() -> void:
	var post := _post(Vector3.ZERO, 7.0, true)
	world.player.position = Vector3(0, 0, 3)
	var enemy := _enemy(Vector3(0, 0, 2.5))
	enemy.hook(post.owner_id)
	enemy.position = Vector3(0, 0, 12)
	assert_null(enemy.taunt_post(), "Beyond the taunt radius it is not taunted, only hooked")
	_run(enemy, 1.0)
	assert_lt(enemy.position.z, 12.0 - 1.0, "Pulled in from beyond the taunt radius, away from the hero's side")

func test_hooks_are_per_owner_and_one_owner_cannot_release_the_others() -> void:
	var first := _post(Vector3(-3, 0, 0), 7.0, true)
	var second := _post(Vector3(3, 0, 0), 7.0, true)
	var enemy := _enemy(Vector3.ZERO)
	enemy.hook(first.owner_id)
	enemy.hook(second.owner_id)
	enemy.statuses.clear_timed(TauntField.HOOKED, first.owner_id)
	assert_true(enemy.is_hooked(), "The second Decoy still holds it")
	assert_same(world.taunts.hook_anchor(enemy), second)

func test_a_hook_whose_decoy_left_the_field_is_dropped_on_the_next_tick() -> void:
	var post := _post(Vector3.ZERO, 7.0, true)
	var enemy := _enemy(Vector3(0, 0, -3))
	enemy.hook(post.owner_id)
	world.taunts.withdraw(post.owner_id)
	_run(enemy, STEP * 2.0)
	assert_false(enemy.is_hooked(), "Nothing holds the hook any more")

func test_hooking_cancels_a_wound_up_action_and_death_clears_the_hook() -> void:
	var post := _post(Vector3.ZERO, 7.0, true)
	var enemy := _enemy(Vector3(0, 0, -3), "kite")
	enemy.brain.state = EnemyBrain.State.WARNING
	enemy.hook(post.owner_id)
	assert_ne(enemy.brain.state, EnemyBrain.State.WARNING, "The wind-up was cancelled")
	world.combat.apply_hit(enemy, CombatHit3D.new(1.0e9, Vector3.ZERO))
	assert_true(enemy.dead)
	assert_false(enemy.is_hooked(), "A dead enemy holds no hook")

func test_hooked_enemies_do_not_stack_on_one_point() -> void:
	var post := _post(Vector3.ZERO, 7.0, true)
	var hooked: Array[EnemyActor] = []
	for index in 8:
		var angle := float(index) * TAU / 8.0
		var enemy := _enemy(Vector3(cos(angle), 0, sin(angle)) * 5.0)
		enemy.hook(post.owner_id)
		hooked.append(enemy)
	for tick in 360:
		world.crowd.rebuild(world.enemies)
		for enemy in hooked:
			enemy._physics_process(STEP)
	var closest := INF
	for index in hooked.size():
		for other in range(index + 1, hooked.size()):
			closest = minf(closest, hooked[index].position.distance_to(hooked[other].position))
	assert_gt(closest, .3, "They spread round the ring")

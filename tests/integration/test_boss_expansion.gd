extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	world.run_config = RunConfig.new()
	world.run_config.mode = RunConfig.MODE_CORE
	FeatureFlagService.set_enabled(FeatureFlagService.MODE_PROTECT_CORE, true)
	add_child_autofree(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	for turret in world.turrets: turret.set_physics_process(false)
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	world.player.position = Vector3.ZERO
	world.camera_rig.snap()

func boss(kind: String) -> CombatActor:
	var actor := world.spawn_enemy(Vector3(2, 0, 0), kind)
	actor.set_physics_process(false)
	actor.brain.clock = 0.0
	return actor

func test_unique_boss_waves_and_health_curve() -> void:
	assert_eq(EnemyEcology.BOSSES.size(), 9)
	var seen: Array[String] = []
	var previous := 0.0
	for wave: int in EnemyEcology.BOSSES:
		var kind: String = EnemyEcology.BOSSES[wave]
		assert_false(kind in seen)
		seen.append(kind)
		assert_gt(wave, 5)
		assert_true(EnemyEcology.hero_only(kind))
		var hp := EnemyEcology.boss_health(kind, {"enemy_health_mult": 1.0})
		assert_gt(hp, previous)
		previous = hp
		assert_almost_eq(EnemyEcology.boss_health(kind, {"enemy_health_mult": 2.0}), hp * 2.0, 1.0)

func test_four_cannons_have_limited_outward_arcs_including_rear() -> void:
	for index in 4:
		var axis := BossExpansionBrain.cannon_axis(index)
		assert_true(BossExpansionBrain.within_cannon_arc(axis, axis))
		assert_true(BossExpansionBrain.within_cannon_arc(axis, axis.rotated(Vector3.UP, deg_to_rad(59))))
		assert_false(BossExpansionBrain.within_cannon_arc(axis, axis.rotated(Vector3.UP, deg_to_rad(61))))
		assert_false(BossExpansionBrain.within_cannon_arc(axis, -axis))
		assert_false(BossExpansionBrain.within_cannon_arc(axis, Vector3.ZERO))
	assert_true(BossExpansionBrain.within_cannon_arc(BossExpansionBrain.cannon_axis(2), Vector3.BACK))
	assert_true(BossExpansionBrain.within_cannon_arc(BossExpansionBrain.cannon_axis(3), Vector3.BACK))

func test_airship_salvo_is_warned_and_locks_target() -> void:
	var ship := boss("broadside_baron")
	world.player.position = Vector3(-3, 0, 0)
	ship.brain.move(.01, ship.speed)
	assert_eq(ship.brain.state, EnemyBrain.State.WARNING)
	assert_gt(ship.brain.expansion.salvo.size(), 0)
	assert_eq(get_tree().get_nodes_in_group("hostile_ordnance").size(), 0)
	var locked := ship.brain.locked_target
	world.player.position = Vector3(0, 0, 5)
	ship.brain.move(1.2, ship.speed)
	var shots := get_tree().get_nodes_in_group("hostile_ordnance")
	assert_gt(shots.size(), 0)
	for shot: EnemyOrdnance in shots:
		shot.set_physics_process(false)
		assert_eq(shot.target_at, locked)
		assert_false(shot.to_core)
	assert_true(ship.brain.expansion.salvo_lines.is_empty())

func test_bomber_commits_to_pass_and_drops_warned_bombs() -> void:
	var bomber := boss("skyfall_kestrel")
	bomber.brain.move(.01, bomber.speed)
	assert_eq(bomber.brain.state, EnemyBrain.State.WARNING)
	var heading := bomber.brain.expansion.heading
	world.player.position = Vector3(0, 0, 5)
	bomber.brain.move(1.1, bomber.speed)
	var movement := bomber.brain.move(.1, bomber.speed)
	assert_almost_eq(movement.normalized().dot(heading), 1.0, .001)
	var shots := get_tree().get_nodes_in_group("hostile_ordnance")
	assert_eq(shots.size(), 1)
	var bomb: EnemyOrdnance = shots[0]
	bomb.set_physics_process(false)
	assert_gte(bomb.warning_time, 1.0)
	assert_false(bomb.to_core)
	world.paused = true
	bomb._physics_process(2.0)
	assert_eq(bomb.elapsed, 0.0)
	world.paused = false
	world.clear_field(false)
	assert_true(bomb.is_queued_for_deletion())

func test_yeti_crab_regent_warn_hero_only_and_enrage() -> void:
	for kind in ["frostforge_yeti", "crucible_crab", "pendulum_regent"]:
		var actor := boss(kind)
		actor.health = actor.max_health * .4
		actor.brain.move(.01, actor.speed)
		assert_eq(actor.brain.phase, 2)
		assert_eq(actor.brain.state, EnemyBrain.State.WARNING)
		assert_false(actor.brain.contact_allowed())
		var shots := get_tree().get_nodes_in_group("hostile_ordnance")
		assert_gt(shots.size(), 0)
		for shot: EnemyOrdnance in shots:
			shot.set_physics_process(false)
			assert_false(shot.to_core)
			assert_gte(shot.warning_time, 1.0)
			shot.free()
		world.enemies.erase(actor)
		actor.free()

func test_wheel_contact_only_during_committed_roll() -> void:
	var wheel := boss("crownwheel_colossus")
	assert_false(wheel.brain.contact_allowed())
	wheel.brain.move(.01, wheel.speed)
	assert_eq(wheel.brain.state, EnemyBrain.State.WARNING)
	assert_false(wheel.brain.contact_allowed())
	wheel.brain.move(1.3, wheel.speed)
	assert_true(wheel.brain.contact_allowed())
	var locked := wheel.brain.expansion.heading
	world.player.position = Vector3(0, 0, 8)
	assert_almost_eq(wheel.brain.move(.1, wheel.speed).normalized().dot(locked), 1.0, .001)
	wheel.brain.move(1.4, wheel.speed)
	assert_false(wheel.brain.contact_allowed())

func test_new_boss_kills_queue_epic_items_once() -> void:
	for kind in EnemyEcology.EXPANSION_BOSSES:
		var actor := boss(kind)
		var before := world.drops.pending_items.size()
		actor.take_damage(actor.max_health + 1.0)
		assert_eq(world.drops.pending_items.size(), before + 1)
		actor.take_damage(1000.0)
		assert_eq(world.drops.pending_items.size(), before + 1)
		var item: Dictionary = ItemRegistry.get_item_dict(world.drops.pending_items.back().id)
		assert_eq(item.rarity, GameEnums.ItemRarity.EPIC)

func test_each_encounter_completes_repeated_attack_cycles_without_core_damage() -> void:
	world.player.invulnerability = 999.0
	var core_hp := world.core.health
	for kind in EnemyEcology.EXPANSION_BOSSES:
		var actor := boss(kind)
		actor.position = Vector3(3.5, 0, 0)
		actor.health = actor.max_health * .4
		var attacks_seen := 0
		for step in 360:
			var velocity := actor.brain.move(.1, actor.speed)
			actor.position = WorldGeometry.clamp_position(actor.position + velocity * .1)
			actor._animate(.1, velocity.normalized(), false)
			for shot: EnemyOrdnance in get_tree().get_nodes_in_group("hostile_ordnance"):
				shot.set_physics_process(false)
				if not shot.is_queued_for_deletion():
					attacks_seen += 1
					assert_false(shot.to_core)
					shot._physics_process(.1)
				if shot.is_queued_for_deletion(): shot.free()
		assert_gt(actor.brain.attacks, 1, kind + " recovers and repeats its pattern")
		assert_gt(attacks_seen, 0, kind + " produces live ordnance")
		assert_eq(world.core.health, core_hp)
		for shot in get_tree().get_nodes_in_group("hostile_ordnance"): shot.free()
		world.warning_actors.erase(actor)
		world.enemies.erase(actor)
		actor.free()

func test_surviving_expansion_bosses_do_not_block_round_end_or_award_items() -> void:
	for kind in EnemyEcology.EXPANSION_BOSSES: boss(kind)
	world.waves.remaining_spawns = 0
	world.waves.boss_spawned = true
	world.waves.time_left = .001
	world.waves.tick(.01)
	await get_tree().process_frame
	assert_true(world.enemies.is_empty())
	assert_true(world.drops.pending_items.is_empty())
	assert_eq(get_tree().get_nodes_in_group("hostile_ordnance").size(), 0)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)

func test_imported_bosses_have_live_animation_and_airship_muzzles() -> void:
	for kind in EnemyEcology.EXPANSION_BOSSES:
		assert_true(ClockworkModels.available(kind), "No placeholder model: " + kind)
		if not ClockworkModels.available(kind): continue
		var actor := boss(kind)
		assert_not_null(actor.ecology_motion)
		if not actor.ecology_motion: continue
		var player := actor.ecology_motion.player
		assert_not_null(player)
		if not player: continue
		for clip in ["Idle", "Walk", "Swim", "Attack"]:
			assert_true(player.has_animation(clip), kind + ": " + clip)
			if player.has_animation(clip): assert_gt(player.get_animation(clip).length, .1)
		actor.ecology_motion.tick(.1, false, false, false)
		var body := actor.visual.find_child("Body", true, false) as Node3D
		assert_not_null(body)
		var nodes := actor.visual.find_children("*", "Node3D", true, false)
		var before: Array[Transform3D] = []
		for node: Node3D in nodes: before.append(node.transform)
		actor.ecology_motion.tick(.37, true, true, false)
		var changed := false
		for index in nodes.size(): changed = changed or not nodes[index].transform.is_equal_approx(before[index])
		assert_true(changed, kind + " imported animation changes its actual pivots")
		if kind == "broadside_baron":
			for suffix in BossExpansionBrain.CANNONS:
				var pivot := actor.visual.find_child("Cannon_" + suffix, true, false) as Node3D
				var muzzle := actor.visual.find_child("Muzzle_" + suffix, true, false) as Node3D
				assert_not_null(pivot)
				assert_not_null(muzzle)
				if pivot and muzzle: assert_true(pivot.is_ancestor_of(muzzle))

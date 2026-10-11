extends GutTest

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

func test_evolution_replaces_model_preserving_identity_and_investment() -> void:
	var turret := world.turrets[0]
	turret.progression.award(110)
	turret.stay_time = 14
	turret.entrench_stacks_cached = 2
	var before_id := turret.turret_id
	var before_position := turret.position
	var before_count := TurretStatsService.get_total_turret_count()
	var old_model := turret.model
	assert_true(turret.evolve("machine_gun"))
	assert_ne(turret.model, old_model)
	assert_eq(turret.turret_id, before_id)
	assert_eq(turret.position, before_position)
	assert_eq(turret.stay_time, 14.0)
	assert_eq(turret.progression.total_xp, 110)
	assert_eq(TurretStatsService.get_total_turret_count(), before_count)
	assert_eq(turret.turret_type, "normal")
	assert_eq(turret.display_name(), "Machine Gun")
	assert_gt(turret._current_view(0).fire_rate, 3.0)
	assert_false(turret.evolve("scatter"), "Cannot spend a milestone twice")

func test_scatter_emits_three_distinct_attributed_projectiles() -> void:
	var turret := world.turrets[0]
	turret.progression.award(110)
	assert_true(turret.evolve("scatter"))
	var enemy := world.spawn_enemy(turret.position + Vector3(0, 0, -1.8))
	enemy.set_physics_process(false)
	turret.target = enemy
	turret._fire_projectile(turret._current_view(0))
	assert_eq(world.projectiles.size(), 3)
	assert_ne(world.projectiles[0].direction, world.projectiles[1].direction)
	assert_ne(world.projectiles[1].direction, world.projectiles[2].direction)
	for shot in world.projectiles:
		assert_eq(shot.shot.source_id, turret.turret_id)
		assert_eq(shot.shot.attack_families, ["projectile"])

func test_saber_reaches_and_hits_beyond_base_bat_radius() -> void:
	var turret := world.add_turret(Vector3.ZERO, "melee")
	turret.set_physics_process(false)
	turret.progression.award(110)
	assert_true(turret.evolve("saber"))
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	var enemy := world.spawn_enemy(Vector3(0, 0, -1.5))
	enemy.set_physics_process(false)
	enemy.health = 100
	world.crowd.rebuild(world.enemies)
	var stats := turret._current_view(0)
	turret._spin_bat(.1, stats, stats.range_metres)
	assert_lt(enemy.health, 100.0)
	assert_gt(stats.range_metres, 1.45)
	assert_almost_eq(WorldGeometry.planar(turret.muzzle.global_position - turret.aim.global_position).length(), stats.range_metres, .001)

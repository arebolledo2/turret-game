extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_flags()
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	world.run_config = RunConfig.new()
	world.run_config.mode = RunConfig.MODE_CORE
	add_child_autofree(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	for turret in world.turrets: turret.set_physics_process(false)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	world.waves.remaining_spawns = 0
	world.player.position = Vector3(10, 0, 5)

func test_group_warns_before_multiple_enemies_arrive_together() -> void:
	world.waves.spawn_plan.assign(["basic", "basic", "basic", "basic"])
	world.waves.remaining_spawns = 4
	world.waves.spawn_interval = .8
	world.waves.spawn_clock = 0
	world.waves.tick(.01)
	assert_eq(world.enemies.size(), 0)
	assert_eq(world.waves.pending_spawns.size(), 4)
	world.waves.tick(.5)
	assert_eq(world.enemies.size(), 0)
	world.waves.tick(.41)
	assert_eq(world.enemies.size(), 4)
	assert_true(world.waves.pending_spawns.is_empty())

func test_hero_or_core_cancels_warning_without_replacement() -> void:
	var at := Vector3(4, 0, 0)
	for blocker in [world.player, world.core]:
		world.player.position = Vector3(10, 0, 5)
		world.core.position = Vector3.ZERO
		world.waves.warn_spawn("basic", at)
		assert_eq(world.waves.pending_spawns.size(), 1)
		blocker.position = at
		world.waves.advance_spawn_warnings(.1)
		assert_true(world.waves.pending_spawns.is_empty())
		blocker.position = Vector3(10, 0, 5)
		world.waves.advance_spawn_warnings(1.0)
		assert_eq(world.enemies.size(), 0)

func test_occupied_point_never_arms_and_cleanup_removes_all_warnings() -> void:
	world.waves.warn_spawn("basic", world.player.position)
	world.waves.warn_spawn("basic", world.core.position)
	assert_true(world.waves.pending_spawns.is_empty())
	world.waves.warn_spawn("basic", Vector3(4, 0, 0))
	assert_eq(world.waves.pending_spawns.size(), 1)
	world.clear_field(false)
	assert_true(world.waves.pending_spawns.is_empty())
	world.waves.advance_spawn_warnings(2.0)
	assert_true(world.enemies.is_empty())

func test_pause_freezes_warning_countdown() -> void:
	world.waves.warn_spawn("basic", Vector3(4, 0, 0))
	var left: float = world.waves.pending_spawns[0].left
	world.paused = true
	world.waves.tick(10.0)
	assert_eq(world.waves.pending_spawns[0].left, left)
	assert_true(world.enemies.is_empty())

func test_sparse_escort_budget_is_not_exhausted_early() -> void:
	world.waves.spawn_plan.assign(["basic", "basic", "basic", "basic", "basic", "basic"])
	world.waves.remaining_spawns = 6
	world.waves.spawn_interval = 10.0
	world.waves.arrival_time_left = 60.0
	world.waves.time_left = 60.0
	world.waves.spawn_clock = 0.0
	var elapsed := 0.0
	var last_group := 0.0
	while elapsed < 59.5:
		var before := world.waves.spawned_this_wave
		world.waves.tick(.1)
		elapsed += .1
		if world.waves.spawned_this_wave > before: last_group = elapsed
	assert_gt(last_group, 55.0, "small escorts are spread across the whole encounter")
	assert_eq(world.waves.spawned_this_wave, 6)

func test_group_positions_are_independently_scattered() -> void:
	GameRandom.gameplay.seed = 92741
	world.player.position = Vector3.ZERO
	world.core.position = Vector3(10, 0, 5)
	world.waves.spawn_plan.assign(["drowse", "drowse", "drowse", "drowse"])
	world.waves.remaining_spawns = 4
	world.waves.spawn_interval = .8
	world.waves.queue_spawn_group()
	assert_eq(world.waves.pending_spawns.size(), 4)
	var points: Array[Vector3] = []
	for entry in world.waves.pending_spawns: points.append(entry.at)
	var spread := 0.0
	for a in points:
		for b in points: spread = maxf(spread, a.distance_to(b))
	assert_gt(spread, 3.0, "A timed group no longer occupies a fixed 1.4 m grid")

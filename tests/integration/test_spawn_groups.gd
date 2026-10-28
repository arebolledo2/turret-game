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

func setup_convoy_route() -> void:
	world.convoy_mode = true
	world.convoy_route = ConvoyRoute.new()
	world.convoy_route.doors = PackedVector3Array([Vector3(-10, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, 10)])
	world.convoy_mover = ConvoyMover.new()
	world.convoy_mover.start(world.convoy_route)
	world.core.position = Vector3(-8, 0, 0)
	world.player.position = Vector3(-10, 0, -8)

func test_convoy_active_leg_and_core_gap_exclude_spawn_points() -> void:
	setup_convoy_route()
	assert_true(world.waves.spawn_blocked(Vector3(5, 0, 0)), "Ahead on active leg")
	assert_true(world.waves.spawn_blocked(Vector3(-10, 0, 0)), "Behind on active leg")
	assert_true(world.waves.spawn_blocked(Vector3(5, 0, 1.9)), "Corridor has width")
	assert_false(world.waves.spawn_blocked(Vector3(5, 0, 2.1)))
	assert_true(world.waves.spawn_blocked(world.core.position + Vector3(0, 0, 4)))
	assert_false(world.waves.spawn_blocked(world.core.position + Vector3(0, 0, 5)))
	assert_false(world.waves.spawn_blocked(Vector3(10, 0, 6)), "Future legs remain eligible")
	world.convoy_mover.target_index = 2
	world.core.position = Vector3(10, 0, 0)
	assert_true(world.waves.spawn_blocked(Vector3(10, 0, 6)))
	assert_false(world.waves.spawn_blocked(Vector3(-5, 0, 0)), "Completed leg becomes eligible")

func test_convoy_warning_cancels_when_core_or_active_leg_changes() -> void:
	setup_convoy_route()
	world.waves.warn_spawn("basic", Vector3(10, 0, 6))
	assert_eq(world.waves.pending_spawns.size(), 1)
	world.convoy_mover.target_index = 2
	world.waves.advance_spawn_warnings(1.0)
	assert_true(world.waves.pending_spawns.is_empty())
	assert_true(world.enemies.is_empty())
	world.waves.warn_spawn("basic", Vector3(0, 0, 5))
	assert_eq(world.waves.pending_spawns.size(), 1)
	world.core.position = Vector3(0, 0, 2)
	world.waves.advance_spawn_warnings(1.0)
	assert_true(world.enemies.is_empty())
	assert_true(world.waves.pending_spawns.is_empty())

func test_convoy_sampling_preserves_safe_arrivals_and_summons_obey_exclusion() -> void:
	setup_convoy_route()
	GameRandom.gameplay.seed = 719
	for kind in ["basic", "drowse", "kite", "brass_ram"]:
		for index in 20:
			assert_false(world.waves.spawn_blocked(world.waves.encounter_position(kind)))
	var tender := world.spawn_enemy(Vector3(0, 0, 0), "tender")
	tender.set_physics_process(false)
	assert_null(tender.brain._summon("skitter", 0.0))
	assert_true(tender.brain.children.is_empty())
	tender.position = Vector3(0, 0, 5)
	assert_not_null(tender.brain._summon("skitter", 0.0))

func test_spawn_zone_counts_and_randomized_bias() -> void:
	GameRandom.gameplay.seed = 2026
	for wave in range(1, 21):
		world.spawn_zones.generate(wave)
		assert_gte(world.spawn_zones.centres.size(), 1 if wave <= 5 else 2)
		assert_lte(world.spawn_zones.centres.size(), 2 if wave <= 5 else 4)
	world.spawn_zones.centres.assign([Vector3(-10, 0, -5)])
	var nearby := 0
	for index in 400:
		var at := world.waves._sample_encounter_position("drowse")
		if at.distance_to(world.spawn_zones.centres[0]) <= SpawnZones.RADIUS + .01: nearby += 1
	assert_gt(nearby, 240)
	assert_lt(nearby, 340, "Some arrivals still use unrestricted random locations")
	GameStateMachine.force_transition(GameStateMachine.GameState.PREPARATION)
	world.spawn_zones._process(0)
	assert_true(world.spawn_zones.visible)
	assert_true(world.spawn_zones.labels[0].visible)
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	world.spawn_zones._process(0)
	assert_false(world.spawn_zones.visible)

func test_boss_and_full_health_crate_have_offscreen_pointer_data() -> void:
	var overlay := EnemyHealthOverlay.new()
	overlay.world = world
	add_child_autofree(overlay)
	world.camera_rig.set_zoom(1.5)
	world.camera_rig.snap()
	await wait_process_frames(2)
	for kind in ["brass_ram", "tech_drop"]:
		var actor := world.spawn_enemy(Vector3(100, 0, 0), kind)
		actor.set_physics_process(false)
		var data := overlay.pointer_data(actor)
		assert_false(data.is_empty())
		assert_true(get_viewport().get_visible_rect().has_point(data.at))
		assert_gt(data.direction.x, 0.0)
		actor.position = world.camera_rig.focus
		assert_true(overlay.pointer_data(actor).is_empty())

func test_spawn_zone_discs_clear_core_and_entire_convoy_route() -> void:
	for seed_value in range(20):
		GameRandom.gameplay.seed = seed_value
		world.spawn_zones.generate(10)
		for at in world.spawn_zones.centres:
			assert_gte(at.distance_to(world.core.position), SpawnZones.RADIUS + SpawnZones.CORE_GAP + world.core.radius)
	world.convoy_mode = true
	world.convoy_route = ConvoyRoute.new()
	world.convoy_route.doors = PackedVector3Array([Vector3(-18, 0, -4), Vector3(0, 0, -4), Vector3(18, 0, 3)])
	world.core.position = world.convoy_route.doors[0]
	world.spawn_zones.generate(10)
	for at in world.spawn_zones.centres:
		for i in range(1, world.convoy_route.doors.size()):
			var closest := Geometry3D.get_closest_point_to_segment(at, world.convoy_route.doors[i - 1], world.convoy_route.doors[i])
			assert_gte(at.distance_to(closest), SpawnZones.RADIUS + SpawnZones.CORE_GAP + world.core.radius)

func test_ranged_enemies_are_tracked_for_offscreen_alerts() -> void:
	var overlay := EnemyHealthOverlay.new()
	overlay.world = world
	add_child_autofree(overlay)
	for kind in ["kite", "lobber", "lens", "anchor", "tender", "prism_conductor", "grand_marionettist"]:
		var actor := world.spawn_enemy(Vector3(100, 0, 0), kind)
		actor.set_physics_process(false)
		overlay._process(.1)
		assert_has(overlay.tracked, actor)
		assert_false(overlay.pointer_data(actor).is_empty())

func test_survival_clears_spawn_zones() -> void:
	assert_false(world.spawn_zones.centres.is_empty())
	world.core_mode = false
	world.spawn_zones.generate(10)
	assert_true(world.spawn_zones.centres.is_empty())
	assert_true(world.spawn_zones.labels.is_empty())
	assert_eq(world.spawn_zones.get_child_count(), 0)

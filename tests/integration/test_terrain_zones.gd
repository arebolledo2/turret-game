extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()

func after_each() -> void:
	Input.action_release("move_right")
	TestHelpers.reset_flags()

func _world(layout_id: String = "crossroads", mode: String = RunConfig.MODE_SURVIVE) -> ArenaWorld:
	FeatureFlagService.set_enabled(FeatureFlagService.TERRAIN_ZONES, true)
	var config := RunConfig.new()
	config.layout_id = layout_id
	config.mode = mode
	var arena := load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	arena.run_config = config
	add_child_autofree(arena)
	await wait_process_frames(2)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	arena.waves.remaining_spawns = 0
	arena.waves.time_left = 999.0
	return arena

# ---- Layout data -------------------------------------------------------------------------------------------------

func test_every_layout_fits_the_arena_and_clears_the_centre() -> void:
	var half := WorldGeometry.HALF_ARENA
	assert_gte(ArenaLayouts.ids().size(), 3)
	for layout_id in ArenaLayouts.ids():
		var layout := ArenaLayouts.get_layout(layout_id)
		for zone in layout.zones:
			assert_gte(zone.clearance_from_origin(), GameConstants.ZONE_CENTRE_CLEARANCE, "%s / %s is clear of the origin" % [layout_id, zone.label()])
			assert_lte(zone.centre.x + zone.half_extents.x, half.x, "%s / %s stays inside x" % [layout_id, zone.label()])
			assert_gte(zone.centre.x - zone.half_extents.x, -half.x)
			assert_lte(zone.centre.y + zone.half_extents.y, half.y, "%s / %s stays inside z" % [layout_id, zone.label()])
			assert_gte(zone.centre.y - zone.half_extents.y, -half.y)

func test_every_layout_uses_all_four_zone_types() -> void:
	for layout_id in ArenaLayouts.ids():
		var layout := ArenaLayouts.get_layout(layout_id)
		for zone_type in [TerrainZone.HIGH_GROUND, TerrainZone.MUD, TerrainZone.NO_BUILD, TerrainZone.POWER_NODE]:
			assert_true(layout.has_type(zone_type), "%s has %s" % [layout_id, zone_type])

func test_unknown_layout_is_null_and_random_picks_a_real_one() -> void:
	assert_null(ArenaLayouts.get_layout("nope"))
	assert_true(ArenaLayouts.random_layout(GameRandom.gameplay).id in ArenaLayouts.ids())

func test_run_config_layout_argument() -> void:
	assert_eq(RunConfig.from_args(PackedStringArray(["--layout=SUMP"])).layout_id, "sump")
	assert_eq(RunConfig.from_args(PackedStringArray(["--layout=banana"])).layout_id, "")

# ---- Queries -----------------------------------------------------------------------------------------------------

func test_shapes_contain_their_points() -> void:
	var disc := TerrainZone.circle(TerrainZone.MUD, 5, 5, 2.0)
	assert_true(disc.contains(6.5, 5))
	assert_false(disc.contains(7.1, 5))
	var slab := TerrainZone.rect(TerrainZone.MUD, 0, 0, 3.0, 1.0)
	assert_true(slab.contains(2.9, .9))
	assert_false(slab.contains(0, 1.1))

func test_index_agrees_with_brute_force() -> void:
	var layout := ArenaLayouts.get_layout("highlands")
	var terrain := TerrainZones.new(layout)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for index in 600:
		var at := Vector3(rng.randf_range(-28.5, 28.5), 0, rng.randf_range(-16, 16))
		for zone_type in [TerrainZone.HIGH_GROUND, TerrainZone.MUD, TerrainZone.NO_BUILD, TerrainZone.POWER_NODE]:
			var expected := false
			for zone in layout.zones:
				expected = expected or (zone.type == zone_type and zone.contains(at.x, at.z))
			assert_eq(terrain.covers(at, zone_type), expected, "%s at %s" % [zone_type, at])

func test_mud_slow_is_capped() -> void:
	var layout := ArenaLayout.new()
	layout.zones.append(TerrainZone.circle(TerrainZone.MUD, 10, 10, 2.0, 5.0))
	var terrain := TerrainZones.new(layout)
	assert_almost_eq(terrain.mud_factor_at(Vector3(10, 0, 10)), 1.0 - GameConstants.ZONE_MUD_MAX_SLOW, .0001)
	assert_eq(terrain.mud_factor_at(Vector3(-10, 0, -10)), 1.0)

func test_no_mud_layout_short_circuits() -> void:
	var layout := ArenaLayout.new()
	layout.zones.append(TerrainZone.circle(TerrainZone.NO_BUILD, 10, 10, 2.0))
	var terrain := TerrainZones.new(layout)
	assert_false(terrain.has_mud)
	assert_eq(terrain.mud_factor_at(Vector3(10, 0, 10)), 1.0)

# ---- In the arena ------------------------------------------------------------------------------------------------

func test_run_gets_one_layout_that_lasts_all_waves() -> void:
	world = await _world("")
	assert_not_null(world.terrain)
	var terrain := world.terrain
	var layout_id := terrain.layout.id
	world.finish_wave()
	world.begin_next_wave()
	world.finish_wave()
	assert_same(world.terrain, terrain)
	assert_eq(world.terrain.layout.id, layout_id)
	assert_gt(world.terrain.root.get_child_count(), 0, "scenery was built")

func test_flag_off_means_no_terrain() -> void:
	world = load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	add_child_autofree(world)
	await wait_process_frames(2)
	assert_null(world.terrain)

func test_no_build_ground_rejects_turrets() -> void:
	world = await _world()
	assert_false(world.valid_placement(Vector3(-9, 0, 6.5)))
	assert_true(world.valid_placement(Vector3(-9, 0, 2.0)))

func test_high_ground_extends_turret_range() -> void:
	world = await _world()
	var flat := world.add_turret(Vector3(5, 0, 0), "normal")
	var raised := world.add_turret(Vector3(-14, 0, -8), "normal")
	await wait_physics_frames(2)
	var flat_range := float(flat._current_stats(.0)["range"])
	var raised_range := float(raised._current_stats(.0)["range"])
	assert_almost_eq(raised_range, flat_range * (1.0 + GameConstants.ZONE_HIGH_GROUND_RANGE_BONUS), .01)

func test_power_node_speeds_up_entrench() -> void:
	world = await _world()
	var seconds := GameConstants.ENTRENCH_STACK_SECONDS
	var plain := world.add_turret(Vector3(5, 0, 0), "normal")
	var node := world.add_turret(Vector3(18, 0, -10), "normal")
	await wait_physics_frames(2)
	node._current_stats(.0)
	var stay := seconds / (1.0 + GameConstants.ZONE_POWER_NODE_ENTRENCH_BONUS) + .01
	plain.stay_time = stay
	node.stay_time = stay
	assert_eq(plain.entrench_stacks(), 0)
	assert_eq(node.entrench_stacks(), 1)

func test_mud_slows_enemies() -> void:
	world = await _world()
	world.player.position = Vector3(0, 0, 1)
	var muddy := world.spawn_enemy(Vector3(0, 0, -11.5), "basic")
	var clear := world.spawn_enemy(Vector3(10, 0, -11.5), "basic")
	for enemy in [muddy, clear]:
		enemy.max_health = 1e9
		enemy.health = 1e9
	var muddy_start := muddy.position
	var clear_start := clear.position
	await wait_physics_frames(20)
	var muddy_travel := muddy.position.distance_to(muddy_start)
	var clear_travel := clear.position.distance_to(clear_start)
	assert_lt(muddy_travel, clear_travel * (1.0 - GameConstants.ZONE_MUD_SLOW) + .05)
	assert_gt(muddy_travel, 0.0)

func test_mud_slows_the_hero_too() -> void:
	world = await _world()
	world.turrets[0].set_physics_process(false)
	var speeds: Array[float] = []
	for start in [Vector3(-25, 0, 0), Vector3(-3.5, 0, -11.5)]:
		world.player.position = start
		world.player.velocity = Vector3.ZERO
		Input.action_press("move_right", 1.0)
		await wait_physics_frames(25)
		speeds.append(world.player.velocity.length())
		Input.action_release("move_right")
	assert_lt(speeds[1], speeds[0] * .8, "the hero moves slower inside the mud zone")

func test_tech_drops_avoid_no_build_and_mud() -> void:
	world = await _world()
	for attempt in 40:
		var at := world.drops.find_position()
		if at != Vector3.INF:
			assert_false(world.terrain.blocks_build(at))
			assert_eq(world.terrain.mud_factor_at(at), 1.0)

func test_debug_zones_draws_labels_and_hides_again() -> void:
	world = await _world()
	world.terrain.update_debug(true)
	var debug := world.terrain.root.get_node("ZoneDebug") as Node3D
	assert_true(debug.visible)
	assert_eq(debug.get_child_count(), world.terrain.zones.size() * 2)
	world.terrain.update_debug(false)
	assert_false(debug.visible)

func test_core_mode_layouts_leave_the_core_clear() -> void:
	world = await _world("sump", RunConfig.MODE_CORE)
	assert_not_null(world.core)
	assert_false(world.terrain.blocks_build(world.core.position))
	assert_eq(world.terrain.mud_factor_at(world.core.position), 1.0)

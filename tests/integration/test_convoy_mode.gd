extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_flags()
	TestHelpers.reset_all_services()

func _convoy_world() -> ArenaWorld:
	var config := RunConfig.new()
	config.mode = RunConfig.MODE_CONVOY
	var arena := load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	arena.run_config = config
	add_child_autofree(arena)
	await wait_process_frames(2)
	return arena

func _to_combat(arena: ArenaWorld) -> void:
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	arena.waves.remaining_spawns = 0

func test_convoy_is_a_core_mode_with_a_planned_route() -> void:
	world = await _convoy_world()
	assert_true(world.convoy_mode)
	assert_true(world.core_mode)
	assert_not_null(world.core)
	assert_not_null(world.convoy_route)
	assert_eq(world.convoy_route.doors[0], world.core.position, "the route starts where the core is")
	assert_not_null(world.get_node_or_null("RouteOverlay"))

func test_flag_off_falls_back_to_survive() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.MODE_CONVOY, false)
	world = await _convoy_world()
	assert_false(world.convoy_mode)
	assert_null(world.core)

func test_core_drives_to_the_first_door_during_combat() -> void:
	world = await _convoy_world()
	_to_combat(world)
	var start := world.core.position
	await wait_physics_frames(30)
	assert_gt(world.core.position.distance_to(start), .1, "the core moved")
	var door := world.convoy_route.doors[1]
	assert_lt(world.core.position.distance_to(door), start.distance_to(door), "...toward the first door")

func test_core_stays_put_outside_combat() -> void:
	world = await _convoy_world()
	var start := world.core.position
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	await wait_physics_frames(10)
	assert_eq(world.core.position, start)

func test_round_ends_when_the_core_reaches_the_final_door() -> void:
	world = await _convoy_world()
	_to_combat(world)
	world.convoy_mover.advance(10000.0, 1000.0) # drive the whole route at once
	assert_true(world.convoy_mover.finished)
	world.core.position = world.convoy_mover.position
	await wait_physics_frames(2)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)

func test_next_route_is_planned_from_the_end_point_and_differs() -> void:
	world = await _convoy_world()
	_to_combat(world)
	var first := world.convoy_route
	world.convoy_mover.advance(10000.0, 1000.0)
	world.core.position = world.convoy_mover.position
	world.finish_wave()
	assert_ne(world.convoy_route, first, "a new route is previewed in the shop")
	assert_eq(world.convoy_route.doors[0], first.doors[first.doors.size() - 1], "starting where the last one ended")
	var planned := world.convoy_route
	world.begin_next_wave()
	assert_eq(world.convoy_route, planned, "the previewed route is the one driven")
	assert_eq(world.convoy_mover.route, planned)

func test_enemies_head_for_the_moved_core() -> void:
	world = await _convoy_world()
	_to_combat(world)
	world.core.position = Vector3(10, 0, 8)
	var enemy := world.spawn_enemy(Vector3(-12, 0, -6), "basic")
	assert_eq(enemy.chase_position(), world.core.position)

func test_spawn_box_follows_the_core() -> void:
	world = await _convoy_world()
	world.core.position = Vector3(10, 0, 8)
	for attempt in 20:
		var at := world.waves.spawn_position()
		var half := WorldGeometry.HALF_ARENA * GameConstants.CORE_SPAWN_BOX
		var offset := at - world.core.position
		# Clamping to the arena can pull a point in, so only the far edge is bounded.
		assert_lte(absf(offset.x), half.x + .01)
		assert_lte(absf(offset.z), half.y + .01)

func test_faster_core_means_fewer_enemies_and_a_shorter_round() -> void:
	world = await _convoy_world()
	var slow_spawns := world.waves.remaining_spawns
	var slow_limit := world.waves.time_left
	var boost := Item.create_modifier("core_move_speed", "increase", 1.0)
	boost["id"] = "test_boost"
	ModifierService.add_modifiers([boost])
	GameStateMachine.force_transition(GameStateMachine.GameState.IDLE)
	GameStateService.current_wave = 0
	world.convoy_mover = null
	world.plan_convoy_route(1)
	world.waves.begin_next_wave()
	assert_lte(world.waves.remaining_spawns, slow_spawns)
	assert_lt(world.waves.time_left, slow_limit)

func test_heavy_hauler_adds_real_encounters_even_on_long_routes() -> void:
	world = await _convoy_world()
	world.set_physics_process(false)
	# A long route that already exceeded the old 2x budget cap.
	var route := ConvoyRoute.new()
	route.doors = PackedVector3Array([Vector3(-18, 0, 9), Vector3(18, 0, -9), Vector3(-18, 0, -9), Vector3(18, 0, 9)])
	world.convoy_route = route
	world.convoy_mover = null
	GameStateService.current_wave = 0
	GameStateMachine.force_transition(GameStateMachine.GameState.IDLE)
	world.begin_next_wave()
	var normal_count := world.waves.remaining_spawns
	var normal_time := world.waves.arrival_time_left
	var normal_interval := world.waves.spawn_interval
	var entries: Array = []
	for modifier: Dictionary in ItemRegistry.get_modifiers("heavy_hauler"):
		var entry := modifier.duplicate(true)
		entry["id"] = "test_hauler_" + str(entry.stat)
		entries.append(entry)
	ModifierService.add_modifiers(entries)
	world.convoy_mover = null
	GameStateService.current_wave = 0
	GameStateMachine.force_transition(GameStateMachine.GameState.IDLE)
	world.begin_next_wave()
	assert_gt(world.waves.remaining_spawns, normal_count * 1.15, "slower journey creates additional enemies, not stretched-out downtime")
	assert_gt(world.waves.arrival_time_left, normal_time * 1.15)
	assert_almost_eq(world.waves.spawn_interval, normal_interval, .1, "arrival pressure is maintained")
	assert_almost_eq(PlayerStatsService.get_core_move_speed(), GameConstants.CORE_MOVE_SPEED * .8, .001)

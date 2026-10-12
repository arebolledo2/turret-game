extends GutTest

func before_each() -> void:
	TestHelpers.reset_flags()
	TestHelpers.reset_all_services()

func _route(seed_value: int, wave: int = 1, start: Vector3 = Vector3.ZERO) -> ConvoyRoute:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return ConvoyRoute.generate(rng, wave, start)

func test_leg_count_grows_with_the_wave() -> void:
	assert_eq(ConvoyRoute.leg_count(1), 2)
	assert_eq(ConvoyRoute.leg_count(3), 3)
	assert_eq(ConvoyRoute.leg_count(5), 4)
	assert_eq(ConvoyRoute.leg_count(30), 4, "capped")

func test_same_seed_gives_the_same_route() -> void:
	var a := _route(42, 3)
	var b := _route(42, 3)
	assert_eq(a.doors, b.doors)
	assert_ne(_route(43, 3).doors, a.doors, "a different seed changes the route")

func test_route_starts_at_the_given_point_and_has_the_wave_s_doors() -> void:
	var route := _route(7, 3, Vector3(5, 0, -4))
	assert_eq(route.doors[0], ConvoyRoute.wall_point(Vector3(5, 0, -4), WorldGeometry.HALF_ARENA - Vector2.ONE * GameConstants.CONVOY_EDGE_MARGIN))
	assert_eq(route.door_count(), 1 + ConvoyRoute.leg_count(3))

func test_doors_stay_inside_the_arena_margin_and_legs_are_long_enough() -> void:
	var bounds := WorldGeometry.HALF_ARENA - Vector2.ONE * GameConstants.CONVOY_EDGE_MARGIN
	for seed_value in 40:
		var route := _route(seed_value, 5)
		for index in range(1, route.doors.size()):
			assert_lte(absf(route.doors[index].x), bounds.x + .001)
			assert_lte(absf(route.doors[index].z), bounds.y + .001)
			assert_gte(route.doors[index].distance_to(route.doors[index - 1]), GameConstants.CONVOY_MIN_LEG, "seed %d leg %d" % [seed_value, index])

func test_duration_scales_with_speed_and_counts_intermediate_pauses() -> void:
	var route := ConvoyRoute.new()
	route.doors = PackedVector3Array([Vector3.ZERO, Vector3(10, 0, 0), Vector3(10, 0, 10), Vector3(0, 0, 10)])
	assert_almost_eq(route.total_length(), 30.0, .001)
	assert_almost_eq(route.duration(1.0), 30.0 + 2.0 * route.pause_time, .001, "two intermediate doors pause")
	assert_almost_eq(route.duration(2.0), 15.0 + 2.0 * route.pause_time, .001, "pauses do not shrink with speed")

func test_mover_drives_pauses_and_finishes() -> void:
	var route := ConvoyRoute.new()
	route.pause_time = 2.0
	route.doors = PackedVector3Array([Vector3.ZERO, Vector3(10, 0, 0), Vector3(10, 0, 10)])
	var mover := ConvoyMover.new()
	mover.start(route)
	mover.advance(5.0, 1.0)
	assert_eq(mover.position, Vector3(5, 0, 0))
	mover.advance(5.0, 1.0)
	assert_eq(mover.position, Vector3(10, 0, 0), "arrives at door 1")
	assert_eq(mover.target_index, 2)
	mover.advance(1.5, 1.0)
	assert_eq(mover.position, Vector3(10, 0, 0), "paused at the intermediate door")
	mover.advance(1.0, 1.0) # .5 s of pause left, then .5 s of driving
	assert_almost_eq(mover.position.z, .5, .001)
	assert_false(mover.finished)
	mover.advance(20.0, 1.0)
	assert_eq(mover.position, Vector3(10, 0, 10))
	assert_true(mover.finished, "no pause at the final door")

func test_mover_total_time_matches_route_duration() -> void:
	var route := _route(11, 4)
	var mover := ConvoyMover.new()
	mover.start(route)
	var elapsed := 0.0
	while not mover.finished and elapsed < 1000.0:
		mover.advance(.1, 1.5)
		elapsed += .1
	assert_almost_eq(elapsed, route.duration(1.5), .15)

func test_core_move_speed_stat_and_items() -> void:
	assert_almost_eq(PlayerStatsService.get_core_move_speed(), GameConstants.CORE_MOVE_SPEED, .001)
	var entries: Array = []
	for modifier: Dictionary in ItemRegistry.get_modifiers("tracked_chassis"):
		var entry := modifier.duplicate(true)
		entry["id"] = "test_tracked_chassis"
		entries.append(entry)
	ModifierService.add_modifiers(entries)
	assert_almost_eq(PlayerStatsService.get_core_move_speed(), GameConstants.CORE_MOVE_SPEED * 1.15, .001)

func test_core_speed_has_a_floor() -> void:
	var slow := Item.create_modifier("core_move_speed", "increase", -5.0)
	slow["id"] = "test_slow"
	ModifierService.add_modifiers([slow])
	assert_almost_eq(PlayerStatsService.get_core_move_speed(), GameConstants.CORE_MIN_MOVE_SPEED, .001)

func test_start_and_exit_are_on_walls_and_existing_exit_is_preserved() -> void:
	var bounds := WorldGeometry.HALF_ARENA - Vector2.ONE * GameConstants.CONVOY_EDGE_MARGIN
	for seed_value in 100:
		var route := _route(seed_value, 8)
		for point in [route.doors[0], route.doors[-1]]:
			assert_true(is_equal_approx(absf(point.x), bounds.x) or is_equal_approx(absf(point.z), bounds.y))
		var next := _route(seed_value + 1, 9, route.doors[-1])
		assert_eq(next.doors[0], route.doors[-1])

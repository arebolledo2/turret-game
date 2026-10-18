extends GutTest

var world: ArenaWorld
var rig: CameraRig

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child_autofree(world)
	world.start_run()
	world.preparation.deploy()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	rig = world.camera_rig

func settle(frames: int = 120) -> void:
	for i in frames:
		rig.advance(1.0 / 60.0)

func visible_ground_inside_arena(zoom_value: float) -> bool:
	var half := rig.visible_half_extents(zoom_value)
	var margin := GameConstants.CAMERA_EDGE_MARGIN + .001
	return abs(rig.focus.x) + half.x <= WorldGeometry.HALF_ARENA.x + margin or rig.focus.x == 0.0

func test_arena_is_narrowed_20_percent_with_unchanged_depth() -> void:
	var size := WorldGeometry.HALF_ARENA * 2.0
	assert_almost_eq(size.x * size.y, 57.6 * 32.4 * .5 * .75 * .81 * WorldGeometry.ARENA_WIDTH_SCALE, .001)
	assert_almost_eq(size.x / size.y, 16.0 / 9.0 * WorldGeometry.ARENA_WIDTH_SCALE, .0001)

func test_camera_keeps_rotation_and_follows_the_player() -> void:
	# Test unrestricted follow at a close zoom; wider views clamp at arena edges.
	rig.set_zoom(1.5)
	rig.snap()
	var basis_before := world.camera.global_basis
	world.player.position = Vector3(4, 0, 2)
	settle()
	assert_almost_eq(rig.focus.x, 4.0, .05)
	assert_almost_eq(rig.focus.z, 2.0, .05)
	assert_eq(world.camera.global_basis, basis_before, "Only translation may change; movement is camera-relative")
	assert_almost_eq(world.camera.position.x, rig.focus.x, .001)

func test_wave_targets_closer_combat_zoom() -> void:
	var previous := rig.visible_half_extents(1.5)
	var current := rig.visible_half_extents(GameConstants.CAMERA_ZOOM_MIN)
	assert_almost_eq(current.x * current.y / (previous.x * previous.y), 6.25, .001)
	assert_eq(rig.target_zoom, GameConstants.CAMERA_DEFAULT_ZOOM)

func test_zoom_is_clamped_and_changes_orthographic_size() -> void:
	rig.set_zoom(100.0)
	assert_eq(rig.target_zoom, GameConstants.CAMERA_ZOOM_MAX)
	rig.set_zoom(0.0)
	assert_eq(rig.target_zoom, GameConstants.CAMERA_ZOOM_MIN)
	rig.set_zoom(1.0)
	settle(240)
	var normal_size := world.camera.size
	rig.set_zoom(2.0)
	settle(240)
	assert_almost_eq(world.camera.size, normal_size / 2.0, .01)

func test_wheel_zoom_steps_in_and_out() -> void:
	rig.set_zoom(1.0) # Start away from zoom limits.
	var start := rig.target_zoom
	rig.zoom_steps(1.0)
	assert_gt(rig.target_zoom, start)
	rig.zoom_steps(-2.0)
	assert_lt(rig.target_zoom, start)

func test_view_never_leaves_the_arena_at_any_corner_zoom_or_aspect() -> void:
	for aspect in [1.0, 16.0 / 9.0, 32.0 / 9.0]:
		rig.aspect = aspect
		for zoom_value in [GameConstants.CAMERA_ZOOM_MIN, 1.0, GameConstants.CAMERA_ZOOM_MAX]:
			for corner in [Vector3(-100, 0, -100), Vector3(100, 0, -100), Vector3(-100, 0, 100), Vector3(100, 0, 100)]:
				var focus := rig.clamp_focus(corner, zoom_value)
				var half := rig.visible_half_extents(zoom_value)
				var allowed := WorldGeometry.HALF_ARENA + Vector2.ONE * (GameConstants.CAMERA_EDGE_MARGIN + .001)
				assert_true(abs(focus.x) + half.x <= allowed.x or focus.x == 0.0, "x aspect %s zoom %s" % [aspect, zoom_value])
				assert_true(abs(focus.z) + half.y <= allowed.y or focus.z == 0.0, "z aspect %s zoom %s" % [aspect, zoom_value])

func test_camera_recentres_when_the_view_is_larger_than_the_arena() -> void:
	rig.aspect = 64.0 / 9.0
	assert_eq(rig.clamp_focus(Vector3(20, 0, 0), GameConstants.CAMERA_ZOOM_MIN).x, 0.0)

func test_player_at_the_edge_keeps_view_inside_the_floor() -> void:
	world.player.position = WorldGeometry.clamp_position(Vector3(100, 0, 100))
	settle(240)
	assert_true(visible_ground_inside_arena(rig.zoom))
	assert_lt(rig.focus.x, WorldGeometry.HALF_ARENA.x)

func test_enemy_spawns_stay_inside_the_arena_and_away_from_the_player() -> void:
	for player_at in [Vector3.ZERO, Vector3(27, 0, 15), Vector3(-27, 0, -15)]:
		world.player.position = WorldGeometry.clamp_position(player_at)
		for i in 40:
			var at := world._spawn_position()
			assert_eq(at, WorldGeometry.clamp_position(at), "spawn must be within the arena")
			assert_gt(WorldGeometry.planar(at - world.player.position).length(), 2.0, "never spawn on top of the player")

func test_survive_arrivals_are_scattered_over_the_whole_arena() -> void:
	assert_null(world.core)
	GameRandom.gameplay.seed = 4411
	world.player.position = Vector3.ZERO
	for kind in ["drowse", "basic", "fast", "kite", "lobber", "tender"]:
		var quadrants := {}
		var far := 0
		for i in 80:
			var at := world.waves._sample_encounter_position(kind)
			assert_eq(at, WorldGeometry.clamp_position(at), kind + " inside the arena")
			assert_gte(at.distance_to(world.player.position), GameConstants.ENEMY_SPAWN_MIN_DISTANCE, kind + " keeps clear of the hero")
			quadrants[Vector2i(int(signf(at.x)), int(signf(at.z)))] = true
			if at.distance_to(world.player.position) > 8.0: far += 1
		assert_eq(quadrants.size(), 4, kind + " arrives from every part of the map")
		assert_gt(far, 10, kind + " is not confined to a ring around the hero")

func test_turret_placement_search_starts_from_the_player() -> void:
	world.player.position = Vector3(10, 0, 8)
	var at := world.find_placement()
	assert_lt(WorldGeometry.planar(at - world.player.position).length(), 8.0)

func test_snap_clears_old_camera_interpolation_history() -> void:
	world.camera.get_global_transform_interpolated()
	world.player.position = Vector3(4, 0, 2)
	rig.snap()
	assert_almost_eq(world.camera.get_global_transform_interpolated().origin, world.camera.global_position, Vector3.ONE * .001, "Snapping must not sweep from the old view")

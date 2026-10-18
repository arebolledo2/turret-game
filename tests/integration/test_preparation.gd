extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_flags()
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	world.run_config = RunConfig.new()
	world.run_config.mode = RunConfig.MODE_CONVOY
	add_child_autofree(world)
	world.start_run()
	world.set_physics_process(false)
	world.preparation.set_physics_process(false)

func test_initial_preparation_is_unlimited_and_hero_is_hidden() -> void:
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.PREPARATION)
	assert_false(world.player.visible)
	var time := world.waves.time_left
	var lived := GameStateService.time_survived
	var core_at := world.core.position
	var stay := world.turrets[0].stay_time
	world._physics_process(1000.0)
	world.waves.tick(1000.0)
	world.turrets[0]._physics_process(1000.0)
	assert_eq(world.waves.time_left, time)
	assert_eq(GameStateService.time_survived, lived)
	assert_eq(world.core.position, core_at)
	assert_eq(world.turrets[0].stay_time, stay, "no free entrenchment while preparing")
	assert_true(world.enemies.is_empty())
	assert_true(world.waves.pending_spawns.is_empty())

func test_invalid_move_cannot_commit_or_deploy_and_cancel_restores_entrenchment() -> void:
	var turret := world.turrets[0]
	var origin := turret.position
	turret.stay_time = 20.0
	turret.entrench_stacks_cached = 2
	assert_true(world.preparation.interact())
	world.preparation.set_cursor(world.core.position)
	assert_false(world.preparation.interact())
	assert_false(world.preparation.deploy())
	world.preparation.cancel_move()
	assert_eq(turret.position, origin)
	assert_eq(turret.stay_time, 20.0)
	assert_eq(turret.entrench_stacks_cached, 2)

func test_valid_move_is_free_and_resets_entrenchment_only_on_commit() -> void:
	var turret := world.turrets[0]
	turret.stay_time = 20.0
	var scrap := EconomyService.total_scrap
	world.preparation.interact()
	world.preparation.set_cursor(Vector3(4, 0, 0))
	assert_true(world.preparation.interact())
	assert_eq(turret.position, Vector3(4, 0, 0))
	assert_eq(turret.stay_time, 0.0)
	assert_eq(EconomyService.total_scrap, scrap)
	assert_false(world.preparation.moving)

func test_cursor_respects_bounds_and_other_turrets() -> void:
	var second := world.add_turret(Vector3(5, 0, 0), "plasma")
	world.preparation.interact()
	world.preparation.set_cursor(second.position)
	assert_false(world.preparation.interact())
	world.preparation.set_cursor(Vector3(999, 0, 999))
	assert_lte(world.preparation.cursor.x, WorldGeometry.HALF_ARENA.x - TurretPlacement.EDGE_MARGIN + .001)
	assert_lte(world.preparation.cursor.z, WorldGeometry.HALF_ARENA.y - TurretPlacement.EDGE_MARGIN + .001)

func test_controller_cycles_moves_cancels_and_explicitly_deploys() -> void:
	var second := world.add_turret(Vector3(5, 0, 0), "plasma")
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	assert_true(world.preparation.handle_input(event))
	assert_eq(world.preparation.selected, second)
	assert_eq(world.camera_rig._follow_point(), second.position)
	event.button_index = JOY_BUTTON_A
	world.preparation.handle_input(event)
	assert_true(world.preparation.moving)
	event.button_index = JOY_BUTTON_X
	world.preparation.handle_input(event)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.PREPARATION)
	event.button_index = JOY_BUTTON_B
	world.preparation.handle_input(event)
	assert_false(world.preparation.moving)
	event.button_index = JOY_BUTTON_X
	world.preparation.handle_input(event)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_ANNOUNCEMENT)
	assert_true(world.player.visible)
	assert_false(world.preparation.active)
	assert_false(world.preparation.deploy(), "duplicate activation cannot start another wave")
	assert_eq(GameStateService.current_wave, 1)
	world.waves.tick(1.0)
	assert_true(world.is_combat())

func test_shop_enters_another_prep_and_restart_discards_uncommitted_move() -> void:
	world.preparation.deploy()
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	assert_true(world.finish_wave())
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)
	assert_true(world.begin_next_wave())
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.PREPARATION)
	assert_false(world.player.visible)
	assert_eq(GameStateService.current_wave, 2)
	world.preparation.interact()
	world.preparation.set_cursor(Vector3(4, 0, 0))
	world.start_run()
	assert_false(world.preparation.moving)
	assert_eq(GameStateService.current_wave, 1)
	assert_eq(world.preparation.selected, world.turrets[0])

func test_pause_blocks_placement_and_deploy() -> void:
	world.toggle_pause()
	assert_false(world.preparation.interact())
	assert_false(world.preparation.deploy())
	assert_false(world.player.visible)
	world.toggle_pause()
	assert_true(world.preparation.deploy())

func test_mouse_click_selects_and_places_using_ground_projection() -> void:
	world.camera_rig.snap()
	await wait_process_frames(2)
	var turret := world.turrets[0]
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = world.camera.unproject_position(turret.position)
	assert_true(world.preparation.handle_input(event))
	assert_true(world.preparation.moving)
	var destination := Vector3(4, 0, 0)
	event.position = world.camera.unproject_position(destination)
	assert_true(world.preparation.handle_input(event))
	assert_false(world.preparation.moving)
	assert_lt(turret.position.distance_to(destination), .01)

func test_gamepad_stick_moves_cursor_and_carried_turret() -> void:
	var prep := world.preparation
	prep.interact()
	var start := prep.cursor
	Input.action_press("gamepad_right", .8)
	prep._physics_process(.2)
	Input.action_release("gamepad_right")
	assert_gt(prep.cursor.x, start.x)
	assert_eq(prep.selected.position, prep.cursor)
	assert_eq(prep.view_focus, prep.cursor)
	var stopped := prep.cursor
	prep._physics_process(.2)
	assert_eq(prep.cursor, stopped, "Releasing the stick stops movement")

func test_playfield_reserves_ui_space_and_mouse_projection_roundtrips() -> void:
	world.playfield = PlayfieldView.new()
	world.playfield.world = world
	world.add_child(world.playfield)
	world.camera_rig.snap()
	await wait_process_frames(2)
	var field := world.playfield
	var size := get_viewport().get_visible_rect().size
	assert_eq(field.rect.position.y, PlayfieldView.TOP)
	assert_eq(field.rect.end.y, size.y - PlayfieldView.BOTTOM)
	assert_eq(world.camera.get_viewport(), field.viewport)
	assert_almost_eq(world.camera_rig.aspect, float(field.viewport.size.x) / field.viewport.size.y, .001)
	var turret := world.turrets[0]
	var event := InputEventMouseButton.new()
	event.pressed = true
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(10, 10)
	assert_false(world.preparation.handle_input(event), "UI rail cannot place a turret")
	event.position = field.to_screen(turret.position)
	assert_true(world.preparation.handle_input(event))
	assert_true(world.preparation.moving)
	var at := Vector3(4, 0, 0)
	event.position = field.to_screen(at)
	world.preparation.handle_input(event)
	assert_lt(turret.position.distance_to(at), .01)
	assert_false(world.preparation.moving)

func test_spawn_zone_restriction_is_optional_and_blocks_deploy_until_cleared() -> void:
	var turret := world.turrets[0]
	world.spawn_zones.centres.assign([turret.position])
	FeatureFlagService.set_enabled(FeatureFlagService.RESTRICT_SPAWN_PLACEMENT, false)
	assert_true(world.valid_placement(turret.position, turret))
	FeatureFlagService.set_enabled(FeatureFlagService.RESTRICT_SPAWN_PLACEMENT, true)
	assert_false(world.valid_placement(turret.position, turret))
	assert_false(world.preparation.deploy())
	world.preparation.arrange_turrets()
	assert_true(world.valid_placement(turret.position, turret))
	assert_true(world.preparation.deploy())

func test_auto_layout_covers_zones_and_distributes_remaining_along_route() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.RESTRICT_SPAWN_PLACEMENT, true)
	world.spawn_zones.centres.assign([Vector3(-8, 0, -5), Vector3(8, 0, 5)])
	for i in 5: world.add_turret(Vector3(i * 2, 0, -9), "normal")
	world.preparation.arrange_turrets()
	for i in world.turrets.size():
		var turret := world.turrets[i]
		assert_true(world.valid_placement(turret.position, turret))
		assert_false(world.placement.spawn_zone_blocked(turret.position))
		if i < 2:
			assert_lt(turret.position.distance_to(world.spawn_zones.centres[i]), 4.5)
	assert_true(world.preparation.active, "arranging never starts the wave")
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.PREPARATION)

func test_auto_layout_runs_on_next_preparation_and_supports_no_core() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.AUTO_DEPLOY, true)
	world.core.queue_free()
	world.core = null
	world.convoy_mode = false
	world.spawn_zones.centres.clear()
	world.turrets[0].position = Vector3(10, 0, 8)
	world.preparation.begin()
	assert_lt(world.turrets[0].position.length(), 3.0)
	assert_true(world.preparation.active)

func test_unrestricted_auto_layout_uses_exact_spawn_centres() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.RESTRICT_SPAWN_PLACEMENT, false)
	world.spawn_zones.centres.assign([Vector3(-8.13, 0, -5.17), Vector3(8.21, 0, 5.12)])
	world.add_turret(Vector3(5, 0, -9), "normal")
	world.preparation.arrange_turrets()
	for i in 2:
		assert_eq(world.turrets[i].position, world.spawn_zones.centres[i])
		assert_true(world.valid_placement(world.turrets[i].position, world.turrets[i]))

func test_area_layout_separates_attack_ranges_and_balanced_keeps_centre_covered() -> void:
	world.convoy_mode = false
	world.core.position = Vector3.ZERO
	world.spawn_zones.centres.clear()
	for i in 3: world.add_turret(Vector3(i * 2, 0, -8), "normal")
	SettingsService.auto_prepare_mode = 2
	world.preparation.arrange_turrets()
	for i in world.turrets.size():
		for j in range(i):
			var reach := TurretLayoutSolver.new(world).attack_reach(world.turrets[i]) + TurretLayoutSolver.new(world).attack_reach(world.turrets[j])
			assert_gte(world.turrets[i].position.distance_to(world.turrets[j].position), reach - .05)
	SettingsService.auto_prepare_mode = 1
	world.preparation.arrange_turrets()
	var centre_covered := false
	for turret in world.turrets:
		if turret.position.length() <= TurretLayoutSolver.new(world).attack_reach(turret): centre_covered = true
	assert_true(centre_covered)
	SettingsService.auto_prepare_mode = 0

func test_area_layout_packs_mixed_ranges_without_grid_gaps() -> void:
	world.convoy_mode = false
	world.core.position = Vector3.ZERO
	world.spawn_zones.centres.clear()
	for type_id: String in ["melee", "bow", "plasma", "shock", "bowling"]:
		world.add_turret(Vector3(12, 0, 8), type_id)
	SettingsService.auto_prepare_mode = 2
	world.preparation.arrange_turrets()
	for i in world.turrets.size():
		var turret := world.turrets[i]
		assert_true(world.valid_placement(turret.position, turret))
		if i == 0: continue
		var nearest_gap := INF
		for j in range(i):
			var other := world.turrets[j]
			var gap := turret.position.distance_to(other.position) - TurretLayoutSolver.new(world).attack_reach(turret) - TurretLayoutSolver.new(world).attack_reach(other)
			assert_gte(gap, -.05, "Attack circles should not materially overlap")
			nearest_gap = minf(nearest_gap, gap)
		assert_lt(nearest_gap, .08, "Each added turret joins the coverage instead of leaving a grid-sized gap")
	SettingsService.auto_prepare_mode = 0

func test_playfield_scaled_projection_roundtrips() -> void:
	world.playfield = PlayfieldView.new()
	world.playfield.world = world
	world.add_child(world.playfield)
	var field := world.playfield
	# Exercise a non-unit pixel ratio independent of the headless window size.
	field.viewport.size = Vector2i(2560, 1339)
	world.camera_rig.refresh_aspect()
	world.camera_rig.snap()
	var point := Vector3(4, 0, 0)
	var pixel := field.to_viewport(field.to_screen(point))
	var origin := world.camera.project_ray_origin(pixel)
	var direction := world.camera.project_ray_normal(pixel)
	var hit: Vector3 = Plane(Vector3.UP, 0).intersects_ray(origin, direction)
	assert_lt(hit.distance_to(point), .001)

func test_preparation_resets_overview_and_deploy_eases_to_combat_zoom() -> void:
	world.player.position = Vector3(10, 0, -8)
	world.player.velocity = Vector3(2, 0, 1)
	world.player.knockback_velocity = Vector3(3, 0, 2)
	world.camera_rig.set_zoom(1.8)
	world.camera_rig.snap()
	world.preparation.begin()
	assert_eq(world.player.position, Vector3.ZERO, "Convoy hero starts at centre, not at the route entrance")
	assert_eq(world.player.velocity, Vector3.ZERO)
	assert_eq(world.player.knockback_velocity, Vector3.ZERO)
	assert_eq(world.preparation.view_focus, Vector3.ZERO)
	assert_eq(world.camera_rig.zoom, GameConstants.CAMERA_ZOOM_MIN)
	assert_eq(world.camera_rig.focus, Vector3.ZERO)
	world.camera_rig.set_zoom(.8)
	world.camera_rig.snap()
	world.preparation.cycle(1)
	assert_true(world.preparation.deploy())
	assert_eq(world.camera_rig.zoom, .8, "Deploy begins its transition at the current zoom")
	assert_eq(world.camera_rig.focus, Vector3.ZERO)
	assert_eq(world.camera_rig.target_zoom, GameConstants.CAMERA_DEFAULT_ZOOM)
	world.camera_rig.advance(1.0)
	assert_almost_eq(world.camera_rig.zoom, GameConstants.CAMERA_DEFAULT_ZOOM, .001)
	assert_true(world.player.visible)

func test_core_at_centre_keeps_hero_clear_and_survival_starts_at_origin() -> void:
	world.convoy_mode = false
	world.core.position = Vector3.ZERO
	world.preparation.begin()
	assert_eq(world.player.position, Vector3(0, 0, GameConstants.CORE_START_OFFSET))
	assert_gt(world.player.position.distance_to(world.core.position), world.core.radius + world.player.hurtbox_radius())
	world.core.queue_free()
	world.core = null
	world.preparation.begin()
	assert_eq(world.player.position, Vector3.ZERO)

func test_saved_layout_restores_positions_and_stages_new_turrets() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.RESTRICT_SPAWN_PLACEMENT, false)
	var prep := world.preparation
	var first := world.turrets[0]
	first.position = Vector3(4, 0, 0)
	prep.save_layout()
	assert_eq(SettingsService.auto_prepare_mode, 4)
	first.position = Vector3(-4, 0, 0)
	var second := world.add_turret(Vector3(7, 0, 0), "plasma")
	prep.begin()
	assert_eq(first.position, Vector3(4, 0, 0))
	assert_lt(second.position.length(), 3.0)
	assert_true(prep.new_markers.has(second.turret_id))
	assert_false(prep.new_markers.has(first.turret_id))
	assert_true(world.valid_placement(second.position, second))
	assert_true(prep.deploy())
	assert_true(prep.saved_positions.has(second.turret_id))
	assert_true(prep.new_markers.is_empty())
	SettingsService.auto_prepare_mode = 0

func test_saved_layout_relocates_blocked_spot_and_resets_for_new_run() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.RESTRICT_SPAWN_PLACEMENT, false)
	var prep := world.preparation
	var turret := world.turrets[0]
	prep.saved_positions[turret.turret_id] = world.core.position
	SettingsService.auto_prepare_mode = 4
	prep.arrange_turrets()
	assert_true(world.valid_placement(turret.position, turret))
	assert_gt(turret.position.distance_to(world.core.position), world.core.radius)
	world.start_run()
	assert_true(prep.saved_positions.is_empty())
	SettingsService.auto_prepare_mode = 0

func test_max_spread_separates_turrets_and_respects_exclusions() -> void:
	for i in 5: world.add_turret(Vector3(3 + i, 0, 0), "normal")
	FeatureFlagService.set_enabled(FeatureFlagService.RESTRICT_SPAWN_PLACEMENT, true)
	SettingsService.auto_prepare_mode = 3
	world.preparation.arrange_turrets()
	var positions: Array[Vector3] = []
	for turret in world.turrets:
		assert_true(world.valid_placement(turret.position, turret))
		assert_gt(TurretLayoutSolver.new(world)._nearest_distance(turret.position, turret), 25.0)
		assert_gt(TurretLayoutSolver.new(world)._spread_clearance(turret.position, turret), 2.5)
		positions.append(turret.position)
	world.preparation.arrange_turrets()
	for i in world.turrets.size(): assert_eq(world.turrets[i].position, positions[i])
	SettingsService.auto_prepare_mode = 0

func test_controller_can_save_layout() -> void:
	var event := InputEventJoypadButton.new()
	event.pressed = true
	event.button_index = JOY_BUTTON_LEFT_STICK
	assert_true(world.preparation.handle_input(event))
	assert_true(world.preparation.saved_positions.has(world.turrets[0].turret_id))
	SettingsService.auto_prepare_mode = 0

func test_max_spread_four_turrets_balance_quadrants_and_walls() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.RESTRICT_SPAWN_PLACEMENT, false)
	# Isolate the spacing objective from terrain and core placement restrictions.
	world.terrain = null
	world.core.position = Vector3(100, 0, 100)
	for i in 3: world.add_turret(Vector3(3 + i, 0, 0), "normal")
	SettingsService.auto_prepare_mode = 3
	world.preparation.arrange_turrets()
	var quadrants: Dictionary = {}
	for turret in world.turrets:
		quadrants[Vector2(signf(turret.position.x), signf(turret.position.z))] = true
		assert_almost_eq(absf(turret.position.x), WorldGeometry.HALF_ARENA.x * .5, .3)
		assert_almost_eq(absf(turret.position.z), WorldGeometry.HALF_ARENA.y * .5, .3)
		assert_true(world.valid_placement(turret.position, turret))
	assert_eq(quadrants.size(), 4)
	SettingsService.auto_prepare_mode = 0

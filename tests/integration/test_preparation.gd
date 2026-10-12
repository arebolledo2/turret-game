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
	assert_almost_eq(world.camera_rig.aspect, field.rect.size.x / field.rect.size.y, .001)
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

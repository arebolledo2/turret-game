extends GutTest

## Unit tests for Escort Game Mode

func before_each() -> void:
	GameModeService.reset_state()
	GameStateMachine.reset()

func test_escort_mode_activation() -> void:
	GameModeService.set_mode(GameEnums.GameMode.ESCORT)
	assert_true(GameModeService.is_escort_mode_active(), "Escort mode should be active")
	assert_true(GameModeService.is_mode_active(GameEnums.GameMode.ESCORT), "Escort mode should be in active_modes")

func test_path_generation() -> void:
	var path = GameModeService.generate_escort_path()
	assert_gt(path.size(), 2, "Path should have at least start, middle, and end points")
	
	# Verify points are within arena bounds (approximate)
	var hh = GameConstants.ARENA_HEIGHT / 2.0
	var hw = GameConstants.ARENA_WIDTH / 2.0
	
	for point in path:
		assert_between(point.x, -hw - 200, hw + 200, "Point X should be within bounds")
		assert_between(point.y, -hh - 200, hh + 200, "Point Y should be within bounds")

func test_escort_initialization() -> void:
	var target = load("res://scenes/defense_target.tscn").instantiate()
	add_child_autofree(target)

	var path: Array[Vector2] = [Vector2(0, 0), Vector2(100, 0), Vector2(200, 0)]
	target.initialize_escort(path)

	assert_true(target.is_escort_mode, "Target should be in escort mode")
	assert_eq(target.escort_path.size(), 3, "Target should have the path")
	assert_not_null(target.escort_curve, "Escort curve should be initialized")

func test_escort_wave_progress_movement() -> void:
	var target = load("res://scenes/defense_target.tscn").instantiate()
	add_child_autofree(target)
	target.global_position = Vector2(0, 0)

	var path: Array[Vector2] = [Vector2(0, 0), Vector2(200, 0), Vector2(400, 0)]
	target.initialize_escort(path)

	# Mock wave controller
	var mock_controller = Node.new()
	mock_controller.set_script(load("res://scripts/wave_controller.gd"))
	GameStateService.wave_controller = mock_controller
	add_child_autofree(mock_controller)

	GameStateMachine.current_state = GameStateMachine.GameState.COMBAT

	# Simulate wave at 50% progress (50% time remaining)
	mock_controller.wave_max_duration = 100.0
	mock_controller.wave_timer = 50.0  # 50% progress (1.0 - 50/100 = 0.5)

	target._physics_process(0.1)

	# At 50% progress, should be approximately at midpoint of path
	assert_true(target.is_moving, "Should be moving during combat")
	assert_gt(target.global_position.x, 50, "Should have moved forward along curve")
	assert_lt(target.global_position.x, 350, "Should not have reached end yet")

func test_escort_reaches_destination() -> void:
	var target = load("res://scenes/defense_target.tscn").instantiate()
	add_child_autofree(target)
	target.global_position = Vector2(0, 0)

	var path: Array[Vector2] = [Vector2(0, 0), Vector2(100, 0), Vector2(200, 0)]
	target.initialize_escort(path)

	# Mock wave controller
	var mock_controller = Node.new()
	mock_controller.set_script(load("res://scripts/wave_controller.gd"))
	GameStateService.wave_controller = mock_controller
	add_child_autofree(mock_controller)

	GameStateMachine.current_state = GameStateMachine.GameState.COMBAT

	# Test at various progress levels
	mock_controller.wave_max_duration = 100.0

	# At 50% progress
	mock_controller.wave_timer = 50.0
	target._physics_process(0.1)
	assert_false(target.is_at_destination(), "Should not be at destination at 50%")

	# At 90% progress
	mock_controller.wave_timer = 10.0
	target._physics_process(0.1)
	assert_false(target.is_at_destination(), "Should not be at destination at 90%")

	# At 100% progress - reaches destination
	mock_controller.wave_timer = 0.0
	assert_true(target.is_at_destination(), "Should be at destination at 100%")

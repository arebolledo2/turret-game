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
	assert_gt(target.escort_speed, 0, "Speed should be greater than 0")

func test_escort_proximity_movement() -> void:
	var target = load("res://scenes/defense_target.tscn").instantiate()
	add_child_autofree(target)
	target.global_position = Vector2(0, 0)
	
	var path: Array[Vector2] = [Vector2(0, 0), Vector2(100, 0)]
	target.initialize_escort(path)
	
	# Mock player
	var player = Node2D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	
	GameStateMachine.current_state = GameStateMachine.GameState.COMBAT
	
	# Player far away
	player.global_position = Vector2(500, 500)
	target._physics_process(0.1)
	assert_false(target.is_moving, "Should not move if player is far away")
	assert_eq(target.global_position, Vector2(0, 0), "Position should not change")
	
	# Player close
	player.global_position = Vector2(50, 0)
	print("DEBUG: Player pos: ", player.global_position, " Target pos: ", target.global_position)
	target._physics_process(1.0) # Will move at escort_speed * 1.0
	print("DEBUG: Target pos after move: ", target.global_position, " Speed: ", target.escort_speed)
	assert_true(target.is_moving, "Should move if player is close")
	assert_gt(target.global_position.x, 0, "Position should have moved forward")

func test_escort_reaches_destination() -> void:
	var target = load("res://scenes/defense_target.tscn").instantiate()
	add_child_autofree(target)
	target.global_position = Vector2(0, 0)
	
	var path: Array[Vector2] = [Vector2(0, 0), Vector2(10, 0)]
	target.initialize_escort(path)
	
	# Mock player close
	var player = Node2D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	player.global_position = Vector2(0, 0)
	
	GameStateMachine.current_state = GameStateMachine.GameState.COMBAT
	
	watch_signals(Events)
	
	# Move in smaller steps
	var steps = 10
	var step_delta = 41.0 / steps
	for i in range(steps):
		print("DEBUG: Step ", i, " Pos: ", target.global_position, " Index: ", target.current_path_index)
		target._physics_process(step_delta)
	
	print("DEBUG: Final Pos: ", target.global_position, " Index: ", target.current_path_index, " Size: ", target.escort_path.size())
	assert_true(target.is_at_destination(), "Should be at destination")
	assert_signal_emitted(Events, "escort_reached_destination")

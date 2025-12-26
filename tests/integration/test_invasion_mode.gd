extends GutTest

func before_each() -> void:
	GameStateService.reset_state()
	GameModeService.reset_state()
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	# Set rectangular arena mode for consistent test expectations
	GameModeService.set_mode(GameEnums.GameMode.ARENA_RECTANGULAR)

func test_sentinel_mode_spawn_positions():
	# Sentinel is default
	assert_true(GameModeService.is_mode_active(GameEnums.GameMode.SENTINEL), "Sentinel should be active by default")
	
	var spawn_zones = _get_mock_spawn_zones()
	
	# Sample many positions to ensure they are all in zones
	for i in range(100):
		var pos = GameModeService.get_random_spawn_position(spawn_zones)
		var in_any_zone = false
		for zone in spawn_zones:
			if zone.has_point(pos):
				in_any_zone = true
				break
		assert_true(in_any_zone, "Spawn position %s should be in one of the edge zones" % pos)

func test_invasion_mode_spawn_positions():
	# Switch to Invasion mode
	GameModeService.set_mode(GameEnums.GameMode.INVASION)
	assert_true(GameModeService.is_mode_active(GameEnums.GameMode.INVASION), "Invasion should be active after setting it")
	
	var half_width = GameConstants.ARENA_WIDTH / 2.0
	var half_height = GameConstants.ARENA_HEIGHT / 2.0
	var inset = 40.0
	
	# Sample many positions to ensure they are within the arena bounds
	var found_middle = false
	var positions = []
	for i in range(200):
		var pos = GameModeService.get_random_spawn_position([])
		positions.append(pos)
		
		# Check bounds
		assert_true(pos.x >= -half_width + inset and pos.x <= half_width - inset, "X position %f out of bounds" % pos.x)
		assert_true(pos.y >= -half_height + inset and pos.y <= half_height - inset, "Y position %f out of bounds" % pos.y)
		
		# Check if it's in the "middle" (away from edges)
		if abs(pos.x) < (half_width - 300) and abs(pos.y) < (half_height - 300):
			found_middle = true
			
	assert_true(found_middle, "Invasion mode should have spawned at least some enemies in the middle of the arena. Positions: %s" % str(positions))

func _get_mock_spawn_zones() -> Array[Rect2]:
	var half_width := GameConstants.ARENA_WIDTH / 2.0
	var half_height := GameConstants.ARENA_HEIGHT / 2.0
	var zone_depth := 200.0
	var inset := 20.0
	
	var zones: Array[Rect2] = []
	zones.append(Rect2(-half_width + inset, -half_height + inset, GameConstants.ARENA_WIDTH - (inset * 2), zone_depth))
	zones.append(Rect2(-half_width + inset, half_height - inset - zone_depth, GameConstants.ARENA_WIDTH - (inset * 2), zone_depth))
	zones.append(Rect2(-half_width + inset, -half_height + inset, zone_depth, GameConstants.ARENA_HEIGHT - (inset * 2)))
	zones.append(Rect2(half_width - inset - zone_depth, -half_height + inset, zone_depth, GameConstants.ARENA_HEIGHT - (inset * 2)))
	return zones

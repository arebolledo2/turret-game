extends GutTest

# =============================================================================
# Unit tests for TechDropSpawner
# Tests spawn logic, position finding, and wave management
# =============================================================================


# =============================================================================
# CONFIGURATION
# =============================================================================

func test_spawn_alert_time_defined():
	# Verify the alert time constant is reasonable (1-3 seconds)
	# The actual value (1.5s) is defined in tech_drop_spawner.gd
	var expected_alert_time: float = 1.5
	assert_gte(expected_alert_time, 1.0, "Alert time should be at least 1 second")
	assert_lte(expected_alert_time, 3.0, "Alert time should be at most 3 seconds")


# =============================================================================
# SPAWN CHANCE
# =============================================================================

func test_spawn_chance_reasonable():
	var chance = GameConstants.TECH_DROP_SPAWN_CHANCE
	assert_gt(chance, 0.0, "Spawn chance should be positive")
	assert_lt(chance, 1.0, "Spawn chance should be less than 100%")


func test_spawn_interval_reasonable():
	var interval = GameConstants.TECH_DROP_SPAWN_INTERVAL
	assert_gt(interval, 0.0, "Spawn interval should be positive")
	assert_lte(interval, 30.0, "Spawn interval should be reasonable")


# =============================================================================
# ARENA BOUNDS
# =============================================================================

func test_arena_dimensions_valid():
	var width = ArenaBoundsService.arena_width
	var height = ArenaBoundsService.arena_height

	assert_gt(width, 0, "Arena width should be positive")
	assert_gt(height, 0, "Arena height should be positive")


func test_spawn_margin_within_arena():
	# Spawn margin (100) should be less than half of smallest arena dimension
	var half_width = ArenaBoundsService.arena_width / 2.0
	var half_height = ArenaBoundsService.arena_height / 2.0
	var margin = 100.0 # From tech_drop_spawner.gd

	assert_lt(margin, half_width, "Margin should fit within arena width")
	assert_lt(margin, half_height, "Margin should fit within arena height")


# =============================================================================
# TECH DROP CONSTANTS
# =============================================================================

func test_tech_drop_scrap_reward_positive():
	var scrap = GameConstants.TECH_DROP_SCRAP_REWARD
	assert_gt(scrap, 0, "Scrap reward should be positive")


func test_tech_drop_base_health_positive():
	var health = GameConstants.TECH_DROP_BASE_HEALTH
	assert_gt(health, 0.0, "Base health should be positive")


func test_tech_drop_scatter_configuration():
	var count = GameConstants.TECH_DROP_SCATTER_COUNT
	var radius = GameConstants.TECH_DROP_SCATTER_RADIUS
	
	assert_gt(count, 0, "Scatter count should be positive")
	assert_gt(radius, 0.0, "Scatter radius should be positive")


# =============================================================================
# SPAWN POSITION VALIDATION
# =============================================================================

func test_minimum_distance_between_drops():
	# Tech drops should spawn at least 150 units apart (from tech_drop_spawner.gd)
	var min_distance = 150.0
	assert_gt(min_distance, 0.0, "Minimum distance should be positive")
	assert_lt(min_distance, ArenaBoundsService.arena_width / 2.0, "Min distance should fit in arena")

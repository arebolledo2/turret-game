extends GutTest

# =============================================================================
# Unit tests for EnemyRegistry
# Tests enemy type definitions, and wave scaling
# =============================================================================


# =============================================================================
# TYPE DEFINITIONS
# =============================================================================

func test_all_enemy_types_exist():
	var expected_types = ["basic", "fast", "tank", "exploder", "lazy_wanderer", "charger", "neon_drone"]
	for type_id in expected_types:
		assert_has(EnemyRegistry.TYPES, type_id, "Enemy type '%s' should exist" % type_id)


func test_get_all_type_ids():
	var ids = EnemyRegistry.get_all_type_ids()
	assert_gt(ids.size(), 0, "Should return at least one type ID")
	assert_has(ids, "basic", "Should include 'basic' type")


# =============================================================================
# BASE STATS
# =============================================================================

func test_get_base_stats_returns_required_fields():
	var stats = EnemyRegistry.get_base_stats("basic")
	assert_has(stats, "health", "Base stats should have health")
	assert_has(stats, "speed", "Base stats should have speed")
	assert_has(stats, "contact_damage", "Base stats should have contact_damage")
	assert_has(stats, "scrap_value", "Base stats should have scrap_value")


func test_get_base_stats_returns_copy():
	var stats1 = EnemyRegistry.get_base_stats("basic")
	var stats2 = EnemyRegistry.get_base_stats("basic")

	stats1["health"] = 9999.0

	assert_ne(stats2["health"], 9999.0, "get_base_stats should return a copy, not reference")


func test_get_base_stats_fallback_for_invalid():
	var stats = EnemyRegistry.get_base_stats("nonexistent")
	var basic_stats = EnemyRegistry.get_base_stats("basic")
	assert_eq(stats["health"], basic_stats["health"], "Invalid type should fall back to basic stats")


func test_each_enemy_type_has_valid_stats():
	for type_id in EnemyRegistry.get_all_type_ids():
		var stats = EnemyRegistry.get_base_stats(type_id)
		assert_gt(stats["health"], 0.0, "%s should have positive health" % type_id)
		assert_gte(stats["speed"], 0.0, "%s should have non-negative speed" % type_id)
		assert_gte(stats["contact_damage"], 0.0, "%s should have non-negative damage" % type_id)


# =============================================================================
# WAVE SCALING - HEALTH
# =============================================================================

func test_health_scaling_wave_1_easy():
	var easy_config = DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = EnemyRegistry.get_stats_for_wave("basic", 1, easy_config)
	var base_stats = EnemyRegistry.get_base_stats("basic")

	# Wave 1 with easy: base * 1.0 * 1.1^0 = base
	assert_eq(stats["health"], base_stats["health"], "Wave 1 Easy should have base health")


func test_health_scaling_exponential():
	var easy_config = DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var wave1_stats = EnemyRegistry.get_stats_for_wave("basic", 1, easy_config)
	var wave5_stats = EnemyRegistry.get_stats_for_wave("basic", 5, easy_config)

	# Wave 5: health * 1.1^4
	var expected_ratio = pow(easy_config["enemy_hp_scale_per_wave"], 4)
	var actual_ratio = wave5_stats["health"] / wave1_stats["health"]

	assert_almost_eq(actual_ratio, expected_ratio, 0.01,
		"Health should scale exponentially per wave")


func test_health_scaling_with_difficulty():
	var easy_config = DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var hard_config = DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.HARD]

	var easy_stats = EnemyRegistry.get_stats_for_wave("basic", 3, easy_config)
	var hard_stats = EnemyRegistry.get_stats_for_wave("basic", 3, hard_config)

	assert_gt(hard_stats["health"], easy_stats["health"],
		"Hard mode enemies should have more health")


func test_health_scaling_different_enemy_types():
	var easy_config = DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]

	var basic_stats = EnemyRegistry.get_stats_for_wave("basic", 3, easy_config)
	var tank_stats = EnemyRegistry.get_stats_for_wave("tank", 3, easy_config)

	# Tank should have more health than basic at same wave
	assert_gt(tank_stats["health"], basic_stats["health"],
		"Tank should have more health than basic enemy")


# =============================================================================
# WAVE SCALING - SPEED
# =============================================================================

func test_speed_scaling_wave_1_easy():
	var easy_config = DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = EnemyRegistry.get_stats_for_wave("fast", 1, easy_config)
	var base_stats = EnemyRegistry.get_base_stats("fast")

	# Wave 1 with easy: base * 1.0 * 1.0^0 = base
	assert_eq(stats["speed"], base_stats["speed"], "Wave 1 Easy should have base speed")


func test_speed_scaling_with_waves():
	var easy_config = DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var wave1_stats = EnemyRegistry.get_stats_for_wave("basic", 1, easy_config)
	var wave5_stats = EnemyRegistry.get_stats_for_wave("basic", 5, easy_config)

	# Easy mode has speed_scale_per_wave = 1.0, so speed should not change
	if easy_config["enemy_speed_scale_per_wave"] == 1.0:
		assert_eq(wave5_stats["speed"], wave1_stats["speed"],
			"Speed should remain constant when scale factor is 1.0")
	else:
		var expected_ratio = pow(easy_config["enemy_speed_scale_per_wave"], 4)
		var actual_ratio = wave5_stats["speed"] / wave1_stats["speed"]
		assert_almost_eq(actual_ratio, expected_ratio, 0.01,
			"Speed should scale exponentially per wave")


func test_fast_enemy_is_faster_than_basic():
	var easy_config = DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var basic_stats = EnemyRegistry.get_stats_for_wave("basic", 1, easy_config)
	var fast_stats = EnemyRegistry.get_stats_for_wave("fast", 1, easy_config)

	assert_gt(fast_stats["speed"], basic_stats["speed"],
		"Fast enemy should be faster than basic")


func test_tank_enemy_is_slower_than_basic():
	var easy_config = DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var basic_stats = EnemyRegistry.get_stats_for_wave("basic", 1, easy_config)
	var tank_stats = EnemyRegistry.get_stats_for_wave("tank", 1, easy_config)

	assert_lt(tank_stats["speed"], basic_stats["speed"],
		"Tank enemy should be slower than basic")


# =============================================================================
# WAVE SCALING - DAMAGE
# =============================================================================

func test_damage_scaling_with_difficulty():
	var easy_config = DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var hard_config = DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.HARD]

	var easy_stats = EnemyRegistry.get_stats_for_wave("basic", 1, easy_config)
	var hard_stats = EnemyRegistry.get_stats_for_wave("basic", 1, hard_config)

	assert_gt(hard_stats["contact_damage"], easy_stats["contact_damage"],
		"Hard mode enemies should deal more contact damage")


func test_tank_has_higher_contact_damage():
	var easy_config = DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var basic_stats = EnemyRegistry.get_stats_for_wave("basic", 1, easy_config)
	var tank_stats = EnemyRegistry.get_stats_for_wave("tank", 1, easy_config)

	assert_gt(tank_stats["contact_damage"], basic_stats["contact_damage"],
		"Tank should deal more contact damage than basic")

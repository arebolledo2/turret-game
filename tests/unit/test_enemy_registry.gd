extends GutTest

# =============================================================================
# Unit tests for EnemyRegistry
# Tests enemy type definitions, wave scaling, and spawn selection
# =============================================================================


# =============================================================================
# TYPE DEFINITIONS
# =============================================================================

func test_all_enemy_types_exist():
	var expected_types = ["basic", "fast", "tank", "exploder", "lazy_wanderer", "charger", "neon_drone"]
	for type_id in expected_types:
		assert_has(EnemyRegistry.TYPES, type_id, "Enemy type '%s' should exist" % type_id)


func test_get_type_returns_valid_definition():
	var basic = EnemyRegistry.get_type("basic")
	assert_has(basic, "name", "Enemy definition should have name")
	assert_has(basic, "behaviors", "Enemy definition should have behaviors")
	assert_has(basic, "base_stats", "Enemy definition should have base_stats")
	assert_has(basic, "spawn_weight", "Enemy definition should have spawn_weight")
	assert_has(basic, "min_wave", "Enemy definition should have min_wave")


func test_get_type_fallback_to_basic():
	var result = EnemyRegistry.get_type("nonexistent_enemy")
	var basic = EnemyRegistry.get_type("basic")
	assert_eq(result, basic, "Non-existent type should fall back to basic")


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


# =============================================================================
# AVAILABLE TYPES BY WAVE
# =============================================================================

func test_get_available_types_wave_1():
	var available = EnemyRegistry.get_available_types(1)

	# Only enemies with min_wave <= 1 should be available
	assert_has(available, "basic", "Basic should be available on wave 1")

	# Fast has min_wave = 2
	assert_does_not_have(available, "fast", "Fast should NOT be available on wave 1")


func test_get_available_types_wave_2():
	var available = EnemyRegistry.get_available_types(2)

	assert_has(available, "basic", "Basic should be available on wave 2")
	assert_has(available, "fast", "Fast should be available on wave 2")
	assert_has(available, "lazy_wanderer", "Lazy wanderer should be available on wave 2")

	# Tank has min_wave = 3
	assert_does_not_have(available, "tank", "Tank should NOT be available on wave 2")


func test_get_available_types_wave_3():
	var available = EnemyRegistry.get_available_types(3)

	assert_has(available, "basic", "Basic should be available")
	assert_has(available, "fast", "Fast should be available")
	assert_has(available, "tank", "Tank should be available on wave 3")
	assert_has(available, "charger", "Charger should be available on wave 3")


func test_get_available_types_late_wave():
	var available = EnemyRegistry.get_available_types(10)

	# All enemy types should be available by wave 10
	for type_id in EnemyRegistry.get_all_type_ids():
		var min_wave = EnemyRegistry.get_type(type_id).get("min_wave", 1)
		if min_wave <= 10:
			assert_has(available, type_id, "%s should be available on wave 10" % type_id)


func test_available_types_increases_with_waves():
	var wave1_count = EnemyRegistry.get_available_types(1).size()
	var wave5_count = EnemyRegistry.get_available_types(5).size()

	assert_gte(wave5_count, wave1_count,
		"Later waves should have at least as many available types")


# =============================================================================
# RANDOM TYPE SELECTION
# =============================================================================

func test_select_random_type_returns_valid_type():
	for i in range(10):
		var selected = EnemyRegistry.select_random_type(5)
		assert_has(EnemyRegistry.TYPES, selected,
			"Selected type should exist in registry")


func test_select_random_type_respects_min_wave():
	# Wave 1 should never select enemies with min_wave > 1
	var available_wave_1 = EnemyRegistry.get_available_types(1)

	for i in range(20):
		var selected = EnemyRegistry.select_random_type(1)
		assert_has(available_wave_1, selected,
			"Wave 1 selection should be from available types")


func test_select_random_type_empty_available_returns_basic():
	# Even with no available types (hypothetically), should fall back to basic
	var result = EnemyRegistry.select_random_type(0)
	# Wave 0 should return basic as fallback
	assert_eq(result, "basic", "Should return basic as fallback")


func test_select_random_type_distribution():
	# Over many selections, should see variety based on spawn weights
	var selections: Dictionary = {}
	var wave = 5 # All common types available

	for i in range(100):
		var selected = EnemyRegistry.select_random_type(wave)
		selections[selected] = selections.get(selected, 0) + 1

	# Basic has weight 100, should be selected frequently
	assert_gt(selections.get("basic", 0), 0, "Basic should be selected sometimes")


func test_zero_weight_enemies_not_selected():
	# Exploder has spawn_weight = 0, should never be selected
	var selections: Dictionary = {}

	for i in range(50):
		var selected = EnemyRegistry.select_random_type(10)
		selections[selected] = selections.get(selected, 0) + 1

	assert_eq(selections.get("exploder", 0), 0,
		"Zero-weight enemies should never be selected")


# =============================================================================
# BEHAVIOR CHECKS
# =============================================================================

func test_has_behavior_chase():
	assert_true(EnemyRegistry.has_behavior("basic", GameEnums.EnemyBehavior.CHASE),
		"Basic should have CHASE behavior")


func test_has_behavior_tank():
	assert_true(EnemyRegistry.has_behavior("tank", GameEnums.EnemyBehavior.TANK),
		"Tank should have TANK behavior")


func test_has_behavior_wander():
	assert_true(EnemyRegistry.has_behavior("lazy_wanderer", GameEnums.EnemyBehavior.WANDER),
		"Lazy wanderer should have WANDER behavior")


func test_has_behavior_charge():
	assert_true(EnemyRegistry.has_behavior("charger", GameEnums.EnemyBehavior.CHARGE),
		"Charger should have CHARGE behavior")


func test_has_behavior_explosive():
	assert_true(EnemyRegistry.has_behavior("exploder", GameEnums.EnemyBehavior.EXPLOSIVE),
		"Exploder should have EXPLOSIVE behavior")


func test_has_behavior_returns_false_for_missing():
	assert_false(EnemyRegistry.has_behavior("basic", GameEnums.EnemyBehavior.RANGED),
		"Basic should NOT have RANGED behavior")


func test_has_behavior_invalid_type():
	assert_false(EnemyRegistry.has_behavior("nonexistent", GameEnums.EnemyBehavior.CHASE),
		"Invalid type should return false for any behavior")


# =============================================================================
# SPAWN COUNT
# =============================================================================

func test_get_spawn_count_basic():
	# Test multiple times since spawn count is now randomized [1, 5]
	var counts_seen = {}
	for i in range(20):
		var count = EnemyRegistry.get_spawn_count("basic")
		assert_between(count, 1, 5, "Basic enemy spawn count should be between 1-5")
		counts_seen[count] = true
	
	# Verify we see some randomization (at least 2 different values in 20 calls)
	assert_gte(counts_seen.size(), 2, "Should see randomization in spawn counts")


func test_get_spawn_count_fast():
	var count = EnemyRegistry.get_spawn_count("fast")
	assert_eq(count, 5, "Fast enemy spawn count should be 5")


func test_get_spawn_count_charger():
	var count = EnemyRegistry.get_spawn_count("charger")
	assert_eq(count, 1, "Charger spawn count should be 1")


func test_get_spawn_count_invalid_type():
	var count = EnemyRegistry.get_spawn_count("nonexistent")
	assert_eq(count, 1, "Invalid type should return default spawn count of 1")


# =============================================================================
# COLOR TINT
# =============================================================================

func test_get_color_returns_defined_tint():
	var fast_color = EnemyRegistry.get_color("fast")
	assert_eq(fast_color, Color(0.6, 0.9, 1.0), "Fast enemy should have cyan tint")


func test_get_color_default_white():
	var basic_color = EnemyRegistry.get_color("basic")
	# Basic doesn't have a color_tint defined, should return WHITE
	assert_eq(basic_color, Color.WHITE, "Basic should return WHITE (no tint)")


func test_get_color_invalid_type():
	var color = EnemyRegistry.get_color("nonexistent")
	assert_eq(color, Color.WHITE, "Invalid type should return WHITE")


# =============================================================================
# SPRITE FOLDER
# =============================================================================

func test_get_sprite_folder_default():
	var folder = EnemyRegistry.get_sprite_folder("fast")
	assert_eq(folder, "res://assets/sprites/enemy_fast",
		"Fast enemy should use enemy_fast sprites")


func test_get_sprite_folder_invalid_type():
	var folder = EnemyRegistry.get_sprite_folder("nonexistent")
	assert_eq(folder, "res://assets/sprites/enemy_spider_drone",
		"Invalid type should fall back to basic enemy sprite folder")


func before_each() -> void:
	TestHelpers.reset_all_services()

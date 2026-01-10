extends GutTest

# =============================================================================
# Unit tests for globals.gd helper functions
# These test pure calculations without scene tree dependencies
# =============================================================================

func before_each() -> void:
	GameStateService.reset_state()
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)


# =============================================================================
# WAVE DURATION TESTS
# =============================================================================

func test_wave_duration_wave_1():
	# Wave 1 should be 40 seconds
	var duration = GameStateService.get_wave_duration(1)
	assert_eq(duration, 40.0, "Wave 1 should be 40 seconds")


func test_wave_duration_scales_correctly():
	# Wave 5 = 60 seconds (using lerp-based scaling in game_state_service)
	var duration = GameStateService.get_wave_duration(5)
	assert_eq(duration, 60.0, "Wave 5 duration should be 60 seconds")


func test_wave_duration_wave_10():
	# Wave 7+ is capped at 60 seconds
	var duration = GameStateService.get_wave_duration(10)
	assert_eq(duration, 60.0, "Wave 10 should be capped at 60 seconds")


# =============================================================================
# ENEMY COUNT TESTS
# =============================================================================

func test_wave_enemy_count_wave_1_easy():
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	var mult = DifficultyService.get_difficulty_config()["enemy_count_mult"]
	var count = GameStateService.get_wave_enemy_count(1, mult, 1.0)
	# Wave 1: base count * difficulty mult
	var expected = int(GameConstants.WAVE_BASE_ENEMY_COUNT * mult)
	assert_eq(count, expected, "Wave 1 Easy should have base enemy count")


func test_wave_enemy_count_scales_with_waves():
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	var mult = DifficultyService.get_difficulty_config()["enemy_count_mult"]
	var wave1_count = GameStateService.get_wave_enemy_count(1, mult, 1.0)
	var wave5_count = GameStateService.get_wave_enemy_count(5, mult, 1.0)
	
	# Wave 5 = base + 4 * increment
	var expected_wave5 = int((GameConstants.WAVE_BASE_ENEMY_COUNT + 4 * GameConstants.WAVE_ENEMY_INCREMENT) * mult)
	assert_gt(wave5_count, wave1_count, "Later waves should have more enemies")
	assert_eq(wave5_count, expected_wave5, "Wave 5 Easy should have calculated enemy count")


func test_wave_enemy_count_scales_with_difficulty():
	var wave = 3

	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	var easy_count = GameStateService.get_wave_enemy_count(wave, DifficultyService.get_difficulty_config()["enemy_count_mult"], 1.0)

	DifficultyService.set_difficulty(GameEnums.Difficulty.MEDIUM)
	var medium_count = GameStateService.get_wave_enemy_count(wave, DifficultyService.get_difficulty_config()["enemy_count_mult"], 1.0)

	DifficultyService.set_difficulty(GameEnums.Difficulty.HARD)
	var hard_count = GameStateService.get_wave_enemy_count(wave, DifficultyService.get_difficulty_config()["enemy_count_mult"], 1.0)

	assert_gt(medium_count, easy_count, "Medium should spawn more enemies than Easy")
	assert_gt(hard_count, medium_count, "Hard should spawn more enemies than Medium")


# =============================================================================
# ENEMY HEALTH SCALING TESTS
# =============================================================================

func test_enemy_health_wave_1():
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	var health = EnemyRegistry.get_stats_for_wave("basic", 1, DifficultyService.get_difficulty_config())["health"]
	# Wave 1: base * mult * 1.0^0 = base
	assert_eq(health, GameConstants.ENEMY_BASE_HEALTH, "Wave 1 Easy should have base health")


func test_enemy_health_scales_exponentially():
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	var wave1_hp = EnemyRegistry.get_stats_for_wave("basic", 1, DifficultyService.get_difficulty_config())["health"]
	var wave5_hp = EnemyRegistry.get_stats_for_wave("basic", 5, DifficultyService.get_difficulty_config())["health"]

	# Easy: 10% per wave, so wave 5 = base * 1.1^4
	var expected_ratio = pow(1.10, 4) # ~1.4641
	var actual_ratio = wave5_hp / wave1_hp

	assert_almost_eq(actual_ratio, expected_ratio, 0.01, "Health should scale by 1.1^(wave-1)")


func test_enemy_health_harder_on_hard_mode():
	var wave = 3

	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	var easy_hp = EnemyRegistry.get_stats_for_wave("basic", wave, DifficultyService.get_difficulty_config())["health"]

	DifficultyService.set_difficulty(GameEnums.Difficulty.HARD)
	var hard_hp = EnemyRegistry.get_stats_for_wave("basic", wave, DifficultyService.get_difficulty_config())["health"]

	assert_gt(hard_hp, easy_hp, "Hard mode enemies should have more health")


# =============================================================================
# ENEMY SPEED SCALING TESTS
# =============================================================================

func test_enemy_speed_wave_1():
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	var base_stats = EnemyRegistry.get_base_stats("basic")
	var speed = EnemyRegistry.get_stats_for_wave("basic", 1, DifficultyService.get_difficulty_config())["speed"]
	assert_eq(speed, base_stats["speed"], "Wave 1 Easy should have base speed")


func test_enemy_speed_scales_with_waves():
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	var wave1_speed = EnemyRegistry.get_stats_for_wave("basic", 1, DifficultyService.get_difficulty_config())["speed"]
	var wave5_speed = EnemyRegistry.get_stats_for_wave("basic", 5, DifficultyService.get_difficulty_config())["speed"]

	assert_eq(wave5_speed, wave1_speed, "Enemy speed should remain constant across waves")


func test_enemy_speed_faster_on_hard():
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	var easy_speed = EnemyRegistry.get_stats_for_wave("basic", 1, DifficultyService.get_difficulty_config())["speed"]

	DifficultyService.set_difficulty(GameEnums.Difficulty.HARD)
	var hard_speed = EnemyRegistry.get_stats_for_wave("basic", 1, DifficultyService.get_difficulty_config())["speed"]

	assert_eq(hard_speed, easy_speed, "Enemy speed should be the same across difficulties")


# =============================================================================
# SPAWN INTERVAL TESTS
# =============================================================================

func test_spawn_interval_calculation():
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	var interval = GameStateService.get_spawn_interval(1, DifficultyService.get_difficulty_config()["enemy_count_mult"], 1.0)
	var duration = GameStateService.get_wave_duration(1)
	var count = GameStateService.get_wave_enemy_count(1, DifficultyService.get_difficulty_config()["enemy_count_mult"], 1.0)

	var expected = duration / float(count)
	assert_eq(interval, expected, "Spawn interval should be duration / enemy count")


func test_spawn_interval_decreases_on_hard():
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	var easy_interval = GameStateService.get_spawn_interval(3, DifficultyService.get_difficulty_config()["enemy_count_mult"], 1.0)

	DifficultyService.set_difficulty(GameEnums.Difficulty.HARD)
	var hard_interval = GameStateService.get_spawn_interval(3, DifficultyService.get_difficulty_config()["enemy_count_mult"], 1.0)

	# Hard has more enemies in same time = shorter interval
	assert_lt(hard_interval, easy_interval, "Hard should spawn enemies faster")


# =============================================================================
# PLAYER STATS TESTS
# =============================================================================

func test_player_health_reduced_on_hard():
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	var easy_hp = PlayerStatsService.get_player_max_health(DifficultyService.get_difficulty_config()["player_health_mult"])

	DifficultyService.set_difficulty(GameEnums.Difficulty.HARD)
	var hard_hp = PlayerStatsService.get_player_max_health(DifficultyService.get_difficulty_config()["player_health_mult"])

	assert_lt(hard_hp, easy_hp, "Hard mode should have less player health")
	assert_almost_eq(hard_hp, GameConstants.PLAYER_BASE_MAX_HEALTH * 0.8, 0.01, "Hard should be 80% health")


func test_turret_damage_reduced_on_hard():
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	var easy_dmg = GameConstants.TURRET_BASE_DAMAGE * DifficultyService.get_difficulty_config()["turret_damage_mult"]

	DifficultyService.set_difficulty(GameEnums.Difficulty.HARD)
	var hard_dmg = GameConstants.TURRET_BASE_DAMAGE * DifficultyService.get_difficulty_config()["turret_damage_mult"]

	assert_lt(hard_dmg, easy_dmg, "Hard mode turrets should deal less damage")


# =============================================================================
# RESET STATS TESTS
# =============================================================================

func test_reset_stats_clears_all():
	# Set some values
	GameStateService.current_wave = 5
	GameStateService.total_scrap = 100
	GameStateService.total_kills = 50
	GameStateService.turrets_spawned = 3
	GameStateService.time_survived = 120.0
	GameStateService.is_game_active = true
	
	# Reset
	GameStateService.reset_state()
	
	# Verify all cleared
	assert_eq(GameStateService.current_wave, 0, "Wave should reset to 0")
	assert_eq(GameStateService.total_scrap, 0, "XP should reset to 0")
	assert_eq(GameStateService.total_kills, 0, "Kills should reset to 0")
	assert_eq(GameStateService.turrets_spawned, 0, "Turrets should reset to 0")
	assert_eq(GameStateService.time_survived, 0.0, "Time should reset to 0")
	assert_false(GameStateService.is_game_active, "Game should be inactive")

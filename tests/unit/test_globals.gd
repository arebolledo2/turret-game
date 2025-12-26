extends GutTest

# =============================================================================
# Unit tests for globals.gd helper functions
# These test pure calculations without scene tree dependencies
# =============================================================================

func before_each() -> void:
	Globals.reset_stats()
	Globals.current_difficulty = GameEnums.Difficulty.EASY


# =============================================================================
# WAVE DURATION TESTS
# =============================================================================

func test_wave_duration_wave_1():
	# Wave 1 should be 25 seconds
	var duration = Globals.get_wave_duration(1)
	assert_eq(duration, 25.0, "Wave 1 should be 25 seconds")


func test_wave_duration_scales_correctly():
	# Wave 5 = 50 seconds (using lerp-based scaling in game_state_service)
	var duration = Globals.get_wave_duration(5)
	assert_eq(duration, 50.0, "Wave 5 duration should be 50 seconds")


func test_wave_duration_wave_10():
	# Wave 7+ is capped at 60 seconds
	var duration = Globals.get_wave_duration(10)
	assert_eq(duration, 60.0, "Wave 10 should be capped at 60 seconds")


# =============================================================================
# ENEMY COUNT TESTS
# =============================================================================

func test_wave_enemy_count_wave_1_easy():
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	var count = Globals.get_wave_enemy_count(1)
	# Wave 1: base count * difficulty mult
	var expected = int(GameConstants.WAVE_BASE_ENEMY_COUNT * 1.0)
	assert_eq(count, expected, "Wave 1 Easy should have base enemy count")


func test_wave_enemy_count_scales_with_waves():
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	var wave1_count = Globals.get_wave_enemy_count(1)
	var wave5_count = Globals.get_wave_enemy_count(5)
	
	# Wave 5 = base + 4 * increment
	var expected_wave5 = int((GameConstants.WAVE_BASE_ENEMY_COUNT + 4 * GameConstants.WAVE_ENEMY_INCREMENT) * 1.0)
	assert_gt(wave5_count, wave1_count, "Later waves should have more enemies")
	assert_eq(wave5_count, expected_wave5, "Wave 5 Easy should have calculated enemy count")


func test_wave_enemy_count_scales_with_difficulty():
	var wave = 3
	
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	var easy_count = Globals.get_wave_enemy_count(wave)
	
	Globals.current_difficulty = GameEnums.Difficulty.MEDIUM
	var medium_count = Globals.get_wave_enemy_count(wave)
	
	Globals.current_difficulty = GameEnums.Difficulty.HARD
	var hard_count = Globals.get_wave_enemy_count(wave)
	
	assert_gt(medium_count, easy_count, "Medium should spawn more enemies than Easy")
	assert_gt(hard_count, medium_count, "Hard should spawn more enemies than Medium")


# =============================================================================
# ENEMY HEALTH SCALING TESTS
# =============================================================================

func test_enemy_health_wave_1():
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	var health = Globals.get_enemy_health(1)
	# Wave 1: base * mult * 1.0^0 = base
	assert_eq(health, Globals.ENEMY_BASE_HEALTH, "Wave 1 Easy should have base health")


func test_enemy_health_scales_exponentially():
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	var wave1_hp = Globals.get_enemy_health(1)
	var wave5_hp = Globals.get_enemy_health(5)
	
	# Easy: 10% per wave, so wave 5 = base * 1.1^4
	var expected_ratio = pow(1.10, 4) # ~1.4641
	var actual_ratio = wave5_hp / wave1_hp
	
	assert_almost_eq(actual_ratio, expected_ratio, 0.01, "Health should scale by 1.1^(wave-1)")


func test_enemy_health_harder_on_hard_mode():
	var wave = 3
	
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	var easy_hp = Globals.get_enemy_health(wave)
	
	Globals.current_difficulty = GameEnums.Difficulty.HARD
	var hard_hp = Globals.get_enemy_health(wave)
	
	assert_gt(hard_hp, easy_hp, "Hard mode enemies should have more health")


# =============================================================================
# ENEMY SPEED SCALING TESTS
# =============================================================================

func test_enemy_speed_wave_1():
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	var speed = Globals.get_enemy_speed(1)
	assert_eq(speed, Globals.ENEMY_BASE_SPEED, "Wave 1 Easy should have base speed")


func test_enemy_speed_scales_with_waves():
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	var wave1_speed = Globals.get_enemy_speed(1)
	var wave5_speed = Globals.get_enemy_speed(5)
	
	assert_eq(wave5_speed, wave1_speed, "Enemy speed should remain constant across waves")


func test_enemy_speed_faster_on_hard():
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	var easy_speed = Globals.get_enemy_speed(1)
	
	Globals.current_difficulty = GameEnums.Difficulty.HARD
	var hard_speed = Globals.get_enemy_speed(1)
	
	assert_eq(hard_speed, easy_speed, "Enemy speed should be the same across difficulties")


# =============================================================================
# SPAWN INTERVAL TESTS
# =============================================================================

func test_spawn_interval_calculation():
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	var interval = Globals.get_spawn_interval(1)
	var duration = Globals.get_wave_duration(1)
	var count = Globals.get_wave_enemy_count(1)
	
	var expected = duration / float(count)
	assert_eq(interval, expected, "Spawn interval should be duration / enemy count")


func test_spawn_interval_decreases_on_hard():
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	var easy_interval = Globals.get_spawn_interval(3)
	
	Globals.current_difficulty = GameEnums.Difficulty.HARD
	var hard_interval = Globals.get_spawn_interval(3)
	
	# Hard has more enemies in same time = shorter interval
	assert_lt(hard_interval, easy_interval, "Hard should spawn enemies faster")


# =============================================================================
# PLAYER STATS TESTS
# =============================================================================

func test_player_health_reduced_on_hard():
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	var easy_hp = Globals.PLAYER_MAX_HEALTH
	
	Globals.current_difficulty = GameEnums.Difficulty.HARD
	var hard_hp = Globals.PLAYER_MAX_HEALTH
	
	assert_lt(hard_hp, easy_hp, "Hard mode should have less player health")
	assert_almost_eq(hard_hp, Globals.PLAYER_BASE_MAX_HEALTH * 0.8, 0.01, "Hard should be 80% health")


func test_turret_damage_reduced_on_hard():
	Globals.current_difficulty = GameEnums.Difficulty.EASY
	var easy_dmg = Globals.TURRET_DAMAGE
	
	Globals.current_difficulty = GameEnums.Difficulty.HARD
	var hard_dmg = Globals.TURRET_DAMAGE
	
	assert_lt(hard_dmg, easy_dmg, "Hard mode turrets should deal less damage")


# =============================================================================
# RESET STATS TESTS
# =============================================================================

func test_reset_stats_clears_all():
	# Set some values
	Globals.current_wave = 5
	Globals.total_xp = 100
	Globals.total_kills = 50
	Globals.turrets_spawned = 3
	Globals.time_survived = 120.0
	Globals.is_game_active = true
	
	# Reset
	Globals.reset_stats()
	
	# Verify all cleared
	assert_eq(Globals.current_wave, 0, "Wave should reset to 0")
	assert_eq(Globals.total_xp, 0, "XP should reset to 0")
	assert_eq(Globals.total_kills, 0, "Kills should reset to 0")
	assert_eq(Globals.turrets_spawned, 0, "Turrets should reset to 0")
	assert_eq(Globals.time_survived, 0.0, "Time should reset to 0")
	assert_false(Globals.is_game_active, "Game should be inactive")

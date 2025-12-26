extends GutTest

# =============================================================================
# Unit tests for RuntimeGameState
# Tests state management, wave calculations, and stat helpers
# =============================================================================

var game_state: RuntimeGameState


func before_each() -> void:
	game_state = RuntimeGameState.new()


# =============================================================================
# INITIAL STATE
# =============================================================================

func test_initial_difficulty():
	assert_eq(game_state.current_difficulty, GameEnums.Difficulty.EASY,
		"Default difficulty should be EASY")


func test_initial_wave():
	assert_eq(game_state.current_wave, 0, "Initial wave should be 0")


func test_initial_game_active():
	assert_false(game_state.is_game_active, "Game should not be active initially")


func test_initial_xp():
	assert_eq(game_state.total_xp, 0, "Initial XP should be 0")


func test_initial_kills():
	assert_eq(game_state.total_kills, 0, "Initial kills should be 0")


func test_initial_gold():
	assert_eq(game_state.total_gold, GameConstants.STARTING_GOLD,
		"Initial gold should match STARTING_GOLD constant")


func test_initial_player_level():
	assert_eq(game_state.player_level, 1, "Initial player level should be 1")


func test_initial_time_survived():
	assert_eq(game_state.time_survived, 0.0, "Initial time survived should be 0")


func test_initial_turrets_spawned():
	assert_eq(game_state.turrets_spawned, 0, "Initial turrets spawned should be 0")


func test_initial_modifier_system():
	assert_not_null(game_state.modifiers, "Modifier system should be initialized")
	assert_eq(game_state.modifiers.get_all_modifiers().size(), 0,
		"Modifier system should start empty")


# =============================================================================
# DIFFICULTY CONFIGURATION
# =============================================================================

func test_get_difficulty_config_easy():
	game_state.current_difficulty = GameEnums.Difficulty.EASY
	var config = game_state.get_difficulty_config()

	assert_eq(config["name"], "Easy", "Easy config should have correct name")
	assert_eq(config["enemy_health_mult"], 1.0, "Easy health mult should be 1.0")


func test_get_difficulty_config_medium():
	game_state.current_difficulty = GameEnums.Difficulty.MEDIUM
	var config = game_state.get_difficulty_config()

	assert_eq(config["name"], "Medium", "Medium config should have correct name")
	assert_gt(config["enemy_health_mult"], 1.0, "Medium health mult should be > 1.0")


func test_get_difficulty_config_hard():
	game_state.current_difficulty = GameEnums.Difficulty.HARD
	var config = game_state.get_difficulty_config()

	assert_eq(config["name"], "Hard", "Hard config should have correct name")
	assert_lt(config["player_health_mult"], 1.0, "Hard player health mult should be < 1.0")


func test_get_difficulty_name():
	game_state.current_difficulty = GameEnums.Difficulty.MEDIUM
	assert_eq(game_state.get_difficulty_name(), "Medium",
		"get_difficulty_name should return correct name")


func test_set_difficulty():
	game_state.set_difficulty(GameEnums.Difficulty.HARD)
	assert_eq(game_state.current_difficulty, GameEnums.Difficulty.HARD,
		"set_difficulty should update current_difficulty")


# =============================================================================
# WAVE DURATION
# =============================================================================

func test_wave_duration_wave_1():
	var duration = game_state.get_wave_duration(1)
	assert_eq(duration, GameConstants.WAVE_BASE_DURATION,
		"Wave 1 duration should equal base duration")


func test_wave_duration_increases():
	var wave1 = game_state.get_wave_duration(1)
	var wave5 = game_state.get_wave_duration(5)

	assert_gt(wave5, wave1, "Later waves should have longer duration")


func test_wave_duration_formula():
	var wave = 5
	var expected = GameConstants.WAVE_BASE_DURATION + (wave - 1) * GameConstants.WAVE_DURATION_INCREMENT
	var actual = game_state.get_wave_duration(wave)

	assert_eq(actual, expected, "Duration formula: base + (wave-1) * increment")


func test_wave_duration_wave_10():
	var expected = GameConstants.WAVE_BASE_DURATION + 9 * GameConstants.WAVE_DURATION_INCREMENT
	var actual = game_state.get_wave_duration(10)

	assert_eq(actual, expected, "Wave 10 should have correct duration")


# =============================================================================
# WAVE ENEMY COUNT
# =============================================================================

func test_enemy_count_wave_1_easy():
	game_state.current_difficulty = GameEnums.Difficulty.EASY
	var count = game_state.get_wave_enemy_count(1)

	var expected = int(GameConstants.WAVE_BASE_ENEMY_COUNT * 1.0) # Easy mult is 1.0
	assert_eq(count, expected, "Wave 1 Easy should have base enemy count")


func test_enemy_count_increases_with_wave():
	game_state.current_difficulty = GameEnums.Difficulty.EASY
	var wave1 = game_state.get_wave_enemy_count(1)
	var wave5 = game_state.get_wave_enemy_count(5)

	assert_gt(wave5, wave1, "Later waves should have more enemies")


func test_enemy_count_scales_with_difficulty():
	var wave = 3

	game_state.current_difficulty = GameEnums.Difficulty.EASY
	var easy_count = game_state.get_wave_enemy_count(wave)

	game_state.current_difficulty = GameEnums.Difficulty.HARD
	var hard_count = game_state.get_wave_enemy_count(wave)

	assert_gt(hard_count, easy_count, "Hard mode should have more enemies")


func test_enemy_count_formula():
	game_state.current_difficulty = GameEnums.Difficulty.EASY
	var wave = 5
	var base = GameConstants.WAVE_BASE_ENEMY_COUNT + (wave - 1) * GameConstants.WAVE_ENEMY_INCREMENT
	var expected = int(base * 1.0) # Easy mult
	var actual = game_state.get_wave_enemy_count(wave)

	assert_eq(actual, expected, "Enemy count formula: (base + increment) * difficulty_mult")


# =============================================================================
# SPAWN INTERVAL
# =============================================================================

func test_spawn_interval_calculation():
	game_state.current_difficulty = GameEnums.Difficulty.EASY
	var wave = 3

	var duration = game_state.get_wave_duration(wave)
	var count = game_state.get_wave_enemy_count(wave)
	var expected = duration / float(count)

	var actual = game_state.get_spawn_interval(wave)

	assert_eq(actual, expected, "Spawn interval = duration / enemy_count")


func test_spawn_interval_decreases_on_hard():
	var wave = 3

	game_state.current_difficulty = GameEnums.Difficulty.EASY
	var easy_interval = game_state.get_spawn_interval(wave)

	game_state.current_difficulty = GameEnums.Difficulty.HARD
	var hard_interval = game_state.get_spawn_interval(wave)

	# Hard has more enemies in same duration = shorter interval
	assert_lt(hard_interval, easy_interval,
		"Hard mode should have shorter spawn intervals")


# =============================================================================
# ENEMY HEALTH SCALING
# =============================================================================

func test_enemy_health_wave_1_easy():
	game_state.current_difficulty = GameEnums.Difficulty.EASY
	var health = game_state.get_enemy_health(1)

	# Wave 1: base * mult * 1.0^0 = base * 1.0 = base
	assert_eq(health, GameConstants.ENEMY_BASE_HEALTH,
		"Wave 1 Easy enemy health should be base health")


func test_enemy_health_scales_exponentially():
	game_state.current_difficulty = GameEnums.Difficulty.EASY
	var wave1 = game_state.get_enemy_health(1)
	var wave5 = game_state.get_enemy_health(5)

	var config = game_state.get_difficulty_config()
	var expected_ratio = pow(config["enemy_hp_scale_per_wave"], 4)
	var actual_ratio = wave5 / wave1

	assert_almost_eq(actual_ratio, expected_ratio, 0.01,
		"Health should scale exponentially per wave")


func test_enemy_health_harder_on_hard():
	var wave = 3

	game_state.current_difficulty = GameEnums.Difficulty.EASY
	var easy_hp = game_state.get_enemy_health(wave)

	game_state.current_difficulty = GameEnums.Difficulty.HARD
	var hard_hp = game_state.get_enemy_health(wave)

	assert_gt(hard_hp, easy_hp, "Hard mode enemies should have more health")


# =============================================================================
# ENEMY SPEED SCALING
# =============================================================================

func test_enemy_speed_wave_1_easy():
	game_state.current_difficulty = GameEnums.Difficulty.EASY
	var speed = game_state.get_enemy_speed(1)

	assert_eq(speed, GameConstants.ENEMY_BASE_SPEED,
		"Wave 1 Easy enemy speed should be base speed")


func test_enemy_speed_with_scaling():
	game_state.current_difficulty = GameEnums.Difficulty.EASY
	var config = game_state.get_difficulty_config()

	# If speed scale is 1.0, speed should remain constant
	if config["enemy_speed_scale_per_wave"] == 1.0:
		var wave1 = game_state.get_enemy_speed(1)
		var wave5 = game_state.get_enemy_speed(5)
		assert_eq(wave5, wave1, "Speed should remain constant when scale is 1.0")
	else:
		var wave1 = game_state.get_enemy_speed(1)
		var wave5 = game_state.get_enemy_speed(5)
		assert_ne(wave5, wave1, "Speed should change when scale != 1.0")


# =============================================================================
# ENEMY CONTACT DAMAGE
# =============================================================================

func test_enemy_contact_damage_easy():
	game_state.current_difficulty = GameEnums.Difficulty.EASY
	var damage = game_state.get_enemy_contact_damage()

	assert_eq(damage, GameConstants.ENEMY_BASE_CONTACT_DAMAGE,
		"Easy mode damage should be base damage")


func test_enemy_contact_damage_hard():
	game_state.current_difficulty = GameEnums.Difficulty.HARD
	var damage = game_state.get_enemy_contact_damage()

	var config = game_state.get_difficulty_config()
	var expected = GameConstants.ENEMY_BASE_CONTACT_DAMAGE * config["enemy_damage_mult"]

	assert_eq(damage, expected, "Hard mode damage should be scaled")
	assert_gt(damage, GameConstants.ENEMY_BASE_CONTACT_DAMAGE,
		"Hard mode should deal more damage")


# =============================================================================
# PLAYER STATS WITH MODIFIERS
# =============================================================================

func test_player_max_health_no_modifiers():
	game_state.current_difficulty = GameEnums.Difficulty.EASY
	var health = game_state.get_player_max_health()

	var expected = GameConstants.PLAYER_BASE_MAX_HEALTH * 1.0 # Easy mult
	assert_eq(health, expected, "Base player health with no modifiers")


func test_player_max_health_with_difficulty():
	game_state.current_difficulty = GameEnums.Difficulty.HARD
	var health = game_state.get_player_max_health()

	var config = game_state.get_difficulty_config()
	var expected = GameConstants.PLAYER_BASE_MAX_HEALTH * config["player_health_mult"]

	assert_eq(health, expected, "Player health should scale with difficulty")


func test_player_max_health_with_modifiers():
	game_state.modifiers.add_modifier({
		"id": "health_boost",
		"stat": "player_max_health",
		"operation": "add",
		"value": 50.0
	})

	game_state.current_difficulty = GameEnums.Difficulty.EASY
	var health = game_state.get_player_max_health()

	var expected = GameConstants.PLAYER_BASE_MAX_HEALTH + 50.0
	assert_eq(health, expected, "Player health should include modifiers")


func test_player_speed_no_modifiers():
	var speed = game_state.get_player_speed()
	assert_eq(speed, GameConstants.PLAYER_SPEED, "Base player speed with no modifiers")


func test_player_speed_with_modifiers():
	game_state.modifiers.add_modifier({
		"id": "speed_boost",
		"stat": "player_speed",
		"operation": "multiply",
		"value": 1.2
	})

	var speed = game_state.get_player_speed()
	var expected = GameConstants.PLAYER_SPEED * 1.2

	assert_eq(speed, expected, "Player speed should include modifiers")


func test_player_weapon_damage_no_modifiers():
	var damage = game_state.get_player_weapon_damage()
	assert_eq(damage, GameConstants.PLAYER_WEAPON_DAMAGE,
		"Base player weapon damage with no modifiers")


func test_player_weapon_damage_with_modifiers():
	game_state.modifiers.add_modifier({
		"id": "damage_boost",
		"stat": "player_weapon_damage",
		"operation": "add",
		"value": 5.0
	})

	var damage = game_state.get_player_weapon_damage()
	var expected = GameConstants.PLAYER_WEAPON_DAMAGE + 5.0

	assert_eq(damage, expected, "Player weapon damage should include modifiers")


# =============================================================================
# TURRET STATS
# =============================================================================

func test_get_turret_stats_delegates_to_modifiers():
	game_state.current_difficulty = GameEnums.Difficulty.EASY
	var stats = game_state.get_turret_stats("normal")

	assert_has(stats, "damage", "Turret stats should have damage")
	assert_has(stats, "fire_rate", "Turret stats should have fire_rate")
	assert_has(stats, "range", "Turret stats should have range")


func test_get_turret_stats_with_difficulty():
	game_state.current_difficulty = GameEnums.Difficulty.HARD
	var stats = game_state.get_turret_stats("normal")

	var config = game_state.get_difficulty_config()
	var base_stats = TurretRegistry.get_base_stats("normal")
	var expected_damage = base_stats["damage"] * config["turret_damage_mult"]

	assert_eq(stats["damage"], expected_damage,
		"Turret damage should scale with difficulty")


# =============================================================================
# TURRET COUNTS
# =============================================================================

func test_get_total_turret_count_empty():
	var count = game_state.get_total_turret_count()
	assert_eq(count, 0, "Initial turret count should be 0")


func test_get_total_turret_count_with_turrets():
	game_state.turret_counts["normal"] = 2
	game_state.turret_counts["fire"] = 3

	var count = game_state.get_total_turret_count()

	assert_eq(count, 5, "Total turret count should sum all types")


# =============================================================================
# RESET
# =============================================================================

func test_reset_clears_wave():
	game_state.current_wave = 5
	game_state.reset()
	assert_eq(game_state.current_wave, 0, "Reset should clear wave to 0")


func test_reset_clears_xp():
	game_state.total_xp = 100
	game_state.reset()
	assert_eq(game_state.total_xp, 0, "Reset should clear XP to 0")


func test_reset_clears_kills():
	game_state.total_kills = 50
	game_state.reset()
	assert_eq(game_state.total_kills, 0, "Reset should clear kills to 0")


func test_reset_clears_turrets_spawned():
	game_state.turrets_spawned = 10
	game_state.reset()
	assert_eq(game_state.turrets_spawned, 0, "Reset should clear turrets spawned")


func test_reset_clears_time():
	game_state.time_survived = 120.5
	game_state.reset()
	assert_eq(game_state.time_survived, 0.0, "Reset should clear time survived")


func test_reset_deactivates_game():
	game_state.is_game_active = true
	game_state.reset()
	assert_false(game_state.is_game_active, "Reset should deactivate game")


func test_reset_resets_player_level():
	game_state.player_level = 5
	game_state.reset()
	assert_eq(game_state.player_level, 1, "Reset should reset player level to 1")


func test_reset_clears_turret_counts():
	game_state.turret_counts["normal"] = 3
	game_state.reset()
	assert_true(game_state.turret_counts.is_empty(), "Reset should clear turret counts")


func test_reset_clears_selected_turret():
	game_state.selected_turret_type = "fire"
	game_state.reset()
	assert_eq(game_state.selected_turret_type, "", "Reset should clear selected turret")


func test_reset_clears_collected_items():
	game_state.collected_items.append("scrap_magnet")
	game_state.reset()
	assert_true(game_state.collected_items.is_empty(), "Reset should clear collected items")


func test_reset_clears_modifiers():
	game_state.modifiers.add_modifier({"id": "test", "stat": "damage", "operation": "add", "value": 10.0})
	game_state.reset()
	assert_eq(game_state.modifiers.get_all_modifiers().size(), 0,
		"Reset should clear modifiers")


func test_reset_resets_gold():
	game_state.total_gold = 500
	game_state.reset()
	assert_eq(game_state.total_gold, GameConstants.STARTING_GOLD,
		"Reset should restore starting gold")


func test_reset_clears_shop_reroll_count():
	game_state.shop_reroll_count = 3
	game_state.reset()
	assert_eq(game_state.shop_reroll_count, 0, "Reset should clear reroll count")


func test_reset_clears_shop_offers():
	game_state.current_shop_offers.append({"type": "turret", "id": "normal"})
	game_state.reset()
	assert_true(game_state.current_shop_offers.is_empty(),
		"Reset should clear shop offers")


func test_reset_clears_pending_purchases():
	game_state.pending_turret_purchases.append("fire")
	game_state.reset()
	assert_true(game_state.pending_turret_purchases.is_empty(),
		"Reset should clear pending purchases")


# =============================================================================
# SETTINGS PERSISTENCE
# =============================================================================

func test_settings_not_reset():
	game_state.show_damage_numbers = false
	game_state.player_auto_attack_enabled = true
	game_state.show_turret_ranges = true

	game_state.reset()

	# Settings should NOT be reset by game reset
	assert_false(game_state.show_damage_numbers, "Settings should persist through reset")
	assert_true(game_state.player_auto_attack_enabled, "Settings should persist through reset")
	assert_true(game_state.show_turret_ranges, "Settings should persist through reset")


func test_difficulty_not_reset():
	game_state.current_difficulty = GameEnums.Difficulty.HARD
	game_state.reset()

	# Difficulty is a user choice, should persist
	# Note: This depends on design decision. If reset SHOULD clear difficulty, update test.
	# Currently reset() does not change current_difficulty
	assert_eq(game_state.current_difficulty, GameEnums.Difficulty.HARD,
		"Difficulty should persist through reset")

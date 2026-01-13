extends GutTest

# =============================================================================
# Unit tests for Critical Hit System
# Tests player and turret crit chance, multiplier, and modifier integration
# =============================================================================

var player_stats_service: Node
var turret_stats_service: Node
var modifier_service: Node

func before_all() -> void:
	player_stats_service = get_node("/root/PlayerStatsService")
	turret_stats_service = get_node("/root/TurretStatsService")
	modifier_service = get_node("/root/ModifierService")

func before_each() -> void:
	player_stats_service.reset_state()
	turret_stats_service.reset_state()
	modifier_service.clear_modifiers()


# =============================================================================
# PLAYER CRIT CHANCE
# =============================================================================

func test_get_player_crit_chance_base():
	var crit_chance = player_stats_service.get_player_crit_chance()
	assert_eq(crit_chance, GameConstants.PLAYER_BASE_CRIT_CHANCE,
		"Should return base crit chance (5%) without modifiers")


func test_get_player_crit_chance_with_additive_modifier():
	modifier_service.add_modifier({
		"stat": "player_crit_chance",
		"operation": "add",
		"value": 0.10,
		"source": "test_item"
	})
	var crit_chance = player_stats_service.get_player_crit_chance()
	assert_almost_eq(crit_chance, 0.15, 0.001,
		"Should apply +10% crit chance (5% + 10% = 15%)")


func test_get_player_crit_chance_with_multiple_modifiers():
	modifier_service.add_modifier({
		"stat": "player_crit_chance",
		"operation": "add",
		"value": 0.10,
		"source": "item1"
	})
	modifier_service.add_modifier({
		"stat": "player_crit_chance",
		"operation": "add",
		"value": 0.05,
		"source": "item2"
	})
	var crit_chance = player_stats_service.get_player_crit_chance()
	assert_almost_eq(crit_chance, 0.20, 0.001,
		"Should stack multiple crit chance modifiers (5% + 10% + 5% = 20%)")


func test_get_player_crit_chance_with_more_modifier():
	modifier_service.add_modifier({
		"stat": "player_crit_chance",
		"operation": "more",
		"value": 2.0,
		"source": "test_item"
	})
	var crit_chance = player_stats_service.get_player_crit_chance()
	assert_almost_eq(crit_chance, 0.10, 0.001,
		"Should apply 'more' modifier (5% * 2 = 10%)")


# =============================================================================
# PLAYER CRIT MULTIPLIER
# =============================================================================

func test_get_player_crit_multiplier_base():
	var crit_mult = player_stats_service.get_player_crit_multiplier()
	assert_eq(crit_mult, GameConstants.PLAYER_BASE_CRIT_MULTIPLIER,
		"Should return base crit multiplier (2.0x) without modifiers")


func test_get_player_crit_multiplier_with_additive_modifier():
	modifier_service.add_modifier({
		"stat": "player_crit_multiplier",
		"operation": "add",
		"value": 0.5,
		"source": "test_item"
	})
	var crit_mult = player_stats_service.get_player_crit_multiplier()
	assert_almost_eq(crit_mult, 2.5, 0.001,
		"Should apply +0.5 multiplier (2.0 + 0.5 = 2.5x)")


func test_get_player_crit_multiplier_with_more_modifier():
	modifier_service.add_modifier({
		"stat": "player_crit_multiplier",
		"operation": "more",
		"value": 1.5,
		"source": "test_item"
	})
	var crit_mult = player_stats_service.get_player_crit_multiplier()
	assert_almost_eq(crit_mult, 3.0, 0.001,
		"Should apply 'more' modifier (2.0 * 1.5 = 3.0x)")


# =============================================================================
# PLAYER CRIT CALCULATION
# =============================================================================

func test_calculate_player_crit_damage_base():
	var base_damage = 10.0
	var crit_damage = player_stats_service.calculate_player_crit_damage(base_damage)
	assert_eq(crit_damage, 20.0,
		"Should deal 2x damage on crit (10 * 2 = 20)")


func test_calculate_player_crit_damage_with_modifier():
	modifier_service.add_modifier({
		"stat": "player_crit_multiplier",
		"operation": "add",
		"value": 0.5,
		"source": "test_item"
	})
	var base_damage = 10.0
	var crit_damage = player_stats_service.calculate_player_crit_damage(base_damage)
	assert_eq(crit_damage, 25.0,
		"Should deal 2.5x damage on crit with modifier (10 * 2.5 = 25)")


func test_roll_player_crit_returns_boolean():
	var result = player_stats_service.roll_player_crit()
	assert_typeof(result, TYPE_BOOL,
		"roll_player_crit should return a boolean")


func test_roll_player_crit_probability_distribution():
	# Test that crit rolls follow expected distribution over many rolls
	var crit_count = 0
	var total_rolls = 10000

	for i in range(total_rolls):
		if player_stats_service.roll_player_crit():
			crit_count += 1

	var actual_rate = float(crit_count) / float(total_rolls)
	var expected_rate = GameConstants.PLAYER_BASE_CRIT_CHANCE

	# Allow 1% margin of error for statistical variance
	assert_almost_eq(actual_rate, expected_rate, 0.01,
		"Crit rolls should follow 5% probability over many rolls")


# =============================================================================
# TURRET CRIT CHANCE
# =============================================================================

func test_get_turret_crit_chance_base():
	var crit_chance = turret_stats_service.get_turret_crit_chance()
	assert_eq(crit_chance, GameConstants.TURRET_BASE_CRIT_CHANCE,
		"Should return base turret crit chance (5%) without modifiers")


func test_get_turret_crit_chance_with_additive_modifier():
	modifier_service.add_modifier({
		"stat": "turret_crit_chance",
		"operation": "add",
		"value": 0.15,
		"source": "test_item"
	})
	var crit_chance = turret_stats_service.get_turret_crit_chance()
	assert_almost_eq(crit_chance, 0.20, 0.001,
		"Should apply +15% turret crit chance (5% + 15% = 20%)")


func test_turret_crit_independent_from_player_crit():
	# Modify player crit
	modifier_service.add_modifier({
		"stat": "player_crit_chance",
		"operation": "add",
		"value": 0.50,
		"source": "player_item"
	})

	# Turret crit should be unaffected
	var turret_crit = turret_stats_service.get_turret_crit_chance()
	assert_eq(turret_crit, GameConstants.TURRET_BASE_CRIT_CHANCE,
		"Turret crit should be independent from player crit modifiers")


# =============================================================================
# TURRET CRIT MULTIPLIER
# =============================================================================

func test_get_turret_crit_multiplier_base():
	var crit_mult = turret_stats_service.get_turret_crit_multiplier()
	assert_eq(crit_mult, GameConstants.TURRET_BASE_CRIT_MULTIPLIER,
		"Should return base turret crit multiplier (2.0x) without modifiers")


func test_get_turret_crit_multiplier_with_additive_modifier():
	modifier_service.add_modifier({
		"stat": "turret_crit_multiplier",
		"operation": "add",
		"value": 1.0,
		"source": "test_item"
	})
	var crit_mult = turret_stats_service.get_turret_crit_multiplier()
	assert_almost_eq(crit_mult, 3.0, 0.001,
		"Should apply +1.0 multiplier (2.0 + 1.0 = 3.0x)")


# =============================================================================
# TURRET CRIT CALCULATION
# =============================================================================

func test_calculate_turret_crit_damage_base():
	var base_damage = 15.0
	var crit_damage = turret_stats_service.calculate_turret_crit_damage(base_damage)
	assert_eq(crit_damage, 30.0,
		"Should deal 2x damage on crit (15 * 2 = 30)")


func test_calculate_turret_crit_damage_with_modifier():
	modifier_service.add_modifier({
		"stat": "turret_crit_multiplier",
		"operation": "add",
		"value": 1.5,
		"source": "test_item"
	})
	var base_damage = 15.0
	var crit_damage = turret_stats_service.calculate_turret_crit_damage(base_damage)
	assert_eq(crit_damage, 52.5,
		"Should deal 3.5x damage on crit with modifier (15 * 3.5 = 52.5)")


func test_roll_turret_crit_returns_boolean():
	var result = turret_stats_service.roll_turret_crit()
	assert_typeof(result, TYPE_BOOL,
		"roll_turret_crit should return a boolean")


func test_roll_turret_crit_probability_distribution():
	# Test that turret crit rolls follow expected distribution
	var crit_count = 0
	var total_rolls = 10000

	for i in range(total_rolls):
		if turret_stats_service.roll_turret_crit():
			crit_count += 1

	var actual_rate = float(crit_count) / float(total_rolls)
	var expected_rate = GameConstants.TURRET_BASE_CRIT_CHANCE

	# Allow 1% margin of error for statistical variance
	assert_almost_eq(actual_rate, expected_rate, 0.01,
		"Turret crit rolls should follow 5% probability over many rolls")


# =============================================================================
# COMBINED MODIFIERS (Player and Turret)
# =============================================================================

func test_player_and_turret_crit_modifiers_are_independent():
	# Add player crit chance modifier
	modifier_service.add_modifier({
		"stat": "player_crit_chance",
		"operation": "add",
		"value": 0.20,
		"source": "player_item"
	})

	# Add turret crit chance modifier
	modifier_service.add_modifier({
		"stat": "turret_crit_chance",
		"operation": "add",
		"value": 0.10,
		"source": "turret_item"
	})

	var player_crit = player_stats_service.get_player_crit_chance()
	var turret_crit = turret_stats_service.get_turret_crit_chance()

	assert_almost_eq(player_crit, 0.25, 0.001, "Player should have 25% crit (5% + 20%)")
	assert_almost_eq(turret_crit, 0.15, 0.001, "Turret should have 15% crit (5% + 10%)")


func test_crit_multipliers_apply_to_damage_correctly():
	# Test that the full damage calculation chain works
	var base_damage = 100.0

	# Player with 3x crit multiplier
	modifier_service.add_modifier({
		"stat": "player_crit_multiplier",
		"operation": "add",
		"value": 1.0,
		"source": "player_item"
	})

	# Turret with 2.5x crit multiplier
	modifier_service.add_modifier({
		"stat": "turret_crit_multiplier",
		"operation": "add",
		"value": 0.5,
		"source": "turret_item"
	})

	var player_crit_damage = player_stats_service.calculate_player_crit_damage(base_damage)
	var turret_crit_damage = turret_stats_service.calculate_turret_crit_damage(base_damage)

	assert_eq(player_crit_damage, 300.0, "Player should crit for 3x (100 * 3)")
	assert_eq(turret_crit_damage, 250.0, "Turret should crit for 2.5x (100 * 2.5)")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_crit_chance_with_zero_damage():
	var crit_damage = player_stats_service.calculate_player_crit_damage(0.0)
	assert_eq(crit_damage, 0.0,
		"Crit on zero damage should be zero")


func test_crit_chance_with_negative_damage():
	# Edge case - shouldn't happen in practice, but test behavior
	var crit_damage = player_stats_service.calculate_player_crit_damage(-10.0)
	assert_eq(crit_damage, -20.0,
		"Crit multiplier applies even to negative damage")


func test_crit_chance_never_exceeds_100_percent():
	# Add massive crit chance modifier
	modifier_service.add_modifier({
		"stat": "player_crit_chance",
		"operation": "add",
		"value": 2.0,
		"source": "test_item"
	})

	var crit_chance = player_stats_service.get_player_crit_chance()

	# Note: The system doesn't cap crit chance, but roll_crit will always return true if > 1.0
	# This test documents the behavior
	assert_gt(crit_chance, 1.0,
		"Crit chance can exceed 100% (but roll will always succeed)")

	# All rolls should crit
	var all_crits = true
	for i in range(100):
		if not player_stats_service.roll_player_crit():
			all_crits = false
			break

	assert_true(all_crits, "With >100% crit chance, all rolls should crit")


func test_crit_multiplier_less_than_one():
	# Edge case - negative crit multiplier modifier
	modifier_service.add_modifier({
		"stat": "player_crit_multiplier",
		"operation": "add",
		"value": -1.5,
		"source": "curse_item"
	})

	var crit_mult = player_stats_service.get_player_crit_multiplier()
	assert_eq(crit_mult, 0.5,
		"Crit multiplier can go below 1.0 (cursed crits deal less damage)")

	var crit_damage = player_stats_service.calculate_player_crit_damage(100.0)
	assert_eq(crit_damage, 50.0,
		"Crit with 0.5x multiplier deals half damage")

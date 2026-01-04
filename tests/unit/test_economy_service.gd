extends GutTest

# =============================================================================
# Unit tests for EconomyService
# Tests scrap management, shop offers, rerolls, and purchase tracking
# =============================================================================

var economy_service: Node

func before_all() -> void:
	economy_service = get_node("/root/EconomyService")

func before_each() -> void:
	economy_service.reset_state()


# =============================================================================
# RESET STATE
# =============================================================================

func test_reset_state_sets_starting_scrap():
	economy_service.reset_state()
	assert_eq(economy_service.total_scrap, GameConstants.STARTING_SCRAP,
		"Reset should set starting scrap")


func test_reset_state_clears_shop_rerolls():
	economy_service.shop_reroll_count = 5
	economy_service.reset_state()
	assert_eq(economy_service.shop_reroll_count, 0,
		"Reset should clear reroll count")


func test_reset_state_clears_shop_offers():
	economy_service.current_shop_offers = [ {"type": "turret"}]
	economy_service.reset_state()
	assert_eq(economy_service.current_shop_offers.size(), 0,
		"Reset should clear shop offers")


func test_reset_state_clears_pending_purchases():
	economy_service.pending_turret_purchases.append("fire")
	economy_service.pending_turret_purchases.append("sniper")
	economy_service.reset_state()
	assert_eq(economy_service.pending_turret_purchases.size(), 0,
		"Reset should clear pending purchases")


func test_reset_state_clears_turrets_purchased():
	economy_service.turrets_purchased = 10
	economy_service.reset_state()
	assert_eq(economy_service.turrets_purchased, 0,
		"Reset should clear purchase count")


# =============================================================================
# SCRAP MANAGEMENT
# =============================================================================

func test_add_scrap_without_multiplier():
	economy_service.total_scrap = 100
	economy_service.add_scrap(50, 1.0)
	assert_eq(economy_service.total_scrap, 150,
		"Should add 50 scrap")


func test_add_scrap_with_multiplier():
	economy_service.total_scrap = 100
	economy_service.add_scrap(50, 1.5)
	assert_eq(economy_service.total_scrap, 175,
		"Should add 50 * 1.5 = 75 scrap")


func test_add_scrap_with_exact_multiplier():
	economy_service.total_scrap = 100
	economy_service.add_scrap(10, 2.0) # 10 * 2.0 = 20 (exact, no probabilistic rounding)
	assert_eq(economy_service.total_scrap, 120,
		"Should add exactly 20 scrap with multiplier 2.0")


func test_deduct_scrap_success():
	economy_service.total_scrap = 100
	var result = economy_service.deduct_scrap(50)
	assert_true(result, "Should succeed with sufficient funds")
	assert_eq(economy_service.total_scrap, 50,
		"Should deduct 50 scrap")


func test_deduct_scrap_exact_amount():
	economy_service.total_scrap = 100
	var result = economy_service.deduct_scrap(100)
	assert_true(result, "Should succeed with exact amount")
	assert_eq(economy_service.total_scrap, 0,
		"Should have 0 scrap remaining")


func test_deduct_scrap_insufficient_funds():
	economy_service.total_scrap = 50
	var result = economy_service.deduct_scrap(100)
	assert_false(result, "Should fail with insufficient funds")
	assert_eq(economy_service.total_scrap, 50,
		"Scrap should remain unchanged")


func test_deduct_scrap_zero():
	economy_service.total_scrap = 100
	var result = economy_service.deduct_scrap(0)
	assert_true(result, "Should succeed with 0 deduction")
	assert_eq(economy_service.total_scrap, 100,
		"Scrap should remain unchanged")


# =============================================================================
# REROLL COST CALCULATION
# =============================================================================

func test_get_reroll_cost_wave1_no_rerolls():
	economy_service.shop_reroll_count = 0
	# Wave 1: 1 × 1.5 = 1 (rounded down)
	var expected = int(1 * GameConstants.REROLL_WAVE_BASE_MULTIPLIER)
	var cost = economy_service.get_reroll_cost(1, 1.0)
	assert_eq(cost, expected,
		"Wave 1, first reroll should cost 1 scrap")


func test_get_reroll_cost_wave5_no_rerolls():
	economy_service.shop_reroll_count = 0
	# Wave 5: 5 × 1.5 = 7 (rounded down)
	var expected = int(5 * GameConstants.REROLL_WAVE_BASE_MULTIPLIER)
	var cost = economy_service.get_reroll_cost(5, 1.0)
	assert_eq(cost, expected,
		"Wave 5, first reroll should cost 7 scrap")


func test_get_reroll_cost_wave1_with_rerolls():
	economy_service.shop_reroll_count = 3
	# Wave 1: (1 × 1.5) + (3 × 1) = 1 + 3 = 4
	var expected = int(1 * GameConstants.REROLL_WAVE_BASE_MULTIPLIER + 3 * GameConstants.REROLL_COST_INCREMENT)
	var cost = economy_service.get_reroll_cost(1, 1.0)
	assert_eq(cost, expected,
		"Wave 1, 4th reroll should cost 4 scrap")


func test_get_reroll_cost_wave3_with_rerolls():
	economy_service.shop_reroll_count = 2
	# Wave 3: (3 × 1.5) + (2 × 1) = 4 + 2 = 6
	var expected = int(3 * GameConstants.REROLL_WAVE_BASE_MULTIPLIER + 2 * GameConstants.REROLL_COST_INCREMENT)
	var cost = economy_service.get_reroll_cost(3, 1.0)
	assert_eq(cost, expected,
		"Wave 3, 3rd reroll should cost 6 scrap")


func test_get_reroll_cost_with_item_multiplier():
	economy_service.shop_reroll_count = 1
	# Wave 2: (2 × 1.5) + (1 × 1) = 3 + 1 = 4, then × 1.5 = 6
	var base_cost = 2 * GameConstants.REROLL_WAVE_BASE_MULTIPLIER + 1 * GameConstants.REROLL_COST_INCREMENT
	var expected = int(base_cost * 1.5)
	var cost = economy_service.get_reroll_cost(2, 1.5)
	assert_eq(cost, expected,
		"Should apply item multiplier to total cost")


func test_get_reroll_cost_with_discount():
	economy_service.shop_reroll_count = 1
	# Wave 5: (5 × 1.5) + (1 × 1) = 7 + 1 = 8, then × 0.5 = 4
	var base_cost = 5 * GameConstants.REROLL_WAVE_BASE_MULTIPLIER + 1 * GameConstants.REROLL_COST_INCREMENT
	var expected = int(base_cost * 0.5)
	var cost = economy_service.get_reroll_cost(5, 0.5)
	assert_eq(cost, expected,
		"Should apply discount multiplier")


func test_get_reroll_cost_rounds_down():
	economy_service.shop_reroll_count = 0
	var cost = economy_service.get_reroll_cost(1, 1.25)
	assert_typeof(cost, TYPE_INT,
		"Cost should be an integer")


# =============================================================================
# WAVE SCRAP BONUS CALCULATION
# =============================================================================

func test_get_wave_scrap_bonus_wave_1():
	var bonus = economy_service.get_wave_scrap_bonus(1, 1.0)
	var expected_val = GameConstants.SCRAP_WAVE_BONUS_BASE
	assert_eq(bonus, expected_val,
		"Wave 1 should get base bonus")


func test_get_wave_scrap_bonus_wave_5():
	var bonus = economy_service.get_wave_scrap_bonus(5, 1.0)
	var expected = GameConstants.SCRAP_WAVE_BONUS_BASE + (5 - 1) * 5
	assert_eq(bonus, expected,
		"Wave 5 bonus should scale")


func test_get_wave_scrap_bonus_wave_10():
	var bonus = economy_service.get_wave_scrap_bonus(10, 1.0)
	var expected = GameConstants.SCRAP_WAVE_BONUS_BASE + (10 - 1) * 5
	assert_eq(bonus, expected,
		"Wave 10 bonus should scale")


func test_get_wave_scrap_bonus_with_multiplier():
	var base_bonus = GameConstants.SCRAP_WAVE_BONUS_BASE + (3 - 1) * 5
	var expected = int(base_bonus * 2.0)
	var bonus = economy_service.get_wave_scrap_bonus(3, 2.0)
	assert_eq(bonus, expected,
		"Should apply multiplier to bonus")


func test_get_wave_scrap_bonus_rounds_down():
	var bonus = economy_service.get_wave_scrap_bonus(1, 1.33)
	assert_typeof(bonus, TYPE_INT,
		"Bonus should be an integer")


func test_get_wave_scrap_bonus_increases_per_wave():
	var wave1 = economy_service.get_wave_scrap_bonus(1, 1.0)
	var wave2 = economy_service.get_wave_scrap_bonus(2, 1.0)
	var wave3 = economy_service.get_wave_scrap_bonus(3, 1.0)

	assert_gt(wave2, wave1, "Wave 2 bonus > Wave 1")
	assert_gt(wave3, wave2, "Wave 3 bonus > Wave 2")
	assert_eq(wave2 - wave1, 5, "Should increase by 5 per wave")
	assert_eq(wave3 - wave2, 5, "Should increase by 5 per wave")


# =============================================================================
# SHOP STATE MANAGEMENT
# =============================================================================

func test_pending_turret_purchases_starts_empty():
	assert_eq(economy_service.pending_turret_purchases.size(), 0,
		"Should start with no pending purchases")


func test_shop_offers_starts_empty():
	assert_eq(economy_service.current_shop_offers.size(), 0,
		"Should start with no shop offers")


func test_turrets_purchased_tracking():
	economy_service.turrets_purchased = 0
	economy_service.turrets_purchased += 1
	assert_eq(economy_service.turrets_purchased, 1,
		"Should track purchased turrets")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_negative_scrap_deduction():
	economy_service.total_scrap = 100
	var result = economy_service.deduct_scrap(-50)
	assert_true(result, "Negative deduction should succeed")
	assert_eq(economy_service.total_scrap, 150,
		"Negative deduction should add scrap")


func test_large_scrap_amounts():
	economy_service.total_scrap = 999999
	economy_service.add_scrap(100000, 1.0)
	assert_eq(economy_service.total_scrap, 1099999,
		"Should handle large scrap amounts")


func test_wave_bonus_wave_zero():
	# Edge case: wave 0 shouldn't happen but test gracefully
	var bonus = economy_service.get_wave_scrap_bonus(0, 1.0)
	var expected = GameConstants.SCRAP_WAVE_BONUS_BASE + (0 - 1) * 5
	assert_eq(bonus, expected,
		"Should handle wave 0 gracefully")

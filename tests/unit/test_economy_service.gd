extends GutTest

# =============================================================================
# Unit tests for EconomyService
# Tests gold management, shop offers, rerolls, and purchase tracking
# =============================================================================

var economy_service: Node

func before_all() -> void:
	economy_service = get_node("/root/EconomyService")

func before_each() -> void:
	economy_service.reset_state()


# =============================================================================
# RESET STATE
# =============================================================================

func test_reset_state_sets_starting_gold():
	economy_service.reset_state()
	assert_eq(economy_service.total_gold, GameConstants.STARTING_GOLD,
		"Reset should set starting gold")


func test_reset_state_clears_shop_rerolls():
	economy_service.shop_reroll_count = 5
	economy_service.reset_state()
	assert_eq(economy_service.shop_reroll_count, 0,
		"Reset should clear reroll count")


func test_reset_state_clears_shop_offers():
	economy_service.current_shop_offers = [{"type": "turret"}]
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
# GOLD MANAGEMENT
# =============================================================================

func test_add_gold_without_multiplier():
	economy_service.total_gold = 100
	economy_service.add_gold(50, 1.0)
	assert_eq(economy_service.total_gold, 150,
		"Should add 50 gold")


func test_add_gold_with_multiplier():
	economy_service.total_gold = 100
	economy_service.add_gold(50, 1.5)
	assert_eq(economy_service.total_gold, 175,
		"Should add 50 * 1.5 = 75 gold")


func test_add_gold_rounds_down():
	economy_service.total_gold = 100
	economy_service.add_gold(10, 1.25)  # 10 * 1.25 = 12.5
	assert_eq(economy_service.total_gold, 112,
		"Should round down to 12 gold (int)")


func test_deduct_gold_success():
	economy_service.total_gold = 100
	var result = economy_service.deduct_gold(50)
	assert_true(result, "Should succeed with sufficient funds")
	assert_eq(economy_service.total_gold, 50,
		"Should deduct 50 gold")


func test_deduct_gold_exact_amount():
	economy_service.total_gold = 100
	var result = economy_service.deduct_gold(100)
	assert_true(result, "Should succeed with exact amount")
	assert_eq(economy_service.total_gold, 0,
		"Should have 0 gold remaining")


func test_deduct_gold_insufficient_funds():
	economy_service.total_gold = 50
	var result = economy_service.deduct_gold(100)
	assert_false(result, "Should fail with insufficient funds")
	assert_eq(economy_service.total_gold, 50,
		"Gold should remain unchanged")


func test_deduct_gold_zero():
	economy_service.total_gold = 100
	var result = economy_service.deduct_gold(0)
	assert_true(result, "Should succeed with 0 deduction")
	assert_eq(economy_service.total_gold, 100,
		"Gold should remain unchanged")


# =============================================================================
# REROLL COST CALCULATION
# =============================================================================

func test_get_reroll_cost_no_rerolls():
	economy_service.shop_reroll_count = 0
	var cost = economy_service.get_reroll_cost(1.0)
	assert_eq(cost, GameConstants.REROLL_BASE_COST,
		"First reroll should cost base amount")


func test_get_reroll_cost_increments():
	economy_service.shop_reroll_count = 3
	var expected = GameConstants.REROLL_BASE_COST + 3 * GameConstants.REROLL_COST_INCREMENT
	var cost = economy_service.get_reroll_cost(1.0)
	assert_eq(cost, expected,
		"Cost should increase with reroll count")


func test_get_reroll_cost_with_multiplier():
	economy_service.shop_reroll_count = 2
	var base_cost = GameConstants.REROLL_BASE_COST + 2 * GameConstants.REROLL_COST_INCREMENT
	var expected = int(base_cost * 1.5)
	var cost = economy_service.get_reroll_cost(1.5)
	assert_eq(cost, expected,
		"Should apply multiplier to total cost")


func test_get_reroll_cost_rounds_down():
	economy_service.shop_reroll_count = 0
	var cost = economy_service.get_reroll_cost(1.25)
	assert_typeof(cost, TYPE_INT,
		"Cost should be an integer")


func test_get_reroll_cost_discount():
	economy_service.shop_reroll_count = 1
	var base_cost = GameConstants.REROLL_BASE_COST + GameConstants.REROLL_COST_INCREMENT
	var expected = int(base_cost * 0.5)
	var cost = economy_service.get_reroll_cost(0.5)
	assert_eq(cost, expected,
		"Should apply discount multiplier")


# =============================================================================
# WAVE GOLD BONUS CALCULATION
# =============================================================================

func test_get_wave_gold_bonus_wave_1():
	var bonus = economy_service.get_wave_gold_bonus(1, 1.0)
	var expected = GameConstants.GOLD_WAVE_BONUS_BASE
	assert_eq(bonus, expected,
		"Wave 1 should get base bonus")


func test_get_wave_gold_bonus_wave_5():
	var bonus = economy_service.get_wave_gold_bonus(5, 1.0)
	var expected = GameConstants.GOLD_WAVE_BONUS_BASE + (5 - 1) * 5
	assert_eq(bonus, expected,
		"Wave 5 bonus should scale")


func test_get_wave_gold_bonus_wave_10():
	var bonus = economy_service.get_wave_gold_bonus(10, 1.0)
	var expected = GameConstants.GOLD_WAVE_BONUS_BASE + (10 - 1) * 5
	assert_eq(bonus, expected,
		"Wave 10 bonus should scale")


func test_get_wave_gold_bonus_with_multiplier():
	var base_bonus = GameConstants.GOLD_WAVE_BONUS_BASE + (3 - 1) * 5
	var expected = int(base_bonus * 2.0)
	var bonus = economy_service.get_wave_gold_bonus(3, 2.0)
	assert_eq(bonus, expected,
		"Should apply multiplier to bonus")


func test_get_wave_gold_bonus_rounds_down():
	var bonus = economy_service.get_wave_gold_bonus(1, 1.33)
	assert_typeof(bonus, TYPE_INT,
		"Bonus should be an integer")


func test_get_wave_gold_bonus_increases_per_wave():
	var wave1 = economy_service.get_wave_gold_bonus(1, 1.0)
	var wave2 = economy_service.get_wave_gold_bonus(2, 1.0)
	var wave3 = economy_service.get_wave_gold_bonus(3, 1.0)

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

func test_negative_gold_deduction():
	economy_service.total_gold = 100
	var result = economy_service.deduct_gold(-50)
	assert_true(result, "Negative deduction should succeed")
	assert_eq(economy_service.total_gold, 150,
		"Negative deduction should add gold")


func test_large_gold_amounts():
	economy_service.total_gold = 999999
	economy_service.add_gold(100000, 1.0)
	assert_eq(economy_service.total_gold, 1099999,
		"Should handle large gold amounts")


func test_wave_bonus_wave_zero():
	# Edge case: wave 0 shouldn't happen but test gracefully
	var bonus = economy_service.get_wave_gold_bonus(0, 1.0)
	var expected = GameConstants.GOLD_WAVE_BONUS_BASE + (0 - 1) * 5
	assert_eq(bonus, expected,
		"Should handle wave 0 gracefully")

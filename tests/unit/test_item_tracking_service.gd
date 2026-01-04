extends GutTest

# =============================================================================
# Unit tests for ItemTrackingService
# Tests item collection tracking and modifier-related queries
# =============================================================================

var item_tracking_service: Node
var modifier_service: Node

func before_all() -> void:
	item_tracking_service = get_node("/root/ItemTrackingService")
	modifier_service = get_node("/root/ModifierService")

func before_each() -> void:
	item_tracking_service.reset_state()
	modifier_service.clear_modifiers()


# =============================================================================
# RESET STATE
# =============================================================================

func test_reset_state_clears_collected_items():
	item_tracking_service.collected_items.append("item1")
	item_tracking_service.collected_items.append("item2")
	item_tracking_service.reset_state()
	assert_eq(item_tracking_service.collected_items.size(), 0,
		"Reset should clear collected items")


func test_reset_state_clears_item_counts():
	item_tracking_service.item_counts = {"item1": 3, "item2": 1}
	item_tracking_service.reset_state()
	assert_eq(item_tracking_service.item_counts.size(), 0,
		"Reset should clear item counts")


# =============================================================================
# REROLL COST MULTIPLIER
# =============================================================================

func test_get_reroll_cost_multiplier_base():
	var mult = item_tracking_service.get_reroll_cost_multiplier()
	assert_eq(mult, 1.0,
		"Should return 1.0 without modifiers")


func test_get_reroll_cost_multiplier_with_discount():
	modifier_service.add_modifier({
		"stat": "reroll_cost",
		"operation": "multiply",
		"value": 0.5,
		"source": "discount_item"
	})
	var mult = item_tracking_service.get_reroll_cost_multiplier()
	assert_eq(mult, 0.5,
		"Should return discount multiplier")


func test_get_reroll_cost_multiplier_with_increase():
	modifier_service.add_modifier({
		"stat": "reroll_cost",
		"operation": "multiply",
		"value": 1.5,
		"source": "penalty_item"
	})
	var mult = item_tracking_service.get_reroll_cost_multiplier()
	assert_eq(mult, 1.5,
		"Should return increased cost multiplier")


func test_get_reroll_cost_multiplier_stacks():
	modifier_service.add_modifier({
		"stat": "reroll_cost",
		"operation": "multiply",
		"value": 0.8,
		"source": "item1"
	})
	modifier_service.add_modifier({
		"stat": "reroll_cost",
		"operation": "multiply",
		"value": 0.9,
		"source": "item2"
	})
	var mult = item_tracking_service.get_reroll_cost_multiplier()
	assert_eq(mult, 0.8 * 0.9,
		"Multiple multipliers should stack")


# =============================================================================
# GOLD EARN MULTIPLIER
# =============================================================================

func test_get_scrap_earn_multiplier_base():
	var mult = item_tracking_service.get_scrap_earn_multiplier()
	assert_eq(mult, 1.0,
		"Should return 1.0 without modifiers")


func test_get_scrap_earn_multiplier_with_bonus():
	modifier_service.add_modifier({
		"stat": "scrap_earn_mult",
		"operation": "multiply",
		"value": 1.25,
		"source": "scrap_boost_item"
	})
	var mult = item_tracking_service.get_scrap_earn_multiplier()
	assert_eq(mult, 1.25,
		"Should return scrap earn multiplier")


func test_get_scrap_earn_multiplier_with_penalty():
	modifier_service.add_modifier({
		"stat": "scrap_earn_mult",
		"operation": "multiply",
		"value": 0.75,
		"source": "scrap_penalty"
	})
	var mult = item_tracking_service.get_scrap_earn_multiplier()
	assert_eq(mult, 0.75,
		"Should return reduced scrap multiplier")


func test_get_scrap_earn_multiplier_multiple_sources():
	modifier_service.add_modifier({
		"stat": "scrap_earn_mult",
		"operation": "multiply",
		"value": 1.15,
		"source": "item1"
	})
	modifier_service.add_modifier({
		"stat": "scrap_earn_mult",
		"operation": "multiply",
		"value": 1.10,
		"source": "item2"
	})
	var mult = item_tracking_service.get_scrap_earn_multiplier()
	assert_almost_eq(mult, 1.15 * 1.10, 0.001,
		"Should stack scrap earn multipliers")


# =============================================================================
# ENEMY COUNT MULTIPLIER
# =============================================================================

func test_get_enemy_count_multiplier_base():
	var mult = item_tracking_service.get_enemy_count_multiplier()
	assert_eq(mult, 1.0,
		"Should return 1.0 without modifiers")


func test_get_enemy_count_multiplier_increased():
	modifier_service.add_modifier({
		"stat": "enemy_count_mult",
		"operation": "multiply",
		"value": 1.5,
		"source": "horde_mode_item"
	})
	var mult = item_tracking_service.get_enemy_count_multiplier()
	assert_eq(mult, 1.5,
		"Should return increased enemy count")


func test_get_enemy_count_multiplier_decreased():
	modifier_service.add_modifier({
		"stat": "enemy_count_mult",
		"operation": "multiply",
		"value": 0.7,
		"source": "fewer_enemies_item"
	})
	var mult = item_tracking_service.get_enemy_count_multiplier()
	assert_eq(mult, 0.7,
		"Should return decreased enemy count")


# =============================================================================
# SHOP PRICE MULTIPLIER
# =============================================================================

func test_get_shop_price_multiplier_base():
	var mult = item_tracking_service.get_shop_price_multiplier()
	assert_eq(mult, 1.0,
		"Should return 1.0 without modifiers")


func test_get_shop_price_multiplier_discount():
	modifier_service.add_modifier({
		"stat": "shop_price_mult",
		"operation": "multiply",
		"value": 0.8,
		"source": "discount_item"
	})
	var mult = item_tracking_service.get_shop_price_multiplier()
	assert_eq(mult, 0.8,
		"Should return shop discount")


func test_get_shop_price_multiplier_increase():
	modifier_service.add_modifier({
		"stat": "shop_price_mult",
		"operation": "multiply",
		"value": 1.3,
		"source": "expensive_item"
	})
	var mult = item_tracking_service.get_shop_price_multiplier()
	assert_eq(mult, 1.3,
		"Should return increased shop prices")


func test_get_shop_price_multiplier_stacking():
	modifier_service.add_modifier({
		"stat": "shop_price_mult",
		"operation": "multiply",
		"value": 0.9,
		"source": "discount1"
	})
	modifier_service.add_modifier({
		"stat": "shop_price_mult",
		"operation": "multiply",
		"value": 0.85,
		"source": "discount2"
	})
	var mult = item_tracking_service.get_shop_price_multiplier()
	assert_almost_eq(mult, 0.9 * 0.85, 0.001,
		"Multiple discounts should stack multiplicatively")


# =============================================================================
# WAVE BONUS MULTIPLIER
# =============================================================================

func test_get_wave_bonus_multiplier_base():
	var mult = item_tracking_service.get_wave_bonus_multiplier()
	assert_eq(mult, 1.0,
		"Should return 1.0 without modifiers")


func test_get_wave_bonus_multiplier_increased():
	modifier_service.add_modifier({
		"stat": "wave_bonus_mult",
		"operation": "multiply",
		"value": 1.5,
		"source": "bonus_item"
	})
	var mult = item_tracking_service.get_wave_bonus_multiplier()
	assert_eq(mult, 1.5,
		"Should return increased wave bonus")


func test_get_wave_bonus_multiplier_decreased():
	modifier_service.add_modifier({
		"stat": "wave_bonus_mult",
		"operation": "multiply",
		"value": 0.5,
		"source": "penalty_item"
	})
	var mult = item_tracking_service.get_wave_bonus_multiplier()
	assert_eq(mult, 0.5,
		"Should return decreased wave bonus")


# =============================================================================
# SHOP OFFER COUNT
# =============================================================================

func test_get_shop_offer_count_base():
	var count = item_tracking_service.get_shop_offer_count()
	assert_eq(count, GameConstants.SHOP_OFFER_COUNT,
		"Should return default offer count")


func test_get_shop_offer_count_increased():
	modifier_service.add_modifier({
		"stat": "shop_offer_count",
		"operation": "add",
		"value": 2.0,
		"source": "more_offers_item"
	})
	var count = item_tracking_service.get_shop_offer_count()
	assert_eq(count, GameConstants.SHOP_OFFER_COUNT + 2,
		"Should return increased offer count")


func test_get_shop_offer_count_decreased():
	modifier_service.add_modifier({
		"stat": "shop_offer_count",
		"operation": "add",
		"value": -1.0,
		"source": "fewer_offers_item"
	})
	var count = item_tracking_service.get_shop_offer_count()
	assert_eq(count, GameConstants.SHOP_OFFER_COUNT - 1,
		"Should return decreased offer count")


func test_get_shop_offer_count_returns_integer():
	modifier_service.add_modifier({
		"stat": "shop_offer_count",
		"operation": "add",
		"value": 1.7,
		"source": "item"
	})
	var count = item_tracking_service.get_shop_offer_count()
	assert_typeof(count, TYPE_INT,
		"Should return integer offer count")


func test_get_shop_offer_count_multiple_modifiers():
	modifier_service.add_modifier({
		"stat": "shop_offer_count",
		"operation": "add",
		"value": 1.0,
		"source": "item1"
	})
	modifier_service.add_modifier({
		"stat": "shop_offer_count",
		"operation": "add",
		"value": 2.0,
		"source": "item2"
	})
	var count = item_tracking_service.get_shop_offer_count()
	assert_eq(count, GameConstants.SHOP_OFFER_COUNT + 3,
		"Should stack additive modifiers")


# =============================================================================
# MODIFIER SERVICE INTEGRATION
# =============================================================================

func test_modifier_service_lazy_loaded():
	assert_not_null(item_tracking_service._get_modifier_service(),
		"Should lazy load modifier service")


func test_all_multipliers_with_different_modifiers():
	# Set up different modifiers for each stat
	modifier_service.add_modifier({
		"stat": "reroll_cost",
		"operation": "multiply",
		"value": 0.8,
		"source": "reroll_item"
	})
	modifier_service.add_modifier({
		"stat": "scrap_earn_mult",
		"operation": "multiply",
		"value": 1.2,
		"source": "gold_item"
	})
	modifier_service.add_modifier({
		"stat": "enemy_count_mult",
		"operation": "multiply",
		"value": 1.5,
		"source": "enemy_item"
	})
	modifier_service.add_modifier({
		"stat": "shop_price_mult",
		"operation": "multiply",
		"value": 0.9,
		"source": "shop_item"
	})
	modifier_service.add_modifier({
		"stat": "wave_bonus_mult",
		"operation": "multiply",
		"value": 1.3,
		"source": "wave_item"
	})

	assert_eq(item_tracking_service.get_reroll_cost_multiplier(), 0.8)
	assert_eq(item_tracking_service.get_scrap_earn_multiplier(), 1.2)
	assert_eq(item_tracking_service.get_enemy_count_multiplier(), 1.5)
	assert_eq(item_tracking_service.get_shop_price_multiplier(), 0.9)
	assert_eq(item_tracking_service.get_wave_bonus_multiplier(), 1.3)


# =============================================================================
# COLLECTION TRACKING
# =============================================================================

func test_collected_items_starts_empty():
	assert_eq(item_tracking_service.collected_items.size(), 0,
		"Should start with no collected items")


func test_item_counts_starts_empty():
	assert_eq(item_tracking_service.item_counts.size(), 0,
		"Should start with no item counts")


func test_can_track_collected_items():
	item_tracking_service.collected_items.append("plasma_accelerator")
	item_tracking_service.collected_items.append("fire_boost")
	assert_eq(item_tracking_service.collected_items.size(), 2,
		"Should track 2 collected items")
	assert_true("plasma_accelerator" in item_tracking_service.collected_items,
		"Should contain plasma_accelerator")
	assert_true("fire_boost" in item_tracking_service.collected_items,
		"Should contain fire_boost")


func test_can_track_item_counts():
	item_tracking_service.item_counts = {"stacking_item": 3, "another_item": 1}
	assert_eq(item_tracking_service.item_counts["stacking_item"], 3,
		"Should track stacking item count")
	assert_eq(item_tracking_service.item_counts["another_item"], 1,
		"Should track another item count")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_zero_multiplier_values():
	modifier_service.add_modifier({
		"stat": "scrap_earn_mult",
		"operation": "multiply",
		"value": 0.0,
		"source": "zero_gold"
	})
	var mult = item_tracking_service.get_scrap_earn_multiplier()
	assert_eq(mult, 0.0,
		"Should handle zero multiplier")


func test_very_large_multipliers():
	modifier_service.add_modifier({
		"stat": "enemy_count_mult",
		"operation": "multiply",
		"value": 10.0,
		"source": "huge_mult"
	})
	var mult = item_tracking_service.get_enemy_count_multiplier()
	assert_eq(mult, 10.0,
		"Should handle large multipliers")


func test_negative_shop_offer_count():
	modifier_service.add_modifier({
		"stat": "shop_offer_count",
		"operation": "add",
		"value": -100.0,
		"source": "penalty"
	})
	var count = item_tracking_service.get_shop_offer_count()
	# Note: No clamping in current implementation
	assert_lt(count, 0,
		"Should allow negative offer count (caller should clamp)")


func test_fractional_shop_offer_count_rounds():
	modifier_service.add_modifier({
		"stat": "shop_offer_count",
		"operation": "add",
		"value": 2.7,
		"source": "item"
	})
	var count = item_tracking_service.get_shop_offer_count()
	# int() truncates, so should round down
	assert_eq(count, GameConstants.SHOP_OFFER_COUNT + 2,
		"Should truncate fractional offers")

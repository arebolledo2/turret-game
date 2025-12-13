extends GutTest

# =============================================================================
# Integration tests for ShopManager
# Tests shop offer generation, purchasing, rerolling, and economy
# =============================================================================

var shop_manager: Node
var _shop_manager_script: GDScript


func before_all() -> void:
	_shop_manager_script = load("res://scripts/shop_manager.gd")


func before_each() -> void:
	Globals.reset_stats()
	Globals.current_difficulty = Globals.Difficulty.EASY
	Globals.current_wave = 1
	Globals.total_gold = Globals.STARTING_GOLD
	Globals.shop_reroll_count = 0
	Globals.current_shop_offers.clear()
	Globals.pending_turret_purchases.clear()
	# Create a fresh instance for each test
	shop_manager = _shop_manager_script.new()
	add_child_autofree(shop_manager)


# =============================================================================
# OFFER GENERATION
# =============================================================================

func test_generate_offers_creates_correct_count():
	shop_manager.generate_offers()

	# Should generate 3 turrets + 1 item = 4 offers
	assert_eq(Globals.current_shop_offers.size(), 4,
		"Should generate exactly 4 offers (3 turrets + 1 item)")


func test_generate_offers_has_turret_offers():
	shop_manager.generate_offers()

	var turret_count = 0
	for offer in Globals.current_shop_offers:
		if offer["type"] == "turret":
			turret_count += 1

	assert_eq(turret_count, 3, "Should have exactly 3 turret offers")


func test_generate_offers_has_item_offers():
	shop_manager.generate_offers()

	var item_count = 0
	for offer in Globals.current_shop_offers:
		if offer["type"] == "item":
			item_count += 1

	assert_eq(item_count, 1, "Should have exactly 1 item offer")


func test_turret_offers_have_valid_turret_ids():
	shop_manager.generate_offers()

	for offer in Globals.current_shop_offers:
		if offer["type"] == "turret":
			assert_has(Globals.TURRET_TYPES, offer["turret_id"],
				"Turret offer should have valid turret_id")


func test_item_offers_have_valid_item_ids():
	shop_manager.generate_offers()

	for offer in Globals.current_shop_offers:
		if offer["type"] == "item":
			assert_has(Globals.ITEMS, offer["item_id"],
				"Item offer should have valid item_id")


func test_offers_have_required_fields():
	shop_manager.generate_offers()

	for offer in Globals.current_shop_offers:
		assert_has(offer, "type", "Offer should have type")
		assert_has(offer, "price", "Offer should have price")
		assert_has(offer, "sold", "Offer should have sold flag")
		assert_false(offer["sold"], "New offers should not be sold")


func test_generate_offers_no_duplicate_turrets():
	shop_manager.generate_offers()

	var turret_ids = []
	for offer in Globals.current_shop_offers:
		if offer["type"] == "turret":
			assert_does_not_have(turret_ids, offer["turret_id"],
				"Should not have duplicate turret types")
			turret_ids.append(offer["turret_id"])


func test_generate_offers_clears_previous():
	# Generate first set
	shop_manager.generate_offers()
	var first_offers = Globals.current_shop_offers.duplicate(true)

	# Generate again
	shop_manager.generate_offers()

	# Should still have exactly 4 offers (not 8)
	assert_eq(Globals.current_shop_offers.size(), 4,
		"generate_offers should clear previous offers")


# =============================================================================
# PRICE CALCULATIONS
# =============================================================================

func test_turret_price_wave_1():
	Globals.current_wave = 1
	shop_manager.generate_offers()

	for offer in Globals.current_shop_offers:
		if offer["type"] == "turret":
			var base_price = Globals.TURRET_BASE_PRICES[offer["turret_id"]]
			var expected = int(base_price * (1.0 + Globals.WAVE_PRICE_SCALE * 1))
			assert_eq(offer["price"], expected,
				"Wave 1 turret price should be base * (1 + 0.15 * 1)")


func test_turret_price_scales_with_wave():
	Globals.current_wave = 5
	shop_manager.generate_offers()

	for offer in Globals.current_shop_offers:
		if offer["type"] == "turret":
			var base_price = Globals.TURRET_BASE_PRICES[offer["turret_id"]]
			var expected = int(base_price * (1.0 + Globals.WAVE_PRICE_SCALE * 5))
			assert_eq(offer["price"], expected,
				"Wave 5 turret price should be base * (1 + 0.15 * 5)")


func test_calculate_turret_price_formula():
	# Test the price calculation function directly
	var base_price = 100
	var wave = 3
	var expected = int(base_price * (1.0 + Globals.WAVE_PRICE_SCALE * wave))

	var result = shop_manager.calculate_turret_price(base_price, wave)
	assert_eq(result, expected, "Price formula: base * (1.0 + 0.15 * wave)")


func test_item_price_scales_with_wave():
	Globals.current_wave = 5
	shop_manager.generate_offers()

	for offer in Globals.current_shop_offers:
		if offer["type"] == "item":
			var item_data = Globals.ITEMS[offer["item_id"]]
			var base_price = Globals.ITEM_BASE_PRICES[item_data["rarity"]]
			var expected = int(base_price * (1.0 + Globals.WAVE_PRICE_SCALE * 5))
			assert_eq(offer["price"], expected,
				"Item price should scale with wave")


# =============================================================================
# PURCHASING - TURRETS
# =============================================================================

func test_purchase_turret_success():
	Globals.total_gold = 500
	shop_manager.generate_offers()

	var result = shop_manager.purchase_offer(0)

	assert_true(result, "Purchase should succeed with enough gold")


func test_purchase_turret_deducts_gold():
	Globals.total_gold = 500
	shop_manager.generate_offers()
	var price = Globals.current_shop_offers[0]["price"]

	shop_manager.purchase_offer(0)

	assert_eq(Globals.total_gold, 500 - price,
		"Purchase should deduct correct gold amount")


func test_purchase_turret_marks_sold():
	Globals.total_gold = 500
	shop_manager.generate_offers()

	shop_manager.purchase_offer(0)

	assert_true(Globals.current_shop_offers[0]["sold"],
		"Purchased offer should be marked as sold")


func test_purchase_turret_adds_to_pending():
	Globals.total_gold = 500
	shop_manager.generate_offers()

	# Find first turret offer
	var turret_index = -1
	for i in range(Globals.current_shop_offers.size()):
		if Globals.current_shop_offers[i]["type"] == "turret":
			turret_index = i
			break

	var turret_id = Globals.current_shop_offers[turret_index]["turret_id"]
	shop_manager.purchase_offer(turret_index)

	assert_has(Globals.pending_turret_purchases, turret_id,
		"Purchased turret should be added to pending purchases")


func test_purchase_insufficient_funds():
	Globals.total_gold = 1  # Very low gold
	shop_manager.generate_offers()

	var result = shop_manager.purchase_offer(0)

	assert_false(result, "Purchase should fail with insufficient gold")


func test_purchase_insufficient_funds_keeps_gold():
	Globals.total_gold = 1
	shop_manager.generate_offers()

	shop_manager.purchase_offer(0)

	assert_eq(Globals.total_gold, 1, "Failed purchase should not deduct gold")


func test_purchase_already_sold_fails():
	Globals.total_gold = 1000
	shop_manager.generate_offers()

	shop_manager.purchase_offer(0)
	var gold_after_first = Globals.total_gold

	var result = shop_manager.purchase_offer(0)

	assert_false(result, "Cannot purchase already sold offer")
	assert_eq(Globals.total_gold, gold_after_first,
		"Failed purchase should not deduct gold")


func test_purchase_invalid_index_negative():
	Globals.total_gold = 500
	shop_manager.generate_offers()

	var result = shop_manager.purchase_offer(-1)

	assert_false(result, "Negative index should fail")


func test_purchase_invalid_index_too_high():
	Globals.total_gold = 500
	shop_manager.generate_offers()

	var result = shop_manager.purchase_offer(100)

	assert_false(result, "Index beyond array should fail")


# =============================================================================
# PURCHASING - ITEMS
# =============================================================================

func test_purchase_item_adds_to_collected():
	Globals.total_gold = 500
	shop_manager.generate_offers()

	# Find item offer
	var item_index = -1
	var item_id = ""
	for i in range(Globals.current_shop_offers.size()):
		if Globals.current_shop_offers[i]["type"] == "item":
			item_index = i
			item_id = Globals.current_shop_offers[i]["item_id"]
			break

	if item_index >= 0:
		shop_manager.purchase_offer(item_index)
		assert_has(Globals.collected_items, item_id,
			"Purchased item should be added to collected items")


func test_purchase_item_adds_modifiers():
	Globals.total_gold = 500
	shop_manager.generate_offers()

	var initial_modifier_count = Globals.active_modifiers.size()

	# Find item offer
	var item_index = -1
	for i in range(Globals.current_shop_offers.size()):
		if Globals.current_shop_offers[i]["type"] == "item":
			item_index = i
			break

	if item_index >= 0:
		shop_manager.purchase_offer(item_index)
		assert_gt(Globals.active_modifiers.size(), initial_modifier_count,
			"Purchased item should add modifiers")


# =============================================================================
# REROLL SYSTEM
# =============================================================================

func test_get_reroll_cost_initial():
	Globals.shop_reroll_count = 0
	var cost = shop_manager.get_reroll_cost()

	var expected = Globals.REROLL_BASE_COST + (Globals.REROLL_COST_INCREMENT * 0)
	assert_eq(cost, expected, "First reroll should cost base cost")


func test_get_reroll_cost_increases():
	Globals.shop_reroll_count = 0
	var cost0 = shop_manager.get_reroll_cost()

	Globals.shop_reroll_count = 1
	var cost1 = shop_manager.get_reroll_cost()

	Globals.shop_reroll_count = 2
	var cost2 = shop_manager.get_reroll_cost()

	assert_lt(cost0, cost1, "Reroll cost should increase")
	assert_lt(cost1, cost2, "Reroll cost should continue increasing")


func test_get_reroll_cost_formula():
	for i in range(5):
		Globals.shop_reroll_count = i
		var cost = shop_manager.get_reroll_cost()
		var expected = Globals.REROLL_BASE_COST + (Globals.REROLL_COST_INCREMENT * i)
		assert_eq(cost, expected, "Reroll %d cost should be %d" % [i, expected])


func test_reroll_shop_success():
	Globals.total_gold = 100
	shop_manager.generate_offers()

	var result = shop_manager.reroll_shop()

	assert_true(result, "Reroll should succeed with enough gold")


func test_reroll_shop_deducts_gold():
	Globals.total_gold = 100
	Globals.shop_reroll_count = 0
	shop_manager.generate_offers()

	var reroll_cost = shop_manager.get_reroll_cost()
	shop_manager.reroll_shop()

	assert_eq(Globals.total_gold, 100 - reroll_cost,
		"Reroll should deduct correct gold amount")


func test_reroll_shop_increments_count():
	Globals.total_gold = 100
	Globals.shop_reroll_count = 0
	shop_manager.generate_offers()

	shop_manager.reroll_shop()

	assert_eq(Globals.shop_reroll_count, 1, "Reroll count should increment")


func test_reroll_shop_generates_new_offers():
	Globals.total_gold = 100
	shop_manager.generate_offers()
	var old_offers = Globals.current_shop_offers.duplicate(true)

	shop_manager.reroll_shop()

	# At minimum, still should have 4 offers
	assert_eq(Globals.current_shop_offers.size(), 4,
		"Reroll should generate new offers")


func test_reroll_insufficient_funds():
	Globals.total_gold = 0
	shop_manager.generate_offers()

	var result = shop_manager.reroll_shop()

	assert_false(result, "Reroll should fail with insufficient gold")


func test_reroll_max_rerolls_reached():
	Globals.total_gold = 1000
	Globals.shop_reroll_count = Globals.MAX_REROLLS_PER_WAVE
	shop_manager.generate_offers()

	var result = shop_manager.reroll_shop()

	assert_false(result, "Reroll should fail when max reached")


func test_can_afford_reroll_with_gold():
	Globals.total_gold = 100
	Globals.shop_reroll_count = 0

	var result = shop_manager.can_afford_reroll()

	assert_true(result, "Should be able to afford reroll with enough gold")


func test_can_afford_reroll_without_gold():
	Globals.total_gold = 0
	Globals.shop_reroll_count = 0

	var result = shop_manager.can_afford_reroll()

	assert_false(result, "Should not be able to afford reroll without gold")


func test_can_afford_reroll_max_reached():
	Globals.total_gold = 1000
	Globals.shop_reroll_count = Globals.MAX_REROLLS_PER_WAVE

	var result = shop_manager.can_afford_reroll()

	assert_false(result, "Should not be able to reroll when max reached")


# =============================================================================
# SIGNALS
# =============================================================================

func test_purchase_emits_gold_spent_signal():
	Globals.total_gold = 500
	shop_manager.generate_offers()
	watch_signals(Events)

	shop_manager.purchase_offer(0)

	assert_signal_emitted(Events, "gold_spent")


func test_purchase_emits_shop_purchase_made_signal():
	Globals.total_gold = 500
	shop_manager.generate_offers()
	watch_signals(Events)

	shop_manager.purchase_offer(0)

	assert_signal_emitted(Events, "shop_purchase_made")


func test_insufficient_funds_emits_signal():
	Globals.total_gold = 1
	shop_manager.generate_offers()
	watch_signals(Events)

	shop_manager.purchase_offer(0)

	assert_signal_emitted(Events, "shop_insufficient_funds")


func test_reroll_emits_gold_spent_signal():
	Globals.total_gold = 100
	shop_manager.generate_offers()
	watch_signals(Events)

	shop_manager.reroll_shop()

	assert_signal_emitted(Events, "gold_spent")


func test_reroll_emits_shop_rerolled_signal():
	Globals.total_gold = 100
	shop_manager.generate_offers()
	watch_signals(Events)

	shop_manager.reroll_shop()

	assert_signal_emitted(Events, "shop_rerolled")


func test_generate_offers_emits_signal():
	watch_signals(Events)

	shop_manager.generate_offers()

	assert_signal_emitted(Events, "shop_offers_generated")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_multiple_purchases_in_one_shop():
	Globals.total_gold = 2000
	shop_manager.generate_offers()

	# Buy all offers
	for i in range(Globals.current_shop_offers.size()):
		shop_manager.purchase_offer(i)

	# Count sold
	var sold_count = 0
	for offer in Globals.current_shop_offers:
		if offer["sold"]:
			sold_count += 1

	assert_eq(sold_count, 4, "Should be able to buy all offers with enough gold")


func test_gold_exactly_enough():
	shop_manager.generate_offers()
	var price = Globals.current_shop_offers[0]["price"]
	Globals.total_gold = price

	var result = shop_manager.purchase_offer(0)

	assert_true(result, "Should be able to purchase with exact gold amount")
	assert_eq(Globals.total_gold, 0, "Should have zero gold after purchase")


func test_reroll_then_purchase():
	Globals.total_gold = 500
	shop_manager.generate_offers()

	# Reroll
	shop_manager.reroll_shop()

	# Purchase from new offers
	var result = shop_manager.purchase_offer(0)

	assert_true(result, "Should be able to purchase after reroll")

extends GutTest

# =============================================================================
# Unit tests for LootService
# Tests item drop rolling, found items tracking, and pending loot state
# =============================================================================


func before_each() -> void:
	# Reset service state
	LootService.reset_state()
	GameStateService.reset_state()
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)


# =============================================================================
# RESET FUNCTIONALITY
# =============================================================================

func test_reset_clears_found_items() -> void:
	LootService.add_found_item("test_item_1")
	LootService.add_found_item("test_item_2")
	assert_eq(LootService.found_items.size(), 2)
	
	LootService.reset_state()
	assert_eq(LootService.found_items.size(), 0, "Reset should clear found items")


# =============================================================================
# FOUND ITEMS TRACKING
# =============================================================================

func test_add_found_item_adds_to_list() -> void:
	assert_eq(LootService.found_items.size(), 0)
	
	LootService.add_found_item("lucky_charm")
	assert_eq(LootService.found_items.size(), 1)
	assert_eq(LootService.found_items[0], "lucky_charm")


func test_add_found_item_allows_duplicates() -> void:
	LootService.add_found_item("lucky_charm")
	LootService.add_found_item("lucky_charm")
	assert_eq(LootService.found_items.size(), 2, "Should allow duplicate items")


func test_get_found_items_returns_copy() -> void:
	LootService.add_found_item("test_item")
	var items = LootService.get_found_items()
	items.clear()
	
	assert_eq(LootService.found_items.size(), 1, "Original list should be unchanged")


func test_clear_found_items_empties_list() -> void:
	LootService.add_found_item("item1")
	LootService.add_found_item("item2")
	
	LootService.clear_found_items()
	assert_eq(LootService.found_items.size(), 0, "Clear should empty the list")


# =============================================================================
# PENDING LOOT STATE
# =============================================================================

func test_has_pending_loot_false_when_empty() -> void:
	assert_false(LootService.has_pending_loot(), "Should be false with no items")


func test_has_pending_loot_true_when_items_exist() -> void:
	LootService.add_found_item("test_item")
	assert_true(LootService.has_pending_loot(), "Should be true with items")


# =============================================================================
# ITEM DROP ROLLING
# =============================================================================

func test_roll_for_item_drop_returns_empty_on_no_drop() -> void:
	# Run multiple times to test probability (30% chance)
	var empty_count := 0
	for i in range(100):
		var result = LootService.roll_for_item_drop(1)
		if result.is_empty():
			empty_count += 1
	
	# With 30% drop chance, expect ~70 empty results
	assert_gte(empty_count, 40, "Should often return empty (no drop)")
	assert_lte(empty_count, 95, "Should sometimes return items")


func test_roll_for_item_drop_returns_valid_item_id() -> void:
	# Run until we get an item (should happen within reasonable tries)
	var item_id := ""
	for i in range(50):
		item_id = LootService.roll_for_item_drop(1)
		if not item_id.is_empty():
			break
	
	if not item_id.is_empty():
		assert_true(ItemRegistry.has_item(item_id), "Returned item should exist in registry")


# =============================================================================
# DROP CHANCE CONSTANT
# =============================================================================

func test_drop_chance_is_reasonable() -> void:
	var chance := GameConstants.TECH_DROP_ITEM_DROP_CHANCE
	assert_gt(chance, 0.0, "Drop chance should be positive")
	assert_lte(chance, 1.0, "Drop chance should be at most 100%")
	assert_eq(chance, 0.30, "Drop chance should be 30%")


# =============================================================================
# ITEM DROP ROLLING - WAVE SCALING
# =============================================================================

func test_roll_for_item_drop_wave_1() -> void:
	var drop_count := 0
	for i in range(200):
		var result := LootService.roll_for_item_drop(1)
		if not result.is_empty():
			drop_count += 1

	# With 30% chance, expect ~60 drops out of 200
	assert_gt(drop_count, 20, "Should get some drops at wave 1")
	assert_lt(drop_count, 120, "Should not get drops every time")


func test_roll_for_item_drop_higher_wave_returns_valid_items() -> void:
	for wave in [3, 5, 8, 10]:
		var item_id := ""
		for i in range(50):
			item_id = LootService.roll_for_item_drop(wave)
			if not item_id.is_empty():
				break

		if not item_id.is_empty():
			assert_true(ItemRegistry.has_item(item_id),
				"Item from wave %d should exist in registry" % wave)


# =============================================================================
# MULTIPLE FOUND ITEMS
# =============================================================================

func test_found_items_preserve_order() -> void:
	LootService.add_found_item("item_a")
	LootService.add_found_item("item_b")
	LootService.add_found_item("item_c")

	var items := LootService.get_found_items()
	assert_eq(items[0], "item_a", "First item should be item_a")
	assert_eq(items[1], "item_b", "Second item should be item_b")
	assert_eq(items[2], "item_c", "Third item should be item_c")


func test_found_items_count_after_many_adds() -> void:
	for i in range(20):
		LootService.add_found_item("item_%d" % i)

	assert_eq(LootService.found_items.size(), 20,
		"Should track all 20 items")


func test_clear_found_items_then_add_works() -> void:
	LootService.add_found_item("old_item")
	LootService.clear_found_items()
	LootService.add_found_item("new_item")

	assert_eq(LootService.found_items.size(), 1, "Should have one item")
	assert_eq(LootService.found_items[0], "new_item", "Should be the new item")


# =============================================================================
# RESET VS CLEAR DISTINCTION
# =============================================================================

func test_reset_clears_all_state() -> void:
	LootService.add_found_item("test")
	LootService.reset_state()
	assert_false(LootService.has_pending_loot(),
		"Reset should clear pending loot")


func test_clear_found_items_only_clears_items() -> void:
	LootService.add_found_item("item1")
	LootService.clear_found_items()
	assert_eq(LootService.found_items.size(), 0,
		"Clear should empty items list")
	assert_false(LootService.has_pending_loot(),
		"Should have no pending loot after clear")

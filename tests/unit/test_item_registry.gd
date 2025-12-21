extends GutTest

# =============================================================================
# Unit tests for ItemRegistry
# Tests item definitions, rarity system, and pricing
# =============================================================================


# =============================================================================
# ITEM DEFINITIONS
# =============================================================================

func test_all_items_exist():
	# Shop V2 items
	var expected_items = ["scrap_magnet", "reinforced_hull", "quick_loader", "shock_absorbers", "dense_rounds"]
	for item_id in expected_items:
		assert_true(ItemRegistry.has_item(item_id), "Item '%s' should exist" % item_id)


func test_get_all_item_ids():
	var ids = ItemRegistry.get_all_item_ids()
	assert_gt(ids.size(), 0, "Should return at least one item ID")
	assert_has(ids, "scrap_magnet", "Should include 'scrap_magnet'")


func test_get_item_returns_valid_definition():
	var item = ItemRegistry.get_item("scrap_magnet")
	assert_not_null(item, "Item should exist")
	assert_not_null(item.name, "Item should have name")
	assert_not_null(item.description, "Item should have description")
	assert_not_null(item.icon, "Item should have icon")
	assert_not_null(item.rarity, "Item should have rarity")
	assert_not_null(item.modifiers, "Item should have modifiers")


func test_get_item_nonexistent_returns_empty():
	var item = ItemRegistry.get_item("nonexistent_item")
	assert_null(item, "Non-existent item should return null")


func test_has_item_returns_true_for_valid():
	assert_true(ItemRegistry.has_item("dense_rounds"), "Should return true for valid item")


func test_has_item_returns_false_for_invalid():
	assert_false(ItemRegistry.has_item("fake_item"), "Should return false for invalid item")


func test_all_items_have_required_fields():
	for item_id in ItemRegistry.get_all_item_ids():
		var item = ItemRegistry.get_item(item_id)
		assert_not_null(item, "%s should exist" % item_id)
		assert_not_null(item.name, "%s should have name" % item_id)
		assert_not_null(item.description, "%s should have description" % item_id)
		assert_typeof(item.rarity, TYPE_INT, "%s should have rarity" % item_id)
		assert_typeof(item.modifiers, TYPE_ARRAY, "%s should have modifiers" % item_id)


func test_all_items_have_at_least_one_modifier():
	# Note: Some items like executioners_mark have special_effect instead of modifiers
	for item_id in ItemRegistry.get_all_item_ids():
		var item = ItemRegistry.get_item(item_id)
		var modifiers = ItemRegistry.get_modifiers(item_id)
		var has_special_effect = not item.special_effect.is_empty()
		assert_true(modifiers.size() > 0 or has_special_effect,
			"%s should have at least one modifier or a special_effect" % item_id)


# =============================================================================
# RARITY SYSTEM
# =============================================================================

func test_get_rarity_returns_correct_rarity():
	var rarity = ItemRegistry.get_rarity("scrap_magnet")
	assert_eq(rarity, GameEnums.ItemRarity.COMMON, "Scrap magnet should be COMMON rarity")


func test_get_rarity_fallback_for_invalid():
	var rarity = ItemRegistry.get_rarity("nonexistent")
	assert_eq(rarity, GameEnums.ItemRarity.COMMON, "Invalid item should default to COMMON")


func test_all_rarity_colors_defined():
	var rarities = [
		GameEnums.ItemRarity.COMMON,
		GameEnums.ItemRarity.UNCOMMON,
		GameEnums.ItemRarity.RARE,
		GameEnums.ItemRarity.EPIC,
		GameEnums.ItemRarity.LEGENDARY,
		GameEnums.ItemRarity.UNIQUE
	]
	for rarity in rarities:
		var color = ItemRegistry.get_rarity_color(rarity)
		assert_ne(color, Color.BLACK, "Rarity %s should have a defined color" % rarity)


func test_rarity_color_common_is_white():
	var color = ItemRegistry.get_rarity_color(GameEnums.ItemRarity.COMMON)
	assert_eq(color, Color.WHITE, "COMMON rarity should be WHITE")


func test_rarity_color_uncommon_is_green():
	var color = ItemRegistry.get_rarity_color(GameEnums.ItemRarity.UNCOMMON)
	assert_eq(color, Color.GREEN, "UNCOMMON rarity should be GREEN")


func test_rarity_color_rare_is_blue():
	var color = ItemRegistry.get_rarity_color(GameEnums.ItemRarity.RARE)
	assert_eq(color, Color.CORNFLOWER_BLUE, "RARE rarity should be CORNFLOWER_BLUE")


func test_all_rarity_names_defined():
	var rarities = [
		GameEnums.ItemRarity.COMMON,
		GameEnums.ItemRarity.UNCOMMON,
		GameEnums.ItemRarity.RARE,
		GameEnums.ItemRarity.EPIC,
		GameEnums.ItemRarity.LEGENDARY,
		GameEnums.ItemRarity.UNIQUE
	]
	for rarity in rarities:
		var name = ItemRegistry.get_rarity_name(rarity)
		assert_ne(name, "", "Rarity %s should have a name" % rarity)


func test_rarity_name_common():
	assert_eq(ItemRegistry.get_rarity_name(GameEnums.ItemRarity.COMMON), "Common")


func test_rarity_name_legendary():
	assert_eq(ItemRegistry.get_rarity_name(GameEnums.ItemRarity.LEGENDARY), "Legendary")


# =============================================================================
# PRICING SYSTEM
# =============================================================================

func test_rarity_price_common():
	var price = ItemRegistry.get_rarity_price(GameEnums.ItemRarity.COMMON)
	assert_eq(price, 40, "COMMON base price should be 40")


func test_rarity_price_uncommon():
	var price = ItemRegistry.get_rarity_price(GameEnums.ItemRarity.UNCOMMON)
	assert_eq(price, 70, "UNCOMMON base price should be 70")


func test_rarity_price_rare():
	var price = ItemRegistry.get_rarity_price(GameEnums.ItemRarity.RARE)
	assert_eq(price, 110, "RARE base price should be 110")


func test_rarity_price_epic():
	var price = ItemRegistry.get_rarity_price(GameEnums.ItemRarity.EPIC)
	assert_eq(price, 160, "EPIC base price should be 160")


func test_rarity_price_legendary():
	var price = ItemRegistry.get_rarity_price(GameEnums.ItemRarity.LEGENDARY)
	assert_eq(price, 240, "LEGENDARY base price should be 240")


func test_rarity_price_unique():
	var price = ItemRegistry.get_rarity_price(GameEnums.ItemRarity.UNIQUE)
	assert_eq(price, 350, "UNIQUE base price should be 350")


func test_price_increases_with_rarity():
	var common_price = ItemRegistry.get_rarity_price(GameEnums.ItemRarity.COMMON)
	var uncommon_price = ItemRegistry.get_rarity_price(GameEnums.ItemRarity.UNCOMMON)
	var rare_price = ItemRegistry.get_rarity_price(GameEnums.ItemRarity.RARE)
	var epic_price = ItemRegistry.get_rarity_price(GameEnums.ItemRarity.EPIC)
	var legendary_price = ItemRegistry.get_rarity_price(GameEnums.ItemRarity.LEGENDARY)

	assert_lt(common_price, uncommon_price, "Common < Uncommon")
	assert_lt(uncommon_price, rare_price, "Uncommon < Rare")
	assert_lt(rare_price, epic_price, "Rare < Epic")
	assert_lt(epic_price, legendary_price, "Epic < Legendary")


func test_get_item_price():
	var price = ItemRegistry.get_item_price("scrap_magnet")
	var expected = ItemRegistry.get_rarity_price(GameEnums.ItemRarity.COMMON)
	assert_eq(price, expected, "Item price should match rarity price")


func test_get_item_price_invalid():
	var price = ItemRegistry.get_item_price("nonexistent")
	assert_eq(price, 40, "Invalid item should default to COMMON price")


# =============================================================================
# MODIFIERS
# =============================================================================

func test_get_modifiers_returns_array():
	var mods = ItemRegistry.get_modifiers("scrap_magnet")
	assert_typeof(mods, TYPE_ARRAY, "get_modifiers should return array")


func test_get_modifiers_nonexistent_returns_empty():
	var mods = ItemRegistry.get_modifiers("nonexistent")
	assert_eq(mods.size(), 0, "Non-existent item should return empty modifiers")


func test_shock_absorbers_has_speed_modifier():
	var mods = ItemRegistry.get_modifiers("shock_absorbers")
	var has_speed_mod = false
	for mod in mods:
		if mod.get("stat") == "player_speed":
			has_speed_mod = true
			assert_eq(mod.get("operation"), "multiply", "Speed modifier should be multiply")
			assert_gt(mod.get("value"), 1.0, "Speed modifier should increase speed")
	assert_true(has_speed_mod, "Shock absorbers should have speed modifier")


func test_dense_rounds_has_damage_modifier():
	var mods = ItemRegistry.get_modifiers("dense_rounds")
	var has_damage_mod = false
	for mod in mods:
		if mod.get("stat") == "damage":
			has_damage_mod = true
			assert_gt(mod.get("value"), 1.0, "Damage modifier should increase damage")
	assert_true(has_damage_mod, "Dense rounds should have damage modifier")


func test_reinforced_hull_has_health_modifier():
	var mods = ItemRegistry.get_modifiers("reinforced_hull")
	var has_health_mod = false
	for mod in mods:
		if mod.get("stat") == "player_max_health":
			has_health_mod = true
			assert_gt(mod.get("value"), 0.0, "Health modifier should be positive add")
	assert_true(has_health_mod, "Reinforced hull should have health modifier")


func test_modifier_has_required_fields():
	for item_id in ItemRegistry.get_all_item_ids():
		var mods = ItemRegistry.get_modifiers(item_id)
		for mod in mods:
			assert_has(mod, "stat", "%s modifier should have stat" % item_id)
			assert_has(mod, "operation", "%s modifier should have operation" % item_id)
			assert_has(mod, "value", "%s modifier should have value" % item_id)

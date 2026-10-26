extends GutTest

const GATE: String = "test_shop_gate"

func before_each() -> void:
	TestHelpers.reset_all_services()
	FeatureFlagService.reset_state()
	ShopCatalog.reset()


func after_each() -> void:
	ShopCatalog.reset()
	FeatureFlagService.reset_state()


func test_default_catalog_matches_the_supported_content() -> void:
	assert_eq(ShopCatalog.available_ids("item"), ShopCatalog.ids("item"))
	assert_eq(ShopCatalog.available_ids("turret"), ShopCatalog.ids("turret"))
	for item_id in ShopCatalog.ids("item"):
		assert_true(ItemRegistry.has_item(item_id), "%s must exist in the registry" % item_id)
	for type_id in ShopCatalog.ids("turret"):
		assert_true(TurretRegistry.TYPES.has(type_id), "%s must exist in the registry" % type_id)


func test_stocked_turrets_and_the_form_table_agree() -> void:
	var stocked := ShopCatalog.ids("turret")
	assert_eq(ArenaShop.TURRETS, stocked, "The arena shop sells exactly the catalog's turrets")
	for type_id in stocked:
		assert_true(type_id in TurretEvolution.bases(), "%s is stocked, so the form table needs its upgrade and two finals" % type_id)
		assert_true(TurretRegistry.BASE_PRICES.has(type_id), "%s has a registry price" % type_id)
	for base in TurretEvolution.bases():
		for form in TurretEvolution.options(base, 0) + TurretEvolution.options(base, 1):
			if TurretEvolution.is_implemented(form):
				assert_true(base in stocked, "%s has the built form %s, so the shop must stock it" % [base, form])


func test_unknown_entries_are_never_available() -> void:
	assert_false(ShopCatalog.is_available("item", "salvage_optimizer"))
	assert_false(ShopCatalog.is_available("turret", "missing"))
	assert_false(ShopCatalog.is_available("widget", "scrap_magnet"))


func test_flag_gated_entries_follow_their_flag() -> void:
	FeatureFlagService.register_flag(GATE, {"name": "Gate", "scope": FeatureFlagService.SCOPE_EXPERIMENT})
	ShopCatalog.entries["item"]["salvage_optimizer"] = GATE
	assert_eq(ShopCatalog.requires_flag("item", "salvage_optimizer"), GATE)
	assert_false(ShopCatalog.is_available("item", "salvage_optimizer"))
	assert_false("salvage_optimizer" in ShopCatalog.available_ids("item"))
	FeatureFlagService.set_enabled(GATE, true)
	assert_true(ShopCatalog.is_available("item", "salvage_optimizer"))
	assert_true("salvage_optimizer" in ShopCatalog.available_ids("item"))

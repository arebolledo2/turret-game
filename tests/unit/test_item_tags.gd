extends GutTest

func after_each() -> void:
	ModifierService.clear_modifiers()

func test_families_map_turret_types() -> void:
	assert_eq(TurretRegistry.get_family("normal"), "ion")
	assert_eq(TurretRegistry.get_family("plasma"), "plasma")
	assert_eq(TurretRegistry.get_family("shock"), "electric")
	assert_eq(TurretRegistry.get_family("tesla"), "electric")
	assert_eq(TurretRegistry.get_family("melee"), "melee")
	assert_eq(TurretRegistry.get_family("mine"), "")

func test_family_filter_scopes_a_modifier() -> void:
	ModifierService.add_modifier(Item.create_increase("damage", .25, Item.filter_family(["electric"])))
	var base_tesla := float(TurretRegistry.get_base_stats("tesla")["damage"])
	var base_ion := float(TurretRegistry.get_base_stats("normal")["damage"])
	assert_almost_eq(float(ModifierService.get_turret_stats("tesla", {"turret_damage_mult": 1.0})["damage"]), base_tesla * 1.25, .001)
	assert_almost_eq(float(ModifierService.get_turret_stats("shock", {"turret_damage_mult": 1.0})["damage"]), float(TurretRegistry.get_base_stats("shock")["damage"]) * 1.25, .001)
	assert_almost_eq(float(ModifierService.get_turret_stats("normal", {"turret_damage_mult": 1.0})["damage"]), base_ion, .001)

func test_every_catalogued_item_has_a_known_tag() -> void:
	for item_id in ShopCatalog.ids("item"):
		assert_true(ItemRegistry.get_tag(item_id) in ItemRegistry.TAGS, item_id)

func test_weapon_stock_fits_the_offer_count() -> void:
	assert_lte(GameConstants.SHOP_TURRET_MAX, GameConstants.SHOP_OFFER_COUNT)

func test_shop_text_names_effect_audience_without_category_prefixes() -> void:
	assert_eq(ArenaShop.item_description("polished_barrels"), "Projectile damage +10%.")
	for id: String in ShopCatalog.ids("item"):
		var offer := ShopOffer.new("item", id, 10)
		assert_false(ArenaShop.offer_name(offer).begins_with("["))
		assert_false("Tags:" in ArenaShop.offer_description(offer))

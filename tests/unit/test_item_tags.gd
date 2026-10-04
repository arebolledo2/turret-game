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

func test_shop_slots_add_up_to_the_offer_count() -> void:
	assert_eq(GameConstants.SHOP_TURRET_SLOTS + GameConstants.SHOP_ITEM_SLOTS, GameConstants.SHOP_OFFER_COUNT)

func test_item_text_names_the_audience() -> void:
	var text := ArenaShop._scoped_label("turret damage", Item.filter_family(["ion"]))
	assert_eq(text, "Ion turret damage")
	assert_eq(ArenaShop._scoped_label("turret range", Item.filter_turret_type(["all"])), "turret range")
	assert_eq(ArenaShop._scoped_label("move speed", Item.filter_family(["ion"])), "move speed")

extends GutTest

func after_each() -> void:
	ModifierService.clear_modifiers()

func test_families_map_turret_types() -> void:
	assert_eq(TurretRegistry.get_family("normal"), "ion")
	assert_eq(TurretRegistry.get_family("plasma"), "plasma")
	assert_eq(TurretRegistry.get_family("shock"), "electric")
	assert_eq(TurretRegistry.get_family("tesla"), "electric")
	assert_eq(TurretRegistry.get_family("melee"), "melee")
	assert_eq(TurretRegistry.get_family("mine_layer"), "")

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

func _utility_definition() -> Dictionary:
	var definition: Dictionary = TurretRegistry.get_type("normal").duplicate(true)
	definition["attack_styles"] = []
	definition["no_attack"] = true
	return definition

func test_aggro_is_a_build_family_holding_only_the_decoy_so_far() -> void:
	assert_true(TurretRegistry.FAMILIES.has("aggro"))
	assert_eq(TurretRegistry.FAMILIES["aggro"], ["decoy"], "Lullaby and Discord are not registered yet")
	assert_eq(TurretRegistry.get_family("decoy"), "aggro")
	for type_id: String in TurretRegistry.get_all_type_ids():
		if type_id != "decoy":
			assert_ne(TurretRegistry.get_family(type_id), "aggro", type_id)
	# An aggro-scoped item reaches the Decoy alone, and does not disturb the other families.
	ModifierService.add_modifier(Item.create_increase("damage", .5, Item.filter_family(["aggro"])))
	assert_almost_eq(float(ModifierService.get_turret_stats("decoy", {"turret_damage_mult": 1.0})["damage"]), float(TurretRegistry.get_base_stats("decoy")["damage"]) * 1.5, .001, "decoy")
	for type_id in ["normal", "plasma", "shock", "tesla", "melee", "mine_layer"]:
		assert_almost_eq(float(ModifierService.get_turret_stats(type_id, {"turret_damage_mult": 1.0})["damage"]), float(TurretRegistry.get_base_stats(type_id)["damage"]), .001, type_id)

func test_every_family_lists_only_registered_turrets_and_each_turret_has_one_family() -> void:
	var owners := {}
	for family: String in TurretRegistry.FAMILIES:
		for type_id: String in TurretRegistry.FAMILIES[family]:
			assert_true(TurretRegistry.TYPES.has(type_id), "%s in %s" % [type_id, family])
			assert_false(owners.has(type_id), "%s appears in two families" % type_id)
			owners[type_id] = family

func test_deployable_maps_to_the_aoe_family_so_aoe_items_reach_mines() -> void:
	assert_eq(TurretRegistry.get_attack_families("mine_layer"), ["aoe"])
	var base := float(TurretRegistry.get_base_stats("mine_layer")["damage"])
	ModifierService.add_modifier({"stat": "damage", "operation": "increase", "value": .2, "filter": {"attack_family": ["aoe"]}})
	assert_almost_eq(float(ModifierService.get_turret_stats("mine_layer", {"turret_damage_mult": 1.0})["damage"]), base * 1.2, .001)
	ModifierService.clear_modifiers()
	ModifierService.add_modifier({"stat": "damage", "operation": "increase", "value": .2, "filter": {"attack_family": ["projectile"]}})
	assert_almost_eq(float(ModifierService.get_turret_stats("mine_layer", {"turret_damage_mult": 1.0})["damage"]), base, .001)

func test_deployable_plus_aoe_style_lists_the_aoe_family_once() -> void:
	var definition: Dictionary = TurretRegistry.get_type("mine_layer").duplicate(true)
	definition["attack_styles"] = [GameEnums.AttackStyle.AOE, GameEnums.AttackStyle.DEPLOYABLE]
	TurretRegistry.register_test_type("test_hybrid_mine", definition)
	assert_eq(TurretRegistry.get_attack_families("test_hybrid_mine"), ["aoe"])
	TurretRegistry.clear_test_types()

func test_no_attack_marker_is_a_capability_of_flagged_entries_only() -> void:
	# The Scrap Press is the one registered utility turret so far; every other entry attacks.
	for type_id: String in TurretRegistry.get_all_type_ids():
		var utility := type_id == "scrap_press"
		assert_eq(TurretRegistry.is_no_attack(type_id), utility, type_id)
		assert_eq(TurretRegistry.has_capability(type_id, "no_attack"), utility, type_id)
	assert_false(TurretRegistry.is_no_attack("not_a_turret"))
	TurretRegistry.register_test_type("test_beacon", _utility_definition())
	assert_true(TurretRegistry.is_no_attack("test_beacon"))
	assert_true(TurretRegistry.has_capability("test_beacon", "no_attack"))
	assert_true(TurretRegistry.get_attack_families("test_beacon").is_empty())
	TurretRegistry.clear_test_types()

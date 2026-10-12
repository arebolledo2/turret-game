extends GutTest

const V2_IDS := ["polished_barrels", "blast_charges", "capacitor_bank", "weighted_bat", "concrete_footings", "static_grounding",
	"faulty_wiring", "ion_doctrine", "plasma_doctrine", "voltage_doctrine", "bat_doctrine", "piercing_rounds",
	"cluster_warheads", "superconductors", "spiked_bat", "hardpoint", "arc_rod", "plasma_capacitor", "killzone_bat",
	"overwatch_optics", "army_doctrine", "elite_forces", "last_stand", "quality_over_quantity", "glass_cannon_core",
	"mono_type_mastery", "reactor_overload", "storm_conductor", "elemental_conduit", "whirlwind_frame"]

func before_each() -> void:
	FeatureFlagService.reset_state()
	ModifierService.clear_modifiers()

func after_each() -> void:
	ShopCatalog.reset()
	ModifierService.clear_modifiers()
	FeatureFlagService.reset_state()

func _stat(type_id: String, stat: String) -> float:
	return float(ModifierService.get_turret_stats(type_id, {"turret_damage_mult": 1.0}).get(stat, 0.0))

func _base(type_id: String, stat: String) -> float:
	return float(TurretRegistry.get_base_stats(type_id).get(stat, 0.0))

func _own(item_id: String) -> void:
	for modifier: Dictionary in ItemRegistry.get_modifiers(item_id):
		ModifierService.add_modifier(modifier.duplicate(true))

func test_every_v2_item_exists_with_tag_and_modifiers() -> void:
	for item_id in V2_IDS:
		assert_true(ItemRegistry.has_item(item_id), item_id)
		assert_true(ItemRegistry.get_tag(item_id) in ItemRegistry.TAGS, item_id)
		assert_false(ItemRegistry.get_modifiers(item_id).is_empty() and ItemRegistry.get_item_dict(item_id).get("special_effect", "").is_empty(), item_id)
		assert_false(ArenaShop.item_description(item_id).is_empty(), item_id)

func test_pool_rarity_split_is_13_20_12_9_2() -> void: # includes the 3 convoy items (1 common, 2 uncommon)
	var counts := {}
	for item_id in ShopCatalog.ids("item"):
		var rarity := ItemRegistry.get_rarity(item_id)
		counts[rarity] = int(counts.get(rarity, 0)) + 1
	assert_eq(counts[GameEnums.ItemRarity.COMMON], 13)
	assert_eq(counts[GameEnums.ItemRarity.UNCOMMON], 20)
	assert_eq(counts[GameEnums.ItemRarity.RARE], 12)
	assert_eq(counts[GameEnums.ItemRarity.EPIC], 9)
	assert_eq(counts[GameEnums.ItemRarity.LEGENDARY], 2)

func test_projectile_doctrine_also_benefits_explosive_projectiles_without_other_penalties() -> void:
	_own("ion_doctrine")
	for type_id in ["normal", "plasma", "shock", "tesla", "melee"]:
		assert_almost_eq(_stat(type_id, "damage"), _base(type_id, "damage") * (1.2 if type_id in ["normal", "plasma"] else 1.0), .001)

func test_each_family_doctrine_targets_only_that_family() -> void:
	var targets := {"plasma_doctrine": ["plasma", "shock"], "voltage_doctrine": ["shock", "tesla"], "bat_doctrine": ["melee"]}
	for item_id: String in targets:
		ModifierService.clear_modifiers()
		_own(item_id)
		for type_id in ["normal", "plasma", "shock", "tesla", "melee"]:
			var expected := 1.2 if type_id in targets[item_id] else 1.0
			assert_almost_eq(_stat(type_id, "damage"), _base(type_id, "damage") * expected, .001, "%s %s" % [item_id, type_id])

func test_specialists_change_the_right_stats() -> void:
	_own("superconductors")
	assert_eq(_stat("tesla", "chain_count"), _base("tesla", "chain_count") + 1.0)
	assert_eq(_stat("normal", "chain_count"), 0.0)
	assert_almost_eq(_stat("shock", "slow_intensity"), _base("shock", "slow_intensity") * 1.25, .001)
	assert_almost_eq(_stat("shock", "fire_rate"), _base("shock", "fire_rate"), .001)
	ModifierService.clear_modifiers()
	_own("static_grounding")
	assert_almost_eq(_stat("shock", "slow_intensity"), _base("shock", "slow_intensity") + .10, .001)
	assert_eq(_stat("tesla", "slow_intensity"), 0.0, "Tesla must not gain a slow")
	ModifierService.clear_modifiers()
	_own("piercing_rounds")
	assert_eq(_stat("normal", "pierce"), 1.0)
	assert_eq(_stat("plasma", "pierce"), 0.0)

func test_pool_flag_gates_the_new_items() -> void:
	assert_true(ShopCatalog.is_available("item", "ion_doctrine"))
	FeatureFlagService.set_enabled(FeatureFlagService.ITEMS_V2, false)
	assert_false(ShopCatalog.is_available("item", "ion_doctrine"))
	assert_true(ShopCatalog.is_available("item", "dense_rounds"))
	assert_false(ShopCatalog.is_available("item", "reactor_overload"), "Rares depend on items_v2")
	assert_eq(ShopCatalog.available_ids("item").size(), 26, "10 original + 3 convoy + 13 expansion items")
	FeatureFlagService.reset_state()
	FeatureFlagService.set_enabled(FeatureFlagService.ITEMS_V2_HOOKS, false)
	assert_true(ShopCatalog.is_available("item", "ion_doctrine"))
	assert_false(ShopCatalog.is_available("item", "reactor_overload"))
	assert_eq(ShopCatalog.available_ids("item").size(), 42)

func test_tall_items_use_entrench_and_carry_stats() -> void:
	_own("hardpoint")
	assert_eq(ModifierService.apply_modifiers_to_stat(5.0, "entrench_max_stacks"), 7.0)
	assert_almost_eq(ModifierService.apply_modifiers_to_stat(1.0, "carry_speed"), .9, .001)

func test_rare_stat_items() -> void:
	_own("arc_rod")
	assert_eq(_stat("tesla", "chain_count"), _base("tesla", "chain_count") + 2.0)
	assert_almost_eq(_stat("tesla", "chain_decay"), .85, .001)
	assert_almost_eq(_stat("tesla", "damage"), _base("tesla", "damage"), .001)
	assert_almost_eq(_stat("shock", "damage"), _base("shock", "damage"), .001)
	ModifierService.clear_modifiers()
	_own("overwatch_optics")
	assert_almost_eq(_stat("tesla", "range"), _base("tesla", "range") * 1.3, .001)
	assert_almost_eq(_stat("normal", "fire_rate"), _base("normal", "fire_rate"), .001)
	assert_almost_eq(_stat("plasma", "range"), _base("plasma", "range"), .001)
	ModifierService.clear_modifiers()
	_own("killzone_bat")
	assert_almost_eq(_stat("melee", "rehit_delay"), .25, .001)
	assert_almost_eq(_stat("melee", "knockback_force"), _base("melee", "knockback_force"), .001)

func test_whirlwind_frame_buffs_kinetic_without_other_penalties() -> void:
	_own("whirlwind_frame")
	assert_almost_eq(_stat("melee", "rotation_rate"), _base("melee", "rotation_rate") * 2.0, .001)
	assert_almost_eq(_stat("melee", "slow_intensity"), .25, .001)
	assert_almost_eq(_stat("melee", "damage"), _base("melee", "damage"), .001)
	for other in ["normal", "plasma", "shock", "tesla"]:
		assert_almost_eq(_stat(other, "damage"), _base(other, "damage"), .001, other)

func test_family_diversity_counts_families_not_damage_types() -> void:
	TurretStatsService.turret_counts = {"normal": 1, "melee": 2, "shock": 1, "tesla": 1}
	assert_eq(TurretStatsService.get_family_diversity(), 4)
	TurretStatsService.reset_state()

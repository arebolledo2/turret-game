extends GutTest

## Tests for the new turret type system
## Focus on data/configuration rather than full integration behavior

func before_each():
	TestHelpers.reset_all_services()
	GameStateService.reset_state()
	ModifierService.active_modifiers.clear()


# =============================================================================
# TURRET TYPE CONFIGURATION TESTS
# =============================================================================

func test_all_turret_types_exist():
	var expected_types = ["normal", "sniper", "fire", "plasma", "shock", "tesla"]
	for turret_type in expected_types:
		assert_true(TurretRegistry.TYPES.has(turret_type), "Missing turret type: " + turret_type)


func test_turret_types_have_required_fields():
	for turret_type in TurretRegistry.TYPES:
		var turret_def = TurretRegistry.get_type(turret_type)
		assert_true(turret_def.has("name"), turret_type + " missing name")
		assert_true(turret_def.has("attack_styles"), turret_type + " missing attack_styles")
		assert_true(turret_def.has("damage_types"), turret_type + " missing damage_types")
		assert_true(turret_def.has("base_stats"), turret_type + " missing base_stats")


func test_turret_types_have_colors():
	for turret_type in TurretRegistry.TYPES:
		assert_true(TurretRegistry.COLORS.has(turret_type), turret_type + " missing color")


func test_normal_turret_is_projectile_physical():
	var turret_def = TurretRegistry.get_type("normal")
	var styles = turret_def["attack_styles"]
	var types = turret_def["damage_types"]
	assert_true(GameEnums.AttackStyle.PROJECTILE in styles)
	assert_true(GameEnums.DamageType.PHYSICAL in types)


func test_sniper_turret_is_instant_physical():
	var turret_def = TurretRegistry.get_type("sniper")
	var styles = turret_def["attack_styles"]
	var types = turret_def["damage_types"]
	assert_true(GameEnums.AttackStyle.INSTANT in styles)
	assert_true(GameEnums.DamageType.PHYSICAL in types)


func test_fire_turret_has_dot_stats():
	var stats = TurretRegistry.get_base_stats("fire")
	assert_true(stats.has("dot_damage"), "Fire turret should have dot_damage")
	assert_true(stats.has("dot_duration"), "Fire turret should have dot_duration")
	assert_gt(stats["dot_damage"], 0.0, "Fire dot_damage should be positive")
	assert_gt(stats["dot_duration"], 0.0, "Fire dot_duration should be positive")


func test_fire_turret_has_high_pierce():
	var stats = TurretRegistry.get_base_stats("fire")
	assert_gte(stats.get("pierce", 0), 99, "Fire turret should have high pierce")


func test_tesla_turret_has_chain_stats():
	var stats = TurretRegistry.get_base_stats("tesla")
	assert_true(stats.has("chain_count"), "Tesla should have chain_count")
	assert_true(stats.has("chain_range"), "Tesla should have chain_range")
	assert_true(stats.has("chain_decay"), "Tesla should have chain_decay")


func test_plasma_turret_has_aoe_stats():
	var stats = TurretRegistry.get_base_stats("plasma")
	assert_true(stats.has("aoe_radius"), "Plasma should have aoe_radius")
	assert_gt(stats["aoe_radius"], 0.0, "AoE radius should be positive")


func test_shock_turret_is_aoe_electric():
	var turret_def = TurretRegistry.get_type("shock")
	var styles = turret_def["attack_styles"]
	var types = turret_def["damage_types"]
	assert_true(GameEnums.AttackStyle.AOE in styles)
	assert_true(GameEnums.DamageType.ELECTRIC in types)


# =============================================================================
# MODIFIER SYSTEM TESTS
# =============================================================================

func test_modifier_affects_matching_turret():
	ModifierService.add_modifier({
		"id": "test_fire_boost",
		"stat": "damage",
		"operation": "increase",
		"value": 0.5,
		"filter": {"damage_type": [GameEnums.DamageType.FIRE]}
	})

	var base_damage = TurretRegistry.get_base_stats("fire")["damage"]
	var fire_stats = TurretRegistry.get_base_stats("fire")
	fire_stats["damage"] = ModifierService.apply_modifiers_to_stat(base_damage * DifficultyService.get_difficulty_config()["turret_damage_mult"], "damage")
	var expected = base_damage * DifficultyService.get_difficulty_config()["turret_damage_mult"] * 1.5

	assert_almost_eq(fire_stats["damage"], expected, 0.01, "Fire damage should be boosted 50% via increase")


func test_modifier_does_not_affect_unmatched_turret():
	ModifierService.add_modifier({
		"id": "test_fire_boost",
		"stat": "damage",
		"operation": "increase",
		"value": 0.5,
		"filter": {"damage_type": [GameEnums.DamageType.FIRE]}
	})

	var normal_stats = ModifierService.get_turret_stats("normal", DifficultyService.get_difficulty_config())
	var base_damage = TurretRegistry.get_base_stats("normal")["damage"]
	var expected = base_damage * DifficultyService.get_difficulty_config()["turret_damage_mult"]

	assert_almost_eq(normal_stats["damage"], expected, 0.01, "Normal damage should NOT be boosted")


func test_add_modifier_for_chain():
	ModifierService.add_modifier({
		"id": "test_chain_boost",
		"stat": "chain_count",
		"operation": "add",
		"value": 2.0,
		"filter": {"attack_style": [GameEnums.AttackStyle.CHAIN]}
	})

	var base_chain: float = TurretRegistry.get_base_stats("tesla")["chain_count"]
	var tesla_stats = TurretRegistry.get_base_stats("tesla")
	tesla_stats["chain_count"] = ModifierService.apply_modifiers_to_stat(base_chain, "chain_count")

	assert_eq(tesla_stats["chain_count"], base_chain + 2.0, "Tesla chain count should be increased by 2")


func test_remove_modifier():
	ModifierService.add_modifier({
		"id": "temp_boost",
		"stat": "damage",
		"operation": "more",
		"value": 2.0,
		"filter": {}
	})

	var base_damage_before = TurretRegistry.get_base_stats("normal")["damage"]
	var before = ModifierService.apply_modifiers_to_stat(base_damage_before * DifficultyService.get_difficulty_config()["turret_damage_mult"], "damage")
	ModifierService.remove_modifier("temp_boost")
	var after = ModifierService.apply_modifiers_to_stat(base_damage_before * DifficultyService.get_difficulty_config()["turret_damage_mult"], "damage")

	assert_lt(after, before, "Damage should decrease after removing 'more' boost")


func test_clear_modifiers():
	ModifierService.add_modifier({"id": "m1", "stat": "damage", "operation": "add", "value": 10, "filter": {}})
	ModifierService.add_modifier({"id": "m2", "stat": "range", "operation": "add", "value": 50, "filter": {}})
	
	ModifierService.clear_modifiers()
	
	assert_eq(ModifierService.active_modifiers.size(), 0, "All modifiers should be cleared")


# =============================================================================
# HELPER FUNCTION TESTS
# =============================================================================

func test_turret_has_attack_style():
	assert_true(GameEnums.AttackStyle.CHAIN in TurretRegistry.TYPES["tesla"]["attack_styles"])
	assert_false(GameEnums.AttackStyle.CHAIN in TurretRegistry.TYPES["normal"]["attack_styles"])


func test_turret_has_damage_type():
	assert_true(GameEnums.DamageType.FIRE in TurretRegistry.TYPES["fire"]["damage_types"])
	assert_false(GameEnums.DamageType.FIRE in TurretRegistry.TYPES["normal"]["damage_types"])


func test_get_turret_color():
	var color = TurretRegistry.get_color("fire")
	assert_eq(color, Color("FF6633"), "Fire turret should be orange")

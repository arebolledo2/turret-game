extends GutTest

# =============================================================================
# Unit tests for ModifierSystem
# Tests modifier filtering, stat application, and edge cases
# Uses Path of Exile-style modifier operations:
#   - "add": Flat value added to base
#   - "increase": Percentage modifier (stacks additively)
#   - "more": Multiplicative modifier (each stacks independently)
# Formula: (base + flat) Ã— (1 + increases) Ã— more1 Ã— more2 Ã— ...
# =============================================================================

var modifier_system: ModifierSystem


func before_each() -> void:
	TestHelpers.reset_all_services()
	modifier_system = ModifierSystem.new()


# =============================================================================
# BASIC MODIFIER OPERATIONS
# =============================================================================

func test_add_modifier_returns_modifier():
	var modifier = {"id": "test_1", "stat": "damage", "operation": "add", "value": 5.0}
	var result = modifier_system.add_modifier(modifier)
	assert_eq(result, modifier, "add_modifier should return the added modifier")


func test_get_all_modifiers_returns_empty_initially():
	var mods = modifier_system.get_all_modifiers()
	assert_eq(mods.size(), 0, "Should start with no modifiers")


func test_get_all_modifiers_returns_added_modifiers():
	modifier_system.add_modifier({"id": "test_1", "stat": "damage", "operation": "add", "value": 5.0})
	modifier_system.add_modifier({"id": "test_2", "stat": "fire_rate", "operation": "increase", "value": 0.5})

	var mods = modifier_system.get_all_modifiers()
	assert_eq(mods.size(), 2, "Should have 2 modifiers")


func test_remove_modifier_by_id():
	modifier_system.add_modifier({"id": "test_1", "stat": "damage", "operation": "add", "value": 5.0})
	modifier_system.add_modifier({"id": "test_2", "stat": "fire_rate", "operation": "increase", "value": 0.5})

	var result = modifier_system.remove_modifier("test_1")

	assert_true(result, "remove_modifier should return true on success")
	assert_eq(modifier_system.get_all_modifiers().size(), 1, "Should have 1 modifier left")


func test_remove_nonexistent_modifier_returns_false():
	var result = modifier_system.remove_modifier("does_not_exist")
	assert_false(result, "remove_modifier should return false for non-existent ID")


func test_clear_modifiers():
	modifier_system.add_modifier({"id": "test_1", "stat": "damage", "operation": "add", "value": 5.0})
	modifier_system.add_modifier({"id": "test_2", "stat": "fire_rate", "operation": "increase", "value": 0.5})

	modifier_system.clear_modifiers()

	assert_eq(modifier_system.get_all_modifiers().size(), 0, "Should have no modifiers after clear")


# =============================================================================
# FILTER MATCHING - EMPTY FILTER
# =============================================================================

func test_empty_filter_matches_all_turrets():
	# Modifier with empty filter should match all turret types
	modifier_system.add_modifier({
		"id": "universal",
		"stat": "damage",
		"operation": "add",
		"value": 10.0,
		"filter": {}
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]

	# All turret types should get the +10 damage bonus
	for turret_type in TurretRegistry.get_all_type_ids():
		var stats = modifier_system.get_turret_stats(turret_type, easy_config)
		var base_stats = TurretRegistry.get_base_stats(turret_type)
		assert_eq(stats["damage"], base_stats["damage"] + 10.0,
			"Empty filter should apply to " + turret_type)


func test_no_filter_key_matches_all_turrets():
	# Modifier without filter key at all should match all turret types
	modifier_system.add_modifier({
		"id": "universal",
		"stat": "damage",
		"operation": "add",
		"value": 10.0
		# No filter key
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]

	for turret_type in TurretRegistry.get_all_type_ids():
		var stats = modifier_system.get_turret_stats(turret_type, easy_config)
		var base_stats = TurretRegistry.get_base_stats(turret_type)
		assert_eq(stats["damage"], base_stats["damage"] + 10.0,
			"No filter should apply to " + turret_type)


# =============================================================================
# FILTER MATCHING - TURRET TYPE
# =============================================================================

func test_turret_type_filter_matches_specific_turret():
	modifier_system.add_modifier({
		"id": "fire_boost",
		"stat": "damage",
		"operation": "add",
		"value": 20.0,
		"filter": {"turret_type": ["fire"]}
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]

	var fire_stats = modifier_system.get_turret_stats("fire", easy_config)
	var fire_base = TurretRegistry.get_base_stats("fire")
	assert_eq(fire_stats["damage"], fire_base["damage"] + 20.0,
		"Fire turret should get the damage boost")

	var normal_stats = modifier_system.get_turret_stats("normal", easy_config)
	var normal_base = TurretRegistry.get_base_stats("normal")
	assert_eq(normal_stats["damage"], normal_base["damage"],
		"Normal turret should NOT get the damage boost")


func test_turret_type_filter_or_logic():
	# Filter with multiple turret types should match any of them (OR logic)
	modifier_system.add_modifier({
		"id": "electric_boost",
		"stat": "damage",
		"operation": "add",
		"value": 15.0,
		"filter": {"turret_type": ["shock", "tesla"]}
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]

	var shock_stats = modifier_system.get_turret_stats("shock", easy_config)
	var shock_base = TurretRegistry.get_base_stats("shock")
	assert_eq(shock_stats["damage"], shock_base["damage"] + 15.0,
		"Shock turret should get the boost")

	var tesla_stats = modifier_system.get_turret_stats("tesla", easy_config)
	var tesla_base = TurretRegistry.get_base_stats("tesla")
	assert_eq(tesla_stats["damage"], tesla_base["damage"] + 15.0,
		"Tesla turret should get the boost")

	var normal_stats = modifier_system.get_turret_stats("normal", easy_config)
	var normal_base = TurretRegistry.get_base_stats("normal")
	assert_eq(normal_stats["damage"], normal_base["damage"],
		"Normal turret should NOT get the boost")


# =============================================================================
# FILTER MATCHING - DAMAGE TYPE
# =============================================================================

func test_damage_type_filter_matches_turrets():
	# Filter for ELECTRIC damage type should match shock and tesla
	modifier_system.add_modifier({
		"id": "electric_boost",
		"stat": "damage",
		"operation": "increase",
		"value": 0.5,  # +50% increase
		"filter": {"damage_type": [GameEnums.DamageType.ELECTRIC]}
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]

	# Shock and Tesla have ELECTRIC damage type
	var shock_stats = modifier_system.get_turret_stats("shock", easy_config)
	var shock_base = TurretRegistry.get_base_stats("shock")
	assert_eq(shock_stats["damage"], shock_base["damage"] * 1.5,
		"Shock turret should get 1.5x damage (1 + 0.5 increase)")

	var tesla_stats = modifier_system.get_turret_stats("tesla", easy_config)
	var tesla_base = TurretRegistry.get_base_stats("tesla")
	assert_eq(tesla_stats["damage"], tesla_base["damage"] * 1.5,
		"Tesla turret should get 1.5x damage (1 + 0.5 increase)")

	# Normal has PHYSICAL damage type
	var normal_stats = modifier_system.get_turret_stats("normal", easy_config)
	var normal_base = TurretRegistry.get_base_stats("normal")
	assert_eq(normal_stats["damage"], normal_base["damage"],
		"Normal turret should NOT get the boost")


func test_damage_type_filter_or_logic():
	# Multiple damage types should use OR logic
	modifier_system.add_modifier({
		"id": "elemental_boost",
		"stat": "damage",
		"operation": "add",
		"value": 10.0,
		"filter": {"damage_type": [GameEnums.DamageType.FIRE, GameEnums.DamageType.ELECTRIC]}
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]

	# Fire turret has FIRE damage
	var fire_stats = modifier_system.get_turret_stats("fire", easy_config)
	var fire_base = TurretRegistry.get_base_stats("fire")
	assert_eq(fire_stats["damage"], fire_base["damage"] + 10.0, "Fire should match")

	# Shock turret has ELECTRIC damage
	var shock_stats = modifier_system.get_turret_stats("shock", easy_config)
	var shock_base = TurretRegistry.get_base_stats("shock")
	assert_eq(shock_stats["damage"], shock_base["damage"] + 10.0, "Shock should match")


# =============================================================================
# FILTER MATCHING - ATTACK STYLE
# =============================================================================

func test_attack_style_filter_matches_turrets():
	# Filter for AOE attack style
	modifier_system.add_modifier({
		"id": "aoe_boost",
		"stat": "damage",
		"operation": "add",
		"value": 25.0,
		"filter": {"attack_style": [GameEnums.AttackStyle.AOE]}
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]

	# Shock and Plasma have AOE attack style
	var shock_stats = modifier_system.get_turret_stats("shock", easy_config)
	var shock_base = TurretRegistry.get_base_stats("shock")
	assert_eq(shock_stats["damage"], shock_base["damage"] + 25.0,
		"Shock turret should get AOE boost")

	var plasma_stats = modifier_system.get_turret_stats("plasma", easy_config)
	var plasma_base = TurretRegistry.get_base_stats("plasma")
	assert_eq(plasma_stats["damage"], plasma_base["damage"] + 25.0,
		"Plasma turret should get AOE boost")

	# Normal has PROJECTILE, not AOE
	var normal_stats = modifier_system.get_turret_stats("normal", easy_config)
	var normal_base = TurretRegistry.get_base_stats("normal")
	assert_eq(normal_stats["damage"], normal_base["damage"],
		"Normal turret should NOT get AOE boost")


func test_attack_style_instant_filter():
	# Filter for INSTANT attack style (sniper, tesla)
	modifier_system.add_modifier({
		"id": "instant_boost",
		"stat": "damage",
		"operation": "increase",
		"value": 1.0,  # +100% increase
		"filter": {"attack_style": [GameEnums.AttackStyle.INSTANT]}
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]

	var sniper_stats = modifier_system.get_turret_stats("sniper", easy_config)
	var sniper_base = TurretRegistry.get_base_stats("sniper")
	assert_eq(sniper_stats["damage"], sniper_base["damage"] * 2.0,
		"Sniper turret should get 2x damage (1 + 1.0 increase)")

	var tesla_stats = modifier_system.get_turret_stats("tesla", easy_config)
	var tesla_base = TurretRegistry.get_base_stats("tesla")
	assert_eq(tesla_stats["damage"], tesla_base["damage"] * 2.0,
		"Tesla turret should get 2x damage (1 + 1.0 increase)")


# =============================================================================
# STAT APPLICATION - ADD OPERATIONS
# =============================================================================

func test_add_operation_adds_to_stat():
	modifier_system.add_modifier({
		"id": "damage_add",
		"stat": "damage",
		"operation": "add",
		"value": 10.0
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	assert_eq(stats["damage"], base_stats["damage"] + 10.0, "Damage should increase by 10")


func test_multiple_add_operations_stack():
	modifier_system.add_modifier({
		"id": "damage_add_1",
		"stat": "damage",
		"operation": "add",
		"value": 5.0
	})
	modifier_system.add_modifier({
		"id": "damage_add_2",
		"stat": "damage",
		"operation": "add",
		"value": 7.0
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	assert_eq(stats["damage"], base_stats["damage"] + 12.0, "Add modifiers should stack: +5 +7 = +12")


# =============================================================================
# STAT APPLICATION - INCREASE OPERATIONS (Additive %)
# =============================================================================

func test_increase_operation_applies_percentage():
	modifier_system.add_modifier({
		"id": "damage_inc",
		"stat": "damage",
		"operation": "increase",
		"value": 0.5  # +50% increase
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	# base * (1 + 0.5) = base * 1.5
	assert_eq(stats["damage"], base_stats["damage"] * 1.5, "Damage should be increased by 50%")


func test_multiple_increase_operations_stack_additively():
	# PoE-style: multiple increases SUM before multiplying
	modifier_system.add_modifier({
		"id": "damage_inc_1",
		"stat": "damage",
		"operation": "increase",
		"value": 0.5  # +50%
	})
	modifier_system.add_modifier({
		"id": "damage_inc_2",
		"stat": "damage",
		"operation": "increase",
		"value": 0.5  # +50%
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	# Two +50% increases = +100% total = base * (1 + 0.5 + 0.5) = base * 2.0
	# NOT base * 1.5 * 1.5 = base * 2.25 (that would be multiplicative)
	assert_eq(stats["damage"], base_stats["damage"] * 2.0,
		"Increase modifiers should stack additively: 50% + 50% = 100% = 2.0x")


# =============================================================================
# STAT APPLICATION - MORE OPERATIONS (Multiplicative %)
# =============================================================================

func test_more_operation_multiplies_stat():
	modifier_system.add_modifier({
		"id": "damage_more",
		"stat": "damage",
		"operation": "more",
		"value": 1.5  # 50% more
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	assert_eq(stats["damage"], base_stats["damage"] * 1.5, "Damage should be 50% more")


func test_multiply_operation_alias_multiplies_turret_stat():
	modifier_system.add_modifier({
		"id": "damage_multiply",
		"stat": "damage",
		"operation": "multiply",
		"value": 1.15
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	assert_eq(stats["damage"], base_stats["damage"] * 1.15,
		"Multiply should behave as an independent multiplier for turret stats")


func test_multiple_more_operations_stack_multiplicatively():
	# PoE-style: "more" modifiers multiply independently
	modifier_system.add_modifier({
		"id": "damage_more_1",
		"stat": "damage",
		"operation": "more",
		"value": 1.5  # 50% more
	})
	modifier_system.add_modifier({
		"id": "damage_more_2",
		"stat": "damage",
		"operation": "more",
		"value": 1.5  # 50% more
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	# Two 50% more = base * 1.5 * 1.5 = base * 2.25
	assert_eq(stats["damage"], base_stats["damage"] * 2.25,
		"More modifiers should stack multiplicatively: 1.5 * 1.5 = 2.25x")


# =============================================================================
# STAT APPLICATION - POE FORMULA ORDER
# Formula: (base + flat) Ã— (1 + increases) Ã— more1 Ã— more2 Ã— ...
# =============================================================================

func test_poe_formula_flat_then_increase():
	# Add flat +10, then 50% increase
	modifier_system.add_modifier({
		"id": "damage_add",
		"stat": "damage",
		"operation": "add",
		"value": 10.0
	})
	modifier_system.add_modifier({
		"id": "damage_inc",
		"stat": "damage",
		"operation": "increase",
		"value": 0.5  # +50%
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	# (base + 10) * (1 + 0.5) = (base + 10) * 1.5
	var expected = (base_stats["damage"] + 10.0) * 1.5
	assert_eq(stats["damage"], expected, "Flat should apply before increase")


func test_poe_formula_increase_then_more():
	# +50% increase and 50% more
	modifier_system.add_modifier({
		"id": "damage_inc",
		"stat": "damage",
		"operation": "increase",
		"value": 0.5
	})
	modifier_system.add_modifier({
		"id": "damage_more",
		"stat": "damage",
		"operation": "more",
		"value": 1.5
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	# base * (1 + 0.5) * 1.5 = base * 1.5 * 1.5 = base * 2.25
	var expected = base_stats["damage"] * 1.5 * 1.5
	assert_eq(stats["damage"], expected, "Increase should apply before more")


func test_poe_formula_full_calculation():
	# Full PoE formula test: flat, increases, and more
	modifier_system.add_modifier({
		"id": "damage_add",
		"stat": "damage",
		"operation": "add",
		"value": 10.0
	})
	modifier_system.add_modifier({
		"id": "damage_inc_1",
		"stat": "damage",
		"operation": "increase",
		"value": 0.5  # +50%
	})
	modifier_system.add_modifier({
		"id": "damage_inc_2",
		"stat": "damage",
		"operation": "increase",
		"value": 0.3  # +30%
	})
	modifier_system.add_modifier({
		"id": "damage_more_1",
		"stat": "damage",
		"operation": "more",
		"value": 1.2  # 20% more
	})
	modifier_system.add_modifier({
		"id": "damage_more_2",
		"stat": "damage",
		"operation": "more",
		"value": 1.3  # 30% more
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	# (base + 10) * (1 + 0.5 + 0.3) * 1.2 * 1.3
	# = (base + 10) * 1.8 * 1.2 * 1.3
	# = (base + 10) * 1.8 * 1.56
	# = (base + 10) * 2.808
	var expected = (base_stats["damage"] + 10.0) * (1.0 + 0.5 + 0.3) * 1.2 * 1.3
	assert_almost_eq(stats["damage"], expected, 0.001, "Full PoE formula should apply correctly")


func test_order_is_flat_increase_more_regardless_of_insertion_order():
	# Add in reverse order - should still apply in correct order
	modifier_system.add_modifier({
		"id": "damage_more",
		"stat": "damage",
		"operation": "more",
		"value": 1.5
	})
	modifier_system.add_modifier({
		"id": "damage_inc",
		"stat": "damage",
		"operation": "increase",
		"value": 0.5
	})
	modifier_system.add_modifier({
		"id": "damage_add",
		"stat": "damage",
		"operation": "add",
		"value": 10.0
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	# (base + 10) * (1 + 0.5) * 1.5 - order of insertion doesn't matter
	var expected = (base_stats["damage"] + 10.0) * 1.5 * 1.5
	assert_eq(stats["damage"], expected, "Formula order should be maintained regardless of insertion")


# =============================================================================
# DIFFICULTY INTEGRATION
# =============================================================================

func test_difficulty_modifier_applied_to_damage():
	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var hard_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.HARD]

	var easy_stats = modifier_system.get_turret_stats("normal", easy_config)
	var hard_stats = modifier_system.get_turret_stats("normal", hard_config)

	# Hard mode has turret_damage_mult of 0.9
	assert_lt(hard_stats["damage"], easy_stats["damage"],
		"Hard mode should have lower turret damage")


func test_modifiers_stack_with_difficulty():
	modifier_system.add_modifier({
		"id": "damage_boost",
		"stat": "damage",
		"operation": "add",
		"value": 10.0
	})

	var hard_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.HARD]
	var stats = modifier_system.get_turret_stats("normal", hard_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	# Hard: base * 0.9 (difficulty) + 10 (modifier)
	var expected = base_stats["damage"] * hard_config["turret_damage_mult"] + 10.0
	assert_eq(stats["damage"], expected, "Modifiers should apply on top of difficulty")


# =============================================================================
# APPLY TO STAT (PLAYER STATS)
# =============================================================================

func test_apply_to_stat_with_no_modifiers():
	var result = modifier_system.apply_to_stat(100.0, "player_speed")
	assert_eq(result, 100.0, "With no modifiers, base value should be unchanged")


func test_apply_to_stat_with_add():
	modifier_system.add_modifier({
		"id": "speed_add",
		"stat": "player_speed",
		"operation": "add",
		"value": 20.0
	})

	var result = modifier_system.apply_to_stat(100.0, "player_speed")
	assert_eq(result, 120.0, "Should add 20 to base speed")


func test_apply_to_stat_with_increase():
	modifier_system.add_modifier({
		"id": "speed_inc",
		"stat": "player_speed",
		"operation": "increase",
		"value": 0.5  # +50%
	})

	var result = modifier_system.apply_to_stat(100.0, "player_speed")
	assert_eq(result, 150.0, "Should increase base by 50%")


func test_apply_to_stat_with_more():
	modifier_system.add_modifier({
		"id": "speed_more",
		"stat": "player_speed",
		"operation": "more",
		"value": 1.5  # 50% more
	})

	var result = modifier_system.apply_to_stat(100.0, "player_speed")
	assert_eq(result, 150.0, "Should multiply base by 1.5 (50% more)")


func test_apply_to_stat_with_multiply_alias():
	modifier_system.add_modifier({
		"id": "speed_multiply",
		"stat": "player_speed",
		"operation": "multiply",
		"value": 1.25
	})

	var result = modifier_system.apply_to_stat(100.0, "player_speed")
	assert_eq(result, 125.0, "Multiply should behave as an independent multiplier for player stats")


func test_apply_to_stat_ignores_other_stats():
	modifier_system.add_modifier({
		"id": "health_add",
		"stat": "player_max_health",
		"operation": "add",
		"value": 50.0
	})

	var result = modifier_system.apply_to_stat(100.0, "player_speed")
	assert_eq(result, 100.0, "Modifier for different stat should be ignored")


# =============================================================================
# PLAYER STAT HELPERS
# =============================================================================

func test_get_player_speed():
	modifier_system.add_modifier({
		"id": "scrap_magnet",
		"stat": "player_speed",
		"operation": "increase",
		"value": 0.1  # +10%
	})

	var result = modifier_system.get_player_speed(200.0)
	assert_almost_eq(result, 220.0, 0.01, "Player speed should be 200 * 1.1 = 220")


func test_get_player_max_health():
	modifier_system.add_modifier({
		"id": "vitality",
		"stat": "player_max_health",
		"operation": "add",
		"value": 25.0
	})

	var result = modifier_system.get_player_max_health(100.0)
	assert_eq(result, 125.0, "Player max health should be 100 + 25 = 125")


func test_get_player_weapon_damage():
	modifier_system.add_modifier({
		"id": "damage_amp",
		"stat": "player_weapon_damage",
		"operation": "increase",
		"value": 1.0  # +100%
	})

	var result = modifier_system.get_player_weapon_damage(10.0)
	assert_eq(result, 20.0, "Player weapon damage should be 10 * 2 = 20")


# =============================================================================
# FILTER VALIDATION (ENTITY_TYPE)
# =============================================================================

func test_apply_to_stat_respects_entity_type_filter():
	modifier_system.clear_modifiers()

	# Add player-specific modifier
	var player_mod = {
		"id": "player_health_boost",
		"stat": "max_health",
		"operation": "increase",
		"value": 0.5,  # +50%
		"filter": {"entity_type": ["player"]}
	}
	modifier_system.add_modifier(player_mod)

	# Should apply to player entity type
	var result_player = modifier_system.apply_to_stat(100.0, "max_health", "player")
	assert_eq(result_player, 150.0, "Should apply player modifier to player entity")

	# Should NOT apply to turret entity type
	var result_turret = modifier_system.apply_to_stat(100.0, "max_health", "turret")
	assert_eq(result_turret, 100.0, "Should not apply player modifier to turret entity")


func test_apply_to_stat_allows_empty_filter():
	modifier_system.clear_modifiers()

	# Add modifier with no filter (applies to all)
	var universal_mod = {
		"id": "universal_boost",
		"stat": "damage",
		"operation": "add",
		"value": 10.0,
		"filter": {}
	}
	modifier_system.add_modifier(universal_mod)

	# Should apply to both player and turret
	var result_player = modifier_system.apply_to_stat(50.0, "damage", "player")
	var result_turret = modifier_system.apply_to_stat(50.0, "damage", "turret")
	assert_eq(result_player, 60.0, "Should apply universal modifier to player")
	assert_eq(result_turret, 60.0, "Should apply universal modifier to turret")


func test_apply_to_stat_handles_multiple_entity_types_in_filter():
	modifier_system.clear_modifiers()

	# Add modifier that applies to both player and enemy
	var multi_mod = {
		"id": "speed_boost",
		"stat": "speed",
		"operation": "increase",
		"value": 0.2,  # +20%
		"filter": {"entity_type": ["player", "enemy"]}
	}
	modifier_system.add_modifier(multi_mod)

	# Should apply to player
	var result_player = modifier_system.apply_to_stat(100.0, "speed", "player")
	assert_eq(result_player, 120.0, "Should apply to player in multi-entity filter")

	# Should apply to enemy
	var result_enemy = modifier_system.apply_to_stat(100.0, "speed", "enemy")
	assert_eq(result_enemy, 120.0, "Should apply to enemy in multi-entity filter")

	# Should NOT apply to turret
	var result_turret = modifier_system.apply_to_stat(100.0, "speed", "turret")
	assert_eq(result_turret, 100.0, "Should not apply to turret not in filter")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_modifier_with_zero_add():
	modifier_system.add_modifier({
		"id": "zero_add",
		"stat": "damage",
		"operation": "add",
		"value": 0.0
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	assert_eq(stats["damage"], base_stats["damage"], "Zero add should not change stat")


func test_modifier_with_zero_increase():
	modifier_system.add_modifier({
		"id": "zero_inc",
		"stat": "damage",
		"operation": "increase",
		"value": 0.0  # 0% increase
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	assert_eq(stats["damage"], base_stats["damage"], "0% increase should not change stat")


func test_modifier_with_one_more():
	modifier_system.add_modifier({
		"id": "one_more",
		"stat": "damage",
		"operation": "more",
		"value": 1.0  # 1x (no change)
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	assert_eq(stats["damage"], base_stats["damage"], "1x more should not change stat")


func test_negative_add_reduces_stat():
	modifier_system.add_modifier({
		"id": "damage_penalty",
		"stat": "damage",
		"operation": "add",
		"value": -5.0
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	assert_eq(stats["damage"], base_stats["damage"] - 5.0, "Negative add should reduce stat")


func test_negative_increase_reduces_stat():
	modifier_system.add_modifier({
		"id": "damage_reduction",
		"stat": "damage",
		"operation": "increase",
		"value": -0.5  # -50%
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	assert_eq(stats["damage"], base_stats["damage"] * 0.5, "-50% increase should halve stat")


func test_less_modifier_reduces_stat():
	modifier_system.add_modifier({
		"id": "damage_less",
		"stat": "damage",
		"operation": "more",
		"value": 0.5  # 50% less (0.5x multiplier)
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	assert_eq(stats["damage"], base_stats["damage"] * 0.5, "0.5x more (50% less) should halve stat")


func test_modifier_for_nonexistent_stat():
	modifier_system.add_modifier({
		"id": "fake_stat",
		"stat": "nonexistent_stat",
		"operation": "add",
		"value": 100.0
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	# Should not crash, just not affect any real stats
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	assert_not_null(stats, "Should handle non-existent stat gracefully")

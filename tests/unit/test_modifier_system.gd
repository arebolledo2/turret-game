extends GutTest

# =============================================================================
# Unit tests for ModifierSystem
# Tests modifier filtering, stat application, and edge cases
# =============================================================================

var modifier_system: ModifierSystem


func before_each() -> void:
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
	modifier_system.add_modifier({"id": "test_2", "stat": "fire_rate", "operation": "multiply", "value": 1.5})

	var mods = modifier_system.get_all_modifiers()
	assert_eq(mods.size(), 2, "Should have 2 modifiers")


func test_remove_modifier_by_id():
	modifier_system.add_modifier({"id": "test_1", "stat": "damage", "operation": "add", "value": 5.0})
	modifier_system.add_modifier({"id": "test_2", "stat": "fire_rate", "operation": "multiply", "value": 1.5})

	var result = modifier_system.remove_modifier("test_1")

	assert_true(result, "remove_modifier should return true on success")
	assert_eq(modifier_system.get_all_modifiers().size(), 1, "Should have 1 modifier left")


func test_remove_nonexistent_modifier_returns_false():
	var result = modifier_system.remove_modifier("does_not_exist")
	assert_false(result, "remove_modifier should return false for non-existent ID")


func test_clear_modifiers():
	modifier_system.add_modifier({"id": "test_1", "stat": "damage", "operation": "add", "value": 5.0})
	modifier_system.add_modifier({"id": "test_2", "stat": "fire_rate", "operation": "multiply", "value": 1.5})

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
		"operation": "multiply",
		"value": 1.5,
		"filter": {"damage_type": [GameEnums.DamageType.ELECTRIC]}
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]

	# Shock and Tesla have ELECTRIC damage type
	var shock_stats = modifier_system.get_turret_stats("shock", easy_config)
	var shock_base = TurretRegistry.get_base_stats("shock")
	assert_eq(shock_stats["damage"], shock_base["damage"] * 1.5,
		"Shock turret should get 1.5x damage")

	var tesla_stats = modifier_system.get_turret_stats("tesla", easy_config)
	var tesla_base = TurretRegistry.get_base_stats("tesla")
	assert_eq(tesla_stats["damage"], tesla_base["damage"] * 1.5,
		"Tesla turret should get 1.5x damage")

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
		"operation": "multiply",
		"value": 2.0,
		"filter": {"attack_style": [GameEnums.AttackStyle.INSTANT]}
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]

	var sniper_stats = modifier_system.get_turret_stats("sniper", easy_config)
	var sniper_base = TurretRegistry.get_base_stats("sniper")
	assert_eq(sniper_stats["damage"], sniper_base["damage"] * 2.0,
		"Sniper turret should get 2x damage")

	var tesla_stats = modifier_system.get_turret_stats("tesla", easy_config)
	var tesla_base = TurretRegistry.get_base_stats("tesla")
	assert_eq(tesla_stats["damage"], tesla_base["damage"] * 2.0,
		"Tesla turret should get 2x damage")


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
# STAT APPLICATION - MULTIPLY OPERATIONS
# =============================================================================

func test_multiply_operation_multiplies_stat():
	modifier_system.add_modifier({
		"id": "damage_mult",
		"stat": "damage",
		"operation": "multiply",
		"value": 1.5
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	assert_eq(stats["damage"], base_stats["damage"] * 1.5, "Damage should be multiplied by 1.5")


func test_multiple_multiply_operations_stack_multiplicatively():
	modifier_system.add_modifier({
		"id": "damage_mult_1",
		"stat": "damage",
		"operation": "multiply",
		"value": 1.5
	})
	modifier_system.add_modifier({
		"id": "damage_mult_2",
		"stat": "damage",
		"operation": "multiply",
		"value": 2.0
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	# Multipliers stack: base * 1.5 * 2.0 = base * 3.0
	assert_eq(stats["damage"], base_stats["damage"] * 3.0,
		"Multiply modifiers should stack: 1.5 * 2.0 = 3.0x")


# =============================================================================
# STAT APPLICATION - ADD THEN MULTIPLY ORDER
# =============================================================================

func test_add_applied_before_multiply():
	# First add +10, then multiply by 2
	modifier_system.add_modifier({
		"id": "damage_add",
		"stat": "damage",
		"operation": "add",
		"value": 10.0
	})
	modifier_system.add_modifier({
		"id": "damage_mult",
		"stat": "damage",
		"operation": "multiply",
		"value": 2.0
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	# (base + 10) * 2
	var expected = (base_stats["damage"] + 10.0) * 2.0
	assert_eq(stats["damage"], expected, "Add should apply before multiply")


func test_order_is_add_first_regardless_of_insertion_order():
	# Add multiply first, then add - should still apply add before multiply
	modifier_system.add_modifier({
		"id": "damage_mult",
		"stat": "damage",
		"operation": "multiply",
		"value": 2.0
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

	# (base + 10) * 2 - order of insertion doesn't matter
	var expected = (base_stats["damage"] + 10.0) * 2.0
	assert_eq(stats["damage"], expected, "Add should still apply before multiply")


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


func test_apply_to_stat_with_multiply():
	modifier_system.add_modifier({
		"id": "speed_mult",
		"stat": "player_speed",
		"operation": "multiply",
		"value": 1.5
	})

	var result = modifier_system.apply_to_stat(100.0, "player_speed")
	assert_eq(result, 150.0, "Should multiply base by 1.5")


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
		"id": "swift_boots",
		"stat": "player_speed",
		"operation": "multiply",
		"value": 1.1
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
		"operation": "multiply",
		"value": 2.0
	})

	var result = modifier_system.get_player_weapon_damage(10.0)
	assert_eq(result, 20.0, "Player weapon damage should be 10 * 2 = 20")


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


func test_modifier_with_one_multiply():
	modifier_system.add_modifier({
		"id": "one_mult",
		"stat": "damage",
		"operation": "multiply",
		"value": 1.0
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	assert_eq(stats["damage"], base_stats["damage"], "Multiply by 1 should not change stat")


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


func test_fractional_multiply_reduces_stat():
	modifier_system.add_modifier({
		"id": "damage_reduction",
		"stat": "damage",
		"operation": "multiply",
		"value": 0.5
	})

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)
	var base_stats = TurretRegistry.get_base_stats("normal")

	assert_eq(stats["damage"], base_stats["damage"] * 0.5, "Multiply by 0.5 should halve stat")


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

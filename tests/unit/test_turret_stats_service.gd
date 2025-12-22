extends GutTest

# =============================================================================
# Unit tests for TurretStatsService
# Tests turret counts, diversity metrics, stat calculations, and modifier filtering
# =============================================================================

var turret_stats_service: Node
var modifier_service: Node

func before_all() -> void:
	turret_stats_service = get_node("/root/TurretStatsService")
	modifier_service = get_node("/root/ModifierService")

func before_each() -> void:
	turret_stats_service.reset_state()
	modifier_service.clear_modifiers()


# =============================================================================
# RESET STATE
# =============================================================================

func test_reset_state_clears_turret_counts():
	turret_stats_service.turret_counts = {"fire": 3, "sniper": 2}
	turret_stats_service.reset_state()
	assert_eq(turret_stats_service.turret_counts.size(), 0,
		"Reset should clear turret counts")


func test_reset_state_clears_selected_turret():
	turret_stats_service.selected_turret_type = "plasma"
	turret_stats_service.reset_state()
	assert_eq(turret_stats_service.selected_turret_type, "",
		"Reset should clear selected turret")


# =============================================================================
# TURRET STATS CALCULATION
# =============================================================================

func test_get_turret_stats_returns_base_stats():
	var stats = turret_stats_service.get_turret_stats("normal", 1.0)
	var base_stats = TurretRegistry.get_base_stats("normal")
	assert_eq(stats["damage"], base_stats["damage"],
		"Should return base damage")
	assert_eq(stats["fire_rate"], base_stats["fire_rate"],
		"Should return base fire rate")
	assert_eq(stats["range"], base_stats["range"],
		"Should return base range")


func test_get_turret_stats_applies_difficulty_to_damage():
	var stats = turret_stats_service.get_turret_stats("fire", 1.5)
	var base_stats = TurretRegistry.get_base_stats("fire")
	assert_eq(stats["damage"], base_stats["damage"] * 1.5,
		"Should apply difficulty mult to damage")


func test_get_turret_stats_invalid_type_returns_empty():
	var stats = turret_stats_service.get_turret_stats("invalid_type", 1.0)
	assert_true(stats.is_empty(),
		"Invalid turret type should return empty dict")


func test_get_turret_stats_with_additive_modifier():
	modifier_service.add_modifier({
		"stat": "damage",
		"operation": "add",
		"value": 10.0,
		"filter": {},
		"source": "test_item"
	})
	var base_stats = TurretRegistry.get_base_stats("normal")
	var stats = turret_stats_service.get_turret_stats("normal", 1.0)
	assert_eq(stats["damage"], base_stats["damage"] + 10.0,
		"Should apply additive modifier")


func test_get_turret_stats_with_multiplicative_modifier():
	modifier_service.add_modifier({
		"stat": "fire_rate",
		"operation": "multiply",
		"value": 1.5,
		"filter": {},
		"source": "test_item"
	})
	var base_stats = TurretRegistry.get_base_stats("sniper")
	var stats = turret_stats_service.get_turret_stats("sniper", 1.0)
	assert_eq(stats["fire_rate"], base_stats["fire_rate"] * 1.5,
		"Should apply multiplicative modifier")


func test_get_turret_stats_adds_before_multiplies():
	modifier_service.add_modifier({
		"stat": "damage",
		"operation": "add",
		"value": 5.0,
		"filter": {},
		"source": "item1"
	})
	modifier_service.add_modifier({
		"stat": "damage",
		"operation": "multiply",
		"value": 2.0,
		"filter": {},
		"source": "item2"
	})
	var base_stats = TurretRegistry.get_base_stats("normal")
	var expected = (base_stats["damage"] + 5.0) * 2.0
	var stats = turret_stats_service.get_turret_stats("normal", 1.0)
	assert_eq(stats["damage"], expected,
		"Should apply adds before multipliers")


func test_get_turret_stats_multiple_multipliers_stack():
	modifier_service.add_modifier({
		"stat": "range",
		"operation": "multiply",
		"value": 1.2,
		"filter": {},
		"source": "item1"
	})
	modifier_service.add_modifier({
		"stat": "range",
		"operation": "multiply",
		"value": 1.5,
		"filter": {},
		"source": "item2"
	})
	var base_stats = TurretRegistry.get_base_stats("plasma")
	var expected = base_stats["range"] * 1.2 * 1.5
	var stats = turret_stats_service.get_turret_stats("plasma", 1.0)
	assert_almost_eq(stats["range"], expected, 0.001,
		"Multiple multipliers should stack multiplicatively")


# =============================================================================
# MODIFIER FILTERING BY TURRET TYPE
# =============================================================================

func test_modifier_filtered_by_turret_type_match():
	modifier_service.add_modifier({
		"stat": "damage",
		"operation": "add",
		"value": 10.0,
		"filter": {"turret_type": ["fire"]},
		"source": "fire_boost"
	})
	var base_stats = TurretRegistry.get_base_stats("fire")
	var stats = turret_stats_service.get_turret_stats("fire", 1.0)
	assert_eq(stats["damage"], base_stats["damage"] + 10.0,
		"Fire turret should get fire-filtered modifier")


func test_modifier_filtered_by_turret_type_no_match():
	modifier_service.add_modifier({
		"stat": "damage",
		"operation": "add",
		"value": 10.0,
		"filter": {"turret_type": ["fire"]},
		"source": "fire_boost"
	})
	var base_stats = TurretRegistry.get_base_stats("sniper")
	var stats = turret_stats_service.get_turret_stats("sniper", 1.0)
	assert_eq(stats["damage"], base_stats["damage"],
		"Sniper should not get fire-filtered modifier")


# =============================================================================
# MODIFIER FILTERING BY DAMAGE TYPE
# =============================================================================

func test_modifier_filtered_by_damage_type_match():
	modifier_service.add_modifier({
		"stat": "damage",
		"operation": "multiply",
		"value": 1.5,
		"filter": {"damage_type": [GameEnums.DamageType.PLASMA]},
		"source": "plasma_boost"
	})
	var base_stats = TurretRegistry.get_base_stats("plasma")
	var stats = turret_stats_service.get_turret_stats("plasma", 1.0)
	assert_eq(stats["damage"], base_stats["damage"] * 1.5,
		"Plasma turret should get plasma damage modifier")


func test_modifier_filtered_by_damage_type_no_match():
	modifier_service.add_modifier({
		"stat": "damage",
		"operation": "multiply",
		"value": 1.5,
		"filter": {"damage_type": [GameEnums.DamageType.FIRE]},
		"source": "fire_boost"
	})
	var base_stats = TurretRegistry.get_base_stats("shock")
	var stats = turret_stats_service.get_turret_stats("shock", 1.0)
	assert_eq(stats["damage"], base_stats["damage"],
		"Shock turret should not get fire damage modifier")


# =============================================================================
# MODIFIER FILTERING BY ATTACK STYLE
# =============================================================================

func test_modifier_filtered_by_attack_style_match():
	modifier_service.add_modifier({
		"stat": "fire_rate",
		"operation": "multiply",
		"value": 1.3,
		"filter": {"attack_style": [GameEnums.AttackStyle.PROJECTILE]},
		"source": "projectile_boost"
	})
	var base_stats = TurretRegistry.get_base_stats("normal")  # Normal has PROJECTILE
	var stats = turret_stats_service.get_turret_stats("normal", 1.0)
	assert_eq(stats["fire_rate"], base_stats["fire_rate"] * 1.3,
		"Normal (projectile) should get projectile modifier")


func test_modifier_filtered_by_attack_style_no_match():
	modifier_service.add_modifier({
		"stat": "fire_rate",
		"operation": "multiply",
		"value": 1.3,
		"filter": {"attack_style": [GameEnums.AttackStyle.AOE]},
		"source": "aoe_boost"
	})
	var base_stats = TurretRegistry.get_base_stats("sniper")
	var stats = turret_stats_service.get_turret_stats("sniper", 1.0)
	assert_eq(stats["fire_rate"], base_stats["fire_rate"],
		"Sniper should not get AOE modifier")


# =============================================================================
# TURRET COLOR & TYPE QUERIES
# =============================================================================

func test_get_turret_color():
	var color = turret_stats_service.get_turret_color("fire")
	assert_not_null(color, "Should return a color for fire turret")
	assert_typeof(color, TYPE_COLOR, "Should return Color type")


func test_turret_has_attack_style():
	var has_instant = turret_stats_service.turret_has_attack_style("sniper", GameEnums.AttackStyle.INSTANT)
	assert_true(has_instant, "Sniper should have instant attack style")


func test_turret_has_damage_type():
	var has_fire = turret_stats_service.turret_has_damage_type("fire", GameEnums.DamageType.FIRE)
	assert_true(has_fire, "Fire turret should have fire damage type")


# =============================================================================
# TURRET COUNT TRACKING
# =============================================================================

func test_get_total_turret_count_empty():
	assert_eq(turret_stats_service.get_total_turret_count(), 0,
		"Should return 0 with no turrets")


func test_get_total_turret_count_single_type():
	turret_stats_service.turret_counts = {"fire": 5}
	assert_eq(turret_stats_service.get_total_turret_count(), 5,
		"Should return 5 with 5 fire turrets")


func test_get_total_turret_count_multiple_types():
	turret_stats_service.turret_counts = {"fire": 3, "sniper": 2, "plasma": 4}
	assert_eq(turret_stats_service.get_total_turret_count(), 9,
		"Should return 9 total turrets")


# =============================================================================
# TURRET DIVERSITY METRICS
# =============================================================================

func test_get_turret_type_diversity_none():
	assert_eq(turret_stats_service.get_turret_type_diversity(), 0,
		"Should return 0 with no turrets")


func test_get_turret_type_diversity_one_type():
	turret_stats_service.turret_counts = {"fire": 5}
	assert_eq(turret_stats_service.get_turret_type_diversity(), 1,
		"Should return 1 with one turret type")


func test_get_turret_type_diversity_multiple_types():
	turret_stats_service.turret_counts = {"fire": 2, "sniper": 1, "plasma": 3}
	assert_eq(turret_stats_service.get_turret_type_diversity(), 3,
		"Should return 3 with three turret types")


func test_get_turret_type_diversity_ignores_zero_counts():
	turret_stats_service.turret_counts = {"fire": 2, "sniper": 0, "plasma": 1}
	assert_eq(turret_stats_service.get_turret_type_diversity(), 2,
		"Should ignore turret types with 0 count")


func test_get_damage_type_diversity():
	# fire has FIRE, sniper has PHYSICAL, plasma has PLASMA
	turret_stats_service.turret_counts = {"fire": 1, "sniper": 1, "plasma": 1}
	var diversity = turret_stats_service.get_damage_type_diversity()
	assert_gte(diversity, 3, "Should have at least 3 different damage types")


func test_get_damage_type_diversity_empty():
	assert_eq(turret_stats_service.get_damage_type_diversity(), 0,
		"Should return 0 with no turrets")


# =============================================================================
# MOST COMMON TURRET TYPE
# =============================================================================

func test_get_most_common_turret_type_empty():
	var most_common = turret_stats_service.get_most_common_turret_type()
	assert_eq(most_common, "",
		"Should return empty string with no turrets")


func test_get_most_common_turret_type_single():
	turret_stats_service.turret_counts = {"fire": 5}
	var most_common = turret_stats_service.get_most_common_turret_type()
	assert_eq(most_common, "fire",
		"Should return fire as most common")


func test_get_most_common_turret_type_multiple():
	turret_stats_service.turret_counts = {"fire": 2, "sniper": 5, "plasma": 1}
	var most_common = turret_stats_service.get_most_common_turret_type()
	assert_eq(most_common, "sniper",
		"Should return sniper as most common")


# =============================================================================
# TURRET PLACEMENT CONSTRAINTS
# =============================================================================

func test_get_turret_min_distance_default():
	var min_dist = turret_stats_service.get_turret_min_distance({})
	assert_eq(min_dist, GameConstants.TURRET_MIN_DISTANCE,
		"Should return default min distance")


func test_get_turret_purchase_penalty_default():
	var penalty = turret_stats_service.get_turret_purchase_penalty()
	assert_eq(penalty, GameConstants.TURRET_PURCHASE_PENALTY,
		"Should return default penalty")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_get_turret_stats_zero_difficulty():
	var stats = turret_stats_service.get_turret_stats("normal", 0.0)
	assert_eq(stats["damage"], 0.0,
		"Zero difficulty should result in 0 damage")


func test_get_turret_stats_negative_difficulty():
	var base_stats = TurretRegistry.get_base_stats("fire")
	var stats = turret_stats_service.get_turret_stats("fire", -1.0)
	assert_eq(stats["damage"], base_stats["damage"] * -1.0,
		"Negative difficulty should result in negative damage")


func test_empty_filter_applies_to_all_turrets():
	modifier_service.add_modifier({
		"stat": "range",
		"operation": "add",
		"value": 50.0,
		"filter": {},
		"source": "universal_boost"
	})
	var fire_stats = turret_stats_service.get_turret_stats("fire", 1.0)
	var sniper_stats = turret_stats_service.get_turret_stats("sniper", 1.0)

	var fire_base = TurretRegistry.get_base_stats("fire")
	var sniper_base = TurretRegistry.get_base_stats("sniper")

	assert_eq(fire_stats["range"], fire_base["range"] + 50.0,
		"Empty filter should apply to fire")
	assert_eq(sniper_stats["range"], sniper_base["range"] + 50.0,
		"Empty filter should apply to sniper")

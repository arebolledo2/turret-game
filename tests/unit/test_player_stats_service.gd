extends GutTest

# =============================================================================
# Unit tests for PlayerStatsService
# Tests player health, speed, luck, and modifier integration
# =============================================================================

var player_stats_service: Node
var modifier_service: Node

func before_all() -> void:
	player_stats_service = get_node("/root/PlayerStatsService")
	modifier_service = get_node("/root/ModifierService")

func before_each() -> void:
	TestHelpers.reset_all_services()
	player_stats_service.reset_state()
	modifier_service.clear_modifiers()


# =============================================================================
# RESET STATE
# =============================================================================

func test_reset_state_sets_base_luck():
	player_stats_service.player_luck = 5
	player_stats_service.reset_state()
	assert_eq(player_stats_service.player_luck, GameConstants.PLAYER_BASE_LUCK,
		"Reset should set base luck")


func test_reset_state_is_idempotent():
	player_stats_service.reset_state()
	var luck1 = player_stats_service.player_luck
	player_stats_service.reset_state()
	var luck2 = player_stats_service.player_luck
	assert_eq(luck1, luck2, "Multiple resets should be consistent")


# =============================================================================
# PLAYER SPEED
# =============================================================================

func test_get_player_speed_base():
	var speed = player_stats_service.get_player_speed()
	assert_eq(speed, GameConstants.PLAYER_SPEED,
		"Should return base speed without modifiers")


func test_get_player_speed_with_additive_modifier():
	modifier_service.add_modifier({
		"stat": "player_speed",
		"operation": "add",
		"value": 50.0,
		"source": "test_item"
	})
	var speed = player_stats_service.get_player_speed()
	assert_eq(speed, GameConstants.PLAYER_SPEED + 50.0,
		"Should apply additive modifier")


func test_get_player_speed_with_increase_modifier():
	modifier_service.add_modifier({
		"stat": "player_speed",
		"operation": "increase",
		"value": 0.5,
		"source": "test_item"
	})
	var speed = player_stats_service.get_player_speed()
	assert_eq(speed, GameConstants.PLAYER_SPEED * 1.5,
		"Should apply 50% increase modifier (base * 1.5)")


func test_get_player_speed_with_multiple_modifiers():
	modifier_service.add_modifier({
		"stat": "player_speed",
		"operation": "add",
		"value": 50.0,
		"source": "item1"
	})
	modifier_service.add_modifier({
		"stat": "player_speed",
		"operation": "more",
		"value": 2.0,
		"source": "item2"
	})
	# Should apply adds first, then "more" multipliers
	var expected = (GameConstants.PLAYER_SPEED + 50.0) * 2.0
	var speed = player_stats_service.get_player_speed()
	assert_eq(speed, expected,
		"Should apply adds before 'more' multipliers")


# =============================================================================
# PLAYER MAX HEALTH
# =============================================================================

func test_get_player_max_health_base():
	var health = player_stats_service.get_player_max_health(1.0)
	assert_eq(health, GameConstants.PLAYER_BASE_MAX_HEALTH,
		"Should return base health with 1.0 difficulty mult")


func test_get_player_max_health_with_difficulty():
	var health = player_stats_service.get_player_max_health(1.5)
	assert_eq(health, GameConstants.PLAYER_BASE_MAX_HEALTH * 1.5,
		"Should apply difficulty multiplier")


func test_get_player_max_health_with_modifier():
	modifier_service.add_modifier({
		"stat": "player_max_health",
		"operation": "add",
		"value": 20.0,
		"source": "test_item"
	})
	var health = player_stats_service.get_player_max_health(1.0)
	assert_eq(health, GameConstants.PLAYER_BASE_MAX_HEALTH + 20.0,
		"Should apply health modifier")


func test_get_player_max_health_difficulty_and_modifiers():
	modifier_service.add_modifier({
		"stat": "player_max_health",
		"operation": "increase",
		"value": 0.2,
		"source": "test_item"
	})
	# Base * difficulty * (1 + increase)
	var expected = (GameConstants.PLAYER_BASE_MAX_HEALTH * 0.8) * 1.2
	var health = player_stats_service.get_player_max_health(0.8)
	assert_eq(health, expected,
		"Should apply both difficulty and increase modifiers")


# =============================================================================
# PLAYER WEAPON DAMAGE
# =============================================================================

func test_get_player_weapon_damage_base():
	var damage = player_stats_service.get_player_weapon_damage()
	assert_eq(damage, GameConstants.PLAYER_TURRET_DAMAGE,
		"Should return base weapon damage")


func test_get_player_weapon_damage_with_modifier():
	modifier_service.add_modifier({
		"stat": "player_weapon_damage",
		"operation": "increase",
		"value": 0.5,
		"source": "damage_boost"
	})
	var damage = player_stats_service.get_player_weapon_damage()
	assert_eq(damage, GameConstants.PLAYER_TURRET_DAMAGE * 1.5,
		"Should apply 50% increase damage modifier")


# =============================================================================
# PLAYER LUCK
# =============================================================================

func test_get_player_luck_base():
	var luck = player_stats_service.get_player_luck()
	assert_eq(luck, GameConstants.PLAYER_BASE_LUCK,
		"Should return base luck")


func test_get_player_luck_with_additive_modifier():
	modifier_service.add_modifier({"stat": "player_luck", "operation": "add", "value": 2, "source": "luck_item"})
	assert_eq(player_stats_service.get_player_luck(), GameConstants.PLAYER_BASE_LUCK + 2,
		"Should apply luck modifier")


func test_get_player_luck_is_uncapped():
	player_stats_service.player_luck = 500
	assert_eq(player_stats_service.get_player_luck(), 500, "Luck points have no cap")


func test_get_player_luck_can_be_negative():
	modifier_service.add_modifier({"stat": "player_luck", "operation": "add", "value": -3, "source": "luck_penalty"})
	assert_eq(player_stats_service.get_player_luck(), -3, "Luck can go below zero")
	assert_lt(player_stats_service.get_luck_factor(), 0.0, "Negative luck gives a negative factor")


func test_get_player_luck_display_is_signed_int():
	player_stats_service.player_luck = 7
	assert_eq(player_stats_service.get_player_luck_display(), 7)
	player_stats_service.player_luck = -2
	assert_eq(player_stats_service.get_player_luck_display(), -2)


func test_luck_factor_has_diminishing_returns():
	assert_eq(ItemRegistry.luck_factor_for(0.0), 0.0)
	var previous := 0.0
	var previous_gain := INF
	for points in [5.0, 10.0, 20.0, 40.0, 80.0]:
		var factor := ItemRegistry.luck_factor_for(points)
		assert_gt(factor, previous, "More luck always helps")
		assert_lt(factor, GameConstants.LUCK_FACTOR_MAX, "Factor stays under its asymptote")
		var gain_per_point: float = (factor - previous) / (points - (previous_points_for(points)))
		assert_lt(gain_per_point, previous_gain, "Each extra point is worth less")
		previous = factor
		previous_gain = gain_per_point


func previous_points_for(points: float) -> float:
	return {5.0: 0.0, 10.0: 5.0, 20.0: 10.0, 40.0: 20.0, 80.0: 40.0}[points]


func test_negative_luck_factor_floors_at_negative_max():
	assert_lt(ItemRegistry.luck_factor_for(-10.0), 0.0)
	assert_gt(ItemRegistry.luck_factor_for(-1000.0), -GameConstants.LUCK_NEGATIVE_FACTOR_MAX - 0.0001)
	assert_almost_eq(ItemRegistry.luck_factor_for(-1000.0), -GameConstants.LUCK_NEGATIVE_FACTOR_MAX, 0.001)


# =============================================================================
# PICKUP RADIUS
# =============================================================================

func test_get_pickup_radius_base():
	var radius = player_stats_service.get_pickup_radius()
	assert_eq(radius, GameConstants.PLAYER_PICKUP_RADIUS,
		"Should return base pickup radius")


func test_get_pickup_radius_with_modifier():
	modifier_service.add_modifier({
		"stat": "pickup_radius",
		"operation": "increase",
		"value": 0.5,
		"source": "magnet_item"
	})
	var radius = player_stats_service.get_pickup_radius()
	assert_eq(radius, GameConstants.PLAYER_PICKUP_RADIUS * 1.5,
		"Should apply 50% increase radius modifier")


# =============================================================================
# MODIFIER SERVICE INTEGRATION
# =============================================================================

func test_multiple_stats_with_different_modifiers():
	modifier_service.add_modifier({
		"stat": "player_speed",
		"operation": "add",
		"value": 50.0,
		"source": "speed_item"
	})
	modifier_service.add_modifier({
		"stat": "player_weapon_damage",
		"operation": "more",
		"value": 2.0,
		"source": "damage_item"
	})
	modifier_service.add_modifier({
		"stat": "player_luck",
		"operation": "add",
		"value": 3,
		"source": "luck_item"
	})

	var speed = player_stats_service.get_player_speed()
	var damage = player_stats_service.get_player_weapon_damage()
	var luck = player_stats_service.get_player_luck()

	assert_eq(speed, GameConstants.PLAYER_SPEED + 50.0,
		"Speed should be modified by add")
	assert_eq(damage, GameConstants.PLAYER_TURRET_DAMAGE * 2.0,
		"Damage should be modified by 'more' 2.0x")
	assert_eq(luck, GameConstants.PLAYER_BASE_LUCK + 3,
		"Luck should be modified by add")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_zero_difficulty_multiplier():
	var health = player_stats_service.get_player_max_health(0.0)
	assert_eq(health, 0.0,
		"Zero difficulty mult should result in 0 health")


func test_negative_difficulty_multiplier():
	var health = player_stats_service.get_player_max_health(-1.0)
	assert_lt(health, 0.0,
		"Negative difficulty mult should result in negative health")


func test_very_high_difficulty():
	var health = player_stats_service.get_player_max_health(10.0)
	assert_eq(health, GameConstants.PLAYER_BASE_MAX_HEALTH * 10.0,
		"Should handle very high difficulty")


func test_luck_increase_modifier_rounds_to_whole_points():
	player_stats_service.player_luck = 5
	modifier_service.add_modifier({"stat": "player_luck", "operation": "increase", "value": 0.3, "source": "luck_item"})
	assert_eq(player_stats_service.get_player_luck(), 7, "5 * 1.3 = 6.5 rounds to 7")


# =============================================================================
# HEALTH REGEN
# =============================================================================

func test_get_player_health_regen_base():
	var regen = player_stats_service.get_player_health_regen()
	assert_eq(regen, GameConstants.PLAYER_BASE_HEALTH_REGEN,
		"Should return base health regen (0)")


func test_get_player_health_regen_with_modifier():
	modifier_service.add_modifier({
		"stat": "player_health_regen",
		"operation": "add",
		"value": 2.0,
		"source": "regen_item"
	})
	var regen = player_stats_service.get_player_health_regen()
	assert_eq(regen, 2, "Should apply regen modifier and return int")


func test_get_heal_interval_no_regen():
	var interval = player_stats_service.get_heal_interval()
	assert_eq(interval, -1.0, "No healing when regen is 0")


func test_get_heal_interval_with_regen():
	modifier_service.add_modifier({
		"stat": "player_health_regen",
		"operation": "add",
		"value": 2.0,
		"source": "regen_item"
	})
	var interval = player_stats_service.get_heal_interval()
	var expected = GameConstants.PLAYER_BASE_HEAL_INTERVAL / 2.0
	assert_eq(interval, expected, "Should calculate interval from regen (10.0 / 2 = 5.0)")

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
	player_stats_service.player_luck = 0.5
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
	modifier_service.add_modifier({
		"stat": "player_luck",
		"operation": "add",
		"value": 0.05,
		"source": "luck_item"
	})
	var luck = player_stats_service.get_player_luck()
	assert_eq(luck, GameConstants.PLAYER_BASE_LUCK + 0.05,
		"Should apply luck modifier")


func test_get_player_luck_clamped_to_max():
	player_stats_service.player_luck = 1.8
	modifier_service.add_modifier({
		"stat": "player_luck",
		"operation": "add",
		"value": 0.5, # 1.8 + 0.5 = 2.3, should clamp to 2.0
		"source": "luck_item"
	})
	var luck = player_stats_service.get_player_luck()
	assert_eq(luck, GameConstants.PLAYER_MAX_LUCK,
		"Luck should be clamped to max")


func test_get_player_luck_clamped_to_zero():
	player_stats_service.player_luck = 0.05
	modifier_service.add_modifier({
		"stat": "player_luck",
		"operation": "add",
		"value": - 0.2,
		"source": "luck_penalty"
	})
	var luck = player_stats_service.get_player_luck()
	assert_eq(luck, 0.0,
		"Luck should be clamped to 0")


func test_get_player_luck_within_bounds():
	player_stats_service.player_luck = 0.15
	var luck = player_stats_service.get_player_luck()
	assert_gte(luck, 0.0, "Luck should be >= 0")
	assert_lte(luck, GameConstants.PLAYER_MAX_LUCK,
		"Luck should be <= max")


func test_get_player_luck_display():
	player_stats_service.player_luck = 0.15
	var display = player_stats_service.get_player_luck_display()
	assert_eq(display, 15, "Should convert 0.15 to 15")


func test_get_player_luck_display_with_modifier():
	player_stats_service.player_luck = 0.10
	modifier_service.add_modifier({
		"stat": "player_luck",
		"operation": "add",
		"value": 0.05,
		"source": "luck_item"
	})
	var display = player_stats_service.get_player_luck_display()
	assert_eq(display, 15, "Should display modified luck as integer")


func test_get_player_luck_display_max():
	player_stats_service.player_luck = GameConstants.PLAYER_MAX_LUCK
	var display = player_stats_service.get_player_luck_display()
	assert_eq(display, int(GameConstants.PLAYER_MAX_LUCK * 100),
		"Should display max luck correctly")


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
		"value": 0.1,
		"source": "luck_item"
	})

	var speed = player_stats_service.get_player_speed()
	var damage = player_stats_service.get_player_weapon_damage()
	var luck = player_stats_service.get_player_luck()

	assert_eq(speed, GameConstants.PLAYER_SPEED + 50.0,
		"Speed should be modified by add")
	assert_eq(damage, GameConstants.PLAYER_TURRET_DAMAGE * 2.0,
		"Damage should be modified by 'more' 2.0x")
	assert_eq(luck, GameConstants.PLAYER_BASE_LUCK + 0.1,
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


func test_luck_display_rounds_down():
	player_stats_service.player_luck = 0.159
	var display = player_stats_service.get_player_luck_display()
	assert_eq(display, 15,
		"Should round down 15.9 to 15")


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

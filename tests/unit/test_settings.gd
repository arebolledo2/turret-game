extends GutTest

# =============================================================================
# Unit tests for settings flags in SettingsService
# Tests runtime toggle behavior
# =============================================================================

func before_each() -> void:
	GameStateService.reset_state()
	DifficultyService.set_difficulty(GameEnums.Difficulty.EASY)
	SettingsService.reset_state()


# =============================================================================
# DAMAGE NUMBERS SETTING
# =============================================================================

func test_show_damage_numbers_default():
	assert_true(SettingsService.show_damage_numbers, "Damage numbers should be enabled by default")


func test_show_damage_numbers_can_be_toggled():
	SettingsService.show_damage_numbers = false
	assert_false(SettingsService.show_damage_numbers, "Damage numbers should be disabled")

	SettingsService.show_damage_numbers = true
	assert_true(SettingsService.show_damage_numbers, "Damage numbers should be re-enabled")


# =============================================================================
# PLAYER AUTO-ATTACK SETTING
# =============================================================================

func test_player_auto_attack_disabled_by_default():
	assert_false(SettingsService.player_auto_attack_enabled,
		"Player auto-attack should be disabled by default")


func test_player_auto_attack_can_be_enabled():
	SettingsService.player_auto_attack_enabled = true
	assert_true(SettingsService.player_auto_attack_enabled,
		"Player auto-attack should be enabled after setting")

	SettingsService.player_auto_attack_enabled = false
	assert_false(SettingsService.player_auto_attack_enabled,
		"Player auto-attack should be disabled again")


# =============================================================================
# TURRET PICKUP CONSTANTS
# =============================================================================

func test_turret_pickup_range_exists():
	assert_gt(GameConstants.TURRET_PICKUP_RANGE, 0.0, 
		"Turret pickup range should be positive")


func test_turret_carry_speed_penalty_exists():
	assert_gt(GameConstants.TURRET_CARRY_SPEED_PENALTY, 0.0, 
		"Speed penalty should be positive")
	assert_lt(GameConstants.TURRET_CARRY_SPEED_PENALTY, 1.0, 
		"Speed penalty should be less than 1.0 (reduces speed)")


func test_turret_carry_offset_exists():
	assert_typeof(GameConstants.TURRET_CARRY_OFFSET, TYPE_VECTOR2, 
		"Carry offset should be a Vector2")


func test_turret_in_range_indicator_alpha_exists():
	assert_gte(GameConstants.TURRET_IN_RANGE_INDICATOR_ALPHA, 0.0, 
		"Indicator alpha should be >= 0")
	assert_lte(GameConstants.TURRET_IN_RANGE_INDICATOR_ALPHA, 1.0, 
		"Indicator alpha should be <= 1")

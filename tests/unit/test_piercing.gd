extends GutTest

# =============================================================================
# Unit tests for Piercing mechanic
# Tests that the "Piercing Rounds" item adds pierce to direct projectile turrets only
# =============================================================================

var modifier_system: ModifierSystem
var easy_config: Dictionary


func before_each() -> void:
	TestHelpers.reset_all_services()
	modifier_system = ModifierSystem.new()
	easy_config = DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]


func _pierce_of(turret_type: String) -> int:
	return int(modifier_system.get_turret_stats(turret_type, easy_config).get("pierce", 0))


func test_piercing_rounds_adds_pierce_to_normal_turret() -> void:
	modifier_system.add_modifier(ItemRegistry.get_modifiers("piercing_rounds")[0])
	assert_eq(_pierce_of("normal"), 1, "Normal turret base pierce is 0, so Piercing Rounds makes it 1")


func test_piercing_rounds_does_not_affect_shock_turret() -> void:
	modifier_system.add_modifier(ItemRegistry.get_modifiers("piercing_rounds")[0])
	assert_eq(_pierce_of("shock"), 0, "Shock is not a direct projectile")


func test_piercing_rounds_does_not_affect_tesla_turret() -> void:
	modifier_system.add_modifier(ItemRegistry.get_modifiers("piercing_rounds")[0])
	assert_eq(_pierce_of("tesla"), 0, "Tesla chains instantly rather than firing projectiles")


func test_multiple_piercing_rounds_stack() -> void:
	var first: Dictionary = ItemRegistry.get_modifiers("piercing_rounds")[0].duplicate(true)
	var second: Dictionary = ItemRegistry.get_modifiers("piercing_rounds")[0].duplicate(true)
	first["id"] = "piercing_1"
	second["id"] = "piercing_2"
	modifier_system.add_modifier(first)
	modifier_system.add_modifier(second)
	assert_eq(_pierce_of("normal"), 2, "Two Piercing Rounds give +2 pierce total")

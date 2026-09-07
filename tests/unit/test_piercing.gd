extends GutTest

# =============================================================================
# Unit tests for Piercing mechanic
# Tests that the "Shrapnel Rounds" item correctly adds piercing to projectile turrets
# =============================================================================

var modifier_system: ModifierSystem


func before_each() -> void:
	TestHelpers.reset_all_services()
	modifier_system = ModifierSystem.new()


func test_shrapnel_rounds_adds_pierce_to_normal_turret():
	# Shrapnel Rounds should add +1 pierce to Normal turret (PROJECTILE attack style)
	var shrapnel_modifier = ItemRegistry.get_modifiers("shrapnel_rounds")[0]
	modifier_system.add_modifier(shrapnel_modifier)

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)

	# Normal turret base pierce is 0, should become 1
	assert_eq(stats.get("pierce", 0), 1,
		"Normal turret should have 1 pierce with Shrapnel Rounds")


func test_shrapnel_rounds_adds_pierce_to_fire_turret():
	# Fire turret also has PROJECTILE attack style
	var shrapnel_modifier = ItemRegistry.get_modifiers("shrapnel_rounds")[0]
	modifier_system.add_modifier(shrapnel_modifier)

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("fire", easy_config)

	# Fire turret base pierce is 99, should become 100
	assert_eq(stats.get("pierce", 0), 100,
		"Fire turret should have 100 pierce with Shrapnel Rounds (99 base + 1)")


func test_shrapnel_rounds_adds_pierce_to_plasma_turret():
	# Plasma turret has both PROJECTILE and AOE attack styles
	var shrapnel_modifier = ItemRegistry.get_modifiers("shrapnel_rounds")[0]
	modifier_system.add_modifier(shrapnel_modifier)

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("plasma", easy_config)

	# Plasma turret base pierce is 0, should become 1
	assert_eq(stats.get("pierce", 0), 1,
		"Plasma turret should have 1 pierce with Shrapnel Rounds")


func test_shrapnel_rounds_does_not_affect_sniper_turret():
	# Sniper has INSTANT attack style, not PROJECTILE
	var shrapnel_modifier = ItemRegistry.get_modifiers("shrapnel_rounds")[0]
	modifier_system.add_modifier(shrapnel_modifier)

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("sniper", easy_config)

	# Sniper doesn't have pierce stat in base stats, and shouldn't get it from Shrapnel
	assert_eq(stats.get("pierce", 0), 0,
		"Sniper turret should NOT get pierce from Shrapnel Rounds (INSTANT attack style)")


func test_shrapnel_rounds_does_not_affect_shock_turret():
	# Shock has AOE attack style, not PROJECTILE
	var shrapnel_modifier = ItemRegistry.get_modifiers("shrapnel_rounds")[0]
	modifier_system.add_modifier(shrapnel_modifier)

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("shock", easy_config)

	assert_eq(stats.get("pierce", 0), 0,
		"Shock turret should NOT get pierce from Shrapnel Rounds (AOE attack style)")


func test_shrapnel_rounds_does_not_affect_tesla_turret():
	# Tesla has INSTANT and CHAIN attack styles, not PROJECTILE
	var shrapnel_modifier = ItemRegistry.get_modifiers("shrapnel_rounds")[0]
	modifier_system.add_modifier(shrapnel_modifier)

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("tesla", easy_config)

	assert_eq(stats.get("pierce", 0), 0,
		"Tesla turret should NOT get pierce from Shrapnel Rounds (CHAIN/INSTANT attack style)")


func test_multiple_shrapnel_rounds_stack():
	# Multiple Shrapnel Rounds should stack additively
	var shrapnel_modifier_1 = ItemRegistry.get_modifiers("shrapnel_rounds")[0].duplicate(true)
	var shrapnel_modifier_2 = ItemRegistry.get_modifiers("shrapnel_rounds")[0].duplicate(true)
	shrapnel_modifier_1["id"] = "shrapnel_1"
	shrapnel_modifier_2["id"] = "shrapnel_2"

	modifier_system.add_modifier(shrapnel_modifier_1)
	modifier_system.add_modifier(shrapnel_modifier_2)

	var easy_config = GameConstants.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY]
	var stats = modifier_system.get_turret_stats("normal", easy_config)

	# Normal turret should have 2 pierce (0 base + 1 + 1)
	assert_eq(stats.get("pierce", 0), 2,
		"Two Shrapnel Rounds should give +2 pierce total")

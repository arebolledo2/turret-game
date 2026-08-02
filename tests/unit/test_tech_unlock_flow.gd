extends GutTest

## Unit tests for Tech Unlock Flow
## Tests unlocking techs, prerequisite checking, cost deduction, and effect application

var tech_tree_service: Node

func before_each():
	tech_tree_service = TechTreeService
	tech_tree_service.reset_state()
	ModifierService.clear_modifiers()
	ItemTrackingService.reset_state()


# =============================================================================
# BASIC UNLOCK FLOW
# =============================================================================

func test_unlock_tech_success():
	tech_tree_service.add_research_points(100)

	var result = tech_tree_service.unlock_tech("turret_damage_1")

	assert_true(result, "Should successfully unlock tech")
	assert_true(tech_tree_service.is_tech_unlocked("turret_damage_1"),
		"Tech should be marked as unlocked")


func test_unlock_tech_deducts_cost():
	tech_tree_service.add_research_points(100)

	tech_tree_service.unlock_tech("turret_damage_1")  # Cost: 10

	assert_eq(tech_tree_service.total_research_points, 90,
		"Should deduct cost from research points")


func test_unlock_tech_increments_unlock_count():
	tech_tree_service.add_research_points(100)

	tech_tree_service.unlock_tech("turret_damage_1")

	assert_eq(tech_tree_service.get_tech_unlock_count("turret_damage_1"), 1,
		"Should increment unlock count")


func test_unlock_tech_emits_signal():
	tech_tree_service.add_research_points(100)

	watch_signals(Events)
	tech_tree_service.unlock_tech("turret_damage_1")

	assert_signal_emitted(Events, "tech_unlocked",
		"Should emit tech_unlocked signal")


# =============================================================================
# PREREQUISITE CHECKING
# =============================================================================

func test_cannot_unlock_without_prerequisites():
	tech_tree_service.add_research_points(100)

	# rapid_fire_1 requires turret_damage_1
	var result = tech_tree_service.can_unlock_tech("rapid_fire_1")

	assert_false(result,
		"Should not be able to unlock tech without prerequisites")


func test_can_unlock_after_prerequisites_met():
	tech_tree_service.add_research_points(100)

	# First unlock prerequisite
	tech_tree_service.unlock_tech("turret_damage_1")

	# Now check if tier 2 tech is available
	var result = tech_tree_service.can_unlock_tech("rapid_fire_1")

	assert_true(result,
		"Should be able to unlock tech after prerequisites met")


func test_unlock_tier2_after_tier1():
	tech_tree_service.add_research_points(100)

	# Unlock tier 1
	tech_tree_service.unlock_tech("turret_damage_1")
	# Unlock tier 2
	var result = tech_tree_service.unlock_tech("rapid_fire_1")

	assert_true(result, "Should successfully unlock tier 2 tech")
	assert_true(tech_tree_service.is_tech_unlocked("rapid_fire_1"),
		"Tier 2 tech should be unlocked")


func test_capstone_requires_multiple_prerequisites():
	tech_tree_service.add_research_points(500)

	# economic_supremacy requires both shop_lock and compound_interest
	var cannot_unlock_yet = not tech_tree_service.can_unlock_tech("economic_supremacy")

	# Unlock path to shop_lock (tier 1 -> tier 2 -> tier 3 -> tier 4)
	tech_tree_service.unlock_tech("scrap_collector")
	tech_tree_service.unlock_tech("shop_discount")
	tech_tree_service.unlock_tech("bargain_hunter")
	tech_tree_service.unlock_tech("shop_lock")

	var still_cannot_unlock = not tech_tree_service.can_unlock_tech("economic_supremacy")

	# Unlock path to compound_interest
	tech_tree_service.unlock_tech("efficient_looting")
	tech_tree_service.unlock_tech("scrap_magnet")
	tech_tree_service.unlock_tech("compound_interest")

	var can_unlock_now = tech_tree_service.can_unlock_tech("economic_supremacy")

	assert_true(cannot_unlock_yet, "Should not unlock capstone without any prerequisites")
	assert_true(still_cannot_unlock, "Should not unlock capstone with only one prerequisite")
	assert_true(can_unlock_now, "Should unlock capstone with all prerequisites")


# =============================================================================
# COST CHECKING
# =============================================================================

func test_cannot_unlock_without_enough_research():
	tech_tree_service.add_research_points(5)  # Less than cost of 10

	var result = tech_tree_service.can_unlock_tech("turret_damage_1")

	assert_false(result,
		"Should not be able to unlock tech without enough research points")


func test_can_unlock_with_exact_cost():
	tech_tree_service.add_research_points(10)  # Exact cost

	var result = tech_tree_service.can_unlock_tech("turret_damage_1")

	assert_true(result,
		"Should be able to unlock tech with exact cost")


func test_unlock_fails_without_enough_research():
	tech_tree_service.add_research_points(5)

	watch_signals(Events)
	var result = tech_tree_service.unlock_tech("turret_damage_1")

	assert_false(result, "Should fail to unlock")
	assert_signal_emitted(Events, "tech_unlock_failed",
		"Should emit tech_unlock_failed signal")


# =============================================================================
# REPEATABLE TECHS
# =============================================================================

func test_cannot_unlock_nonrepeatable_tech_twice():
	tech_tree_service.add_research_points(100)

	tech_tree_service.unlock_tech("turret_damage_1")
	var can_unlock_again = tech_tree_service.can_unlock_tech("turret_damage_1")

	assert_false(can_unlock_again,
		"Should not be able to unlock non-repeatable tech twice")


# Note: There are currently no repeatable techs in the registry
# If repeatable techs are added later, add tests like:
# func test_can_unlock_repeatable_tech_multiple_times()
# func test_repeatable_tech_respects_max_unlocks()


# =============================================================================
# MAX UNLOCK LIMITS
# =============================================================================

func test_respects_max_unlocks_limit():
	# All current techs have max_unlocks: 1, so this is the same as non-repeatable
	tech_tree_service.add_research_points(100)

	tech_tree_service.unlock_tech("turret_damage_1")  # max_unlocks: 1
	var count = tech_tree_service.get_tech_unlock_count("turret_damage_1")
	var cannot_unlock_again = not tech_tree_service.can_unlock_tech("turret_damage_1")

	assert_eq(count, 1, "Should have unlocked once")
	assert_true(cannot_unlock_again, "Should not be able to unlock again (max reached)")


# =============================================================================
# EFFECT APPLICATION - MODIFIERS
# =============================================================================

func test_unlock_tech_applies_modifiers():
	tech_tree_service.add_research_points(100)
	ModifierService.clear_modifiers()

	tech_tree_service.unlock_tech("turret_damage_1")

	var active_modifiers = ModifierService.active_modifiers
	assert_gt(active_modifiers.size(), 0,
		"Should have added modifier(s) to ModifierService")


func test_unlock_tech_changes_turret_damage():
	ModifierService.clear_modifiers()
	var base_damage = TurretStatsService.get_turret_stats("normal", 1.0)["damage"]

	tech_tree_service.add_research_points(100)
	tech_tree_service.unlock_tech("turret_damage_1")

	var modified_damage = TurretStatsService.get_turret_stats("normal", 1.0)["damage"]
	assert_almost_eq(modified_damage, base_damage * 1.15, 0.001,
		"Enhanced Ammunition should increase turret damage by 15%")


func test_modifier_has_correct_id():
	tech_tree_service.add_research_points(100)
	ModifierService.clear_modifiers()

	tech_tree_service.unlock_tech("turret_damage_1")

	var active_modifiers = ModifierService.active_modifiers
	var has_tech_modifier = false
	for modifier in active_modifiers:
		if modifier.get("id", "").begins_with("tech_turret_damage_1"):
			has_tech_modifier = true
			break

	assert_true(has_tech_modifier,
		"Should have modifier with correct tech ID prefix")


func test_modifier_has_source_metadata():
	tech_tree_service.add_research_points(100)
	ModifierService.clear_modifiers()

	tech_tree_service.unlock_tech("turret_damage_1")

	var active_modifiers = ModifierService.active_modifiers
	var tech_modifier = null
	for modifier in active_modifiers:
		if modifier.get("source") == "tech":
			tech_modifier = modifier
			break

	assert_not_null(tech_modifier, "Should find tech modifier")
	assert_eq(tech_modifier.get("source_id"), "turret_damage_1",
		"Should have correct source_id")


func test_multiple_tech_unlocks_apply_multiple_modifiers():
	tech_tree_service.add_research_points(100)
	ModifierService.clear_modifiers()

	tech_tree_service.unlock_tech("turret_damage_1")
	var count_after_first = ModifierService.active_modifiers.size()

	tech_tree_service.unlock_tech("rapid_fire_1")  # Requires turret_damage_1 as prereq
	var count_after_second = ModifierService.active_modifiers.size()

	assert_gt(count_after_second, count_after_first,
		"Should have more modifiers after unlocking second tech")


func test_modifier_emits_modifiers_changed_signal():
	tech_tree_service.add_research_points(100)
	ModifierService.clear_modifiers()

	watch_signals(Events)
	tech_tree_service.unlock_tech("turret_damage_1")

	assert_signal_emitted(Events, "modifiers_changed",
		"Should emit modifiers_changed signal")


# =============================================================================
# EFFECT APPLICATION - UNLOCK MECHANIC
# =============================================================================

func test_unlock_mechanic_tech():
	tech_tree_service.add_research_points(100)

	var result = tech_tree_service.unlock_tech("splash_damage")

	assert_true(result, "Should successfully unlock mechanic tech")
	assert_true(tech_tree_service.has_mechanic_unlocked("turret_aoe_damage"),
		"Should have mechanic unlocked")


func test_splash_damage_applies_projectile_aoe_modifier():
	tech_tree_service.add_research_points(100)

	var before_stats = TurretStatsService.get_turret_stats("normal", 1.0)
	assert_eq(before_stats.get("aoe_radius", 0.0), 0.0,
		"Normal turrets should not have splash radius before the tech")

	tech_tree_service.unlock_tech("splash_damage")

	var after_stats = TurretStatsService.get_turret_stats("normal", 1.0)
	assert_eq(after_stats.get("aoe_radius", 0.0), GameConstants.TURRET_SPLASH_AOE_RADIUS,
		"Splash Damage should add its radius to projectile turrets")

	var sniper_stats = TurretStatsService.get_turret_stats("sniper", 1.0)
	assert_eq(sniper_stats.get("aoe_radius", 0.0), 0.0,
		"Splash Damage should not affect instant-hit turrets")


func test_has_mechanic_unlocked_returns_false_for_unlocked_mechanic():
	tech_tree_service.reset_state()

	var result = tech_tree_service.has_mechanic_unlocked("turret_aoe_damage")

	assert_false(result,
		"Should return false for non-unlocked mechanic")


func test_multiple_mechanics_can_be_unlocked():
	tech_tree_service.add_research_points(500)

	# Unlock multiple mechanic techs
	tech_tree_service.unlock_tech("splash_damage")  # turret_aoe_damage

	# Unlock evasion (need prerequisites)
	tech_tree_service.unlock_tech("tactical_armor")
	tech_tree_service.unlock_tech("agile_footwork")
	tech_tree_service.unlock_tech("sprint_training")
	tech_tree_service.unlock_tech("evasion")  # player_evasion

	assert_true(tech_tree_service.has_mechanic_unlocked("turret_aoe_damage"),
		"Should have turret AOE unlocked")
	assert_true(tech_tree_service.has_mechanic_unlocked("player_evasion"),
		"Should have player evasion unlocked")


# =============================================================================
# SHOP MODIFIERS
# =============================================================================

func test_get_shop_modifiers_defaults():
	tech_tree_service.reset_state()

	var shop_mods = tech_tree_service.get_shop_modifiers()

	assert_eq(shop_mods.get("price_mult"), 1.0,
		"Default price multiplier should be 1.0")
	assert_eq(shop_mods.get("offer_count_bonus"), 0,
		"Default offer count bonus should be 0")


func test_shop_discount_tech_affects_price():
	tech_tree_service.add_research_points(100)

	# Unlock shop discount tech
	tech_tree_service.unlock_tech("scrap_collector")
	tech_tree_service.unlock_tech("shop_discount")

	var shop_mods = tech_tree_service.get_shop_modifiers()

	assert_lt(shop_mods.get("price_mult"), 1.0,
		"Price multiplier should be less than 1.0 (discount)")


func test_shop_offer_count_tech_adds_offers():
	tech_tree_service.add_research_points(200)

	# Unlock bargain hunter (adds shop offers)
	tech_tree_service.unlock_tech("scrap_collector")
	tech_tree_service.unlock_tech("shop_discount")
	tech_tree_service.unlock_tech("bargain_hunter")

	var shop_mods = tech_tree_service.get_shop_modifiers()

	assert_eq(shop_mods.get("offer_count_bonus"), 1,
		"Should add 1 bonus offer")


func test_multiple_shop_techs_stack():
	tech_tree_service.add_research_points(500)

	# Unlock multiple shop improvement techs
	# Path: scrap_collector -> shop_discount -> bargain_hunter -> shop_lock
	tech_tree_service.unlock_tech("scrap_collector")
	tech_tree_service.unlock_tech("shop_discount")  # 10% discount (0.90 mult)
	tech_tree_service.unlock_tech("bargain_hunter")  # +1 offer

	# Also unlock economic_supremacy (requires compound_interest too)
	tech_tree_service.unlock_tech("efficient_looting")
	tech_tree_service.unlock_tech("scrap_magnet")
	tech_tree_service.unlock_tech("compound_interest")
	tech_tree_service.unlock_tech("shop_lock")
	tech_tree_service.unlock_tech("economic_supremacy")  # 20% discount (0.80 mult), +2 offers

	var shop_mods = tech_tree_service.get_shop_modifiers()

	# 0.90 * 0.80 = 0.72 (28% total discount)
	assert_almost_eq(shop_mods.get("price_mult"), 0.72, 0.01,
		"Should stack multiple price discounts multiplicatively")

	# 1 + 2 = 3 bonus offers
	assert_eq(shop_mods.get("offer_count_bonus"), 3,
		"Should add all offer count bonuses")


# =============================================================================
# INVALID TECH IDS
# =============================================================================

func test_cannot_unlock_invalid_tech():
	tech_tree_service.add_research_points(100)

	var result = tech_tree_service.unlock_tech("invalid_tech_id")

	assert_false(result, "Should fail to unlock invalid tech")


func test_can_unlock_tech_returns_false_for_invalid_id():
	tech_tree_service.add_research_points(100)

	var result = tech_tree_service.can_unlock_tech("invalid_tech_id")

	assert_false(result, "Should return false for invalid tech ID")


func test_is_tech_unlocked_returns_false_for_invalid_id():
	var result = tech_tree_service.is_tech_unlocked("invalid_tech_id")

	assert_false(result, "Should return false for invalid tech ID")


func test_get_tech_unlock_count_returns_zero_for_invalid_id():
	var count = tech_tree_service.get_tech_unlock_count("invalid_tech_id")

	assert_eq(count, 0, "Should return 0 for invalid tech ID")


# =============================================================================
# STATE PERSISTENCE
# =============================================================================

func test_unlocked_techs_persist_across_operations():
	tech_tree_service.add_research_points(100)

	tech_tree_service.unlock_tech("turret_damage_1")
	tech_tree_service.add_research_points(50)

	# Tech should still be unlocked after adding more research
	assert_true(tech_tree_service.is_tech_unlocked("turret_damage_1"),
		"Tech should remain unlocked after adding research points")


func test_reset_clears_unlocked_techs():
	tech_tree_service.add_research_points(100)
	tech_tree_service.unlock_tech("turret_damage_1")

	tech_tree_service.reset_state()

	assert_false(tech_tree_service.is_tech_unlocked("turret_damage_1"),
		"Tech should not be unlocked after reset")
	assert_eq(tech_tree_service.get_tech_unlock_count("turret_damage_1"), 0,
		"Unlock count should be 0 after reset")

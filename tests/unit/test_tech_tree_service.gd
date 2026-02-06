extends GutTest

# =============================================================================
# Unit tests for TechTreeService
# Tests research point management, tech unlock tracking, and state management
# =============================================================================

var tech_tree_service: Node

func before_all() -> void:
	tech_tree_service = get_node("/root/TechTreeService")

func before_each() -> void:
	tech_tree_service.reset_state()


# =============================================================================
# RESET STATE
# =============================================================================

func test_reset_state_clears_research_points():
	tech_tree_service.total_research_points = 100
	tech_tree_service.reset_state()
	assert_eq(tech_tree_service.total_research_points, 0,
		"Reset should clear research points")


func test_reset_state_clears_unlocked_techs():
	tech_tree_service.unlocked_tech_ids.append("tech1")
	tech_tree_service.unlocked_tech_ids.append("tech2")
	tech_tree_service.reset_state()
	assert_eq(tech_tree_service.unlocked_tech_ids.size(), 0,
		"Reset should clear unlocked techs")


func test_reset_state_clears_unlock_counts():
	tech_tree_service.tech_unlock_counts = {"tech1": 3, "tech2": 1}
	tech_tree_service.reset_state()
	assert_eq(tech_tree_service.tech_unlock_counts.size(), 0,
		"Reset should clear unlock counts")


# =============================================================================
# ADD RESEARCH POINTS
# =============================================================================

func test_add_research_points_basic():
	tech_tree_service.total_research_points = 0
	tech_tree_service.add_research_points(50)
	assert_eq(tech_tree_service.total_research_points, 50,
		"Should add 50 research points")


func test_add_research_points_accumulates():
	tech_tree_service.total_research_points = 100
	tech_tree_service.add_research_points(50)
	assert_eq(tech_tree_service.total_research_points, 150,
		"Should accumulate research points")


func test_add_research_points_multiple_times():
	tech_tree_service.total_research_points = 0
	tech_tree_service.add_research_points(10)
	tech_tree_service.add_research_points(20)
	tech_tree_service.add_research_points(30)
	assert_eq(tech_tree_service.total_research_points, 60,
		"Should accumulate multiple additions")


func test_add_research_points_zero_does_nothing():
	tech_tree_service.total_research_points = 100
	tech_tree_service.add_research_points(0)
	assert_eq(tech_tree_service.total_research_points, 100,
		"Zero should not change research points")


func test_add_research_points_negative_does_nothing():
	tech_tree_service.total_research_points = 100
	tech_tree_service.add_research_points(-50)
	assert_eq(tech_tree_service.total_research_points, 100,
		"Negative amount should not change research points")


# =============================================================================
# IS TECH UNLOCKED
# =============================================================================

func test_is_tech_unlocked_returns_false_initially():
	assert_false(tech_tree_service.is_tech_unlocked("tech1"),
		"Tech should not be unlocked initially")


func test_is_tech_unlocked_returns_true_after_adding():
	tech_tree_service.unlocked_tech_ids.append("tech1")
	assert_true(tech_tree_service.is_tech_unlocked("tech1"),
		"Tech should be unlocked after adding to list")


func test_is_tech_unlocked_only_checks_specific_tech():
	tech_tree_service.unlocked_tech_ids.append("tech1")
	assert_true(tech_tree_service.is_tech_unlocked("tech1"),
		"Tech1 should be unlocked")
	assert_false(tech_tree_service.is_tech_unlocked("tech2"),
		"Tech2 should not be unlocked")


func test_is_tech_unlocked_case_sensitive():
	tech_tree_service.unlocked_tech_ids.append("Tech1")
	assert_true(tech_tree_service.is_tech_unlocked("Tech1"),
		"Should match exact case")
	assert_false(tech_tree_service.is_tech_unlocked("tech1"),
		"Should be case sensitive")


# =============================================================================
# GET TECH UNLOCK COUNT
# =============================================================================

func test_get_tech_unlock_count_returns_zero_initially():
	var count = tech_tree_service.get_tech_unlock_count("tech1")
	assert_eq(count, 0,
		"Unlock count should be 0 initially")


func test_get_tech_unlock_count_returns_correct_value():
	tech_tree_service.tech_unlock_counts["tech1"] = 3
	var count = tech_tree_service.get_tech_unlock_count("tech1")
	assert_eq(count, 3,
		"Should return correct unlock count")


func test_get_tech_unlock_count_independent_per_tech():
	tech_tree_service.tech_unlock_counts["tech1"] = 2
	tech_tree_service.tech_unlock_counts["tech2"] = 5
	assert_eq(tech_tree_service.get_tech_unlock_count("tech1"), 2,
		"Tech1 count should be 2")
	assert_eq(tech_tree_service.get_tech_unlock_count("tech2"), 5,
		"Tech2 count should be 5")


# =============================================================================
# UNLOCK STATE TRACKING
# =============================================================================

func test_unlocked_tech_ids_starts_empty():
	assert_eq(tech_tree_service.unlocked_tech_ids.size(), 0,
		"Should start with no unlocked techs")


func test_tech_unlock_counts_starts_empty():
	assert_eq(tech_tree_service.tech_unlock_counts.size(), 0,
		"Should start with no unlock counts")


func test_manual_unlock_tracking():
	# Manually track unlock (simulates what unlock_tech does)
	tech_tree_service.unlocked_tech_ids.append("tech1")
	tech_tree_service.tech_unlock_counts["tech1"] = 1

	assert_true(tech_tree_service.is_tech_unlocked("tech1"),
		"Tech should be unlocked")
	assert_eq(tech_tree_service.get_tech_unlock_count("tech1"), 1,
		"Unlock count should be 1")


func test_manual_repeatable_unlock_tracking():
	# Simulate unlocking a repeatable tech multiple times
	tech_tree_service.unlocked_tech_ids.append("tech1")
	tech_tree_service.tech_unlock_counts["tech1"] = 1

	# Unlock again (only increment count, don't re-add to unlocked list)
	tech_tree_service.tech_unlock_counts["tech1"] = 2

	assert_true(tech_tree_service.is_tech_unlocked("tech1"),
		"Tech should still be unlocked")
	assert_eq(tech_tree_service.get_tech_unlock_count("tech1"), 2,
		"Unlock count should be 2")
	assert_eq(tech_tree_service.unlocked_tech_ids.count("tech1"), 1,
		"Tech should only appear once in unlocked list")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_large_research_point_amounts():
	tech_tree_service.total_research_points = 0
	tech_tree_service.add_research_points(999999)
	assert_eq(tech_tree_service.total_research_points, 999999,
		"Should handle large research amounts")


func test_empty_tech_id():
	assert_false(tech_tree_service.is_tech_unlocked(""),
		"Empty tech ID should not be unlocked")
	assert_eq(tech_tree_service.get_tech_unlock_count(""), 0,
		"Empty tech ID should have 0 count")


func test_multiple_techs_unlocked():
	tech_tree_service.unlocked_tech_ids.append("tech1")
	tech_tree_service.unlocked_tech_ids.append("tech2")
	tech_tree_service.unlocked_tech_ids.append("tech3")

	assert_eq(tech_tree_service.unlocked_tech_ids.size(), 3,
		"Should track multiple unlocked techs")
	assert_true(tech_tree_service.is_tech_unlocked("tech1"), "Tech1 unlocked")
	assert_true(tech_tree_service.is_tech_unlocked("tech2"), "Tech2 unlocked")
	assert_true(tech_tree_service.is_tech_unlocked("tech3"), "Tech3 unlocked")


func test_reset_after_unlocks():
	# Add research points and unlock techs
	tech_tree_service.total_research_points = 500
	tech_tree_service.unlocked_tech_ids.append("tech1")
	tech_tree_service.unlocked_tech_ids.append("tech2")
	tech_tree_service.tech_unlock_counts["tech1"] = 2

	# Reset everything
	tech_tree_service.reset_state()

	# Verify all cleared
	assert_eq(tech_tree_service.total_research_points, 0,
		"Research should be cleared")
	assert_eq(tech_tree_service.unlocked_tech_ids.size(), 0,
		"Unlocked techs should be cleared")
	assert_eq(tech_tree_service.tech_unlock_counts.size(), 0,
		"Unlock counts should be cleared")
	assert_false(tech_tree_service.is_tech_unlocked("tech1"),
		"Tech1 should not be unlocked after reset")


# =============================================================================
# TURRET UNLOCK SYSTEM
# =============================================================================

func test_turret_unlock_techs_exist():
	# Verify all 7 turret unlock techs exist in registry
	var turret_types = ["sniper", "fire", "plasma", "shock", "tesla", "melee", "mine"]
	for turret_type in turret_types:
		var tech_id = "turret_unlock_%s" % turret_type
		var tech = TechRegistry.get_tech(tech_id)
		assert_false(tech.is_empty(),
			"Turret unlock tech for %s should exist" % turret_type)
		assert_eq(tech.get("path"), "turret_unlock",
			"Turret unlock tech should be in turret_unlock path")
		assert_eq(tech.get("effect_type"), "unlock_mechanic",
			"Turret unlock tech should have unlock_mechanic effect type")


func test_normal_turret_always_unlocked():
	# Normal turret should always be available without research
	assert_true(tech_tree_service.is_turret_type_unlocked("normal"),
		"Normal turret should always be unlocked")


func test_advanced_turrets_locked_initially():
	# All advanced turrets should be locked at game start
	var advanced_turrets = ["sniper", "fire", "plasma", "shock", "tesla", "melee", "mine"]
	for turret_type in advanced_turrets:
		assert_false(tech_tree_service.is_turret_type_unlocked(turret_type),
			"%s turret should be locked initially" % turret_type)


func test_unlocking_turret_tech_unlocks_turret():
	# Grant research points
	tech_tree_service.add_research_points(50)

	# Verify sniper is locked
	assert_false(tech_tree_service.is_turret_type_unlocked("sniper"),
		"Sniper should be locked before unlock")

	# Unlock sniper tech
	var success = tech_tree_service.unlock_tech("turret_unlock_sniper")
	assert_true(success, "Should successfully unlock sniper tech")

	# Verify sniper is now unlocked
	assert_true(tech_tree_service.is_turret_type_unlocked("sniper"),
		"Sniper should be unlocked after tech purchase")


func test_turret_unlock_techs_are_purchaseable():
	# Grant research points
	tech_tree_service.add_research_points(100)

	# Verify we can purchase turret unlock techs
	var fire_tech_id = "turret_unlock_fire"
	assert_true(tech_tree_service.can_unlock_tech(fire_tech_id),
		"Should be able to unlock fire turret with sufficient research")

	var success = tech_tree_service.unlock_tech(fire_tech_id)
	assert_true(success, "Should successfully purchase fire turret unlock")
	assert_true(tech_tree_service.is_tech_unlocked(fire_tech_id),
		"Fire unlock tech should be in unlocked list")


# =============================================================================
# UNLOCK TECH PREREQUISITES & COST
# =============================================================================

func test_cannot_unlock_without_enough_points() -> void:
	tech_tree_service.total_research_points = 0
	var can_unlock = tech_tree_service.can_unlock_tech("turret_unlock_sniper")
	assert_false(can_unlock,
		"Should not be able to unlock with 0 research points")


func test_unlock_tech_deducts_cost() -> void:
	tech_tree_service.add_research_points(200)
	var before = tech_tree_service.total_research_points

	tech_tree_service.unlock_tech("turret_unlock_sniper")

	var after = tech_tree_service.total_research_points
	assert_lt(after, before,
		"Unlocking should deduct research points")


func test_cannot_unlock_same_non_repeatable_tech_twice() -> void:
	tech_tree_service.add_research_points(200)
	tech_tree_service.unlock_tech("turret_unlock_sniper")

	# Try to unlock again
	var can_unlock = tech_tree_service.can_unlock_tech("turret_unlock_sniper")
	assert_false(can_unlock,
		"Should not be able to re-unlock a non-repeatable tech")


func test_unlock_multiple_turret_types() -> void:
	tech_tree_service.add_research_points(500)

	tech_tree_service.unlock_tech("turret_unlock_sniper")
	tech_tree_service.unlock_tech("turret_unlock_fire")

	assert_true(tech_tree_service.is_turret_type_unlocked("sniper"),
		"Sniper should be unlocked")
	assert_true(tech_tree_service.is_turret_type_unlocked("fire"),
		"Fire should be unlocked")
	assert_false(tech_tree_service.is_turret_type_unlocked("plasma"),
		"Plasma should still be locked")


# =============================================================================
# UNLOCK CHAIN - SEQUENTIAL UNLOCKING
# =============================================================================

func test_unlock_chain_preserves_previous_unlocks() -> void:
	tech_tree_service.add_research_points(500)

	tech_tree_service.unlock_tech("turret_unlock_sniper")
	tech_tree_service.unlock_tech("turret_unlock_fire")
	tech_tree_service.unlock_tech("turret_unlock_plasma")

	assert_eq(tech_tree_service.unlocked_tech_ids.size(), 3,
		"Should have 3 unlocked techs")
	assert_true(tech_tree_service.is_tech_unlocked("turret_unlock_sniper"),
		"First unlocked tech should persist")


# =============================================================================
# RESEARCH POINTS - EDGE CASES
# =============================================================================

func test_research_points_exactly_at_cost() -> void:
	# Get cost of a tech
	var tech := TechRegistry.get_tech("turret_unlock_sniper")
	var cost: int = tech.get("cost", 999)

	tech_tree_service.total_research_points = cost
	assert_true(tech_tree_service.can_unlock_tech("turret_unlock_sniper"),
		"Should be able to unlock with exact cost")


func test_research_points_one_below_cost() -> void:
	var tech := TechRegistry.get_tech("turret_unlock_sniper")
	var cost: int = tech.get("cost", 999)

	tech_tree_service.total_research_points = cost - 1
	assert_false(tech_tree_service.can_unlock_tech("turret_unlock_sniper"),
		"Should not be able to unlock with cost - 1")

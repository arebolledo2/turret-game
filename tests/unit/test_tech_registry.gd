extends GutTest

## Unit tests for TechRegistry
## Tests tech definitions, paths, and registry queries

# =============================================================================
# REGISTRY INITIALIZATION
# =============================================================================

func test_registry_has_techs():
	var all_tech_ids = TechRegistry.get_all_tech_ids()
	assert_gt(all_tech_ids.size(), 0,
		"Registry should have techs loaded")


func test_registry_has_all_six_paths():
	var all_paths = TechRegistry.get_all_paths()
	assert_eq(all_paths.size(), 6,
		"Registry should have exactly 6 tech paths")

	assert_true("turret_offense" in all_paths, "Should have turret_offense path")
	assert_true("turret_utility" in all_paths, "Should have turret_utility path")
	assert_true("turret_unlock" in all_paths, "Should have turret_unlock path")
	assert_true("player_combat" in all_paths, "Should have player_combat path")
	assert_true("player_defense" in all_paths, "Should have player_defense path")
	assert_true("economy" in all_paths, "Should have economy path")


func test_registry_count_per_path():
	var turret_offense_techs = TechRegistry.get_techs_by_path("turret_offense")
	var turret_utility_techs = TechRegistry.get_techs_by_path("turret_utility")
	var player_combat_techs = TechRegistry.get_techs_by_path("player_combat")
	var player_defense_techs = TechRegistry.get_techs_by_path("player_defense")
	var economy_techs = TechRegistry.get_techs_by_path("economy")

	assert_gt(turret_offense_techs.size(), 0, "Turret offense should have techs")
	assert_gt(turret_utility_techs.size(), 0, "Turret utility should have techs")
	assert_gt(player_combat_techs.size(), 0, "Player combat should have techs")
	assert_gt(player_defense_techs.size(), 0, "Player defense should have techs")
	assert_gt(economy_techs.size(), 0, "Economy should have techs")


# =============================================================================
# TECH DEFINITION STRUCTURE
# =============================================================================

func test_tech_has_required_fields():
	var tech = TechRegistry.get_tech("turret_damage_1")

	assert_true(tech.has("id"), "Tech should have id")
	assert_true(tech.has("name"), "Tech should have name")
	assert_true(tech.has("icon"), "Tech should have icon")
	assert_true(tech.has("description"), "Tech should have description")
	assert_true(tech.has("path"), "Tech should have path")
	assert_true(tech.has("tier"), "Tech should have tier")
	assert_true(tech.has("cost"), "Tech should have cost")
	assert_true(tech.has("prerequisites"), "Tech should have prerequisites")
	assert_true(tech.has("repeatable"), "Tech should have repeatable")
	assert_true(tech.has("max_unlocks"), "Tech should have max_unlocks")
	assert_true(tech.has("effect_type"), "Tech should have effect_type")


func test_tier1_tech_has_no_prerequisites():
	# Tier 1 techs should always be available (no prerequisites)
	var turret_damage = TechRegistry.get_tech("turret_damage_1")
	assert_eq(turret_damage.get("tier"), 1, "Should be tier 1")
	assert_eq(turret_damage.get("prerequisites", []).size(), 0,
		"Tier 1 tech should have no prerequisites")


func test_tier2_tech_has_prerequisites():
	# Tier 2+ techs should have prerequisites
	var rapid_fire = TechRegistry.get_tech("rapid_fire_1")
	assert_eq(rapid_fire.get("tier"), 2, "Should be tier 2")
	assert_gt(rapid_fire.get("prerequisites", []).size(), 0,
		"Tier 2 tech should have prerequisites")


# =============================================================================
# SPECIFIC TECH QUERIES
# =============================================================================

func test_get_tech_turret_offense_starter():
	var tech = TechRegistry.get_tech("turret_damage_1")

	assert_eq(tech.get("name"), "Enhanced Ammunition")
	assert_eq(tech.get("path"), "turret_offense")
	assert_eq(tech.get("tier"), 1)
	assert_eq(tech.get("cost"), 10)
	assert_false(tech.get("repeatable"))


func test_get_tech_economy_capstone():
	var tech = TechRegistry.get_tech("economic_supremacy")

	assert_eq(tech.get("name"), "Economic Supremacy")
	assert_eq(tech.get("path"), "economy")
	assert_eq(tech.get("tier"), 5)
	assert_eq(tech.get("cost"), 120)
	assert_gt(tech.get("prerequisites", []).size(), 1,
		"Capstone should have multiple prerequisites")


func test_get_tech_with_modifiers():
	var tech = TechRegistry.get_tech("turret_damage_1")
	var modifiers = tech.get("modifiers", [])

	assert_eq(modifiers.size(), 1, "Should have 1 modifier")

	var modifier = modifiers[0]
	assert_eq(modifier.get("stat"), "damage")
	assert_eq(modifier.get("operation"), "multiply")
	assert_eq(modifier.get("value"), 1.15)


func test_get_tech_with_unlock_mechanic():
	var tech = TechRegistry.get_tech("splash_damage")

	assert_eq(tech.get("effect_type"), "unlock_mechanic")
	assert_eq(tech.get("special_effect"), "turret_aoe_damage")
	assert_eq(tech.get("modifiers", []).size(), 1,
		"Splash Damage should define its projectile AOE modifier")
	assert_eq(tech.get("modifiers", [])[0].get("stat"), "aoe_radius")


# =============================================================================
# TECH QUERIES BY PATH
# =============================================================================

func test_get_techs_by_path_turret_offense():
	var techs = TechRegistry.get_techs_by_path("turret_offense")

	assert_gt(techs.size(), 5, "Turret offense should have multiple techs")

	# Verify all techs in this path have correct path field
	for tech in techs:
		assert_eq(tech.get("path"), "turret_offense",
			"All techs should have turret_offense path")


func test_get_techs_by_path_economy():
	var techs = TechRegistry.get_techs_by_path("economy")

	assert_gt(techs.size(), 5, "Economy should have multiple techs")

	# Verify all techs in this path have correct path field
	for tech in techs:
		assert_eq(tech.get("path"), "economy",
			"All techs should have economy path")


func test_get_techs_by_invalid_path():
	var techs = TechRegistry.get_techs_by_path("invalid_path")

	assert_eq(techs.size(), 0,
		"Invalid path should return empty array")


# =============================================================================
# TECH EXISTENCE CHECKS
# =============================================================================

func test_has_tech_returns_true_for_valid_tech():
	assert_true(TechRegistry.has_tech("turret_damage_1"),
		"Should find turret_damage_1")
	assert_true(TechRegistry.has_tech("economic_supremacy"),
		"Should find economic_supremacy")


func test_has_tech_returns_false_for_invalid_tech():
	assert_false(TechRegistry.has_tech("invalid_tech_id"),
		"Should not find invalid tech")
	assert_false(TechRegistry.has_tech(""),
		"Should not find empty tech ID")


# =============================================================================
# TECH COSTS AND TIERS
# =============================================================================

func test_tier_costs_scale_correctly():
	# Tier 1 should be cheapest, Tier 5 should be most expensive
	var tier1 = TechRegistry.get_tech("turret_damage_1")
	var tier2 = TechRegistry.get_tech("rapid_fire_1")
	var tier3 = TechRegistry.get_tech("overclocked_systems")
	var tier4 = TechRegistry.get_tech("critical_systems")
	var tier5 = TechRegistry.get_tech("ultimate_firepower")

	assert_lt(tier1.get("cost"), tier2.get("cost"), "Tier 1 < Tier 2")
	assert_lt(tier2.get("cost"), tier3.get("cost"), "Tier 2 < Tier 3")
	assert_lt(tier3.get("cost"), tier4.get("cost"), "Tier 3 < Tier 4")
	assert_lt(tier4.get("cost"), tier5.get("cost"), "Tier 4 < Tier 5")


func test_all_tier1_techs_cost_same():
	var all_techs = TechRegistry.get_all_techs()
	var tier1_cost = null

	for tech_id in all_techs.keys():
		var tech = all_techs[tech_id]
		# Skip turret_unlock techs - they're priced based on turret power level
		if tech.get("path") == "turret_unlock":
			continue
		if tech.get("tier") == 1:
			if tier1_cost == null:
				tier1_cost = tech.get("cost")
			else:
				assert_eq(tech.get("cost"), tier1_cost,
					"All tier 1 techs (excluding turret unlocks) should have same cost")


# =============================================================================
# PREREQUISITES VALIDATION
# =============================================================================

func test_prerequisites_reference_valid_techs():
	var all_techs = TechRegistry.get_all_techs()

	for tech_id in all_techs.keys():
		var tech = all_techs[tech_id]
		var prerequisites = tech.get("prerequisites", [])

		for prereq_id in prerequisites:
			assert_true(TechRegistry.has_tech(prereq_id),
				"Prerequisite '%s' for tech '%s' should exist" % [prereq_id, tech_id])


func test_capstone_techs_have_multiple_prerequisites():
	# Tier 5 capstone techs should require multiple tier 4 techs
	var all_techs = TechRegistry.get_all_techs()

	for tech_id in all_techs.keys():
		var tech = all_techs[tech_id]
		if tech.get("tier") == 5:
			var prerequisites = tech.get("prerequisites", [])
			assert_gte(prerequisites.size(), 2,
				"Tier 5 tech '%s' should have at least 2 prerequisites" % tech_id)


# =============================================================================
# EDGE CASES
# =============================================================================

func test_get_nonexistent_tech_returns_empty_dict():
	var tech = TechRegistry.get_tech("nonexistent_tech")

	assert_eq(tech.size(), 0,
		"Nonexistent tech should return empty dictionary")


func test_all_techs_have_unique_ids():
	var all_tech_ids = TechRegistry.get_all_tech_ids()
	var unique_ids = {}

	for tech_id in all_tech_ids:
		assert_false(tech_id in unique_ids,
			"Tech ID '%s' should be unique" % tech_id)
		unique_ids[tech_id] = true


func test_all_techs_have_icons():
	var all_techs = TechRegistry.get_all_techs()

	for tech_id in all_techs.keys():
		var tech = all_techs[tech_id]
		var icon = tech.get("icon", "")
		assert_false(icon.is_empty(),
			"Tech '%s' should have an icon" % tech_id)


func test_modifier_techs_have_modifiers_array():
	var all_techs = TechRegistry.get_all_techs()

	for tech_id in all_techs.keys():
		var tech = all_techs[tech_id]
		if tech.get("effect_type") == "modifier":
			var modifiers = tech.get("modifiers", [])
			assert_gt(modifiers.size(), 0,
				"Modifier tech '%s' should have at least 1 modifier" % tech_id)


func test_unlock_mechanic_techs_have_special_effect():
	var all_techs = TechRegistry.get_all_techs()

	for tech_id in all_techs.keys():
		var tech = all_techs[tech_id]
		if tech.get("effect_type") == "unlock_mechanic":
			var special_effect = tech.get("special_effect", "")
			assert_false(special_effect.is_empty(),
				"Unlock mechanic tech '%s' should have special_effect" % tech_id)

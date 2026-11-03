extends GutTest

func before_each() -> void:
	TestHelpers.reset_all_services()

func test_shares_the_turret_xp_curve() -> void:
	var growth := HeroProgression.new()
	growth.award(44)
	assert_eq(growth.level, 2)
	growth.award(1)
	assert_eq(growth.level, 3, "45 total XP is the second threshold, as for a turret")
	assert_eq(growth.xp, 0)

func test_level_one_has_identity_multipliers() -> void:
	var multipliers := HeroProgression.new().stat_multipliers()
	for key: String in ["health", "damage", "fire_rate", "range"]:
		assert_eq(float(multipliers[key]), 1.0, key)

func test_levels_raise_health_damage_and_fire_rate() -> void:
	var growth := HeroProgression.new()
	growth.award(110)
	assert_eq(growth.level, 5)
	var multipliers := growth.stat_multipliers()
	assert_almost_eq(float(multipliers.health), 1.0 + .06 * 4 + .05, .0001)
	assert_almost_eq(float(multipliers.damage), 1.0 + .05 * 4 + .05, .0001)
	assert_almost_eq(float(multipliers.fire_rate), 1.0 + .03 * 4 + .04, .0001)

func test_milestones_queue_in_order_and_gate_options() -> void:
	var growth := HeroProgression.new()
	growth.award(109)
	assert_true(growth.evolution_options().is_empty())
	var change := growth.award(1)
	assert_true(change.leveled)
	assert_eq(growth.pending_evolutions, [5])
	assert_eq(growth.evolution_options(), ["pip_arc"] as Array[String])
	assert_false(growth.evolve("pip_lancer"), "A final is not offered at level 5")
	assert_true(growth.evolve("pip_arc"))
	assert_eq(growth.evolution_form, "pip_arc")
	assert_true(growth.evolution_options().is_empty())
	growth.award(389 - 110)
	assert_eq(growth.level, 10)
	assert_eq(growth.evolution_options().size(), 2)
	assert_true(growth.evolve("pip_storm"))
	assert_eq(growth.evolution_stage, 2)

func test_form_bonuses_multiply_level_growth() -> void:
	var growth := HeroProgression.new()
	growth.award(110)
	var plain := float(growth.stat_multipliers().damage)
	growth.evolve("pip_arc")
	assert_almost_eq(float(growth.stat_multipliers().damage), plain * 1.15, .0001)

func test_player_stats_follow_level_and_form() -> void:
	PlayerStatsService.state.turret_progression_enabled = true
	var base_health := PlayerStatsService.get_player_max_health(1.0)
	var base_damage := float(PlayerStatsService.get_weapon_stats().damage)
	PlayerStatsService.state.hero_progression.award(110)
	assert_gt(PlayerStatsService.get_player_max_health(1.0), base_health)
	assert_gt(float(PlayerStatsService.get_weapon_stats().damage), base_damage)

func test_progression_off_leaves_stats_alone() -> void:
	PlayerStatsService.state.turret_progression_enabled = false
	var base_health := PlayerStatsService.get_player_max_health(1.0)
	PlayerStatsService.state.hero_progression.award(500)
	assert_eq(PlayerStatsService.get_player_max_health(1.0), base_health)

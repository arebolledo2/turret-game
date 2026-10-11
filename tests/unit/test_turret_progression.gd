extends GutTest

func before_each() -> void:
	TestHelpers.reset_all_services()

func test_first_wave_award_gives_one_or_two_levels() -> void:
	var growth := TurretProgression.new()
	growth.award(27)
	assert_eq(growth.level, 2, "Observed Hard wave-one salvage earns one level")
	assert_eq(growth.xp, 7)
	growth.award(10)
	assert_eq(growth.level, 2, "37 XP first-wave example stays at level 2")
	assert_eq(growth.xp, 17)
	growth.award(7)
	assert_eq(growth.level, 2, "44 XP is still below the second threshold")
	growth.award(1)
	assert_eq(growth.level, 3, "45 total XP earns a second level")
	assert_eq(growth.xp, 0)
	growth.award(29)
	assert_eq(growth.level, 3, "A third level requires 75 total XP")
	growth.award(1)
	assert_eq(growth.level, 4)

func test_thresholds_overflow_and_ordered_milestones() -> void:
	var growth := TurretProgression.new()
	growth.award(109)
	assert_eq(growth.level, 4)
	assert_eq(growth.xp, 34)
	assert_true(growth.pending_evolutions.is_empty())
	var change := growth.award(1)
	assert_eq(change.before.level, 4)
	assert_eq(change.after.level, 5)
	assert_eq(growth.xp, 0)
	assert_eq(growth.pending_evolutions, [5])
	growth.award(389 - 110)
	assert_eq(growth.level, 10)
	growth.award(896 - 389 + 7)
	assert_eq(growth.level, 15)
	assert_eq(growth.xp, 7)
	assert_eq(growth.total_xp, 903)
	assert_eq(growth.pending_evolutions, [5, 10, 15])
	assert_eq(change.after.pending_evolutions, [5], "Snapshots must not change with the live queue")

func test_growth_continues_beyond_mastery_without_extra_forms_or_compounding() -> void:
	var growth := TurretProgression.new()
	growth.award(896)
	assert_almost_eq(growth.damage_multiplier(), 1.40, .00001)
	for step in 35:
		growth.award(TurretProgression.cost_to_next(growth.level))
	assert_eq(growth.level, 50)
	assert_almost_eq(growth.damage_multiplier(), 2.45, .00001)
	assert_eq(growth.pending_evolutions, [5, 10, 15])
	var before := growth.snapshot()
	growth.award(-500)
	assert_eq(growth.snapshot(), before)

func test_chunking_awards_does_not_change_progression() -> void:
	var bulk := TurretProgression.new()
	var units := TurretProgression.new()
	bulk.award(2000)
	for unit in 2000:
		units.award(1)
	assert_eq(bulk.snapshot(), units.snapshot())

func test_distance_weights_are_planar_and_keep_distant_recipients_eligible() -> void:
	assert_almost_eq(WaveSalvage.weight(Vector3.ZERO, Vector3(0, 90, 0)), 1.15, .00001)
	assert_almost_eq(WaveSalvage.weight(Vector3.ZERO, Vector3(4, 0, 0)), .65, .00001)
	assert_gt(WaveSalvage.weight(Vector3.ZERO, Vector3(10000, 0, 0)), .15)

func test_scarcity_prices_count_acquisitions_and_preserve_item_prices() -> void:
	var old_item := EconomyService.calculate_item_price(20, 4)
	EconomyService.state.turret_progression_enabled = true
	assert_eq(EconomyService.calculate_turret_price(10, 1), 24)
	EconomyService.state.additional_turrets_acquired = 2
	assert_eq(EconomyService.calculate_turret_price(10, 1), 64)
	EconomyService.turrets_purchased = 20
	assert_eq(EconomyService.calculate_turret_price(10, 1), 64, "Paid counter alone does not set scarcity")
	assert_eq(EconomyService.calculate_item_price(20, 4), old_item)
	assert_eq(EconomyService.calculate_turret_price(0, 1), 1)

func test_quantity_discount_counts_paid_purchases_only() -> void:
	EconomyService.state.turret_progression_enabled = true
	EconomyService.state.additional_turrets_acquired = 2
	ItemTrackingService.item_counts["quantity_discount"] = 1
	assert_eq(EconomyService.calculate_turret_price(10, 1), 64)
	EconomyService.turrets_purchased = 2
	assert_eq(EconomyService.calculate_turret_price(10, 1), 32)

func test_older_preferences_keep_new_flag_at_its_default() -> void:
	var config := ConfigFile.new()
	config.set_value("dev_flags", "entrench", false)
	SettingsService.load_dev_flags(config)
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.TURRET_PROGRESSION))
	assert_false(FeatureFlagService.is_enabled(FeatureFlagService.ENTRENCH))

func test_purchase_penalty_items_have_linear_floor_and_keep_quadratic_growth() -> void:
	EconomyService.state.turret_progression_enabled = true
	EconomyService.state.additional_turrets_acquired = 4
	ModifierService.add_modifiers([Item.create_modifier("turret_penalty_reduction", "add", -1.0)])
	# 10 * 2 * (1 + .4*4 + .1*16) = 84; the .4 floor cannot remove the quadratic term.
	assert_eq(EconomyService.calculate_turret_price(10, 0), 84)

func test_levels_reward_distinct_stats_and_milestone_burst() -> void:
	var growth := TurretProgression.new()
	growth.level = 3
	var stats := {"damage": 100.0, "range": 100.0, "fire_rate": 2.0, "rotation_rate": 360.0}
	growth.apply_stats(stats)
	assert_almost_eq(stats.damage, 105.0, .001)
	assert_almost_eq(stats.fire_rate, 2.12, .001)
	assert_almost_eq(stats.rotation_rate, 381.6, .001)
	assert_eq(stats.range, 100.0)
	growth.level = 4
	assert_almost_eq(float(growth.stat_multipliers().range), 1.10, .001)
	growth.level = 5
	assert_almost_eq(growth.damage_multiplier(), 1.10, .001)
	assert_almost_eq(float(growth.stat_multipliers().speed), 1.10, .001)
	assert_almost_eq(float(growth.stat_multipliers().range), 1.13, .001)

extends GutTest

func test_level_5_offers_exactly_one_upgrade() -> void:
	var growth := TurretProgression.new()
	assert_eq(growth.evolution_options("normal"), [] as Array[String], "Nothing before the first milestone")
	assert_false(growth.evolve("normal", "machine_gun"))
	growth.award(110)
	assert_eq(growth.level, 5)
	assert_eq(growth.evolution_options("normal"), ["machine_gun"])
	assert_eq(growth.evolution_options("melee"), ["saber"])
	assert_false(growth.evolve("normal", "omnifire"), "A level-10 final cannot be taken at level 5")
	assert_false(growth.evolve("normal", "saber"), "Another base's upgrade is not offered")
	assert_eq(growth.evolution_stage, 0)

func test_level_10_offers_the_two_finals_and_the_choice_is_final() -> void:
	var growth := TurretProgression.new()
	growth.award(389)
	var before := growth.snapshot()
	assert_eq(growth.pending_evolutions, [5, 10])
	assert_true(growth.evolve("normal", "machine_gun"))
	assert_eq(growth.evolution_form, "machine_gun")
	assert_eq(growth.evolution_stage, 1)
	assert_eq(growth.pending_evolutions, [10])
	assert_eq(growth.evolution_options("normal"), ["cyclone_gatling", "omnifire"])
	assert_false(growth.evolve("normal", "machine_gun"), "The upgrade cannot be taken twice")
	assert_false(growth.evolve("normal", "stormblade"), "A final of another base is not offered")
	assert_true(growth.evolve("normal", "omnifire"))
	assert_eq(growth.evolution_form, "omnifire")
	assert_eq(growth.evolution_stage, 2)
	assert_true(growth.pending_evolutions.is_empty())
	assert_false(growth.evolve("normal", "cyclone_gatling"), "Only one final form per turret")
	assert_false(growth.evolve("normal", "omnifire"))
	assert_eq(growth.evolution_options("normal"), [] as Array[String])
	assert_eq(growth.level, before.level)
	assert_eq(growth.total_xp, before.total_xp)
	assert_eq(growth.xp, before.xp)
	assert_eq(TurretEvolution.form_name("omnifire"), "Omnifire")
	assert_eq(before.evolution_stage, 0, "Earlier settlement snapshots remain frozen")
	assert_eq(before.evolution_form, "")
	assert_eq(growth.snapshot().evolution_form, "omnifire")

func test_level_10_final_cannot_be_taken_before_the_level_5_upgrade() -> void:
	var growth := TurretProgression.new()
	growth.level = 10
	growth.pending_evolutions.assign([10])
	assert_eq(growth.evolution_options("normal"), [] as Array[String], "The queued level-10 milestone is not the next stage")
	assert_false(growth.evolve("normal", "cyclone_gatling"))
	assert_false(growth.evolve("normal", "machine_gun"))
	assert_eq(growth.evolution_stage, 0)
	assert_eq(growth.pending_evolutions, [10])

func test_a_single_award_crossing_both_levels_queues_both_in_order() -> void:
	var growth := TurretProgression.new()
	growth.award(389)
	assert_eq(growth.level, 10)
	assert_eq(growth.pending_evolutions, [5, 10])
	assert_eq(growth.evolution_options("bow"), ["repeater_bow"], "Only the upgrade is offered first")
	assert_false(growth.evolve("bow", "arrowstorm"))
	assert_true(growth.evolve("bow", "repeater_bow"))
	assert_eq(growth.evolution_options("bow"), ["arrowstorm", "titan_bow"])
	assert_true(growth.evolve("bow", "titan_bow"))
	assert_eq(growth.evolution_form, "titan_bow")

func test_no_third_evolution_appears_after_level_10() -> void:
	var growth := TurretProgression.new()
	growth.award(896)
	assert_true(growth.evolve("shock", "resonator"))
	assert_true(growth.evolve("shock", "thunder_spear"))
	growth.award(TurretProgression.cost_to_next(growth.level) * 12)
	assert_gt(growth.level, 15)
	assert_true(growth.pending_evolutions.is_empty())
	assert_eq(growth.evolution_options("shock"), [] as Array[String])
	assert_false(growth.evolve("shock", "resonance_engine"))

func test_every_base_has_one_upgrade_and_two_named_finals() -> void:
	assert_eq(TurretEvolution.PATHS.size(), 8)
	for base: String in TurretEvolution.PATHS:
		var upgrades := TurretEvolution.options(base, 0)
		var finals := TurretEvolution.options(base, 1)
		assert_eq(upgrades.size(), 1, "%s has one level-5 upgrade" % base)
		assert_eq(finals.size(), 2, "%s has two level-10 finals" % base)
		assert_true(TurretEvolution.options(base, 2).is_empty())
		assert_true(TurretEvolution.options(base, -1).is_empty())
		for form: String in upgrades + finals:
			assert_true(TurretEvolution.FORMS.has(form), "%s is registered in FORMS" % form)
			assert_false(TurretEvolution.form_name(form).is_empty())
			assert_false(TurretEvolution.model_key(form).is_empty())
	assert_true(TurretEvolution.options("missing", 0).is_empty())
	assert_eq(TurretEvolution.form_name("missing"), "")
	assert_eq(TurretEvolution.model_key(""), "")

func test_every_registered_form_belongs_to_one_path() -> void:
	var seen: Dictionary = {}
	for base: String in TurretEvolution.PATHS:
		for form: String in TurretEvolution.options(base, 0) + TurretEvolution.options(base, 1):
			assert_false(seen.has(form), "%s appears in two paths" % form)
			seen[form] = base
	for form: String in TurretEvolution.FORMS:
		assert_true(seen.has(form), "%s is in FORMS but no path offers it" % form)
	assert_eq(seen.size(), 24, "8 bases x (1 upgrade + 2 finals)")

func test_legacy_stage_is_one_for_upgrades_and_three_for_finals() -> void:
	for base: String in TurretEvolution.PATHS:
		for form in TurretEvolution.options(base, 0):
			assert_eq(TurretEvolution.legacy_stage(form), 1, "%s renders and behaves as the old stage 1" % form)
		for form in TurretEvolution.options(base, 1):
			assert_eq(TurretEvolution.legacy_stage(form), 3, "%s renders and behaves as the old stage 3" % form)
	assert_eq(TurretEvolution.legacy_stage(""), 0)
	assert_eq(TurretEvolution.legacy_stage("missing"), 0)

func test_implemented_forms_are_the_twenty_with_attacks_and_stats() -> void:
	assert_eq(TurretEvolution.IMPLEMENTED.size(), 20)
	for form in TurretEvolution.IMPLEMENTED:
		assert_true(TurretEvolution.FORMS.has(form), "%s is registered" % form)
		assert_false(TurretEvolution.description(form).is_empty(), "%s has a description" % form)
	for form in ["forked_coil", "storm_network", "thunderhead", "constellation"]:
		assert_true(TurretEvolution.FORMS.has(form))
		assert_false(form in TurretEvolution.IMPLEMENTED, "%s is registered but gated off until built" % form)

func test_form_stats_keep_the_authored_stage_one_and_stage_three_numbers() -> void:
	var upgrade := TurretEvolution.base_stats("normal", "machine_gun")
	var final := TurretEvolution.base_stats("normal", "cyclone_gatling")
	assert_eq(upgrade.fire_rate, 3.2)
	assert_eq(final.fire_rate, 4.8)
	assert_eq(upgrade.pierce, 0)
	assert_eq(final.pierce, 1)
	assert_eq(TurretEvolution.base_stats("normal", ""), TurretRegistry.get_base_stats("normal"), "No form leaves the base stats alone")
	assert_eq(TurretEvolution.base_stats("tesla", "storm_network"), TurretRegistry.get_base_stats("tesla"), "Unbuilt forms add no stats yet")
	assert_eq(TurretEvolution.volley_size(TurretEvolution.legacy_stage("repeater_bow")), 2)
	assert_eq(TurretEvolution.volley_size(TurretEvolution.legacy_stage("arrowstorm")), 5)

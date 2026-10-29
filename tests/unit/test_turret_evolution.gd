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
	assert_eq(TurretEvolution.form_ids().size(), TurretEvolution.bases().size() * 3, "Every base has one upgrade and two finals")
	for base: String in TurretEvolution.bases():
		var upgrades := TurretEvolution.options(base, 0)
		var finals := TurretEvolution.options(base, 1)
		assert_eq(upgrades.size(), 1, "%s has one level-5 upgrade" % base)
		assert_eq(finals.size(), 2, "%s has two level-10 finals" % base)
		assert_true(TurretEvolution.options(base, 2).is_empty())
		assert_true(TurretEvolution.options(base, -1).is_empty())
		for form: String in upgrades + finals:
			assert_true(TurretEvolution.has_form(form), "%s is registered in the form table" % form)
			assert_false(TurretEvolution.form_name(form).is_empty())
			assert_false(TurretEvolution.model_key(form).is_empty())
	assert_true(TurretEvolution.options("missing", 0).is_empty())
	assert_eq(TurretEvolution.form_name("missing"), "")
	assert_eq(TurretEvolution.model_key(""), "")

func test_every_registered_form_belongs_to_one_path() -> void:
	var seen: Dictionary = {}
	for base: String in TurretEvolution.bases():
		for form: String in TurretEvolution.options(base, 0) + TurretEvolution.options(base, 1):
			assert_false(seen.has(form), "%s appears in two paths" % form)
			seen[form] = base
	for form: String in TurretEvolution.form_ids():
		assert_true(seen.has(form), "%s is in FORMS but no path offers it" % form)
	assert_eq(seen.size(), TurretEvolution.form_ids().size(), "Every registered form is offered by exactly one path")

func test_implemented_forms_have_attack_stats_description_chassis_and_portrait() -> void:
	assert_false(TurretEvolution.implemented_forms().is_empty())
	for form in TurretEvolution.implemented_forms():
		assert_true(TurretEvolution.has_form(form), "%s is registered" % form)
		assert_false(TurretEvolution.description(form).is_empty(), "%s has a description" % form)
		var chassis := TurretEvolution.model_key(form)
		assert_true(chassis in ClockworkModels.KEYS, "%s: chassis %s is a known model key" % [form, chassis])
		assert_true(ClockworkModels.available(chassis), "%s: chassis %s has a model file the shop can show" % [form, chassis])
		var portrait := "res://assets/ui/turrets/%s.png" % ShopArt.turret_portrait_key("", form)
		assert_true(FileAccess.file_exists(portrait) and ResourceLoader.exists(portrait), "%s has an imported portrait file: %s" % [form, portrait])

func test_form_stats_keep_the_authored_upgrade_and_final_numbers() -> void:
	var upgrade := TurretEvolution.base_stats("normal", "machine_gun")
	var final := TurretEvolution.base_stats("normal", "cyclone_gatling")
	assert_eq(upgrade.fire_rate, 3.2)
	assert_eq(final.fire_rate, 4.8)
	assert_eq(upgrade.pierce, 0)
	assert_eq(final.pierce, 1)
	assert_eq(TurretEvolution.base_stats("normal", ""), TurretRegistry.get_base_stats("normal"), "No form leaves the base stats alone")
	assert_eq(TurretEvolution.base_stats("tesla", "storm_network"), TurretRegistry.get_base_stats("tesla"), "Unbuilt forms add no stats yet")
	assert_eq(TurretEvolution.volley_size("repeater_bow"), 2)
	assert_eq(TurretEvolution.volley_size("arrowstorm"), 5)

func _dps(stats: Dictionary) -> float:
	return float(stats.damage) * float(stats.fire_rate)

func test_sniper_path_forms_tiers_and_placeholder_chassis() -> void:
	assert_eq(TurretEvolution.options("sniper", 0), ["piercer_rifle"])
	assert_eq(TurretEvolution.options("sniper", 1), ["horizon_piercer", "overwatch"])
	assert_eq(TurretEvolution.form_name("piercer_rifle"), "Piercer Rifle")
	assert_eq(TurretEvolution.form_name("horizon_piercer"), "Horizon Piercer")
	assert_eq(TurretEvolution.form_name("overwatch"), "Overwatch")
	for form in ["piercer_rifle", "horizon_piercer", "overwatch"]:
		assert_true(TurretEvolution.is_implemented(form))
		assert_eq(TurretEvolution.model_key(form), "sniper", "Every Sniper form uses the cp_sniper chassis")
		assert_true(ClockworkModels.available(TurretEvolution.model_key(form)))
		assert_false(TurretEvolution.description(form).is_empty())

func test_sniper_base_stats_match_the_design() -> void:
	var base := TurretRegistry.get_base_stats("sniper")
	assert_eq(base.damage, 40.0)
	assert_eq(base.fire_rate, .35)
	assert_eq(base.range, 700.0)
	assert_eq(TurretRegistry.get_base_price("sniper"), 18)
	assert_eq(TurretRegistry.get_targeting("sniper"), "toughest")
	assert_eq(TurretRegistry.get_fire_mode("sniper"), TurretRegistry.FIRE_INSTANT)
	assert_true(TurretRegistry.has_attack_style("sniper", GameEnums.AttackStyle.INSTANT))
	assert_eq(TurretRegistry.get_damage_type("sniper"), GameEnums.DamageType.PHYSICAL)
	assert_eq(TurretRegistry.get_attack_families("sniper"), ["instant"] as Array[String])

func test_sniper_forms_climb_in_dps_and_pierce() -> void:
	var base := TurretEvolution.base_stats("sniper", "")
	var rifle := TurretEvolution.base_stats("sniper", "piercer_rifle")
	var horizon := TurretEvolution.base_stats("sniper", "horizon_piercer")
	var overwatch := TurretEvolution.base_stats("sniper", "overwatch")
	assert_gt(_dps(rifle), _dps(base), "The upgrade is a straight improvement")
	assert_gt(rifle.range, base.range)
	assert_eq(int(rifle.pierce), 2)
	assert_eq(int(overwatch.pierce), 2, "Overwatch keeps the Piercer shot")
	assert_gte(int(horizon.pierce), TurretEvolution.SNIPER_UNLIMITED_PIERCE)
	assert_between(_dps(horizon) / _dps(rifle), 1.4, 1.6, "Horizon Piercer single-target DPS is 1.4 to 1.6 times the Piercer Rifle's")
	assert_gt(_dps(overwatch), _dps(rifle), "Overwatch is above the upgrade even before its mark")
	assert_between(_dps(overwatch) * (1.0 + StatusEffects3D.MARKED_BONUS) / _dps(rifle), 1.4, 1.6, "Against its own marked target Overwatch lands in the band")

func test_pierce_text_names_none_a_count_and_the_whole_line() -> void:
	assert_eq(TurretEvolution.pierce_text(0), "none")
	assert_eq(TurretEvolution.pierce_text(2), "2")
	assert_eq(TurretEvolution.pierce_text(TurretEvolution.SNIPER_UNLIMITED_PIERCE), "whole line")

func test_quake_path_forms_tiers_and_placeholder_chassis() -> void:
	assert_eq(TurretEvolution.options("quake", 0), ["aftershock"])
	assert_eq(TurretEvolution.options("quake", 1), ["tectonic", "cataclysm"])
	assert_eq(TurretEvolution.form_name("aftershock"), "Aftershock")
	assert_eq(TurretEvolution.form_name("tectonic"), "Tectonic")
	assert_eq(TurretEvolution.form_name("cataclysm"), "Cataclysm")
	for form in ["aftershock", "tectonic", "cataclysm"]:
		assert_true(TurretEvolution.is_implemented(form))
		assert_eq(TurretEvolution.model_key(form), "quake", "Every Quake form uses the cp_quake chassis")
		assert_true(ClockworkModels.available(TurretEvolution.model_key(form)))
		assert_false(TurretEvolution.description(form).is_empty())

func test_quake_base_stats_match_the_design() -> void:
	var base := TurretRegistry.get_base_stats("quake")
	assert_eq(base.damage, 16.0)
	assert_eq(base.fire_rate, .45)
	assert_eq(base.range, 260.0)
	assert_eq(base.knockback_force, 200.0)
	assert_eq(base.stagger, .4)
	assert_eq(base.rotation_speed, 0.0, "The stomp has no aim")
	assert_eq(TurretRegistry.get_base_price("quake"), 17)
	assert_eq(TurretRegistry.get_fire_mode("quake"), TurretRegistry.FIRE_PULSE)
	assert_eq(TurretRegistry.get_damage_type("quake"), GameEnums.DamageType.PHYSICAL)
	assert_eq(TurretRegistry.get_attack_families("quake"), ["aoe", "kinetic"] as Array[String])

func test_quake_forms_hold_the_dps_ladder() -> void:
	var base := TurretEvolution.base_stats("quake", "")
	var aftershock := TurretEvolution.base_stats("quake", "aftershock")
	var tectonic := TurretEvolution.base_stats("quake", "tectonic")
	var cataclysm := TurretEvolution.base_stats("quake", "cataclysm")
	assert_gt(aftershock.damage, base.damage, "The upgrade is a straight improvement")
	assert_eq(tectonic.range, 400.0, "Tectonic reaches 4 m")
	assert_eq(tectonic.stagger, .4, "Tectonic keeps the base stagger")
	assert_eq(cataclysm.stagger, TurretEvolution.CATACLYSM_STAGGER)
	assert_gt(cataclysm.stagger, base.stagger)
	assert_gt(TurretEvolution.AFTERSHOCK_DELAY, 0.0)
	assert_eq(TurretEvolution.AFTERSHOCK_DAMAGE, .5, "The second pulse is half damage")
	assert_lte(TurretEvolution.CATACLYSM_MAX_RADIUS_SCALE, 2.0, "Cataclysm growth is capped")
	assert_gt(TurretEvolution.TECTONIC_SECONDS, 0.0)

func test_every_form_row_names_a_known_chassis_and_an_existing_base() -> void:
	for form in TurretEvolution.form_ids():
		var row := TurretEvolution.row(form)
		assert_true(TurretRegistry.TYPES.has(row["base"]), "%s: base %s is in the registry" % [form, row["base"]])
		assert_true(str(row["model"]) in ClockworkModels.KEYS, "%s: model %s is a known key" % [form, row["model"]])
		assert_false(TurretEvolution.form_name(form).is_empty())

func test_base_entries_name_registered_turrets() -> void:
	for base: String in TurretForms.BASES:
		assert_true(TurretRegistry.TYPES.has(base), "%s is in the registry" % base)

func test_forms_are_unique_to_one_base_and_listed_under_it() -> void:
	for base in TurretEvolution.bases():
		for form in TurretEvolution.options(base, 0) + TurretEvolution.options(base, 1):
			assert_eq(TurretEvolution.row(form)["base"], base, "%s is listed under the base that owns it" % form)

func test_decoy_path_forms_tiers_and_chassis() -> void:
	assert_eq(TurretEvolution.options("decoy", 0), ["bumper_post"])
	assert_eq(TurretEvolution.options("decoy", 1), ["pile_driver", "maelstrom"])
	assert_eq(TurretEvolution.form_name("bumper_post"), "Bumper Post")
	assert_eq(TurretEvolution.form_name("pile_driver"), "Pile Driver")
	assert_eq(TurretEvolution.form_name("maelstrom"), "Maelstrom")
	for form in ["bumper_post", "pile_driver", "maelstrom"]:
		assert_true(TurretEvolution.is_implemented(form))
		assert_eq(TurretEvolution.model_key(form), "decoy", "Every Decoy form uses the cp_decoy chassis")
		assert_true(ClockworkModels.available(TurretEvolution.model_key(form)))
		assert_false(TurretEvolution.description(form).is_empty())
	assert_true(TurretEvolution.behaviour_script("decoy", "").new() is DecoyForm, "The unevolved Decoy taunts through its form")

func test_decoy_base_stats_match_the_design() -> void:
	var base := TurretRegistry.get_base_stats("decoy")
	assert_eq(base.damage, 3.0)
	assert_almost_eq(float(base.fire_rate), 1.0 / 1.5, .0001)
	assert_eq(base.range, 150.0)
	assert_eq(base.knockback_force, 150.0)
	assert_eq(base.taunt_range, 450.0)
	assert_eq(TurretRegistry.get_base_price("decoy"), 10)
	assert_eq(TurretRegistry.get_fire_mode("decoy"), TurretRegistry.FIRE_PULSE)

func test_decoy_forms_climb_in_damage_reach_and_taunt() -> void:
	var base := TurretEvolution.base_stats("decoy", "")
	var bumper := TurretEvolution.base_stats("decoy", "bumper_post")
	var driver := TurretEvolution.base_stats("decoy", "pile_driver")
	var maelstrom := TurretEvolution.base_stats("decoy", "maelstrom")
	assert_gt(bumper.damage, base.damage)
	assert_gt(bumper.fire_rate, base.fire_rate)
	assert_almost_eq(float(bumper.knockback_force), float(base.knockback_force) * 1.5, .001, "Knockback x1.5")
	assert_gt(driver.range, bumper.range, "Pile Driver reaches farther")
	assert_eq(maelstrom.taunt_range, 700.0, "Maelstrom taunts out to 7 m")
	assert_eq(driver.taunt_range, 450.0)
	assert_eq(TurretEvolution.param("pile_driver", "slam_every"), 4)
	assert_eq(TurretEvolution.param("pile_driver", "slam_damage"), 3.0)
	assert_eq(TurretEvolution.param("pile_driver", "slam_radius"), 1.5)
	assert_eq(TurretEvolution.param("pile_driver", "slam_stagger"), .6)
	assert_eq(TurretEvolution.param("maelstrom", "hooks"), 10)
	assert_true(TurretEvolution.param("maelstrom", "ranged_taunt"))
	assert_null(TurretEvolution.param("bumper_post", "ranged_taunt"), "Only the Maelstrom draws ranged enemies")

func test_scrap_press_path_forms_tiers_and_placeholder_chassis() -> void:
	assert_eq(TurretEvolution.options("scrap_press", 0), ["coin_feeder"])
	assert_eq(TurretEvolution.options("scrap_press", 1), ["treasury", "academy"])
	assert_eq(TurretEvolution.form_name("coin_feeder"), "Coin Feeder")
	assert_eq(TurretEvolution.form_name("treasury"), "Treasury")
	assert_eq(TurretEvolution.form_name("academy"), "Academy")
	for form in ["coin_feeder", "treasury", "academy"]:
		assert_true(TurretEvolution.is_implemented(form))
		assert_eq(TurretEvolution.model_key(form), "shock", "Every Scrap Press form uses the brass-tinted Shock bell until a model is wired")
		assert_false(TurretEvolution.description(form).is_empty())
	assert_true(TurretEvolution.behaviour_script("scrap_press", "").new() is ScrapPressForm, "The unevolved press drops through its form")

func test_scrap_press_base_stats_match_the_design() -> void:
	var base := TurretRegistry.get_base_stats("scrap_press")
	assert_eq(base.damage, 0.0, "No attack")
	assert_almost_eq(float(base.fire_rate), .25, .0001, "One drop every 4 s")
	assert_eq(base.range, 150.0, "Drops land within 1.5 m")
	assert_eq(TurretRegistry.get_base_price("scrap_press"), 14)
	assert_eq(TurretRegistry.get_fire_mode("scrap_press"), TurretRegistry.FIRE_NONE)

func test_scrap_press_forms_change_where_drops_go_and_how_often() -> void:
	var base := TurretEvolution.base_stats("scrap_press", "")
	var feeder := TurretEvolution.base_stats("scrap_press", "coin_feeder")
	var treasury := TurretEvolution.base_stats("scrap_press", "treasury")
	var academy := TurretEvolution.base_stats("scrap_press", "academy")
	assert_eq(feeder.fire_rate, base.fire_rate, "Coin Feeder moves the drop, it does not enlarge it")
	assert_almost_eq(float(treasury.fire_rate) / float(base.fire_rate), 1.25, .0001, "Treasury makes 25% more")
	assert_almost_eq(float(academy.fire_rate) / float(base.fire_rate), .5, .0001, "Academy drops every 8 s")
	assert_eq(TurretEvolution.param("coin_feeder", "deposit_share"), .5)
	assert_eq(TurretEvolution.param("treasury", "deposit_share"), 1.0)
	assert_eq(TurretEvolution.param("treasury", "interest_per"), 10)
	assert_eq(TurretEvolution.param("treasury", "interest_cap"), 5)
	assert_eq(TurretEvolution.param("academy", "xp_radius"), 6.0)
	assert_null(TurretEvolution.param("coin_feeder", "xp_radius"))

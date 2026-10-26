extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.show_hud = false
	world.run_config = RunConfig.slice()
	add_child_autofree(world)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)

func stats(id: String) -> Dictionary:
	return TurretStatsService.get_turret_stats(id, 1.0)

func test_hybrid_or_filter_applies_once_and_separate_items_add() -> void:
	var base := float(stats("plasma")["damage"])
	ModifierService.add_modifier({"stat": "damage", "operation": "increase", "value": .1,
		"filter": {"attack_family": ["projectile", "aoe"]}})
	assert_almost_eq(float(stats("plasma")["damage"]), base * 1.1, .001)
	world.shop.apply_item("polished_barrels")
	world.shop.apply_item("plasma_doctrine")
	assert_almost_eq(float(stats("plasma")["damage"]), base * 1.4, .001)
	assert_eq(TurretRegistry.get_attack_families("shock"), ["aoe", "instant"])
	assert_false("kinetic" in TurretRegistry.get_attack_families("normal"), "Physical bullets are not contact attacks")

func test_speed_upgrades_change_firing_and_melee_sweeps() -> void:
	var normal := float(stats("normal")["fire_rate"])
	var spin := float(stats("melee")["rotation_rate"])
	world.shop.apply_item("quick_loader")
	assert_almost_eq(float(stats("normal")["fire_rate"]), normal * 1.07, .001)
	assert_almost_eq(float(stats("melee")["rotation_rate"]), spin * 1.07, .001)

func test_area_upgrade_reaches_shock_boundary_and_preserves_projectile_targeting_range() -> void:
	var shock := world.add_turret(Vector3(10, 0, 0), "shock")
	var base := TurretStats.new(stats("shock")).range_metres
	var plasma_range := TurretStats.new(stats("plasma")).range_metres
	var plasma_area := TurretStats.new(stats("plasma")).aoe_radius_metres
	world.shop.apply_item("cluster_warheads")
	world.show_ranges = true
	shock._update_range_ring()
	assert_almost_eq(shock.range_ring_metres, base * 1.2, .001)
	var target := world.spawn_enemy(shock.position + Vector3(base * 1.2, 0, 0))
	target.set_physics_process(false)
	target.health = 100
	shock.cooldown = 0
	shock._physics_process(.01)
	assert_lt(target.health, 100.0, "The expanded pulse actually hits beyond the old radius")
	assert_almost_eq(TurretStats.new(stats("plasma")).range_metres, plasma_range, .001)
	assert_almost_eq(TurretStats.new(stats("plasma")).aoe_radius_metres, plasma_area * 1.2, .001)

func test_diversity_assigns_separate_turrets_and_mastery_uses_shared_family() -> void:
	TurretStatsService.turret_counts = {"plasma": 1}
	assert_eq(TurretStatsService.get_family_diversity(), 1)
	TurretStatsService.turret_counts = {"plasma": 1, "shock": 1}
	assert_eq(TurretStatsService.get_family_diversity(), 2)
	assert_eq(TurretStatsService.shared_attack_families(), ["aoe"])
	var base := float(stats("plasma")["damage"])
	world.shop.apply_item("mono_type_mastery")
	assert_almost_eq(float(stats("plasma")["damage"]), base * 1.5, .001)
	TurretStatsService.turret_counts["melee"] = 1
	assert_almost_eq(float(stats("plasma")["damage"]), base, .001)
	world.shop.apply_item("elemental_conduit")
	assert_almost_eq(float(stats("plasma")["damage"]), base * 1.36, .001)

func test_previews_match_purchase_and_restore_all_shared_state() -> void:
	world.add_turret(Vector3(5, 0, 0), "plasma")
	world.finish_wave()
	EconomyService.total_scrap = 10000
	for id: String in ["polished_barrels", "mono_type_mastery", "elemental_conduit", "rapid_coolant", "reinforced_hull"]:
		var offer := ShopOffer.new("item", id, world.shop.item_price(id))
		var counts := ItemTrackingService.item_counts.duplicate(true)
		var turrets := TurretStatsService.turret_counts.duplicate(true)
		var modifiers := ModifierService.active_modifiers.duplicate(true)
		var money := EconomyService.total_scrap
		var rng := GameRandom.gameplay.state
		var before := ShopViewData.build_data(world)
		var preview := ShopViewData.preview(world, offer)
		assert_eq(ItemTrackingService.item_counts, counts)
		assert_eq(TurretStatsService.turret_counts, turrets)
		assert_eq(ModifierService.active_modifiers, modifiers)
		assert_eq(EconomyService.total_scrap, money)
		assert_eq(GameRandom.gameplay.state, rng)
		assert_eq(ShopViewData.build_data(world), before)
		EconomyService.current_shop_offers.assign([offer])
		assert_true(world.shop.purchase(0))
		assert_eq(ShopViewData.build_data(world), preview, id)

func test_reactor_accepts_shock_context_preserves_attribution_and_caps_depth() -> void:
	world.shop.apply_item("reactor_overload")
	var source := world.spawn_enemy(Vector3.ZERO)
	var target := world.spawn_enemy(Vector3(.5, 0, 0))
	target.health = 100
	var hit := CombatHit3D.new(50, Vector3.ZERO, Vector3.ZERO, GameEnums.DamageType.ELECTRIC)
	hit.attack_families = ["instant", "aoe"]
	hit.source_area_radius = 2.0
	hit.source_id = world.turrets[0].turret_id
	world.shop.apply_item("plasma_doctrine")
	var derived: Array[CombatHit3D] = []
	world.combat.hit_applied.connect(func(_target: Node3D, applied: CombatHit3D, _damage: float) -> void: derived.append(applied))
	world.blasts.reactor_overload(source, hit)
	assert_almost_eq(target.health, 80.0, .001, "40% damage, without another family multiplier")
	assert_eq(derived[0].source_id, hit.source_id)
	assert_eq(derived[0].attack_families, hit.attack_families)
	assert_eq(derived[0].source_area_radius, 2.0)
	hit.blast_depth = GameConstants.REACTOR_MAX_CHAIN_DEPTH
	world.blasts.reactor_overload(source, hit)
	assert_almost_eq(target.health, 80.0, .001)

func test_all_stocked_combat_filters_use_families_and_every_asset_exists() -> void:
	for id: String in ShopCatalog.ids("item"):
		assert_true(ResourceLoader.exists("res://assets/ui/items/%s.svg" % id), id)
		for modifier: Dictionary in ItemRegistry.get_modifiers(id):
			var filter: Dictionary = modifier.get("filter", {})
			assert_false(filter.has("family") or filter.has("turret_type") or filter.has("damage_type"), id)

func test_purchase_penalty_reductions_floor_at_zero_even_when_combined() -> void:
	for i in range(3):
		world.shop.apply_item("compact_design")
	for i in range(2):
		world.shop.apply_item("mass_production")
	assert_almost_eq(TurretStatsService.get_turret_purchase_penalty(), .18, .001)
	ModifierService.add_modifier({"stat": "turret_penalty_reduction", "operation": "add", "value": -.5})
	assert_eq(TurretStatsService.get_turret_purchase_penalty(), 0.0)
	EconomyService.turrets_purchased = 40
	assert_gt(world.turret_price("normal"), 0)

func test_build_readout_uses_runtime_clamps_and_effective_pulse_reach() -> void:
	world.add_turret(Vector3(5, 0, 0), "melee")
	world.add_turret(Vector3(-5, 0, 0), "shock")
	world.shop.apply_item("cluster_warheads")
	world.shop.apply_item("killzone_bat")
	world.shop.apply_item("killzone_bat")
	for row: Dictionary in ShopViewData.build_data(world)["turrets"]:
		if row["id"] == "melee":
			assert_almost_eq(float(row["stats"]["rehit_delay"]), .05, .001)
		elif row["id"] == "shock":
			var view := TurretStats.new(stats("shock"))
			assert_almost_eq(float(row["range"]), view.range_metres * view.area_size, .001)
			assert_eq(row["range"], row["area"])

func test_count_reduction_items_stack_beyond_former_floor_in_progression() -> void:
	world.session.state.turret_progression_enabled = true
	world.session.state.additional_turrets_acquired = 9
	var previous := world.turret_price("normal")
	for id in ["compact_design", "compact_design", "compact_design", "mass_production", "mass_production"]:
		world.shop.apply_item(id)
		var price := world.turret_price("normal")
		assert_lt(price, previous, "Every legal stack reduces the entire count surcharge")
		previous = price
	assert_almost_eq(TurretStatsService.get_turret_purchase_penalty(.65), .33, .001)
	world.session.state.additional_turrets_acquired = 0
	var discounted_early := world.turret_price("normal")
	ModifierService.clear_modifiers()
	assert_eq(world.turret_price("normal"), discounted_early, "No count surcharge to reduce before the first purchase")

func _register_beacon() -> void:
	var definition: Dictionary = TurretRegistry.get_type("normal").duplicate(true)
	definition["attack_styles"] = []
	definition["no_attack"] = true
	TurretRegistry.register_test_type("test_beacon", definition)

func test_no_attack_turrets_do_not_break_focused_arsenal() -> void:
	_register_beacon()
	TurretStatsService.turret_counts = {"plasma": 1, "shock": 1}
	var base := float(stats("plasma")["damage"])
	world.shop.apply_item("mono_type_mastery")
	assert_almost_eq(float(stats("plasma")["damage"]), base * 1.5, .001)
	TurretStatsService.turret_counts["test_beacon"] = 2
	assert_eq(TurretStatsService.shared_attack_families(), ["aoe"])
	assert_almost_eq(float(stats("plasma")["damage"]), base * 1.5, .001, "A utility turret beside a focused build keeps the bonus")
	TurretStatsService.turret_counts["melee"] = 1
	assert_almost_eq(float(stats("plasma")["damage"]), base, .001, "A real off-family turret still breaks it")

func test_only_no_attack_turrets_share_no_family() -> void:
	_register_beacon()
	TurretStatsService.turret_counts = {"test_beacon": 3}
	assert_true(TurretStatsService.shared_attack_families().is_empty())
	assert_eq(TurretStatsService.get_family_diversity(), 0)

func test_no_attack_turrets_do_not_count_toward_army_doctrine() -> void:
	_register_beacon()
	world.shop.apply_item("army_doctrine")
	TurretStatsService.turret_counts = {"normal": 4}
	assert_almost_eq(float(stats("normal")["attack_speed"]), 1.03, .001)
	TurretStatsService.turret_counts["test_beacon"] = 5
	assert_eq(TurretStatsService.get_total_turret_count(), 9, "The raw count still includes them")
	assert_eq(TurretStatsService.get_attack_turret_count(), 4)
	assert_almost_eq(float(stats("normal")["attack_speed"]), 1.03, .001, "Utility turrets must not inflate Army Doctrine")
	TurretStatsService.turret_counts["normal"] = 6
	assert_almost_eq(float(stats("normal")["attack_speed"]), 1.09, .001)

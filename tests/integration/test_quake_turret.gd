extends GutTest

## Quake line: stocking, the telegraphed shockwave (near enemies first, knockback and stagger), Aftershock's second pulse,
## Tectonic's crossing fissures (S7 ground zones: enemies slowed, the hero not) and Cataclysm's bounded, stacking repeats.

const GATE := "test_quake_gate"
const STEP := 1.0 / 60.0

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child_autofree(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.session.state.turret_progression_enabled = true
	for turret in world.turrets:
		turret.set_physics_process(false)
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)

func after_each() -> void:
	ShopCatalog.reset()
	TestHelpers.reset_flags()
	Input.action_release("move_right")

func _quake(form_path: Array[String] = []) -> TurretActor:
	var turret := world.add_turret(Vector3(30, 0, 30), "quake")
	turret.set_physics_process(false)
	turret.position = Vector3.ZERO
	if form_path.is_empty():
		return turret
	turret.progression.award(389 if form_path.size() > 1 else 110)
	for form in form_path:
		assert_true(turret.evolve(form), "%s evolves" % form)
	return turret

## An inert enemy (no AI, no ticking) with a fixed health.
func _enemy(at: Vector3, health: float = 1000.0, type_id: String = "basic") -> CombatActor:
	var result := world.spawn_enemy(at, type_id)
	result.set_physics_process(false)
	result.health = health
	result.max_health = health
	return result

func _combat() -> void:
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	world.crowd.rebuild(world.enemies)

## One physics step of the real turret loop.
func _step(turret: TurretActor, delta: float = STEP) -> void:
	world.crowd.rebuild(world.enemies)
	turret._physics_process(delta)

func _run(turret: TurretActor, seconds: float) -> void:
	for step in roundi(seconds / STEP):
		_step(turret)

func _lost(enemy: CombatActor, start: float = 1000.0) -> float:
	return start - enemy.health

## Records, per enemy, the turret-clock time of every hit it takes.
func _record_hits() -> Dictionary:
	var log := {"clock": 0.0, "hits": {}}
	world.combat.hit_applied.connect(func(target: Node3D, hit: CombatHit3D, applied: float) -> void:
		if hit.source_id > 0 and applied > 0.0:
			if not log.hits.has(target):
				log.hits[target] = []
			log.hits[target].append([float(log.clock), applied]))
	return log

func _run_logged(turret: TurretActor, log: Dictionary, seconds: float) -> void:
	for step in roundi(seconds / STEP):
		log.clock = float(log.clock) + STEP
		_step(turret)

# --- Shop, registry and items ---

func test_quake_is_stocked_at_its_registry_price_and_purchasable() -> void:
	assert_has(ArenaShop.TURRETS, "quake")
	assert_has(ShopCatalog.available_ids("turret"), "quake")
	assert_eq(TurretRegistry.get_base_price("quake"), 17)
	var price := world.turret_price("quake")
	assert_eq(price, EconomyService.calculate_turret_price(17, GameStateService.current_wave))
	EconomyService.total_scrap = 500
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", "quake", price)])
	assert_true(world.shop.purchase(0))
	assert_eq(TurretStatsService.turret_counts.get("quake", 0), 1)
	assert_eq(EconomyService.total_scrap, 500 - price)
	assert_gt(world.turret_price("quake"), price, "Each additional turret raises the price")
	assert_eq(ArenaShop.offer_name(ShopOffer.new("turret", "quake", 1)), "Quake Turret")
	assert_ne(ArenaShop.offer_description(ShopOffer.new("turret", "quake", 1)), "")

func test_shop_rolls_the_quake_among_the_weapons() -> void:
	world.shop.rng = RandomNumberGenerator.new()
	world.shop.rng.seed = 11
	var seen := false
	for roll in 300:
		world.shop.generate()
		for offer: ShopOffer in EconomyService.current_shop_offers:
			if offer.kind == "turret" and offer.asset_id == "quake":
				seen = true
				assert_eq(offer.price, world.turret_price("quake"))
	assert_true(seen, "300 refreshes stock the Quake at least once")

func test_flag_gating_removes_the_quake_from_stock_and_purchase() -> void:
	FeatureFlagService.register_flag(GATE, {"name": "Gate", "scope": FeatureFlagService.SCOPE_EXPERIMENT})
	ShopCatalog.entries["turret"]["quake"] = GATE
	assert_false(ShopCatalog.is_available("turret", "quake"))
	assert_false("quake" in ShopCatalog.available_ids("turret"))
	EconomyService.total_scrap = 500
	EconomyService.current_shop_offers.assign([ShopOffer.new("turret", "quake", 1)])
	assert_false(world.shop.purchase(0), "A gated turret cannot be bought")
	world.shop.rng = RandomNumberGenerator.new()
	world.shop.rng.seed = 5
	for roll in 100:
		world.shop.generate()
		for offer: ShopOffer in EconomyService.current_shop_offers:
			assert_ne(offer.asset_id, "quake")
	FeatureFlagService.set_enabled(GATE, true)
	assert_true(ShopCatalog.is_available("turret", "quake"))

func test_shop_view_data_dev_tools_and_art_know_the_quake() -> void:
	_quake()
	assert_gt(world.dev.add_turret("quake"), 0, "The dev panel adds any stocked type")
	var data := ShopViewData.build_data(world)
	var row: Dictionary = {}
	for entry: Dictionary in data.turrets:
		if entry.id == "quake":
			row = entry
	assert_false(row.is_empty())
	assert_eq(row.name, "Quake")
	assert_gt(float(data.dps), 0.0)
	assert_not_null(ShopArt.turret("quake"))
	for form in ["quake", "aftershock", "tectonic", "cataclysm"]:
		assert_true(ResourceLoader.exists("res://assets/ui/turrets/%s.png" % form), form)
	assert_not_null(UiIcons.turret("quake"))
	assert_true(UiIconData.PATHS.has("turret_quake"))

func test_registry_entry_is_kinetic_and_aoe_physical_with_the_designed_numbers() -> void:
	var base := TurretRegistry.get_base_stats("quake")
	assert_eq(base.damage, 16.0)
	assert_eq(base.fire_rate, .45)
	assert_eq(base.range, 260.0)
	assert_eq(base.knockback_force, 200.0)
	assert_eq(base.stagger, .4)
	assert_eq(float(base.rotation_speed), 0.0, "No aiming")
	assert_eq(TurretRegistry.get_damage_type("quake"), GameEnums.DamageType.PHYSICAL)
	assert_eq(TurretRegistry.get_fire_mode("quake"), TurretRegistry.FIRE_PULSE)
	assert_eq(TurretRegistry.get_attack_families("quake"), ["aoe", "kinetic"] as Array[String])
	assert_true(TurretRegistry.has_capability("quake", "knockback"))
	assert_false(TurretRegistry.is_no_attack("quake"))

func test_kinetic_and_aoe_items_reach_the_quake_and_projectile_items_do_not() -> void:
	var turret := _quake()
	var before := turret._current_view(0)
	ItemTrackingService.item_counts["whirlwind_frame"] = 1
	ModifierService.add_modifier({"stat": "range", "operation": "increase", "value": .5, "filter": {"attack_family": ["kinetic"]}})
	ModifierService.add_modifier({"stat": "slow_intensity", "operation": "add", "value": .25, "filter": {"attack_family": ["kinetic"]}})
	ModifierService.add_modifier({"stat": "slow_duration", "operation": "add", "value": .5, "filter": {"attack_family": ["kinetic"]}})
	ModifierService.add_modifier({"stat": "damage", "operation": "increase", "value": .5, "filter": {"attack_family": ["projectile"]}})
	turret.invalidate_stats()
	var after := turret._current_view(0)
	assert_almost_eq(after.range_metres, before.range_metres * 1.5, .001, "Kinetic reach grows the pulse radius")
	assert_almost_eq(after.slow_intensity, .25, .001, "Whirlwind Frame's slow rides the ring hits")
	assert_eq(after.damage, before.damage, "A projectile item does nothing")
	ModifierService.clear_modifiers()
	ModifierService.add_modifier({"stat": "area_size", "operation": "increase", "value": .2, "filter": {"attack_family": ["aoe"]}})
	turret.invalidate_stats()
	assert_almost_eq(turret.effective_range(turret._current_view(0)), 2.6 * 1.2, .001, "AoE area bonuses widen the ring")

# --- Evolution gating and hardware ---

func test_quake_milestones_offer_the_upgrade_then_both_finals() -> void:
	var turret := _quake()
	turret.progression.award(389)
	assert_eq(turret.available_evolutions(), ["aftershock"], "Level 5 offers exactly one upgrade")
	assert_false(turret.evolve("cataclysm"), "A final cannot be taken first")
	assert_true(turret.evolve("aftershock"))
	assert_eq(turret.available_evolutions(), ["tectonic", "cataclysm"], "Level 10 offers both finals")
	assert_true(turret.evolve("tectonic"))
	assert_eq(turret.display_name(), "Tectonic")
	assert_eq(turret.turret_type, "quake")
	assert_true(turret.available_evolutions().is_empty())
	assert_false(turret.evolve("cataclysm"))

func test_every_quake_stage_uses_the_quake_chassis_and_adds_its_own_hardware() -> void:
	var base := _quake()
	for part in ["Base_Stone", "Base_Legs", "Aim_Body", "Hammer_Metal"]:
		assert_not_null(base.model.find_child(part, true, false), "The cp_quake chassis has %s" % part)
	assert_null(base.model.find_child("Bell shell", true, false), "No Shock bell placeholder")
	assert_eq(TurretRegistry.get_type("quake").get("model_key"), "quake")
	for part in ["QuakeFootPlate", "AftershockPiston", "AftershockRing", "TectonicBlade", "TectonicSpike", "CataclysmRing", "CataclysmPylon"]:
		assert_null(base.model.find_child(part, true, false), "The base turret has no %s" % part)
	var upgrade := _quake(["aftershock"])
	for part in ["AftershockPiston", "AftershockCollar", "AftershockHammer", "AftershockRing"]:
		assert_not_null(upgrade.model.find_child(part, true, false), part)
	assert_null(upgrade.model.find_child("TectonicBlade", true, false))
	var tectonic := _quake(["aftershock", "tectonic"])
	for part in ["TectonicBlade", "TectonicSpike"]:
		assert_not_null(tectonic.model.find_child(part, true, false), part)
	assert_null(tectonic.model.find_child("AftershockPiston", true, false))
	assert_null(tectonic.model.find_child("CataclysmRing", true, false))
	var cataclysm := _quake(["aftershock", "cataclysm"])
	for part in ["CataclysmRing", "CataclysmPylon", "CataclysmBeacon"]:
		assert_not_null(cataclysm.model.find_child(part, true, false), part)
	assert_null(cataclysm.model.find_child("TectonicBlade", true, false))
	assert_null(cataclysm.model.find_child("AftershockPiston", true, false))
	for turret in [base, upgrade, tectonic, cataclysm]:
		assert_not_null(turret.model.find_child("Base_Stone", true, false), "Every form keeps the stone slab chassis")
		assert_not_null(turret.aim)
		assert_not_null(turret.muzzle)

func test_quake_hardware_stands_on_and_around_the_stone_slab() -> void:
	var slab := (_quake().model.find_child("Base_Stone", true, false) as MeshInstance3D).mesh.get_aabb()
	var radius := minf(slab.size.x, slab.size.z) * .5
	var top := slab.end.y
	var upgrade := _quake(["aftershock"])
	for piston in upgrade.model.find_children("AftershockPiston", "MeshInstance3D", true, false):
		var at := (piston as Node3D).position
		assert_lt(Vector2(at.x, at.z).length(), radius, "A piston stands on the slab")
		assert_gt(at.y, top, "A piston rises from the slab top, not from inside it")
	var ring := upgrade.model.find_child("AftershockRing", true, false) as Node3D
	assert_gt(ring.position.y, top, "The damper ring lies on top of the slab")
	var tectonic := _quake(["aftershock", "tectonic"])
	for blade in tectonic.model.find_children("TectonicBlade", "MeshInstance3D", true, false):
		var at := (blade as Node3D).position
		assert_gt(Vector2(at.x, at.z).length(), radius, "Fissure cracks run out of the slab, not through the legs")
	var cataclysm := _quake(["aftershock", "cataclysm"])
	for ripple in cataclysm.model.find_children("CataclysmRing", "MeshInstance3D", true, false):
		assert_gt(((ripple as MeshInstance3D).mesh as TorusMesh).inner_radius, radius, "Ripple rings circle the slab")

# --- Base pulse ---

func test_the_quake_only_fires_with_an_enemy_in_range() -> void:
	var turret := _quake()
	_combat()
	_enemy(Vector3(0, 0, -6))
	_run(turret, 1.0)
	assert_eq(turret.cooldown, 0.0, "Nothing in range: no pulse is spent")
	assert_false(turret.form.busy())
	assert_eq(turret.form.pulses_released, 0)
	_enemy(Vector3(0, 0, -2))
	_step(turret)
	assert_true(turret.form.busy(), "An enemy in range starts the telegraph")
	assert_almost_eq(turret.cooldown, 1.0 / .45, .03, "Rate 0.45 per second counted from the trigger")

func test_the_pulse_telegraphs_for_half_a_second_before_anything_is_hit() -> void:
	var turret := _quake()
	_combat()
	var target := _enemy(Vector3(0, 0, -1.2))
	_step(turret)
	var circle: MeshInstance3D = turret.form.telegraph_circle
	assert_not_null(circle)
	assert_true(circle.visible, "A ground warning shows the whole reach")
	assert_almost_eq(circle.scale.x, 2.0 * 2.6, .001, "Its footprint is the pulse's reach")
	_run(turret, .4)
	assert_eq(target.health, 1000.0, "Nothing lands during the warning")
	assert_true(circle.visible)
	var material := circle.material_override as ShaderMaterial
	assert_between(float(material.get_shader_parameter("progress")), .7, 1.0, "The gauge fills as the warning elapses")
	_run(turret, .35)
	assert_false(circle.visible, "The warning ends when the ring is released")
	assert_lt(target.health, 1000.0)

func test_the_ring_reaches_near_enemies_before_far_ones_at_eight_metres_per_second() -> void:
	var turret := _quake()
	_combat()
	var near := _enemy(Vector3(0, 0, -.9))
	var far := _enemy(Vector3(2.3, 0, 0))
	var log := _record_hits()
	_run_logged(turret, log, 1.2)
	var near_at: float = log.hits[near][0][0]
	var far_at: float = log.hits[far][0][0]
	assert_gt(near_at, .49, "Not before the warning is over")
	assert_lt(near_at, far_at, "The nearer enemy is hit first")
	assert_almost_eq(far_at - near_at, (2.3 - .9) / TurretEvolution.QUAKE_RING_SPEED, 2.5 * STEP, "The gap is the distance at the ring's speed")
	assert_eq(log.hits[near].size(), 1, "Each enemy is struck once by a ring")
	assert_eq(log.hits[far].size(), 1)

func test_enemies_outside_the_radius_are_untouched_and_hits_are_attributed_kinetic_aoe_physical() -> void:
	var turret := _quake()
	_combat()
	var inside := _enemy(Vector3(0, 0, -2.4))
	var outside := _enemy(Vector3(0, 0, -3.6))
	var seen: Array[CombatHit3D] = []
	world.combat.hit_applied.connect(func(_t: Node3D, hit: CombatHit3D, _a: float) -> void: seen.append(hit))
	_run(turret, 1.2)
	assert_eq(outside.health, 1000.0)
	assert_almost_eq(_lost(inside), 16.0, .001, "The full pulse damage")
	assert_eq(seen.size(), 1)
	assert_eq(seen[0].attack_families, ["aoe", "kinetic"] as Array[String])
	assert_eq(seen[0].damage_type, GameEnums.DamageType.PHYSICAL)
	assert_eq(seen[0].source_id, turret.turret_id)
	assert_almost_eq(seen[0].source_area_radius, 2.6, .001, "Area items read the pulse radius")
	assert_eq(seen[0].stagger_duration, .4)

func test_the_ring_shoves_enemies_away_from_the_turret_and_staggers_them() -> void:
	var turret := _quake()
	_combat()
	var east := _enemy(Vector3(1.5, 0, 0))
	var north := _enemy(Vector3(0, 0, -1.5))
	_run(turret, .9)
	assert_gt(east.knockback_velocity.x, 1.0, "Pushed east, away from the turret")
	assert_almost_eq(east.knockback_velocity.z, 0.0, .05)
	assert_lt(north.knockback_velocity.z, -1.0, "Pushed north")
	assert_almost_eq(east.knockback_velocity.length(), 2.0, .1, "Knockback 200 is 2 m/s of impulse for a body of mass 1")
	assert_true(east.statuses.is_staggered())
	assert_true(north.statuses.is_staggered())
	assert_lte(east.statuses.staggered_remaining, .4)

func test_a_critical_pulse_crits_the_whole_ring_once() -> void:
	var turret := _quake()
	_combat()
	var a := _enemy(Vector3(0, 0, -1.0))
	var b := _enemy(Vector3(1.0, 0, 0))
	_run(turret, .9)
	assert_almost_eq(_lost(a), _lost(b), .001, "One roll per pulse, shared by every enemy it reaches")

func test_nothing_fires_after_combat_stops_a_pause_or_the_wave_end() -> void:
	var turret := _quake()
	_combat()
	var target := _enemy(Vector3(0, 0, -2.0))
	_run(turret, .3)
	assert_true(turret.form.busy())
	world.toggle_pause()
	_step(turret)
	assert_false(turret.form.busy(), "Pause drops the queued pulse")
	assert_true(turret.form.beats.is_empty())
	assert_false(turret.form.telegraph_circle.visible)
	world.toggle_pause()
	turret.cooldown = 0.0
	_run(turret, .3)
	assert_eq(target.health, 1000.0, "Nothing carried over from before the pause")
	assert_true(turret.form.busy(), "A fresh telegraph starts")
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	_step(turret)
	assert_false(turret.form.busy(), "Wave end drops it too")
	assert_true(turret.form.rings.is_empty())

# --- Stagger on enemies ---

func test_a_staggered_enemy_cannot_move_or_hurt_the_hero() -> void:
	var turret := _quake()
	_combat()
	var chaser := world.spawn_enemy(Vector3(0, 0, -6), "basic")
	chaser.health = 1000.0
	var control := world.spawn_enemy(Vector3(6, 0, 0), "basic")
	control.health = 1000.0
	world.player.position = Vector3(0, 0, 6)
	chaser.statuses.stagger(.4)
	var start := chaser.position
	var control_start := control.position
	for step in 12:
		chaser._physics_process(STEP)
		control._physics_process(STEP)
	assert_almost_eq(chaser.position.distance_to(start), 0.0, .001, "Staggered: it stands still")
	assert_gt(control.position.distance_to(control_start), .1, "An unstaggered enemy chases")
	chaser.statuses.advance_stagger(1.0)
	for step in 12:
		chaser._physics_process(STEP)
	assert_gt(chaser.position.distance_to(start), .05, "It chases again when the stagger ends")
	# Contact damage is a staggered enemy's only attack on the hero.
	var biter := world.spawn_enemy(world.player.position + Vector3(.2, 0, 0), "basic")
	biter.statuses.stagger(1.0)
	var hull := world.player.health
	world.player.invulnerability = 0.0
	biter._physics_process(STEP)
	assert_eq(world.player.health, hull, "No touch damage while staggered")
	biter.statuses.advance_stagger(2.0)
	biter._physics_process(STEP)
	assert_lt(world.player.health, hull, "It bites again afterwards")

func test_stagger_interrupts_a_charger_dash_and_a_hopper_pounce() -> void:
	var turret := _quake()
	_combat()
	world.player.position = Vector3(0, 0, -1.0)
	var charger := world.spawn_enemy(Vector3(0, 0, -2.5), "charger")
	charger.set_physics_process(false)
	charger._physics_process(STEP)
	assert_eq(charger.charge.phase, ChargeController3D.Phase.WINDUP, "The charger is winding up")
	charger.health = 1000.0
	var hopper := world.spawn_enemy(Vector3(1.0, 0, -1.0), "hopper")
	hopper.set_physics_process(false)
	hopper.health = 1000.0
	for step in 3:
		hopper._physics_process(STEP)
	assert_eq(hopper.brain.pounce.phase, ChargeController3D.Phase.WINDUP, "The hopper is winding up its pounce")
	var shot := CombatShot3D.new()
	shot.damage = 1.0
	shot.stagger_duration = .4
	for victim in [charger, hopper]:
		world.combat.apply_hit(victim, world.combat.hit_from_shot(victim, Vector3(0, 0, 0), Vector3(0, 0, -1), shot))
	charger._physics_process(STEP)
	hopper._physics_process(STEP) # the stagger cuts the action short on the very next tick
	assert_eq(charger.charge.phase, ChargeController3D.Phase.RECOVER, "Interrupted")
	assert_false(charger.warning.visible)
	assert_eq(hopper.brain.pounce.phase, ChargeController3D.Phase.RECOVER)
	assert_true(charger.statuses.is_staggered())
	assert_true(hopper.statuses.is_staggered())
	for step in 10:
		charger._physics_process(STEP)
		hopper._physics_process(STEP)
	assert_ne(charger.charge.phase, ChargeController3D.Phase.DASH)
	assert_ne(hopper.brain.pounce.phase, ChargeController3D.Phase.DASH)
	assert_false(world.warning_actors.has(charger), "No stale warning slot is held")
	assert_false(world.warning_actors.has(hopper))

func test_stagger_cancels_a_wound_up_ranged_shot() -> void:
	_combat()
	var kite := world.spawn_enemy(Vector3(0, 0, -4), "kite")
	kite.set_physics_process(false)
	kite.health = 1000.0
	kite.brain.state = EnemyBrain.State.WARNING
	kite.brain.clock = .5
	assert_true(world.warning_actors.has(kite))
	var shot := CombatShot3D.new()
	shot.damage = 1.0
	shot.stagger_duration = .4
	world.combat.apply_hit(kite, world.combat.hit_from_shot(kite, Vector3.ZERO, Vector3(0, 0, -1), shot))
	kite._tick_statuses(STEP)
	assert_ne(kite.brain.state, EnemyBrain.State.WARNING, "The shot is called off")
	assert_false(world.warning_actors.has(kite))
	assert_gte(kite.brain.clock, EnemyBrain.STAGGER_REARM, "It waits before winding up again")

func test_bosses_resist_stagger_and_are_shoved_less() -> void:
	_combat()
	var boss := world.spawn_enemy(Vector3(1.5, 0, 0), "brass_ram")
	boss.set_physics_process(false)
	boss.health = 100000.0
	var grunt := world.spawn_enemy(Vector3(-1.5, 0, 0), "basic")
	grunt.set_physics_process(false)
	grunt.health = 1000.0
	var shot := CombatShot3D.new()
	shot.damage = 1.0
	shot.knockback = 2.0
	shot.stagger_duration = .4
	for victim in [boss, grunt]:
		world.combat.apply_hit(victim, world.combat.hit_from_shot(victim, Vector3.ZERO, Vector3(0, 0, -1), shot))
	assert_false(boss.statuses.is_staggered(), "Bosses are never staggered")
	assert_true(grunt.statuses.is_staggered())
	assert_lt(boss.knockback_velocity.length(), grunt.knockback_velocity.length() * .1, "Knockback is divided by mass, so a boss barely moves")

# --- Aftershock ---

func test_aftershock_pulses_again_after_six_tenths_of_a_second_at_half_damage() -> void:
	var turret := _quake(["aftershock"])
	_combat()
	var target := _enemy(Vector3(0, 0, -1.2))
	var log := _record_hits()
	_run_logged(turret, log, 1.6)
	var hits: Array = log.hits[target]
	assert_eq(hits.size(), 2, "Two pulses")
	var damage := turret._current_view(0).damage
	assert_almost_eq(float(hits[0][1]), damage, .001)
	assert_almost_eq(float(hits[1][1]), damage * .5, .001, "The second pulse is half damage")
	assert_almost_eq(float(hits[1][0]) - float(hits[0][0]), TurretEvolution.AFTERSHOCK_DELAY, 2.0 * STEP, "Released 0.6 s after the first")
	assert_eq(turret.form.pulses_released, 2)

func test_aftershock_second_pulse_has_the_same_radius_and_the_whole_cycle_follows_the_rate() -> void:
	var turret := _quake(["aftershock"])
	_combat()
	var edge := _enemy(Vector3(0, 0, -2.9), 1000.0)
	var out := _enemy(Vector3(0, 0, -4.0), 1000.0)
	_run(turret, 1.6)
	assert_almost_eq(_lost(edge), turret._current_view(0).damage * 1.5, .001, "Both pulses reach the same edge")
	assert_eq(out.health, 1000.0, "The second pulse is no wider")
	assert_almost_eq(turret.cooldown, turret._current_view(0).cooldown_seconds - 1.6, .1, "The cooldown counts from the trigger, not from the second pulse")

func test_aftershock_is_a_straight_improvement_over_the_base_pulse() -> void:
	var base := _quake()
	var upgrade := _quake(["aftershock"])
	assert_gt(upgrade._current_view(0).damage, base._current_view(0).damage)
	assert_gte(upgrade._current_view(0).range_metres, base._current_view(0).range_metres)
	assert_gte(upgrade._current_view(0).knockback_metres, base._current_view(0).knockback_metres)

# --- Tectonic ---

func _cluster_field() -> Dictionary:
	var cluster: Array[CombatActor] = []
	for offset in [Vector2(0, 0), Vector2(.5, .2), Vector2(-.4, .3), Vector2(.2, -.5), Vector2(-.3, -.4)]:
		cluster.append(_enemy(Vector3(2.4 + offset.x, 0, -1.0 + offset.y)))
	return {"cluster": cluster, "lone": _enemy(Vector3(-2.5, 0, 2.0)), "far": _enemy(Vector3(2.4, 0, -6.0))}

func test_tectonic_aims_its_x_at_the_densest_cluster() -> void:
	var turret := _quake(["aftershock", "tectonic"])
	_combat()
	var field := _cluster_field()
	_step(turret)
	assert_true(turret.form.busy())
	assert_eq(turret.form.fissures.size(), 1)
	var focus: Vector3 = turret.form.fissures[0].focus
	assert_lt(focus.distance_to(Vector3(2.4, 0, -1.0)), 1.0, "The X is centred on the cluster, not the nearest enemy or the lone one")
	for line in turret.form.telegraph_lines:
		assert_true(line.visible, "Both fissures are telegraphed")
	assert_eq(turret.form.telegraph_lines.size(), 2)
	_run(turret, .45)
	assert_eq(world.ground_zones.count(), 0, "Nothing opens during the warning")
	assert_eq(field.lone.health, 1000.0)

func test_tectonic_opens_two_crossing_fissures_that_hit_what_stands_in_them_once() -> void:
	var turret := _quake(["aftershock", "tectonic"])
	_combat()
	var field := _cluster_field()
	var log := _record_hits()
	_run_logged(turret, log, .7)
	assert_eq(world.ground_zones.count(), 2)
	var a := world.ground_zones.zones[0]
	var b := world.ground_zones.zones[1]
	assert_eq(a.shape, GroundZone.Shape.LINE)
	assert_lt(a.centre.distance_to(b.centre), .001, "Both fissures are centred on the same point: an X")
	assert_almost_eq(absf(a.direction.dot(b.direction)), 0.0, .001, "Perpendicular")
	var reach := turret.effective_range(turret._current_view(0))
	assert_almost_eq(a.half_length, reach * TurretEvolution.TECTONIC_REACH, .001)
	assert_almost_eq(a.half_width, TurretEvolution.TECTONIC_HALF_WIDTH, .001)
	assert_almost_eq(a.duration, 3.0, .001)
	assert_almost_eq(a.slow, .4, .001)
	assert_eq(a.source_id, turret.turret_id)
	var damage := turret._current_view(0).damage
	var struck := 0
	for enemy in field.cluster:
		if world.ground_zones.covering(enemy.position, enemy.hurtbox_radius()).size() > 0:
			struck += 1
			assert_eq(log.hits[enemy].size(), 1, "Hit once even when it stands in both fissures")
			assert_almost_eq(float(log.hits[enemy][0][1]), damage, .001)
			assert_true(enemy.statuses.is_staggered())
		else:
			assert_false(log.hits.has(enemy), "Outside both fissures: untouched")
	assert_gte(struck, 3, "Most of a tight cluster is caught by the X")
	assert_false(log.hits.has(field.lone), "Outside the X")
	assert_false(log.hits.has(field.far))
	assert_eq(turret.form.rings.size(), 0, "Tectonic replaces the radial pulse")

func test_tectonic_fissures_slow_enemies_inside_and_leave_after_three_seconds() -> void:
	var turret := _quake(["aftershock", "tectonic"])
	_combat()
	var inside := _enemy(Vector3(2.4, 0, -1.0))
	_run(turret, .6)
	assert_eq(world.ground_zones.count(), 2)
	assert_true(inside.statuses.is_staggered())
	assert_almost_eq(world.ground_zones.speed_factor_at(inside.position, inside.hurtbox_radius()), .6, .001)
	# The real enemy step reads it: compare the commanded speed with and without the rift.
	inside.statuses.advance_stagger(5.0)
	world.player.position = Vector3(2.4, 0, 12.0)
	inside.knockback_velocity = Vector3.ZERO
	inside._steer(STEP)
	var slowed_speed := inside.velocity.length()
	assert_true(inside.slow_marker.visible, "The slow ring shows on a slowed enemy")
	world.ground_zones.clear()
	inside._steer(STEP)
	var free_speed := inside.velocity.length()
	assert_gt(free_speed, 0.0)
	assert_almost_eq(slowed_speed / free_speed, .6, .02, "40% slower inside the rift")
	assert_false(inside.slow_marker.visible)

func test_tectonic_rift_ends_on_time() -> void:
	var turret := _quake(["aftershock", "tectonic"])
	_combat()
	_enemy(Vector3(2.4, 0, -1.0))
	_run(turret, .6)
	assert_eq(world.ground_zones.count(), 2)
	world.ground_zones.tick(2.9)
	assert_eq(world.ground_zones.count(), 2, "Still open just before three seconds")
	world.ground_zones.tick(.2)
	assert_eq(world.ground_zones.count(), 0)

func test_zones_slow_enemies_only_never_the_hero() -> void:
	world.ground_zones.add_circle(world.player.position, 3.0, 5.0, .6)
	_combat()
	Input.action_press("move_right")
	world.camera.global_transform = Transform3D(Basis.IDENTITY, Vector3(0, 10, 10))
	var hero_with := Vector3.ZERO
	for step in 30:
		world.player._steer(STEP)
		hero_with = world.player.velocity
	world.ground_zones.clear()
	world.player.velocity = Vector3.ZERO
	var hero_without := Vector3.ZERO
	for step in 30:
		world.player._steer(STEP)
		hero_without = world.player.velocity
	assert_gt(hero_without.length(), 0.0)
	assert_eq(hero_with, hero_without, "The hero moves exactly as fast with a zone under it")
	var grunt := world.spawn_enemy(world.player.position + Vector3(1, 0, 0), "basic")
	grunt.set_physics_process(false)
	world.ground_zones.add_circle(grunt.position, 3.0, 5.0, .6)
	grunt._steer(STEP)
	var slowed := grunt.velocity.length()
	world.ground_zones.clear()
	grunt._steer(STEP)
	assert_almost_eq(slowed / grunt.velocity.length(), .4, .02, "The same zone slows the enemy by 60%")

func test_a_zone_slow_and_a_status_slow_do_not_multiply() -> void:
	var enemy := world.spawn_enemy(Vector3(0, 0, -3), "basic")
	enemy.set_physics_process(false)
	world.player.position = Vector3(0, 0, 20)
	_combat()
	enemy._steer(STEP)
	var free := enemy.velocity.length()
	world.ground_zones.add_circle(enemy.position, 2.0, 5.0, .4)
	enemy._steer(STEP)
	assert_almost_eq(enemy.velocity.length() / free, .6, .02)
	var slow := CombatHit3D.new(0.0)
	slow.slow_intensity = .5
	slow.slow_duration = 2.0
	enemy.statuses.apply(slow)
	enemy._steer(STEP)
	assert_almost_eq(enemy.velocity.length() / free, .5, .02, "The stronger of the two (0.5), not 0.6 x 0.5")
	var weak := CombatHit3D.new(0.0)
	weak.slow_intensity = .3
	weak.slow_duration = 2.0
	enemy.statuses.clear()
	enemy.statuses.apply(weak)
	enemy._steer(STEP)
	assert_almost_eq(enemy.velocity.length() / free, .6, .02, "The zone's 0.4 beats a status 0.3")

func test_ground_zones_end_with_the_wave_a_pause_and_a_new_run() -> void:
	world.ground_zones.add_circle(Vector3.ZERO, 2.0, 5.0, .4)
	world.ground_zones.add_line(Vector3.ZERO, Vector3(3, 0, 0), .5, 5.0, .4)
	_combat()
	world.ground_zones._physics_process(.1)
	assert_eq(world.ground_zones.count(), 2, "Combat keeps them")
	world.toggle_pause()
	world.ground_zones._physics_process(.1)
	assert_eq(world.ground_zones.count(), 0, "Pause drops them")
	world.toggle_pause()
	world.ground_zones.add_circle(Vector3.ZERO, 2.0, 5.0, .4)
	world.clear_field(false)
	assert_eq(world.ground_zones.count(), 0, "Wave end clears the field")
	world.ground_zones.add_circle(Vector3.ZERO, 2.0, 5.0, .4)
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	world.ground_zones._physics_process(.1)
	assert_eq(world.ground_zones.count(), 0, "Leaving combat drops them")
	world.ground_zones.add_circle(Vector3.ZERO, 2.0, 5.0, .4)
	world.start_run()
	assert_eq(world.ground_zones.count(), 0, "A new run starts clean")
	for node in world.ground_zones.nodes:
		assert_false(node.visible)

func test_tectonic_fissures_stay_within_the_zone_cap() -> void:
	var turrets: Array[TurretActor] = []
	for index in 8:
		var turret := _quake(["aftershock", "tectonic"])
		turret.position = Vector3(index * 40, 0, 0)
		turrets.append(turret)
	_combat()
	for turret in turrets:
		_enemy(turret.position + Vector3(2.4, 0, -1.0))
	for step in roundi(8.0 / STEP):
		for turret in turrets:
			_step(turret)
		world.ground_zones.tick(STEP)
		assert_lte(world.ground_zones.count(), GameConstants.GROUND_ZONE_MAX)
	assert_lte(world.ground_zones.nodes.size(), GameConstants.GROUND_ZONE_MAX)

func test_tectonic_does_nothing_without_an_enemy_in_range() -> void:
	var turret := _quake(["aftershock", "tectonic"])
	_combat()
	var reach := turret.effective_range(turret._current_view(0))
	assert_almost_eq(reach, 4.0 * turret.progression.stat_multipliers().range, .001, "Range 400, grown by the level bonus")
	_enemy(Vector3(0, 0, -(reach + 3.0)))
	_run(turret, 1.0)
	assert_false(turret.form.busy())
	assert_eq(world.ground_zones.count(), 0)
	assert_eq(turret.cooldown, 0.0)

# --- Cataclysm ---

func test_cataclysm_repeats_every_nine_tenths_of_a_second_each_ring_wider() -> void:
	var turret := _quake(["aftershock", "cataclysm"])
	_combat()
	var base := turret.effective_range(turret._current_view(0))
	# Enemies on a line, each just inside a different ring (a ring touches a body 0.36 m before its centre).
	var by_distance: Array[CombatActor] = []
	for share in [.5, 1.1, 1.3, 1.5]:
		by_distance.append(_enemy(Vector3(0, 0, -(base * share + .36))))
	var log := _record_hits()
	_run_logged(turret, log, 4.0)
	assert_eq(turret.form.pulses_released, 4, "The first pulse and three repeats")
	var times: Array = []
	for hit in log.hits[by_distance[0]]:
		times.append(hit[0])
	assert_eq(times.size(), 4, "The nearest enemy is struck by every pulse")
	for index in range(1, 4):
		assert_almost_eq(float(times[index]) - float(times[index - 1]), TurretEvolution.CATACLYSM_INTERVAL, 2.0 * STEP)
	assert_eq(log.hits[by_distance[1]].size(), 3, "1.1 times the reach is past the first ring but inside the next three")
	assert_eq(log.hits[by_distance[2]].size(), 2, "1.3 times needs the third ring (1.4)")
	assert_eq(log.hits[by_distance[3]].size(), 1, "1.5 times only the last (1.6)")

func test_cataclysm_is_bounded_in_repeats_growth_and_rings() -> void:
	var turret := _quake(["aftershock", "cataclysm"])
	_combat()
	var enemies: Array[CombatActor] = []
	for index in 6:
		enemies.append(_enemy(Vector3(cos(index) * 1.5, 0, sin(index) * 1.5)))
	var peak_rings := 0
	var widest := 0.0
	var reach := turret.effective_range(turret._current_view(0))
	for step in roundi(30.0 / STEP):
		_step(turret)
		peak_rings = maxi(peak_rings, turret.form.rings.size())
		for ring in turret.form.rings:
			widest = maxf(widest, ring.max_radius)
	assert_lte(peak_rings, 4, "Never more than a salvo's worth of rings")
	assert_gt(turret.form.pulses_released, 8, "It keeps salvoing while enemies stay")
	# A salvo is 4 pulses over 3.2 s, then the recharge: that many salvos fit in 30 s at most.
	var cycle := TurretEvolution.QUAKE_TELEGRAPH_SECONDS + TurretEvolution.CATACLYSM_INTERVAL * TurretEvolution.CATACLYSM_REPEATS + turret._current_view(0).cooldown_seconds
	assert_lte(turret.form.pulses_released, ceili(30.0 / cycle) * 4, "Bounded by the salvo size and the recharge")
	assert_almost_eq(widest, reach * TurretEvolution.CATACLYSM_MAX_RADIUS_SCALE, .001, "Growth stops at the cap")

func test_cataclysm_stops_repeating_when_no_enemy_is_left_in_range() -> void:
	var turret := _quake(["aftershock", "cataclysm"])
	_combat()
	var only := _enemy(Vector3(0, 0, -1.5))
	_run(turret, .7)
	assert_eq(turret.form.pulses_released, 1)
	only.dead = true
	world.enemies.erase(only)
	world.crowd.rebuild(world.enemies)
	_run(turret, .8)
	assert_eq(turret.form.pulses_released, 1, "No enemy in range: the repeats are cancelled")
	assert_true(turret.form.beats.is_empty())
	assert_false(turret.form.salvo_open)
	assert_gt(turret.cooldown, 0.0, "The recharge starts when the salvo is called off")
	assert_lt(turret.cooldown, turret._current_view(0).cooldown_seconds, "...a moment before this check")

func test_cataclysm_stagger_stacks_up_to_the_cap() -> void:
	var turret := _quake(["aftershock", "cataclysm"])
	_combat()
	var target := _enemy(Vector3(0, 0, -1.5))
	var peaks: Array[float] = []
	var last_hits := 0
	var log := _record_hits()
	for step in roundi(3.4 / STEP):
		log.clock = float(log.clock) + STEP
		_step(turret)
		target.statuses.advance_stagger(STEP)
		var hits: int = log.hits.get(target, []).size()
		if hits != last_hits:
			peaks.append(target.statuses.staggered_remaining)
			last_hits = hits
	assert_eq(peaks.size(), 4)
	var per_hit := turret._current_view(0).stagger_seconds
	assert_gt(per_hit, TurretEvolution.CATACLYSM_INTERVAL, "A hit must outlast the gap to the next pulse for stacking to matter")
	assert_almost_eq(peaks[0], per_hit, .03)
	for index in range(1, 4):
		assert_gt(peaks[index], peaks[index - 1], "Each pulse adds to the time left")
		assert_lte(peaks[index], StatusEffects3D.STAGGER_CAP + .0001)
	var capped := _enemy(Vector3(30, 0, 30))
	for hit in 10:
		capped.statuses.extend_stagger(per_hit, StatusEffects3D.STAGGER_CAP)
	assert_almost_eq(capped.statuses.staggered_remaining, StatusEffects3D.STAGGER_CAP, .0001)

func test_cataclysm_hits_do_not_stack_on_a_boss() -> void:
	var turret := _quake(["aftershock", "cataclysm"])
	_combat()
	var boss := _enemy(Vector3(0, 0, -1.5), 100000.0, "brass_ram")
	_run(turret, 1.8)
	assert_lt(boss.health, 100000.0, "Bosses still take the damage")
	assert_false(boss.statuses.is_staggered())

# --- Finals against the upgrade ---

func test_finals_are_above_the_upgrade_in_a_cluster_and_tectonic_is_stronger_in_control() -> void:
	var upgrade := TurretEvolution.base_stats("quake", "aftershock")
	var tectonic := TurretEvolution.base_stats("quake", "tectonic")
	var cataclysm := TurretEvolution.base_stats("quake", "cataclysm")
	assert_gt(float(tectonic.damage) * float(tectonic.fire_rate), float(upgrade.damage) * float(upgrade.fire_rate) * 1.5, "Tectonic's single-target rate is high: it spends its damage in a narrow X")
	assert_gt(float(cataclysm.stagger), TurretEvolution.CATACLYSM_INTERVAL)
	assert_gt(float(tectonic.range), float(upgrade.range), "Range 400")
	for form in ["aftershock", "tectonic", "cataclysm"]:
		assert_true(form in TurretEvolution.IMPLEMENTED)
		assert_eq(TurretEvolution.model_key(form), "quake")
		assert_true(ClockworkModels.available("quake"))
		assert_false(TurretEvolution.description(form).is_empty())
		assert_eq(TurretEvolution.quake_pattern_text(form).is_empty(), false)

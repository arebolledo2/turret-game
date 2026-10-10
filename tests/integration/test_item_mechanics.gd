extends GutTest

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
	world.turrets[0].set_physics_process(false)
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)

func after_each() -> void:
	ModifierService.clear_modifiers()

func own(item_id: String) -> void:
	world.shop.apply_item(item_id)

func enemy(at: Vector3, health: float = 100.0) -> CombatActor:
	var actor := world.spawn_enemy(at)
	actor.set_physics_process(false)
	actor.max_health = health
	actor.health = health
	return actor

func plasma_kill_hit(damage: float) -> CombatHit3D:
	var hit := CombatHit3D.new(damage, Vector3.ZERO, Vector3.ZERO, GameEnums.DamageType.PLASMA)
	hit.attack_families = ["projectile", "aoe"]
	hit.source_area_radius = TurretStats.new(TurretStatsService.get_turret_stats("plasma", 1.0)).aoe_radius_metres
	return hit

func test_reactor_overload_detonates_and_chains() -> void:
	own("reactor_overload")
	var first := enemy(Vector3.ZERO, 5.0)
	var second := enemy(Vector3(.5, 0, 0), 10.0)
	var third := enemy(Vector3(1.0, 0, 0), 100.0)
	var far := enemy(Vector3(8, 0, 0), 100.0)
	world.combat.apply_hit(first, plasma_kill_hit(50.0))
	assert_true(second.dead, "20 blast damage kills the neighbour")
	assert_lt(third.health, 100.0, "the neighbour's own blast chains onward")
	assert_eq(far.health, 100.0)

func test_reactor_overload_ignores_other_damage_and_missing_item() -> void:
	var a := enemy(Vector3.ZERO, 5.0)
	var b := enemy(Vector3(.5, 0, 0), 100.0)
	world.combat.apply_hit(a, plasma_kill_hit(50.0))
	assert_eq(b.health, 100.0, "no item, no blast")
	own("reactor_overload")
	var c := enemy(Vector3(3, 0, 0), 5.0)
	var d := enemy(Vector3(3.5, 0, 0), 100.0)
	world.combat.apply_hit(c, CombatHit3D.new(50.0, Vector3.ZERO))
	assert_eq(d.health, 100.0, "only eligible AoE kills detonate")

func test_last_stand_needs_low_hull() -> void:
	own("last_stand")
	var turret := world.turrets[0]
	var base := float(TurretStatsService.get_turret_stats("normal", 1.0)["fire_rate"])
	world.player.health = world.player.max_health
	turret.invalidate_stats()
	assert_almost_eq(float(turret._current_stats(0.0)["fire_rate"]), base, .001)
	world.player.health = world.player.max_health * .2
	turret.invalidate_stats()
	assert_almost_eq(float(turret._current_stats(0.0)["fire_rate"]), base * 1.4, .001)

func test_storm_conductor_links_nearby_electric_turrets() -> void:
	own("storm_conductor")
	var shock := world.add_turret(Vector3(5, 0, 5), "shock")
	var base := float(TurretStatsService.get_turret_stats("shock", 1.0)["damage"])
	assert_almost_eq(float(shock._current_stats(0.0)["damage"]), base, .001, "alone")
	var tesla := world.add_turret(Vector3(7, 0, 5), "tesla")
	shock.invalidate_stats()
	assert_almost_eq(float(shock._current_stats(0.0)["damage"]), base * 1.35, .001)
	var far := world.add_turret(Vector3(-8, 0, -5), "shock")
	assert_almost_eq(float(far._current_stats(0.0)["damage"]), base, .001, "out of range")
	assert_not_null(tesla)

func test_economy_multipliers_reach_the_world() -> void:
	own("quality_over_quantity")
	assert_almost_eq(ItemTrackingService.get_enemy_count_multiplier(), .7, .001)
	var before := EconomyService.total_scrap
	for index in range(20):
		world.collect_scrap(1)
	assert_eq(EconomyService.total_scrap - before, 40, "+100% scrap")

func test_killzone_bat_hits_sooner_and_whirlwind_slows() -> void:
	own("whirlwind_frame")
	var bat := world.add_turret(Vector3(4, 0, 4), "melee")
	var stats := bat._current_stats(0.0)
	assert_almost_eq(float(stats["slow_intensity"]), .25, .001)
	assert_almost_eq(float(stats["rotation_rate"]), 720.0, .001)

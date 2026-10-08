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
	world.pickup_root.process_mode = Node.PROCESS_MODE_DISABLED
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)

func enemy(at: Vector3, type_id: String = "basic") -> CombatActor:
	var actor := world.spawn_enemy(at, type_id)
	actor.set_physics_process(false)
	actor.health = 100
	actor.max_health = 100
	return actor

func plasma() -> CombatShot3D:
	return CombatShot3D.from_stats(TurretStatsService.get_turret_stats("plasma", 1.0), GameEnums.DamageType.PLASMA)

func test_splash_damages_primary_once_and_respects_planar_boundary() -> void:
	var center := enemy(Vector3.ZERO)
	var edge := enemy(Vector3(1, 3, 0))
	var outside := enemy(Vector3(1.01, 0, 0))
	watch_signals(world.combat)
	var hits := world.combat.impact(center, Vector3.ZERO, Vector3.RIGHT, plasma(), world.enemies)
	assert_eq(hits, 2)
	assert_eq(center.health, 90.0)
	assert_eq(edge.health, 90.0)
	assert_eq(outside.health, 100.0)
	assert_signal_emit_count(world.combat, "hit_applied", 2)
	assert_signal_emit_count(world.combat, "explosion", 1)
	assert_gt(center.knockback_velocity.x, 0.0, "Center uses projectile heading as push direction")
	assert_eq(edge.knockback_velocity.y, 0.0)

func test_splash_kills_do_not_skip_targets_when_live_list_changes() -> void:
	var first := enemy(Vector3.ZERO)
	var second := enemy(Vector3(.2, 0, 0))
	var third := enemy(Vector3(.4, 0, 0))
	for actor in [first, second, third]:
		actor.health = 1
	watch_signals(world.combat)
	assert_eq(world.combat.impact(first, Vector3.ZERO, Vector3.RIGHT, plasma(), world.enemies), 3)
	assert_eq(world.enemies.size(), 0)
	assert_eq(GameStateService.total_kills, 3)
	assert_eq(world.pickup_root.get_child_count(), 3)
	assert_signal_emit_count(world.combat, "actor_defeated", 3)

func test_fast_plasma_projectile_hits_splash_and_reuses_as_plain_shot() -> void:
	var primary := enemy(Vector3(2, 0, 0))
	var neighbor := enemy(Vector3(2, 0, .8))
	await wait_physics_frames(2)
	var spec := plasma()
	spec.speed = 100
	var shot := world.fire_shot(Vector3(0, .65, 0), primary, spec)
	spec.damage = 999
	shot.advance(.04)
	assert_eq(primary.health, 90.0, "Shot snapshots its firing values")
	assert_eq(neighbor.health, 90.0)
	assert_false(shot.active)
	assert_null(shot.shot)
	var reused := world.fire(Vector3(0, .65, 0), primary, 1, 100)
	assert_same(reused, shot)
	assert_eq(reused.shot.splash_radius, 0.0)
	assert_eq(reused.shot.knockback, 0.0)
	assert_eq(reused.shot.damage_type, GameEnums.DamageType.PHYSICAL)
	reused.advance(.04)
	assert_eq(primary.health, 89.0)
	assert_eq(neighbor.health, 90.0, "Normal shot must not retain plasma splash")

func test_cluster_targeting_prefers_group_then_nearest_tie() -> void:
	var lone := enemy(Vector3(.5, 0, 0))
	var cluster := enemy(Vector3(2, 0, 0))
	enemy(Vector3(2.4, 0, 0))
	assert_same(world.combat.select_target(Vector3.ZERO, 3, world.enemies), lone)
	assert_same(world.combat.select_target(Vector3.ZERO, 3, world.enemies, .6), cluster)
	assert_same(world.combat.select_target(Vector3.ZERO, 1, world.enemies, .6), lone)
	world.crowd.rebuild(world.enemies)
	assert_same(world.combat.select_target(Vector3.ZERO, 3, world.enemies, .6, world.crowd), cluster)
	assert_eq(world.crowd.count_near(cluster, .6), 2)
	lone.position = Vector3(2.2, 0, 0)
	world.crowd.rebuild(world.enemies)
	assert_eq(world.crowd.count_near(cluster, .6), 3, "Rebuild invalidates cached cluster counts")

func test_charge_warns_then_dashes_on_locked_heading_and_recovers() -> void:
	var charge := ChargeController3D.new()
	charge.configure(EnemyRegistry.TYPES["charger"]["behavior_params"])
	assert_eq(charge.advance(.1, Vector3.ZERO, Vector3.RIGHT, .6), Vector3.ZERO)
	assert_eq(charge.phase, ChargeController3D.Phase.WINDUP)
	assert_eq(charge.advance(.5, Vector3.ZERO, Vector3.FORWARD, .6), Vector3.ZERO)
	assert_eq(charge.phase, ChargeController3D.Phase.WINDUP)
	charge.advance(.41, Vector3.ZERO, Vector3.FORWARD, .6)
	assert_eq(charge.phase, ChargeController3D.Phase.DASH)
	var velocity := charge.advance(.2, Vector3.ZERO, Vector3.FORWARD, .6)
	assert_almost_eq(velocity.x, 1.8, .001)
	assert_eq(velocity.z, 0.0, "Dodge after warning must not retarget")
	charge.advance(1.4, Vector3.ZERO, Vector3.RIGHT, .6)
	assert_eq(charge.phase, ChargeController3D.Phase.RECOVER)
	charge.advance(2.6, Vector3.ZERO, Vector3.RIGHT, .6)
	assert_eq(charge.phase, ChargeController3D.Phase.APPROACH)

func test_knockback_interrupts_windup_and_dash_with_mass_and_speed_cap() -> void:
	var charger := enemy(Vector3.ZERO, "charger")
	for phase in [ChargeController3D.Phase.WINDUP, ChargeController3D.Phase.DASH]:
		charger.charge.phase = phase
		charger.warning.visible = true
		charger.knockback_velocity = Vector3.ZERO
		world.combat.apply_hit(charger, CombatHit3D.new(1, Vector3.LEFT, Vector3(3, 10, 0)))
		assert_eq(charger.charge.phase, ChargeController3D.Phase.RECOVER)
		assert_false(charger.warning.visible)
		assert_almost_eq(charger.knockback_velocity.x, 2.0, .001)
		assert_eq(charger.knockback_velocity.y, 0.0)
	world.combat.apply_hit(charger, CombatHit3D.new(1, Vector3.LEFT, Vector3(100, 0, 0)))
	assert_almost_eq(charger.knockback_velocity.length(), 9.0, .001)

func test_charge_contact_sweeps_the_whole_dash_segment() -> void:
	world.player.position = Vector3.ZERO
	var charger := enemy(Vector3(-1, 0, 0), "charger")
	charger.charge.phase = ChargeController3D.Phase.DASH
	charger.charge.heading = Vector3.RIGHT
	charger.charge.remaining = 1
	charger.speed = 60
	await wait_physics_frames(2)
	charger.set_physics_process(true)
	await wait_physics_frames(2)
	charger.set_physics_process(false)
	assert_gt(charger.position.x, .5, "Fixture must cross beyond the player's contact radius")
	assert_lt(world.player.health, world.player.max_health, "A dash crossing the player must not tunnel")

func test_stationary_last_warning_frame_does_not_cancel_dash() -> void:
	var charger := enemy(Vector3.ZERO, "charger")
	charger._physics_process(.01)
	assert_eq(charger.charge.phase, ChargeController3D.Phase.WINDUP)
	charger._physics_process(charger.charge.windup_duration + .01)
	assert_eq(charger.charge.phase, ChargeController3D.Phase.DASH)
	assert_true(charger.warning.visible)
	var before := charger.position
	charger.set_physics_process(true)
	await wait_physics_frames(2)
	charger.set_physics_process(false)
	assert_gt(charger.position.distance_to(before), 0.0)
	assert_eq(charger.charge.phase, ChargeController3D.Phase.DASH)

func test_pause_freezes_charge_knockback_and_effect_lifetime() -> void:
	var charger := enemy(Vector3.ZERO, "charger")
	charger._physics_process(.01)
	var phase := charger.charge.phase
	var remaining := charger.charge.remaining
	charger.knockback_velocity = Vector3.RIGHT
	world.effects.show_explosion(Vector3.ZERO, 1)
	world.toggle_pause()
	charger._physics_process(1)
	world.effects._physics_process(1)
	assert_eq(charger.charge.phase, phase)
	assert_eq(charger.charge.remaining, remaining)
	assert_eq(charger.knockback_velocity, Vector3.RIGHT)
	assert_eq(world.effects.ages[0], 0.0)
	assert_eq(world.combat.apply_hit(charger, CombatHit3D.new(10)), 0.0)

func test_death_wave_end_and_restart_remove_warnings_effects_and_crowd_entries() -> void:
	var charger := enemy(Vector3.ZERO, "charger")
	charger._physics_process(.01)
	assert_true(charger.warning.visible)
	world.effects.show_explosion(Vector3.ZERO, 1)
	world.crowd.rebuild(world.enemies)
	world.player.take_damage(100)
	assert_false(charger.warning.visible)
	assert_false(world.effects.pulses[0].visible)
	world.start_run()
	assert_eq(world.crowd.positions.size(), 0)
	assert_eq(world.enemies.size(), 0)
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	charger = enemy(Vector3.ZERO, "charger")
	charger._physics_process(.01)
	world.effects.show_explosion(Vector3.ZERO, 1)
	world.finish_wave()
	assert_false(charger.warning.visible)
	assert_false(world.effects.pulses[0].visible)

func test_crowd_separates_coincident_spawns_and_queries_neighbor_cells() -> void:
	var first := enemy(Vector3.ZERO)
	var second := enemy(Vector3.ZERO)
	world.crowd.rebuild(world.enemies)
	var push := world.crowd.separation(first)
	assert_gt(push.length(), 0.0)
	assert_eq(push, -world.crowd.separation(second))
	first.position = Vector3(.95, 0, 0)
	second.position = Vector3(1.05, 0, 0)
	world.crowd.rebuild(world.enemies)
	assert_lt(world.crowd.separation(first).x, 0.0)
	assert_gt(world.crowd.separation(second).x, 0.0)
	second.position = Vector3(4, 0, 0)
	world.crowd.rebuild(world.enemies)
	assert_eq(world.crowd.separation(first), Vector3.ZERO)

func test_plasma_purchase_counts_and_damage_upgrade_use_shared_services() -> void:
	world.finish_wave()
	EconomyService.total_scrap = 100
	var price := world.turret_price("plasma")
	assert_true(buy("turret", "plasma"))
	assert_eq(EconomyService.total_scrap, 100 - price)
	assert_eq(TurretStatsService.turret_counts["normal"], 1)
	assert_eq(TurretStatsService.turret_counts["plasma"], 1)
	assert_true(buy("item", "dense_rounds"))
	assert_almost_eq(float(TurretStatsService.get_turret_stats("plasma", 1.0)["damage"]), 10.7, .001)
	assert_eq(world.turret_price("plasma"), EconomyService.calculate_turret_price(16, 1))
	world.start_run()
	assert_false(TurretStatsService.turret_counts.has("plasma"))

func test_registry_scaling_and_charger_wave_gate_are_authoritative() -> void:
	GameStateService.current_wave = 3
	var charger := world.spawn_enemy(Vector3.ZERO, "charger")
	charger.set_physics_process(false)
	var expected := EnemyRegistry.get_stats_for_wave("charger", 3, world.difficulty_config)
	assert_almost_eq(charger.health, float(expected["health"]), .001)
	assert_almost_eq(charger.speed, float(expected["speed"]) * .01, .001)
	world.waves.spawned_this_wave = 0
	world.waves.spawn_clock = 0
	world.waves.remaining_spawns = 1
	world._physics_process(.01)
	assert_eq(world.enemies.back().enemy_type, "charger")
	world.start_run()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	world.waves.spawn_clock = 0
	world._physics_process(.01)
	assert_eq(world.enemies.back().enemy_type, "basic")

func test_new_asset_pivots_and_effect_pool_are_bounded() -> void:
	var turret := world.add_turret(Vector3(3, 0, 0), "plasma")
	assert_not_null(turret.aim)
	assert_not_null(turret.muzzle)
	assert_lt(turret.muzzle.global_position.z, turret.position.z)
	assert_not_null(world.player.weapon_muzzle)
	var charger := enemy(Vector3.ZERO, "charger")
	for leg in charger.legs:
		assert_not_null(leg)
	for index in range(50):
		world.effects.show_explosion(Vector3.ZERO, 1)
	assert_eq(world.effects.pulses.size(), CombatEffects3D.MAX_PULSES)
	world.effects._physics_process(.31)
	world.effects.show_explosion(Vector3.ZERO, 2)
	assert_eq(world.effects.pulses.size(), CombatEffects3D.MAX_PULSES)
	assert_true(world.effects.pulses[0].visible)

func buy(kind: String, id: String) -> bool:
	var price := world.turret_price(id) if kind == "turret" else world.shop.item_price(id)
	EconomyService.current_shop_offers.append(ShopOffer.new(kind, id, price))
	return world.shop.purchase(EconomyService.current_shop_offers.size() - 1)

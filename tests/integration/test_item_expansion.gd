extends GutTest
var world: ArenaWorld
func before_each() -> void:
	TestHelpers.reset_all_services()
	TestHelpers.reset_flags()
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	world.run_config = RunConfig.slice()
	world.run_config.mode = RunConfig.MODE_CORE
	add_child_autofree(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	for turret in world.turrets:
		turret.set_physics_process(false)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)

func enemy(at: Vector3 = Vector3(10, 0, 0)) -> CombatActor:
	var actor := world.spawn_enemy(at)
	actor.set_physics_process(false)
	actor.health = 100
	actor.max_health = 100
	return actor

func hit(family: String, damage: float = 10.0, source: int = 0) -> CombatHit3D:
	var result := CombatHit3D.new(damage)
	result.attack_families.assign([family])
	result.source_id = source
	return result

func test_projectile_opening_and_travel_bonuses_are_once_and_do_not_affect_ticks() -> void:
	world.shop.apply_item("opening_salvo")
	world.shop.apply_item("slipstream_fletching")
	var target := enemy()
	var shot := hit("projectile")
	shot.travel_distance = 2.0
	assert_almost_eq(world.combat.apply_hit(target, shot), 15.0, .001)
	assert_almost_eq(world.combat.apply_hit(target, shot), 12.0, .001)
	assert_almost_eq(shot.damage, 10.0, .001, "Reusable hit is not compounded")
	shot.is_dot = true
	assert_almost_eq(world.combat.apply_hit(target, shot), 10.0, .001)
	assert_almost_eq(world.combat.apply_hit(enemy(), hit("instant")), 10.0, .001)

func test_missed_projectile_returns_once_and_pool_resets() -> void:
	world.shop.apply_item("return_address")
	var spec := CombatShot3D.new()
	spec.damage = 10
	spec.speed = 2
	spec.lifetime = .5
	spec.attack_families.assign(["projectile"])
	var projectile := world.fire_direction(Vector3(10, .4, 10), Vector3.RIGHT, spec)
	projectile.set_physics_process(false)
	projectile.advance(.5)
	assert_true(projectile.returning)
	assert_almost_eq(projectile.shot.damage, 5.0, .001)
	assert_eq(projectile.direction, Vector3.LEFT)
	projectile.advance(.5)
	assert_false(projectile.active, "A return never returns again")
	projectile.acquire_shot(Vector3(10, .4, 10), Vector3.RIGHT, spec)
	assert_false(projectile.returning)
	projectile.has_hit = true
	projectile.advance(.5)
	assert_false(projectile.active, "A shot which hit cannot return")

func test_chain_insurance_only_increases_last_hit_and_caps_unused_jumps() -> void:
	world.shop.apply_item("arc_insurance")
	var a := enemy(Vector3(8, 0, 0))
	var b := enemy(Vector3(9, 0, 0))
	var shot := CombatShot3D.new()
	shot.damage = 10
	shot.attack_families.assign(["instant"])
	world.combat.chain(Vector3.ZERO, a, shot, 5, 2.0, .5, world.enemies)
	assert_almost_eq(a.health, 90.0, .001)
	assert_almost_eq(b.health, 93.8, .001, "Five damage plus capped 24%")

func test_cinder_transfer_preserves_source_and_cannot_spread_again() -> void:
	world.shop.apply_item("cinder_reserve")
	var a := enemy(Vector3(8, 0, 0))
	var b := enemy(Vector3(9, 0, 0))
	var c := enemy(Vector3(10, 0, 0))
	var burn := hit("aoe", 1, 17)
	burn.burn_dps = 8
	burn.burn_duration = 3
	a.statuses.apply(burn)
	world.combat.apply_hit(a, hit("projectile", 200))
	assert_eq(b.statuses.burn_dps, 8.0)
	assert_eq(b.statuses.burn_remaining, 1.0)
	assert_eq(b.statuses.burn_source_id, 17)
	assert_true(b.statuses.burn_transferred)
	world.combat.apply_hit(b, hit("kinetic", 200))
	assert_eq(c.statuses.burn_remaining, 0.0)

func test_follow_through_requires_three_distinct_hits_and_caps_at_five() -> void:
	world.shop.apply_item("follow_through")
	var attack := hit("kinetic", 1, 1)
	var target := enemy()
	for i in 4:
		world.combat.apply_hit(target, attack)
	assert_eq(world.item_effects.stacks(1, "follow_through"), 0)
	world.combat.apply_hit(enemy(), attack)
	world.combat.apply_hit(enemy(), attack)
	assert_eq(world.item_effects.stacks(1, "follow_through"), 1)
	world.combat.apply_hit(enemy(), attack)
	assert_eq(world.item_effects.stacks(1, "follow_through"), 1, "One proc per swing/shot")
	for i in 7:
		var next := hit("kinetic", 1, 1)
		for j in 3:
			world.combat.apply_hit(enemy(), next)
	assert_eq(world.item_effects.stacks(1, "follow_through"), 5)
	var stats := {"damage": 10.0, "range": 100.0, "rotation_rate": 360.0}
	world.item_effects.modify_stats(stats, 1, true)
	assert_eq(stats.rotation_rate, 540.0)
	world.paused = true
	world.item_effects.tick(4)
	assert_eq(world.item_effects.stacks(1, "follow_through"), 5)
	world.paused = false
	world.item_effects.tick(2.1)
	assert_eq(world.item_effects.stacks(1, "follow_through"), 0)

func test_victory_lap_and_counterweight_use_kinetic_source() -> void:
	world.shop.apply_item("counterweight")
	world.shop.apply_item("victory_lap")
	var heavy := enemy()
	heavy.mass = 3.0
	assert_almost_eq(world.combat.apply_hit(heavy, hit("kinetic")), 12.0, .001)
	assert_almost_eq(world.combat.apply_hit(heavy, hit("projectile")), 10.0, .001)
	for i in 7:
		world.combat.apply_hit(enemy(), hit("kinetic", 200, 1))
	assert_eq(world.item_effects.stacks(1, "victory_lap"), 5)
	var stats := {"range": 100.0}
	world.item_effects.modify_stats(stats, 1, true)
	assert_eq(stats.range, 150.0)
	assert_eq(world.item_effects.stacks(0, "victory_lap"), 0)

func test_rescue_beacon_nearby_cooldown_and_expiry() -> void:
	world.shop.apply_item("rescue_beacon")
	var near := world.turrets[0]
	near.position = world.player.position + Vector3(1, 0, 0)
	var far := world.add_turret(world.player.position + Vector3(8, 0, 0))
	far.set_physics_process(false)
	world.combat.apply_hit(world.player, hit("", 1))
	assert_eq(world.item_effects.stacks(near.turret_id, "rescue_beacon"), 1)
	assert_eq(world.item_effects.stacks(far.turret_id, "rescue_beacon"), 0)
	assert_eq(world.item_effects.stacks(0, "rescue_beacon"), 1)
	world.item_effects.tick(2.1)
	world.player.invulnerability = 0
	world.combat.apply_hit(world.player, hit("", 1))
	assert_eq(world.item_effects.stacks(0, "rescue_beacon"), 0, "Cooldown blocks refresh")

func test_battery_heals_once_per_wave_and_is_not_in_survival_pool() -> void:
	world.shop.apply_item("reserve_battery")
	world.core.health = world.core.max_health * .31
	world.damage_core(world.core.max_health * .02)
	assert_eq(world.core.health, world.core.max_health)
	world.core.health = world.core.max_health * .31
	world.damage_core(world.core.max_health * .02)
	assert_lt(world.core.health, world.core.max_health * .3)
	GameStateService.current_wave += 1
	world.damage_core(1)
	assert_eq(world.core.health, world.core.max_health)
	var saved := world.core
	world.core = null
	assert_has(world.shop.unavailable_item_ids(), "reserve_battery")
	world.core = saved

func test_partnership_affects_all_nearby_deployed_turrets_but_hero_once() -> void:
	world.shop.apply_item("close_partnership")
	world.turrets[0].position = world.player.position + Vector3(1, 0, 0)
	var second := world.add_turret(world.player.position + Vector3(-1, 0, 0))
	second.set_physics_process(false)
	for source in [0, world.turrets[0].turret_id, second.turret_id]:
		var stats := {"damage": 10.0}
		world.item_effects.modify_stats(stats, source, false)
		assert_almost_eq(stats.damage, 10.8, .001)
		assert_eq(world.item_effects.visible_buffs(source)[0].id, "close_partnership")
	second.carried = true
	assert_false(world.item_effects.partnered(second.turret_id))
	world.turrets[0].position = Vector3(20, 0, 0)
	assert_false(world.item_effects.partnered(0))
	world.item_effects.grant(0, "rescue_beacon")
	world.item_effects.clear_wave()
	assert_true(world.item_effects.visible_buffs(0).is_empty())

func test_returning_shot_can_hit_and_actual_travel_qualifies_slipstream() -> void:
	world.shop.apply_item("return_address")
	world.shop.apply_item("slipstream_fletching")
	var spec := CombatShot3D.new()
	spec.damage = 10
	spec.speed = 4
	spec.lifetime = 1.0
	spec.attack_families.assign(["projectile"])
	var projectile := world.fire_direction(Vector3(8, .4, 8), Vector3.RIGHT, spec)
	projectile.set_physics_process(false)
	projectile.advance(1.0)
	assert_true(projectile.returning)
	var target := enemy(Vector3(10, 0, 8))
	await get_tree().physics_frame
	projectile.advance(1.0)
	assert_almost_eq(target.health, 94.0, .001, "50% return damage with long-flight +20%")
	assert_false(projectile.active)

func test_hero_partnership_changes_fired_shot_without_mutating_cached_base() -> void:
	world.shop.apply_item("close_partnership")
	world.turrets[0].position = world.player.position + Vector3(1, 0, 0)
	var base := PlayerStatsService.get_weapon_stats(world.run_config.hero).duplicate(true)
	enemy(world.player.position + Vector3(0, 0, -1))
	world.player.weapon_clock = 0
	world.player._tick_player_weapon(.01)
	assert_almost_eq(world.projectiles[-1].shot.damage, float(base.damage) * 1.08, .001)
	assert_eq(PlayerStatsService.get_weapon_stats(world.run_config.hero), base)

func test_battery_does_not_resurrect_after_lethal_damage() -> void:
	world.shop.apply_item("reserve_battery")
	world.core.health = 1
	world.damage_core(2)
	assert_true(world.core.dead)
	assert_eq(world.core.health, 0.0)

func test_conditional_item_previews_restore_inventory() -> void:
	world.turrets[0].position = world.player.position + Vector3(1, 0, 0)
	var before := ItemTrackingService.item_counts.duplicate(true)
	var data := ShopViewData.build_data(world)
	var preview := ShopViewData.preview(world, ShopOffer.new("item", "close_partnership", 18))
	assert_gt(float(preview.hero_weapon.damage), float(data.hero_weapon.damage))
	assert_eq(ItemTrackingService.item_counts, before)
	assert_eq(ShopViewData.build_data(world), data)

func test_proximity_items_switch_with_layout_and_never_buff_hero() -> void:
	var turret := world.turrets[0]
	turret.position = Vector3.ZERO
	var base := turret.resolve_attack_stats()
	world.shop.apply_item("lone_sentry")
	world.shop.apply_item("crosslink_array")
	var isolated := turret.resolve_attack_stats()
	assert_almost_eq(float(isolated.damage), float(base.damage) * 1.2, .001)
	assert_almost_eq(float(isolated.fire_rate), float(base.fire_rate) * 1.2, .001)
	assert_eq(world.item_effects.visible_buffs(turret.turret_id)[0].id, "lone_sentry")
	var reach := turret.effective_range(TurretStats.new(base))
	var neighbour := world.add_turret(Vector3(reach, 0, 0), "melee")
	neighbour.set_physics_process(false)
	var linked := turret.resolve_attack_stats()
	assert_almost_eq(float(linked.damage), float(base.damage) * 1.05, .001, "Range boundary includes centre; never counts itself")
	assert_almost_eq(float(linked.fire_rate), float(base.fire_rate) * 1.05, .001)
	assert_eq(world.item_effects.visible_buffs(turret.turret_id)[0].id, "crosslink_array")
	neighbour.position.x = reach + .01
	assert_almost_eq(float(turret.resolve_attack_stats().damage), float(base.damage) * 1.2, .001)
	world.shop.apply_item("extended_barrel")
	assert_almost_eq(float(turret.resolve_attack_stats().damage), float(base.damage) * 1.05, .001, "Range items extend the neighbour check")
	neighbour.carried = true
	assert_almost_eq(float(turret.resolve_attack_stats().damage), float(base.damage) * 1.2, .001)
	turret.carried = true
	assert_almost_eq(float(turret.resolve_attack_stats().damage), float(base.damage), .001)
	var hero := {"damage": 10.0, "fire_rate": 2.0}
	world.item_effects.modify_stats(hero, 0, false)
	assert_eq(hero.damage, 10.0)
	assert_eq(hero.fire_rate, 2.0)

func test_crosslink_counts_each_neighbour_and_boosts_melee_rotation() -> void:
	var melee := world.add_turret(Vector3.ZERO, "melee")
	melee.set_physics_process(false)
	world.turrets[0].position = Vector3(.2, 0, 0)
	for at in [Vector3(-.2, 0, 0), Vector3(0, 0, .3)]:
		var turret := world.add_turret(at)
		turret.set_physics_process(false)
	var base := melee.resolve_attack_stats()
	world.shop.apply_item("crosslink_array")
	var linked := melee.resolve_attack_stats()
	assert_almost_eq(float(linked.damage), float(base.damage) * 1.15, .001)
	assert_almost_eq(float(linked.rotation_rate), float(base.rotation_rate) * 1.15, .001)
	assert_eq(world.item_effects.visible_buffs(melee.turret_id)[0].stacks, 3)

func test_proximity_items_are_uncommon_single_copy_and_stocked() -> void:
	for id in ["lone_sentry", "crosslink_array"]:
		assert_eq(ItemRegistry.get_item(id).rarity, GameEnums.ItemRarity.UNCOMMON)
		assert_eq(ItemRegistry.get_max_stacks(id), 1)
		assert_true(ShopCatalog.is_available("item", id))
		assert_false(ItemRegistry.is_at_max_stacks(id, {}))
		world.shop.apply_item(id)
		assert_true(ItemRegistry.is_at_max_stacks(id, ItemTrackingService.item_counts))
		var counts := ItemTrackingService.item_counts.duplicate()
		for i in 100:
			assert_ne(ItemRegistry.get_weighted_random_item(20, 0.0, counts, [], GameRandom.gameplay), id)

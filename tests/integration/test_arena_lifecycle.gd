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

func spawn_enemy(at: Vector3) -> CombatActor:
	var actor := world.spawn_enemy(at)
	actor.set_physics_process(false)
	return actor

func combat() -> void:
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)

func test_wave_shop_purchase_and_restart_use_shared_run_services() -> void:
	assert_eq(GameStateService.current_wave, 1)
	assert_same(EconomyService.state, world.session.state)
	combat()
	var before := EconomyService.total_scrap
	assert_true(world.finish_wave())
	assert_eq(EconomyService.total_scrap, before + EconomyService.get_wave_scrap_base(1))
	assert_false(world.finish_wave(), "A duplicate end must not pay twice")
	EconomyService.total_scrap = 100
	var price := world.turret_price()
	assert_true(buy("turret", "normal"))
	assert_eq(world.turrets.size(), 2)
	assert_eq(EconomyService.total_scrap, 100 - price)
	assert_eq(TurretStatsService.get_total_turret_count(), 2)
	assert_true(world.begin_next_wave())
	assert_false(world.begin_next_wave(), "Duplicate deployment must not increment the wave")
	assert_eq(GameStateService.current_wave, 2)
	assert_false(buy("turret", "normal"), "No combat purchases")
	world.start_run()
	assert_eq(world.turrets.size(), 1)
	assert_eq(GameStateService.current_wave, 1)
	assert_eq(EconomyService.total_scrap, GameConstants.STARTING_SCRAP)
	assert_eq(GameStateService.total_kills, 0)
	assert_eq(world.projectiles.size(), 0)

func test_upgrade_uses_existing_modifier_calculation_and_rejects_invalid_purchase() -> void:
	combat()
	world.finish_wave()
	EconomyService.total_scrap = 100
	var before: float = TurretStatsService.get_turret_stats("normal", 1.0)["damage"]
	assert_true(buy("item", "dense_rounds"))
	var after: float = TurretStatsService.get_turret_stats("normal", 1.0)["damage"]
	assert_almost_eq(after, before * 1.07, .001)
	var balance := EconomyService.total_scrap
	assert_false(world.repair(), "Full health must not charge for a repair")
	assert_false(world.shop.purchase(-1))
	assert_eq(EconomyService.total_scrap, balance)
	EconomyService.total_scrap = 0
	assert_false(buy("turret", "normal"))
	assert_eq(world.turrets.size(), 1)
	world.start_run()
	assert_almost_eq(float(TurretStatsService.get_turret_stats("normal", 1.0)["damage"]), before, .001)

func test_targeting_ignores_height_and_dead_enemies() -> void:
	var near := spawn_enemy(Vector3(1, 4, 0))
	var far := spawn_enemy(Vector3(2, 0, 0))
	assert_same(world.nearest_enemy(Vector3.ZERO, 1.5), near)
	near.dead = true
	assert_null(world.nearest_enemy(Vector3.ZERO, 1.5))
	assert_same(world.nearest_enemy(Vector3.ZERO, 3), far)

func test_fast_projectile_sweeps_between_frames_and_pool_resets_damage() -> void:
	combat()
	var enemy := spawn_enemy(Vector3(2, 0, 0))
	await wait_physics_frames(2)
	var shot := world.fire(Vector3(0, .65, 0), enemy, 100, 100)
	shot.advance(.04)
	assert_true(enemy.dead, "Shot travels beyond the target in one tick and must still hit")
	assert_eq(GameStateService.total_kills, 1)
	assert_false(shot.active)
	var next := spawn_enemy(Vector3(3, 0, 0))
	await wait_physics_frames(2)
	var reused := world.fire(Vector3(0, .65, 0), next, 1, 100)
	assert_same(reused, shot)
	reused.advance(.04)
	assert_almost_eq(next.health, next.max_health - 1, .001)
	assert_false(next.dead, "Pooled shot must not retain previous lethal damage")

func test_pickup_and_enemy_death_are_idempotent() -> void:
	combat()
	var enemy := spawn_enemy(Vector3(1, 0, 0))
	enemy.take_damage(100)
	enemy.take_damage(100)
	assert_eq(GameStateService.total_kills, 1)
	assert_eq(world.pickup_root.get_child_count(), 1)
	var pickup := world.pickup_root.get_child(0) as ScrapPickup
	var before := EconomyService.total_scrap
	pickup.collect()
	pickup.collect()
	assert_eq(EconomyService.total_scrap, before + 1)

func test_pause_freezes_timer_and_blocks_shop_mutation() -> void:
	combat()
	world.toggle_pause()
	var before := world.waves.time_left
	world._physics_process(5.0)
	assert_eq(world.waves.time_left, before)
	assert_false(world.is_combat())
	assert_false(world.finish_wave())
	world.toggle_pause()
	world.finish_wave()
	world.toggle_pause()
	assert_false(buy("turret", "normal"))

func test_carry_placement_and_wave_end_restore_ground_position() -> void:
	combat()
	world.player.position = Vector3(0, 0, -.2)
	assert_true(world.interact())
	assert_true(world.turrets[0].carried)
	world.player.position = Vector3(2, 0, 0)
	assert_true(world.interact())
	assert_false(world.turrets[0].carried)
	assert_almost_eq(world.turrets[0].position.y, 0, .001)
	assert_true(world.valid_placement(Vector3(10, 0, 0)), "The enlarged arena keeps the old edge placeable")
	assert_false(world.valid_placement(Vector3(WorldGeometry.HALF_ARENA.x + 1.0, 0, 0)))
	assert_false(world.valid_placement(world.turrets[0].position))
	assert_true(world.interact())
	world.turrets[0].position.y = 1.5
	world.finish_wave()
	assert_null(world.carried_turret)
	assert_almost_eq(world.turrets[0].position.y, 0, .001)

func test_player_death_and_final_wave_reach_terminal_states() -> void:
	combat()
	world.player.take_damage(100)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.GAME_OVER)
	assert_false(GameStateService.is_game_active)
	world.start_run()
	combat()
	GameStateService.current_wave = world.wave_limit
	world.finish_wave()
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.VICTORY)
	assert_false(GameStateService.is_game_active)

func test_imported_model_contracts_and_muzzle_axis() -> void:
	var turret := world.turrets[0]
	assert_not_null(turret.aim)
	assert_not_null(turret.muzzle)
	assert_lt(turret.muzzle.global_position.z, turret.global_position.z, "Model faces Godot -Z")
	assert_gt(turret.muzzle.global_position.y, .3)
	var enemy := spawn_enemy(Vector3.ZERO)
	if ClockworkModels.available("basic"):
		assert_eq(enemy.legs.size(), 0, "Bramble is a hoverer")
		assert_not_null(enemy.clockwork_motion)
		assert_not_null(enemy.clockwork_motion.body, "Hover motion has an authored Body pivot")
	else:
		assert_eq(enemy.legs.size(), 6)
		for leg in enemy.legs:
			assert_not_null(leg)

func test_imported_hero_aims_pistol_at_target_without_twisting_hip_pivots() -> void:
	if not ClockworkModels.available("hero"):
		return
	combat()
	var hero := world.player
	var motion := hero.clockwork_motion
	assert_not_null(motion)
	var hip := motion.limbs[0]
	var hip_rest := hip.transform
	var target := spawn_enemy(hero.position + Vector3(2, 0, 0))
	hero.weapon_clock = 0.0
	hero._tick_player_weapon(.01)
	var forward := WorldGeometry.planar(-hero.weapon_muzzle.global_basis.z).normalized()
	assert_gt(forward.dot(Vector3.RIGHT), .999, "Imported pistol points at the enemy when firing")
	assert_true(hip.transform.is_equal_approx(hip_rest), "Upper-body aim leaves hips attached in their authored pose")
	assert_gt(hero.weapon_clock, 0.0, "A real shot was fired")
	target.dead = true
	hero._tick_player_weapon(.01)
	assert_null(hero.weapon_target, "Dead target does not hold the aiming pose")

func test_imported_hero_boots_stay_above_the_ground_during_a_stride() -> void:
	if not ClockworkModels.available("hero"):
		return
	var motion := world.player.clockwork_motion
	var lowest := INF
	for step in range(40):
		motion.tick(.05, 2.0, false)
		for leg in motion.limbs:
			for mesh: MeshInstance3D in leg.find_children("*", "MeshInstance3D", true, false):
				var bounds := mesh.get_aabb()
				for corner in range(8):
					lowest = minf(lowest, (mesh.global_transform * bounds.get_endpoint(corner)).y)
	assert_gte(lowest, -.002, "Imported boots must not dip beneath the arena floor")

func test_announcement_enters_combat_then_timer_opens_shop() -> void:
	world._physics_process(2.1)
	assert_true(world.is_combat())
	world.waves.remaining_spawns = 0
	world._physics_process(world.waves.time_left + .1)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)

func test_real_input_moves_player_and_pause_stops_physics() -> void:
	combat()
	world.player.set_physics_process(true)
	var start := world.player.position
	Input.action_press("move_right")
	await wait_physics_frames(12)
	Input.action_release("move_right")
	assert_gt(world.player.position.x, start.x)
	assert_almost_eq(world.player.position.y, 0.0, .001)
	world.toggle_pause()
	var paused_position := world.player.position
	await wait_physics_frames(3)
	assert_eq(world.player.position, paused_position)

func test_contact_damage_has_invulnerability_and_repair_is_capped() -> void:
	combat()
	var before := world.player.health
	world.player.take_damage(4)
	world.player.take_damage(4)
	assert_eq(world.player.health, before - 4)
	world.finish_wave()
	EconomyService.total_scrap = 20
	assert_true(world.repair())
	assert_eq(world.player.health, world.player.max_health)
	assert_eq(EconomyService.total_scrap, 15)

func test_spawn_overlap_hits_once_and_wave_cleanup_releases_all_projectiles() -> void:
	combat()
	var enemy := spawn_enemy(Vector3.ZERO)
	await wait_physics_frames(2)
	var shot := world.fire(Vector3(0, .65, 0), enemy, 1, 7)
	shot.advance(.016)
	assert_eq(enemy.health, enemy.max_health - 1.0)
	assert_false(shot.active)
	var another := world.fire(Vector3(4, .65, 0), enemy, 1, 7)
	world.finish_wave()
	assert_false(another.active)
	assert_eq(world.enemies.size(), 0)

func buy(kind: String, id: String) -> bool:
	var price := world.turret_price(id) if kind == "turret" else world.shop.item_price(id)
	EconomyService.current_shop_offers.append(ShopOffer.new(kind, id, price))
	return world.shop.purchase(EconomyService.current_shop_offers.size() - 1)

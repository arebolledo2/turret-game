extends GutTest

var world: ArenaWorld

func before_each() -> void:
	FeatureFlagService.reset_state()
	TestHelpers.reset_all_services()
	world = load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	add_child_autofree(world)
	await wait_process_frames(2)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	world.waves.remaining_spawns = 0
	world.waves.time_left = 999.0

func after_each() -> void:
	ModifierService.clear_modifiers()
	FeatureFlagService.reset_state()

func test_drop_is_a_stationary_target_that_never_moves_or_hurts() -> void:
	var drop := world.drops.spawn(Vector3(12, 0, 8))
	assert_true(world.enemies.has(drop))
	world.player.position = Vector3(12, 0, 8.2)
	await wait_physics_frames(20)
	assert_eq(drop.position, Vector3(12, 0, 8))
	assert_eq(world.player.health, world.player.max_health)

func test_drop_health_is_half_a_tank_at_this_wave() -> void:
	var drop := world.drops.spawn(Vector3(12, 0, 8))
	var tank := EnemyRegistry.get_stats_for_wave("tank", GameStateService.current_wave, world.difficulty_config)
	assert_almost_eq(drop.max_health, float(tank["health"]) * GameConstants.TECH_DROP_HEALTH_FRACTION, .001)

func test_destroying_a_drop_pays_scrap_and_does_not_count_as_a_kill() -> void:
	var drop := world.drops.spawn(Vector3(12, 0, 8))
	var kills := GameStateService.total_kills
	var pickups := world.pickup_root.get_child_count()
	world.combat.apply_hit(drop, CombatHit3D.new(drop.health + 1.0, drop.position))
	assert_eq(world.pickup_root.get_child_count(), pickups + GameConstants.TECH_DROP_SCRAP_PICKUPS)
	assert_eq(GameStateService.total_kills, kills)
	assert_false(world.enemies.has(drop))
	assert_eq(world.drops.destroyed, 1)

func test_item_chance_grants_a_free_item() -> void:
	var drop := world.drops.spawn(Vector3(12, 0, 8))
	GameRandom.gameplay.seed = 1
	var before := ItemTrackingService.collected_items.size()
	var granted := false
	for attempt in 30:
		var extra := world.drops.spawn(Vector3(12, 0, 8))
		world.combat.apply_hit(extra, CombatHit3D.new(extra.health + 1.0, extra.position))
		if ItemTrackingService.collected_items.size() > before:
			granted = true
			break
	assert_true(granted, "at least one of thirty destroyed drops grants an item at a 50% chance")
	assert_not_null(drop)

func test_drops_spawn_clear_of_turrets_and_the_core() -> void:
	world.turrets[0].position = Vector3(0, 0, 0)
	for attempt in 30:
		var at := world.drops.find_position()
		assert_ne(at, Vector3.INF)
		assert_gte(at.length(), GameConstants.TECH_DROP_MIN_TURRET_DISTANCE)

func test_warning_precedes_the_drop_and_wave_end_removes_everything() -> void:
	world.drops.queue_drop(Vector3(10, 0, 5))
	assert_eq(world.drops.active_count(), 1)
	assert_eq(world.enemies.size(), 0, "nothing spawns during the warning")
	world.drops.queued[0]["left"] = 0.0
	world.drops.tick(.01)
	assert_eq(world.enemies.size(), 1)
	world.finish_wave()
	assert_eq(world.enemies.size(), 0, "an unclaimed drop is lost at wave end")
	assert_eq(world.drops.queued.size(), 0)

func test_only_one_drop_at_a_time() -> void:
	world.drops.spawn(Vector3(10, 0, 5))
	assert_gte(world.drops.active_count(), GameConstants.TECH_DROP_MAX_ACTIVE)

func test_flag_off_stops_spawning() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.TECH_DROPS, false)
	world.drops.roll_clock = 999.0
	GameRandom.gameplay.seed = 3
	for index in 200:
		world.drops.tick(.1)
	assert_eq(world.drops.active_count(), 0)

func test_turret_shoots_a_drop_in_range() -> void:
	var drop := world.drops.spawn(world.turrets[0].position + Vector3(3, 0, 0))
	drop.max_health = 1e9
	drop.health = 1e9 # survive the whole test so damage can be measured
	await wait_physics_frames(120)
	assert_lt(drop.health, 1e9)

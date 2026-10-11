extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_flags()
	TestHelpers.reset_all_services()
	world = load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	add_child_autofree(world)
	await wait_process_frames(2)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	world.waves.remaining_spawns = 0
	world.waves.time_left = 999.0
	world.build_zones.reset_run()
	# Keep the random spawn roll out of these tests; they place zones by hand.
	world.build_zones.roll_clock = -100000.0

func after_each() -> void:
	ModifierService.clear_modifiers()
	TestHelpers.reset_flags()

func _active_zone(at: Vector3, kind: String = "turret", asset_id: String = "shock", tier: int = 0) -> BuildZoneActor:
	var zone := world.build_zones.spawn_zone(at, kind, asset_id, tier)
	zone.warning_left = 0.0
	return zone

func test_zone_is_pending_until_its_warning_ends() -> void:
	var zone := world.build_zones.spawn_zone(Vector3(10, 0, 5), "turret", "shock", 0)
	assert_false(zone.is_active())
	world.player.position = zone.position
	world.build_zones.tick(.5)
	assert_eq(zone.progress, 0.0, "no progress while the warning runs")
	world.build_zones.tick(GameConstants.BUILD_ZONE_WARNING_TIME)
	assert_true(zone.is_active())

func test_progress_accrues_only_while_the_hero_stands_inside() -> void:
	var zone := _active_zone(Vector3(10, 0, 5))
	world.player.position = Vector3(-10, 0, -5)
	world.build_zones.tick(1.0)
	assert_eq(zone.progress, 0.0)
	world.player.position = zone.position
	world.build_zones.tick(1.0)
	assert_almost_eq(zone.progress, 1.0 / GameConstants.BUILD_ZONE_BUILD_TIME, .001)

func test_progress_holds_through_the_grace_time_then_decays() -> void:
	var zone := _active_zone(Vector3(10, 0, 5))
	world.player.position = zone.position
	world.build_zones.tick(3.0)
	var built := zone.progress
	world.player.position = Vector3(-10, 0, -5)
	world.build_zones.tick(GameConstants.BUILD_ZONE_GRACE_TIME - .1)
	assert_eq(zone.progress, built, "progress holds during the grace period")
	world.build_zones.tick(1.0)
	assert_lt(zone.progress, built, "progress drains once the grace period has passed")

func test_finishing_a_turret_zone_adds_a_turret_there() -> void:
	var zone := _active_zone(Vector3(10, 0, 5), "turret", "shock")
	var turrets := world.turrets.size()
	world.player.position = zone.position
	world.build_zones.tick(GameConstants.BUILD_ZONE_BUILD_TIME + .1)
	assert_eq(world.turrets.size(), turrets + 1)
	assert_eq(world.turrets.back().position, Vector3(10, 0, 5))
	assert_eq(world.build_zones.completed, 1)
	assert_eq(world.build_zones.zones.size(), 0)

func test_finishing_an_item_zone_grants_the_item() -> void:
	var item_id := world.shop.roll_item_reward()
	assert_ne(item_id, "")
	var zone := _active_zone(Vector3(10, 0, 5), "item", item_id)
	var before := ItemTrackingService.collected_items.size()
	world.player.position = zone.position
	world.build_zones.tick(GameConstants.BUILD_ZONE_BUILD_TIME + .1)
	assert_eq(ItemTrackingService.collected_items.size(), before + 1)

func test_higher_tiers_build_faster() -> void:
	assert_lt(world.build_zones.build_time(2), world.build_zones.build_time(0))

func test_unfinished_zones_fade_and_wave_end_clears_them() -> void:
	var zone := _active_zone(Vector3(10, 0, 5))
	world.build_zones.tick(GameConstants.BUILD_ZONE_LIFETIME + 1.0)
	assert_eq(world.build_zones.zones.size(), 0, "an unvisited zone fades")
	assert_true(zone.is_queued_for_deletion())
	_active_zone(Vector3(-10, 0, 5))
	world.finish_wave()
	assert_eq(world.build_zones.zones.size(), 0)

func test_zones_spawn_clear_of_turrets_and_each_other() -> void:
	world.turrets[0].position = Vector3.ZERO
	var first := _active_zone(Vector3(10, 0, 5))
	for attempt in 30:
		var at := world.build_zones.find_position()
		assert_ne(at, Vector3.INF)
		assert_gte(at.length(), GameConstants.BUILD_ZONE_MIN_TURRET_DISTANCE)
		assert_gte((at - first.position).length(), GameConstants.BUILD_ZONE_MIN_ZONE_DISTANCE)

func test_roll_result_is_a_sellable_turret_or_a_real_item() -> void:
	GameRandom.gameplay.seed = 3
	for attempt in 40:
		var result := world.build_zones.roll_result(2)
		if result["kind"] == "turret":
			assert_true(ShopCatalog.is_available("turret", result["asset_id"]))
		else:
			assert_true(ItemRegistry.get_all_item_ids().has(result["asset_id"]))

func test_leftover_scrap_is_banked_and_raises_the_next_waves_zones() -> void:
	# Banking/zone bonuses remain supported when the progression economy is disabled.
	FeatureFlagService.set_enabled(FeatureFlagService.TURRET_PROGRESSION, false)
	world.start_run()
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	for index in 3:
		var pickup := ScrapPickup.new()
		pickup.world = world
		pickup.amount = 10
		pickup.position = Vector3(20, 0, 10)
		world.pickup_root.add_child(pickup)
	var before := EconomyService.total_scrap
	world.finish_wave()
	assert_gt(EconomyService.total_scrap, before, "leftover scrap is still banked")
	assert_eq(world.build_zones.leftover_scrap, 30)
	world.build_zones.begin_wave()
	assert_eq(world.build_zones.bonus_slots, 2)
	assert_eq(world.build_zones.wave_tier, 1)
	assert_eq(world.build_zones.max_active(), GameConstants.BUILD_ZONE_BASE_ACTIVE + 2)
	assert_eq(world.build_zones.leftover_scrap, 0, "the leftover is spent once applied")

func test_no_leftover_means_no_bonus() -> void:
	world.build_zones.begin_wave()
	assert_eq(world.build_zones.bonus_slots, 0)
	assert_eq(world.build_zones.wave_tier, 0)

func test_bonus_and_tier_are_capped() -> void:
	world.build_zones.note_leftover(100000)
	world.build_zones.begin_wave()
	assert_eq(world.build_zones.bonus_slots, GameConstants.BUILD_ZONE_MAX_BONUS)
	assert_eq(world.build_zones.wave_tier, GameConstants.BUILD_ZONE_MAX_TIER)

func test_flag_off_means_no_progress() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.BUILD_ZONES, false)
	var zone := _active_zone(Vector3(10, 0, 5))
	world.player.position = zone.position
	world.build_zones.tick(2.0)
	assert_eq(zone.progress, 0.0)

func test_reset_run_forgets_leftover_scrap() -> void:
	world.build_zones.note_leftover(50)
	world.build_zones.reset_run()
	assert_eq(world.build_zones.leftover_scrap, 0)

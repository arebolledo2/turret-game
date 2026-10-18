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

func after_each() -> void:
	ModifierService.clear_modifiers()
	TestHelpers.reset_flags()

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

func test_item_chance_queues_an_item_for_review() -> void:
	var drop := world.drops.spawn(Vector3(12, 0, 8))
	GameRandom.gameplay.seed = 1
	var before := ItemTrackingService.collected_items.size()
	var granted := false
	for attempt in 30:
		var extra := world.drops.spawn(Vector3(12, 0, 8))
		world.combat.apply_hit(extra, CombatHit3D.new(extra.health + 1.0, extra.position))
		if not world.drops.pending_items.is_empty():
			granted = true
			break
	assert_true(granted, "at least one of thirty destroyed drops queues an item at a 25% chance")
	assert_eq(ItemTrackingService.collected_items.size(), before, "item is not installed during combat")
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

func test_turret_shoots_a_drop_in_range() -> void:
	var drop := world.drops.spawn(world.turrets[0].position + Vector3(3, 0, 0))
	drop.max_health = 1e9
	drop.health = 1e9 # survive the whole test so damage can be measured
	await wait_physics_frames(120)
	assert_lt(drop.health, 1e9)

func test_reduced_motion_warning_fills_without_changing_its_boundary() -> void:
	world.set_physics_process(false)
	FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, true)
	world.drops.queue_drop(Vector3(10, 0, 5))
	var marker: MeshInstance3D = world.drops.queued[0]["marker"]
	var initial_scale := marker.scale
	world.drops.tick(GameConstants.TECH_DROP_WARNING_TIME * .5)
	assert_eq(marker.scale, initial_scale)
	var material := marker.material_override as ShaderMaterial
	assert_almost_eq(float(material.get_shader_parameter("progress")), .5, .001)
	assert_eq(material.get_shader_parameter("brightness"), 1.0)
	assert_eq(world.enemies.size(), 0)

func test_chest_reward_blocks_shop_without_xp_and_keep_applies_once() -> void:
	world.present_wave_rewards = false
	world.drops.queue_item("dense_rounds")
	assert_false(world.drops.resolve_item(true), "cannot accept during combat")
	world.finish_wave()
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_END)
	assert_true(world.chest_rewards.active)
	assert_eq(ItemTrackingService.item_counts.get("dense_rounds", 0), 0)
	world.chest_rewards.ready_at = 0
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	world.chest_rewards.focus_choice()
	world.chest_rewards._input(accept)
	assert_eq(ItemTrackingService.item_counts.get("dense_rounds", 0), 1)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)
	assert_false(world.drops.resolve_item(true))

func test_sell_is_frozen_and_exact_and_multiple_rewards_need_separate_choices() -> void:
	world.present_wave_rewards = false
	world.drops.queue_item("dense_rounds")
	world.drops.queue_item("scrap_magnet")
	var price := int(world.drops.pending_items[0].value)
	var payout := floori(price * .25)
	ModifierService.add_modifier({"stat": "scrap_earn_mult", "operation": "increase", "value": 10.0})
	world.finish_wave()
	var balance := EconomyService.total_scrap
	world.chest_rewards.ready_at = 0
	world.chest_rewards.sell_button.grab_focus()
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	world.chest_rewards._input(accept)
	assert_eq(EconomyService.total_scrap, balance + payout)
	assert_eq(ItemTrackingService.item_counts.get("dense_rounds", 0), 0)
	assert_eq(world.drops.pending_items.size(), 1)
	assert_true(world.chest_rewards.active)
	world.chest_rewards._input(accept)
	assert_eq(world.drops.pending_items.size(), 1, "same input cannot claim the next item")
	world.chest_rewards.ready_at = 0
	world.chest_rewards._choose(true)
	assert_eq(ItemTrackingService.item_counts.get("scrap_magnet", 0), 1)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)

func test_chest_reward_is_reviewed_after_xp_and_before_final_victory() -> void:
	world.drops.queue_item("dense_rounds")
	world.wave_limit = GameStateService.current_wave
	GameStateMachine.force_transition(GameStateMachine.GameState.WAVE_END)
	world.reward_presentation.begin({})
	world.reward_presentation.complete()
	assert_true(world.chest_rewards.active)
	assert_false(world.reward_presentation.active)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_END)
	world.chest_rewards.ready_at = 0
	world.chest_rewards._choose(true)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.VICTORY)

func test_stack_limit_can_sell_and_restart_discards_pending_rewards() -> void:
	world.drops.queue_item("glass_cannon_core")
	world.shop.apply_item("glass_cannon_core")
	world.present_wave_rewards = false
	world.finish_wave()
	assert_true(world.chest_rewards.keep_button.disabled)
	assert_false(world.drops.resolve_item(true))
	assert_true(world.drops.resolve_item(false))
	world.drops.queue_item("dense_rounds")
	world.start_run()
	assert_true(world.drops.pending_items.is_empty())
	assert_false(world.chest_rewards.active)

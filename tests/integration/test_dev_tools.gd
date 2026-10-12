extends GutTest

## Phase 0 tooling inside a real arena: run config, flag-gated shop stock, dev panel and telemetry.

const EXPERIMENT: String = "test_arena_experiment"

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	TestHelpers.reset_flags()
	ShopCatalog.reset()
	world = _make_world(RunConfig.slice())


func after_each() -> void:
	Engine.time_scale = 1.0
	ShopCatalog.reset()
	FeatureFlagService.reset_state()


func _make_world(config: RunConfig) -> ArenaWorld:
	var arena := ArenaWorld.new()
	arena.run_config = config
	arena.auto_start = false
	arena.show_hud = false
	add_child_autofree(arena)
	arena.start_run()
	arena.set_physics_process(false)
	arena.player.set_physics_process(false)
	arena.turrets[0].set_physics_process(false)
	arena.pickup_root.process_mode = Node.PROCESS_MODE_DISABLED
	return arena


func _register_experiment() -> void:
	FeatureFlagService.register_flag(EXPERIMENT, {"name": "Arena experiment", "scope": FeatureFlagService.SCOPE_EXPERIMENT})


func _enemy(at: Vector3 = Vector3.ZERO) -> CombatActor:
	var actor := world.spawn_enemy(at)
	actor.set_physics_process(false)
	return actor


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	return event


# --- RunConfig -----------------------------------------------------------------------------

func test_default_arena_runs_twenty_waves_on_easy() -> void:
	var arena := _make_world(null)
	assert_eq(arena.wave_limit, 20)
	assert_eq(arena.run_config.wave_limit, 20)
	assert_true(arena.difficulty_config == DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY])


func test_run_config_sets_wave_limit_and_difficulty() -> void:
	var config := RunConfig.new()
	config.wave_limit = 3
	config.difficulty = GameEnums.Difficulty.HARD
	var arena := _make_world(config)
	assert_eq(arena.wave_limit, 3)
	assert_eq(arena.difficulty_config["name"], "Hard")
	GameStateService.current_wave = 3
	arena.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	arena.finish_wave()
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.VICTORY, "The configured limit ends the run")


func test_run_config_preset_is_applied_when_the_arena_starts() -> void:
	_register_experiment()
	var config := RunConfig.slice()
	config.flag_preset = "all_experiments"
	_make_world(config)
	assert_true(FeatureFlagService.is_enabled(EXPERIMENT))


# --- Flags and waves -------------------------------------------------------------------------

func test_queued_flags_land_when_the_next_wave_begins() -> void:
	_register_experiment()
	var panel := world.dev_panel
	assert_not_null(panel)
	assert_eq(panel.toggle_flag(EXPERIMENT, true), FeatureFlagService.QUEUED)
	assert_false(FeatureFlagService.is_enabled(EXPERIMENT))
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	world.finish_wave()
	assert_false(FeatureFlagService.is_enabled(EXPERIMENT), "Still queued during the shop")
	assert_true(world.begin_next_wave())
	assert_true(FeatureFlagService.is_enabled(EXPERIMENT))
	assert_false(FeatureFlagService.has_pending())


func test_restart_discards_queued_flags() -> void:
	_register_experiment()
	world.dev_panel.toggle_flag(EXPERIMENT, true)
	world.start_run()
	assert_false(FeatureFlagService.has_pending())
	assert_false(FeatureFlagService.is_enabled(EXPERIMENT))
	await wait_process_frames(2) # Let the discarded first-run actors finish freeing.


# --- Shop gating ----------------------------------------------------------------------------

func test_flag_gated_catalog_rows_leave_stock_and_block_purchase_until_enabled() -> void:
	_register_experiment()
	ShopCatalog.entries["item"]["salvage_optimizer"] = EXPERIMENT
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	world.finish_wave()
	world.shop.rng = RandomNumberGenerator.new()
	for seed_value in range(1, 40):
		world.shop.rng.seed = seed_value
		world.shop.generate()
		for offer in EconomyService.current_shop_offers:
			assert_ne(offer.asset_id, "salvage_optimizer", "Gated items are never stocked while the flag is off")
	var index := EconomyService.current_shop_offers.size()
	EconomyService.current_shop_offers.append(ShopOffer.new("item", "salvage_optimizer", 1))
	EconomyService.total_scrap = 100
	assert_false(world.shop.purchase(index), "A stale offer for gated content cannot be bought")
	assert_eq(EconomyService.total_scrap, 100)
	FeatureFlagService.set_enabled(EXPERIMENT, true)
	assert_true(world.shop.purchase(index))
	assert_eq(ItemTrackingService.item_counts.get("salvage_optimizer", 0), 1)


# --- Dev panel ------------------------------------------------------------------------------

func test_dev_panel_exists_only_when_available() -> void:
	assert_not_null(world.dev_panel)
	FeatureFlagService.set_enabled(FeatureFlagService.DEV_PANEL, false)
	var arena := _make_world(RunConfig.slice())
	assert_null(arena.dev_panel, "No panel is created while the dev_panel flag is off")


func test_f1_opens_and_closes_the_panel_and_pauses_the_run() -> void:
	var panel := world.dev_panel
	assert_false(world.paused)
	panel._input(_key(KEY_F1))
	assert_true(panel.is_open)
	assert_true(world.paused)
	assert_true(world.dev_menu_open)
	panel._input(_key(KEY_F1))
	assert_false(panel.is_open)
	assert_false(world.paused)
	assert_false(world.dev_menu_open)


func test_closing_restores_an_existing_pause() -> void:
	world.toggle_pause()
	world.dev_panel.set_open(true)
	world.dev_panel.set_open(false)
	assert_true(world.paused, "The pause menu that was open before stays open")


func test_escape_while_open_closes_the_panel_instead_of_toggling_pause() -> void:
	var panel := world.dev_panel
	panel.set_open(true)
	panel._input(_key(KEY_ESCAPE))
	assert_false(panel.is_open)
	assert_false(world.paused)


func test_a_lone_stick_click_does_not_open_the_panel() -> void:
	var panel := world.dev_panel
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_RIGHT_STICK
	event.pressed = true
	panel._input(event)
	assert_false(panel.is_open, "A single stick click does nothing")


func test_panel_ui_lists_flags_and_reflects_their_state() -> void:
	var panel := world.dev_panel
	panel.set_open(true)
	for flag_id in FeatureFlagService.get_flag_ids():
		assert_true(panel.flag_checks.has(flag_id), "%s is listed" % flag_id)
	var overlays: CheckButton = panel.flag_checks[FeatureFlagService.DEBUG_OVERLAYS]
	assert_false(overlays.button_pressed)
	overlays.button_pressed = true
	assert_true(FeatureFlagService.is_enabled(FeatureFlagService.DEBUG_OVERLAYS), "Live-safe flags apply at once")
	assert_string_contains(panel.overlay_text(), "enemies")


func test_panel_marks_flags_that_apply_next_wave() -> void:
	_register_experiment()
	var panel := world.dev_panel
	panel.set_open(true)
	var note: Label = panel.flag_notes[EXPERIMENT]
	assert_string_contains(note.text, "next wave")
	panel.toggle_flag(EXPERIMENT, true)
	assert_string_contains(note.text, "QUEUED ON")


func test_presets_queue_experiments_during_a_run() -> void:
	_register_experiment()
	world.dev_panel.apply_preset("all_experiments")
	assert_true(FeatureFlagService.get_pending().get(EXPERIMENT, false))
	assert_false(FeatureFlagService.is_enabled(EXPERIMENT))


func test_time_scale_resets_when_the_panel_leaves_the_tree() -> void:
	Engine.time_scale = 4.0
	var arena := _make_world(RunConfig.slice())
	arena.queue_free()
	await get_tree().process_frame
	assert_eq(Engine.time_scale, 1.0)


# --- Dev commands ---------------------------------------------------------------------------

func test_god_mode_blocks_player_damage_only() -> void:
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	world.god_mode = true
	var before := world.player.health
	world.combat.apply_hit(world.player, CombatHit3D.new(5.0, Vector3.ZERO))
	assert_eq(world.player.health, before)
	var enemy := _enemy()
	assert_gt(world.combat.apply_hit(enemy, CombatHit3D.new(1.0, Vector3.ZERO)), 0.0, "Enemies still take damage")
	world.god_mode = false
	world.combat.apply_hit(world.player, CombatHit3D.new(5.0, Vector3.ZERO))
	assert_lt(world.player.health, before)


func test_scrap_hull_and_spawn_commands() -> void:
	EconomyService.total_scrap = 3
	assert_true(world.dev.add_scrap(50))
	assert_eq(EconomyService.total_scrap, 53)
	world.dev.add_scrap(-1000)
	assert_eq(EconomyService.total_scrap, 0, "Scrap never goes negative")
	world.player.health = 1.0
	assert_true(world.dev.restore_hull())
	assert_eq(world.player.health, world.player.max_health)
	assert_eq(world.dev.spawn_enemy("fast", 3), 3)
	assert_eq(world.enemies.size(), 3)
	assert_eq(world.dev.spawn_enemy("not_a_type", 3), 0)


func test_kill_all_enemies_works_while_the_panel_pauses_the_run() -> void:
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	_enemy()
	_enemy(Vector3(2, 0, 0))
	world.dev_panel.set_open(true)
	assert_eq(world.dev.kill_all_enemies(), 2)
	assert_true(world.paused, "The pause is restored afterwards")
	assert_eq(GameStateService.total_kills, 2)


func test_jump_to_wave_opens_that_waves_shop_and_deploys_it() -> void:
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	_enemy()
	assert_true(world.dev.jump_to_wave(4))
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)
	assert_eq(GameStateService.current_wave, 3)
	assert_true(world.enemies.is_empty())
	assert_false(EconomyService.current_shop_offers.is_empty())
	assert_true(world.dev.skip_shop())
	assert_eq(GameStateService.current_wave, 4)
	assert_true(world.dev.jump_to_wave(999), "Targets clamp to the wave limit")
	assert_eq(GameStateService.current_wave, world.wave_limit - 1)


func test_jump_is_rejected_outside_a_live_run() -> void:
	GameStateService.is_game_active = false
	assert_false(world.dev.jump_to_wave(2))
	assert_false(world.dev.skip_shop())


# --- Telemetry ------------------------------------------------------------------------------

func test_telemetry_attributes_kills_to_the_turret_that_fired() -> void:
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	var starter := world.turrets[0]
	assert_eq(starter.turret_id, 1)
	var second := world.add_turret(Vector3(3, 0, 0), "plasma")
	assert_eq(second.turret_id, 2)
	var shot_hit := CombatHit3D.new(10000.0, Vector3.ZERO)
	shot_hit.source_id = second.turret_id
	world.combat.apply_hit(_enemy(), shot_hit)
	world.combat.apply_hit(_enemy(), CombatHit3D.new(10000.0, Vector3.ZERO))
	var wave_data := world.telemetry.waves.back() as Dictionary
	assert_eq(wave_data["kills"], 2)
	assert_eq(wave_data["kills_by_turret"], {"2:plasma": 1})


func test_shots_carry_their_turret_id_into_hits() -> void:
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	var shot := CombatShot3D.new()
	shot.damage = 10000.0
	shot.source_id = 7
	assert_eq(shot.copy().source_id, 7)
	var target := _enemy()
	var captured: Array[int] = []
	world.combat.hit_applied.connect(func(_t: Node3D, hit: CombatHit3D, _a: float) -> void: captured.append(hit.source_id))
	world.combat.impact(target, target.position, Vector3.FORWARD, shot, world.enemies)
	assert_eq(captured, [7])


func test_telemetry_counts_turret_moves_and_spending() -> void:
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	world.player.position = world.turrets[0].position + Vector3(0, 0, .5)
	assert_true(world.interact(), "Pick up")
	world.player.position += Vector3(4, 0, 0)
	assert_true(world.interact(), "Place elsewhere")
	assert_eq(world.telemetry.total("turret_moves"), 1)
	world.finish_wave()
	EconomyService.total_scrap = 100
	var index := EconomyService.current_shop_offers.size()
	EconomyService.current_shop_offers.append(ShopOffer.new("item", "scrap_magnet", 5))
	assert_true(world.shop.purchase(index))
	assert_true(world.shop.reroll())
	world.player.health = 1.0
	assert_true(world.repair())
	assert_eq(world.telemetry.total_spent("item"), 5)
	assert_gt(world.telemetry.total_spent("reroll"), 0)
	assert_eq(world.telemetry.total_spent("repair"), GameConstants.REPAIR_COST)


func test_telemetry_resets_with_each_run_and_records_flags() -> void:
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	_enemy().take_damage(10000.0)
	assert_eq(world.telemetry.total("kills"), 1)
	FeatureFlagService.set_enabled(FeatureFlagService.DEBUG_OVERLAYS, true)
	world.start_run()
	assert_eq(world.telemetry.total("kills"), 0)
	assert_eq(world.telemetry.waves.size(), 1, "Wave 1 is open for the new run")
	assert_true(world.telemetry.flags[FeatureFlagService.DEBUG_OVERLAYS])
	await wait_process_frames(2)

extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()

func setup_mode(mode: String) -> void:
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	world.run_config = RunConfig.new()
	world.run_config.mode = mode
	world.run_config.difficulty = GameEnums.Difficulty.HARD
	FeatureFlagService.set_enabled(FeatureFlagService.MODE_PROTECT_CORE, true)
	FeatureFlagService.set_enabled(FeatureFlagService.MODE_CONVOY, true)
	add_child_autofree(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.invulnerability = 999.0
	for turret in world.turrets: turret.set_physics_process(false)
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)

func test_core_target_masks_and_lobber_impact() -> void:
	setup_mode(RunConfig.MODE_CORE)
	assert_not_null(world.core)
	world.player.position = Vector3(8, 0, 0)
	var health := world.core.health
	for kind in ["drowse", "hopper", "tender", "brass_ram", "prism_conductor", "grand_marionettist", "skitter", "puppet"]:
		var actor := world.spawn_enemy(world.core.position, kind)
		actor.set_physics_process(false)
		if actor.brain.pounce: actor.brain.pounce.phase = ChargeController3D.Phase.DASH
		actor.brain.awake = true
		actor._apply_contact_damage(2.0, actor.position)
	assert_eq(world.core.health, health, "Hero-only roles cannot touch the core")
	var lobber := world.spawn_enemy(Vector3(4, 0, 0), "lobber")
	lobber.set_physics_process(false)
	lobber.brain.clock = 0.0
	lobber.brain.move(.01, lobber.speed)
	var attacks := get_tree().get_nodes_in_group("hostile_ordnance")
	assert_eq(attacks.size(), 1)
	var shell: EnemyOrdnance = attacks[0]
	shell.set_physics_process(false)
	assert_true(shell.to_core)
	shell._physics_process(1.21)
	assert_almost_eq(world.core.health, health - world.core_max_health() * .03, .01)

func test_survival_lobber_warns_at_hero_and_pause_freezes_shell() -> void:
	setup_mode(RunConfig.MODE_SURVIVE)
	assert_null(world.core)
	var lobber := world.spawn_enemy(Vector3(4, 0, 0), "lobber")
	lobber.set_physics_process(false)
	lobber.brain.clock = 0.0
	lobber.brain.move(.01, lobber.speed)
	var shell: EnemyOrdnance = get_tree().get_nodes_in_group("hostile_ordnance")[0]
	shell.set_physics_process(false)
	assert_false(shell.to_core)
	assert_eq(shell.target_at, WorldGeometry.planar(world.player.position))
	world.paused = true
	shell._physics_process(3.0)
	assert_eq(shell.elapsed, 0.0)
	world.paused = false
	world.clear_field(false)
	assert_true(shell.is_queued_for_deletion())

func test_convoy_timeout_ignores_surviving_boss() -> void:
	setup_mode(RunConfig.MODE_CONVOY)
	assert_true(world.convoy_mode)
	GameStateService.current_wave = 6
	world.waves.remaining_spawns = 0
	world.waves.boss_spawned = true
	var boss := world.spawn_enemy(Vector3(4, 0, 0), "brass_ram")
	boss.set_physics_process(false)
	world.waves.time_left = .001
	world.waves.tick(.01)
	await get_tree().process_frame
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)
	assert_true(world.drops.pending_items.is_empty())
	assert_true(world.enemies.is_empty())

func test_specialist_cap_falls_back_inside_wave_roster() -> void:
	setup_mode(RunConfig.MODE_CORE)
	GameStateService.current_wave = 9
	world.waves.spawn_plan.assign(["lobber", "lobber", "lobber"])
	world.waves.spawned_this_wave = 0
	world.waves.remaining_spawns = 3
	world.waves.spawn_clock = 0.0
	world.waves.spawn_interval = 1.0
	for index in 3:
		world.waves.tick(1.0)
		for actor in world.enemies: actor.set_physics_process(false)
	assert_eq(world.waves.active_count("lobber"), 2)
	assert_eq(world.enemies.size(), 3)
	for actor in world.enemies: assert_true(EnemyEcology.roster(9).has(actor.enemy_type))

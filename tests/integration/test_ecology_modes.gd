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
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)

func test_core_target_masks_and_lobber_impact() -> void:
	setup_mode(RunConfig.MODE_CORE)
	assert_not_null(world.core)
	world.player.position = Vector3(8, 0, 0)
	var health := world.core.health
	for kind in ["hopper", "tender", "brass_ram", "prism_conductor", "grand_marionettist", "skitter", "puppet"]:
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
	for index in 5:
		world.waves.tick(1.0)
		for actor in world.enemies: actor.set_physics_process(false)
	assert_eq(world.waves.active_count("lobber"), 2)
	assert_eq(world.enemies.size(), 3)
	for actor in world.enemies: assert_true(EnemyEcology.roster(9).has(actor.enemy_type))

func test_drowse_wakes_for_core_and_can_damage_it() -> void:
	setup_mode(RunConfig.MODE_CORE)
	world.player.position = Vector3(10, 0, 0)
	var beetle := world.spawn_enemy(world.core.position + Vector3(1.2, 0, 0), "drowse")
	beetle.set_physics_process(false)
	var before := world.core.health
	beetle.brain.move(.1, beetle.speed)
	assert_true(beetle.brain.awake)
	assert_false(beetle.chasing_hero)
	beetle._apply_contact_damage(.1, beetle.position)
	assert_eq(world.core.health, before, "Wake warning is harmless")
	beetle.brain.move(.5, beetle.speed)
	assert_lt(beetle.brain.move(.1, beetle.speed).x, 0.0)
	beetle.position = world.core.position
	beetle._apply_contact_damage(1.0, beetle.position)
	assert_lt(world.core.health, before)
	world.core.position = Vector3(-10, 0, 0)
	beetle.brain.move(2.1, beetle.speed)
	assert_false(beetle.brain.awake)

func test_low_health_warning_channels_and_phase_gating() -> void:
	setup_mode(RunConfig.MODE_CORE)
	var warning := LowHealthWarning.new()
	warning.world = world
	add_child_autofree(warning)
	world.player.health = world.player.max_health * .2
	world.core.health = world.core.max_health * .1
	warning._process(1.0)
	assert_true(warning.visible)
	assert_almost_eq(warning.hero_strength, .75, .001)
	assert_eq(warning.core_strength, 1.0)
	assert_true(warning.hero_label.visible)
	assert_true(warning.core_label.visible)
	FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, true)
	var time := warning.pulse_time
	warning._process(1.0)
	assert_eq(warning.pulse_time, time)
	world.player.health = world.player.max_health
	warning._process(1.0)
	assert_eq(warning.hero_strength, 0.0)
	assert_false(warning.hero_label.visible)
	assert_true(warning.core_label.visible)
	world.paused = true
	warning._process(.1)
	assert_false(warning.visible)
	world.paused = false
	GameStateMachine.force_transition(GameStateMachine.GameState.PREPARATION)
	warning._process(.1)
	assert_false(warning.visible)

func test_every_late_core_wave_has_active_pressure_without_changing_early_waves() -> void:
	for wave in range(1, 21):
		if wave <= 5:
			assert_eq(EnemyEcology.schedule(wave, 200, true), EnemyEcology.schedule(wave, 200))
			continue
		var pressure := 0
		var total := 0
		for kind in EnemyEcology.schedule(wave, 200, true):
			var points := EnemyEcology.cost(kind)
			total += points
			if kind == "lobber" or not EnemyEcology.TYPES.has(kind): pressure += points
		assert_gte(float(pressure) / total, .5, "Wave %d must threaten the core" % wave)
		if EnemyEcology.BOSSES.has(wave):
			assert_eq(EnemyEcology.budget_multiplier(wave, true), .6)
			assert_eq(EnemyEcology.budget_multiplier(wave), .25)

func test_core_seekers_have_a_late_wave_floor_even_on_easy() -> void:
	setup_mode(RunConfig.MODE_CORE)
	world.difficulty_config["seeker_share"] = 0.0
	GameStateService.current_wave = 6
	world.waves.seeker_credit = 0
	var seekers := 0
	for i in 10:
		if world.waves._take_credit("seeker_share"): seekers += 1
	assert_eq(seekers, 5)
	world.convoy_mode = true
	world.waves.seeker_credit = 0
	assert_false(world.waves._take_credit("seeker_share"), "Convoy retains its own difficulty rules")

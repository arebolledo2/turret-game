extends GutTest

func before_each() -> void:
	TestHelpers.reset_flags()
	TestHelpers.reset_all_services()

func _world(difficulty: GameEnums.Difficulty, mode: String = RunConfig.MODE_SURVIVE) -> ArenaWorld:
	var config := RunConfig.new()
	config.difficulty = difficulty
	config.mode = mode
	var arena := load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	arena.run_config = config
	add_child_autofree(arena)
	await wait_process_frames(2)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	arena.waves.remaining_spawns = 0
	arena.waves.time_left = 999.0
	return arena

func after_each() -> void:
	TestHelpers.reset_flags()

func test_brutal_exists_and_parses() -> void:
	assert_true(DifficultyService.DIFFICULTY_CONFIG.has(GameEnums.Difficulty.BRUTAL))
	assert_eq(RunConfig.from_args(PackedStringArray(["--difficulty=brutal"])).difficulty, GameEnums.Difficulty.BRUTAL)

func test_tiers_escalate_in_every_rule() -> void:
	var order := [GameEnums.Difficulty.EASY, GameEnums.Difficulty.MEDIUM, GameEnums.Difficulty.HARD, GameEnums.Difficulty.BRUTAL]
	for key in ["elite_chance", "seeker_share", "spawn_rate_mult"]:
		var last := -1.0
		for tier in order:
			var value := DifficultyService.rule(DifficultyService.DIFFICULTY_CONFIG[tier], key)
			assert_gte(value, last, "%s never drops going up the tiers" % key)
			last = value
	var core_last := 99.0
	for tier in order:
		var core_value := DifficultyService.rule(DifficultyService.DIFFICULTY_CONFIG[tier], "core_health_mult")
		assert_lte(core_value, core_last, "core gets weaker going up the tiers")
		core_last = core_value
	assert_eq(DifficultyService.rule(DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.EASY], "elite_chance"), 0.0)

func test_elites_arrive_at_the_configured_share() -> void:
	var world := await _world(GameEnums.Difficulty.BRUTAL)
	var elites := 0
	for index in 100:
		if world.waves._take_credit("elite_chance"):
			elites += 1
	assert_eq(elites, 15, "15% of 100 spawns, evenly spread")

func test_elite_is_tougher_faster_and_worth_more() -> void:
	var world := await _world(GameEnums.Difficulty.BRUTAL)
	var normal := world.waves.spawn_enemy(Vector3(5, 0, 5), "basic")
	var elite := world.waves.spawn_enemy(Vector3(6, 0, 5), "basic", true)
	assert_true(elite.elite)
	assert_almost_eq(elite.max_health, normal.max_health * 2.0, .001)
	assert_almost_eq(elite.speed, normal.speed * 1.2, .001)
	assert_eq(elite.scrap_value, normal.scrap_value * 2)

func test_easy_and_medium_spawn_no_elites() -> void:
	for tier in [GameEnums.Difficulty.EASY, GameEnums.Difficulty.MEDIUM]:
		var world := await _world(tier)
		for index in 50:
			assert_false(world.waves._take_credit("elite_chance"))

func test_rules_flag_off_neutralises_everything() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.DIFFICULTY_RULES, false)
	var world := await _world(GameEnums.Difficulty.BRUTAL, RunConfig.MODE_CORE)
	assert_eq(DifficultyService.rule(world.difficulty_config, "elite_chance"), 0.0)
	assert_eq(world.core.max_health, GameConstants.PLAYER_BASE_MAX_HEALTH * GameConstants.CORE_HEALTH_MULT)
	assert_eq(world.difficulty_config["enemy_health_mult"], DifficultyService.DIFFICULTY_CONFIG[GameEnums.Difficulty.BRUTAL]["enemy_health_mult"],
		"the multipliers still apply")

func test_brutal_core_has_less_health() -> void:
	var world := await _world(GameEnums.Difficulty.BRUTAL, RunConfig.MODE_CORE)
	assert_almost_eq(world.core.max_health, GameConstants.PLAYER_BASE_MAX_HEALTH * GameConstants.CORE_HEALTH_MULT * .7, .01)

func test_seekers_ignore_the_hero_in_core_mode() -> void:
	var world := await _world(GameEnums.Difficulty.BRUTAL, RunConfig.MODE_CORE)
	var seeker := world.waves.spawn_enemy(Vector3(8, 0, 8), "basic", false, true)
	world.player.position = Vector3(8.5, 0, 8)
	assert_eq(seeker.chase_position(), world.core.position)
	assert_false(seeker.chasing_hero)

func test_brutal_core_waves_arrive_faster() -> void:
	var easy := await _world(GameEnums.Difficulty.EASY, RunConfig.MODE_CORE)
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	easy.begin_next_wave()
	var easy_span := easy.waves.spawn_interval * easy.waves.remaining_spawns / easy.waves.time_left
	var brutal := await _world(GameEnums.Difficulty.BRUTAL, RunConfig.MODE_CORE)
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	brutal.begin_next_wave()
	var brutal_span := brutal.waves.spawn_interval * brutal.waves.remaining_spawns / brutal.waves.time_left
	assert_lt(brutal_span, easy_span, "the same wave is spawned over a shorter share of its time")

func test_survive_mode_never_makes_seekers() -> void:
	var world := await _world(GameEnums.Difficulty.BRUTAL)
	world.waves.remaining_spawns = 5
	world.waves.spawn_clock = 0.0
	world.waves.tick(.01)
	for enemy in world.enemies:
		assert_false(enemy.ignores_hero)

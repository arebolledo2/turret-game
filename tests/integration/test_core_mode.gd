extends GutTest

var world: ArenaWorld

func before_each() -> void:
	FeatureFlagService.reset_state()
	TestHelpers.reset_all_services()

func _core_world(difficulty: GameEnums.Difficulty = GameEnums.Difficulty.EASY) -> ArenaWorld:
	var config := RunConfig.new()
	config.mode = RunConfig.MODE_CORE
	config.difficulty = difficulty
	var arena := load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	arena.run_config = config
	add_child_autofree(arena)
	await wait_process_frames(2)
	return arena

func _to_combat(arena: ArenaWorld) -> void:
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	arena.waves.remaining_spawns = 0
	arena.waves.time_left = 999.0

func test_survive_mode_has_no_core() -> void:
	world = load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	add_child_autofree(world)
	await wait_process_frames(2)
	assert_null(world.core)
	assert_false(world.core_mode)

func test_core_mode_spawns_core_and_moves_the_start() -> void:
	world = await _core_world()
	assert_not_null(world.core)
	assert_eq(world.core.max_health, GameConstants.PLAYER_BASE_MAX_HEALTH * GameConstants.CORE_HEALTH_MULT)
	assert_almost_eq(world.player.position.z, GameConstants.CORE_START_OFFSET, .01)

func test_flag_off_falls_back_to_survive() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.MODE_PROTECT_CORE, false)
	world = await _core_world()
	assert_null(world.core)

func test_turrets_cannot_be_placed_on_the_core() -> void:
	world = await _core_world()
	assert_false(world.valid_placement(Vector3(0.5, 0, 0)))
	assert_true(world.valid_placement(Vector3(5, 0, 0)))

func test_enemy_far_from_hero_heads_for_the_core() -> void:
	world = await _core_world()
	_to_combat(world)
	var enemy := world.spawn_enemy(Vector3(-12, 0, -6), "basic")
	await wait_physics_frames(1)
	assert_eq(enemy.chase_position(), world.core.position)
	assert_false(enemy.chasing_hero)

func test_aggro_has_hysteresis() -> void:
	world = await _core_world()
	_to_combat(world)
	world.player.position = Vector3(10, 0, 10)
	var enemy := world.spawn_enemy(Vector3(10 + GameConstants.CORE_AGGRO_RANGE - .3, 0, 10), "basic")
	enemy.chase_position()
	assert_true(enemy.chasing_hero, "inside aggro range")
	enemy.position = Vector3(10 + GameConstants.CORE_DEAGGRO_RANGE - .3, 0, 10)
	enemy.chase_position()
	assert_true(enemy.chasing_hero, "still chasing between the two ranges")
	enemy.position = Vector3(10 + GameConstants.CORE_DEAGGRO_RANGE + .3, 0, 10)
	enemy.chase_position()
	assert_false(enemy.chasing_hero, "beyond the de-aggro range")
	enemy.position = Vector3(10 + GameConstants.CORE_AGGRO_RANGE + .3, 0, 10)
	enemy.chase_position()
	assert_false(enemy.chasing_hero, "must come inside the aggro range again")

func test_enemy_at_the_core_damages_it_on_an_interval() -> void:
	world = await _core_world()
	_to_combat(world)
	var enemy := world.spawn_enemy(Vector3(0, 0, -(world.core.radius + .2)), "basic")
	enemy.max_health = 1e9
	enemy.health = 1e9 # keep the turret from killing it mid-test
	var expected := enemy.contact_damage * GameConstants.CORE_DAMAGE_FRACTION
	await wait_physics_frames(3)
	assert_almost_eq(world.core.health, world.core.max_health - expected, .01, "first contact hits once")
	await wait_physics_frames(10)
	assert_almost_eq(world.core.health, world.core.max_health - expected, .01, "no second hit inside the interval")
	enemy.core_clock = 0.0
	await wait_physics_frames(2)
	assert_almost_eq(world.core.health, world.core.max_health - expected * 2.0, .01)

func test_core_destruction_ends_the_run() -> void:
	world = await _core_world()
	_to_combat(world)
	world.damage_core(world.core.max_health + 1.0)
	assert_true(world.core.dead)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.GAME_OVER)
	assert_eq(world.defeat_reason, "CORE DESTROYED")

func test_hero_death_still_ends_the_run() -> void:
	world = await _core_world()
	_to_combat(world)
	world.combat.apply_hit(world.player, CombatHit3D.new(world.player.max_health + 1.0, world.player.position))
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.GAME_OVER)
	assert_eq(world.defeat_reason, "HULL LOST")

func test_core_repair_costs_scrap_in_the_shop() -> void:
	world = await _core_world()
	_to_combat(world)
	world.damage_core(30.0)
	world.finish_wave()
	var before := EconomyService.total_scrap
	EconomyService.total_scrap = maxi(before, 10)
	var hurt := world.core.health
	assert_true(world.repair_core())
	assert_almost_eq(world.core.health, hurt + GameConstants.REPAIR_HEAL_AMOUNT, .01)

func test_spawns_land_on_the_spawn_box() -> void:
	world = await _core_world()
	var half := WorldGeometry.HALF_ARENA * GameConstants.CORE_SPAWN_BOX
	for index in 40:
		var at := world.waves.spawn_position()
		var on_x := is_equal_approx(absf(at.x), half.x) and absf(at.z) <= half.y + .01
		var on_z := is_equal_approx(absf(at.z), half.y) and absf(at.x) <= half.x + .01
		assert_true(on_x or on_z, "spawn %s lies on the box" % at)

func test_survive_mode_enemies_still_chase_the_hero() -> void:
	world = load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	add_child_autofree(world)
	await wait_process_frames(2)
	_to_combat(world)
	var enemy := world.spawn_enemy(Vector3(-8, 0, -5), "basic")
	var start := enemy.position.distance_to(world.player.position)
	await wait_physics_frames(30)
	assert_lt(enemy.position.distance_to(world.player.position), start)

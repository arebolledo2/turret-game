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
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)

func _growth() -> HeroProgression:
	return PlayerStatsService.state.hero_progression

func test_collected_scrap_grants_hero_xp() -> void:
	assert_true(world.session.state.turret_progression_enabled)
	world.collect_scrap(10)
	assert_eq(_growth().total_xp, 10)
	assert_eq(_growth().level, 1)

func test_level_up_raises_and_heals_max_health() -> void:
	var before := world.player.max_health
	world.player.health = before - 2.0
	var seen: Array[int] = []
	var listener := func(level: int) -> void: seen.append(level)
	Events.hero_leveled.connect(listener)
	world.collect_scrap(20)
	Events.hero_leveled.disconnect(listener)
	assert_eq(_growth().level, 2)
	assert_eq(seen, [2] as Array[int])
	assert_gt(world.player.max_health, before)
	assert_almost_eq(world.player.health, before - 2.0 + (world.player.max_health - before), .001)

func test_evolution_only_in_shop_and_changes_form() -> void:
	world.collect_scrap(110)
	assert_eq(_growth().pending_evolutions, [5])
	assert_false(world.evolve_hero("pip_arc"), "Evolving is a shop action")
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	assert_true(world.shop.is_open())
	assert_false(world.evolve_hero("pip_storm"), "The wrong tier is refused")
	assert_true(world.evolve_hero("pip_arc"))
	assert_eq(_growth().evolution_form, "pip_arc")
	assert_almost_eq(world.player.visual.scale.x, float(HeroForms.row("pip_arc").scale), .0001)

func test_progression_flag_off_gives_no_hero_xp() -> void:
	world.session.state.turret_progression_enabled = false
	world.collect_scrap(50)
	assert_eq(_growth().total_xp, 0)

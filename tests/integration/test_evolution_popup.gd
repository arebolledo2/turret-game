extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.run_config = RunConfig.slice()
	world.run_config.mode = RunConfig.MODE_CORE
	add_child_autofree(world)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.session.state.turret_progression_enabled = true
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)

func _popup() -> EvolutionPopup:
	return world.evolution_popup

func _growth() -> HeroProgression:
	return PlayerStatsService.state.hero_progression

func test_wave_end_with_nothing_ready_goes_straight_to_the_shop() -> void:
	world.finish_wave()
	assert_false(_popup().active)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)

func test_ready_turret_pops_up_before_the_shop_and_must_be_resolved() -> void:
	var turret := world.turrets[0]
	turret.progression.award(110)
	world.finish_wave()
	assert_true(_popup().active)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_END, "The shop waits behind the popup")
	assert_false(world.shop.is_open())
	assert_eq(_popup().buttons.size(), 1, "Level 5 offers a single upgrade")
	_popup().buttons[0].pressed.emit()
	assert_eq(turret.progression.evolution_form, "machine_gun")
	assert_false(_popup().active)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)
	assert_true(world.shop.is_open())

func test_a_turret_owed_both_milestones_is_shown_twice() -> void:
	var turret := world.turrets[0]
	turret.progression.award(1500)
	world.finish_wave()
	assert_eq(_popup().buttons.size(), 1)
	_popup().buttons[0].pressed.emit()
	assert_true(_popup().active, "The level-10 choice follows the level-5 upgrade")
	assert_eq(_popup().buttons.size(), 2, "Level 10 offers both finals")
	_popup().buttons[1].pressed.emit()
	assert_eq(turret.progression.evolution_form, "omnifire")
	assert_false(_popup().active)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)

func test_hero_is_offered_and_evolves_in_the_popup() -> void:
	world.collect_scrap(110)
	assert_eq(_growth().pending_evolutions, [5])
	world.finish_wave()
	assert_true(_popup().active)
	assert_eq(_popup().queue, [null], "Only the hero is ready")
	_popup().buttons[0].pressed.emit()
	assert_eq(_growth().evolution_form, "pip_arc")
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)

func test_hero_and_turret_are_resolved_one_after_the_other() -> void:
	var turret := world.turrets[0]
	turret.progression.award(110)
	world.collect_scrap(110)
	world.finish_wave()
	assert_eq(_popup().queue.size(), 2)
	_popup().buttons[0].pressed.emit()
	assert_true(_popup().active)
	_popup().buttons[0].pressed.emit()
	assert_false(_popup().active)
	assert_eq(_growth().evolution_form, "pip_arc")
	assert_eq(turret.progression.evolution_form, "machine_gun")

func test_evolving_is_refused_during_combat() -> void:
	world.turrets[0].progression.award(110)
	assert_false(world.turrets[0].evolve("machine_gun"))
	world.collect_scrap(110)
	assert_false(world.evolve_hero("pip_arc"))

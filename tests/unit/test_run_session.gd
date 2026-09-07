extends GutTest

func before_each() -> void:
	TestHelpers.reset_all_services()

func test_standalone_service_instances_have_private_state() -> void:
	var script := load("res://scripts/autoload/economy_service.gd")
	var first = autofree(script.new())
	var second = autofree(script.new())
	first.total_scrap = 50
	assert_ne(second.total_scrap, first.total_scrap)

func test_run_binds_services_and_replaces_transient_state() -> void:
	var session := RunSession.new()
	add_child_autofree(session)
	FeatureFlagService.set_enabled(FeatureFlagService.SHOP, false)
	DifficultyService.set_difficulty(GameEnums.Difficulty.HARD)
	session.begin_run()
	var old := session.state
	EconomyService.total_scrap = 777
	LootService.add_found_item("scrap_magnet")
	assert_eq(old.total_scrap, 777)
	session.begin_run()
	assert_ne(session.state, old)
	assert_eq(old.total_scrap, 777)
	assert_eq(EconomyService.total_scrap, GameConstants.STARTING_SCRAP)
	assert_false(LootService.has_pending_loot())
	assert_false(FeatureFlagService.is_enabled(FeatureFlagService.SHOP))
	assert_eq(DifficultyService.current_difficulty, GameEnums.Difficulty.HARD)

func test_teardown_detaches_current_run() -> void:
	var session := RunSession.new()
	add_child(session)
	session.begin_run()
	var old := session.state
	session.free()
	assert_ne(GameStateService.state, old)
	assert_null(GameStateService.wave_controller)

func test_old_scene_teardown_cannot_clear_new_run() -> void:
	var old := RunSession.new()
	add_child(old)
	old.begin_run()
	var current := RunSession.new()
	add_child_autofree(current)
	current.begin_run()
	EconomyService.total_scrap = 321
	old.free()
	assert_same(GameStateService.state, current.state)
	assert_eq(EconomyService.total_scrap, 321)

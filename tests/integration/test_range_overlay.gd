extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	add_child_autofree(world)
	await wait_process_frames(2)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	world.waves.remaining_spawns = 0
	world.waves.time_left = 999.0

func after_each() -> void:
	TestHelpers.reset_flags()

func _press_toggle() -> void:
	var event := InputEventAction.new()
	event.action = "toggle_range"
	event.pressed = true
	world._unhandled_input(event)

func test_toggle_action_is_bound_to_y_and_tab() -> void:
	var kinds: Array[String] = []
	for event in InputMap.action_get_events("toggle_range"):
		if event is InputEventJoypadButton:
			assert_eq((event as InputEventJoypadButton).button_index, JOY_BUTTON_Y)
		kinds.append(event.get_class())
	assert_has(kinds, "InputEventJoypadButton")

func test_rings_are_hidden_until_toggled() -> void:
	var turret := world.turrets[0]
	world.player.position = turret.position + Vector3(10, 0, 0)
	await wait_physics_frames(2)
	assert_null(turret.range_ring)
	_press_toggle()
	await wait_physics_frames(2)
	assert_true(world.show_ranges)
	assert_true(turret.range_ring.visible)
	var expected := turret._current_view(0.0).range_metres
	assert_almost_eq(turret.range_ring_metres, expected, .001)
	_press_toggle()
	await wait_physics_frames(2)
	assert_false(turret.range_ring.visible)

func test_ring_follows_a_carried_turret_on_the_floor() -> void:
	var turret := world.turrets[0]
	world.show_ranges = true
	turret.carried = true
	await wait_physics_frames(3)
	assert_almost_eq(turret.range_ring.global_position.y, .04, .001)
	assert_true(turret.range_ring.visible)

func test_flag_off_disables_the_toggle() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.RANGE_OVERLAY, false)
	_press_toggle()
	assert_false(world.show_ranges)

func test_nearby_turret_reveals_range_without_global_toggle() -> void:
	var turret := world.turrets[0]
	SettingsService.ground_markers = SettingsService.GroundMarkers.CONTEXTUAL
	world.show_ranges = false
	world.player.position = turret.position + Vector3(.5, 0, 0)
	turret._update_range_ring()
	assert_true(turret.range_ring.visible)
	world.player.position += Vector3(10, 0, 0)
	turret._update_range_ring()
	assert_false(turret.range_ring.visible)

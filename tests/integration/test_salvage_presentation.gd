extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.present_wave_rewards = true
	add_child_autofree(world)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.turrets[0].set_physics_process(false)
	world.pickup_root.process_mode = Node.PROCESS_MODE_DISABLED
	world.reward_presentation.set_process(false)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)

func _finish(amount: int = 74) -> void:
	var pickup := ScrapPickup.new()
	pickup.world = world
	pickup.amount = amount
	pickup.position = Vector3(7, 0, 5)
	world.pickup_root.add_child(pickup)
	assert_true(world.finish_wave())

func test_collection_waits_for_continue_then_opens_shop_once() -> void:
	_finish()
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_END)
	assert_eq(world.turrets[0].progression.level, 5, "Committed before animation")
	assert_true(world.reward_presentation.active)
	assert_eq(world.reward_presentation.cards[1].level, 1, "Presentation begins at the previous level")
	world.reward_presentation.advance(2.0)
	assert_eq(world.reward_presentation.cards[1].level, 5)
	assert_true(world.reward_presentation.cards[1].floating.text.contains("LEVEL UP"))
	world.reward_presentation.advance(60.0)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_END, "Never auto-advance")
	assert_true(world.reward_presentation.active)
	world.reward_presentation.skip_button.pressed.emit()
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)
	assert_false(world.reward_presentation.active)
	var money := EconomyService.total_scrap
	world.reward_presentation.complete()
	assert_eq(EconomyService.total_scrap, money)
	assert_eq(world.turrets[0].progression.total_xp, 74)

func test_pause_freezes_sequence_and_skip_keeps_rewards() -> void:
	_finish()
	world.toggle_pause()
	world.reward_presentation.advance(10)
	assert_eq(world.reward_presentation.elapsed, 0.0)
	assert_false(world.reward_presentation.root.visible)
	world.reward_presentation.complete()
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_END)
	world.toggle_pause()
	world.reward_presentation.advance(.1)
	world.reward_presentation.skip_button.pressed.emit()
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)
	assert_eq(world.turrets[0].progression.total_xp, 74)

func test_restart_cancels_old_presentation_without_late_shop_transition() -> void:
	_finish()
	world.start_run()
	assert_false(world.reward_presentation.active)
	world.reward_presentation.advance(10)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_ANNOUNCEMENT)
	assert_eq(world.turrets[0].progression.total_xp, 0)
	assert_true(world.salvage.settlements.is_empty())

func test_carried_turret_stays_at_snapshot_position_until_victory() -> void:
	world.wave_limit = 1
	var turret := world.turrets[0]
	turret.carried = true
	world.carried_turret = turret
	turret.position = Vector3(2, 1.4, 3)
	_finish()
	assert_true(turret.carried)
	assert_eq(turret.position, Vector3(2, 1.4, 3))
	world.reward_presentation.complete()
	assert_false(turret.carried)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.VICTORY)
	assert_false(GameStateService.is_game_active)

func test_reduced_motion_has_no_flights_or_pulses_but_shows_levels() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, true)
	_finish()
	for packet in world.reward_presentation.packets:
		assert_true(packet.nodes.is_empty())
	assert_null(world.reward_presentation.cards[1].glow)
	world.reward_presentation.advance(2.0)
	assert_eq(world.reward_presentation.cards[1].level, 5)
	world.reward_presentation.advance(60.0)
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.WAVE_END)

func test_xp_bars_show_partial_progress_in_recap_and_turret_roster() -> void:
	_finish(77)
	world.reward_presentation.advance(2.0)
	var bar: ProgressBar = world.reward_presentation.cards[1].bar
	assert_eq(bar.value, 3.0, "Overflow after reaching level 5 is shown")
	assert_eq(bar.max_value, float(TurretProgression.cost_to_next(5)))
	world.reward_presentation.complete()
	var shop: ShopScreen = world.hud.shop_screen
	shop.refresh()
	shop.switch_tab(1)
	assert_eq(shop.turret_inspector.xp_bar.value, bar.value)
	assert_eq(shop.turret_inspector.roster_bars[0].value, bar.value)
	assert_eq(shop.turret_inspector.roster_bars[0].max_value, bar.max_value)

func test_no_leftovers_does_not_delay_shop() -> void:
	world.finish_wave()
	assert_eq(GameStateMachine.current_state, GameStateMachine.GameState.SHOP)
	assert_false(world.reward_presentation.active)

func test_turrets_tab_uses_individual_stats_and_controller_can_reach_deploy() -> void:
	_finish()
	world.reward_presentation.complete()
	var second := world.add_turret(Vector3(6, 0, 0), "melee")
	second.set_physics_process(false)
	var shop: ShopScreen = world.hud.shop_screen
	shop.refresh()
	shop.switch_tab(1)
	assert_false(shop.offers_content.visible)
	assert_true(shop.turret_inspector.visible)
	assert_false(shop.reroll_button.visible)
	assert_eq(shop.turret_inspector.buttons.size(), 2)
	assert_true(shop.turret_inspector.title.text.contains("LEVEL 5"))
	assert_true(shop.turret_inspector.detail.text.contains("+74 XP"))
	assert_true(shop.turret_inspector.detail.text.contains("%.0f" % world.turrets[0]._current_view(0).damage))
	shop.turret_inspector.select(second.turret_id)
	assert_true(shop.turret_inspector.title.text.contains("LEVEL 1"))
	assert_true(shop.turret_inspector.detail.text.contains("Sweep"))
	var last: Button = shop.turret_inspector.buttons.back()
	last.grab_focus()
	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	Input.parse_input_event(down)
	await wait_process_frames(1)
	assert_same(get_viewport().gui_get_focus_owner(), shop.continue_button)
	var bumper := InputEventJoypadButton.new()
	bumper.button_index = JOY_BUTTON_LEFT_SHOULDER
	bumper.pressed = true
	Input.parse_input_event(bumper)
	await wait_process_frames(1)
	assert_eq(shop.active_tab, 0)
	assert_true(shop.offers_content.visible)

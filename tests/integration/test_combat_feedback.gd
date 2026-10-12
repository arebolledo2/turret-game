extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.show_hud = false
	add_child_autofree(world)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.turrets[0].set_physics_process(false)
	world.audio.set_process(false)
	world.effects.set_physics_process(false)
	world.preparation.deploy()
	world.audio.reset()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)

func test_audio_pool_throttles_crowds_and_reserves_warning_voices() -> void:
	assert_eq(world.audio.voices.size(), 12)
	assert_true(world.audio.play_cue("ion", Vector3.LEFT))
	assert_false(world.audio.play_cue("ion", Vector3.RIGHT))
	for index in range(GameAudio.GENERAL_VOICES):
		world.audio.remaining[index] = 1.0
	assert_false(world.audio.play_cue("plasma", Vector3.ZERO))
	assert_true(world.audio.play_cue("warning", Vector3.RIGHT))
	assert_eq(world.audio.voices[10].position, Vector3.RIGHT)
	assert_true(world.audio.play_cue("hull", Vector3.ZERO))
	assert_true(world.audio.play_cue("victory", Vector3.ZERO))
	assert_eq(world.audio.voices.size(), 12, "Critical replacement must not allocate another voice")

func test_pause_freezes_audio_and_effects_restart_clears_them() -> void:
	world.audio.play_cue("ion", Vector3.ZERO)
	await wait_physics_frames(2) # AudioStreamPlayer3D starts playback on the physics boundary.
	world.effects.show_muzzle(Vector3.ZERO, GameEnums.DamageType.PHYSICAL)
	var remaining := world.audio.remaining[0]
	var lifetime := world.effects.spark_lifetimes[0]
	world.toggle_pause()
	world.audio._process(.5)
	world.effects._physics_process(.5)
	assert_true(world.audio.voices[0].stream_paused)
	assert_eq(world.audio.remaining[0], remaining)
	assert_eq(world.effects.spark_lifetimes[0], lifetime)
	assert_false(world.audio.play_cue("warning", Vector3.ZERO))
	world.toggle_pause()
	world.audio._process(.01)
	assert_false(world.audio.voices[0].stream_paused)
	world.start_run()
	assert_eq(world.audio.remaining[0], 0.0)
	assert_false(world.effects.sparks[0].visible)
	assert_false(world.audio.cooldowns.has("ion"))
	await wait_process_frames(2)

func test_hits_warning_and_terminal_states_route_real_combat_notifications() -> void:
	var enemy := world.spawn_enemy(world.player.position + Vector3(1, 0, 0), "charger")
	enemy.set_physics_process(false)
	enemy._physics_process(.01)
	assert_true(world.audio.cooldowns.has("warning"))
	world.player.take_damage(1)
	assert_true(world.audio.cooldowns.has("hull"))
	assert_eq(world.effects.sparks.size(), 1)
	world.player.invulnerability = 0
	world.player.take_damage(1000)
	assert_true(world.audio.cooldowns.has("defeat"))
	assert_false(world.audio.cooldowns.has("warning"))
	assert_false(world.effects.sparks[0].visible)
	world.start_run()
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	GameStateService.current_wave = world.wave_limit
	world.finish_wave()
	assert_true(world.audio.cooldowns.has("victory"))
	assert_false(world.audio.cooldowns.has("defeat"))
	await wait_process_frames(2)

func test_feedback_caps_instances_and_remains_static_in_reduced_motion() -> void:
	SettingsService.set_reduced_motion(true, false)
	for index in range(100):
		world.effects.show_muzzle(Vector3(index, 1, 0), GameEnums.DamageType.PHYSICAL)
	assert_eq(world.effects.sparks.size(), CombatEffects3D.MAX_SPARKS)
	var initial_position := world.effects.sparks[0].position
	var initial_scale := world.effects.sparks[0].scale
	world.effects._physics_process(.02)
	assert_eq(world.effects.sparks[0].position, initial_position)
	assert_eq(world.effects.sparks[0].scale, initial_scale)
	world.effects._physics_process(.1)
	assert_false(world.effects.sparks[0].visible)
	world.effects.show_muzzle(Vector3.ZERO, GameEnums.DamageType.PLASMA)
	assert_eq(world.effects.sparks.size(), CombatEffects3D.MAX_SPARKS)
	assert_true(world.effects.sparks[0].visible)
	SettingsService.set_reduced_motion(false, false)

func test_audio_and_feedback_do_not_consume_gameplay_rng() -> void:
	var state := GameRandom.gameplay.state
	world.audio.play_cue("plasma", Vector3.ZERO)
	world.effects.show_muzzle(Vector3.ZERO, GameEnums.DamageType.PLASMA)
	assert_eq(GameRandom.gameplay.state, state)

func test_matching_markers_share_resources_but_keep_independent_transforms() -> void:
	SettingsService.set_ground_markers(SettingsService.GroundMarkers.ALL, false)
	var first := world.spawn_enemy(Vector3.LEFT)
	var second := world.spawn_enemy(Vector3.RIGHT)
	assert_same(first.marker.mesh, second.marker.mesh)
	assert_same(first.marker.material_override, second.marker.material_override)
	first.marker.visible = false
	assert_true(second.marker.visible)
	assert_ne(first.position, second.position)

func test_ground_marker_modes_preserve_special_threats_and_status_feedback() -> void:
	var ordinary := world.spawn_enemy(Vector3.LEFT)
	var charger := world.spawn_enemy(Vector3.RIGHT, "charger")
	assert_false(ordinary.marker.visible)
	assert_false(world.player.marker.visible)
	assert_true(charger.marker.visible)
	ordinary.slow_marker.visible = true
	SettingsService.set_ground_markers(SettingsService.GroundMarkers.OFF, false)
	assert_false(charger.marker.visible)
	assert_true(ordinary.slow_marker.visible, "Status feedback survives cosmetic marker settings")
	SettingsService.set_ground_markers(SettingsService.GroundMarkers.ALL, false)
	assert_true(ordinary.marker.visible)
	assert_true(world.player.marker.visible)

func test_entrench_marker_is_contextual_without_changing_bonuses() -> void:
	var turret := world.turrets[0]
	world.player.position = Vector3(10, 0, 10)
	turret._tick_entrench(turret._stack_seconds() + .01)
	assert_true(turret.entrench_ring.visible, "New stack briefly announces itself")
	var bonus := turret.entrench_damage_bonus()
	turret._tick_entrench(.7)
	assert_false(turret.entrench_ring.visible, "Distant persistent ring is hidden")
	world.player.position = turret.position
	turret._update_entrench_ring()
	assert_true(turret.entrench_ring.visible, "Nearby inspection shows entrench")
	SettingsService.set_ground_markers(SettingsService.GroundMarkers.OFF, false)
	turret._update_entrench_ring()
	assert_false(turret.entrench_ring.visible)
	assert_eq(turret.entrench_damage_bonus(), bonus)

func test_core_clearance_is_only_contextual_during_placement() -> void:
	var core := CoreObjective.new()
	core.world = world
	add_child_autofree(core)
	core._refresh_markers()
	assert_false(core.footprint.visible)
	assert_false(core.clearance.visible)
	world.carried_turret = world.turrets[0]
	core._refresh_markers()
	assert_true(core.clearance.visible)
	SettingsService.set_ground_markers(SettingsService.GroundMarkers.OFF, false)
	core._refresh_markers()
	assert_false(core.clearance.visible)
	world.carried_turret = null

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
	var first := world.spawn_enemy(Vector3.LEFT)
	var second := world.spawn_enemy(Vector3.RIGHT)
	assert_same(first.marker.mesh, second.marker.mesh)
	assert_same(first.marker.material_override, second.marker.material_override)
	first.marker.visible = false
	assert_true(second.marker.visible)
	assert_ne(first.position, second.position)

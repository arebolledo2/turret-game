extends Node
var world: ArenaWorld
func _ready() -> void:
	world = ArenaWorld.new()
	world.show_hud = false
	world.auto_start = false
	world.run_config = RunConfig.slice()
	world.run_config.mode = RunConfig.MODE_CORE
	add_child(world)
	world.start_run()
	FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, false)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.effects.set_physics_process(false)
	world.player.position = Vector3(3, 0, 2)
	world.camera_rig.set_physics_process(false)
	world.camera.position = Vector3(0, 12, 12)
	world.camera.look_at(Vector3.ZERO)
	world.camera.size = 13.33
	for turret in world.turrets:
		turret.set_physics_process(false)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	await get_tree().create_timer(.5).timeout
	for i in range(4):
		var enemy := world.spawn_enemy(Vector3(i * 2.4 - 3.6, 0, -2))
		enemy.set_physics_process(false)
		enemy.health = 200
		var hit := CombatHit3D.new(13.4 + i * 6)
		hit.critical = i == 1
		if i == 2:
			hit.damage_type = GameEnums.DamageType.FIRE
			hit.burn_dps = 3
			hit.burn_duration = 3
		if i == 0 or i == 3:
			hit.damage_type = GameEnums.DamageType.ELECTRIC
		world.combat.apply_hit(enemy, hit)
	world.combat.apply_hit(world.player, CombatHit3D.new(4))
	world.damage_core(7)
	# A three-jump chain: turret -> enemy 0 -> enemy 1 -> enemy 2, each hop lighting a beat after the last.
	world.effects.show_arc(Vector3(-4.6, .7, 0), Vector3(-3.6, .45, -2), 0)
	world.effects.show_arc(Vector3(-3.6, .45, -2), Vector3(-1.2, .45, -2), 1)
	world.effects.show_arc(Vector3(-1.2, .45, -2), Vector3(1.2, .45, -2), 2)
	world.effects.show_shock(Vector3(-3.6,0,-2), 1.5)
	world.effects.show_flame(Vector3(1,.4,1), Vector3.FORWARD, 3, .25, Vector3(1,0,1))
	world.effects.visual_time = .3
	for i in range(3):
		world.effects._physics_process(.03)
	await _capture("combat-feedback-strike.png")
	for i in range(3):
		world.effects._physics_process(.03)
	await _capture("combat-feedback.png")
	get_tree().quit()

func _capture(name: String) -> void:
	await get_tree().create_timer(.1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.test-results/" + name))

extends Node

## Deterministic native evolution scene; generated captures live outside tracked assets.
var world: ArenaWorld
var frames := 0

func _ready() -> void:
	world = ArenaWorld.new()
	world.show_hud = false
	world.auto_start = false
	add_child(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.position = Vector3(0, 0, 4)
	world.camera_rig.set_physics_process(false)
	world.camera.position = Vector3(0, 9, 9)
	world.camera.look_at(Vector3(0, .5, 0))
	world.camera.size = 9.0
	world.session.state.turret_progression_enabled = true
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP)
	var machine := world.turrets[0]
	machine.position = Vector3(-3, 0, 0)
	var scatter := world.add_turret(Vector3.ZERO, "normal")
	var saber := world.add_turret(Vector3(3, 0, 0), "melee")
	var gatling := world.add_turret(Vector3(-3, 0, -3), "normal")
	var crossfire := world.add_turret(Vector3(0, 0, -3), "normal")
	var siege := world.add_turret(Vector3(3, 0, -3), "plasma")
	var actors: Array[TurretActor] = [machine, scatter, saber, gatling, crossfire, siege]
	var branches := ["machine_gun", "scatter", "saber", "machine_gun", "scatter", "siege"]
	for i in actors.size():
		var turret := actors[i]
		turret.progression.award(389 if i in [3, 4] else 110)
		turret.evolve(branches[i])
		if i in [3, 4]:
			turret.evolve(branches[i])
		turret.aim.rotation.y = PI - .4
		turret.set_physics_process(false)
		turret.reset_physics_interpolation()
		var label := Label3D.new()
		label.text = turret.display_name()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = turret.position + Vector3(0, 2.0, 0)
		label.font_size = 44
		label.pixel_size = .005
		world.add_child(label)

func _process(_delta: float) -> void:
	frames += 1
	if frames == 45:
		capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://.test-results/evolution-preview.png")
	get_viewport().get_texture().get_image().save_png(output)
	print("EVOLUTION_PREVIEW ", output)
	get_tree().quit()

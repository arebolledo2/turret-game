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
	if "--saber-preview" in OS.get_cmdline_user_args():
		world.turrets[0].visible = false
		for i in range(3):
			var turret := world.add_turret(Vector3(i * 3 - 3, 0, 0), "melee")
			turret.set_physics_process(false)
			turret.progression.award(1500)
			var path: Array = [["saber"], ["saber", "orbit_saber"], ["saber", "stormblade"]][i]
			for form: String in path:
				turret.evolve(form)
			turret.aim.rotation.y = PI * .65
		return
	if "--sniper-preview" in OS.get_cmdline_user_args():
		# Base, Piercer Rifle, Horizon Piercer and Overwatch side by side; --yaw=<degrees> turns the rifles (default 150).
		var yaw := 150.0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--yaw="):
				yaw = float(argument.trim_prefix("--yaw="))
		world.turrets[0].visible = false
		world.camera.position = Vector3(0, 5.5, 7.5)
		world.camera.look_at(Vector3(0, .6, 0))
		world.camera.size = 7.5
		for i in range(4):
			var turret := world.add_turret(Vector3((i - 1.5) * 2.4, 0, 0), "sniper")
			turret.set_physics_process(false)
			turret.progression.award(389)
			for form: String in [[], ["piercer_rifle"], ["piercer_rifle", "horizon_piercer"], ["piercer_rifle", "overwatch"]][i]:
				turret.evolve(form)
			turret.aim.rotation.y = deg_to_rad(yaw)
			turret.reset_physics_interpolation()
			var label := Label3D.new()
			label.text = turret.display_name()
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = turret.position + Vector3(0, 2.0, 0)
			label.font_size = 44
			label.pixel_size = .005
			world.add_child(label)
		return
	if "--quake-preview" in OS.get_cmdline_user_args():
		# Quake, Aftershock, Tectonic and Cataclysm side by side; --yaw=<degrees> turns the cube (default 0), --low pulls the camera down.
		var yaw := 0.0
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--yaw="):
				yaw = float(argument.trim_prefix("--yaw="))
		world.turrets[0].visible = false
		world.camera.position = Vector3(0, 5.5, 7.5)
		world.camera.look_at(Vector3(0, .6, 0))
		world.camera.size = 8.5
		for i in range(4):
			var turret := world.add_turret(Vector3((i - 1.5) * 2.8, 0, 0), "quake")
			turret.set_physics_process(false)
			turret.progression.award(1500)
			for form: String in [[], ["aftershock"], ["aftershock", "tectonic"], ["aftershock", "cataclysm"]][i]:
				turret.evolve(form)
			turret.aim.rotation.y = deg_to_rad(yaw)
			turret.reset_physics_interpolation()
			var label := Label3D.new()
			label.text = turret.display_name()
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = turret.position + Vector3(0, 2.0, 0)
			label.font_size = 44
			label.pixel_size = .005
			world.add_child(label)
		return
	if "--flame-preview" in OS.get_cmdline_user_args():
		world.turrets[0].visible = false
		world.effects.set_physics_process(false)
		for i in range(2):
			var turret := world.add_turret(Vector3(i * 5 - 2.5, 0, 1), "flamethrower")
			turret.set_physics_process(false)
			turret.progression.award(1500)
			var path: Array = [["wide_flame", "inferno_crown"], ["wide_flame", "dragonheart"]][i]
			for form: String in path:
				turret.evolve(form)
			var stats := turret._current_view(0)
			turret._fire_flame(stats, stats.range_metres, Vector3.FORWARD)
		return
	if "--expansion-preview" in OS.get_cmdline_user_args():
		world.turrets[0].visible = false
		for i in range(3):
			var turret := world.add_turret(Vector3((i - 1) * 3, 0, 0), ["bow", "flamethrower", "bowling"][i])
			turret.set_physics_process(false)
			turret.aim.rotation.y = PI - .4
		var gunblade := ClockworkModels.instantiate("gunblade")
		world.add_child(gunblade)
		gunblade.position = Vector3(0, 0, -3)
		gunblade.rotation.y = PI - .4
		for i in range(2):
			var projectile := ClockworkModels.instantiate(["arrow", "bowling_ball"][i])
			world.add_child(projectile)
			projectile.position = Vector3((i * 2 - 1) * 2, .5, -3)
			projectile.rotation.y = PI - .4
		return
	var machine := world.turrets[0]
	machine.position = Vector3(-3, 0, 0)
	var omnifire := world.add_turret(Vector3.ZERO, "normal")
	var saber := world.add_turret(Vector3(3, 0, 0), "melee")
	var gatling := world.add_turret(Vector3(-3, 0, -3), "normal")
	var repeater := world.add_turret(Vector3(0, 0, -3), "bow")
	var siege := world.add_turret(Vector3(3, 0, -3), "plasma")
	var actors: Array[TurretActor] = [machine, omnifire, saber, gatling, repeater, siege]
	var paths: Array = [["machine_gun"], ["machine_gun", "omnifire"], ["saber"], ["machine_gun", "cyclone_gatling"], ["repeater_bow"], ["siege"]]
	for i in actors.size():
		var turret := actors[i]
		turret.progression.award(389 if i in [1, 3] else 110)
		for form: String in paths[i]:
			turret.evolve(form)
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
	var filename := "saber-preview.png" if "--saber-preview" in OS.get_cmdline_user_args() else "flame-preview.png" if "--flame-preview" in OS.get_cmdline_user_args() else "expansion-preview.png" if "--expansion-preview" in OS.get_cmdline_user_args() else "sniper-preview.png" if "--sniper-preview" in OS.get_cmdline_user_args() else "quake-preview.png" if "--quake-preview" in OS.get_cmdline_user_args() else "evolution-preview.png"
	var output := ProjectSettings.globalize_path("res://.test-results/" + filename)
	get_viewport().get_texture().get_image().save_png(output)
	print("EVOLUTION_PREVIEW ", output)
	get_tree().quit()

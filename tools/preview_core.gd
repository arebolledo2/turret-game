extends Node

## Actual arena lighting and runtime reactor; close, gameplay and damage-state captures.
func _ready() -> void:
	var world := preload("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	world.show_hud = false
	add_child(world)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.position = Vector3(1.5, 0, .8)
	world.player.reset_physics_interpolation()
	for turret in world.turrets:
		turret.hide()
		turret.set_physics_process(false)
	SettingsService.set_ground_markers(SettingsService.GroundMarkers.CONTEXTUAL, false)
	var core := world.core
	if not core:
		core = CoreObjective.new()
		core.world = world
		world.actor_root.add_child(core)
	core.reset(100.0)
	world.camera_rig.set_physics_process(false)
	var camera := world.camera_rig.camera
	camera.position = Vector3(3, 3.5, 5)
	camera.look_at(Vector3(0, .75, 0))
	camera.size = 3.4
	camera.reset_physics_interpolation()
	world.player.hide()
	for i in range(90):
		await get_tree().physics_frame
	await capture("core-close")
	if "--motion-preview" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.test-results/core-motion"))
		for frame in range(60):
			for step in range(6):
				await get_tree().physics_frame
			await capture("core-motion/frame%03d" % frame)
	for i in range(90):
		await get_tree().physics_frame
	await capture("core-rotated")
	core.take_hit(80.0)
	for i in range(30):
		await get_tree().physics_frame
	await capture("core-critical")
	core.take_hit(20.0)
	for i in range(20):
		await get_tree().physics_frame
	await capture("core-destroyed")
	core.reset(100.0)
	world.player.show()
	world.add_turret(Vector3(-1.9, 0, 1.0), "normal")
	camera.position = CameraRig.OFFSET
	camera.look_at(Vector3.ZERO)
	camera.size = world.camera_rig.view_size(GameConstants.CAMERA_DEFAULT_ZOOM)
	camera.reset_physics_interpolation()
	for i in range(30):
		await get_tree().physics_frame
	await capture("core-gameplay")
	print("CORE_CAPTURE_COMPLETE")
	get_tree().quit()

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.test-results/%s.png" % label))

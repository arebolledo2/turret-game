extends Node

func _ready() -> void:
	var world := preload("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	world.show_hud = false
	add_child(world)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.hide()
	world.player.position = Vector3.ZERO
	SettingsService.set_ground_markers(SettingsService.GroundMarkers.ALL, false)
	for turret in world.turrets:
		turret.hide()
		turret.set_physics_process(false)
	for i in range(3):
		var zone := BuildZoneActor.new()
		world.actor_root.add_child(zone)
		zone.position = Vector3(-4.5 + i * 4.5, 0, -2.0)
		zone.setup("turret", "plasma", i)
		zone.warning_left = 2.0 if i == 0 else 0.0
		zone.progress = [0.0, .36, .78][i]
		zone.occupied = i == 1
		zone.refresh()
		var turret := world.add_turret(Vector3(-4.5 + i * 4.5, 0, 2.1), "normal")
		turret.set_physics_process(false)
		turret.stay_time = turret._stack_seconds() * float(i + 1)
		turret._tick_entrench(0)
	world.camera_rig.set_zoom(.85)
	world.camera_rig.snap()
	for i in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.test-results/ground-dials.png"))
	print("GROUND_DIAL_CAPTURE_COMPLETE")
	get_tree().quit()

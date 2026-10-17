extends Node

## Captures every telegraph shape at several fill levels: `godot --path . res://tools/preview_telegraphs.tscn`.
func _ready() -> void:
	var world := preload("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	world.show_hud = false
	add_child(world)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.player.hide()
	for turret in world.turrets:
		turret.hide()
		turret.set_physics_process(false)
	var progress := [.15, .5, .85]
	for column in 3:
		var x := -9.0 + column * 4.5
		var line := Telegraph.create(world.actor_root, Telegraph.Shape.LINE, Telegraph.CHARGE)
		Telegraph.place_line(line, Vector3(x, 0, 6.0), Vector3.FORWARD, 4.0, 1.0)
		Telegraph.set_progress(line, progress[column])
		var circle := Telegraph.create(world.actor_root, Telegraph.Shape.CIRCLE, Telegraph.BLAST)
		Telegraph.place_circle(circle, Vector3(x, 0, 0.0), 1.3)
		Telegraph.set_progress(circle, progress[column])
		var cone := Telegraph.create(world.actor_root, Telegraph.Shape.SECTOR, Telegraph.SWEEP)
		Telegraph.place_sector(cone, Vector3(x, 0, -2.2), Vector3.BACK, 3.0, .7)
		Telegraph.set_progress(cone, progress[column])
	var thin := Telegraph.create(world.actor_root, Telegraph.Shape.LINE, Telegraph.SHOT)
	Telegraph.place_line(thin, Vector3(6.0, 0, 6.0), Vector3.FORWARD, 6.0, .025)
	Telegraph.set_progress(thin, .6)
	var pulse := Telegraph.create(world.actor_root, Telegraph.Shape.SECTOR, Telegraph.BLAST)
	Telegraph.place_sector(pulse, Vector3(9.5, 0, 2.0), Vector3.FORWARD, 3.0, PI - .5, true)
	Telegraph.set_progress(pulse, .7)
	world.camera_rig.set_zoom(.85)
	world.camera_rig.snap()
	for i in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.test-results/telegraphs.png"))
	print("TELEGRAPH_CAPTURE_COMPLETE")
	get_tree().quit()

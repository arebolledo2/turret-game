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
	var progress := [.2, .5, .8, .97]
	for column in 4:
		var x := -7.5 + column * 5.0
		var line := Telegraph.create(world.actor_root, Telegraph.Shape.LINE, Telegraph.CHARGE)
		Telegraph.place_line(line, Vector3(x, 0, 6.0), Vector3.FORWARD, 3.6, .9)
		Telegraph.set_progress(line, progress[column])
		var circle := Telegraph.create(world.actor_root, Telegraph.Shape.CIRCLE, Telegraph.BLAST)
		Telegraph.place_circle(circle, Vector3(x, 0, 0.8), 1.2)
		Telegraph.set_progress(circle, progress[column])
		var cone := Telegraph.create(world.actor_root, Telegraph.Shape.SECTOR, Telegraph.SWEEP)
		Telegraph.place_sector(cone, Vector3(x, 0, -4.2), Vector3.BACK, 2.6, .7)
		Telegraph.set_progress(cone, progress[column])
	world.camera_rig.set_zoom(.85)
	world.camera_rig.snap()
	for i in range(30):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://.test-results/telegraphs.png"))
	print("TELEGRAPH_CAPTURE_COMPLETE")
	get_tree().quit()

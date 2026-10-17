extends Node

## Rendered review of the death shatter: kills a few enemies in a real arena and saves the shard flight at fixed ages.
##   godot --path . res://tools/capture_shatter.tscn -- [--enemy=drowse] [--zoom=2.0] [--live]
## Writes .test-results/shatter-<enemy>-NN.png per age and shatter-<enemy>-sheet.png with all of them side by side.
## `--live` skips the fixed ages and lets the shatter play in real time (for a screen recording).
const AGES: Array[float] = [0.0, .05, .12, .22, .34, .48, .64, .82, 1.0, 1.2]
const COLUMNS: int = 5
const CELL := Vector2i(512, 288)

var world: ArenaWorld
var enemy_type := "drowse"
var zoom := 2.0
var live := false
var corpses: Array[DeathShatter] = []

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--enemy="):
			enemy_type = arg.trim_prefix("--enemy=")
		elif arg.begins_with("--zoom="):
			zoom = float(arg.trim_prefix("--zoom="))
		elif arg == "--live":
			live = true
	world = ArenaWorld.new()
	world.auto_start = false
	world.run_config = RunConfig.new()
	add_child(world)
	world.start_run()
	world.set_physics_process(false)
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	world.player.set_physics_process(false)
	world.player.position = Vector3(0, 0, .2) # the camera follows the (hidden) hero
	world.player.hide()
	if world.core:
		world.core.set_physics_process(false)
		world.core.hide()
	for turret in world.turrets:
		turret.set_physics_process(false)
		turret.hide()
	world.hud.hide()
	var victims: Array[CombatActor] = []
	for spot in [Vector3(-1.5, 0, .4), Vector3(.1, 0, -.3), Vector3(1.6, 0, .5)]:
		var enemy := world.spawn_enemy(spot, enemy_type)
		enemy.set_physics_process(false)
		enemy.visual.rotation.y = PI - .35 + spot.x * .4
		victims.append(enemy)
	world.camera_rig.set_zoom(zoom)
	world.camera_rig.snap()
	world.camera_rig.set_physics_process(false)
	for frame in 6:
		await get_tree().process_frame
		for enemy in victims:
			if enemy.ecology_motion:
				enemy.ecology_motion.tick(.1, true, false, false)
	for enemy in victims:
		enemy.take_damage(enemy.health + 1.0)
	for node in world.actor_root.get_children():
		if node is DeathShatter:
			corpses.append(node)
	print("SHATTER_CORPSES ", corpses.size(), " of ", victims.size(), " (", DeathDissolve.active_count, " dissolving)")
	if live:
		return
	var frames: Array[Image] = []
	for corpse in corpses:
		corpse.set_process(false)
	for age in AGES:
		for corpse in corpses:
			corpse._process(age - corpse.age)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := ProjectSettings.globalize_path("res://.test-results/shatter-%s-%02d.png" % [enemy_type, frames.size()])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		image.save_png(path)
		frames.append(image)
	_save_sheet(frames)
	get_tree().quit()

func _save_sheet(frames: Array[Image]) -> void:
	var rows := ceili(float(frames.size()) / COLUMNS)
	var sheet := Image.create(CELL.x * COLUMNS, CELL.y * rows, false, Image.FORMAT_RGB8)
	for index in frames.size():
		var cell := frames[index].duplicate() as Image
		cell.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(cell, Rect2i(Vector2i.ZERO, CELL), Vector2i(index % COLUMNS, index / COLUMNS) * CELL)
	var path := ProjectSettings.globalize_path("res://.test-results/shatter-%s-sheet.png" % enemy_type)
	sheet.save_png(path)
	print("SHATTER_SHEET ", path)

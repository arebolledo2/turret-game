extends Node

## Developer visual check for the room's alert state (ArenaRoom.set_alert). Needs a rendering driver (not --headless):
##   Godot --path . --resolution 1920x1080 res://tools/preview_room_alert.tscn -- --theme=foundry [--tag=_f]
##       [--shot=name,tx,tz,size,amount,pulse_seconds]...
## Builds the real arena (no staged actors), freezes the room at the given alert amount (0 calm, 1 full, in the boss wave colour) and
## `pulse_seconds` into the pulse (0 is the brightest, ArenaRoom.ALERT_PERIOD / 2 the dimmest) and writes
## .test-results/floor/alert_<theme>_<name><tag>.png from the game's camera angle (`size` is the vertical orthographic size in metres,
## target at ground point tx, tz; size 34 with tx = tz = 0 is the whole room).
const LAYOUTS := {"foundry": "crossroads", "concrete": "highlands", "grating": "sump", "hexworks": "hive", "marquetry": "parlour", "orrery": "observatory", "mosaic": "bathhouse", "frost": "glacier"}
const GAME_OFFSET := Vector3(0, 17, 13)

var theme := "foundry"
var tag := ""
var shots: Array[PackedStringArray] = []
var world: ArenaWorld

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--theme="):
			theme = argument.trim_prefix("--theme=")
		elif argument.begins_with("--tag="):
			tag = argument.trim_prefix("--tag=")
		elif argument.begins_with("--shot="):
			shots.append(argument.trim_prefix("--shot=").split(","))
	if shots.is_empty():
		shots.append(PackedStringArray(["calm", "0", "0", "34", "0", "0"]))
		shots.append(PackedStringArray(["alert", "0", "0", "34", "1", "0"]))
		shots.append(PackedStringArray(["dim", "0", "0", "34", "1", str(ArenaRoom.ALERT_PERIOD * 0.5)]))
	call_deferred("run")

func run() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.TERRAIN_ZONES, true)
	GameRandom.gameplay.seed = 42
	world = ArenaWorld.new()
	world.show_hud = false
	world.run_config = RunConfig.new()
	world.run_config.layout_id = LAYOUTS.get(theme, "crossroads")
	add_child(world)
	world.waves.remaining_spawns = 0
	world.preparation.deploy()
	world.waves.announcement_left = 0
	world.stage.set_floor_theme(theme)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.camera_rig.set_physics_process(false)
	var room := world.stage.room
	for shot in shots:
		room.set_process(true)
		room.set_alert(ArenaStage.SEAM_BOSS, float(shot[4]), 0.0)
		room._alert_clock = float(shot[5])
		room._apply_alert()
		room.set_process(false) # hold the pulse where it is for the picture
		var camera := world.camera
		var target := Vector3(float(shot[1]), 0.0, float(shot[2]))
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = float(shot[3])
		camera.position = target + GAME_OFFSET
		camera.look_at(target, Vector3.UP)
		camera.reset_physics_interpolation()
		for i in range(24):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output := ProjectSettings.globalize_path("res://.test-results/floor/alert_%s_%s%s.png" % [theme, shot[0], tag])
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		get_viewport().get_texture().get_image().save_png(output)
		print("ALERT_PREVIEW ", output)
	get_tree().quit()

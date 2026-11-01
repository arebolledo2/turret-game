extends Node

## Developer visual check for the ship exterior (scripts/game/ship_exterior.gd). Needs a rendering driver (not --headless):
##   Godot --path . --resolution 1920x1080 res://tools/preview_exterior.tscn -- --theme=foundry [--space=deep_space] [--tag=_e]
##       [--zoom=0.75] [--player=x,z] [--shot=name,tx,tz,size[,ox,oy,oz[,ty]]]...
## Runs the real arena (no staged actors) and writes .test-results/floor/exterior_<theme>_<shot><tag>.png. Shots: `default` and
## `wide` are as in preview_floor_theme; a custom `--shot` aims an orthographic camera at the ground point (tx, ty, tz) from
## the game's fixed offset (0, 17, 13) unless an offset is given; `size` is the vertical orthographic size in metres
## (a screen metre is 1.26 ground metres deep). Use several `--shot` flags for several images.
const LAYOUTS := {"foundry": "crossroads", "concrete": "highlands", "grating": "sump", "hexworks": "hive", "marquetry": "parlour", "orrery": "observatory", "mosaic": "bathhouse", "frost": "glacier"}
const GAME_OFFSET := Vector3(0, 17, 13)

var theme := "foundry"
var tag := ""
var space_theme := ""
var zoom := 0.75
var player_at := Vector3.ZERO
var shots: Array[PackedStringArray] = []
var world: ArenaWorld

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--theme="):
			theme = argument.trim_prefix("--theme=")
		elif argument.begins_with("--tag="):
			tag = argument.trim_prefix("--tag=")
		elif argument.begins_with("--space="):
			space_theme = argument.trim_prefix("--space=")
		elif argument.begins_with("--zoom="):
			zoom = float(argument.trim_prefix("--zoom="))
		elif argument.begins_with("--player="):
			var parts := argument.trim_prefix("--player=").split(",")
			player_at = Vector3(float(parts[0]), 0, float(parts[1]))
		elif argument.begins_with("--shot="):
			shots.append(argument.trim_prefix("--shot=").split(","))
	if shots.is_empty():
		shots.append(PackedStringArray(["default"]))
		shots.append(PackedStringArray(["wide"]))
	call_deferred("run")

func run() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.TERRAIN_ZONES, true)
	GameRandom.gameplay.seed = 42
	world = ArenaWorld.new()
	world.show_hud = false
	world.run_config = RunConfig.new()
	world.run_config.layout_id = LAYOUTS.get(theme, "crossroads")
	world.run_config.space_theme = space_theme
	add_child(world)
	world.waves.remaining_spawns = 0
	world.preparation.deploy()
	world.waves.announcement_left = 0
	world.stage.set_floor_theme(theme)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.camera_rig.set_physics_process(false)
	for shot in shots:
		_frame(shot)
		for i in range(24):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output := ProjectSettings.globalize_path("res://.test-results/floor/exterior_%s_%s%s.png" % [theme, shot[0], tag])
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		get_viewport().get_texture().get_image().save_png(output)
		print("EXTERIOR_PREVIEW ", output)
	get_tree().quit()

func _frame(shot: PackedStringArray) -> void:
	var camera := world.camera
	var rig := world.camera_rig
	match shot[0]:
		"default":
			world.player.position = player_at
			rig.set_zoom(zoom)
			rig.snap()
		"wide":
			camera.size = 34
			camera.position = Vector3(0, 35, 25)
			camera.look_at(Vector3.ZERO)
		_:
			var target := Vector3(float(shot[1]), float(shot[7]) if shot.size() > 7 else 0.0, float(shot[2]))
			var offset := GAME_OFFSET
			if shot.size() > 6:
				offset = Vector3(float(shot[4]), float(shot[5]), float(shot[6]))
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = float(shot[3])
			camera.position = target + offset
			camera.look_at(target, Vector3.UP if absf(offset.normalized().y) < 0.99 else Vector3.FORWARD)
	camera.reset_physics_interpolation()

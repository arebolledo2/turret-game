extends Node

## Developer visual check for the floor texture themes (tools/build_floor_textures.py). Needs a rendering driver (not --headless):
##   Godot --path . --resolution 1920x1080 res://tools/preview_floor_theme.tscn -- --theme=concrete [--imported] [--shots=default,close,macro,top]
## Runs the real arena (ArenaWorld, ArenaStage lighting, FloorDecals, zone overlays, camera rig) with a staged scene of turrets,
## enemies and pickups and writes .test-results/floor/<theme>_<shot>.png. The floor material is the shipping one
## (WorldGeometry.floor_material through ArenaStage.set_floor_theme). By default its four textures are swapped for the PNGs read
## straight from disk, so no import step is needed while iterating; `--imported` keeps the imported resources (the faithful path).
##
## Shots: default = gameplay zoom 0.75 (about 80 px/m at 1080p), close = about 150 px/m, macro = max zoom 2.0 (about 216 px/m),
## top = straight down over 2 x 2 tiles for seam checks, wide = the whole arena. `--zoom=` overrides the zoom of default/close.
const FOCI := {"foundry": Vector3(-7, 0, 0), "concrete": Vector3(-9, 0, -3), "grating": Vector3(-9, 0, 0)}
const LAYOUTS := {"foundry": "crossroads", "concrete": "highlands", "grating": "sump"}
const ZOOMS := {"default": 0.75, "close": 1.39, "macro": 2.0}

var theme := "foundry"
var shots: PackedStringArray = ["default", "close", "macro", "top"]
var tag := ""
var use_imported := false
var zoom_override := -1.0
var focus := Vector3.ZERO
var world: ArenaWorld

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--theme="):
			theme = argument.trim_prefix("--theme=")
		elif argument.begins_with("--shots="):
			shots = argument.trim_prefix("--shots=").split(",")
		elif argument.begins_with("--tag="):
			tag = argument.trim_prefix("--tag=")
		elif argument.begins_with("--zoom="):
			zoom_override = float(argument.trim_prefix("--zoom="))
		elif argument.begins_with("--focus="):
			var parts := argument.trim_prefix("--focus=").split(",")
			focus = Vector3(float(parts[0]), 0, float(parts[1]))
		elif argument == "--imported":
			use_imported = true
	if focus == Vector3.ZERO:
		focus = FOCI.get(theme, Vector3.ZERO)
	call_deferred("run")

func run() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.TERRAIN_ZONES, true)
	FeatureFlagService.set_enabled(FeatureFlagService.ZONE_READABILITY, true)
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
	if not use_imported:
		_load_textures_from_disk()
	_stage_actors()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.camera_rig.set_physics_process(false)
	for shot in shots:
		_frame(shot)
		for i in range(24):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output := ProjectSettings.globalize_path("res://.test-results/floor/%s_%s%s.png" % [theme, shot, tag])
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		get_viewport().get_texture().get_image().save_png(output)
		print("FLOOR_PREVIEW ", output)
	get_tree().quit()

func _disk_texture(file: String) -> ImageTexture:
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/floor/%s/floor_%s.png" % [theme, file]))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _load_textures_from_disk() -> void:
	var material := world.stage.floor_visual.material_override as StandardMaterial3D
	material.albedo_texture = _disk_texture("albedo")
	material.roughness_texture = _disk_texture("roughness")
	material.normal_texture = _disk_texture("normal")
	material.emission_texture = _disk_texture("emission")

func _stage_actors() -> void:
	var kinds := ["basic", "fast", "tank", "charger", "exploder"]
	for index in range(16):
		var angle := float(index) * 2.39996
		var ring := 2.0 + float(index % 5) * 1.1
		var enemy := world.spawn_enemy(focus + Vector3(cos(angle) * ring * 1.5, 0, sin(angle) * ring), kinds[index % kinds.size()])
		enemy.set_physics_process(false)
	world.add_turret(focus + Vector3(-2.2, 0, 0.6), "plasma")
	world.add_turret(focus + Vector3(2.2, 0, 0.6), "shock")
	world.add_turret(focus + Vector3(0, 0, -2.4), "tesla")
	world.player.position = focus + Vector3(0, 0, 1.4)
	world.drops.spawn(focus + Vector3(1.0, 0, 3.0)).set_physics_process(false)

func _frame(shot: String) -> void:
	var camera := world.camera
	var rig := world.camera_rig
	match shot:
		"default", "close", "macro":
			rig.set_zoom(zoom_override if zoom_override > 0.0 and shot != "macro" else ZOOMS[shot])
			rig.snap()
		"wide":
			camera.size = 34
			camera.position = Vector3(0, 35, 25)
			camera.look_at(Vector3.ZERO)
		"top":
			camera.size = WorldGeometry.FLOOR_TILE_METRES * 2.0
			camera.position = focus + Vector3(0, 40, 0)
			camera.look_at(focus, Vector3.FORWARD)
	camera.reset_physics_interpolation()

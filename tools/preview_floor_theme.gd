extends Node

## Developer visual check for the floor texture themes (tools/build_floor_textures.py). Needs a rendering driver (not --headless):
##   Godot --path . res://tools/preview_floor_theme.tscn -- --theme=concrete [--layout=highlands] [--shots=wide,game,top,detail]
## Loads the theme's PNGs straight from disk (no import step), puts them on the real arena floor with the real lighting, zone
## overlays, turrets and enemies, and writes .test-results/floor/<theme>_<shot>.png.
const LAYOUTS := {"foundry": "crossroads", "concrete": "highlands", "grating": "sump"}
## Material settings each theme was authored against (mirror these in WorldGeometry.floor_material).
const METALLIC := {"foundry": 0.3, "concrete": 0.05, "grating": 0.15}
const EMISSION_ENERGY := {"foundry": 0.9, "concrete": 0.9, "grating": 0.9}

var theme := "foundry"
var layout := ""
var metallic_override := -1.0
var tag := ""
var use_imported := false
var debug_flat := false
var debug_rough := -1.0
var shots: PackedStringArray = ["wide", "game", "top", "detail"]
var world: ArenaWorld

func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--theme="):
			theme = argument.trim_prefix("--theme=")
		elif argument.begins_with("--layout="):
			layout = argument.trim_prefix("--layout=")
		elif argument.begins_with("--metallic="):
			metallic_override = float(argument.trim_prefix("--metallic="))
		elif argument == "--imported":
			use_imported = true
		elif argument == "--flat":
			debug_flat = true
		elif argument.begins_with("--rough="):
			debug_rough = float(argument.trim_prefix("--rough="))
		elif argument.begins_with("--tag="):
			tag = argument.trim_prefix("--tag=")
		elif argument.begins_with("--shots="):
			shots = argument.trim_prefix("--shots=").split(",")
	if layout.is_empty():
		layout = LAYOUTS.get(theme, "crossroads")
	call_deferred("run")

func run() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.TERRAIN_ZONES, true)
	FeatureFlagService.set_enabled(FeatureFlagService.ZONE_READABILITY, true)
	GameRandom.gameplay.seed = 42
	world = ArenaWorld.new()
	world.show_hud = false
	world.run_config = RunConfig.new()
	world.run_config.layout_id = layout
	add_child(world)
	world.waves.remaining_spawns = 0
	_swap_floor()
	_stage_actors()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.camera_rig.set_physics_process(false)
	for shot in shots:
		_frame(shot)
		for i in range(20):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var output := ProjectSettings.globalize_path("res://.test-results/floor/%s_%s%s.png" % [theme, shot, tag])
		DirAccess.make_dir_recursive_absolute(output.get_base_dir())
		get_viewport().get_texture().get_image().save_png(output)
		print("FLOOR_PREVIEW ", output)
	get_tree().quit()

func _texture(file: String) -> Texture2D:
	if use_imported:
		return load("res://assets/textures/floor/%s/floor_%s.png" % [theme, file])
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/textures/floor/%s/floor_%s.png" % [theme, file]))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _swap_floor() -> void:
	var instance: MeshInstance3D = world.stage.floor_visual if "floor_visual" in world.stage else null
	if instance == null:
		for node in world.find_children("*", "MeshInstance3D", true, false):
			if (node as MeshInstance3D).mesh is PlaneMesh:
				instance = node
				break
	var area: Vector2 = (instance.mesh as PlaneMesh).size
	var material := StandardMaterial3D.new()
	material.albedo_texture = _texture("albedo")
	material.roughness = 1.0
	material.roughness_texture = _texture("roughness")
	material.metallic = metallic_override if metallic_override >= 0.0 else METALLIC.get(theme, 0.3)
	material.normal_enabled = true
	material.normal_texture = _texture("normal")
	material.emission_enabled = true
	material.emission_texture = _texture("emission")
	material.emission_energy_multiplier = EMISSION_ENERGY.get(theme, 0.9)
	material.uv1_scale = Vector3(area.x / WorldGeometry.FLOOR_TILE_METRES, area.y / WorldGeometry.FLOOR_TILE_METRES, 1.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if debug_flat:
		material.normal_enabled = false
	if debug_rough >= 0.0:
		material.roughness_texture = null
		material.roughness = debug_rough
	instance.material_override = material

func _stage_actors() -> void:
	var kinds := ["basic", "fast", "tank", "charger", "exploder"]
	for index in range(14):
		var angle := float(index) * 2.39996
		var enemy := world.spawn_enemy(Vector3(cos(angle) * (3.0 + index % 5) * 1.5, 0, sin(angle) * (3.0 + index % 5) * 0.8), kinds[index % kinds.size()])
		enemy.set_physics_process(false)
	world.add_turret(Vector3(-3, 0, 0), "plasma")
	world.add_turret(Vector3(3, 0, 0), "shock")
	world.player.position = Vector3(0, 0, 2)

func _frame(shot: String) -> void:
	var camera := world.camera
	match shot:
		"wide":
			camera.size = 34
			camera.position = Vector3(0, 35, 25)
			camera.look_at(Vector3.ZERO)
		"game":
			camera.size = 34.0 / 1.5 # about the in-game 0.75x zoom
			camera.position = Vector3(0, 35, 25) * 0.5 + Vector3(-4, 0, 0)
			camera.look_at(Vector3(-4, 0, 0))
		"top":
			camera.size = WorldGeometry.FLOOR_TILE_METRES * 2.0
			camera.position = Vector3(0, 40, 0)
			camera.look_at(Vector3.ZERO, Vector3.FORWARD)
		"detail":
			camera.size = 9.0
			camera.position = Vector3(5, 35, 25) * 0.5
			camera.look_at(Vector3(5, 0, 0))
	camera.reset_physics_interpolation()

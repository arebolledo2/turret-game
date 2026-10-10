extends Node3D

## Render actual imported rigs with the game controller. This scene is not a benchmark.
const ORDER := ["hero", "basic", "fast", "tank", "charger", "exploder", "dropbox", "ion", "plasma", "tesla", "shock", "melee"]
var models: Dictionary = {}
var motions: Dictionary = {}
var aims: Dictionary = {}
var frame: int = 0
var phase: float = 0.0
var output: String

func _ready() -> void:
	output = ProjectSettings.globalize_path("res://.test-results/clockwork-motion")
	DirAccess.make_dir_recursive_absolute(output)
	var environment := WorldEnvironment.new()
	var lighting := Environment.new()
	lighting.background_mode = Environment.BG_COLOR
	lighting.background_color = Color("132936")
	lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	lighting.ambient_light_color = Color("b8d4db")
	lighting.ambient_light_energy = .65
	lighting.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	lighting.tonemap_white = 6.0
	environment.environment = lighting
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.4
	camera.position = Vector3(0, 10, 13)
	camera.look_at(Vector3(0, .3, 0))
	camera.current = true
	WorldGeometry.box(self, Vector3(15, .08, 12), Vector3(0, -.05, 0), WorldGeometry.material(Color("253d49")))
	for index in range(ORDER.size()):
		var key: String = ORDER[index]
		var at := Vector3(float(index % 4) * 3.1 - 4.65, 0, float(index / 4) * 3.0 - 3.0)
		var label := Label3D.new()
		label.text = key + (" (pending)" if not ClockworkModels.available(key) else "")
		label.position = at + Vector3(0, .02, 1.15)
		label.rotation_degrees.x = -65
		label.pixel_size = .006
		label.font_size = 36
		add_child(label)
		if not ClockworkModels.available(key):
			continue
		var model := ClockworkModels.instantiate(key)
		add_child(model)
		model.position = at
		model.rotation.y = PI - .3
		models[key] = model
		if key in ["hero", "basic", "fast", "tank", "charger", "exploder"]:
			motions[key] = ClockworkMotion.new(model, key)
			motions[key].hover_phase = 0.0
		var aim := model.find_child("Aim", true, false) as Node3D
		if aim:
			aims[key] = aim
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _physics_process(delta: float) -> void:
	phase += delta
	for key: String in motions:
		var motion: ClockworkMotion = motions[key]
		motion.tick(delta, 1.8, false, key == "hero" and phase > 2.0)
		if key == "hero":
			motion.aim_hero(Vector3(sin(phase) * .6, 0, 1))
			if fmod(phase, .5) < delta:
				motion.fire(false)
	for key: String in aims:
		if key != "shock":
			aims[key].rotation.y = phase * 2.0 if key == "melee" else sin(phase) * .5

func _process(_delta: float) -> void:
	frame += 1
	# With --fixed-fps 30 these samples cover four seconds of real controller poses.
	if frame in [15, 30, 45, 60, 75, 90, 105, 120]:
		capture.call_deferred(frame)

func capture(number: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join("pose-%03d.png" % number))
	if number == 120:
		print("MOTION_PREVIEW ", JSON.stringify({"models": models.keys(), "frames": 8, "output": output}))
		get_tree().quit()

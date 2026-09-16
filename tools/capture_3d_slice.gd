extends Node

## Developer visual check. Run with a rendering driver (not --headless).
## Screenshots and timings go to ignored .test-results, never player saves.
var world: SliceWorld
var frames: int = 0
var samples: Array[float] = []
var stress: bool = false
var shop: bool = false
var last_tick: int = 0

func _ready() -> void:
	call_deferred("setup")

func setup() -> void:
	world = load("res://scenes/three_d/proving_ground.tscn").instantiate() as SliceWorld
	add_child(world)
	world.remaining_spawns = 0
	world.announcement_left = 0
	world.player.invulnerability = 999
	stress = "--stress" in OS.get_cmdline_user_args()
	shop = "--shop" in OS.get_cmdline_user_args()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameRandom.gameplay.seed = 42
	for index in range(150 if stress else 18):
		var angle := float(index) * 2.39996
		var radius := 2.5 + float(index % 6) * .5
		var enemy := world.spawn_enemy(Vector3(cos(angle) * radius * 1.4, 0, sin(angle) * radius * .7))
		if stress:
			enemy.health = 10000
			enemy.speed = .15
	world.add_turret(Vector3(-3, 0, 0))
	world.add_turret(Vector3(3, 0, 0))
	if stress:
		for index in range(7):
			world.add_turret(Vector3(-6 + index * 2, 0, -2))
	last_tick = Time.get_ticks_usec()

func _process(_delta: float) -> void:
	if not is_instance_valid(world):
		return
	frames += 1
	var tick := Time.get_ticks_usec()
	if frames > 120:
		samples.append(float(tick - last_tick) / 1000.0)
	last_tick = tick
	if frames == 180 and shop:
		world.finish_wave()
	if frames == 720:
		capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var suffix := "-stress" if stress else ("-shop" if shop else "")
	var output := ProjectSettings.globalize_path("res://.test-results/3d-slice%s.png" % suffix)
	get_viewport().get_texture().get_image().save_png(output)
	samples.sort()
	print("SLICE_CAPTURE ", output)
	print("SLICE_METRICS ", JSON.stringify({"frames": samples.size(), "median_frame_ms": samples[samples.size() / 2],
		"p95_frame_ms": samples[int(samples.size() * .95)], "enemies": world.enemies.size(),
		"projectiles": world.projectiles.size(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}))
	get_tree().quit()

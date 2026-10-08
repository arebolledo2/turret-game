extends Node

## Developer visual check. Run with a rendering driver (not --headless).
## Screenshots and timings go to ignored .test-results, never player saves.
var world: ArenaWorld
var frames: int = 0
var samples: Array[float] = []
var stress: bool = false
var shop: bool = false
var combat_demo: bool = false
var new_turrets: bool = false
var zones_demo: bool = false
var last_tick: int = 0
var physics_samples: Array[float] = []
var process_samples: Array[float] = []
var gpu_samples: Array[float] = []
var render_cpu_samples: Array[float] = []
var peak_voices: int = 0

func _ready() -> void:
	call_deferred("setup")

func setup() -> void:
	world = load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	var arguments := OS.get_cmdline_user_args()
	for argument in arguments:
		if argument.begins_with("--zones"):
			# --zones[=layout_id] frames a layout with no enemies (--focus=<zone type> picks the zone); --legacy-zones turns `zone_readability` off.
			zones_demo = true
			var config := RunConfig.new()
			config.layout_id = argument.trim_prefix("--zones=") if "=" in argument else "crossroads"
			world.run_config = config
	if "--legacy-zones" in arguments:
		FeatureFlagService.set_enabled(FeatureFlagService.ZONE_READABILITY, false)
	add_child(world)
	world.waves.remaining_spawns = 0
	world.waves.announcement_left = 0
	world.player.invulnerability = 999
	stress = "--stress" in OS.get_cmdline_user_args()
	shop = "--shop" in OS.get_cmdline_user_args()
	combat_demo = "--combat-demo" in OS.get_cmdline_user_args()
	new_turrets = "--new-turrets" in OS.get_cmdline_user_args()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	GameRandom.gameplay.seed = 42
	for index in range(150 if stress else (0 if zones_demo else 18)):
		var angle := float(index) * 2.39996
		var radius := 2.5 + float(index % 6) * .5
		var enemy := world.spawn_enemy(Vector3(cos(angle) * radius * 1.4, 0, sin(angle) * radius * .7), "charger" if index % 4 == 0 else "basic")
		if stress:
			enemy.health = 10000
	world.add_turret(Vector3(-3, 0, 0), "plasma")
	world.add_turret(Vector3(3, 0, 0), "shock")
	if new_turrets:
		world.add_turret(Vector3(0, 0, 2.5), "tesla")
		world.add_turret(Vector3(0, 0, -2.5), "melee")
	if stress:
		for index in range(7):
			world.add_turret(Vector3(-6 + index * 2, 0, -2), ArenaShop.TURRETS[index % 3])
	last_tick = Time.get_ticks_usec()

func _process(_delta: float) -> void:
	if not is_instance_valid(world):
		return
	frames += 1
	var tick := Time.get_ticks_usec()
	if frames > 120:
		samples.append(float(tick - last_tick) / 1000.0)
		physics_samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		process_samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		var viewport_rid := get_viewport().get_viewport_rid()
		gpu_samples.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
		render_cpu_samples.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid))
		var active_voices: int = 0
		for remaining: float in world.audio.remaining:
			if remaining > 0.0:
				active_voices += 1
		peak_voices = maxi(peak_voices, active_voices)
	last_tick = tick
	if zones_demo and frames == 180:
		var spot := world.terrain.zones[0].centre
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--focus="):
				for zone in world.terrain.zones:
					if zone.type == argument.trim_prefix("--focus="):
						spot = zone.centre
						break
		world.player.position = Vector3(spot.x + 5.0, 0, spot.y + 3.0)
		world.camera_rig.set_zoom(.75)
		world.camera_rig.snap()
	if frames == 180 and shop:
		world.finish_wave()
	if frames == 180 and combat_demo:
		stage_combat_demo()
	if frames == 720:
		capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var suffix := "-stress" if stress else ("-turrets" if new_turrets else "-shop" if shop else ("-combat" if combat_demo else ("-zones" if zones_demo else "")))
	var output := ProjectSettings.globalize_path("res://.test-results/game%s.png" % suffix)
	get_viewport().get_texture().get_image().save_png(output)
	samples.sort()
	physics_samples.sort()
	process_samples.sort()
	gpu_samples.sort()
	render_cpu_samples.sort()
	print("GAME_CAPTURE ", output)
	print("GAME_METRICS ", JSON.stringify({"frames": samples.size(), "median_frame_ms": samples[samples.size() / 2],
		"p95_frame_ms": samples[int(samples.size() * .95)], "enemies": world.enemies.size(),
		"projectiles": world.projectiles.size(), "peak_audio_voices": peak_voices,
		"spark_instances": world.effects.sparks.size(), "turrets": world.turrets.size(),
		"physics_p95_ms": physics_samples[int(physics_samples.size() * .95)],
		"process_p95_ms": process_samples[int(process_samples.size() * .95)],
		"physics_median_ms": physics_samples[physics_samples.size() / 2], "process_median_ms": process_samples[process_samples.size() / 2],
		"gpu_median_ms": gpu_samples[gpu_samples.size() / 2], "gpu_p95_ms": gpu_samples[int(gpu_samples.size() * .95)],
		"render_cpu_median_ms": render_cpu_samples[render_cpu_samples.size() / 2], "render_cpu_p95_ms": render_cpu_samples[int(render_cpu_samples.size() * .95)], "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}))
	get_tree().quit()

func stage_combat_demo() -> void:
	# Freeze an actual warning and impact for a reproducible readability check.
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	for actor in world.enemies:
		actor.set_physics_process(false)
	for turret in world.turrets:
		turret.set_physics_process(false)
	var charger := world.spawn_enemy(world.player.position + Vector3(1.6, 0, 0), "charger")
	charger.set_physics_process(false)
	charger._physics_process(.01)
	var target := world.spawn_enemy(Vector3(-2.5, 0, 0))
	target.set_physics_process(false)
	world.combat.impact(target, target.position, Vector3.RIGHT,
		CombatShot3D.from_stats(TurretStatsService.get_turret_stats("plasma", 1.0), GameEnums.DamageType.PLASMA), world.enemies)
	var slowed := world.spawn_enemy(Vector3(3.8, 0, -.4))
	slowed.health = 100
	slowed.set_physics_process(false)
	var shock := world.turrets[2]
	shock.cooldown = 0
	shock._physics_process(.01)
	world.effects._physics_process(.14)
	world.effects.set_physics_process(false)

extends Node

## Developer visual check. Run with a rendering driver (not --headless).
## Screenshots and timings go to ignored .test-results, never player saves.
var world: ArenaWorld
var frames: int = 0
var samples: Array[float] = []
var stress: bool = false
var mixed_stress: bool = false
var benchmark_seconds: float = 0.0
var started_usec: int = 0
var capture_pending: bool = false
var shop: bool = false
var shop_focus: int = -1
var combat_demo: bool = false
var new_turrets: bool = false
var zones_demo: bool = false
var roster_demo: bool = false
var sniper_demo: bool = false
var quake_demo: bool = false
var quake_frame: int = 225
var decoy_demo: bool = false
var decoy_frame: int = 480
var press_demo: bool = false
var press_frame: int = 600
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
		if argument.begins_with("--benchmark-seconds="):
			benchmark_seconds = maxf(1.0, float(argument.trim_prefix("--benchmark-seconds=")))
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
	world.preparation.deploy()
	world.waves.announcement_left = 0
	world.player.invulnerability = 999
	mixed_stress = "--mixed-stress" in arguments
	stress = "--stress" in arguments or mixed_stress
	if "--reduced-motion" in arguments:
		FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, true)
	shop = "--shop" in OS.get_cmdline_user_args()
	for argument in arguments:
		if argument.begins_with("--shop-focus="): # --shop-focus=N: focus offer card N so the build preview shows
			shop = true
			shop_focus = int(argument.trim_prefix("--shop-focus="))
	combat_demo = "--combat-demo" in OS.get_cmdline_user_args()
	roster_demo = "--roster-demo" in arguments
	sniper_demo = "--sniper-demo" in arguments
	quake_demo = "--quake-demo" in arguments
	decoy_demo = "--decoy-demo" in arguments
	press_demo = "--scrap-press-demo" in arguments
	for argument in arguments:
		if argument.begins_with("--scrap-press-frame="):
			press_frame = int(argument.trim_prefix("--scrap-press-frame="))
		if argument.begins_with("--decoy-frame="):
			decoy_frame = int(argument.trim_prefix("--decoy-frame="))
		if argument.begins_with("--quake-frame="):
			quake_frame = int(argument.trim_prefix("--quake-frame="))
	new_turrets = "--new-turrets" in arguments or mixed_stress
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	GameRandom.gameplay.seed = 42
	for index in range(150 if stress else (0 if zones_demo or roster_demo or sniper_demo or quake_demo or decoy_demo or press_demo else 18)):
		var angle := float(index) * 2.39996
		var radius := 2.5 + float(index % 6) * .5
		var kind: String = ["basic", "fast", "tank", "charger", "exploder"][index % 5] if mixed_stress else ("charger" if index % 4 == 0 else "basic")
		var enemy := world.spawn_enemy(Vector3(cos(angle) * radius * 1.4, 0, sin(angle) * radius * .7), kind)
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
	if mixed_stress:
		world.drops.spawn(Vector3(2, 0, 2)).health = 10000
	if roster_demo:
		stage_roster_demo()
	if sniper_demo:
		stage_sniper_demo()
	if quake_demo:
		stage_quake_demo()
	if decoy_demo:
		stage_decoy_demo()
	if press_demo:
		stage_scrap_press_demo()
	last_tick = Time.get_ticks_usec()
	started_usec = last_tick

## The Sniper line in combat: base, Piercer Rifle, Horizon Piercer and Overwatch each fire once at three stationary
## enemies in a lane (`--sniper-demo`).
func stage_sniper_demo() -> void:
	world.set_physics_process(false)
	world.hud.hide()
	world.player.set_physics_process(false)
	world.player.position = Vector3(0, 0, 4)
	for old in world.turrets:
		old.visible = false
		old.set_physics_process(false)
	var forms: Array = ["", "piercer_rifle", "horizon_piercer", "overwatch"]
	for index in range(forms.size()):
		var turret := world.add_turret(Vector3(-4.5 + index * 3.0, 0, 0), "sniper")
		turret.set_physics_process(false)
		if not (forms[index] as String).is_empty():
			turret.progression.evolution_form = forms[index]
			turret.progression.evolution_stage = 1 if forms[index] == "piercer_rifle" else 2
			turret._rebuild_model()
			turret.invalidate_stats()
		for lane in range(3):
			var enemy := world.spawn_enemy(turret.position + Vector3(0, 0, -3.5 - lane * 1.3), "tank" if lane == 0 else "basic")
			enemy.set_physics_process(false)
			enemy.health = 100000
			enemy.max_health = 100000
		turret.reset_physics_interpolation()
	world.crowd.rebuild(world.enemies)
	world.camera_rig.set_zoom(.75)
	world.camera_rig.snap()

## The Quake line in real combat (`--quake-demo[ --quake-frame=N]`, run with `--fixed-fps 60` so a frame is a physics tick):
## Quake, Aftershock, Tectonic and Cataclysm each face a cluster of stationary enemies. Combat starts at frame 180 and the
## screenshot is taken at `quake_frame` (the default catches the rings and fissures opening).
func stage_quake_demo() -> void:
	world.hud.hide()
	world.player.position = Vector3(0, 0, 8)
	world.player.health = 100000
	world.player.max_health = 100000
	for old in world.turrets:
		old.visible = false
		old.set_physics_process(false)
	world.session.state.turret_progression_enabled = true
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP) # evolving is a shop action
	var forms: Array = [[], ["aftershock"], ["aftershock", "tectonic"], ["aftershock", "cataclysm"]]
	for index in range(forms.size()):
		var turret := world.add_turret(Vector3(-7.5 + index * 5.0, 0, 0), "quake")
		turret.progression.award(1500)
		for form: String in forms[index]:
			if not turret.evolve(form):
				push_error("Cannot evolve %s" % form)
		for k in range(7):
			var angle := float(k) * TAU / 7.0
			var spread := .5 if k < 4 else 1.0
			var enemy := world.spawn_enemy(turret.position + Vector3(cos(angle) * spread, 0, -2.4 + sin(angle) * spread), "basic")
			enemy.stationary = true
			enemy.health = 100000
			enemy.max_health = 100000
	world.crowd.rebuild(world.enemies)
	world.camera_rig.set_zoom(.9)
	world.camera_rig.snap()

## The Decoy line in real combat (`--decoy-demo[ --decoy-frame=N]`, run with `--fixed-fps 60`): Decoy and Bumper Post on the near
## row, Pile Driver and Maelstrom on the far row, each with a ring of real, moving enemies (basics, plus Kites round the
## Maelstrom). The hero stands far off at +z. Combat starts at frame 180; the screenshot is taken at `decoy_frame` (the
## default is about four seconds in: pulled crowds stacked round the first three, and the Maelstrom's hooks circling).
func stage_decoy_demo() -> void:
	world.hud.hide()
	world.player.position = Vector3(0, 0, 8)
	world.player.health = 100000
	world.player.max_health = 100000
	for old in world.turrets:
		old.visible = false
		old.set_physics_process(false)
	world.session.state.turret_progression_enabled = true
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP) # evolving is a shop action
	var forms: Array = [[], ["bumper_post"], ["bumper_post", "pile_driver"], ["bumper_post", "maelstrom"]]
	var spots: Array = [Vector3(-6, 0, -4), Vector3(6, 0, -4), Vector3(-6, 0, 3), Vector3(6, 0, 3)]
	for index in range(forms.size()):
		var turret := world.add_turret(spots[index], "decoy")
		turret.progression.award(1500)
		for form: String in forms[index]:
			if not turret.evolve(form):
				push_error("Cannot evolve %s" % form)
		for k in range(8):
			var angle := float(k) * TAU / 8.0 + .4
			var type_id := "kite" if index == 3 and k % 4 == 0 else "basic"
			var enemy := world.spawn_enemy(turret.position + Vector3(cos(angle), 0, sin(angle)) * 3.6, type_id)
			enemy.health = 100000
			enemy.max_health = 100000
	world.crowd.rebuild(world.enemies)
	world.camera_rig.set_zoom(.85)
	world.camera_rig.snap()

## The Scrap Press line in real combat (`--scrap-press-demo[ --scrap-press-frame=N]`, run with `--fixed-fps 60`): the plain press and
## Coin Feeder on the near row, Treasury and Academy on the far row, with two Ion turrets beside the Academy (so it has turrets in
## reach to teach) and no enemies. The hero stays far off at +z so nothing is picked up: floor scrap piles up round the first two,
## the Treasury and Coin Feeder deposit into the wallet and the Academy rings out every few seconds. Combat starts at frame 180;
## the screenshot is taken at `press_frame` (about seven seconds of production).
func stage_scrap_press_demo() -> void:
	world.hud.hide()
	world.player.position = Vector3(0, 0, 12)
	for old in world.turrets:
		old.visible = false
		old.set_physics_process(false)
	world.session.state.turret_progression_enabled = true
	GameStateMachine.force_transition(GameStateMachine.GameState.SHOP) # evolving is a shop action
	var forms: Array = [[], ["coin_feeder"], ["coin_feeder", "treasury"], ["coin_feeder", "academy"]]
	var spots: Array = [Vector3(-6, 0, -3), Vector3(-1, 0, -3), Vector3(-6, 0, 3), Vector3(-1, 0, 3)]
	for index in range(forms.size()):
		var turret := world.add_turret(spots[index], "scrap_press")
		turret.progression.award(1500)
		for form: String in forms[index]:
			if not turret.evolve(form):
				push_error("Cannot evolve %s" % form)
	for offset in [Vector3(2.4, 0, 0), Vector3(0, 0, 2.4)]:
		var neighbour := world.add_turret(spots[3] + offset, "normal")
		neighbour.progression.award(60)
	world.camera_rig.set_zoom(.85)
	world.camera_rig.snap()

## Once combat has started: every visible Sniper fires one real shot (tracer, muzzle flash, hit), then effects freeze.
func fire_sniper_demo() -> void:
	# With no initial wave the run drifts to the shop; turrets only fire in combat.
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
	world.crowd.rebuild(world.enemies)
	for turret in world.turrets:
		if turret.visible:
			turret.cooldown = 0
			turret._physics_process(.016)
	world.effects._physics_process(.03)
	world.effects.set_physics_process(false)

## A frozen gameplay-scale roster, used for appearance checks rather than benchmarking.
func stage_roster_demo() -> void:
	world.set_physics_process(false)
	world.hud.hide()
	world.player.set_physics_process(false)
	world.player.position = Vector3(0, 0, 2)
	world.player.visual.rotation.y = PI - .4
	var kinds := ["basic", "fast", "tank", "charger", "exploder"]
	for index in range(kinds.size()):
		var actor := world.spawn_enemy(Vector3(-4 + index * 2, 0, -2), kinds[index])
		actor.set_physics_process(false)
		actor.visual.rotation.y = PI - .4
	world.drops.spawn(Vector3(2, 0, 2)).set_physics_process(false)
	if not new_turrets:
		world.add_turret(Vector3(-2, 0, 0), "tesla")
		world.add_turret(Vector3(2, 0, 0), "melee")
	for index in range(world.turrets.size()):
		world.turrets[index].position = Vector3(-4 + index * 2, 0, 0)
		world.turrets[index].set_physics_process(false)
		world.turrets[index].aim.rotation.y = PI - .4
	world.camera_rig.set_zoom(.75)
	world.camera_rig.snap()

func _process(_delta: float) -> void:
	if not is_instance_valid(world):
		return
	frames += 1
	var tick := Time.get_ticks_usec()
	var elapsed := float(tick - started_usec) / 1000000.0
	var warmed_up := elapsed >= 2.0 if benchmark_seconds > 0.0 else frames > 120
	if warmed_up:
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
	if frames == 400 and shop_focus >= 0:
		world.hud.shop_screen.offer_buttons[shop_focus].grab_focus()
	if frames == 180 and (quake_demo or decoy_demo or press_demo):
		GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)
		world.crowd.rebuild(world.enemies)
	if frames == 180 and sniper_demo:
		fire_sniper_demo()
	if frames == 180 and combat_demo:
		stage_combat_demo()
	var finished := elapsed >= benchmark_seconds + 2.0 if benchmark_seconds > 0.0 else frames == (press_frame if press_demo else (decoy_frame if decoy_demo else (quake_frame if quake_demo else 720)))
	if finished and not capture_pending:
		capture_pending = true
		capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var suffix := "-stress" if stress else ("-turrets" if new_turrets else "-shop" if shop else ("-combat" if combat_demo else ("-zones" if zones_demo else "")))
	if roster_demo:
		suffix = "-roster"
	if sniper_demo:
		suffix = "-sniper"
	if quake_demo:
		suffix = "-quake-%d" % quake_frame
	if decoy_demo:
		suffix = "-decoy-%d" % decoy_frame
	if press_demo:
		suffix = "-scrap-press-%d" % press_frame
	var output := ProjectSettings.globalize_path("res://.test-results/game%s.png" % suffix)
	get_viewport().get_texture().get_image().save_png(output)
	samples.sort()
	physics_samples.sort()
	process_samples.sort()
	gpu_samples.sort()
	render_cpu_samples.sort()
	print("GAME_CAPTURE ", output)
	var enemy_counts: Dictionary = {}
	for enemy in world.enemies:
		enemy_counts[enemy.enemy_type] = int(enemy_counts.get(enemy.enemy_type, 0)) + 1
	var custom_assets: Array[String] = []
	for key in ClockworkModels.KEYS:
		if ClockworkModels.available(key):
			custom_assets.append(key)
	print("GAME_METRICS ", JSON.stringify({"frames": samples.size(), "median_frame_ms": samples[samples.size() / 2],
		"sample_seconds": benchmark_seconds, "warmup_seconds": 2.0 if benchmark_seconds > 0.0 else 0.0,
		"scenario": "mixed_stress" if mixed_stress else "stress" if stress else "visual_review",
		"enemy_counts": enemy_counts, "clockwork_assets": custom_assets,
		"reduced_motion": FeatureFlagService.is_enabled(FeatureFlagService.REDUCED_MOTION),
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

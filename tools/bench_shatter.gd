extends Node

## Cost of the death effects with many enemies. Kills a batch of beetles at once and times the kill call and the
## following frames, with bystanders alive in the arena, for each effect. Needs a window (render timings, draw calls).
##   godot --path . res://tools/bench_shatter.tscn -- [--mode=shatter|dissolve|none] [--kills=16] [--bystanders=100]
## Prints one SHATTER_BENCH line. VSync is forced off so frame time is the real cost, not the refresh interval.
const SAMPLE_FRAMES: int = 70 # about the 1.3 s life of a shatter at an uncapped frame rate; a slow run just samples less of it

var mode := "shatter"
var kills := 16
var bystanders := 100

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--kills="):
			kills = int(arg.trim_prefix("--kills="))
		elif arg.begins_with("--bystanders="):
			bystanders = int(arg.trim_prefix("--bystanders="))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var world := ArenaWorld.new()
	world.auto_start = false
	world.run_config = RunConfig.new()
	add_child(world)
	world.start_run()
	world.set_physics_process(false)
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)
	world.player.set_physics_process(false)
	world.player.position = Vector3(0, 0, .2)
	world.player.invulnerability = 999.0
	for turret in world.turrets:
		turret.set_physics_process(false)
	world.camera_rig.set_zoom(.8)
	world.camera_rig.snap()
	var victims: Array[CombatActor] = []
	for index in kills + bystanders:
		var at := Vector3(fmod(index * 1.37, 9.0) - 4.5, 0, fmod(index * .83, 5.0) - 2.5)
		var enemy := world.spawn_enemy(at, "drowse")
		enemy.set_physics_process(false)
		if index < kills:
			victims.append(enemy)
	if mode == "dissolve":
		DeathShatter._sets["drowse"] = null
	for frame in 30:
		await get_tree().process_frame
	var warm_ms := 0.0
	if mode != "none" and victims.size() > 1:
		var first := Time.get_ticks_usec()
		victims.pop_front().take_damage(1000.0)
		warm_ms = (Time.get_ticks_usec() - first) / 1000.0
	var started := Time.get_ticks_usec()
	if mode != "none":
		for enemy in victims:
			enemy.take_damage(enemy.health + 1.0)
	var kill_ms := (Time.get_ticks_usec() - started) / 1000.0
	var intervals: Array[float] = []
	var draw_calls := 0
	var last := Time.get_ticks_usec()
	for frame in SAMPLE_FRAMES:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		intervals.append((now - last) / 1000.0)
		last = now
		draw_calls = maxi(draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	intervals.sort()
	print("SHATTER_BENCH mode=%s kills=%d bystanders=%d first_kill=%.2fms rest_kill_calls=%.2fms median_frame=%.2fms p95_frame=%.2fms max_frame=%.2fms peak_draw_calls=%d" % [
		mode, kills, bystanders, warm_ms, kill_ms, intervals[intervals.size() / 2], intervals[int(intervals.size() * .95)], intervals[-1], draw_calls])
	get_tree().quit()

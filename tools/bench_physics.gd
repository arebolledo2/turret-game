extends Node

## Headless frame-cost ablation: builds the stress scene (150 durable enemies, ten mixed turrets), then times
## `Performance.TIME_PHYSICS_PROCESS` and `TIME_PROCESS` with subsystems switched off one at a time. Modes repeat in
## `ROUNDS` interleaved passes and report the median of the per-pass medians, which tames drift. It measures CPU
## script and physics-server cost only (no rendering), so a busy GPU does not affect it.
## Run: godot --headless --path . res://tools/bench_physics.tscn
const WARMUP_TICKS: int = 60
const SAMPLE_TICKS: int = 180
const ROUNDS: int = 3

var world: ArenaWorld
var step: int = 0
var ticks: int = 0
var samples: Array[float] = []
var process_samples: Array[float] = []
var physics_by_mode: Dictionary = {}
var process_by_mode: Dictionary = {}
var modes: Array[String] = ["all_on", "no_enemy_scripts", "no_turret_scripts", "no_world_tick", "no_effects",
	"no_hud", "no_minimap", "no_audio_camera", "nothing"]

func _ready() -> void:
	world = load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	add_child(world)
	world.waves.remaining_spawns = 0
	world.preparation.deploy()
	world.waves.announcement_left = 0
	world.player.invulnerability = 999
	GameRandom.gameplay.seed = 42
	for index in range(150):
		var angle := float(index) * 2.39996
		var radius := 2.5 + float(index % 6) * .5
		var enemy := world.spawn_enemy(Vector3(cos(angle) * radius * 1.4, 0, sin(angle) * radius * .7), "charger" if index % 4 == 0 else "basic")
		enemy.health = 10000
	world.add_turret(Vector3(-3, 0, 0), "plasma")
	world.add_turret(Vector3(3, 0, 0), "shock")
	for index in range(7):
		world.add_turret(Vector3(-6 + index * 2, 0, -2), ArenaShop.TURRETS[index % 3])
	apply_mode()

func current_mode() -> String:
	return modes[step % modes.size()]

func apply_mode() -> void:
	var mode := current_mode()
	var enemies_on := mode not in ["no_enemy_scripts", "nothing"]
	var turrets_on := mode not in ["no_turret_scripts", "nothing"]
	for enemy in world.enemies:
		enemy.set_physics_process(enemies_on)
	for turret in world.turrets:
		turret.set_physics_process(turrets_on)
	world.set_physics_process(mode not in ["no_world_tick", "nothing"])
	world.effects.set_physics_process(mode not in ["no_effects", "nothing"])
	world.player.set_physics_process(mode != "nothing")
	if world.hud:
		world.hud.set_process(mode not in ["no_hud", "nothing"])
		world.hud.minimap.set_process(mode not in ["no_minimap", "nothing"])
	world.audio.set_process(mode not in ["no_audio_camera", "nothing"])
	world.camera_rig.set_process(mode not in ["no_audio_camera", "nothing"])
	ticks = 0
	samples.clear()
	process_samples.clear()

func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])

func _physics_process(_delta: float) -> void:
	ticks += 1
	if ticks <= WARMUP_TICKS:
		return
	samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	process_samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	if samples.size() < SAMPLE_TICKS:
		return
	var mode := current_mode()
	if not physics_by_mode.has(mode):
		physics_by_mode[mode] = []
		process_by_mode[mode] = []
	physics_by_mode[mode].append(_median(samples))
	process_by_mode[mode].append(_median(process_samples))
	step += 1
	if step >= modes.size() * ROUNDS:
		for name in modes:
			print("BENCH %-18s physics %.2f ms | process %.2f ms" % [name, _median(physics_by_mode[name]), _median(process_by_mode[name])])
		get_tree().quit()
		return
	apply_mode()

extends Node

## Headless per-subsystem script cost (ms per physics tick) for realistic enemy mixes. The legacy `bench_split` only
## spawns basic/charger, which hides the cost of ecology enemies (brain, AnimationPlayer, attack-slot checks).
## Run: godot --headless --path . res://tools/bench_mix.tscn -- --mix=hunt [--count=150] [--turrets=10]
## Mixes: legacy, early, hunt, needle, siege, hatch. The wave timer is held open so long runs stay in combat.
const MIXES := {
	"legacy": {"basic": 75, "charger": 25},
	"early": {"drowse": 80, "basic": 20},
	"hunt": {"drowse": 25, "basic": 35, "hopper": 40},
	"needle": {"basic": 30, "fast": 25, "kite": 45},
	"siege": {"tank": 30, "basic": 30, "lobber": 40},
	"hatch": {"drowse": 45, "basic": 20, "tender": 35},
}
const WARMUP: int = 90
const SAMPLES: int = 240

var world: ArenaWorld
var frames: int = 0
var totals: Dictionary = {}
var mix: String = "legacy"
var count: int = 150

func _arg(name: String, fallback: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--%s=" % name):
			return argument.get_slice("=", 1)
	return fallback

func _ready() -> void:
	mix = _arg("mix", "legacy")
	count = int(_arg("count", "150"))
	world = load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	add_child(world)
	world.waves.remaining_spawns = 0
	world.preparation.deploy()
	world.waves.announcement_left = 0
	world.player.invulnerability = 99999
	GameRandom.gameplay.seed = 42
	var types: Array[String] = []
	var weights: Dictionary = MIXES[mix]
	for type_id: String in weights:
		for i in range(roundi(count * float(weights[type_id]) / 100.0)):
			types.append(type_id)
	while types.size() < count:
		types.append(types[0])
	for index in range(count):
		var angle := float(index) * 2.39996
		var radius := 2.5 + float(index % 6) * .5
		var enemy := world.spawn_enemy(Vector3(cos(angle) * radius * 1.4, 0, sin(angle) * radius * .7), types[(index * 37) % types.size()])
		enemy.health = 100000
		enemy.max_health = 100000
	var turret_count := int(_arg("turrets", "10"))
	if turret_count >= 2:
		world.add_turret(Vector3(-3, 0, 0), "plasma")
		world.add_turret(Vector3(3, 0, 0), "shock")
		for index in range(turret_count - 2):
			world.add_turret(Vector3(-6 + index * 2, 0, -2), ArenaShop.TURRETS[index % 3])

func _time(label: String, callable: Callable) -> void:
	var start := Time.get_ticks_usec()
	callable.call()
	totals[label] = float(totals.get(label, 0.0)) + float(Time.get_ticks_usec() - start)

func _physics_process(delta: float) -> void:
	frames += 1
	world.waves.time_left = 99999.0
	for e in world.enemies: e.set_physics_process(false)
	for t in world.turrets: t.set_physics_process(false)
	for p in world.projectiles: p.set_physics_process(false)
	world.set_physics_process(false)
	world.effects.set_physics_process(false)
	world.player.set_physics_process(false)
	if frames < WARMUP:
		return
	_time("world_tick", func(): world._physics_process(delta))
	_time("enemies", func(): for e in world.enemies: e._physics_process(delta))
	_time("turrets", func(): for t in world.turrets: t._physics_process(delta))
	_time("projectiles", func(): for p in world.projectiles: p._physics_process(delta))
	_time("effects", func(): world.effects._physics_process(delta))
	if frames >= WARMUP + SAMPLES:
		var line := "MIX %-7s n=%d |" % [mix, world.enemies.size()]
		var sum := 0.0
		for key in totals:
			var ms := float(totals[key]) / float(SAMPLES) / 1000.0
			sum += ms
			line += " %s %.2f" % [key, ms]
		print(line + " | total %.2f ms/tick" % sum)
		get_tree().quit()

extends Node

## Times each subsystem's physics callback directly (all automatic physics processing is off) to split the tick cost.
## Run: godot --headless --path . res://tools/bench_split.tscn
var world: ArenaWorld
var frames: int = 0
var totals: Dictionary = {}

func _ready() -> void:
	world = load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	add_child(world)
	world.waves.remaining_spawns = 0
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

func _time(label: String, callable: Callable) -> void:
	var start := Time.get_ticks_usec()
	callable.call()
	totals[label] = float(totals.get(label, 0.0)) + float(Time.get_ticks_usec() - start)

func _physics_process(delta: float) -> void:
	frames += 1
	for e in world.enemies: e.set_physics_process(false)
	for t in world.turrets: t.set_physics_process(false)
	for p in world.projectiles: p.set_physics_process(false)
	world.set_physics_process(false)
	world.effects.set_physics_process(false)
	world.player.set_physics_process(false)
	if frames < 60:
		return
	_time("world_tick", func(): world._physics_process(delta))
	_time("enemies", func(): for e in world.enemies: e._physics_process(delta))
	_time("turrets", func(): for t in world.turrets: t._physics_process(delta))
	_time("projectiles", func(): for p in world.projectiles: p._physics_process(delta))
	_time("effects", func(): world.effects._physics_process(delta))
	if frames >= 240:
		for key in totals:
			print("SPLIT %-12s %.2f ms/tick" % [key, float(totals[key]) / 180.0 / 1000.0])
		get_tree().quit()

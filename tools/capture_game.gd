extends Node

## Developer visual check. Run with a rendering driver (not --headless).
## Screenshots and timings go to ignored .test-results, never player saves.
var world: ArenaWorld
var frames: int = 0
var samples: Array[float] = []
var stress: bool = false
var shop: bool = false
var combat_demo: bool = false
var last_tick: int = 0

func _ready() -> void:
	call_deferred("setup")

func setup() -> void:
	world = load("res://scenes/game/arena.tscn").instantiate() as ArenaWorld
	add_child(world)
	world.remaining_spawns = 0
	world.announcement_left = 0
	world.player.invulnerability = 999
	stress = "--stress" in OS.get_cmdline_user_args()
	shop = "--shop" in OS.get_cmdline_user_args()
	combat_demo = "--combat-demo" in OS.get_cmdline_user_args()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	GameRandom.gameplay.seed = 42
	for index in range(150 if stress else 18):
		var angle := float(index) * 2.39996
		var radius := 2.5 + float(index % 6) * .5
		var enemy := world.spawn_enemy(Vector3(cos(angle) * radius * 1.4, 0, sin(angle) * radius * .7), "charger" if index % 4 == 0 else "basic")
		if stress:
			enemy.health = 10000
	world.add_turret(Vector3(-3, 0, 0), "plasma")
	world.add_turret(Vector3(3, 0, 0), "shock")
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
	last_tick = tick
	if frames == 180 and shop:
		world.finish_wave()
	if frames == 180 and combat_demo:
		stage_combat_demo()
	if frames == 720:
		capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	var suffix := "-stress" if stress else ("-shop" if shop else ("-combat" if combat_demo else ""))
	var output := ProjectSettings.globalize_path("res://.test-results/game%s.png" % suffix)
	get_viewport().get_texture().get_image().save_png(output)
	samples.sort()
	print("GAME_CAPTURE ", output)
	print("GAME_METRICS ", JSON.stringify({"frames": samples.size(), "median_frame_ms": samples[samples.size() / 2],
		"p95_frame_ms": samples[int(samples.size() * .95)], "enemies": world.enemies.size(),
		"projectiles": world.projectiles.size(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}))
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

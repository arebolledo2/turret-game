extends Node

## Accelerated real-physics run: real spawning, damage, pickups, stock and budget.
## -- --control buys plasma/shock; default buys ion/fire-rate upgrades.
## Defaults to the six-wave slice so the regression gate stays fast; other options:
##   --waves=N  --difficulty=easy|medium|hard|brutal  --mode=survive|core  --preset=<flag preset>  --flags=a,-b
##   --telemetry-out=<path>  writes the per-wave telemetry JSON (path may use user:// or be absolute)
## A deterministic dodge bot is a regression smoke check, not human playtesting.
var world: ArenaWorld
var control_build: bool = false
var elapsed: float = 0.0
var shopping_wave: int = 0
var telemetry_path: String = ""

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	control_build = "--control" in args
	GameRandom.gameplay.seed = 20260916
	Engine.time_scale = 4.0
	var config := RunConfig.from_args(args)
	var explicit_waves := false
	for arg in args:
		explicit_waves = explicit_waves or arg.begins_with("--waves=")
	if not explicit_waves:
		config.wave_limit = RunConfig.slice().wave_limit
	if not config.flag_preset.is_empty():
		FeatureFlagService.apply_preset(config.flag_preset)
	for arg in args:
		if arg.begins_with("--flags="):
			var failed := FeatureFlagService.apply_flag_list(arg.trim_prefix("--flags="))
			if not failed.is_empty():
				push_error("Unknown or unmet flags: %s" % ", ".join(failed))
		elif arg.begins_with("--telemetry-out="):
			telemetry_path = arg.trim_prefix("--telemetry-out=")
	world = preload("res://scenes/game/arena.tscn").instantiate()
	world.run_config = config
	add_child(world)
	world.shop.rng = RandomNumberGenerator.new()
	world.shop.rng.seed = 42

func _physics_process(delta: float) -> void:
	elapsed += delta
	if not GameStateService.is_game_active or elapsed > world.wave_limit * 80.0 + 120.0:
		for action in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(action)
		var won := GameStateMachine.current_state == GameStateMachine.GameState.VICTORY
		print("PROGRESSION_SMOKE ", JSON.stringify({"route": "control" if control_build else "ion",
			"victory": won, "wave": GameStateService.current_wave, "health": world.player.health,
			"core": world.core.health if world.core else -1.0, "defeat": world.defeat_reason,
			"kills": GameStateService.total_kills, "scrap": EconomyService.total_scrap,
			"items": ItemTrackingService.item_counts, "turrets": TurretStatsService.turret_counts,
			"simulated_seconds": elapsed, "flags": FeatureFlagService.get_snapshot()}))
		write_telemetry()
		set_physics_process(false)
		finish.call_deferred(won)
		return
	if GameStateMachine.current_state == GameStateMachine.GameState.SHOP:
		if shopping_wave != GameStateService.current_wave:
			shopping_wave = GameStateService.current_wave
			shop()
		world.begin_next_wave()
		return
	if not world.is_combat():
		return
	# Orbit the defended central area, steering away from nearby enemies.
	var destination := Vector3(cos(elapsed * .28) * 3.4, 0, sin(elapsed * .28) * 2.3)
	var steering := WorldGeometry.planar(destination - world.player.position).normalized()
	for actor in world.enemies:
		var away := WorldGeometry.planar(world.player.position - actor.position)
		var distance := away.length()
		if distance > .01 and distance < 1.5:
			steering += away.normalized() * (1.5 - distance) * 3.0
	steering = steering.limit_length()
	Input.action_press("move_right", maxf(steering.x, 0))
	Input.action_press("move_left", maxf(-steering.x, 0))
	Input.action_press("move_down", maxf(steering.z, 0))
	Input.action_press("move_up", maxf(-steering.z, 0))

func write_telemetry() -> void:
	var report := JSON.stringify(world.telemetry.to_dict())
	print("PROGRESSION_TELEMETRY ", report)
	if telemetry_path.is_empty():
		return
	var file := FileAccess.open(telemetry_path, FileAccess.WRITE)
	if file:
		file.store_string(report)
	else:
		push_error("Cannot write telemetry to %s" % telemetry_path)

func finish(won: bool) -> void:
	# Let the audio mixer consume stop/free commands before the process exits.
	# Victory cues can otherwise still be queued on this same physics boundary.
	world.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(.1, true, false, true).timeout
	get_tree().quit(0 if won else 1)

func shop() -> void:
	while world.player.health < world.player.max_health - 5 and EconomyService.total_scrap >= 5:
		world.repair()
	while world.core and world.core.health < world.core.max_health - 5 and EconomyService.total_scrap >= 5:
		world.repair_core()
	for attempt in range(3):
		for index in range(EconomyService.current_shop_offers.size()):
			var offer := EconomyService.current_shop_offers[index]
			if offer.kind == "turret":
				var type_id := offer.asset_id
				if (control_build and type_id in ["plasma", "shock"]) or (not control_build and type_id == "normal"):
					world.shop.purchase(index)
			elif offer.asset_id in ["quick_loader", "rapid_coolant", "dense_rounds", "ammo_surplus", "reinforced_hull"]:
				world.shop.purchase(index)
		if attempt < 2 and EconomyService.total_scrap > 20:
			world.shop.reroll()
		else:
			break
	print("SMOKE_SHOP wave=", shopping_wave, " scrap=", EconomyService.total_scrap, " build=", TurretStatsService.turret_counts)

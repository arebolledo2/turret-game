extends Node

## Accelerated real-physics run: real spawning, damage, pickups, stock and budget.
## -- --control buys plasma/shock; default buys ion/fire-rate upgrades.
## A deterministic dodge bot is a regression smoke check, not human playtesting.
var world: ArenaWorld
var control_build: bool = false
var elapsed: float = 0.0
var shopping_wave: int = 0

func _ready() -> void:
	control_build = "--control" in OS.get_cmdline_user_args()
	GameRandom.gameplay.seed = 20260916
	Engine.time_scale = 4.0
	world = preload("res://scenes/game/arena.tscn").instantiate()
	add_child(world)
	world.shop.rng = RandomNumberGenerator.new()
	world.shop.rng.seed = 42

func _physics_process(delta: float) -> void:
	elapsed += delta
	if not GameStateService.is_game_active or elapsed > 600:
		for action in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(action)
		var won := GameStateMachine.current_state == GameStateMachine.GameState.VICTORY
		print("PROGRESSION_SMOKE ", JSON.stringify({"route": "control" if control_build else "ion",
			"victory": won, "wave": GameStateService.current_wave, "health": world.player.health,
			"kills": GameStateService.total_kills, "scrap": EconomyService.total_scrap,
			"items": ItemTrackingService.item_counts, "turrets": TurretStatsService.turret_counts,
			"simulated_seconds": elapsed}))
		get_tree().quit(0 if won else 1)
		set_physics_process(false)
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

func shop() -> void:
	while world.player.health < world.player.max_health - 5 and EconomyService.total_scrap >= 5:
		world.repair()
	for attempt in range(3):
		for index in range(EconomyService.current_shop_offers.size()):
			var offer: Dictionary = EconomyService.current_shop_offers[index]
			if offer["type"] == "turret":
				var type_id: String = offer["turret_id"]
				if (control_build and type_id in ["plasma", "shock"]) or (not control_build and type_id == "normal"):
					world.shop.purchase(index)
			elif offer["item_id"] in ["quick_loader", "rapid_coolant", "dense_rounds", "ammo_surplus", "reinforced_hull"]:
				world.shop.purchase(index)
		if attempt < 2 and EconomyService.total_scrap > 20:
			world.shop.reroll()
		else:
			break
	print("SMOKE_SHOP wave=", shopping_wave, " scrap=", EconomyService.total_scrap, " build=", TurretStatsService.turret_counts)

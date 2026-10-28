extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child_autofree(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.turrets[0].set_physics_process(false)
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)

func _line_of_three() -> Array[CombatActor]:
	var enemies: Array[CombatActor] = []
	for index in range(3):
		var enemy := world.spawn_enemy(Vector3(0, 0, -3.0 - index * 1.2))
		enemy.set_physics_process(false)
		enemy.health = 1000
		enemies.append(enemy)
	return enemies

func _fly(pierce: int) -> Array[CombatActor]:
	var enemies := _line_of_three()
	await wait_physics_frames(2)
	var shot := CombatShot3D.new()
	shot.damage = 10
	shot.speed = 20
	shot.pierce = pierce
	var projectile := world.fire_shot(Vector3(0, .6, 0), enemies[0], shot)
	projectile.set_physics_process(false)
	for tick in range(40):
		await wait_physics_frames(1)
		projectile.advance(1.0 / 60.0)
	return enemies

func test_plain_shot_stops_at_first_enemy() -> void:
	var enemies := await _fly(0)
	var hurt := enemies.filter(func(e: CombatActor) -> bool: return e.health < 1000.0)
	assert_eq(hurt.size(), 1)

func test_pierce_one_hits_two_enemies() -> void:
	var enemies := await _fly(1)
	var hurt := enemies.filter(func(e: CombatActor) -> bool: return e.health < 1000.0)
	assert_eq(hurt.size(), 2)
	assert_eq(enemies[2].health, 1000.0)

func test_shot_copy_keeps_pierce() -> void:
	var shot := CombatShot3D.from_stats({"damage": 5, "pierce": 2})
	assert_eq(shot.copy().pierce, 2)

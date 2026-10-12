extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_flags()
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	world.run_config = RunConfig.new()
	world.run_config.mode = RunConfig.MODE_CORE
	add_child_autofree(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.core.set_physics_process(false)
	for turret in world.turrets: turret.set_physics_process(false)

func target(at: Vector3) -> CombatActor:
	var enemy := world.spawn_enemy(at, "basic")
	enemy.set_physics_process(false)
	return enemy

func combat() -> void:
	world.preparation.deploy()
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)

func test_core_fires_shared_projectile_and_obeys_cooldown() -> void:
	combat()
	var enemy := target(world.core.position + Vector3(2, 0, 0))
	await wait_physics_frames(2)
	world.core._tick_weapon(.01)
	assert_eq(world.projectiles.size(), 1)
	var projectile := world.projectiles[0]
	assert_true(projectile.active)
	assert_eq(projectile.shot.source_id, CoreObjective.WEAPON_SOURCE_ID)
	assert_true("projectile" in projectile.shot.attack_families)
	assert_almost_eq(projectile.shot.damage, float(world.core.weapon_stats().damage), .001)
	assert_gt(projectile.direction.dot(Vector3.RIGHT), .9)
	world.core._tick_weapon(.01)
	assert_eq(world.projectiles.size(), 1)
	var health := enemy.health
	projectile._physics_process(.5)
	assert_lt(enemy.health, health)

func test_core_does_not_fire_outside_combat_or_range_or_when_dead() -> void:
	target(world.core.position + Vector3(2, 0, 0))
	world.core._tick_weapon(2.0)
	assert_true(world.projectiles.is_empty())
	combat()
	world.paused = true
	world.core._tick_weapon(2.0)
	assert_true(world.projectiles.is_empty())
	world.paused = false
	world.core.dead = true
	world.core._tick_weapon(2.0)
	assert_true(world.projectiles.is_empty())
	world.core.dead = false
	world.enemies[0].position = world.core.position + Vector3(20, 0, 0)
	world.core._tick_weapon(2.0)
	assert_true(world.projectiles.is_empty())

func test_core_profile_is_independent_and_items_scale_its_weapon() -> void:
	var before := world.core.weapon_stats()
	world.run_config.hero.weapon.damage = 999
	assert_almost_eq(float(world.core.weapon_stats().damage), float(before.damage), .001)
	ModifierService.add_modifiers([{"id": "core_test", "stat": "damage", "type": "increase", "value": .5, "filter": {"attack_family": ["projectile"]}}])
	assert_gt(float(world.core.weapon_stats().damage), float(before.damage))
	# Shared resolver keeps the same item interpretation for equal hero/core profiles.
	var hero := PlayerStatsService.get_weapon_stats(world.run_config.core_weapon)
	assert_almost_eq(float(world.core.weapon_stats().damage), float(hero.damage), .001)
	combat()
	world.carried_turret = world.turrets[0]
	target(world.core.position + Vector3(2, 0, 0))
	world.core._tick_weapon(.01)
	assert_eq(world.projectiles.size(), 1, "Carrying a turret only suppresses the hero weapon")

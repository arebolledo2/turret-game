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
	for turret in world.turrets:
		turret.set_physics_process(false)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)

func enemy(at: Vector3) -> CombatActor:
	var result := world.spawn_enemy(at)
	result.set_physics_process(false)
	result.health = 100.0
	result.max_health = 100.0
	return result

func test_flame_hits_forward_cone_and_burns_after_target_leaves() -> void:
	var turret := world.add_turret(Vector3.ZERO, "flamethrower")
	turret.set_physics_process(false)
	var front := enemy(Vector3(0, 0, -1.5))
	var behind := enemy(Vector3(0, 0, 1.5))
	var outside := enemy(Vector3(1.5, 0, -1.5))
	world.crowd.rebuild(world.enemies)
	var stats := turret._current_view(0)
	turret._fire_flame(stats, stats.range_metres, Vector3.FORWARD)
	assert_lt(front.health, 100.0)
	assert_eq(behind.health, 100.0)
	assert_eq(outside.health, 100.0)
	assert_eq(front.statuses.burn_source_id, turret.turret_id)
	var health := front.health
	front.position = Vector3(8, 0, 8)
	for hit in front.statuses.advance_burn(1.0):
		world.combat.apply_hit(front, hit)
	assert_lt(front.health, health)
	assert_true(TurretActor.cone_overlaps_body(Vector3(.65, 0, -1.5), Vector3.FORWARD, 2.0, deg_to_rad(18), .25), "Edge overlap counts")

func test_bow_arrow_and_bowling_attack_snapshots_are_distinct() -> void:
	for key: String in ["bow", "bowling", "flamethrower"]:
		assert_has(ShopCatalog.ids("turret"), key)
	var bow := world.add_turret(Vector3.ZERO, "bow")
	var bowling := world.add_turret(Vector3(3, 0, 0), "bowling")
	bow.set_physics_process(false)
	bowling.set_physics_process(false)
	var arrow := bow._new_shot(bow._current_view(0))
	var ball := bowling._new_shot(bowling._current_view(0))
	assert_eq(arrow.visual_key, "arrow")
	assert_eq(arrow.pierce, 1)
	assert_eq(ball.visual_key, "bowling_ball")
	assert_gt(ball.radius, arrow.radius)
	assert_gt(ball.knockback, 0.0)
	assert_has(ball.attack_families, "kinetic")
	assert_has(ball.attack_families, "projectile")

func test_bowling_hits_multiple_contacts_in_one_step_but_only_once_each() -> void:
	var a := enemy(Vector3(0, 0, -1))
	var b := enemy(Vector3(0, 0, -1.8))
	await get_tree().physics_frame
	var spec := CombatShot3D.new()
	spec.damage = 10
	spec.speed = 10
	spec.radius = .24
	spec.pierce = 5
	spec.visual_key = "bowling_ball"
	spec.knockback = 2.5
	var shot := world.fire_direction(Vector3(0, .24, 0), Vector3.FORWARD, spec)
	shot.set_physics_process(false)
	shot.advance(.25)
	assert_eq(a.health, 90.0)
	assert_eq(b.health, 90.0)
	assert_lt(a.knockback_velocity.z, 0.0)
	shot.position = Vector3(0, .24, 0)
	shot.advance(.25)
	assert_eq(a.health, 90.0)
	assert_eq(b.health, 90.0)

func test_projectile_models_reset_between_arrow_ball_and_energy_shots() -> void:
	var projectile := Projectile3D.new()
	projectile.world = world
	add_child_autofree(projectile)
	var spec := CombatShot3D.new()
	spec.speed = 1.0
	spec.visual_key = "bowling_ball"
	spec.visual_scale = 1.9
	spec.radius = .24
	projectile.acquire_shot(Vector3(0, .24, 0), Vector3.FORWARD, spec)
	assert_not_null(projectile.custom_visual)
	assert_true(projectile.custom_visual.visible)
	var initial_basis := projectile.custom_visual.basis
	projectile.advance(.1)
	assert_false(projectile.custom_visual.basis.is_equal_approx(initial_basis), "Ball rolls with travel")
	projectile.release()
	spec.visual_key = "arrow"
	spec.visual_scale = 1.0
	spec.radius = .075
	projectile.acquire_shot(Vector3(0, .5, 0), Vector3.RIGHT, spec)
	assert_eq(projectile.custom_key, "arrow")
	assert_true(projectile.custom_visual.scale.is_equal_approx(Vector3.ONE), "Pooled model scale resets")
	assert_true((-projectile.custom_visual.basis.z).is_equal_approx(Vector3.RIGHT), "Arrow points along flight")
	assert_almost_eq((projectile.sweep.shape as SphereShape3D).radius, .075, .0001)
	assert_false(projectile.orb.visible)
	projectile.release()
	spec.visual_key = ""
	projectile.acquire_shot(Vector3.ZERO, Vector3.FORWARD, spec)
	assert_false(projectile.custom_visual.visible)
	assert_true(projectile.visual.visible)
	assert_true(projectile.orb.visible)
	projectile.release()

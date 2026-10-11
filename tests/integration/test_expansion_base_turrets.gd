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

func test_flame_ribbons_are_bounded_and_reset_between_waves() -> void:
	for pulse in range(20):
		world.effects.show_flame(Vector3(0, 1, -.8), Vector3.FORWARD, 3.0, deg_to_rad(40), Vector3.ZERO)
	assert_eq(world.effects.flame_ribbons.size(), 48)
	world.effects.reset()
	for ribbon in world.effects.flame_ribbons:
		assert_false(ribbon.visible)
	world.effects.show_flame(Vector3(0, 1, -.8), Vector3.FORWARD, 3.0, deg_to_rad(10), Vector3.ZERO)
	assert_eq(world.effects.flame_ribbons.size(), 48, "Reuses pooled ribbons")
	world.effects._physics_process(.3)
	for ribbon in world.effects.flame_ribbons:
		assert_false(ribbon.visible, "Flame expires")

func test_bank_shot_redirects_without_hitting_the_old_path_twice() -> void:
	var first := enemy(Vector3(0, 0, -1))
	var side := enemy(Vector3(.9, 0, -.7))
	var old_path := enemy(Vector3(0, 0, -2.0))
	await get_tree().physics_frame
	var spec := CombatShot3D.new()
	spec.damage = 10.0
	spec.speed = 10.0
	spec.radius = .24
	spec.visual_key = "bowling_ball"
	spec.ricochets = 1
	var ball := world.fire_direction(Vector3(0, .24, 0), Vector3.FORWARD, spec)
	ball.set_physics_process(false)
	ball.advance(.25)
	assert_eq(first.health, 90.0)
	assert_eq(side.health, 90.0, "Redirected path hits the side target in the same step")
	assert_eq(old_path.health, 100.0, "Old-path contacts are discarded")
	assert_false(ball.active, "Finite ricochet count terminates the shot")

func test_bank_shot_without_recipient_can_use_item_pierce_without_extra_movement() -> void:
	var first := enemy(Vector3(0, 0, -1))
	await get_tree().physics_frame
	var spec := CombatShot3D.new()
	spec.damage = 10.0
	spec.speed = 10.0
	spec.radius = .24
	spec.ricochets = 2
	spec.pierce = 1
	var ball := world.fire_direction(Vector3(0, .24, 0), Vector3.FORWARD, spec)
	ball.set_physics_process(false)
	ball.advance(.2)
	assert_eq(first.health, 90.0)
	assert_true(ball.active)
	assert_almost_eq(ball.position.z, -2.0, .001)
	assert_almost_eq(ball.remaining, spec.lifetime - .2, .001)

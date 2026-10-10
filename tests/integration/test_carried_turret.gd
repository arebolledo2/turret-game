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
	world.player.position = Vector3.ZERO
	world.turrets[0].set_physics_process(false)
	world.turrets[0].position = Vector3(10, 0, 8)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)

func _carry(type_id: String) -> TurretActor:
	var turret := world.add_turret(Vector3(.4, 0, 0), type_id)
	turret.set_physics_process(false)
	assert_true(world.placement.interact())
	assert_same(world.carried_turret, turret)
	return turret

func _enemy() -> CombatActor:
	var enemy := world.spawn_enemy(Vector3(0, 0, -1.0), "fast")
	enemy.set_physics_process(false)
	enemy.max_health = 1000.0
	enemy.health = 1000.0
	world.crowd.rebuild(world.enemies)
	return enemy

func test_carried_projectiles_hit_short_enemies_and_preserve_attribution() -> void:
	var enemy := _enemy()
	await wait_physics_frames(2)
	for type_id in ["normal", "plasma"]:
		var turret := _carry(type_id)
		turret._physics_process(.01)
		var active := world.projectiles.filter(func(p: Projectile3D) -> bool: return p.active)
		assert_eq(active.size(), 1)
		var shot: Projectile3D = active[0]
		shot.set_physics_process(false)
		assert_eq(shot.shot.source_id, turret.turret_id)
		assert_eq(shot.shot.attack_families, TurretRegistry.get_attack_families(type_id))
		assert_gt(shot.position.y, 1.15, "The shot visibly starts at the carried muzzle")
		var before := enemy.health
		shot.advance(.5)
		assert_lt(enemy.health, before, "Elevated %s shot must hit a short enemy" % type_id)
		assert_false(shot.active)
		world.placement.drop_carried()
		turret.position = Vector3(12, 0, 8)

func test_carried_pulse_chain_and_melee_attack_without_entrenching() -> void:
	var enemy := _enemy()
	for type_id in ["shock", "tesla", "melee"]:
		var turret := _carry(type_id)
		var before := enemy.health
		turret._physics_process(1.0)
		assert_lt(enemy.health, before, "%s attacks while carried" % type_id)
		assert_eq(turret.stay_time, 0.0)
		assert_eq(turret.entrench_stacks(), 0)
		assert_eq(turret.zone_range_bonus, 0.0)
		world.placement.drop_carried()
		turret.position = Vector3(12, 0, 8)

func test_hero_holds_fire_until_turret_is_placed() -> void:
	_enemy()
	var turret := _carry("normal")
	world.player.weapon_clock = 0.0
	world.player._tick_player_weapon(1.0)
	assert_true(world.projectiles.is_empty())
	assert_null(world.player.weapon_target)
	assert_true(world.placement.interact())
	assert_false(turret.carried)
	world.player._tick_player_weapon(.01)
	assert_eq(world.projectiles.size(), 1)
	assert_true(world.projectiles[0].active)
	assert_eq(world.projectiles[0].shot.source_id, 0, "The hero resumes their own weapon")

func test_carry_preserves_cooldown_and_pause_freezes_attacks() -> void:
	var enemy := _enemy()
	var turret := _carry("shock")
	turret.cooldown = .5
	turret._physics_process(.1)
	assert_eq(enemy.health, 1000.0)
	world.toggle_pause()
	turret._physics_process(1.0)
	assert_eq(enemy.health, 1000.0)
	assert_almost_eq(turret.cooldown, .4, .001)
	world.toggle_pause()
	turret._physics_process(.4)
	assert_lt(enemy.health, 1000.0)

func test_placement_dial_distinguishes_blocked_ground_and_hides_on_drop() -> void:
	_carry("normal")
	world.placement.update_preview()
	var preview := world.placement.preview
	var material := preview.material_override as ShaderMaterial
	assert_not_null(material)
	assert_true(world.placement.preview_ok)
	assert_false(material.get_shader_parameter("pending"))
	assert_eq(material.get_shader_parameter("tint"), Color("58ece1"))
	world.turrets[0].position = world.placement.drop_position()
	world.placement.update_preview()
	assert_false(world.placement.preview_ok)
	assert_true(material.get_shader_parameter("pending"))
	assert_eq(material.get_shader_parameter("tint"), Color("ff5a5a"))
	assert_false(world.placement.interact(), "Invalid placement still blocks deployment")
	world.placement.drop_carried()
	world.placement.update_preview()
	assert_false(preview.visible)

func test_range_dial_tracks_carried_position_on_floor_in_same_tick() -> void:
	var turret := _carry("normal")
	world.show_ranges = true
	world.player.position = Vector3(3, 0, 2)
	turret._physics_process(.01)
	assert_almost_eq(turret.range_ring.global_position.y, .04, .001)
	assert_almost_eq(turret.range_ring.global_position.x, turret.position.x, .001)
	assert_almost_eq(turret.range_ring.global_position.z, turret.position.z, .001)

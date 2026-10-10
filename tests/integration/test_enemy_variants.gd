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
	world.pickup_root.process_mode = Node.PROCESS_MODE_DISABLED
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)

func enemy(at: Vector3, type_id: String = "basic") -> CombatActor:
	var actor := world.spawn_enemy(at, type_id)
	actor.set_physics_process(false)
	return actor

func test_schedule_respects_registry_min_waves_and_is_deterministic() -> void:
	for index in range(40):
		assert_eq(EnemyVariants.pick_type(1, index), "basic", "Wave 1 is spiders only")
	var seen := {}
	for wave in range(1, 7):
		for index in range(40):
			var type_id := EnemyVariants.pick_type(wave, index)
			assert_gte(wave, int(EnemyRegistry.TYPES[type_id]["min_wave"]), "%s too early in wave %d" % [type_id, wave])
			assert_eq(type_id, EnemyVariants.pick_type(wave, index))
			seen[type_id] = true
	for type_id in ["basic", "fast", "tank", "exploder", "charger"]:
		assert_true(seen.has(type_id), "%s appears by wave 6" % type_id)

func test_variants_use_registry_stats_and_body_size() -> void:
	GameStateService.current_wave = 4
	for type_id in ["fast", "tank", "exploder"]:
		var actor := enemy(Vector3.ZERO, type_id)
		var expected := EnemyRegistry.get_stats_for_wave(type_id, 4, world.difficulty_config)
		assert_almost_eq(actor.max_health, float(expected["health"]), .001)
		assert_almost_eq(actor.speed, float(expected["speed"]) * .01, .001)
		assert_almost_eq(actor.mass, float(expected["mass"]), .001)
		assert_eq(actor.visual.scale, Vector3.ONE * EnemyVariants.body_scale(type_id))
	assert_gt(enemy(Vector3.ZERO, "fast").speed, enemy(Vector3.ZERO, "basic").speed)
	assert_lt(enemy(Vector3.ZERO, "tank").speed, enemy(Vector3.ZERO, "basic").speed)

func test_tint_is_shared_between_identical_types_and_leaves_basic_untouched() -> void:
	var first := enemy(Vector3.ZERO, "fast")
	var second := enemy(Vector3.ONE, "fast")
	var a := first.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var b := second.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	if ClockworkModels.available("fast"):
		assert_null(a.get_surface_override_material(0), "Authored moth colors are preserved")
		assert_null(b.get_surface_override_material(0))
	# The legacy tint utility remains shared even when the current roster has authored colors.
	EnemyVariants.apply_tint(first.visual, "fast")
	EnemyVariants.apply_tint(second.visual, "fast")
	assert_not_null(a.get_surface_override_material(0))
	assert_same(a.get_surface_override_material(0), b.get_surface_override_material(0))
	var basic := enemy(Vector3(2, 0, 0), "basic")
	assert_null((basic.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_surface_override_material(0))

func test_exploder_blast_hits_player_and_neighbours_inside_radius_only() -> void:
	GameStateService.current_wave = 4
	var bomb := enemy(Vector3(2, 0, 0), "exploder")
	assert_almost_eq(bomb.explosion_radius, 1.0, .001)
	var near := enemy(Vector3(2.9, 0, 0))
	var far := enemy(Vector3(3.2, 0, 0))
	near.health = 50
	far.health = 50
	world.player.position = Vector3(2, 0, 0.9)
	var hull := world.player.health
	watch_signals(world.combat)
	world.combat.apply_hit(bomb, CombatHit3D.new(1000.0, Vector3.ZERO))
	assert_true(bomb.dead)
	assert_false(world.enemies.has(bomb))
	assert_almost_eq(near.health, 50.0 - bomb.explosion_damage, .001)
	assert_eq(far.health, 50.0)
	assert_lt(world.player.health, hull)
	assert_signal_emit_count(world.combat, "explosion", 1)

func test_exploder_chain_reaction_terminates() -> void:
	GameStateService.current_wave = 4
	var bombs: Array[CombatActor] = []
	for index in range(5):
		bombs.append(enemy(Vector3(index * .4, 0, 0), "exploder"))
		bombs[index].health = 1.0
	world.player.position = Vector3(8, 0, 0)
	world.combat.apply_hit(bombs[0], CombatHit3D.new(1000.0, Vector3.ZERO))
	for bomb in bombs:
		assert_true(bomb.dead, "Adjacent boom bots chain")
	assert_eq(world.enemies.size(), 0)

func test_wave_notices_announce_each_new_enemy() -> void:
	for wave in [2, 3, 4]:
		assert_ne(EnemyVariants.notice_for_wave(wave), "")
	assert_eq(EnemyVariants.notice_for_wave(1), "")

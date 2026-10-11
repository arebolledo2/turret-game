extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	TestHelpers.reset_flags()
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	world.run_config = RunConfig.slice()
	world.run_config.mode = RunConfig.MODE_CORE
	add_child_autofree(world)
	world.start_run()
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	for turret in world.turrets:
		turret.set_physics_process(false)
	world.effects.set_physics_process(false)
	GameStateMachine.force_transition(GameStateMachine.GameState.COMBAT)

func _enemy(at: Vector3) -> CombatActor:
	var enemy := world.spawn_enemy(at)
	enemy.set_physics_process(false)
	enemy.health = 500
	return enemy

func test_arc_shape_is_jagged_and_pins_both_endpoints() -> void:
	var from := Vector3(-2, .5, 0)
	var to := Vector3(2, .5, 1)
	var points := world.effects._bolt_points(from, to, CombatEffects3D.BOLT_PASSES)
	assert_eq(points.size(), (1 << CombatEffects3D.BOLT_PASSES) + 1)
	assert_eq(points[0], from)
	assert_eq(points[points.size() - 1], to)
	var off_line := 0
	for point in points:
		if absf(point.z - lerpf(from.z, to.z, (point.x - from.x) / (to.x - from.x))) > .02:
			off_line += 1
	assert_gt(off_line, points.size() / 2)

func test_chain_hops_light_in_sequence() -> void:
	world.effects.show_arc(Vector3.ZERO, Vector3(2, .5, 0), 0)
	world.effects.show_arc(Vector3(2, .5, 0), Vector3(4, .5, 0), 1)
	world.effects.show_arc(Vector3(4, .5, 0), Vector3(6, .5, 0), 2)
	assert_true(world.effects.arcs[0].visible)
	assert_false(world.effects.arcs[1].visible)
	assert_false(world.effects.arcs[2].visible)
	world.effects._physics_process(CombatEffects3D.ARC_HOP_DELAY + .001)
	assert_true(world.effects.arcs[1].visible)
	assert_false(world.effects.arcs[2].visible)
	world.effects._physics_process(CombatEffects3D.ARC_HOP_DELAY + .001)
	assert_true(world.effects.arcs[2].visible)

func test_arcs_expire_and_slots_are_pooled() -> void:
	world.effects.show_arc(Vector3.ZERO, Vector3(2, .5, 0))
	var mesh := world.effects.arcs[0].mesh
	for i in range(10):
		world.effects._physics_process(.05)
	assert_false(world.effects.arcs[0].visible)
	world.effects.show_arc(Vector3.ZERO, Vector3(0, .5, 3))
	assert_eq(world.effects.arcs.size(), 1)
	assert_same(world.effects.arcs[0].mesh, mesh)
	assert_true(world.effects.arcs[0].visible)

func test_arc_pool_stays_bounded_and_reset_clears_delayed_arcs() -> void:
	for i in range(CombatEffects3D.MAX_ARCS + 8):
		world.effects.show_arc(Vector3.ZERO, Vector3(2, .5, i), 3)
	assert_eq(world.effects.arcs.size(), CombatEffects3D.MAX_ARCS)
	world.effects.reset()
	world.effects._physics_process(1.0)
	for arc in world.effects.arcs:
		assert_false(arc.visible)

func test_arc_flash_light_decays_and_pool_is_bounded() -> void:
	for i in range(CombatEffects3D.MAX_ARC_LIGHTS + 3):
		world.effects.show_arc(Vector3.ZERO, Vector3(2, .5, i))
	assert_eq(world.effects.arc_lights.size(), CombatEffects3D.MAX_ARC_LIGHTS)
	assert_true(world.effects.arc_lights[0].visible)
	world.effects._physics_process(CombatEffects3D.ARC_LIGHT_LIFETIME + .01)
	for light in world.effects.arc_lights:
		assert_false(light.visible)

func test_reduced_motion_keeps_one_static_bolt_shape() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, true)
	world.effects.show_arc(Vector3.ZERO, Vector3(3, .5, 1))
	var mesh := world.effects.arcs[0].mesh as ImmediateMesh
	var material := world.effects.arcs[0].material_override as ShaderMaterial
	assert_true(material.get_shader_parameter("reduced_motion"))
	var before: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	world.effects._physics_process(CombatEffects3D.ARC_REROLL_INTERVAL * 2.0)
	var after: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(after, before)

func test_full_motion_rerolls_bolt_shape_while_it_lives() -> void:
	world.effects.show_arc(Vector3.ZERO, Vector3(3, .5, 1))
	var mesh := world.effects.arcs[0].mesh as ImmediateMesh
	var before: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	world.effects._physics_process(CombatEffects3D.ARC_REROLL_INTERVAL + .001)
	var after: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_ne(after, before)

func test_electric_hit_marks_enemy_shocked_until_it_expires() -> void:
	var enemy := _enemy(Vector3(3, 0, 3))
	var hit := CombatHit3D.new(1, Vector3.ZERO, Vector3.ZERO, GameEnums.DamageType.ELECTRIC)
	world.combat.apply_hit(enemy, hit)
	world.effects._update_shocks()
	assert_eq(world.effects.shock_visuals.size(), 1)
	assert_true(world.effects.shock_visuals[enemy].visible)
	world.effects.visual_time += CombatEffects3D.SHOCK_MARK_SECONDS + .1
	world.effects._update_shocks()
	assert_eq(world.effects.shock_visuals.size(), 0)
	assert_eq(world.effects.shock_pool.size(), 1)
	assert_false(world.effects.shock_pool[0].visible)

func test_non_electric_hit_does_not_shock_and_overlay_is_reused() -> void:
	var enemy := _enemy(Vector3(3, 0, 3))
	world.combat.apply_hit(enemy, CombatHit3D.new(1))
	world.effects._update_shocks()
	assert_eq(world.effects.shock_visuals.size(), 0)
	world.combat.apply_hit(enemy, CombatHit3D.new(1, Vector3.ZERO, Vector3.ZERO, GameEnums.DamageType.ELECTRIC))
	world.effects._update_shocks()
	var overlay: MeshInstance3D = world.effects.shock_visuals[enemy]
	world.effects.reset()
	assert_eq(world.effects.shock_visuals.size(), 0)
	var other := _enemy(Vector3(-3, 0, 3))
	world.combat.apply_hit(other, CombatHit3D.new(1, Vector3.ZERO, Vector3.ZERO, GameEnums.DamageType.ELECTRIC))
	world.effects._update_shocks()
	assert_same(world.effects.shock_visuals[other], overlay)

func test_electric_slow_keeps_shocked_overlay_after_mark_expires() -> void:
	var enemy := _enemy(Vector3(3, 0, 3))
	var hit := CombatHit3D.new(1, Vector3.ZERO, Vector3.ZERO, GameEnums.DamageType.ELECTRIC)
	hit.slow_intensity = .3
	hit.slow_duration = 2.0
	world.combat.apply_hit(enemy, hit)
	world.effects.visual_time += CombatEffects3D.SHOCK_MARK_SECONDS + .1
	world.effects._update_shocks()
	assert_eq(world.effects.shock_visuals.size(), 1)
	enemy.statuses.clear()
	world.effects._update_shocks()
	assert_eq(world.effects.shock_visuals.size(), 0)

func test_electric_effects_do_not_consume_gameplay_rng() -> void:
	var before := GameRandom.gameplay.state
	for hop in range(3):
		world.effects.show_arc(Vector3.ZERO, Vector3(2 + hop, .5, 1), hop)
	world.effects._physics_process(.2)
	assert_eq(GameRandom.gameplay.state, before)

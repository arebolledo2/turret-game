extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	world = ArenaWorld.new()
	world.show_hud = false
	add_child_autofree(world)
	world.set_physics_process(false)
	world.player.set_physics_process(false)
	world.audio.set_process(false)
	world.preparation.deploy()
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)

func _enemy(type_id: String, health: float = 1.0) -> CombatActor:
	var enemy := world.spawn_enemy(Vector3(2, 0, 0), type_id)
	enemy.set_physics_process(false)
	enemy.health = health
	return enemy

func _kill(enemy: CombatActor) -> void:
	enemy.take_damage(enemy.health + 50.0)

func _corpses(script: GDScript) -> Array:
	return world.actor_root.get_children().filter(func(node: Node) -> bool: return node.get_script() == script)

func test_killing_a_beetle_shatters_it_instead_of_dissolving() -> void:
	var before := DeathShatter.active_count
	_kill(_enemy("drowse"))
	assert_eq(_corpses(DeathShatter).size(), 1)
	assert_eq(_corpses(DeathDissolve).size(), 0)
	assert_eq(DeathShatter.active_count, before + 1)

func test_shards_swap_in_the_baked_meshes_with_shared_shatter_materials() -> void:
	var enemy := _enemy("drowse")
	var originals := {}
	for mesh in enemy.visual.find_children("*", "MeshInstance3D", true, false):
		originals[mesh] = (mesh as MeshInstance3D).mesh
	_kill(enemy)
	var corpse := _corpses(DeathShatter)[0] as DeathShatter
	assert_gt(corpse.meshes.size(), 0)
	assert_eq(corpse.meshes.size(), originals.size())
	for mesh in corpse.meshes:
		assert_ne(mesh.mesh, originals[mesh], "Mesh must be the pre-fractured one")
		assert_gt(mesh.extra_cull_margin, 1.0, "Shards land outside the unbroken bounds")
		for surface in mesh.mesh.get_surface_count():
			assert_true(mesh.get_active_material(surface) is ShaderMaterial)
	assert_false(is_instance_valid(enemy) and enemy.is_ancestor_of(corpse), "Corpse must not hang off the freed actor")

func test_corpses_reuse_materials_so_a_kill_allocates_none() -> void:
	_kill(_enemy("drowse"))
	_kill(_enemy("drowse"))
	var corpses := _corpses(DeathShatter)
	assert_eq(corpses.size(), 2)
	var first := corpses[0] as DeathShatter
	var second := corpses[1] as DeathShatter
	for index in first.meshes.size():
		for surface in first.meshes[index].mesh.get_surface_count():
			assert_same(first.meshes[index].get_active_material(surface), second.meshes[index].get_active_material(surface))

func test_shatter_keeps_the_source_material_look() -> void:
	var enemy := _enemy("drowse")
	var source := (enemy.visual.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_active_material(0) as BaseMaterial3D
	_kill(enemy)
	var copy := (_corpses(DeathShatter)[0] as DeathShatter).meshes[0].get_active_material(0) as ShaderMaterial
	assert_eq(copy.get_shader_parameter("albedo_color"), source.albedo_color)
	assert_almost_eq(float(copy.get_shader_parameter("roughness")), source.roughness, .001)

func test_age_advances_and_the_corpse_frees_itself() -> void:
	var before := DeathShatter.active_count
	_kill(_enemy("drowse"))
	var corpse := _corpses(DeathShatter)[0] as DeathShatter
	corpse._process(DeathShatter.DURATION * .5)
	assert_almost_eq(corpse.age, DeathShatter.DURATION * .5, .0001)
	assert_false(corpse.is_queued_for_deletion())
	corpse._process(DeathShatter.DURATION)
	assert_true(corpse.is_queued_for_deletion())
	await get_tree().process_frame
	assert_eq(DeathShatter.active_count, before)

func test_enemy_without_baked_shards_still_dissolves() -> void:
	assert_null(DeathShatter.shatter_set("fast"))
	_kill(_enemy("fast"))
	assert_eq(_corpses(DeathShatter).size(), 0)
	assert_eq(_corpses(DeathDissolve).size(), 1)

func test_unsupported_spawn_leaves_the_actor_visual_untouched() -> void:
	var enemy := _enemy("fast")
	assert_null(DeathShatter.spawn(world.actor_root, enemy))
	assert_eq(enemy.visual.get_parent(), enemy)

func test_reduced_motion_falls_back_to_the_static_dissolve() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.REDUCED_MOTION, true)
	_kill(_enemy("drowse"))
	assert_eq(_corpses(DeathShatter).size(), 0)
	assert_eq(_corpses(DeathDissolve).size(), 1)

func test_mass_wipe_falls_back_to_dissolve_past_the_cap() -> void:
	var enemies: Array[CombatActor] = []
	for index in DeathShatter.MAX_ACTIVE + 4:
		enemies.append(_enemy("drowse"))
	for enemy in enemies:
		_kill(enemy)
	assert_eq(_corpses(DeathShatter).size(), DeathShatter.MAX_ACTIVE)
	assert_eq(_corpses(DeathDissolve).size(), 4)

func test_elite_tint_survives_into_the_shards() -> void:
	var enemy := _enemy("drowse")
	var plain := (enemy.visual.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_active_material(0) as BaseMaterial3D
	var tinted := plain.duplicate() as BaseMaterial3D
	tinted.albedo_color = Color(1.0, .85, .45)
	(enemy.visual.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).set_surface_override_material(0, tinted)
	_kill(enemy)
	var copy := (_corpses(DeathShatter)[0] as DeathShatter).meshes[0].get_active_material(0) as ShaderMaterial
	assert_eq(copy.get_shader_parameter("albedo_color"), tinted.albedo_color)

func test_every_baked_enemy_shatters_in_the_arena() -> void:
	var tried := 0
	for key in ClockworkModels.KEYS:
		if not DeathShatter.shatter_set(key) or not (EnemyRegistry.TYPES.has(key) or EnemyEcology.TYPES.has(key)):
			continue
		tried += 1
		var before := _corpses(DeathShatter).size()
		_kill(_enemy(key))
		assert_eq(_corpses(DeathShatter).size(), before + 1, "%s has baked shards but did not shatter" % key)
	assert_gt(tried, 1, "Expected the beetle and the Basic drone to be baked")

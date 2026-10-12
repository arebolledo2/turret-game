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

func _enemy(health: float = 100.0) -> CombatActor:
	var enemy := world.spawn_enemy(Vector3(2, 0, 0))
	enemy.set_physics_process(false)
	enemy.health = health
	return enemy

func _overlay_count(actor: CombatActor) -> int:
	var count := 0
	for mesh in actor.visual.find_children("*", "MeshInstance3D", true, false):
		if (mesh as MeshInstance3D).material_overlay:
			count += 1
	return count

func test_hit_attaches_flash_overlay_to_every_mesh_and_fade_removes_it() -> void:
	var enemy := _enemy()
	enemy.take_damage(1.0)
	assert_not_null(enemy.hit_flash)
	enemy._physics_process(.01)
	var meshes := enemy.hit_flash.meshes.size()
	assert_gt(meshes, 0)
	assert_eq(_overlay_count(enemy), meshes)
	assert_true(enemy.visual.visible, "Hit feedback must never hide the model")
	enemy.flash_time = 0.0
	enemy._physics_process(.01)
	assert_eq(_overlay_count(enemy), 0)

func test_flash_strength_follows_remaining_time_and_reduced_motion_dims_it() -> void:
	var enemy := _enemy()
	enemy.take_damage(1.0)
	enemy.hit_flash.update(1.0, false)
	assert_almost_eq(float(enemy.hit_flash.material.get_shader_parameter("strength")), 1.0, .001)
	enemy.hit_flash.update(1.0, true)
	assert_almost_eq(float(enemy.hit_flash.material.get_shader_parameter("strength")), HitFlash.REDUCED_MOTION_SCALE, .001)
	enemy.hit_flash.update(0.5, false)
	assert_almost_eq(float(enemy.hit_flash.material.get_shader_parameter("strength")), .5, .001)

func test_clear_transients_removes_flash() -> void:
	var enemy := _enemy()
	enemy.take_damage(1.0)
	enemy._physics_process(.01)
	enemy.clear_transients()
	assert_eq(_overlay_count(enemy), 0)
	assert_eq(enemy.flash_time, 0.0)

func test_kill_hands_the_model_to_a_dissolve_that_progresses_and_frees_itself() -> void:
	var before := DeathDissolve.active_count
	var enemy := _enemy(1.0)
	enemy.take_damage(50.0)
	var corpses := world.actor_root.get_children().filter(func(node: Node) -> bool: return node is DeathDissolve)
	assert_eq(corpses.size(), 1)
	var corpse := corpses[0] as DeathDissolve
	assert_eq(DeathDissolve.active_count, before + 1)
	assert_gt(corpse.materials.size(), 0)
	for mesh in corpse.find_children("*", "MeshInstance3D", true, false):
		assert_true((mesh as MeshInstance3D).get_surface_override_material(0) is ShaderMaterial)
	assert_false(is_instance_valid(enemy) and enemy.is_ancestor_of(corpse), "Corpse must not be parented to the freed actor")
	corpse._process(DeathDissolve.DURATION * .5)
	assert_almost_eq(float(corpse.materials[0].get_shader_parameter("progress")), .5, .001)
	corpse._process(DeathDissolve.DURATION)
	assert_true(corpse.is_queued_for_deletion())
	await get_tree().process_frame
	assert_eq(DeathDissolve.active_count, before)

func test_dissolve_copies_source_material_look() -> void:
	var enemy := _enemy(1.0)
	var source := enemy.visual.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var original := source.get_active_material(0) as BaseMaterial3D
	enemy.take_damage(50.0)
	var corpse := world.actor_root.get_children().filter(func(node: Node) -> bool: return node is DeathDissolve)[0] as DeathDissolve
	var copy := corpse.materials[0]
	assert_eq(copy.get_shader_parameter("albedo_color"), original.albedo_color)
	assert_almost_eq(float(copy.get_shader_parameter("metallic")), original.metallic, .001)

func test_mass_wipe_skips_dissolve_past_the_cap() -> void:
	var enemies: Array[CombatActor] = []
	for index in DeathDissolve.MAX_CORPSES + 5:
		enemies.append(_enemy(1.0))
	for enemy in enemies:
		enemy.take_damage(50.0)
	var corpses := world.actor_root.get_children().filter(func(node: Node) -> bool: return node is DeathDissolve)
	assert_lte(corpses.size(), DeathDissolve.MAX_CORPSES)

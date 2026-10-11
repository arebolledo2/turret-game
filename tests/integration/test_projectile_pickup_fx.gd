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
	GameStateMachine.transition_to(GameStateMachine.GameState.COMBAT)

func _target() -> CombatActor:
	var enemy := world.spawn_enemy(Vector3(6, 0, 0))
	enemy.set_physics_process(false)
	return enemy

func test_projectile_glow_follows_damage_type_and_only_the_trail_pivot_turns() -> void:
	var enemy := _target()
	var ion := world.fire(Vector3(0, .65, 0), enemy, 1, 10)
	assert_eq(ion.rotation, Vector3.ZERO, "The sweep cast is a child, so the projectile itself must stay unrotated")
	assert_same(ion.orb.material_override, EnergyFx.orb_material("ion"))
	assert_same(ion.trail.material_override, EnergyFx.trail_material("ion"))
	var spec := CombatShot3D.new()
	spec.damage_type = GameEnums.DamageType.PLASMA
	spec.splash_radius = 1.0
	var plasma := world.fire_shot(Vector3(0, .65, 1), enemy, spec)
	assert_same(plasma.orb.material_override, EnergyFx.orb_material("plasma"))
	assert_gt(plasma.orb.scale.x, ion.orb.scale.x, "Splash plasma reads bigger than a plain ion bolt")

func test_trail_points_back_along_the_flight_path() -> void:
	var enemy := _target()
	var shot := world.fire(Vector3(0, .65, 0), enemy, 1, 10)
	# Heading is +X, so the node's -Z (the head) must face +X and the streak (+Z) must trail toward -X.
	var behind := shot.trail_pivot.global_basis * Vector3(0, 0, 1)
	assert_lt(behind.x, -.99)

func test_glow_materials_are_shared_across_shots() -> void:
	assert_same(EnergyFx.orb_material("ion"), EnergyFx.orb_material("ion"))
	assert_not_same(EnergyFx.orb_material("ion"), EnergyFx.orb_material("plasma"))
	assert_same(EnergyFx.ground_glow_material(), EnergyFx.ground_glow_material())

func test_burst_pool_is_bounded_recycles_and_resets() -> void:
	for index in CombatEffects3D.MAX_BURSTS * 2:
		world.effects.show_burst(Vector3(index, .5, 0), "ion")
	assert_eq(world.effects.bursts.size(), CombatEffects3D.MAX_BURSTS)
	for kind in CombatEffects3D.BURSTS:
		world.effects.show_burst(Vector3.ZERO, kind) # every preset builds a valid process material
	world.effects.reset()
	for burst in world.effects.bursts:
		assert_false(burst.emitting)

func test_hits_spawn_a_burst_coloured_by_damage_type() -> void:
	var enemy := _target()
	assert_eq(world.effects.bursts.size(), 0)
	world.effects.show_hit(enemy, CombatHit3D.new(1.0, Vector3.ZERO, Vector3.ZERO, GameEnums.DamageType.PLASMA), 1.0)
	assert_eq(world.effects.bursts.size(), 1)
	assert_same(world.effects.bursts[0].process_material, world.effects._burst_material("plasma"))

func test_scrap_pickup_has_model_glow_and_scales_with_value() -> void:
	var small := ScrapPickup.new()
	small.world = world
	world.pickup_root.add_child(small)
	var big := ScrapPickup.new()
	big.world = world
	big.amount = 6
	world.pickup_root.add_child(big)
	assert_gt(small.visual.get_child_count(), 0)
	assert_same(small.glow.material_override, EnergyFx.ground_glow_material())
	assert_gt(big.visual.scale.x, small.visual.scale.x)

func test_scrap_pull_accelerates_while_magnetised_and_resets_when_out_of_range() -> void:
	var pickup := ScrapPickup.new()
	pickup.world = world
	pickup.position = world.player.position + Vector3(.7, 0, 0)
	world.pickup_root.add_child(pickup)
	var first_start := pickup.position
	pickup._physics_process(.02)
	var first_step := first_start.distance_to(pickup.position)
	pickup.pulled_for = 1.0
	var later_start := pickup.position
	pickup._physics_process(.02)
	assert_gt(later_start.distance_to(pickup.position), first_step, "Pull speed ramps up the longer the magnet holds it")
	pickup.position = world.player.position + Vector3(20, 0, 0)
	pickup._physics_process(.02)
	assert_eq(pickup.pulled_for, 0.0)

func test_reduced_motion_pickup_spins_slowly_and_collect_bursts_once() -> void:
	SettingsService.set_reduced_motion(true, false)
	var pickup := ScrapPickup.new()
	pickup.world = world
	pickup.position = world.player.position + Vector3(5, 0, 0)
	world.pickup_root.add_child(pickup)
	pickup._physics_process(.5)
	assert_almost_eq(pickup.visual.rotation.y, .5 * 2.0 * GameConstants.REDUCED_MOTION_SPEED, .001)
	assert_eq(pickup.visual.position.y, ScrapPickup.REST_HEIGHT)
	var before := world.effects.bursts.size()
	pickup.collect()
	pickup.collect()
	assert_eq(world.effects.bursts.size(), before + 1)
	SettingsService.set_reduced_motion(false, false)

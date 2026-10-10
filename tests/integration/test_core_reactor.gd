extends GutTest

var core: CoreObjective

func before_each() -> void:
	TestHelpers.reset_all_services()
	core = CoreObjective.new()
	add_child_autofree(core)
	core.set_physics_process(false)
	core.set_process(false)

func test_rotors_freeze_for_reduced_motion_and_destroyed_core() -> void:
	assert_not_null(core.reactor)
	if not core.reactor:
		return
	var visual := core.reactor
	visual.tick(1.0, 1.0, false, 0.0, false)
	var poses: Array[Transform3D] = []
	for ring in visual.rings:
		poses.append(ring.transform)
		assert_false(ring.basis.is_equal_approx(Basis.IDENTITY))
	var phase := visual.phase
	visual.tick(1.0, .25, false, 1.0, true)
	assert_eq(visual.phase, phase)
	assert_eq(visual.orb_material.get_shader_parameter("hit"), 0.0)
	for i in range(3):
		assert_eq(visual.rings[i].transform, poses[i])
	visual.tick(1.0, 0.0, true, 1.0, false)
	assert_eq(visual.phase, phase)
	assert_eq(visual.light.light_energy, 0.0)
	assert_lt(float(visual.orb_material.get_shader_parameter("power")), .1)
	for i in range(3):
		assert_eq(visual.rings[i].transform, poses[i])

func test_damage_repair_and_reset_drive_the_reactor_without_changing_gameplay() -> void:
	assert_not_null(core.reactor)
	if not core.reactor:
		return
	core.reset(100.0)
	assert_eq(core.take_hit(75.0), 75.0)
	core._physics_process(.01)
	assert_true((core.reactor.orb_material.get_shader_parameter("energy_color") as Color).is_equal_approx(CoreObjective.CRITICAL.lerp(CoreObjective.HEALTHY, .25)))
	assert_eq(core.repair(10.0), 10.0)
	assert_eq(core.health, 35.0)
	assert_eq(core.take_hit(50.0), 35.0)
	core._physics_process(.01)
	assert_true(core.dead)
	assert_eq(core.repair(50.0), 0.0)
	assert_eq(core.radius, GameConstants.CORE_RADIUS)
	core.reset(100.0)
	core._physics_process(.01)
	assert_false(core.dead)
	assert_eq(float(core.reactor.orb_material.get_shader_parameter("power")), 1.0)
	assert_true((core.reactor.orb_material.get_shader_parameter("energy_color") as Color).is_equal_approx(CoreObjective.HEALTHY))

extends GutTest

func _rig() -> Node3D:
	var model := Node3D.new()
	for part: String in ["Body", "Head", "Arm_L", "Arm_R", "Leg_L", "Leg_R", "Muzzle"]:
		var node := Node3D.new()
		node.name = part
		node.position = Vector3(.1, .4, -.2)
		node.rotation = Vector3(.15, -.2, .1)
		model.add_child(node)
	add_child_autofree(model)
	return model

func test_reduced_motion_restores_authored_pose_and_motion_resumes() -> void:
	var model := _rig()
	var motion := ClockworkMotion.new(model, "hero")
	var leg := model.get_node("Leg_L") as Node3D
	var initial := leg.transform
	motion.tick(.1, 2.0, false)
	assert_false(leg.transform.is_equal_approx(initial), "Moving hero poses a leg")
	motion.tick(.1, 2.0, true)
	assert_true(leg.transform.is_equal_approx(initial), "Reduced motion restores the authored basis and position")
	motion.tick(.1, 2.0, false)
	assert_false(leg.transform.is_equal_approx(initial), "Leaving reduced motion resumes posing")

func test_carry_pose_does_not_move_weapon_arm_and_stopping_restores_feet() -> void:
	var model := _rig()
	var motion := ClockworkMotion.new(model, "hero")
	var weapon := model.get_node("Arm_R") as Node3D
	var hand := model.get_node("Arm_L") as Node3D
	var leg := model.get_node("Leg_L") as Node3D
	var weapon_rest := weapon.transform
	var hand_rest := hand.transform
	var leg_rest := leg.transform
	motion.tick(.1, 2.0, false, true)
	assert_false(hand.transform.is_equal_approx(hand_rest), "Carrying raises the utility arm")
	assert_true(weapon.transform.is_equal_approx(weapon_rest), "Locomotion leaves the aiming arm untouched")
	motion.tick(.1, 0.0, false, false)
	assert_true(leg.transform.is_equal_approx(leg_rest), "Stopped feet return to authored stance")
	assert_true(hand.transform.is_equal_approx(hand_rest), "Releasing a carried turret restores idle hand")

func test_upper_body_aim_uses_world_heading_and_preserves_hips() -> void:
	var model := _rig()
	model.rotation.y = .7
	var body := model.get_node("Body") as Node3D
	body.rotation = Vector3.ZERO
	var leg := model.get_node("Leg_L") as Node3D
	var initial := leg.transform
	var motion := ClockworkMotion.new(model, "hero")
	for heading: Vector3 in [Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		motion.aim_hero(heading)
		assert_gt((-body.global_basis.z).normalized().dot(heading), .999)
		assert_true(leg.transform.is_equal_approx(initial), "Aiming leaves the hip pose unchanged")
	motion.aim_hero(Vector3.ZERO)
	assert_true(body.basis.is_equal_approx(Basis.IDENTITY), "Losing a target restores the torso rest orientation")

func test_recoil_recovers_and_reduced_motion_suppresses_it() -> void:
	var model := _rig()
	var arm := model.get_node("Arm_R") as Node3D
	var initial := arm.transform
	var motion := ClockworkMotion.new(model, "hero")
	motion.fire(false)
	motion.tick(.016, 0.0, false)
	assert_gt(arm.position.z, initial.origin.z)
	motion.tick(.2, 0.0, false)
	assert_true(arm.transform.is_equal_approx(initial))
	motion.fire(true)
	motion.tick(.016, 0.0, true)
	assert_true(arm.transform.is_equal_approx(initial))

func test_quadruped_lift_keeps_feet_above_ground_and_stops_at_rest() -> void:
	var model := Node3D.new()
	add_child_autofree(model)
	for side: String in ["L", "R"]:
		for index in range(2):
			var hip := Node3D.new()
			hip.name = "Leg_%s_%d" % [side, index]
			hip.position.y = .3
			model.add_child(hip)
			var foot := Node3D.new()
			foot.name = "Foot"
			foot.position = Vector3(-.3 if side == "L" else .3, -.3, 0)
			hip.add_child(foot)
	var motion := ClockworkMotion.new(model, "charger")
	motion.stagger = Engine.get_physics_frames() % 2
	var lowest := 1.0
	var highest := 0.0
	for step in range(40):
		motion.tick(.05, 2.0, false)
		for hip in motion.limbs:
			var height: float = hip.get_node("Foot").global_position.y
			lowest = minf(lowest, height)
			highest = maxf(highest, height)
	assert_gte(lowest, -.0001, "Mirrored hips lift feet instead of pushing them below ground")
	assert_gt(highest, .02, "The gait includes visible swing clearance")
	var left_front: Node3D = model.get_node("Leg_L_0/Foot")
	var right_front: Node3D = model.get_node("Leg_R_0/Foot")
	assert_lt(left_front.global_position.z * right_front.global_position.z, 0.0, "Opposite front feet travel in opposite stride phases")
	motion.tick(.1, 0.0, false)
	for hip in motion.limbs:
		assert_true(hip.transform.is_equal_approx(motion.rest[hip]))

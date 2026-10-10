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

extends GutTest

## Completion gate: a partial roster or a silent fallback is not a finished conversion.
func test_complete_reviewed_roster_is_present_and_importable() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/models/clockwork/manifest.json"))
	var records: Array = manifest.get("assets", [])
	assert_eq(records.size(), ClockworkModels.KEYS.size())
	var ids: Array[String] = []
	for record: Dictionary in records:
		ids.append(record["id"])
		assert_eq(FileAccess.get_sha256("res://" + record["model"]), record["sha256"], "Export must match the reviewed asset")
	for key in ClockworkModels.KEYS:
		assert_has(ids, key)
		assert_true(ResourceLoader.exists(ClockworkModels.model_path(key)), "Missing imported model: " + key)

func test_imported_roster_has_the_required_articulation() -> void:
	for key in ClockworkModels.KEYS:
		if not ResourceLoader.exists(ClockworkModels.model_path(key)):
			fail_test("Cannot inspect missing model: " + key)
			continue
		var model := (load(ClockworkModels.model_path(key)) as PackedScene).instantiate() as Node3D
		add_child_autofree(model)
		var required: Array[String] = ["Body"]
		if key in ["ion", "plasma", "tesla", "shock", "melee", "machine_gun", "scatter", "saber", "gatling", "crossfire", "siege", "bow", "flamethrower", "bowling", "gunblade", "focused_lance", "resonator", "thunder_pin", "thunder_spear", "resonance_engine", "thunderhead", "storm_network", "sniper", "quake", "decoy", "scrap_press"]:
			required = ["Aim", "Muzzle"]
		elif key == "arrow":
			required = ["FlightRoot", "Arrow"]
		elif key == "bowling_ball":
			required = [] # Single centered rigid mesh, no articulated markers.
		elif key == "core":
			required = ["Body", "Orb", "Ring_Outer", "Ring_Middle", "Ring_Inner"]
		elif key == "hero":
			required = ["Body", "Head", "Arm_L", "Arm_R", "Leg_L", "Leg_R", "Muzzle"]
		elif key == "fast":
			required = ["Body", "Wing_L", "Wing_R"]
		elif key in ["tank", "charger"]:
			for side in ["L", "R"]:
				for index in range(3 if key == "tank" else 2):
					required.append("Leg_%s_%d" % [side, index])
		for part in required:
			assert_not_null(model.find_child(part, true, false), key + ": " + part)
		var muzzle := model.find_child("Muzzle", true, false) as Node3D
		if muzzle:
			assert_eq(muzzle.get_child_count(), 0, "Muzzle is a bare marker")
			assert_eq(muzzle.get_parent().name, &"Arm_R" if key == "hero" else (&"Body" if key in ["prism_conductor", "lens"] else &"Aim"))
			assert_gt((-muzzle.global_basis.z).dot(Vector3.FORWARD), .99, key + " faces forward at rest")
		if key in ["hero", "tank", "charger"]:
			var motion := ClockworkMotion.new(model, key)
			assert_eq(motion.limbs.size(), 2 if key == "hero" else 6 if key == "tank" else 4)
			var body := motion.body
			for leg in motion.limbs:
				assert_false(body.is_ancestor_of(leg), "Torso motion must not drag the planted hip pivots")

func test_grounded_roster_walks_without_floor_penetration_and_returns_to_rest() -> void:
	for key: String in ["hero", "tank", "charger"]:
		if not ResourceLoader.exists(ClockworkModels.model_path(key)):
			fail_test("Cannot check missing model: " + key)
			continue
		var model := (load(ClockworkModels.model_path(key)) as PackedScene).instantiate() as Node3D
		add_child_autofree(model)
		var motion := ClockworkMotion.new(model, key)
		motion.stagger = Engine.get_physics_frames() % 2
		var lowest := INF
		var moved := false
		for step in range(40):
			motion.tick(.05, 2.0, false)
			for leg in motion.limbs:
				moved = moved or not leg.transform.is_equal_approx(motion.rest[leg])
				for mesh: MeshInstance3D in leg.find_children("*", "MeshInstance3D", true, false):
					var bounds := mesh.get_aabb()
					for corner in range(8):
						lowest = minf(lowest, (mesh.global_transform * bounds.get_endpoint(corner)).y)
		assert_true(moved, key + " has moving legs")
		assert_gte(lowest, -.025, key + " feet stay on or above the ground tolerance")
		motion.tick(.1, 0.0, false)
		for leg in motion.limbs:
			assert_true(leg.transform.is_equal_approx(motion.rest[leg]), key + " stops in authored stance")

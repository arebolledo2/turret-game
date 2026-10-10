class_name ClockworkMotion
extends RefCounted

## Cached rigid-part posing. No per-enemy AnimationPlayer or tree scans during updates.
var kind: String
var body: Node3D
var rest: Dictionary = {}
var limbs: Array[Node3D] = []
var limb_phases: Array[float] = []
var limb_sides: Array[float] = []
var foot_bounds: Dictionary = {}
var foot_floors: Dictionary = {}
var wings: Array[Node3D] = []
var left_arm: Node3D
var right_arm: Node3D
var recoil: float = 0.0
var phase: float = 0.0
var hover_phase: float = 0.0
var stagger: int = 0
var was_reduced: bool = false

func _init(model: Node3D, asset_kind: String) -> void:
	kind = asset_kind
	stagger = model.get_instance_id() % 2
	hover_phase = float(model.get_instance_id() % 631) * .01
	body = _part(model, "Body")
	if kind in ["tank", "charger"]:
		for side: String in ["L", "R"]:
			for index in range(3 if kind == "tank" else 2):
				var limb := _part(model, "Leg_%s_%d" % [side, index])
				if limb:
					limbs.append(limb)
					limb_phases.append(float((index + (1 if side == "R" else 0)) % 2) * PI)
					limb_sides.append(1.0 if side == "L" else -1.0)
	elif kind == "hero":
		for part: String in ["Leg_L", "Leg_R"]:
			var limb := _part(model, part)
			if limb:
				limbs.append(limb)
		left_arm = _part(model, "Arm_L")
		right_arm = _part(model, "Arm_R")
	elif kind == "fast":
		for part: String in ["Wing_L", "Wing_R"]:
			var wing := _part(model, part)
			if wing:
				wings.append(wing)
	for limb in limbs:
		_cache_foot_bounds(limb)

func _cache_foot_bounds(limb: Node3D) -> void:
	var points := PackedVector3Array()
	for mesh: MeshInstance3D in limb.find_children("*", "MeshInstance3D", true, false):
		var relative := mesh.transform
		var parent := mesh.get_parent_node_3d()
		while parent != limb:
			relative = parent.transform * relative
			parent = parent.get_parent_node_3d()
		var bounds := mesh.get_aabb()
		for corner in range(8):
			points.append(relative * bounds.get_endpoint(corner))
	if points.is_empty():
		return
	foot_bounds[limb] = points
	var floor_height := INF
	for point in points:
		floor_height = minf(floor_height, (limb.transform * point).y)
	foot_floors[limb] = floor_height

func _keep_foot_above_floor(limb: Node3D) -> void:
	if not foot_bounds.has(limb):
		return
	var lowest := INF
	for point: Vector3 in foot_bounds[limb]:
		lowest = minf(lowest, (limb.transform * point).y)
	limb.position.y += maxf(0.0, float(foot_floors[limb]) - lowest)

func _part(model: Node3D, part_name: String) -> Node3D:
	var node := model.find_child(part_name, true, false) as Node3D
	if node:
		rest[node] = node.transform
	return node

func reset() -> void:
	for node: Node3D in rest:
		node.transform = rest[node]

func tick(delta: float, speed: float, reduced: bool, carrying: bool = false) -> void:
	phase += speed * delta * 6.0
	hover_phase += delta * 2.5
	recoil = maxf(0.0, recoil - delta * .3)
	if reduced:
		if not was_reduced:
			reset()
		was_reduced = true
		return
	was_reduced = false
	# Hero is immediate; enemy cosmetic poses are staggered over two physics ticks.
	if kind != "hero" and (Engine.get_physics_frames() + stagger) % 2 != 0:
		return
	var moving := clampf(speed / 1.5, 0.0, 1.0)
	if body:
		body.transform = rest[body]
		if kind in ["basic", "fast", "exploder"]:
			body.position.y += sin(hover_phase) * .035
		elif moving > .01:
			body.position.y += absf(sin(phase)) * .018 * moving
	for index in range(limbs.size()):
		if kind in ["tank", "charger"]:
			var cycle := phase + limb_phases[index]
			var initial: Transform3D = rest[limbs[index]]
			var sweep := sin(cycle) * .16 * moving
			var lift := maxf(0.0, cos(cycle)) * .14 * moving * limb_sides[index]
			limbs[index].transform = Transform3D(initial.basis * Basis(Vector3.UP, sweep) * Basis(Vector3.FORWARD, lift), initial.origin)
		else:
			var angle := sin(phase + float(index % 2) * PI) * .24 * moving
			_pose(limbs[index], Vector3.RIGHT, angle)
		_keep_foot_above_floor(limbs[index])
	for index in range(wings.size()):
		_pose(wings[index], Vector3.FORWARD, sin(hover_phase * 3.0) * .16 * (-1.0 if index == 0 else 1.0))
	if left_arm:
		_pose(left_arm, Vector3.RIGHT, -.65 if carrying else -sin(phase) * .18 * moving)
	if right_arm:
		right_arm.transform = rest[right_arm]
		right_arm.position.z += recoil

## Aim the torso independently of the hip pivots; heading is in world space.
func aim_hero(heading: Vector3) -> void:
	if kind != "hero" or not body:
		return
	var initial: Transform3D = rest[body]
	if heading.length_squared() < .0001:
		body.basis = initial.basis
		return
	var local_heading := body.get_parent_node_3d().global_basis.inverse() * heading
	var yaw := atan2(-local_heading.x, -local_heading.z)
	body.basis = Basis(Vector3.UP, yaw) * initial.basis

func fire(reduced: bool) -> void:
	if right_arm and not reduced:
		recoil = .025

func _pose(node: Node3D, axis: Vector3, angle: float) -> void:
	var initial: Transform3D = rest[node]
	node.transform = Transform3D(initial.basis * Basis(axis, angle), initial.origin)

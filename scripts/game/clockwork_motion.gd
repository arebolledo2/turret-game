class_name ClockworkMotion
extends RefCounted

## Cached rigid-part posing. No per-enemy AnimationPlayer or tree scans during updates.
var kind: String
var body: Node3D
var rest: Dictionary = {}
var limbs: Array[Node3D] = []
var wings: Array[Node3D] = []
var left_arm: Node3D
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
	elif kind == "hero":
		for part: String in ["Leg_L", "Leg_R"]:
			var limb := _part(model, part)
			if limb:
				limbs.append(limb)
		left_arm = _part(model, "Arm_L")
	elif kind == "fast":
		for part: String in ["Wing_L", "Wing_R"]:
			var wing := _part(model, part)
			if wing:
				wings.append(wing)

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
		var angle := sin(phase + float(index % 2) * PI) * .24 * moving
		_pose(limbs[index], Vector3.RIGHT, angle)
	for index in range(wings.size()):
		_pose(wings[index], Vector3.FORWARD, sin(hover_phase * 3.0) * .16 * (-1.0 if index == 0 else 1.0))
	if left_arm:
		_pose(left_arm, Vector3.RIGHT, -.65 if carrying else -sin(phase) * .18 * moving)

func _pose(node: Node3D, axis: Vector3, angle: float) -> void:
	var initial: Transform3D = rest[node]
	node.transform = Transform3D(initial.basis * Basis(axis, angle), initial.origin)

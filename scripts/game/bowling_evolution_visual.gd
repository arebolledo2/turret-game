class_name BowlingEvolutionVisual
extends Node3D

static var materials: Dictionary = {}
var flippers: Array[Node3D] = []
var kick_time := 0.0

static func build(model: Node3D, form_id: String, stage: int) -> BowlingEvolutionVisual:
	if stage < 1 or form_id not in ["heavy_roller", "juggernaut", "ricochet_king"]:
		return null
	if materials.is_empty():
		for entry in [["brass", "dba94c", .8], ["purple", "624483", .45], ["dark", "202a33", .4]]:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(entry[1])
			material.metallic = entry[2]
			material.roughness = .3
			materials[entry[0]] = material
	var aim := model.find_child("Aim", true, false) as Node3D
	var hardware := BowlingEvolutionVisual.new()
	hardware.name = "BowlingEvolutionHardware"
	aim.add_child(hardware)
	if form_id in ["heavy_roller", "juggernaut"]:
		var growth := 1.0 + .25 * stage
		# Widen the complete cradle and raise its launch height with the ball radius.
		aim.scale = Vector3(growth, growth, 1.0)
		var ball := model.find_child("LoadedBall", true, false) as Node3D
		ball.scale.z *= growth # The ball remains spherical inside the wider housing.
		var plinth := model.find_child("Static coral rounded plinth", true, false) as Node3D
		plinth.scale.x *= growth
		# Paired hydraulic braces reinforce the heavier housing at each milestone.
		for side in [-1, 1]:
			for i in range(stage):
				var z := .40 - i * .25
				var sleeve := _cylinder(hardware, .07, .48, "dark")
				sleeve.position = Vector3(side * .48, .48, z)
				var piston := _cylinder(hardware, .035, .30, "brass")
				piston.position = Vector3(side * .48, .83, z)
				var cap := _cylinder(hardware, .085, .07, "brass")
				cap.position = Vector3(side * .48, .71, z)
	else:
		for side in [-1, 1]:
			for i in range(stage):
				var z := -.50 - i * .27
				var height := .50 - (-z - .25) * .26 + .08
				var bumper := _cylinder(hardware, .13, .08, "brass")
				bumper.position = Vector3(side * .39, height, z)
				var top := _cylinder(hardware, .095, .09, "purple")
				top.position = bumper.position + Vector3(0, .07, 0)
			var pivot := Node3D.new()
			hardware.add_child(pivot)
			pivot.position = Vector3(side * .38, .29, -1.28)
			var paddle := MeshInstance3D.new()
			var mesh := CapsuleMesh.new()
			mesh.radius = .055
			mesh.height = .38
			mesh.radial_segments = 16
			mesh.rings = 4
			paddle.mesh = mesh
			paddle.material_override = materials.brass
			paddle.rotation.x = PI * .5
			paddle.position.z = .13
			pivot.add_child(paddle)
			hardware.flippers.append(pivot)
	return hardware

static func _cylinder(parent: Node3D, radius: float, height: float, material: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = materials[material]
	parent.add_child(instance)
	return instance

func kick() -> void:
	kick_time = .22

func advance(delta: float, reduced_motion: bool) -> void:
	kick_time = maxf(0.0, kick_time - delta)
	for i in flippers.size():
		flippers[i].rotation.y = (1 if i == 0 else -1) * (.5 * sin(kick_time / .22 * PI) if not reduced_motion else 0.0)

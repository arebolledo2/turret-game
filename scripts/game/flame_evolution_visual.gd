class_name FlameEvolutionVisual
extends RefCounted

## Burner manifolds and pressure-lance hardware added to the authored fuel-tank chassis.
static var materials: Dictionary = {}

static func build(model: Node3D, branch: String, stage: int) -> Array[Node3D]:
	var emitters: Array[Node3D] = []
	if stage < 1 or branch not in ["wide_flame", "focused_jet"]:
		return emitters
	if materials.is_empty():
		for entry in [["brass", "dba94c", .8], ["teal", "237d82", .35], ["dark", "16232b", .4], ["coral", "d7695a", .2]]:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(entry[1])
			material.metallic = entry[2]
			material.roughness = .3
			materials[entry[0]] = material
	var aim := model.find_child("Aim", true, false) as Node3D
	var muzzle := model.find_child("Muzzle", true, false) as Node3D
	var hardware := Node3D.new()
	hardware.name = "EvolutionBurners"
	aim.add_child(hardware)
	hardware.position = Vector3(0, .89, -.58)
	if branch == "wide_flame":
		# A visible horizontal fuel manifold supports each added burner pair.
		var manifold := _cylinder(hardware, .075, .075, .68 * stage, "brass")
		manifold.rotation.z = PI * .5
		for side in [-1, 1]:
			for index in range(1, stage + 1):
				var burner := Node3D.new()
				burner.name = "Burner_%d_%d" % [side, index]
				hardware.add_child(burner)
				burner.position.x = side * .34 * index
				burner.rotation.y = -side * deg_to_rad([22.0, 34.0, 47.0][stage - 1]) * float(index) / stage
				var body := _cylinder(burner, .105, .14, .33, "teal")
				body.rotation.x = PI * .5
				body.position.z = -.08
				_ring(burner, .10, .15, -.245)
				_ring(burner, .10, .13, -.19)
				var recess := _cylinder(burner, .095, .095, .025, "dark")
				recess.rotation.x = PI * .5
				recess.position.z = -.19
				var exit := Node3D.new()
				exit.name = "BurnerMuzzle"
				exit.position.z = -.26
				burner.add_child(exit)
				emitters.append(exit)
	else:
		var length := .22 + .18 * stage
		var lance := _cylinder(hardware, .19, .11, length, "teal")
		lance.rotation.x = PI * .5
		lance.position.z = -.24 - length * .5
		for index in range(stage + 2):
			var fraction := float(index) / float(stage + 1)
			_ring(hardware, .10, lerpf(.21, .14, fraction), -.24 - fraction * length)
		var bore := _cylinder(hardware, .10, .10, .018, "dark")
		bore.rotation.x = PI * .5
		bore.position.z = -.23 - length
		muzzle.position.z = hardware.position.z - .25 - length
	return emitters

static func _cylinder(parent: Node3D, top: float, bottom: float, height: float, material: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 1
	mesh.cap_top = material == "dark"
	mesh.cap_bottom = material == "dark"
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = materials[material]
	parent.add_child(instance)
	return instance

static func _ring(parent: Node3D, inner: float, outer: float, z: float) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 24
	mesh.ring_segments = 8
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = materials.brass
	instance.rotation.x = PI * .5
	instance.position.z = z
	parent.add_child(instance)

class_name QuakeEvolutionVisual
extends RefCounted

## Runtime stomp hardware for the Quake line. There is no Quake chassis yet, so every stage is the Shock bell, and this
## builder gives each stage its own silhouette at the foot of the turret:
##   Quake      a broad steel foot plate with brass bolts.
##   Aftershock the plate plus twin brass hammer pistons and a glowing damper ring (the second pulse's hardware).
##   Tectonic   two crossed glowing blades laid in an X on the plate, with a drill spike at each tip (the two fissures).
##   Cataclysm  three stacked glowing rings climbing the bell and four corner pylons (the growing repeats).
## Parts hang off the model root, which is the turret's origin on the floor.
static var materials: Dictionary = {}

static func build(model: Node3D, base_type: String, form_id: String) -> void:
	if base_type != "quake":
		return
	_ensure_materials()
	_cylinder(model, "QuakeFootPlate", .8, .07, "dark", Vector3(0, .035, 0))
	_cylinder(model, "QuakeFootRim", .84, .035, "steel", Vector3(0, .02, 0))
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		_cylinder(model, "QuakeBolt", .05, .1, "brass", Vector3(cos(angle) * .7, .1, sin(angle) * .7))
	match form_id:
		"aftershock":
			for side: float in [-1.0, 1.0]:
				_cylinder(model, "AftershockPiston", .075, .62, "steel", Vector3(side * .66, .42, 0))
				_cylinder(model, "AftershockCollar", .105, .07, "brass", Vector3(side * .66, .62, 0))
				_cylinder(model, "AftershockHammer", .17, .11, "brass", Vector3(side * .66, .13, 0))
			_torus(model, "AftershockRing", .56, .62, "teal", Vector3(0, .13, 0))
		"tectonic":
			for side: float in [-1.0, 1.0]:
				_box(model, "TectonicBlade", Vector3(2.0, .07, .2), "teal", Vector3(0, .11, 0), side * PI / 4.0)
			for index in range(4):
				var angle := PI / 4.0 + PI * .5 * float(index)
				_cone(model, "TectonicSpike", .12, .42, "brass", Vector3(cos(angle) * .92, .24, sin(angle) * .92))
		"cataclysm":
			for index in range(3):
				_torus(model, "CataclysmRing", .5 - .06 * float(index), .56 - .06 * float(index), "teal" if index != 1 else "amber", Vector3(0, .32 + .3 * float(index), 0))
			for index in range(4):
				var angle := PI / 4.0 + PI * .5 * float(index)
				_cylinder(model, "CataclysmPylon", .055, 1.05, "steel", Vector3(cos(angle) * .7, .55, sin(angle) * .7))
				_sphere(model, "CataclysmBeacon", .09, "amber", Vector3(cos(angle) * .7, 1.1, sin(angle) * .7))

static func _ensure_materials() -> void:
	if not materials.is_empty():
		return
	for entry in [["brass", "dba94c", .8, 0.0], ["steel", "a9cfcc", .75, 0.0], ["dark", "16232b", .4, 0.0], ["teal", "6df0b0", .35, 1.6], ["amber", "ffb02e", .3, 1.8]]:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(entry[1])
		material.metallic = entry[2]
		material.roughness = .3
		if entry[3] > 0.0:
			material.emission_enabled = true
			material.emission = Color(entry[1])
			material.emission_energy_multiplier = entry[3]
		materials[entry[0]] = material

static func _cylinder(parent: Node3D, label: String, radius: float, height: float, material: String, at: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.rings = 1
	_part(parent, label, mesh, material, at, 0.0)

static func _cone(parent: Node3D, label: String, radius: float, height: float, material: String, at: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	_part(parent, label, mesh, material, at, 0.0)

static func _box(parent: Node3D, label: String, size: Vector3, material: String, at: Vector3, yaw: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_part(parent, label, mesh, material, at, yaw)

static func _torus(parent: Node3D, label: String, inner: float, outer: float, material: String, at: Vector3) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 8
	_part(parent, label, mesh, material, at, 0.0)

static func _sphere(parent: Node3D, label: String, radius: float, material: String, at: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	_part(parent, label, mesh, material, at, 0.0)

static func _part(parent: Node3D, label: String, mesh: Mesh, material: String, at: Vector3, yaw: float) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = materials[material]
	instance.position = at
	instance.rotation.y = yaw
	parent.add_child(instance)

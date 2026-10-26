class_name QuakeEvolutionVisual
extends RefCounted

## Runtime stomp hardware for the Quake line. Every form shares the cp_quake chassis (a teal cube with a brass hammer on
## three coral legs, standing on a cracked stone slab); the slab already is the foot of the turret, so the upgrade and the
## finals add their own silhouette around it:
##   Quake      the bare chassis.
##   Aftershock twin brass hammer pistons planted on the slab and a glowing damper ring laid on it (the second pulse).
##   Tectonic   four glowing cracks running out of the slab, each with a brass drill spike at the slab edge (the X of fissures).
##   Cataclysm  three glowing ripple rings on the ground around the slab and four amber-tipped pylons (the growing repeats).
## Sizes come from the model itself (`_footprint`): the slab radius and top from `Base_Stone`, the cube top from
## `Aim_Body`, so a re-authored chassis keeps the hardware on its slab. Parts hang off the model root, which is the
## turret's origin on the floor and the centre of the slab (the pulse ring, telegraph and fissures are driven from there).
static var materials: Dictionary = {}

## Fallbacks if the chassis meshes are missing: the cp_quake slab radius and top and the cube top, in metres.
const DEFAULT_SLAB_RADIUS: float = .89
const DEFAULT_SLAB_TOP: float = .2
const DEFAULT_BODY_TOP: float = 1.22
## Hardware angles (radians, atan2(z, x) around the turret) chosen to sit clear of the chassis: its legs stand at 110, 230 and
## 350 degrees and its loose stone chunks lie at 60, 125 and 340 degrees. Pistons go in two of the gaps between legs; cracks and pylons
## are spread around the slab edge.
const CRACK_ANGLES: Array[float] = [.17, 1.75, 3.32, 4.89]
const PISTON_ANGLES: Array[float] = [2.97, .87]

static func build(model: Node3D, form_id: String) -> void:
	if form_id not in ["aftershock", "tectonic", "cataclysm"]:
		return
	_ensure_materials()
	var footprint := _footprint(model)
	var radius: float = footprint.radius
	var top: float = footprint.top
	match form_id:
		"aftershock":
			for index in PISTON_ANGLES.size():
				var at := _polar(PISTON_ANGLES[index], radius * .84)
				_cylinder(model, "AftershockPiston", .075, .62, "steel", Vector3(at.x, top + .31, at.z))
				_cylinder(model, "AftershockCollar", .105, .07, "brass", Vector3(at.x, top + .56, at.z))
				_cylinder(model, "AftershockHammer", .17, .11, "brass", Vector3(at.x, top + .055, at.z))
			_torus(model, "AftershockRing", radius * .83 - .035, radius * .83 + .035, "teal", Vector3(0, top + .012, 0))
		"tectonic":
			for angle in CRACK_ANGLES:
				var inner := radius * .94
				var length := .5
				var middle := _polar(angle, inner + length * .5)
				_box(model, "TectonicBlade", Vector3(length, .05, .14), "teal", Vector3(middle.x, .03, middle.z), -angle)
				var spike := _polar(angle, radius * 1.02)
				_cone(model, "TectonicSpike", .12, .46, "brass", Vector3(spike.x, .23, spike.z))
		"cataclysm":
			for index in range(3):
				var ring_radius := radius * 1.08 + .12 * float(index)
				_torus(model, "CataclysmRing", ring_radius - .025, ring_radius + .025, "teal" if index != 1 else "amber", Vector3(0, .03, 0))
			for angle in CRACK_ANGLES:
				var at := _polar(angle, radius * .98)
				_cylinder(model, "CataclysmPylon", .055, 1.05, "steel", Vector3(at.x, .525, at.z))
				_cylinder(model, "CataclysmCap", .09, .07, "brass", Vector3(at.x, 1.05, at.z))
				_sphere(model, "CataclysmBeacon", .09, "amber", Vector3(at.x, 1.12, at.z))

## The chassis' own measurements: slab radius (half the narrower side of `Base_Stone`) and top, cube top (`Aim_Body`).
static func _footprint(model: Node3D) -> Dictionary:
	var result := {"radius": DEFAULT_SLAB_RADIUS, "top": DEFAULT_SLAB_TOP, "body_top": DEFAULT_BODY_TOP}
	var slab := model.find_child("Base_Stone", true, false) as MeshInstance3D
	if slab and slab.mesh:
		var box := slab.mesh.get_aabb()
		result.radius = minf(box.size.x, box.size.z) * .5
		result.top = box.end.y
	var body := model.find_child("Aim_Body", true, false) as MeshInstance3D
	if body and body.mesh:
		result.body_top = body.mesh.get_aabb().end.y
	return result

static func _polar(angle: float, radius: float) -> Vector3:
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

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

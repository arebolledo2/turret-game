class_name SiegeEvolutionVisual
extends RefCounted

static var materials: Dictionary = {}
## Worldbreaker hardware: pressure housing pairs per side (each one wider and higher than the last) and barrel bands.
const HOUSING_PAIRS: int = 2
const BARREL_BANDS: int = 3

static func build(model: Node3D, form_id: String) -> void:
	if form_id not in ["siege", "worldbreaker"]:
		return
	var barrel := model.find_child("Barrel", true, false) as Node3D
	var muzzle := model.find_child("Muzzle", true, false) as Node3D
	# Keep the launch point attached to the authored recoiling bore.
	muzzle.reparent(barrel, true)
	if form_id != "worldbreaker":
		return
	var aim := model.find_child("Aim", true, false) as Node3D
	var growth := 1.0 + .18 * HOUSING_PAIRS
	barrel.scale = Vector3(growth, growth, 1.0)
	if materials.is_empty():
		for entry in [["brass", "dba94c", .8], ["teal", "237d82", .35], ["steel", "a9cfcc", .75], ["coral", "d7695a", .25]]:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(entry[1])
			material.metallic = entry[2]
			material.roughness = .3
			materials[entry[0]] = material
	for i in range(HOUSING_PAIRS):
		for side: float in [-1.0, 1.0]:
			var x := side * (.34 + .075 * i)
			var y := -.10 + .22 * i
			# Fixed pressure housings with sliding rods attached to the recoil node.
			_cylinder(aim, "HydraulicHousing%d_%s" % [i, side], .10, .52, "teal", barrel.position + Vector3(x, y, .04))
			_cylinder(barrel, "RecoilRod%d_%s" % [i, side], .038, .62, "steel", Vector3(x / growth, y / growth, -.32))
			for z: float in [-.19, .25]:
				_cylinder(aim, "PressureCollar", .115, .055, "brass", barrel.position + Vector3(x, y, z))
	for i in range(BARREL_BANDS):
		var band := TorusMesh.new()
		band.inner_radius = .218
		band.outer_radius = .267
		band.rings = 32
		band.ring_segments = 8
		_part(barrel, "BarrelBand%d" % i, band, "coral" if i == 1 else "brass", Vector3(0, 0, -.25 - .23 * i))

static func _cylinder(parent: Node3D, label: String, radius: float, length: float, material: String, at: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 20
	mesh.rings = 1
	_part(parent, label, mesh, material, at)

static func _part(parent: Node3D, label: String, mesh: Mesh, material: String, at: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = materials[material]
	instance.position = at
	instance.rotation.x = PI * .5
	parent.add_child(instance)

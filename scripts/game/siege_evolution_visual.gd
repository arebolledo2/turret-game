class_name SiegeEvolutionVisual
extends RefCounted

static var materials: Dictionary = {}

## Worldbreaker hardware: `housing_pairs` pressure housing pairs per side (each one wider and higher than the last) and
## `barrel_bands` bands on the barrel.
static func build(model: Node3D, form_id: String) -> TurretVisualHandles:
	if form_id not in ["siege", "worldbreaker", "mortar", "constellation"]:
		return null
	var barrel := model.find_child("Barrel", true, false) as Node3D
	var muzzle := model.find_child("Muzzle", true, false) as Node3D
	# Keep the launch point attached to the authored recoiling bore.
	muzzle.reparent(barrel, true)
	if form_id in ["mortar", "constellation"]:
		_build_mortar(barrel, form_id)
		return null
	if form_id != "worldbreaker":
		return null
	var aim := model.find_child("Aim", true, false) as Node3D
	var pairs := int(TurretEvolution.param(form_id, "housing_pairs", 1))
	var growth := 1.0 + .18 * pairs
	barrel.scale = Vector3(growth, growth, 1.0)
	if materials.is_empty():
		materials = VisualPalette.build([["brass", "dba94c", .8], ["teal", "237d82", .35], ["steel", "a9cfcc", .75], ["coral", "d7695a", .25]])
	for i in range(pairs):
		for side: float in [-1.0, 1.0]:
			var x := side * (.34 + .075 * i)
			var y := -.10 + .22 * i
			# Fixed pressure housings with sliding rods attached to the recoil node.
			_cylinder(aim, "HydraulicHousing%d_%s" % [i, side], .10, .52, "teal", barrel.position + Vector3(x, y, .04))
			_cylinder(barrel, "RecoilRod%d_%s" % [i, side], .038, .62, "steel", Vector3(x / growth, y / growth, -.32))
			for z: float in [-.19, .25]:
				_cylinder(aim, "PressureCollar", .115, .055, "brass", barrel.position + Vector3(x, y, z))
	for i in range(int(TurretEvolution.param(form_id, "barrel_bands", 1))):
		var band := TorusMesh.new()
		band.inner_radius = .218
		band.outer_radius = .267
		band.rings = 32
		band.ring_segments = 8
		_part(barrel, "BarrelBand%d" % i, band, "coral" if i == 1 else "brass", Vector3(0, 0, -.25 - .23 * i))
	return null

## Mortar and Constellation: the barrel tips up into a lobbing angle with collars along it; the Constellation also carries a
## halo of `points` + 1 small stars above the breech.
static func _build_mortar(barrel: Node3D, form_id: String) -> void:
	if materials.is_empty():
		materials = VisualPalette.build([["brass", "dba94c", .8], ["teal", "237d82", .35], ["steel", "a9cfcc", .75], ["coral", "d7695a", .25], ["star", "a97bff", .2, 1.1]])
	elif not materials.has("star"):
		materials.merge(VisualPalette.build([["star", "a97bff", .2, 1.1]]))
	barrel.rotation.x = deg_to_rad(float(TurretEvolution.param(form_id, "elevation", 24.0)))
	for i in 2:
		var band := TorusMesh.new()
		band.inner_radius = .218
		band.outer_radius = .267
		band.rings = 32
		band.ring_segments = 8
		_part(barrel, "MortarBand%d" % i, band, "brass", Vector3(0, 0, -.25 - .3 * i))
	var points := int(TurretEvolution.param(form_id, "points", 0))
	if points <= 0:
		return
	var aim := barrel.get_parent() as Node3D
	var halo := Node3D.new()
	halo.name = "ConstellationHalo"
	aim.add_child(halo)
	halo.position = Vector3(0, .95, .25)
	var stars: Array[Vector3] = [Vector3.ZERO]
	for index in points:
		stars.append(Vector3.RIGHT.rotated(Vector3.UP, TAU * float(index) / float(points)) * .42)
	for index in stars.size():
		var star := SphereMesh.new()
		star.radius = .10 if index == 0 else .075
		star.height = star.radius * 2.0
		star.radial_segments = 12
		star.rings = 6
		var instance := MeshInstance3D.new()
		instance.name = "Star%d" % index
		instance.mesh = star
		instance.material_override = materials["star"]
		instance.position = stars[index]
		halo.add_child(instance)

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

class_name SniperEvolutionVisual
extends RefCounted

## Runtime rifle hardware for the Sniper line. There is no Sniper chassis yet, so every stage is the Ion model and this
## builder gives the upgrade and the finals their own silhouette: a long barrel, brake and scope from the Piercer Rifle up,
## glowing rails on the Horizon Piercer and a spotter mast and ring on the Overwatch.
## Parts hang off `Aim` and are placed on the Ion barrel axis; the `Muzzle` node moves to the new barrel tip so shots and
## tracers leave from the end of the rifle.
static var materials: Dictionary = {}

## The Ion bore in `Aim` space: shots leave along -Z at this x and y.
const BORE_X: float = -.112
const BORE_Y: float = .276
const BARREL_START: float = -.50

static func build(model: Node3D, form_id: String, _stage: int) -> void:
	if form_id not in ["piercer_rifle", "horizon_piercer", "overwatch"]:
		return
	var aim := model.find_child("Aim", true, false) as Node3D
	var muzzle := model.find_child("Muzzle", true, false) as Node3D
	if aim == null or muzzle == null:
		return
	_ensure_materials()
	var horizon := form_id == "horizon_piercer"
	var tip: float = BARREL_START - (1.25 if horizon else .85)
	_cylinder(aim, "RifleBarrel", .042, absf(tip - BARREL_START), "steel", Vector3(BORE_X, BORE_Y, (tip + BARREL_START) * .5))
	var collars: Array[float] = []
	collars.assign([BARREL_START - .3, BARREL_START - .7, BARREL_START - 1.05] if horizon else [BARREL_START - .25, BARREL_START - .6])
	for z: float in collars:
		var collar := TorusMesh.new()
		collar.inner_radius = .04
		collar.outer_radius = .066
		collar.rings = 24
		collar.ring_segments = 8
		_part(aim, "RifleCollar", collar, "brass", Vector3(BORE_X, BORE_Y, z), Vector3(PI * .5, 0, 0))
	_cylinder(aim, "RifleBrake", .068, .13, "brass", Vector3(BORE_X, BORE_Y, tip))
	_cylinder(aim, "RifleScope", .05, .5, "steel", Vector3(BORE_X, BORE_Y + .2, -.2))
	_cylinder(aim, "RifleScopeLens", .056, .04, "teal" if form_id != "overwatch" else "amber", Vector3(BORE_X, BORE_Y + .2, -.46))
	if horizon:
		for side: float in [-1.0, 1.0]:
			var rail := BoxMesh.new()
			rail.size = Vector3(.03, .03, absf(tip - BARREL_START) + .2)
			_part(aim, "HorizonRail", rail, "teal", Vector3(BORE_X + side * .085, BORE_Y, (tip + BARREL_START) * .5), Vector3.ZERO)
	elif form_id == "overwatch":
		_cylinder(aim, "SpotterMast", .028, .42, "steel", Vector3(.12, .86, .12), true)
		var ring := TorusMesh.new()
		ring.inner_radius = .19
		ring.outer_radius = .23
		ring.rings = 32
		ring.ring_segments = 8
		_part(aim, "SpotterRing", ring, "amber", Vector3(.12, 1.12, .12), Vector3.ZERO)
		var lens := SphereMesh.new()
		lens.radius = .075
		lens.height = .15
		_part(aim, "SpotterLens", lens, "amber", Vector3(.12, 1.12, .12), Vector3.ZERO)
	muzzle.position = Vector3(BORE_X, BORE_Y, tip - .08)

static func _ensure_materials() -> void:
	if not materials.is_empty():
		return
	for entry in [["brass", "dba94c", .8, 0.0], ["steel", "a9cfcc", .75, 0.0], ["teal", "37d8d0", .35, 1.6], ["amber", "ffb02e", .3, 1.8]]:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(entry[1])
		material.metallic = entry[2]
		material.roughness = .3
		if entry[3] > 0.0:
			material.emission_enabled = true
			material.emission = Color(entry[1])
			material.emission_energy_multiplier = entry[3]
		materials[entry[0]] = material

## A cylinder along -Z (the bore direction); `upright` keeps it vertical for the spotter mast.
static func _cylinder(parent: Node3D, label: String, radius: float, length: float, material: String, at: Vector3, upright: bool = false) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 20
	mesh.rings = 1
	_part(parent, label, mesh, material, at, Vector3.ZERO if upright else Vector3(PI * .5, 0, 0))

static func _part(parent: Node3D, label: String, mesh: Mesh, material: String, at: Vector3, rotation: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = materials[material]
	instance.position = at
	instance.rotation = rotation
	parent.add_child(instance)

class_name SniperEvolutionVisual
extends RefCounted

## Runtime rifle hardware for the Sniper line. Every stage shares the cp_sniper chassis (teal, coral and brass rifle on a
## tripod); the upgrade and the finals add their own silhouette on top of it:
## - Piercer Rifle: a longer barrel with a brass muzzle brake and two collars along the teal barrel.
## - Horizon Piercer: a much longer barrel, glowing teal rails down both sides and an emitter ring at the tip.
## - Overwatch: a spotter mast behind the scope with a glowing amber ring and lens that faces the target.
## Parts hang off `Aim` around the model's own bore (read from its `Muzzle`), and `Muzzle` moves to the new tip so shots,
## tracers and muzzle flashes leave from the end of the rifle. Overwatch keeps the base barrel and muzzle.
static var materials: Dictionary = {}

## Bore radius of the chassis barrel and its brass muzzle ring (the extension starts flush with it).
const BARREL_RADIUS: float = .088
const MUZZLE_RING_RADIUS: float = .11
## How far past the chassis muzzle the Piercer Rifle brake and the Horizon barrel end.
const PIERCER_EXTENSION: float = .42
const HORIZON_EXTENSION: float = .8
## Mast base on top of the coral receiver (Aim space), behind the scope, and the mast and spotter ring sizes.
const MAST_BASE: Vector3 = Vector3(0, .34, .5)
const MAST_HEIGHT: float = .32

static func build(model: Node3D, form_id: String, _stage: int) -> void:
	if form_id not in ["piercer_rifle", "horizon_piercer", "overwatch"]:
		return
	var aim := model.find_child("Aim", true, false) as Node3D
	var muzzle := model.find_child("Muzzle", true, false) as Node3D
	if aim == null or muzzle == null:
		return
	_ensure_materials()
	var bore := muzzle.position
	if form_id == "overwatch":
		_spotter(aim)
		return
	var horizon := form_id == "horizon_piercer"
	var extension := HORIZON_EXTENSION if horizon else PIERCER_EXTENSION
	var tip := bore.z - extension
	if horizon:
		_horizon_barrel(aim, bore, tip)
	else:
		_piercer_brake(aim, bore, tip)
	muzzle.position = Vector3(bore.x, bore.y, tip - .02)

## Two collars on the teal barrel, a slim barrel extension and a vented brass brake at the end.
static func _piercer_brake(aim: Node3D, bore: Vector3, tip: float) -> void:
	for z: float in [bore.z + .56, bore.z + .44]:
		_ring(aim, "RifleCollar", MUZZLE_RING_RADIUS - .014, MUZZLE_RING_RADIUS + .004, "brass", Vector3(bore.x, bore.y, z))
	var brake_length := .16
	var brake_z := tip + brake_length * .5
	_cylinder(aim, "RifleBarrel", .07, absf(tip - bore.z) + .04, "graphite", Vector3(bore.x, bore.y, (bore.z + tip) * .5))
	_cylinder(aim, "RifleBrake", .098, brake_length, "brass", Vector3(bore.x, bore.y, brake_z))
	_cylinder(aim, "RifleBore", .05, .02, "graphite", Vector3(bore.x, bore.y, tip - .004))
	_ring(aim, "RifleCollar", .062, .09, "brass", Vector3(bore.x, bore.y, tip + brake_length + .08))
	for side: float in [-1.0, 1.0]:
		_box(aim, "RifleBrakePort", Vector3(.028, .05, .09), "graphite", Vector3(bore.x + side * .098, bore.y, brake_z))
	_box(aim, "RifleBrakePort", Vector3(.05, .028, .09), "graphite", Vector3(bore.x, bore.y + .098, brake_z))

## A longer barrel, brass spacer yokes, glowing rails on both sides and a teal emitter ring at the tip.
static func _horizon_barrel(aim: Node3D, bore: Vector3, tip: float) -> void:
	var length := absf(tip - bore.z)
	_cylinder(aim, "RifleBarrel", .065, length + .04, "graphite", Vector3(bore.x, bore.y, (bore.z + tip) * .5))
	for z: float in [bore.z + .56, bore.z + .44]:
		_ring(aim, "RifleCollar", MUZZLE_RING_RADIUS - .014, MUZZLE_RING_RADIUS + .004, "brass", Vector3(bore.x, bore.y, z))
	var rail_start := bore.z + .62
	var rail_length := absf(tip - rail_start)
	for side: float in [-1.0, 1.0]:
		_box(aim, "HorizonRail", Vector3(.032, .032, rail_length), "teal", Vector3(bore.x + side * .148, bore.y, (rail_start + tip) * .5))
	for z: float in [bore.z - .12, bore.z - .38, bore.z - .64]:
		_box(aim, "HorizonYoke", Vector3(.3, .028, .04), "brass", Vector3(bore.x, bore.y, z))
		_ring(aim, "RifleCollar", .056, .082, "brass", Vector3(bore.x, bore.y, z))
	_ring(aim, "HorizonEmitter", .07, .1, "teal", Vector3(bore.x, bore.y, tip))
	_cylinder(aim, "RifleBore", .05, .02, "teal", Vector3(bore.x, bore.y, tip - .004))

## A mast behind the scope carrying an amber ring and lens that face down the barrel.
static func _spotter(aim: Node3D) -> void:
	_cylinder(aim, "SpotterBase", .06, .05, "brass", MAST_BASE + Vector3(0, .02, 0), true)
	_cylinder(aim, "SpotterMast", .034, MAST_HEIGHT, "graphite", MAST_BASE + Vector3(0, MAST_HEIGHT * .5, 0), true)
	var hub := MAST_BASE + Vector3(0, MAST_HEIGHT + .2, 0)
	_ring(aim, "SpotterRing", .19, .245, "amber", hub)
	var lens := SphereMesh.new()
	lens.radius = .09
	lens.height = .18
	_part(aim, "SpotterLens", lens, "amber", hub, Vector3.ZERO)

static func _ensure_materials() -> void:
	if not materials.is_empty():
		return
	for entry in [["brass", "dba94c", .8, 0.0], ["graphite", "56636a", .6, 0.0], ["teal", "37d8d0", .35, 1.8], ["amber", "ffb02e", .3, 1.9]]:
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
	mesh.radial_segments = 24
	mesh.rings = 1
	_part(parent, label, mesh, material, at, Vector3.ZERO if upright else Vector3(PI * .5, 0, 0))

## A torus ring whose axis is the bore (-Z), so it reads as a collar around the barrel or a lens bezel facing forward.
static func _ring(parent: Node3D, label: String, inner: float, outer: float, material: String, at: Vector3) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 10
	_part(parent, label, mesh, material, at, Vector3(PI * .5, 0, 0))

static func _box(parent: Node3D, label: String, size: Vector3, material: String, at: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_part(parent, label, mesh, material, at, Vector3.ZERO)

static func _part(parent: Node3D, label: String, mesh: Mesh, material: String, at: Vector3, rotation: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = materials[material]
	instance.position = at
	instance.rotation = rotation
	parent.add_child(instance)

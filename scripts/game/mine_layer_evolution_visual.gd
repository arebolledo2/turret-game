class_name MineLayerEvolutionVisual
extends RefCounted

## Runtime hardware for the Mine Layer line, built on the placeholder chassis (the tinted Shock bell) until the cp_mine_layer
## model is wired. Each form adds its own silhouette round it, in the model's own frame (front is -z, the origin is on the floor):
##   Mine Layer   the bare chassis.
##   Minefield    a ring of eight spare mines on the floor round the base and a hazard band round the bell.
##   Dead Zone    six detonator pylons with glowing tips and a hazard ring on the floor (the zone it lays).
##   Chain Reaction  three angled launch tubes round the bell, each with a limpet in its mouth, and an amber collar.
## Nothing here moves.
static var materials: Dictionary = {}

## The bell's footprint on the floor (metres).
const BASE_RADIUS: float = .6
const MINE_ANGLES: int = 8
const PYLON_COUNT: int = 6
const TUBE_COUNT: int = 3

static func build(model: Node3D, form_id: String) -> TurretVisualHandles:
	if form_id not in ["minefield", "dead_zone", "chain_reaction"]:
		return null
	_ensure_materials()
	match form_id:
		"minefield":
			for index in MINE_ANGLES:
				var at := _polar(float(index) * TAU / float(MINE_ANGLES) + .2, BASE_RADIUS + .22)
				_cylinder(model, "SpareMine", .13, .06, "steel", Vector3(at.x, .03, at.z), Vector3.ZERO)
				_cylinder(model, "MineTop", .06, .04, "red", Vector3(at.x, .075, at.z), Vector3.ZERO)
			_torus(model, "HazardBand", BASE_RADIUS * .93, BASE_RADIUS * .93 + .06, "amber", Vector3(0, .2, 0))
		"dead_zone":
			for index in PYLON_COUNT:
				var at := _polar(float(index) * TAU / float(PYLON_COUNT) + .5, BASE_RADIUS + .3)
				_cylinder(model, "Pylon", .045, .55, "steel", Vector3(at.x, .275, at.z), Vector3.ZERO)
				_cylinder(model, "PlateFoot", .1, .05, "dark", Vector3(at.x, .025, at.z), Vector3.ZERO)
				_sphere(model, "GlowTip", .07, "red", Vector3(at.x, .6, at.z))
			_torus(model, "HazardRing", 1.25, 1.33, "amber", Vector3(0, .035, 0))
			_torus(model, "HazardBand", BASE_RADIUS * .93, BASE_RADIUS * .93 + .06, "red", Vector3(0, .2, 0))
		"chain_reaction":
			for index in TUBE_COUNT:
				var yaw := float(index) * TAU / float(TUBE_COUNT) + PI
				var base := _polar(yaw, BASE_RADIUS * .75)
				var out := Vector3(cos(yaw), 0, sin(yaw))
				# A tube leaning outward from the bell's shoulder, with a limpet sitting in its mouth.
				var tube := _cylinder(model, "LaunchTube", .1, .55, "steel", Vector3(base.x, .95, base.z), Vector3.ZERO)
				tube.rotation = Vector3(-out.z * .6, 0, out.x * .6)
				var mouth := Vector3(base.x, .95, base.z) + out * .17 + Vector3(0, .25, 0)
				_sphere(model, "Limpet", .09, "amber", mouth)
			_torus(model, "Collar", BASE_RADIUS * .8, BASE_RADIUS * .8 + .07, "amber", Vector3(0, .8, 0))
	return null

static func _polar(angle: float, radius: float) -> Vector3:
	return Vector3(cos(angle) * radius, 0, sin(angle) * radius)

static func _ensure_materials() -> void:
	if not materials.is_empty():
		return
	materials = VisualPalette.build([["steel", "7d8791", .8], ["dark", "1b2127", .4], ["red", "ff5a3c", .3, 1.4], ["amber", "ffb02e", .3, 1.2]])

static func _cylinder(parent: Node3D, label: String, radius: float, height: float, material: String, at: Vector3, rotation: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	return _part(parent, label, mesh, material, at, rotation)

static func _torus(parent: Node3D, label: String, inner: float, outer: float, material: String, at: Vector3) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 8
	return _part(parent, label, mesh, material, at, Vector3.ZERO)

static func _sphere(parent: Node3D, label: String, radius: float, material: String, at: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _part(parent, label, mesh, material, at, Vector3.ZERO)

static func _part(parent: Node3D, label: String, mesh: Mesh, material: String, at: Vector3, rotation: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	# Repeated parts are numbered (SpareMine, SpareMine2, ...) instead of getting engine-made "@MeshInstance3D@N" names.
	var same := 0
	for child in parent.get_children():
		if String(child.name).begins_with(label):
			same += 1
	instance.name = label if same == 0 else "%s%d" % [label, same + 1]
	instance.mesh = mesh
	instance.material_override = materials[material]
	instance.position = at
	instance.rotation = rotation
	parent.add_child(instance)
	return instance

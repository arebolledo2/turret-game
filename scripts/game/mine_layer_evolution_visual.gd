class_name MineLayerEvolutionVisual
extends RefCounted

## Runtime hardware for the Mine Layer line, built on the real cp_mine_layer chassis (a teal hex body on six feet with a coral
## band, a hopper full of spiked mines on top that turns with `Aim`, a long brass-lipped barrel on the front, a spare-mine dish
## on the floor at the front left). Sizes come from the model's own parts in `_footprint`. In the model's frame the front is -z,
## the origin is on the floor, the barrel mouth (`Muzzle`) is 0.91 m out at 0.5 m up and the dish sits 0.85 m out at 225 degrees.
##   Mine Layer   the bare chassis.
##   Minefield    a ring of eight spare mines on the floor round the base (clear of the dish) and a hazard band round the hopper.
##   Dead Zone    six detonator pylons with glowing tips and a hazard ring on the floor (the zone it lays), a red hopper band.
##   Chain Reaction  a rack of three angled limpet tubes on the back of the head, each with a limpet in its mouth, and an amber
##                collar on the hopper. Limpets leave from `Muzzle`; the rack is the magazine.
## The floor pieces stay put; the hopper band, rack and collar are children of `Aim` and turn with the head.
static var materials: Dictionary = {}

## Fallbacks if the chassis meshes are missing (the cp_mine_layer measurements, in metres): body radius, hopper rim radius and
## height, the `Aim` pivot height.
const DEFAULT_BODY_RADIUS: float = .63
const DEFAULT_HOPPER_RADIUS: float = .55
const DEFAULT_HOPPER_TOP: float = 1.52
const AIM_HEIGHT: float = .7
const MINE_ANGLES: int = 8
const PYLON_COUNT: int = 6
const TUBE_COUNT: int = 3
## Floor decorations stand this far from the centre: outside the dish (it reaches 1.1 m) and the barrel mouth (0.91 m), and
## inside the mines the layer lays, which start at `MineLayerForm.CLEARANCE`.
const RING_RADIUS: float = 1.25

static func build(model: Node3D, form_id: String) -> TurretVisualHandles:
	if form_id not in ["minefield", "dead_zone", "chain_reaction"]:
		return null
	_ensure_materials()
	var footprint := _footprint(model)
	var hopper_radius: float = footprint.hopper_radius
	var hopper_top: float = footprint.hopper_top
	# The head's own frame: its pivot is 0.7 m up, so a height `y` above the floor is `y - AIM_HEIGHT` inside it.
	var head: Node3D = footprint.head
	var head_y: float = AIM_HEIGHT if head != model else 0.0
	match form_id:
		"minefield":
			for index in MINE_ANGLES:
				var at := _polar((float(index) + .5) * TAU / float(MINE_ANGLES), RING_RADIUS)
				_cylinder(model, "SpareMine", .15, .07, "steel", Vector3(at.x, .035, at.z), Vector3.ZERO)
				_cylinder(model, "MineTop", .07, .05, "red", Vector3(at.x, .085, at.z), Vector3.ZERO)
			_torus(head, "HazardBand", hopper_radius + .005, hopper_radius + .065, "amber", Vector3(0, hopper_top - .06 - head_y, 0))
		"dead_zone":
			for index in PYLON_COUNT:
				var at := _polar(float(index) * TAU / float(PYLON_COUNT) + .5, RING_RADIUS + .1)
				_cylinder(model, "Pylon", .05, .6, "steel", Vector3(at.x, .3, at.z), Vector3.ZERO)
				_cylinder(model, "PlateFoot", .11, .05, "dark", Vector3(at.x, .025, at.z), Vector3.ZERO)
				_sphere(model, "GlowTip", .08, "red", Vector3(at.x, .66, at.z))
			_torus(model, "HazardRing", 1.62, 1.7, "amber", Vector3(0, .035, 0))
			_torus(head, "HazardBand", hopper_radius + .005, hopper_radius + .065, "red", Vector3(0, hopper_top - .06 - head_y, 0))
		"chain_reaction":
			# A fan of tubes on the back of the head (+z, away from the barrel), each leaning outward from the hopper's shoulder.
			for index in TUBE_COUNT:
				var yaw := deg_to_rad(40.0 + float(index) * 50.0)
				var out := Vector3(cos(yaw), 0, sin(yaw))
				var lean := .3
				var root := Vector3(out.x * (hopper_radius * 1.1), 1.0 - head_y, out.z * (hopper_radius * 1.1))
				var axis := Vector3(out.x * sin(lean), cos(lean), out.z * sin(lean))
				var tube := _cylinder(head, "LaunchTube", .09, .6, "steel", root + axis * .3, Vector3.ZERO)
				tube.basis = Basis(Quaternion(Vector3.UP, axis))
				_cylinder(head, "TubeMouth", .115, .05, "amber", root + axis * .6, Vector3.ZERO).basis = Basis(Quaternion(Vector3.UP, axis))
				_sphere(head, "Limpet", .085, "amber", root + axis * .66)
			_torus(head, "Collar", hopper_radius + .005, hopper_radius + .075, "amber", Vector3(0, hopper_top - .06 - head_y, 0))
	return null

## The chassis measurements the hardware hangs on, read from the model's own meshes (a part missing gives the default).
static func _footprint(model: Node3D) -> Dictionary:
	var result := {"hopper_radius": DEFAULT_HOPPER_RADIUS, "hopper_top": DEFAULT_HOPPER_TOP, "head": model}
	var aim := model.find_child("Aim", true, false) as Node3D
	if aim:
		result.head = aim
	var hopper := model.find_child("Hopper_Teal", true, false) as MeshInstance3D
	if hopper and hopper.mesh:
		var box := hopper.mesh.get_aabb()
		var offset := aim.position.y if aim and hopper.get_parent() == aim else 0.0
		result.hopper_radius = minf(box.size.x, box.size.z) * .5
		result.hopper_top = box.end.y + offset
	return result

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

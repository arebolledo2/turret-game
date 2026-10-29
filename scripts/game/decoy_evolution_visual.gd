class_name DecoyEvolutionVisual
extends RefCounted

## Runtime hardware for the Decoy line, built on the real cp_decoy chassis (cream base blocks on a spring, a teal head with a
## bumper ring and two lenses, a brass lantern on top). Each form adds its own silhouette around it; sizes are read from the model's
## own parts in `_footprint`, the same way `QuakeEvolutionVisual` reads its slab.
##   Decoy        the bare chassis.
##   Bumper Post  four padded bumper posts planted round the base so their pads meet the model's bumper ring, and a rubber band
##                round the base (the harder shove).
##   Pile Driver  four heavy piston columns with ram heads, and a dark hammer head on the lantern cap (the slam).
##   Maelstrom    a mast with three curled hooks above the lantern, and two glowing lane rings on the ground (the hooked orbit).
## Parts hang off the model root, which is the turret's origin on the floor. They do not turn with the head (`Aim`).
static var materials: Dictionary = {}

## Fallbacks if the chassis meshes are missing (the cp_decoy measurements, in metres): base radius and top, bumper ring
## radius and middle height, lantern collar top, crown (lantern top).
const DEFAULT_BASE_RADIUS: float = .42
const DEFAULT_BASE_TOP: float = .22
const DEFAULT_RING_RADIUS: float = .386
const DEFAULT_RING_MID: float = .46
const DEFAULT_COLLAR_TOP: float = 1.18
const DEFAULT_CROWN_TOP: float = 1.64
## Angles (radians, atan2(z, x) around the turret) for the posts and pistons: the diagonals, clear of the front.
const POST_ANGLES: Array[float] = [.785, 2.356, 3.927, 5.498]
const HOOK_ANGLES: Array[float] = [.52, 2.62, 4.71]

static func build(model: Node3D, form_id: String) -> TurretVisualHandles:
	if form_id not in ["bumper_post", "pile_driver", "maelstrom"]:
		return null
	_ensure_materials()
	var footprint := _footprint(model)
	var radius: float = footprint.radius
	var top: float = footprint.top
	var crown: float = footprint.crown
	match form_id:
		"bumper_post":
			# Posts stand on the floor just outside the base; the pad's inner edge touches the bumper ring at its middle height.
			var pad := .1
			var stand: float = footprint.ring_radius + pad
			var pad_y: float = footprint.ring_mid
			for angle in POST_ANGLES:
				var at := _polar(angle, stand)
				_cylinder(model, "BumperCore", .055, pad_y + .26, "steel", Vector3(at.x, (pad_y + .26) * .5, at.z))
				_cylinder(model, "BumperPad", pad, .22, "rubber", Vector3(at.x, pad_y, at.z))
				_cylinder(model, "BumperCap", pad + .015, .04, "brass", Vector3(at.x, pad_y + .13, at.z))
				_cylinder(model, "BumperFoot", .09, .04, "brass", Vector3(at.x, .02, at.z))
			_torus(model, "BumperRing", radius * .93, radius * .93 + .07, "rubber", Vector3(0, top * .5, 0))
		"pile_driver":
			var column := radius + .1
			var span: float = footprint.collar_top - .12
			for angle in POST_ANGLES:
				var at := _polar(angle, column)
				_cylinder(model, "PistonColumn", .075, span, "steel", Vector3(at.x, span * .5, at.z))
				_cylinder(model, "PistonCollar", .105, .08, "brass", Vector3(at.x, span * .45, at.z))
				_cylinder(model, "PistonRam", .15, .1, "dark", Vector3(at.x, span + .05, at.z))
			# The hammer head rides on the lantern cap, well clear of the bulb.
			_cylinder(model, "AnvilStem", .05, .14, "brass", Vector3(0, crown + .02, 0))
			_cylinder(model, "AnvilHead", .22, .09, "dark", Vector3(0, crown + .11, 0))
			for index in range(3):
				var stud := _polar(float(index) * TAU / 3.0 + .5, .15)
				_sphere(model, "AnvilStud", .035, "amber", Vector3(stud.x, crown + .155, stud.z))
		"maelstrom":
			var mast_base := crown
			_cylinder(model, "HookMast", .035, .52, "steel", Vector3(0, mast_base + .24, 0))
			_sphere(model, "HookCrown", .07, "amber", Vector3(0, mast_base + .52, 0))
			for angle in HOOK_ANGLES:
				_hook(model, angle, Vector3(0, mast_base + .36, 0))
			for lane in range(2):
				var ring := TurretEvolution.MAELSTROM_RING + float(lane) * EnemyActor.HOOK_LANE_GAP * 1.5
				_torus(model, "LaneRing", ring - .03, ring + .03, "amber" if lane == 0 else "teal", Vector3(0, .03, 0))
	return null

## One curled hook: an arm that climbs away from the mast, then a tip that drops back down.
static func _hook(model: Node3D, angle: float, from: Vector3) -> void:
	var out := Vector3(cos(angle), 0, sin(angle))
	var climb := deg_to_rad(55.0)
	var fall := deg_to_rad(135.0)
	var first := Vector3(out.x * sin(climb), cos(climb), out.z * sin(climb))
	var second := Vector3(out.x * sin(fall), cos(fall), out.z * sin(fall))
	var arm := .27
	var tip := .22
	_cylinder_dir(model, "HookArm", .028, arm, "brass", from + first * arm * .5, Vector3(0, -angle, -climb))
	var elbow := from + first * arm
	_sphere(model, "HookElbow", .04, "brass", elbow)
	_cone_dir(model, "HookTip", .036, tip, "amber", elbow + second * tip * .5, Vector3(0, -angle, -fall))

## The chassis' own measurements: base radius and top, bumper ring radius and middle height, lantern collar top and crown.
static func _footprint(model: Node3D) -> Dictionary:
	var result := {"radius": DEFAULT_BASE_RADIUS, "top": DEFAULT_BASE_TOP, "ring_radius": DEFAULT_RING_RADIUS, "ring_mid": DEFAULT_RING_MID, "collar_top": DEFAULT_COLLAR_TOP, "crown": DEFAULT_CROWN_TOP}
	var base := _bounds(model, "Base_Body")
	if base.size != Vector3.ZERO:
		result.radius = minf(base.size.x, base.size.z) * .5
		result.top = base.end.y
	var ring := _bounds(model, "Bumper_Ring")
	if ring.size != Vector3.ZERO:
		result.ring_radius = minf(ring.size.x, ring.size.z) * .5
		result.ring_mid = ring.position.y + ring.size.y * .5
	var collar := _bounds(model, "Lantern_Collar")
	if collar.size != Vector3.ZERO:
		result.collar_top = collar.end.y
	var cage := _bounds(model, "Lantern_Cage")
	if cage.size != Vector3.ZERO:
		result.crown = cage.end.y
	return result

## A mesh's box in model space (parents' offsets added; the model's nodes carry no rotation or scale), or an empty box.
static func _bounds(model: Node3D, part: String) -> AABB:
	var node := model.find_child(part, true, false) as MeshInstance3D
	if node == null or node.mesh == null:
		return AABB()
	var box := node.mesh.get_aabb()
	var lift := Vector3.ZERO
	var parent: Node3D = node
	while parent and parent != model:
		lift += parent.position
		parent = parent.get_parent() as Node3D
	box.position += lift
	return box

static func _polar(angle: float, radius: float) -> Vector3:
	return Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)

static func _ensure_materials() -> void:
	if not materials.is_empty():
		return
	materials = VisualPalette.build([["brass", "dba94c", .8], ["steel", "a9cfcc", .75], ["dark", "16232b", .4], ["rubber", "e8742a", .05], ["amber", "ffb02e", .3, 1.8], ["teal", "6df0b0", .35, 1.6]])

static func _cylinder(parent: Node3D, label: String, radius: float, height: float, material: String, at: Vector3) -> void:
	_cylinder_dir(parent, label, radius, height, material, at, Vector3.ZERO)

static func _cylinder_dir(parent: Node3D, label: String, radius: float, height: float, material: String, at: Vector3, rotation: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 1
	_part(parent, label, mesh, material, at, rotation)

static func _cone_dir(parent: Node3D, label: String, radius: float, height: float, material: String, at: Vector3, rotation: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	_part(parent, label, mesh, material, at, rotation)

static func _torus(parent: Node3D, label: String, inner: float, outer: float, material: String, at: Vector3) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 8
	_part(parent, label, mesh, material, at, Vector3.ZERO)

static func _sphere(parent: Node3D, label: String, radius: float, material: String, at: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	_part(parent, label, mesh, material, at, Vector3.ZERO)

static func _part(parent: Node3D, label: String, mesh: Mesh, material: String, at: Vector3, rotation: Vector3) -> void:
	var instance := MeshInstance3D.new()
	# Repeated parts are numbered (BumperCore, BumperCore2, ...) instead of getting engine-made "@MeshInstance3D@N" names.
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

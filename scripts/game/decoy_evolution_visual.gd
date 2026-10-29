class_name DecoyEvolutionVisual
extends RefCounted

## Runtime hardware for the Decoy line, built on the placeholder chassis (the Shock bell on its low foundation, tinted amber by
## `TurretActor`). Each form adds its own silhouette around it; when the real cp_decoy model is wired the sizes are read from
## that model's own parts in `_footprint`, the same way `QuakeEvolutionVisual` reads its slab.
##   Decoy        the bare chassis.
##   Bumper Post  four padded bumper posts planted round the foundation and a rubber ring round the bell (the harder shove).
##   Pile Driver  four heavy piston columns with ram heads, and a steel anvil plate on the crown (the slam).
##   Maelstrom    a mast with three curled hooks above the crown, and two glowing lane rings on the ground (the hooked orbit).
## Parts hang off the model root, which is the turret's origin on the floor.
static var materials: Dictionary = {}

## Fallbacks if the chassis meshes are missing: foundation radius and top, crown top, in metres (the Shock bell's).
const DEFAULT_FOUNDATION_RADIUS: float = .527
const DEFAULT_FOUNDATION_TOP: float = .164
const DEFAULT_CROWN_TOP: float = 1.19
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
			for angle in POST_ANGLES:
				var at := _polar(angle, radius * 1.02)
				_cylinder(model, "BumperCore", .1, .5, "steel", Vector3(at.x, top + .25, at.z))
				_cylinder(model, "BumperPad", .15, .26, "rubber", Vector3(at.x, top + .3, at.z))
				_cylinder(model, "BumperCap", .17, .05, "brass", Vector3(at.x, top + .56, at.z))
			_torus(model, "BumperRing", radius * .9, radius * .9 + .09, "rubber", Vector3(0, top + .2, 0))
		"pile_driver":
			for angle in POST_ANGLES:
				var at := _polar(angle, radius * 1.0)
				_cylinder(model, "PistonColumn", .1, .95, "steel", Vector3(at.x, top + .475, at.z))
				_cylinder(model, "PistonCollar", .14, .09, "brass", Vector3(at.x, top + .62, at.z))
				_cylinder(model, "PistonRam", .2, .12, "dark", Vector3(at.x, top + 1.0, at.z))
			_cylinder(model, "AnvilPlate", .34, .09, "steel", Vector3(0, crown + .045, 0))
			_cylinder(model, "AnvilStem", .06, .14, "brass", Vector3(0, crown + .16, 0))
			_cylinder(model, "AnvilHead", .2, .07, "dark", Vector3(0, crown + .26, 0))
			for index in range(3):
				var stud := _polar(float(index) * TAU / 3.0, .24)
				_sphere(model, "AnvilStud", .04, "amber", Vector3(stud.x, crown + .105, stud.z))
		"maelstrom":
			var mast_base := crown
			_cylinder(model, "HookMast", .035, .62, "steel", Vector3(0, mast_base + .31, 0))
			_sphere(model, "HookCrown", .07, "amber", Vector3(0, mast_base + .66, 0))
			for angle in HOOK_ANGLES:
				_hook(model, angle, Vector3(0, mast_base + .5, 0))
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
	var arm := .26
	var tip := .2
	_cylinder_dir(model, "HookArm", .028, arm, "brass", from + first * arm * .5, Vector3(0, -angle, -climb))
	var elbow := from + first * arm
	_sphere(model, "HookElbow", .04, "brass", elbow)
	_cone_dir(model, "HookTip", .036, tip, "amber", elbow + second * tip * .5, Vector3(0, -angle, -fall))

## The chassis' own measurements: foundation radius and top, and the top of the crown (via the muzzle).
static func _footprint(model: Node3D) -> Dictionary:
	var result := {"radius": DEFAULT_FOUNDATION_RADIUS, "top": DEFAULT_FOUNDATION_TOP, "crown": DEFAULT_CROWN_TOP}
	var foundation := model.find_child("Foundation", true, false) as MeshInstance3D
	if foundation and foundation.mesh:
		var box := foundation.mesh.get_aabb()
		result.radius = minf(box.size.x, box.size.z) * .5
		result.top = box.end.y
	var muzzle := model.find_child("Muzzle", true, false) as Node3D
	if muzzle:
		var lift := 0.0
		var parent := muzzle.get_parent() as Node3D
		while parent and parent != model:
			lift += parent.position.y
			parent = parent.get_parent() as Node3D
		result.crown = muzzle.position.y + lift
	return result

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

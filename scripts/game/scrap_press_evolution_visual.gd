class_name ScrapPressEvolutionVisual
extends RefCounted

## Runtime hardware for the Scrap Press line, built on the placeholder chassis (the Shock bell on its low foundation, tinted brass
## by `TurretActor`). Each form adds its own silhouette; the sizes come from the chassis' own parts in `_footprint`, so the real
## model can take over later by changing what `_footprint` reads, as `QuakeEvolutionVisual` and `DecoyEvolutionVisual` do.
##   Scrap Press  the bare chassis.
##   Coin Feeder  a brass hopper on the crown, a chute running down to a coin tray beside the base, and a small stack of coins.
##   Treasury     four stacks of gold ingots round the base, a gold vault dome with a glowing crest on the crown, and a coin ring.
##   Academy      a mortarboard on the crown with a hanging tassel, three books round the base, and a teal halo above it.
## Parts hang off the model root, which is the turret's origin on the floor. Nothing here moves.
static var materials: Dictionary = {}

## Fallbacks if the chassis meshes are missing: foundation radius and top, crown top, in metres (the Shock bell's).
const DEFAULT_FOUNDATION_RADIUS: float = .527
const DEFAULT_FOUNDATION_TOP: float = .164
const DEFAULT_CROWN_TOP: float = 1.19
## Angles (radians, atan2(z, x) around the turret) for the ingot stacks and books: the diagonals, clear of the front.
const STACK_ANGLES: Array[float] = [.785, 2.356, 3.927, 5.498]
const BOOK_ANGLES: Array[float] = [.6, 2.7, 4.6]

static func build(model: Node3D, form_id: String) -> TurretVisualHandles:
	if form_id not in ["coin_feeder", "treasury", "academy"]:
		return null
	_ensure_materials()
	var footprint := _footprint(model)
	var radius: float = footprint.radius
	var top: float = footprint.top
	var crown: float = footprint.crown
	match form_id:
		"coin_feeder":
			_cone(model, "Hopper", .34, .12, .36, "brass", Vector3(0, crown + .18, 0), Vector3.ZERO)
			_torus(model, "HopperRim", .3, .36, "steel", Vector3(0, crown + .37, 0))
			# The chute leaves the hopper toward +x and slopes down to the tray.
			var tray := Vector3(radius + .42, top + .06, 0)
			var start := Vector3(.12, crown + .1, 0)
			var drop := tray + Vector3(0, .12, 0) - start
			_cylinder_dir(model, "Chute", .05, drop.length(), "steel", start + drop * .5, Vector3(0, 0, atan2(drop.x, -drop.y)))
			_cylinder(model, "Tray", .24, .06, "dark", tray)
			for index in range(4):
				_cylinder(model, "Coin", .11, .026, "gold", tray + Vector3(index * .01, .043 + float(index) * .028, 0))
		"treasury":
			for angle in STACK_ANGLES:
				var at := _polar(angle, radius * 1.05)
				for layer in range(3):
					_box(model, "Ingot", Vector3(.34 - float(layer) * .04, .11, .2), "gold", Vector3(at.x, top + .055 + float(layer) * .12, at.z), Vector3(0, -angle, 0))
			_sphere_scaled(model, "VaultDome", .3, .7, "gold", Vector3(0, crown + .1, 0))
			_cylinder(model, "VaultBand", .31, .05, "steel", Vector3(0, crown + .04, 0))
			_sphere(model, "VaultCrest", .08, "amber", Vector3(0, crown + .36, 0))
			_torus(model, "CoinRing", radius * .9, radius * .9 + .07, "gold", Vector3(0, top + .05, 0))
		"academy":
			_cylinder(model, "CapStem", .1, .16, "dark", Vector3(0, crown + .08, 0))
			_box(model, "CapBoard", Vector3(.78, .05, .78), "dark", Vector3(0, crown + .185, 0), Vector3(0, .785, 0))
			_cylinder(model, "CapButton", .05, .04, "gold", Vector3(0, crown + .23, 0))
			var corner := Vector3(.39 * 1.414, crown + .185, 0)
			_cylinder(model, "TasselCord", .012, .26, "gold", corner + Vector3(0, -.13, 0))
			_sphere(model, "TasselBob", .045, "gold", corner + Vector3(0, -.28, 0))
			for angle in BOOK_ANGLES:
				var at := _polar(angle, radius * 1.08)
				_box(model, "Book", Vector3(.32, .1, .22), "teal_dark", Vector3(at.x, top + .05, at.z), Vector3(0, -angle, 0))
				_box(model, "Pages", Vector3(.3, .04, .2), "paper", Vector3(at.x, top + .12, at.z), Vector3(0, -angle, 0))
			_torus(model, "Halo", .34, .38, "teal", Vector3(0, crown + .52, 0))
	return null

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
	materials = VisualPalette.build([["brass", "dba94c", .8], ["gold", "f2c14e", .9], ["steel", "a9cfcc", .75], ["dark", "16232b", .4],
		["amber", "ffb02e", .3, 1.8], ["teal", "6df0b0", .35, 1.6], ["teal_dark", "1f6f78", .3], ["paper", "f4ead2", .05]])

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

static func _cone(parent: Node3D, label: String, top_radius: float, bottom_radius: float, height: float, material: String, at: Vector3, rotation: Vector3) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 1
	_part(parent, label, mesh, material, at, rotation)

static func _box(parent: Node3D, label: String, size: Vector3, material: String, at: Vector3, rotation: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_part(parent, label, mesh, material, at, rotation)

static func _torus(parent: Node3D, label: String, inner: float, outer: float, material: String, at: Vector3) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 8
	_part(parent, label, mesh, material, at, Vector3.ZERO)

static func _sphere(parent: Node3D, label: String, radius: float, material: String, at: Vector3) -> void:
	_sphere_scaled(parent, label, radius, 1.0, material, at)

## A sphere squashed to `height_ratio` of its width (a dome).
static func _sphere_scaled(parent: Node3D, label: String, radius: float, height_ratio: float, material: String, at: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 * height_ratio
	_part(parent, label, mesh, material, at, Vector3.ZERO)

static func _part(parent: Node3D, label: String, mesh: Mesh, material: String, at: Vector3, rotation: Vector3) -> void:
	var instance := MeshInstance3D.new()
	# Repeated parts are numbered (Ingot, Ingot2, ...) instead of getting engine-made "@MeshInstance3D@N" names.
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

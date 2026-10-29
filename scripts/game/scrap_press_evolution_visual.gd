class_name ScrapPressEvolutionVisual
extends RefCounted

## Runtime hardware for the Scrap Press line, built on the real `cp_scrap_press` chassis (a teal arch frame round a coral
## housing and a brass piston, on a slab base with a cream coin tray at the front and a coin funnel on the -x side). The
## sizes come from the chassis' own parts in `_footprint`. Each form adds its own silhouette:
##   Scrap Press  the bare chassis.
##   Coin Feeder  a brass hopper on legs fed by the chassis' coin funnel, a spout and a floor tray with a stack of coins.
##   Treasury     four stacks of gold ingots at the corners of the base, a gold vault cap with a glowing crest on the piston
##                and a gold coin ring on the floor.
##   Academy      a mortarboard on the piston stem with a hanging tassel, books on the floor round the base and a teal halo.
## Parts hang off the model root in the chassis' own frame (front is -z, the funnel is on -x; `ScrapPressForm.rebuilt` turns
## the whole model so the tray faces the camera). Nothing here moves.
static var materials: Dictionary = {}

## Fallbacks if the chassis meshes are missing (the cp_scrap_press measurements, metres): half the feet's width and depth,
## the top of the piston, the x of the funnel's mouth and the height of its centre.
const DEFAULT_HALF_X: float = .57
const DEFAULT_HALF_Z: float = .495
const DEFAULT_CROWN_TOP: float = 1.58
const DEFAULT_MOUTH_X: float = -.757
const DEFAULT_MOUTH_Y: float = 1.02
## The piston's cap disc tops out this far below the knob's top; the funnel's centre is this far below the frame's top.
const CAP_BELOW_CROWN: float = .28
const MOUTH_BELOW_FRAME_TOP: float = .17

static func build(model: Node3D, form_id: String) -> TurretVisualHandles:
	if form_id not in ["coin_feeder", "treasury", "academy"]:
		return null
	_ensure_materials()
	var footprint := _footprint(model)
	var half_x: float = footprint.half_x
	var half_z: float = footprint.half_z
	var crown: float = footprint.crown
	var cap: float = crown - CAP_BELOW_CROWN
	match form_id:
		"coin_feeder":
			# The hopper stands just outside the funnel's mouth, its wide top level with the mouth, on two legs beside it.
			var hx: float = footprint.mouth_x - .27
			var rim: float = footprint.mouth_y - .04
			_cylinder_dir(model, "Collar", .09, .22, "steel", Vector3(footprint.mouth_x - .08, footprint.mouth_y, 0), Vector3(0, 0, PI * .5))
			_cone(model, "Hopper", .22, .07, .36, "brass", Vector3(hx, rim - .18, 0), Vector3.ZERO)
			_torus(model, "HopperRim", .2, .25, "steel", Vector3(hx, rim, 0))
			for side in [-1.0, 1.0]:
				_cylinder(model, "HopperLeg", .026, rim, "steel", Vector3(hx, rim * .5, side * .23))
			_cylinder(model, "Spout", .05, .3, "steel", Vector3(hx, rim - .36 - .1, 0))
			_cylinder(model, "Tray", .27, .05, "dark", Vector3(hx, .025, 0))
			for index in range(5):
				_cylinder(model, "Coin", .11, .026, "gold", Vector3(hx + float(index % 2) * .01, .063 + float(index) * .028, 0))
		"treasury":
			for corner in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
				var at := Vector3(corner.x * (half_x + .22), 0, corner.y * (half_z + .1))
				for layer in range(3):
					_box(model, "Ingot", Vector3(.2, .11, .34 - float(layer) * .04), "gold", Vector3(at.x, .055 + float(layer) * .12, at.z), Vector3(0, corner.x * corner.y * .12, 0))
			_sphere_scaled(model, "VaultCap", .31, .45, "gold", Vector3(0, cap, 0))
			_cylinder(model, "VaultBand", .3, .05, "steel", Vector3(0, cap - .02, 0))
			_sphere(model, "VaultCrest", .085, "amber", Vector3(0, crown + .08, 0))
			_torus(model, "CoinRing", .93, 1.0, "gold", Vector3(0, .035, 0))
		"academy":
			var board: float = crown + .17
			_cylinder(model, "CapStem", .12, .16, "dark", Vector3(0, crown + .04, 0))
			_box(model, "CapBoard", Vector3(.74, .05, .74), "dark", Vector3(0, board, 0), Vector3(0, .785, 0))
			_cylinder(model, "CapButton", .05, .04, "gold", Vector3(0, board + .045, 0))
			var corner := Vector3(.37 * 1.414, board, 0)
			_cylinder(model, "TasselCord", .012, .26, "gold", corner + Vector3(0, -.13, 0))
			_sphere(model, "TasselBob", .045, "gold", corner + Vector3(0, -.28, 0))
			# Two books side on, one stacked, and one at the back, all on the floor beside the base.
			for spec: Array in [[Vector3(half_x + .28, 0, -.2), PI * .5], [Vector3(half_x + .28, .12, -.2), PI * .5 + .2], [Vector3(.3, 0, half_z + .22), 0.0], [Vector3(-.45, 0, half_z + .22), .15]]:
				var at: Vector3 = spec[0]
				var yaw: float = spec[1]
				_box(model, "Book", Vector3(.32, .1, .22), "teal_dark", Vector3(at.x, at.y + .05, at.z), Vector3(0, yaw, 0))
				_box(model, "Pages", Vector3(.3, .04, .2), "paper", Vector3(at.x, at.y + .12, at.z), Vector3(0, yaw, 0))
			_torus(model, "Halo", .34, .38, "teal", Vector3(0, board + .32, 0))
	return null

## The chassis' own measurements: half the width and depth of the feet, the top of the piston, and where the coin funnel's mouth is.
static func _footprint(model: Node3D) -> Dictionary:
	var result := {"half_x": DEFAULT_HALF_X, "half_z": DEFAULT_HALF_Z, "crown": DEFAULT_CROWN_TOP, "mouth_x": DEFAULT_MOUTH_X, "mouth_y": DEFAULT_MOUTH_Y}
	var feet := model.find_child("Feet", true, false) as MeshInstance3D
	if feet and feet.mesh:
		var box := feet.mesh.get_aabb()
		result.half_x = maxf(absf(feet.position.x + box.position.x), absf(feet.position.x + box.end.x))
		result.half_z = maxf(absf(feet.position.z + box.position.z), absf(feet.position.z + box.end.z))
	var piston := model.find_child("PistonBrass", true, false) as MeshInstance3D
	if piston and piston.mesh:
		result.crown = _lift_to_model(piston, model) + piston.mesh.get_aabb().end.y
	var frame := model.find_child("Frame", true, false) as MeshInstance3D
	if frame and frame.mesh:
		var box := frame.mesh.get_aabb()
		result.mouth_x = frame.position.x + box.position.x
		result.mouth_y = frame.position.y + box.end.y - MOUTH_BELOW_FRAME_TOP
	return result

## Height of `part`'s origin above the model root, summing the parents' offsets (the chassis has no rotation or scale on them).
static func _lift_to_model(part: Node3D, model: Node3D) -> float:
	var lift := part.position.y
	var parent := part.get_parent() as Node3D
	while parent and parent != model:
		lift += parent.position.y
		parent = parent.get_parent() as Node3D
	return lift

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

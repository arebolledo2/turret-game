class_name LaserEvolutionVisual
extends RefCounted

## Runtime hardware for the Laser line. All four stages use the real cp_laser chassis (a teal barrel with a brass bezel and a gem
## lens, 0.88 m across at its widest, whose `Muzzle` is the nozzle tip in front of the bezel); the upgrade and the finals add their
## own silhouette on top of it. Parts hang off `Aim` around the chassis bore (read from its `Muzzle`, in Aim space), so they turn
## with the head:
##   Laser         the bare chassis.
##   Focus Beam    a lensed barrel extension: a graphite sleeve, two cyan collars and a glowing lens disc at the new mouth; `Muzzle`
##                 moves to the lens so the beam leaves from it.
##   Halo Cutter   a ring of emitters round the head: a cyan hoop at `ARM_RADIUS` carrying four glowing lenses at the compass points
##                 (the arms of the cross, which turn with `Aim`) joined to the hub by three spokes (the fourth is the barrel).
##   Sunpiercer    a long barrel with two floating cyan rings and a white-hot lens at the tip, and a tall hexagonal prism spire
##                 behind the scope.
## `LaserForm` draws the beams themselves.
static var materials: Dictionary = {}

## Metres the Focus Beam sleeve and the Sunpiercer barrel reach past the chassis muzzle (the nozzle is 0.15 m in radius).
const FOCUS_EXTENSION: float = .3
const SUN_EXTENSION: float = .6
## Radius of the Halo Cutter hoop; the beams are drawn from here (see `LaserForm.ARM_START`). It clears the model's widest parts
## (the side knobs at 0.64 m and the tubes at the back, 0.79 m behind the pivot).
const ARM_RADIUS: float = .9
## Radius of the chassis body, where the Halo spokes start.
const BODY_RADIUS: float = .45

static func build(model: Node3D, form_id: String) -> TurretVisualHandles:
	if form_id not in ["focus_beam", "halo_cutter", "sunpiercer"]:
		return null
	var aim := model.find_child("Aim", true, false) as Node3D
	var muzzle := model.find_child("Muzzle", true, false) as Node3D
	if aim == null or muzzle == null:
		return null
	_ensure_materials()
	var bore := muzzle.position
	match form_id:
		"focus_beam":
			var tip := bore.z - FOCUS_EXTENSION
			_cylinder(aim, "LensSleeve", .1, FOCUS_EXTENSION + .04, "graphite", Vector3(bore.x, bore.y, (bore.z + tip) * .5))
			for z: float in [bore.z - .06, bore.z - .17]:
				_ring(aim, "LensCollar", .105, .135, "cyan", Vector3(bore.x, bore.y, z))
			_cylinder(aim, "LensDisc", .09, .02, "white", Vector3(bore.x, bore.y, tip - .01))
			muzzle.position = Vector3(bore.x, bore.y, tip - .02)
		"halo_cutter":
			var hub := Vector3(bore.x, bore.y, 0.0)
			_ring(aim, "HaloHoop", ARM_RADIUS - .025, ARM_RADIUS + .025, "cyan", hub, true)
			for index in 4:
				var angle := float(index) * TAU / 4.0
				var out := Vector3(-sin(angle), 0.0, -cos(angle))
				_sphere(aim, "HaloLens", .09, "white", hub + out * ARM_RADIUS)
				if index > 0:
					_spoke(aim, hub, out)
		"sunpiercer":
			var tip := bore.z - SUN_EXTENSION
			_cylinder(aim, "SunBarrel", .09, SUN_EXTENSION + .04, "graphite", Vector3(bore.x, bore.y, (bore.z + tip) * .5))
			for z: float in [bore.z - .18, tip + .06]:
				_ring(aim, "SunRing", .15, .18, "cyan", Vector3(bore.x, bore.y, z))
			_cylinder(aim, "SunLens", .08, .02, "white", Vector3(bore.x, bore.y, tip - .01))
			muzzle.position = Vector3(bore.x, bore.y, tip - .02)
			var spire := _cylinder(aim, "SunSpire", .1, .55, "cyan", Vector3(bore.x, 1.175, .15), true)
			(spire.mesh as CylinderMesh).top_radius = .015
			(spire.mesh as CylinderMesh).radial_segments = 6
			_sphere(aim, "SunSpark", .06, "white", Vector3(bore.x, 1.48, .15))
	return null

static func _ensure_materials() -> void:
	if not materials.is_empty():
		return
	materials = VisualPalette.build([["graphite", "56636a", .6], ["cyan", "37e6ff", .35, 1.8], ["white", "e9ffff", .2, 2.4]])

## A spoke from the hub out to the hoop along the unit direction `out`.
static func _spoke(parent: Node3D, hub: Vector3, out: Vector3) -> void:
	var length := ARM_RADIUS - BODY_RADIUS - .06
	var spoke := _box(parent, "HaloSpoke", Vector3(.05, .05, length), "graphite", hub + out * (BODY_RADIUS + length * .5 - .02))
	spoke.basis = Basis.looking_at(out, Vector3.UP)

## A cylinder along the bore (z); `upright` keeps it standing along y instead.
static func _cylinder(parent: Node3D, label: String, radius: float, height: float, material: String, at: Vector3, upright: bool = false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	var part := _part(parent, label, mesh, material, at)
	if not upright:
		part.rotation.x = PI * .5
	return part

## A ring of the given radii. By default it is a collar round the bore axis (z), a halo the beam passes through; `flat` lays it on
## the ground plane round the head (the hoop).
static func _ring(parent: Node3D, label: String, inner: float, outer: float, material: String, at: Vector3, flat: bool = false) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 8
	var part := _part(parent, label, mesh, material, at)
	if not flat:
		# A torus lies flat by default; stand it across the bore (its axis along z).
		part.rotation.x = PI * .5
	return part

static func _sphere(parent: Node3D, label: String, radius: float, material: String, at: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _part(parent, label, mesh, material, at)

static func _box(parent: Node3D, label: String, size: Vector3, material: String, at: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(parent, label, mesh, material, at)

static func _part(parent: Node3D, label: String, mesh: Mesh, material: String, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	# Repeated parts are numbered (HaloLens, HaloLens2, ...) instead of getting engine-made "@MeshInstance3D@N" names.
	var same := 0
	for child in parent.get_children():
		if String(child.name).begins_with(label):
			same += 1
	instance.name = label if same == 0 else "%s%d" % [label, same + 1]
	instance.mesh = mesh
	instance.material_override = materials[material]
	instance.position = at
	parent.add_child(instance)
	return instance

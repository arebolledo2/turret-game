class_name DroneBayEvolutionVisual
extends RefCounted

## Runtime hardware for the Drone Bay line, built on the cp_drone_bay chassis: a round base with a hangar tunnel, a coral tower and a
## teal sensor head on `Aim`, and two parking dishes on posts (the model's own parked drones give way to the real ones while
## they hold the slots, see `DroneDock.parked_drone`; the real drones rest on the dishes). The unevolved bay is the bare chassis. Each form lights a
## ring on every dock a drone rests on (`DroneDock.dock_offset`: the two dishes, then floor pads in the open front arc of the base)
## and marks the head:
##   Escort Drones  three sky-blue docks, a sky band round the neck collar and a glowing ring up the antenna.
##   Guardian Wing  four green docks, a shield hoop round the head and two angled wing fins at its sides.
##   Reaper Swarm   five red docks, a crown of five spikes round the dome and a red band round the neck collar.
## The docks stay put; the band, ring, hoop, fins and crown are children of `Aim`, in its local space (the head sphere is centred
## `HEAD_CENTER` above the pivot with radius `HEAD_RADIUS`, the dome's top is at `HEAD_TOP`, the neck collar at `COLLAR_Y`).
static var materials: Dictionary = {}

const HEAD_CENTER: float = .27
const HEAD_RADIUS: float = .36
const HEAD_TOP: float = .70
const COLLAR_Y: float = -.045
const COLLAR_RADIUS: float = .30
## The antenna on the head (Aim-local x, z) and its length.
const ANTENNA := Vector2(.20, .17)
const PAD_RADIUS: float = .2
const LIGHT_RADIUS: float = .12

static func build(model: Node3D, form_id: String) -> TurretVisualHandles:
	if form_id not in ["escort_drones", "guardian_wing", "reaper_swarm"]:
		return null
	_ensure_materials()
	var head := model.find_child("Aim", true, false) as Node3D
	if head == null:
		head = model
	var count := int(TurretEvolution.base_stats("drone_bay", form_id).get("drone_count", 2))
	var tone := "sky" if form_id == "escort_drones" else ("green" if form_id == "guardian_wing" else "red")
	var dishes := DroneDock.perches(model)
	for slot in count:
		var at := DroneDock.dock_offset(dishes, slot, count)
		if slot < dishes.size():
			# A dish: a lit ring on its top (the dish's top is just under the empty the drone's centre is lifted from).
			_cylinder(model, "DockLight", LIGHT_RADIUS, .012, tone, Vector3(at.x, at.y - DroneDock.PERCH_LIFT + .008, at.z))
		else:
			var floor_y := at.y - DroneDock.PAD_LIFT if not dishes.is_empty() else 0.0
			_cylinder(model, "DockPad", PAD_RADIUS, .024, "dark", Vector3(at.x, floor_y + .012, at.z))
			_cylinder(model, "DockLight", LIGHT_RADIUS, .03, tone, Vector3(at.x, floor_y + .018, at.z))
	match form_id:
		"escort_drones":
			_torus(head, "Band", COLLAR_RADIUS + .015, COLLAR_RADIUS + .06, "sky", Vector3(0, COLLAR_Y - .05, 0))
			_torus(head, "MastRing", .035, .06, "sky", Vector3(ANTENNA.x, HEAD_TOP + .0, ANTENNA.y))
		"guardian_wing":
			var hoop := HEAD_RADIUS + .28
			_torus(head, "ShieldHoop", hoop - .02, hoop + .02, "green", Vector3(0, HEAD_CENTER, 0))
			for side: float in [-1.0, 1.0]:
				var fin := _box(head, "WingFin", Vector3(.03, .2, .36), "steel", Vector3(side * (hoop + .02), HEAD_CENTER + .06, .0))
				fin.rotation = Vector3(0, 0, side * deg_to_rad(-22.0))
				_box(head, "WingEdge", Vector3(.045, .04, .36), "green", Vector3(side * (hoop + .08), HEAD_CENTER + .16, .0)).rotation = Vector3(0, 0, side * deg_to_rad(-22.0))
		"reaper_swarm":
			for index in 5:
				var angle := deg_to_rad(float(index) * 72.0)
				var out := Vector3(cos(angle), 0.0, sin(angle))
				var spike := _cone(head, "CrownSpike", .055, .3, "red", out * .31 + Vector3(0, HEAD_TOP - .02, 0))
				spike.rotation = Vector3(out.z * deg_to_rad(18.0), 0, -out.x * deg_to_rad(18.0))
			_torus(head, "Band", COLLAR_RADIUS + .015, COLLAR_RADIUS + .06, "red", Vector3(0, COLLAR_Y - .05, 0))
	return null

static func _ensure_materials() -> void:
	if not materials.is_empty():
		return
	materials = VisualPalette.build([["steel", "7d8791", .8], ["dark", "1b2127", .4], ["sky", "58c8ff", .3, 1.4], ["green", "5dffa0", .3, 1.4], ["red", "ff5a3c", .3, 1.4]])

static func _cylinder(parent: Node3D, label: String, radius: float, height: float, material: String, at: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 1
	return _part(parent, label, mesh, material, at)

static func _cone(parent: Node3D, label: String, radius: float, height: float, material: String, at: Vector3) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	return _part(parent, label, mesh, material, at)

static func _box(parent: Node3D, label: String, size: Vector3, material: String, at: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _part(parent, label, mesh, material, at)

static func _torus(parent: Node3D, label: String, inner: float, outer: float, material: String, at: Vector3) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 8
	return _part(parent, label, mesh, material, at)

static func _sphere(parent: Node3D, label: String, radius: float, material: String, at: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return _part(parent, label, mesh, material, at)

static func _part(parent: Node3D, label: String, mesh: Mesh, material: String, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	# Repeated parts are numbered (DockPad, DockPad2, ...) instead of getting engine-made "@MeshInstance3D@N" names.
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

class_name DroneBayEvolutionVisual
extends RefCounted

## Runtime hardware for the Drone Bay line, built on the stand-in cp_mine_layer chassis (a hex body on six feet with a hopper that
## turns with `Aim`; see `MineLayerEvolutionVisual` for its measurements) until the Drone Bay's own chassis is wired. The unevolved
## bay is the bare chassis. Each form puts one landing pad on the floor for every drone it keeps, at the point the drone docks
## (`DroneBayForm.dock_point`), and marks the hopper:
##   Escort Drones  three sky-blue pads, a comms mast with a glowing tip on the hopper and a thin band round it.
##   Guardian Wing  four green pads, a shield hoop round the hopper and two angled wing fins on its sides.
##   Reaper Swarm   five red pads, a crown of five spikes round the hopper and a red band.
## The pads stay put; the mast, hoop, fins, crown and bands are children of `Aim`.
static var materials: Dictionary = {}

const DEFAULT_HOPPER_RADIUS: float = .55
const DEFAULT_HOPPER_TOP: float = 1.52
const AIM_HEIGHT: float = .7
const PAD_RADIUS: float = .17

static func build(model: Node3D, form_id: String) -> TurretVisualHandles:
	if form_id not in ["escort_drones", "guardian_wing", "reaper_swarm"]:
		return null
	_ensure_materials()
	var head := model.find_child("Aim", true, false) as Node3D
	if head == null:
		head = model
	var head_y: float = AIM_HEIGHT if head != model else 0.0
	var hopper_radius := DEFAULT_HOPPER_RADIUS
	var hopper_top := DEFAULT_HOPPER_TOP
	var hopper := model.find_child("Hopper_Teal", true, false) as MeshInstance3D
	if hopper and hopper.mesh:
		var box := hopper.mesh.get_aabb()
		hopper_radius = minf(box.size.x, box.size.z) * .5
		hopper_top = box.end.y + (head.position.y if hopper.get_parent() == head and head != model else 0.0)
	var count := int(TurretEvolution.base_stats("drone_bay", form_id).get("drone_count", 2))
	var pad := "sky" if form_id == "escort_drones" else ("green" if form_id == "guardian_wing" else "red")
	for slot in count:
		var angle := DroneBayForm.dock_angle(slot, count)
		var at := Vector3(cos(angle), 0.0, sin(angle)) * DroneBayForm.DOCK_RADIUS
		_cylinder(model, "DockPad", PAD_RADIUS, .03, "dark", Vector3(at.x, .015, at.z))
		_cylinder(model, "DockLight", PAD_RADIUS * .55, .035, pad, Vector3(at.x, .02, at.z))
	var top := hopper_top - head_y
	match form_id:
		"escort_drones":
			_cylinder(head, "CommsMast", .025, .5, "steel", Vector3(0, top + .25, 0))
			_sphere(head, "MastTip", .06, "sky", Vector3(0, top + .54, 0))
			_torus(head, "Band", hopper_radius + .005, hopper_radius + .06, "sky", Vector3(0, top - .08, 0))
		"guardian_wing":
			_torus(head, "ShieldHoop", hopper_radius + .12, hopper_radius + .16, "green", Vector3(0, top + .06, 0))
			for side: float in [-1.0, 1.0]:
				var fin := _box(head, "WingFin", Vector3(.05, .34, .5), "steel", Vector3(side * (hopper_radius + .05), top - .2, .1))
				fin.rotation = Vector3(0, 0, side * deg_to_rad(-22.0))
				_box(head, "WingEdge", Vector3(.06, .05, .5), "green", Vector3(side * (hopper_radius + .13), top - .04, .1)).rotation = Vector3(0, 0, side * deg_to_rad(-22.0))
		"reaper_swarm":
			for index in 5:
				var angle := float(index) * TAU / 5.0
				var spike := _cone(head, "CrownSpike", .06, .3, "red", Vector3(cos(angle) * (hopper_radius - .04), top + .12, sin(angle) * (hopper_radius - .04)))
				spike.rotation = Vector3(0, 0, 0)
			_torus(head, "Band", hopper_radius + .005, hopper_radius + .07, "red", Vector3(0, top - .08, 0))
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

class_name TeslaEvolutionVisual
extends RefCounted

## Runtime hardware for the Tesla forms, added to the authored chassis (the Tuning Fork Conductor for the Forked Coil and
## Capacitor, the Storm Network and Thunderhead models for the finals).
##   Forked Coil      a pair of brass prongs flanking the muzzle, the visible fork
##   Capacitor        two capacitor cans with brass bands on the sides of the coil and a `ChargeMeter` ring above it
##   Storm Network    a second coil head: the chassis muzzle and a mirrored `Muzzle2` fire in turn (`chain_muzzles`)
##   Thunderhead      a `ChargeMeter` ring round the orb
## The `ChargeMeter` is read and animated by `ChainForm.tick_mechanisms`.
static var materials: Dictionary = {}

static func build(model: Node3D, form_id: String) -> TurretVisualHandles:
	if form_id not in ["forked_coil", "capacitor", "storm_network", "thunderhead"]:
		return null
	if materials.is_empty():
		materials = VisualPalette.build([["brass", "dba94c", .8], ["teal", "237d82", .35], ["steel", "a9cfcc", .75], ["arc", "7fe8ff", .2, 2.0]])
	var aim := model.find_child("Aim", true, false) as Node3D
	var muzzle := model.find_child("Muzzle", true, false) as Node3D
	if aim == null or muzzle == null:
		return null
	match form_id:
		"forked_coil":
			for side: float in [-1.0, 1.0]:
				var prong := _cylinder(.035, .55, "brass")
				prong.name = "ForkProng%d" % int(side)
				aim.add_child(prong)
				prong.rotation.x = PI * .5
				prong.position = muzzle.position + Vector3(side * .13, .02, .05)
				var tip := _cylinder(.05, .06, "arc")
				tip.name = "ForkTip%d" % int(side)
				aim.add_child(tip)
				tip.rotation.x = PI * .5
				tip.position = muzzle.position + Vector3(side * .13, .02, -.25)
		"capacitor":
			for side: float in [-1.0, 1.0]:
				var can := _cylinder(.12, .42, "teal")
				can.name = "CapacitorCan%d" % int(side)
				aim.add_child(can)
				can.position = Vector3(side * .34, .58, 0)
				for height: float in [-.12, .12]:
					var band := TorusMesh.new()
					band.inner_radius = .115
					band.outer_radius = .145
					band.rings = 20
					band.ring_segments = 6
					_add(aim, "CapacitorBand%d_%d" % [int(side), int(height * 10.0)], band, "brass", Vector3(side * .34, .58 + height, 0))
			_meter(aim, muzzle.position + Vector3(0, .32, .3), .22)
		"storm_network":
			var second := Node3D.new()
			second.name = "Muzzle2"
			aim.add_child(second)
			second.position = muzzle.position + Vector3(.32, 0, 0)
			muzzle.position += Vector3(-.32, 0, 0)
			var handles := TurretVisualHandles.new()
			handles.chain_muzzles = [muzzle, second]
			return handles
		"thunderhead":
			_meter(aim, muzzle.position + Vector3(0, .05, .21), .34)
	return null

static func _meter(parent: Node3D, at: Vector3, radius: float) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = radius
	ring.outer_radius = radius + .04
	ring.rings = 28
	ring.ring_segments = 8
	var instance := _add(parent, "ChargeMeter", ring, "arc", at)
	# The meter owns its material: the form raises its emission as the charge builds.
	instance.material_override = (materials["arc"] as StandardMaterial3D).duplicate()
	instance.scale = Vector3.ONE * .35

static func _cylinder(radius: float, height: float, material: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = materials[material]
	return instance

static func _add(parent: Node3D, label: String, mesh: Mesh, material: String, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.material_override = materials[material]
	instance.position = at
	parent.add_child(instance)
	return instance

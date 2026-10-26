class_name GunbladeEvolutionVisual
extends RefCounted

static var materials: Dictionary = {}

static func build(model: Node3D, form_id: String) -> Array[Node3D]:
	var exits: Array[Node3D] = []
	if form_id != "stormblade":
		return exits
	var aim := model.find_child("Aim", true, false) as Node3D
	var muzzle := model.find_child("Muzzle", true, false) as Node3D
	exits.append(muzzle)
	if materials.is_empty():
		for entry in [["brass", "dba94c", .8], ["ivory", "eee7ce", .2], ["dark", "19252b", .4], ["teal", "237d82", .3]]:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(entry[1])
			material.metallic = entry[2]
			material.roughness = .28
			materials[entry[0]] = material
	# One extra barrel per follow-up round; the blade's own muzzle fires the first.
	for i in range(TurretEvolution.STORMBLADE_BURST_SHOTS - 1):
		var barrel := Node3D.new()
		barrel.name = "BurstBarrel%d" % (i + 1)
		aim.add_child(barrel)
		barrel.position = muzzle.position + Vector3(-.14 if i == 0 else .14, .22, 0)
		var sleeve := CylinderMesh.new()
		sleeve.top_radius = .082
		sleeve.bottom_radius = .082
		sleeve.height = .62
		sleeve.radial_segments = 24
		sleeve.rings = 1
		sleeve.cap_top = false
		sleeve.cap_bottom = false
		_part(barrel, sleeve, "brass", Vector3(0, 0, .31), true)
		for z: float in [.025, .20, .40, .59]:
			var rib := TorusMesh.new()
			rib.inner_radius = .056
			rib.outer_radius = .103
			rib.rings = 24
			rib.ring_segments = 8
			_part(barrel, rib, "ivory" if z < .1 else "brass", Vector3(0, 0, z), true)
		var bore := CylinderMesh.new()
		bore.top_radius = .063
		bore.bottom_radius = .063
		bore.height = .01
		bore.radial_segments = 24
		_part(barrel, bore, "dark", Vector3(0, 0, .14), true)
		var receiver := BoxMesh.new()
		receiver.size = Vector3(.20, .22, .31)
		_part(barrel, receiver, "teal", Vector3(0, -.06, .54), false)
		var exit := Node3D.new()
		exit.name = "GunMuzzle%d" % (i + 1)
		barrel.add_child(exit)
		exits.append(exit)
	return exits

static func _part(parent: Node3D, mesh: Mesh, material: String, at: Vector3, along_barrel: bool) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = materials[material]
	instance.position = at
	if along_barrel:
		instance.rotation.x = PI * .5
	parent.add_child(instance)

class_name GatlingEvolutionVisual
extends RefCounted

static var materials: Dictionary = {}

static func build(model: Node3D, form_id: String, stage: int) -> void:
	if form_id != "cyclone_gatling" or stage < 3:
		return
	var aim := model.find_child("Aim", true, false) as Node3D
	var rotor := model.find_child("Rotor", true, false) as Node3D
	if materials.is_empty():
		for entry in [["brass", "dba94c", .8], ["coral", "d7695a", .25], ["mint", "72e0c4", .3]]:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(entry[1])
			material.metallic = entry[2]
			material.roughness = .3
			materials[entry[0]] = material
	for side: float in [-1.0, 1.0]:
		var drum := Node3D.new()
		drum.name = "CycloneDrumLeft" if side < 0 else "CycloneDrumRight"
		aim.add_child(drum)
		drum.position = Vector3(side * .46, .24, .15)
		for entry in [[.0, .22, .24, "coral"], [-.115, .235, .035, "brass"], [.115, .235, .035, "brass"], [side * .145, .13, .055, "mint"]]:
			var body := CylinderMesh.new()
			body.top_radius = entry[1]
			body.bottom_radius = entry[1]
			body.height = entry[2]
			body.radial_segments = 32
			body.rings = 1
			_part(drum, body, entry[3], Vector3(entry[0], 0, 0), Vector3(0, 0, PI * .5))
	var cage := Node3D.new()
	cage.name = "CycloneRotorCage"
	rotor.add_child(cage)
	for z: float in [-.22, -.57]:
		var ring := TorusMesh.new()
		ring.inner_radius = .27
		ring.outer_radius = .31
		ring.rings = 32
		ring.ring_segments = 8
		_part(cage, ring, "brass", Vector3(0, 0, z), Vector3(PI * .5, 0, 0))
	for i in range(6):
		var angle := i * TAU / 6.0
		var rail := BoxMesh.new()
		rail.size = Vector3(.045, .065, .37)
		_part(cage, rail, "mint", Vector3(sin(angle) * .29, cos(angle) * .29, -.395), Vector3(0, 0, -angle))

static func _part(parent: Node3D, mesh: Mesh, material: String, at: Vector3, rotation: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = materials[material]
	instance.position = at
	instance.rotation = rotation
	parent.add_child(instance)

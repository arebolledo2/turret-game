class_name CrossfireEvolutionVisual
extends RefCounted

static func build(model: Node3D, branch: String, stage: int) -> Array[Node3D]:
	var exits: Array[Node3D] = []
	if branch != "scatter" or stage < 2:
		return exits
	for marker: String in ["Muzzle", "Muzzle_1", "Muzzle_2", "Muzzle_3"]:
		exits.append(model.find_child(marker, true, false) as Node3D)
	if stage < 3:
		return exits
	var aim := model.find_child("Aim", true, false) as Node3D
	var barrel := aim.get_node("Barrel_0") as Node3D
	var collar := aim.get_node("Collar_0") as Node3D
	for index in range(12):
		if index % 3 == 0:
			continue
		var spoke := Node3D.new()
		spoke.name = "OmniBarrel%d" % index
		aim.add_child(spoke)
		spoke.rotation.y = index * TAU / 12.0
		spoke.add_child(barrel.duplicate())
		spoke.add_child(collar.duplicate())
		var exit := exits[0].duplicate() as Node3D
		spoke.add_child(exit)
		exits.append(exit)
	return exits

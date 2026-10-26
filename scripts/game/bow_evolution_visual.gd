class_name BowEvolutionVisual
extends RefCounted

## Reuses authored coral limbs, bindings and strings; no duplicated base/support.
const BOW_PARTS := ["BowClamps", "BowHardware", "BowLimbs", "BowString"]

static func build(model: Node3D, form_id: String, stage: int) -> void:
	if stage < 1 or form_id not in ["repeater_bow", "arrowstorm", "titan_bow"]:
		return
	var aim := model.find_child("Aim", true, false) as Node3D
	var receiver := model.find_child("Receiver", true, false) as Node3D
	var muzzle := model.find_child("Muzzle", true, false) as Node3D
	var arrow := model.find_child("LoadedArrow", true, false) as Node3D
	if form_id in ["repeater_bow", "arrowstorm"]:
		var count: int = [2, 3, 5][stage - 1]
		var spacing := .26
		var parts: Array[Node3D] = []
		for part_name: String in BOW_PARTS:
			parts.append(model.find_child(part_name, true, false) as Node3D)
		parts.append(arrow)
		parts.append(muzzle)
		# Parallel bow channels share one receiver; burst shots leave their own rail.
		for i in range(1, count):
			for part in parts:
				var copy := part.duplicate() as Node3D
				copy.name = "%s%d" % [part.name, i]
				aim.add_child(copy)
				copy.position.x += (float(i) - float(count - 1) * .5) * spacing
		for part in parts:
			part.position.x -= float(count - 1) * .5 * spacing
		receiver.scale.x = 1.0 + float(count - 1) * .55
	else:
		# A broad horizontal bow gains additional laminated limb pairs at each form.
		var assembly := Node3D.new()
		assembly.name = "HeavyBowLimbs"
		aim.add_child(assembly)
		assembly.position.y = .22
		assembly.rotation.z = PI * .5
		assembly.scale = Vector3.ONE * (1.0 + .16 * stage)
		for part_name: String in BOW_PARTS:
			var part := model.find_child(part_name, true, false) as Node3D
			part.reparent(assembly, false)
			part.position.y -= .22
			for i in range(1, stage):
				var copy := part.duplicate() as Node3D
				copy.name = "%sLayer%d" % [part_name, i]
				assembly.add_child(copy)
				copy.position.z += .10 * i
		receiver.scale = Vector3(1.1 + .15 * stage, 1.0 + .12 * stage, 1.0)
		# Thicken the loaded shaft/head without pushing the exit through close targets.
		var scale_factor := 1.0 + .3 * stage
		arrow.scale *= Vector3(scale_factor, scale_factor, 1.0)
		arrow.position.y = .22 + (arrow.position.y - .22) * scale_factor

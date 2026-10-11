class_name DamageNumbers3D
extends Node3D

const LIMIT := 64
const LIFETIME := .85
const MERGE_WINDOW := .16
var entries: Array[Dictionary] = []
var serial := 0

func show_damage(actor: Node3D, amount: float, friendly: bool, critical: bool = false, fire: bool = false) -> void:
	if amount <= 0.0:
		return
	var key := "%d:%s:%s" % [actor.get_instance_id(), critical, fire]
	var entry: Dictionary = {}
	for candidate in entries:
		if candidate.key == key and candidate.age < MERGE_WINDOW:
			entry = candidate
			break
	if entry.is_empty():
		for candidate in entries:
			if candidate.age >= LIFETIME:
				entry = candidate
				break
		if entry.is_empty() and entries.size() < LIMIT:
			var label := Label3D.new()
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.no_depth_test = true
			label.font = preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
			label.pixel_size = .009
			label.outline_size = 8
			label.outline_modulate = Color(.025, .04, .06, .95)
			add_child(label)
			entry = {"label": label}
			entries.append(entry)
		elif entry.is_empty():
			entry = entries[0]
			for candidate in entries:
				if candidate.age > entry.age:
					entry = candidate
		serial += 1
		entry.key = key
		entry.age = 0.0
		entry.amount = 0.0
		entry.base = actor.global_position + Vector3((serial % 3 - 1) * .16, 1.9 if actor is CoreObjective else 1.3, 0)
		entry.critical = critical
		entry.friendly = friendly
	entry.amount += amount
	var label: Label3D = entry.label
	label.font_size = 60 if critical or friendly else 48
	label.modulate = Color("ff756c") if friendly else Color("ffd369") if critical else Color("ffb96c") if fire else Color("f0fffa")
	label.text = ("−" if friendly else "") + ("%.1f" % entry.amount if entry.amount < 10.0 else "%.0f" % entry.amount) + ("!" if critical else "")
	label.position = entry.base
	label.visible = true
	label.scale = Vector3.ONE

func advance(delta: float, reduced_motion: bool) -> void:
	for entry in entries:
		entry.age += delta
		var label: Label3D = entry.label
		label.visible = entry.age < LIFETIME
		if not label.visible:
			continue
		var t: float = entry.age / LIFETIME
		label.position = entry.base + Vector3.UP * (0.0 if reduced_motion else .65 * t)
		label.modulate.a = 1.0 - smoothstep(.55, 1.0, t)
		var pop := 1.0 if reduced_motion else 1.0 + .18 * sin(minf(1.0, t * 5.0) * PI)
		label.scale = Vector3.ONE * pop

func reset() -> void:
	for entry in entries:
		entry.age = LIFETIME
		entry.label.visible = false

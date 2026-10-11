class_name EnemyVariants
extends RefCounted

## Presentation and spawn schedule for enemy types that share the spider/charger models.
## Stats come from EnemyRegistry; this only adds tint, body size and a deterministic
## wave schedule (no gameplay RNG is consumed, so seeded runs stay reproducible).
const VARIANTS: Dictionary = {
	"fast": {"tint": Color(0.6, 0.9, 1.0), "scale": 0.8, "emission": 0.0},
	"tank": {"tint": Color(0.8, 0.5, 0.3), "scale": 1.4, "emission": 0.0},
	"exploder": {"tint": Color(1.0, 0.4, 0.2), "scale": 0.95, "emission": 0.6},
}
const NOTICES: Dictionary = {
	2: "Scout bots incoming · fast but fragile",
	3: "Chargers and Heavy bots incoming · dodge the amber lanes · plasma interrupts charges",
	4: "Boom bots incoming · shoot them at range, their blast hurts everyone nearby",
}

static var tinted_materials: Dictionary = {}

static func pick_type(wave: int, index: int) -> String:
	if wave >= 8:
		# Alternating assault patterns replace the fixed early-wave mix.
		var roster: Array[String] = ["basic", "fast", "charger", "basic", "tank", "fast", "exploder", "basic", "charger", "basic"]
		if wave >= 12:
			roster = ["tank", "fast", "charger", "exploder", "basic", "tank", "fast", "charger", "exploder", "basic"]
		if wave >= 16:
			roster = ["tank", "charger", "fast", "exploder", "tank", "charger", "fast", "exploder", "tank", "basic"]
		return roster[(index + wave * 3) % roster.size()]
	if wave >= int(EnemyRegistry.TYPES["charger"]["min_wave"]) and index % 4 == 0:
		return "charger"
	if wave >= int(EnemyRegistry.TYPES["exploder"]["min_wave"]) and index % 5 == 2:
		return "exploder"
	if wave >= int(EnemyRegistry.TYPES["tank"]["min_wave"]) and index % 7 == 3:
		return "tank"
	if wave >= int(EnemyRegistry.TYPES["fast"]["min_wave"]) and index % 4 == 1:
		return "fast"
	return "basic"

static func notice_for_wave(wave: int) -> String:
	if wave == 8: return "Assault waves · scouts and chargers probe your defenses"
	if wave == 12: return "Heavy assault · armored groups and explosive escorts"
	if wave == 16: return "Final onslaught · heavy bots lead the attack"
	return NOTICES.get(wave, "")

static func body_scale(type_id: String) -> float:
	return float(VARIANTS.get(type_id, {}).get("scale", 1.0))

## Shared per-(type, source material) copies keep identical enemies batchable.
static func apply_tint(model: Node, type_id: String) -> void:
	if VARIANTS.has(type_id):
		tint_model(model, type_id, VARIANTS[type_id]["tint"], float(VARIANTS[type_id]["emission"]))

static func tint_model(model: Node, type_id: String, tint: Color, emission: float) -> void:
	var variant := {"tint": tint, "emission": emission}
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in range(mesh_instance.mesh.get_surface_count()):
			var source := mesh_instance.get_active_material(surface) as StandardMaterial3D
			if not source:
				continue
			var key := [type_id, source]
			if not tinted_materials.has(key):
				var copy := source.duplicate() as StandardMaterial3D
				copy.albedo_color = source.albedo_color * (variant["tint"] as Color)
				if float(variant["emission"]) > 0.0:
					copy.emission_enabled = true
					copy.emission = variant["tint"]
					copy.emission_energy_multiplier = float(variant["emission"])
				tinted_materials[key] = copy
			mesh_instance.set_surface_override_material(surface, tinted_materials[key])

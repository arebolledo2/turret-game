class_name VisualPalette
extends RefCounted

## Metal-and-enamel palettes for the evolution visuals: material name -> StandardMaterial3D. An entry is
## [name, html colour, metallic], with an optional fourth number, the emission energy (absent or 0 for none).
static func build(entries: Array, roughness: float = .3) -> Dictionary:
	var result: Dictionary = {}
	for entry: Array in entries:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(entry[1])
		material.metallic = entry[2]
		material.roughness = roughness
		if entry.size() > 3 and entry[3] > 0.0:
			material.emission_enabled = true
			material.emission = Color(entry[1])
			material.emission_energy_multiplier = entry[3]
		result[entry[0]] = material
	return result

class_name ShopCatalog
extends RefCounted

## Which registry entries the arena shop may sell, and the feature flag (if any) each one needs.
## An empty flag means always available. New content ships by adding a row with its flag, so a
## flag that is off removes the content from stock and from purchase validation.
## Restricted to entries that have a 3D consumer; other registry rows are retained data.
const DEFAULT_ENTRIES: Dictionary = {
	"turret": {
		"normal": "", "plasma": "", "shock": "", "tesla": "", "melee": "",
	},
	"item": {
		"scrap_magnet": "", "reinforced_hull": "", "quick_loader": "", "shock_absorbers": "",
		"dense_rounds": "", "budget_capacitor": "", "ammo_surplus": "", "overclock_module": "",
		"compact_design": "", "extended_barrel": "", "rapid_coolant": "", "kinetic_enhancer": "",
		"heavy_plating": "",
	},
}

## Working copy; tests may add flag-gated rows and call reset() afterwards.
static var entries: Dictionary = DEFAULT_ENTRIES.duplicate(true)

static func reset() -> void:
	entries = DEFAULT_ENTRIES.duplicate(true)

## Every catalogued id of a kind, regardless of flags.
static func ids(kind: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in entries.get(kind, {}):
		result.append(id)
	return result

static func requires_flag(kind: String, id: String) -> String:
	return str(entries.get(kind, {}).get(id, ""))

static func is_available(kind: String, id: String) -> bool:
	if not entries.get(kind, {}).has(id):
		return false
	var flag := requires_flag(kind, id)
	return flag.is_empty() or FeatureFlagService.is_enabled(flag)

static func available_ids(kind: String) -> Array[String]:
	var result: Array[String] = []
	for id in ids(kind):
		if is_available(kind, id):
			result.append(id)
	return result

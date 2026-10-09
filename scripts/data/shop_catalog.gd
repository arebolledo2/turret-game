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
		# Kept from the original pool
		"scrap_magnet": "", "reinforced_hull": "", "quick_loader": "", "dense_rounds": "", "budget_capacitor": "",
		"compact_design": "", "extended_barrel": "", "rapid_coolant": "", "heavy_plating": "", "mass_production": "",
		# Item pool v2 (Phase 2)
		"polished_barrels": "items_v2", "blast_charges": "items_v2", "capacitor_bank": "items_v2", "weighted_bat": "items_v2",
		"concrete_footings": "items_v2", "static_grounding": "items_v2", "faulty_wiring": "items_v2",
		"ion_doctrine": "items_v2", "plasma_doctrine": "items_v2", "voltage_doctrine": "items_v2", "bat_doctrine": "items_v2",
		"piercing_rounds": "items_v2", "cluster_warheads": "items_v2", "superconductors": "items_v2", "spiked_bat": "items_v2",
		"hardpoint": "items_v2",
		# Convoy items (also restricted to Convoy runs by CONVOY_ONLY)
		"tracked_chassis": "mode_convoy", "overdrive_engine": "mode_convoy", "heavy_hauler": "mode_convoy",
		# Item pool v2: rare, epic, legendary
		"arc_rod": "items_v2_hooks", "plasma_capacitor": "items_v2_hooks", "killzone_bat": "items_v2_hooks",
		"overwatch_optics": "items_v2_hooks", "army_doctrine": "items_v2_hooks", "elite_forces": "items_v2_hooks",
		"last_stand": "items_v2_hooks", "quality_over_quantity": "items_v2_hooks", "glass_cannon_core": "items_v2_hooks",
		"mono_type_mastery": "items_v2_hooks", "reactor_overload": "items_v2_hooks", "storm_conductor": "items_v2_hooks",
		"elemental_conduit": "items_v2_hooks", "whirlwind_frame": "items_v2_hooks",
	},
}

## Items that only make sense when the core moves; the shop leaves them out of every other mode's stock.
const CONVOY_ONLY: Array[String] = ["tracked_chassis", "overdrive_engine", "heavy_hauler"]

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

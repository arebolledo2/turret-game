class_name ShopCatalog
extends RefCounted

## Which registry entries the arena shop may sell, and the feature flag (if any) each one needs.
## An empty flag means always available. New content ships by adding a row with its flag, so a
## flag that is off removes the content from stock and from purchase validation.
## Restricted to entries that have a 3D consumer; other registry rows are retained data.
const DEFAULT_ENTRIES: Dictionary = {
	"turret": {
		"normal": "", "plasma": "", "shock": "", "tesla": "", "melee": "",
		"bow": "", "flamethrower": "", "bowling": "",
	},
	"item": {
		"opening_salvo": "", "return_address": "", "slipstream_fletching": "", "cinder_reserve": "", "arc_insurance": "", "follow_through": "", "counterweight": "", "victory_lap": "", "rescue_beacon": "", "reserve_battery": "", "close_partnership": "", "lone_sentry": "", "crosslink_array": "",
		# Kept from the original pool
		"scrap_magnet": "", "reinforced_hull": "", "quick_loader": "", "dense_rounds": "", "budget_capacitor": "",
		"compact_design": "", "extended_barrel": "", "rapid_coolant": "", "heavy_plating": "", "mass_production": "",
		# Item pool v2 (Phase 2)
		"polished_barrels": "", "blast_charges": "", "capacitor_bank": "", "weighted_bat": "",
		"concrete_footings": "", "static_grounding": "", "faulty_wiring": "",
		"ion_doctrine": "", "plasma_doctrine": "", "voltage_doctrine": "", "bat_doctrine": "",
		"piercing_rounds": "", "cluster_warheads": "", "superconductors": "", "spiked_bat": "",
		"hardpoint": "",
		# Convoy items (also restricted to Convoy runs by CONVOY_ONLY)
		"tracked_chassis": "mode_convoy", "overdrive_engine": "mode_convoy", "heavy_hauler": "mode_convoy",
		# Item pool v2: rare, epic, legendary
		"arc_rod": "", "plasma_capacitor": "", "killzone_bat": "",
		"overwatch_optics": "", "army_doctrine": "", "elite_forces": "",
		"last_stand": "", "quality_over_quantity": "", "glass_cannon_core": "",
		"mono_type_mastery": "", "reactor_overload": "", "storm_conductor": "",
		"elemental_conduit": "", "whirlwind_frame": "",
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

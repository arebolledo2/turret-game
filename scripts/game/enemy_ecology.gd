class_name EnemyEcology
extends RefCounted

## Runtime identities and authored wave budgets. Summons never enter the normal spawn pool.
const TYPES := {
	"broadside_baron": {"name": "Broadside Baron", "health": 260.0, "speed": 90.0, "contact_damage": 0.0, "mass": 35.0, "scale": 0.95, "cost": 0},
	"frostforge_yeti": {"name": "Frostforge Yeti", "health": 260.0, "speed": 130.0, "contact_damage": 0.0, "mass": 35.0, "scale": 1.10, "cost": 0},
	"skyfall_kestrel": {"name": "Skyfall Kestrel", "health": 260.0, "speed": 280.0, "contact_damage": 0.0, "mass": 35.0, "scale": 0.90, "cost": 0},
	"crucible_crab": {"name": "Crucible Crab", "health": 260.0, "speed": 85.0, "contact_damage": 0.0, "mass": 35.0, "scale": 1.05, "cost": 0},
	"pendulum_regent": {"name": "Pendulum Regent", "health": 260.0, "speed": 105.0, "contact_damage": 0.0, "mass": 35.0, "scale": 1.00, "cost": 0},
	"crownwheel_colossus": {"name": "Crownwheel Colossus", "health": 260.0, "speed": 150.0, "contact_damage": 10.0, "mass": 35.0, "scale": 1.05, "cost": 0},

	"drowse": {"name": "Drowse Beetle", "health": 4.8, "speed": 100.0, "contact_damage": 2.0, "mass": 1.0, "scale": .85, "cost": 1},
	"hopper": {"name": "Rivet Hopper", "health": 8.0, "speed": 300.0, "contact_damage": 6.0, "mass": 1.0, "scale": .85, "cost": 2},
	"kite": {"name": "Needle Kite", "health": 6.0, "speed": 150.0, "contact_damage": 0.0, "mass": .8, "scale": .8, "cost": 2},
	"lobber": {"name": "Kiln Lobber", "health": 12.0, "speed": 65.0, "contact_damage": 0.0, "mass": 3.0, "scale": 1.0, "cost": 4},
	"tender": {"name": "Brood Tender", "health": 16.0, "speed": 75.0, "contact_damage": 0.0, "mass": 3.0, "scale": 1.0, "cost": 6},
	"skitter": {"name": "Rivet Skitter", "health": 3.0, "speed": 170.0, "contact_damage": 3.0, "mass": .4, "scale": .45, "cost": 0},
	"brass_ram": {"name": "Brass Ram", "health": 180.0, "speed": 110.0, "contact_damage": 12.0, "mass": 30.0, "scale": 1.65, "cost": 0},
	"prism_conductor": {"name": "Prism Conductor", "health": 260.0, "speed": 80.0, "contact_damage": 0.0, "mass": 30.0, "scale": 1.55, "cost": 0},
	"grand_marionettist": {"name": "Grand Marionettist", "health": 360.0, "speed": 100.0, "contact_damage": 10.0, "mass": 40.0, "scale": 1.5, "cost": 0},
	"lens": {"name": "Prism Lens", "health": 5.0, "speed": 100.0, "contact_damage": 0.0, "mass": 1.0, "scale": .5, "cost": 0},
	"anchor": {"name": "Tether Anchor", "health": 6.0, "speed": 0.0, "contact_damage": 0.0, "mass": 100.0, "scale": .6, "cost": 0},
	"puppet": {"name": "Clockwork Puppet", "health": 6.0, "speed": 130.0, "contact_damage": 4.0, "mass": .8, "scale": .6, "cost": 0},
}
const FOOTPRINTS := {"broadside_baron": 0.85, "frostforge_yeti": 0.65, "skyfall_kestrel": 0.80, "crucible_crab": 0.80, "pendulum_regent": 0.60, "crownwheel_colossus": 0.65, "drowse": .48, "hopper": .38, "kite": .34, "lobber": .45, "tender": .55, "skitter": .44, "brass_ram": .6, "prism_conductor": .52, "grand_marionettist": .38, "lens": .42, "anchor": .3, "puppet": .25}
const BOSSES := {6: "brass_ram", 8: "frostforge_yeti", 10: "broadside_baron", 12: "prism_conductor", 14: "crucible_crab", 16: "skyfall_kestrel", 18: "pendulum_regent", 19: "crownwheel_colossus", 20: "grand_marionettist"}
const SUMMONS: Array[String] = ["skitter", "lens", "anchor", "puppet"]
const CAPS := {"kite": 4, "lobber": 2, "tender": 2, "skitter": 8, "lens": 2, "anchor": 2, "puppet": 4}
const WAVES := [
	["Sleepy Yard", {"drowse": 40, "basic": 60}],
	["Scout Patrol", {"drowse": 35, "basic": 25, "fast": 40}],
	["Scrap Meadow", {"drowse": 40, "basic": 45, "fast": 15}],
	["Crossing Paths", {"drowse": 30, "basic": 25, "fast": 45}],
	["Wake-up Call", {"drowse": 25, "basic": 45, "fast": 30}],
	["Brass Ram", {"drowse": 25, "basic": 45, "fast": 30}],
	["The Hunt", {"drowse": 25, "basic": 35, "hopper": 40}],
	["Needle Alley", {"basic": 30, "fast": 25, "kite": 45}],
	["Siege Line", {"tank": 30, "basic": 30, "lobber": 40}],
	["Hatchery", {"drowse": 45, "basic": 20, "tender": 35}],
	["Spring Ambush", {"charger": 30, "fast": 30, "hopper": 40}],
	["Prism Conductor", {"basic": 25, "fast": 30, "tank": 20, "kite": 25}],
	["Glass Crossfire", {"fast": 25, "exploder": 25, "kite": 50}],
	["Heavy Pursuit", {"tank": 60, "hopper": 40}],
	["Bombardment", {"tank": 40, "exploder": 20, "lobber": 40}],
	["Factory Floor", {"basic": 30, "charger": 30, "tender": 40}],
	["Rapid Interference", {"charger": 30, "fast": 30, "kite": 40}],
	["Last Hunt", {"fast": 20, "exploder": 20, "hopper": 60}],
	["Fortress Break", {"tank": 30, "basic": 20, "lobber": 30, "tender": 20}],
	["Grand Marionettist", {"tank": 30, "charger": 25, "exploder": 20, "lobber": 25}],
]

## Protect-the-Core escorts preserve each wave's specialty while maintaining active siege pressure.
const CORE_ROSTERS := {
	6: {"basic": 45, "tank": 15, "fast": 25, "drowse": 15},
	7: {"basic": 60, "hopper": 40},
	8: {"basic": 35, "fast": 25, "kite": 40},
	10: {"basic": 40, "fast": 20, "tender": 35, "drowse": 5},
	12: {"fast": 40, "tank": 20, "basic": 20, "kite": 20},
	13: {"fast": 35, "exploder": 25, "kite": 40},
	18: {"fast": 35, "exploder": 25, "hopper": 40},
	20: {"tank": 30, "charger": 30, "basic": 15, "lobber": 25},
}

const EXPANSION_BOSSES: Array[String] = ["broadside_baron", "frostforge_yeti", "skyfall_kestrel", "crucible_crab", "pendulum_regent", "crownwheel_colossus"]

const BOSS_IDS: Array[String] = ["broadside_baron", "frostforge_yeti", "skyfall_kestrel", "crucible_crab", "pendulum_regent", "crownwheel_colossus", "brass_ram", "prism_conductor", "grand_marionettist"]

static func is_boss(type_id: String) -> bool:
	return type_id in BOSS_IDS

static func ranged_threat(type_id: String) -> bool:
	return type_id in EXPANSION_BOSSES or type_id in ["kite", "lobber", "lens", "anchor", "tender", "prism_conductor", "grand_marionettist"]

static func hero_only(type_id: String) -> bool:
	return TYPES.has(type_id) and type_id not in ["lobber", "drowse"]

static func cost(type_id: String) -> int:
	if TYPES.has(type_id):
		return int(TYPES[type_id].cost)
	return int({"basic": 1, "fast": 1, "tank": 3, "charger": 2, "exploder": 2}.get(type_id, 1))

static func roster(wave: int, protect_core: bool = false) -> Dictionary:
	if protect_core and CORE_ROSTERS.has(wave): return CORE_ROSTERS[wave]
	return WAVES[clampi(wave - 1, 0, WAVES.size() - 1)][1]

static func title(wave: int) -> String:
	if BOSSES.has(wave): return str(TYPES[BOSSES[wave]].name)
	return str(WAVES[clampi(wave - 1, 0, WAVES.size() - 1)][0])

static func budget_multiplier(wave: int, _protect_core: bool = false) -> float:
	if wave <= 5:
		return .55 + .05 * maxi(wave, 1)
	return 1.0 # Bosses are additional threats; regular wave budgets are never reduced.

## Smooth weighted selection by deficit spends encounter points, not enemy counts.
## Deterministic and independent of gameplay RNG; no hidden global growing roster.
static func schedule(wave: int, budget: int, protect_core: bool = false) -> Array[String]:
	var weights := roster(wave, protect_core)
	var spent := {}
	var result: Array[String] = []
	var total := 0
	while total < budget:
		var selected := ""
		var largest := -INF
		for type_id: String in weights:
			var points := cost(type_id)
			if points > budget - total:
				continue
			var deficit := float(weights[type_id]) * float(total + points) / 100.0 - float(spent.get(type_id, 0))
			if deficit > largest:
				largest = deficit
				selected = type_id
		if selected.is_empty():
			break
		var points := cost(selected)
		spent[selected] = int(spent.get(selected, 0)) + points
		total += points
		result.append(selected)
	return result

static func fallback(wave: int, protect_core: bool = false) -> String:
	var best := ""
	for type_id: String in roster(wave, protect_core):
		if best.is_empty() or cost(type_id) < cost(best):
			best = type_id
	return best

## Fixed benchmark builds, never the current player's DPS. 90% of the normal combat window.
## Reference focused DPS: 30 at wave6, 75 at12, 180 at20; movement makes actual kills slower.
static func boss_health(type_id: String, difficulty: Dictionary) -> float:
	var wave: int = BOSSES.find_key(type_id)
	var reference_dps := lerpf(30.0, 75.0, clampf((wave - 6) / 6.0, 0.0, 1.0)) if wave <= 12 else lerpf(75.0, 180.0, clampf((wave - 12) / 8.0, 0.0, 1.0))
	return roundf(reference_dps * GameStateService.get_wave_duration(wave) * .9 * float(difficulty.get("enemy_health_mult", 1.0)))

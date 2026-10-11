class_name TurretEvolution
extends RefCounted

## Run-local branches. IDs describe attacks; model_key selects a reusable authored chassis.
## Ownership always remains with the original base type.
const PATHS: Dictionary = {
	"normal": {
		"machine_gun": ["Machine Gun", "Gatling", "Cyclone Gatling"],
		"scatter": ["Scattershot", "Crossfire", "Omnifire"],
	},
	"melee": {
		"saber": ["Saber", "Twin Saber", "Orbit Saber"],
		"gunblade": ["Gunblade", "Repeater Blade", "Stormblade"],
	},
	"plasma": {
		"siege": ["Siege Cannon", "Moonshot", "Worldbreaker"],
		"mortar": ["Mortar", "Starburst", "Constellation"],
	},
	"shock": {
		"resonator": ["Resonator", "Echo Chamber", "Resonance Engine"],
		"lance": ["Focused Lance", "Thunder Pin", "Thunder Spear"],
	},
	"tesla": {
		"relay": ["Forked Coil", "Storm Relay", "Storm Network"],
		"capacitor": ["Capacitor", "Rail Discharge", "Thunderhead"],
	},
	"bow": {
		"repeater_bow": ["Repeater Bow", "Volley Ballista", "Arrowstorm"],
		"greatbow": ["Greatbow", "Harpoon Ballista", "Titan Bow"],
	},
	"flamethrower": {
		"wide_flame": ["Wide Flame", "Furnace Fan", "Inferno Crown"],
		"focused_jet": ["Focused Jet", "Dragon Nozzle", "Dragonheart"],
	},
	"bowling": {
		"heavy_roller": ["Heavy Roller", "Demolition Roller", "Juggernaut"],
		"bank_shot": ["Bank Shot", "Pinball Engine", "Ricochet King"],
	},
}

static func branches(base_type: String) -> Array[String]:
	var result: Array[String] = []
	for branch: String in PATHS.get(base_type, {}):
		result.append(branch)
	return result

static func form_name(base_type: String, branch: String, stage: int) -> String:
	if stage < 1 or stage > 3 or not PATHS.get(base_type, {}).has(branch):
		return ""
	return str(PATHS[base_type][branch][stage - 1])

static func model_key(base_type: String, branch: String, stage: int) -> String:
	match branch:
		"machine_gun": return "gatling" if stage >= 2 else "machine_gun"
		"scatter": return "crossfire" if stage >= 2 else "scatter"
		"saber", "gunblade": return branch
		"siege", "mortar": return "siege"
		"repeater_bow", "greatbow": return "bow"
		"wide_flame", "focused_jet": return "flamethrower"
		"heavy_roller", "bank_shot": return "bowling"
	return "ion" if base_type == "normal" else base_type

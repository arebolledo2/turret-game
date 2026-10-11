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

## Shape the attack before item modifiers so flat bonuses remain meaningful.
static func base_stats(base_type: String, branch: String, stage: int) -> Dictionary:
	var stats := TurretRegistry.get_base_stats(base_type)
	if stage <= 0:
		return stats
	match branch:
		"machine_gun":
			stats.damage = [6.5, 5.5, 6.5][stage - 1]
			stats.fire_rate = [3.2, 4.0, 4.8][stage - 1]
			stats.projectile_speed = 1000.0
		"scatter":
			stats.damage = [8.0, 9.0, 10.0][stage - 1]
			stats.fire_rate = [1.0, 1.15, 1.25][stage - 1]
			stats.range = 220.0
		"siege":
			stats.damage = [42.0, 58.0, 80.0][stage - 1]
			stats.fire_rate = [.45, .5, .55][stage - 1]
			stats.range = 330.0
			stats.projectile_speed = 350.0
			stats.aoe_radius = [135.0, 160.0, 185.0][stage - 1]
			stats.knockback_force = 220.0
		"saber":
			stats.damage = [11.0, 12.0, 14.0][stage - 1]
			stats.rotation_rate = [420.0, 450.0, 480.0][stage - 1]
			stats.range = [145.0, 155.0, 170.0][stage - 1]
	return stats

static func description(branch: String, stage: int) -> String:
	match branch:
		"machine_gun": return "Rapid aimed fire." if stage == 1 else "Rotary fire accelerates while a target remains in range."
		"scatter": return "Three projectiles fan out with each shot." if stage == 1 else "Fires in four directions at once."
		"saber": return "A longer, faster energy-blade sweep."
		"siege": return "Slow, heavy shells explode over a large area and push enemies back."
	return ""

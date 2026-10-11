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
			stats.pierce = 1 if stage >= 3 else 0
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
			stats.knockback_force = [220.0, 280.0, 360.0][stage - 1]
		"heavy_roller":
			stats.damage = [30.0, 43.0, 60.0][stage - 1]
			stats.pierce = [7, 10, 14][stage - 1]
			stats.knockback_force = [330.0, 420.0, 520.0][stage - 1]
			stats.fire_rate = [.6, .65, .7][stage - 1]
		"bank_shot":
			stats.damage = [22.0, 28.0, 36.0][stage - 1]
			stats.fire_rate = [.7, .8, .9][stage - 1]
			stats.projectile_speed = 400.0
			stats.pierce = 0
		"wide_flame":
			stats.damage = [3.2, 4.0, 5.0][stage - 1]
			stats.cone_degrees = [60.0, 85.0, 110.0][stage - 1]
			stats.burn_duration = [2.2, 2.5, 3.0][stage - 1]
		"focused_jet":
			stats.damage = [3.2, 4.0, 5.0][stage - 1]
			stats.range = [280.0, 330.0, 380.0][stage - 1]
			stats.cone_degrees = [24.0, 20.0, 16.0][stage - 1]
			stats.burn_ratio = [2.2, 2.6, 3.0][stage - 1]
			stats.burn_duration = [2.5, 3.0, 3.5][stage - 1]
		"repeater_bow":
			stats.damage = [12.0, 13.0, 14.0][stage - 1]
			stats.fire_rate = [.9, 1.0, 1.1][stage - 1]
			stats.projectile_speed = 1050.0
			stats.pierce = [1, 2, 2][stage - 1]
		"greatbow":
			stats.damage = [32.0, 46.0, 66.0][stage - 1]
			stats.fire_rate = [.7, .75, .8][stage - 1]
			stats.range = [390.0, 430.0, 470.0][stage - 1]
			stats.projectile_speed = 1100.0
			stats.pierce = [3, 5, 8][stage - 1]
			stats.knockback_force = [120.0, 180.0, 240.0][stage - 1]
		"gunblade":
			stats.damage = [9.0, 10.0, 12.0][stage - 1]
			stats.rotation_rate = [300.0, 330.0, 360.0][stage - 1]
			stats.range = [150.0, 160.0, 170.0][stage - 1]
		"saber":
			stats.damage = [11.0, 12.0, 14.0][stage - 1]
			stats.rotation_rate = [420.0, 450.0, 480.0][stage - 1]
			stats.range = [145.0, 155.0, 170.0][stage - 1]
	return stats

static func description(branch: String, stage: int) -> String:
	match branch:
		"machine_gun": return ["Rapid aimed fire.", "Rotary fire accelerates while a target remains in range.", "Piercing rotary fire accelerates to 2.5 times its resting rate."][stage - 1]
		"scatter": return ["Three projectiles fan out with each shot.", "Fires in four directions at once.", "Twelve shots cover a full circle in evenly spaced directions."][stage - 1]
		"heavy_roller": return "Larger balls drive through crowds with stronger knockback."
		"bank_shot": return "Redirects toward a fresh nearby enemy up to %d times." % [2, 4, 6][stage - 1]
		"wide_flame": return "A %d-degree fan blankets a crowd and leaves enemies burning." % [60, 85, 110][stage - 1]
		"focused_jet": return "A longer, narrower jet delivers a stronger, longer-lasting burn."
		"repeater_bow": return "Fires a quick burst of %d piercing arrows." % [2, 3, 5][stage - 1]
		"greatbow": return "Heavy arrows pierce %d enemies and knock them back." % [4, 6, 9][stage - 1]
		"gunblade": return ["Sweeps a blade and fires when its barrel aligns with an enemy.", "Sweeps a stronger blade and fires two-shot bursts along its rotation.", "Three-shot piercing bursts accompany a longer, faster blade sweep."][stage - 1]
		"saber": return ["A longer, faster energy-blade sweep.", "Two opposing held blades sweep both sides of the turret.", "Three held energy blades sweep evenly around the turret."][stage - 1]
		"siege": return "Slow, heavy shells explode over a large area and push enemies back."
	return ""

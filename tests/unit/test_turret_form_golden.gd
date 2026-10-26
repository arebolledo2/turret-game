extends GutTest

## Golden snapshot of every turret form, recorded from the code before the form-table refactor (legacy_stage removal and
## the single form table). The expected values below are plain literals on purpose: a refactor that changes any form's
## stats, text, shot shape, behaviour class, visual builder or built model must fail here instead of passing silently.
## If a number must change on purpose (a balance retune), edit the literal in the same commit and say why.
##
## What is pinned, per form (all 30 registered forms, implemented or not) and per base turret with no form:
##   FORMS     base, kind (upgrade or final), name, model key, implemented, description
##   STATS     the full `TurretEvolution.base_stats(base, form)` dictionary (every key, with its type)
##   SHOTS     `shape_shot` on a fresh `CombatShot3D`: visual_key, visual_scale, radius, lifetime, ricochets, pierce
##   BEHAVIOUR the `TurretForm` subclass the actor creates for the form ("" when the actor handles it itself)
##   BUILDERS  which `*EvolutionVisual` builders change the form's chassis (each is run on a fresh model)
##   MODELS    the model the actor builds: node and mesh counts, handles the attack code reads (muzzles, emitters, saber
##             arms) and a digest of every node's class, name, transform, mesh size and material
##   MISC      volley size, pierce text, the Stormblade barrel stats, Resonator echo delays and Quake pattern text
##
## The collectors only call lookups (`_stats`, `_shot`, `_volley`, ...); when a refactor changes a function signature,
## adapt the lookup here, never the expected values.

const BASES: Array[String] = ["normal", "melee", "bow", "flamethrower", "bowling", "plasma", "shock", "tesla", "sniper", "quake"]
const BUILDERS: Array[String] = ["BowEvolutionVisual", "FlameEvolutionVisual", "BowlingEvolutionVisual", "GunbladeEvolutionVisual", "SiegeEvolutionVisual", "SniperEvolutionVisual", "QuakeEvolutionVisual", "GatlingEvolutionVisual", "CrossfireEvolutionVisual"]

const FORMS: Dictionary = {
	"machine_gun": {
		"base": "normal",
		"kind": "upgrade",
		"name": "Machine Gun",
		"model": "machine_gun",
		"implemented": true,
		"description": "Rapid aimed fire.",
	},
	"cyclone_gatling": {
		"base": "normal",
		"kind": "final",
		"name": "Cyclone Gatling",
		"model": "gatling",
		"implemented": true,
		"description": "Piercing rotary fire accelerates to 2.5 times its resting rate.",
	},
	"omnifire": {
		"base": "normal",
		"kind": "final",
		"name": "Omnifire",
		"model": "crossfire",
		"implemented": true,
		"description": "Twelve shots cover a full circle in evenly spaced directions.",
	},
	"saber": {
		"base": "melee",
		"kind": "upgrade",
		"name": "Saber",
		"model": "saber",
		"implemented": true,
		"description": "A longer, faster energy-blade sweep.",
	},
	"orbit_saber": {
		"base": "melee",
		"kind": "final",
		"name": "Orbit Saber",
		"model": "saber",
		"implemented": true,
		"description": "Three held energy blades sweep evenly around the turret.",
	},
	"stormblade": {
		"base": "melee",
		"kind": "final",
		"name": "Stormblade",
		"model": "gunblade",
		"implemented": true,
		"description": "Three-shot piercing bursts accompany a longer, faster blade sweep.",
	},
	"repeater_bow": {
		"base": "bow",
		"kind": "upgrade",
		"name": "Repeater Bow",
		"model": "bow",
		"implemented": true,
		"description": "Fires a quick burst of 2 piercing arrows.",
	},
	"arrowstorm": {
		"base": "bow",
		"kind": "final",
		"name": "Arrowstorm",
		"model": "bow",
		"implemented": true,
		"description": "Fires a quick burst of 5 piercing arrows.",
	},
	"titan_bow": {
		"base": "bow",
		"kind": "final",
		"name": "Titan Bow",
		"model": "bow",
		"implemented": true,
		"description": "Heavy arrows pierce 9 enemies and knock them back.",
	},
	"wide_flame": {
		"base": "flamethrower",
		"kind": "upgrade",
		"name": "Wide Flame",
		"model": "flamethrower",
		"implemented": true,
		"description": "A 60-degree fan blankets a crowd and leaves enemies burning.",
	},
	"inferno_crown": {
		"base": "flamethrower",
		"kind": "final",
		"name": "Inferno Crown",
		"model": "flamethrower",
		"implemented": true,
		"description": "A 110-degree fan blankets a crowd and leaves enemies burning.",
	},
	"dragonheart": {
		"base": "flamethrower",
		"kind": "final",
		"name": "Dragonheart",
		"model": "flamethrower",
		"implemented": true,
		"description": "A longer, narrower jet delivers a stronger, longer-lasting burn.",
	},
	"heavy_roller": {
		"base": "bowling",
		"kind": "upgrade",
		"name": "Heavy Roller",
		"model": "bowling",
		"implemented": true,
		"description": "Larger balls drive through crowds with stronger knockback.",
	},
	"juggernaut": {
		"base": "bowling",
		"kind": "final",
		"name": "Juggernaut",
		"model": "bowling",
		"implemented": true,
		"description": "Larger balls drive through crowds with stronger knockback.",
	},
	"ricochet_king": {
		"base": "bowling",
		"kind": "final",
		"name": "Ricochet King",
		"model": "bowling",
		"implemented": true,
		"description": "Redirects toward a fresh nearby enemy up to 6 times.",
	},
	"siege": {
		"base": "plasma",
		"kind": "upgrade",
		"name": "Siege Cannon",
		"model": "siege",
		"implemented": true,
		"description": "Slow, heavy shells explode over a large area and push enemies back.",
	},
	"worldbreaker": {
		"base": "plasma",
		"kind": "final",
		"name": "Worldbreaker",
		"model": "siege",
		"implemented": true,
		"description": "Slow, heavy shells explode over a large area and push enemies back.",
	},
	"constellation": {
		"base": "plasma",
		"kind": "final",
		"name": "Constellation",
		"model": "siege",
		"implemented": false,
		"description": "",
	},
	"resonator": {
		"base": "shock",
		"kind": "upgrade",
		"name": "Resonator",
		"model": "resonator",
		"implemented": true,
		"description": "Each pulse echoes once half a second later at half damage, refreshing the slow.",
	},
	"resonance_engine": {
		"base": "shock",
		"kind": "final",
		"name": "Resonance Engine",
		"model": "resonance_engine",
		"implemented": true,
		"description": "Pulses alternate a tight, hard inner ring and a wide outer ring; enemies caught by both are Exposed, taking 30% more from Instant turrets.",
	},
	"thunder_spear": {
		"base": "shock",
		"kind": "final",
		"name": "Thunder Spear",
		"model": "thunder_spear",
		"implemented": true,
		"description": "The bolt drives through a whole lane of enemies and pins every one.",
	},
	"forked_coil": {
		"base": "tesla",
		"kind": "upgrade",
		"name": "Forked Coil",
		"model": "tesla",
		"implemented": false,
		"description": "",
	},
	"storm_network": {
		"base": "tesla",
		"kind": "final",
		"name": "Storm Network",
		"model": "storm_network",
		"implemented": false,
		"description": "",
	},
	"thunderhead": {
		"base": "tesla",
		"kind": "final",
		"name": "Thunderhead",
		"model": "thunderhead",
		"implemented": false,
		"description": "",
	},
	"piercer_rifle": {
		"base": "sniper",
		"kind": "upgrade",
		"name": "Piercer Rifle",
		"model": "sniper",
		"implemented": true,
		"description": "A longer barrel and heavier rounds. The shot passes through two enemies behind its target.",
	},
	"horizon_piercer": {
		"base": "sniper",
		"kind": "final",
		"name": "Horizon Piercer",
		"model": "sniper",
		"implemented": true,
		"description": "The shot runs the whole line to full range and strikes every enemy on it. Aim the toughest enemy through the crowd.",
	},
	"overwatch": {
		"base": "sniper",
		"kind": "final",
		"name": "Overwatch",
		"model": "sniper",
		"implemented": true,
		"description": "Keeps the Piercer shot and marks the three toughest enemies in range for 6 seconds. Marked enemies take 25% more damage from every turret, and the mark jumps to the next toughest enemy when one dies.",
	},
	"aftershock": {
		"base": "quake",
		"kind": "upgrade",
		"name": "Aftershock",
		"model": "quake",
		"implemented": true,
		"description": "A second pulse follows 0.6 seconds after the first at half damage and the same radius.",
	},
	"tectonic": {
		"base": "quake",
		"kind": "final",
		"name": "Tectonic",
		"model": "quake",
		"implemented": true,
		"description": "Splits the ground into two crossing fissures at the densest cluster. Enemies in them are hit when they open, then slowed 40% for 3 seconds.",
	},
	"cataclysm": {
		"base": "quake",
		"kind": "final",
		"name": "Cataclysm",
		"model": "quake",
		"implemented": true,
		"description": "The pulse repeats every 0.9 seconds while enemies stay in range, each ring wider than the last (3 repeats at most). Stagger builds up on every hit, up to 1.5 seconds.",
	},
}

const STATS: Dictionary = {
	"(normal)": {
		"damage": 13.0,
		"fire_rate": 1.2,
		"range": 240.0,
		"rotation_speed": 0.0,
		"projectile_speed": 700.0,
		"pierce": 0,
	},
	"machine_gun": {
		"damage": 6.5,
		"fire_rate": 3.2,
		"range": 240.0,
		"rotation_speed": 0.0,
		"projectile_speed": 1000.0,
		"pierce": 0,
	},
	"cyclone_gatling": {
		"damage": 6.5,
		"fire_rate": 4.8,
		"range": 240.0,
		"rotation_speed": 0.0,
		"projectile_speed": 1000.0,
		"pierce": 1,
	},
	"omnifire": {
		"damage": 10.0,
		"fire_rate": 1.25,
		"range": 220.0,
		"rotation_speed": 0.0,
		"projectile_speed": 700.0,
		"pierce": 0,
	},
	"(melee)": {
		"damage": 8.0,
		"fire_rate": 0.0,
		"range": 120.0,
		"rotation_speed": 0.0,
		"rotation_rate": 360.0,
		"knockback_force": 80.0,
		"rehit_delay": 0.5,
	},
	"saber": {
		"damage": 11.0,
		"fire_rate": 0.0,
		"range": 145.0,
		"rotation_speed": 0.0,
		"rotation_rate": 420.0,
		"knockback_force": 80.0,
		"rehit_delay": 0.5,
	},
	"orbit_saber": {
		"damage": 14.0,
		"fire_rate": 0.0,
		"range": 170.0,
		"rotation_speed": 0.0,
		"rotation_rate": 480.0,
		"knockback_force": 80.0,
		"rehit_delay": 0.5,
	},
	"stormblade": {
		"damage": 12.0,
		"fire_rate": 0.0,
		"range": 170.0,
		"rotation_speed": 0.0,
		"rotation_rate": 360.0,
		"knockback_force": 80.0,
		"rehit_delay": 0.5,
	},
	"(bow)": {
		"damage": 18.0,
		"fire_rate": 0.9,
		"range": 340.0,
		"projectile_speed": 850.0,
		"pierce": 1,
	},
	"repeater_bow": {
		"damage": 12.0,
		"fire_rate": 0.9,
		"range": 340.0,
		"projectile_speed": 1050.0,
		"pierce": 1,
	},
	"arrowstorm": {
		"damage": 14.0,
		"fire_rate": 1.1,
		"range": 340.0,
		"projectile_speed": 1050.0,
		"pierce": 2,
	},
	"titan_bow": {
		"damage": 66.0,
		"fire_rate": 0.8,
		"range": 470.0,
		"projectile_speed": 1100.0,
		"pierce": 8,
		"knockback_force": 240.0,
	},
	"(flamethrower)": {
		"damage": 2.5,
		"fire_rate": 4.0,
		"range": 200.0,
		"burn_ratio": 1.6,
		"burn_duration": 2.0,
		"cone_degrees": 36.0,
	},
	"wide_flame": {
		"damage": 3.2,
		"fire_rate": 4.0,
		"range": 200.0,
		"burn_ratio": 1.6,
		"burn_duration": 2.2,
		"cone_degrees": 60.0,
	},
	"inferno_crown": {
		"damage": 5.0,
		"fire_rate": 4.0,
		"range": 200.0,
		"burn_ratio": 1.6,
		"burn_duration": 3.0,
		"cone_degrees": 110.0,
	},
	"dragonheart": {
		"damage": 5.0,
		"fire_rate": 4.0,
		"range": 380.0,
		"burn_ratio": 3.0,
		"burn_duration": 3.5,
		"cone_degrees": 16.0,
	},
	"(bowling)": {
		"damage": 20.0,
		"fire_rate": 0.6,
		"range": 320.0,
		"projectile_speed": 270.0,
		"pierce": 5,
		"knockback_force": 250.0,
	},
	"heavy_roller": {
		"damage": 30.0,
		"fire_rate": 0.6,
		"range": 320.0,
		"projectile_speed": 270.0,
		"pierce": 7,
		"knockback_force": 330.0,
	},
	"juggernaut": {
		"damage": 60.0,
		"fire_rate": 0.7,
		"range": 320.0,
		"projectile_speed": 270.0,
		"pierce": 14,
		"knockback_force": 520.0,
	},
	"ricochet_king": {
		"damage": 36.0,
		"fire_rate": 0.9,
		"range": 320.0,
		"projectile_speed": 400.0,
		"pierce": 0,
		"knockback_force": 250.0,
	},
	"(plasma)": {
		"damage": 10.0,
		"fire_rate": 1.0,
		"range": 255.0,
		"rotation_speed": 0.0,
		"projectile_speed": 550.0,
		"pierce": 0,
		"aoe_radius": 100.0,
		"knockback_force": 120.0,
		"targeting": "cluster",
	},
	"siege": {
		"damage": 42.0,
		"fire_rate": 0.45,
		"range": 330.0,
		"rotation_speed": 0.0,
		"projectile_speed": 350.0,
		"pierce": 0,
		"aoe_radius": 135.0,
		"knockback_force": 220.0,
		"targeting": "cluster",
	},
	"worldbreaker": {
		"damage": 80.0,
		"fire_rate": 0.55,
		"range": 330.0,
		"rotation_speed": 0.0,
		"projectile_speed": 350.0,
		"pierce": 0,
		"aoe_radius": 185.0,
		"knockback_force": 360.0,
		"targeting": "cluster",
	},
	"constellation": {
		"damage": 10.0,
		"fire_rate": 1.0,
		"range": 255.0,
		"rotation_speed": 0.0,
		"projectile_speed": 550.0,
		"pierce": 0,
		"aoe_radius": 100.0,
		"knockback_force": 120.0,
		"targeting": "cluster",
	},
	"(shock)": {
		"damage": 4.0,
		"fire_rate": 1.2,
		"range": 240.0,
		"rotation_speed": 0.0,
		"slow_intensity": 0.25,
		"slow_duration": 0.5,
	},
	"resonator": {
		"damage": 5.0,
		"fire_rate": 1.2,
		"range": 240.0,
		"rotation_speed": 0.0,
		"slow_intensity": 0.25,
		"slow_duration": 0.5,
	},
	"resonance_engine": {
		"damage": 5.0,
		"fire_rate": 1.2,
		"range": 276.0,
		"rotation_speed": 0.0,
		"slow_intensity": 0.25,
		"slow_duration": 0.5,
	},
	"thunder_spear": {
		"damage": 48.0,
		"fire_rate": 0.85,
		"range": 400.0,
		"rotation_speed": 0.0,
		"slow_intensity": 0.9,
		"slow_duration": 2.0,
	},
	"(tesla)": {
		"damage": 10.0,
		"fire_rate": 1.2,
		"range": 225.0,
		"rotation_speed": 0.0,
		"chain_count": 3,
		"chain_range": 225.0,
		"chain_decay": 0.7,
	},
	"forked_coil": {
		"damage": 10.0,
		"fire_rate": 1.2,
		"range": 225.0,
		"rotation_speed": 0.0,
		"chain_count": 3,
		"chain_range": 225.0,
		"chain_decay": 0.7,
	},
	"storm_network": {
		"damage": 10.0,
		"fire_rate": 1.2,
		"range": 225.0,
		"rotation_speed": 0.0,
		"chain_count": 3,
		"chain_range": 225.0,
		"chain_decay": 0.7,
	},
	"thunderhead": {
		"damage": 10.0,
		"fire_rate": 1.2,
		"range": 225.0,
		"rotation_speed": 0.0,
		"chain_count": 3,
		"chain_range": 225.0,
		"chain_decay": 0.7,
	},
	"(sniper)": {
		"damage": 40.0,
		"fire_rate": 0.35,
		"range": 700.0,
		"rotation_speed": 0.0,
		"pierce": 0,
	},
	"piercer_rifle": {
		"damage": 52.0,
		"fire_rate": 0.4,
		"range": 760.0,
		"rotation_speed": 0.0,
		"pierce": 2,
	},
	"horizon_piercer": {
		"damage": 70.0,
		"fire_rate": 0.45,
		"range": 820.0,
		"rotation_speed": 0.0,
		"pierce": 99,
	},
	"overwatch": {
		"damage": 56.0,
		"fire_rate": 0.42,
		"range": 780.0,
		"rotation_speed": 0.0,
		"pierce": 2,
	},
	"(quake)": {
		"damage": 16.0,
		"fire_rate": 0.45,
		"range": 260.0,
		"rotation_speed": 0.0,
		"knockback_force": 200.0,
		"stagger": 0.4,
	},
	"aftershock": {
		"damage": 18.0,
		"fire_rate": 0.45,
		"range": 270.0,
		"rotation_speed": 0.0,
		"knockback_force": 200.0,
		"stagger": 0.4,
	},
	"tectonic": {
		"damage": 40.0,
		"fire_rate": 0.5,
		"range": 400.0,
		"rotation_speed": 0.0,
		"knockback_force": 150.0,
		"stagger": 0.4,
	},
	"cataclysm": {
		"damage": 30.0,
		"fire_rate": 0.5,
		"range": 280.0,
		"rotation_speed": 0.0,
		"knockback_force": 220.0,
		"stagger": 1.0,
	},
}

const SHOTS: Dictionary = {
	"(normal)": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"machine_gun": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"cyclone_gatling": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"omnifire": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"(melee)": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"saber": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"orbit_saber": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"stormblade": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"(bow)": {"visual_key": "arrow", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"repeater_bow": {"visual_key": "arrow", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"arrowstorm": {"visual_key": "arrow", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"titan_bow": {"visual_key": "arrow", "visual_scale": 1.9, "radius": 0.1425, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"(flamethrower)": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"wide_flame": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"inferno_crown": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"dragonheart": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"(bowling)": {"visual_key": "bowling_ball", "visual_scale": 1.0, "radius": 0.24, "lifetime": 4.0, "ricochets": 0, "pierce": 0},
	"heavy_roller": {"visual_key": "bowling_ball", "visual_scale": 1.25, "radius": 0.3, "lifetime": 4.0, "ricochets": 0, "pierce": 0},
	"juggernaut": {"visual_key": "bowling_ball", "visual_scale": 1.75, "radius": 0.42, "lifetime": 4.0, "ricochets": 0, "pierce": 0},
	"ricochet_king": {"visual_key": "bowling_ball", "visual_scale": 1.0, "radius": 0.24, "lifetime": 6.0, "ricochets": 6, "pierce": 0},
	"(plasma)": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"siege": {"visual_key": "", "visual_scale": 1.0, "radius": 0.22, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"worldbreaker": {"visual_key": "", "visual_scale": 1.0, "radius": 0.34, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"constellation": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"(shock)": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"resonator": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"resonance_engine": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"thunder_spear": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"(tesla)": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"forked_coil": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"storm_network": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"thunderhead": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"(sniper)": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"piercer_rifle": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"horizon_piercer": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"overwatch": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"(quake)": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"aftershock": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"tectonic": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
	"cataclysm": {"visual_key": "", "visual_scale": 1.0, "radius": 0.075, "lifetime": 3.0, "ricochets": 0, "pierce": 0},
}

const BEHAVIOUR: Dictionary = {
	"(normal)": "",
	"machine_gun": "MachineGunForm",
	"cyclone_gatling": "MachineGunForm",
	"omnifire": "ScatterForm",
	"(melee)": "",
	"saber": "",
	"orbit_saber": "",
	"stormblade": "GunbladeForm",
	"(bow)": "",
	"repeater_bow": "RepeaterBowForm",
	"arrowstorm": "RepeaterBowForm",
	"titan_bow": "",
	"(flamethrower)": "",
	"wide_flame": "",
	"inferno_crown": "",
	"dragonheart": "",
	"(bowling)": "",
	"heavy_roller": "",
	"juggernaut": "",
	"ricochet_king": "",
	"(plasma)": "",
	"siege": "",
	"worldbreaker": "",
	"constellation": "",
	"(shock)": "",
	"resonator": "ResonatorForm",
	"resonance_engine": "ResonatorForm",
	"thunder_spear": "LanceForm",
	"(tesla)": "",
	"forked_coil": "",
	"storm_network": "",
	"thunderhead": "",
	"(sniper)": "",
	"piercer_rifle": "",
	"horizon_piercer": "",
	"overwatch": "OverwatchForm",
	"(quake)": "QuakeForm",
	"aftershock": "QuakeForm",
	"tectonic": "QuakeForm",
	"cataclysm": "QuakeForm",
}

const BUILDERS_BY_FORM: Dictionary = {
	"(normal)": [],
	"machine_gun": [],
	"cyclone_gatling": ["GatlingEvolutionVisual"],
	"omnifire": ["CrossfireEvolutionVisual"],
	"(melee)": [],
	"saber": [],
	"orbit_saber": [],
	"stormblade": ["GunbladeEvolutionVisual"],
	"(bow)": [],
	"repeater_bow": ["BowEvolutionVisual"],
	"arrowstorm": ["BowEvolutionVisual"],
	"titan_bow": ["BowEvolutionVisual"],
	"(flamethrower)": [],
	"wide_flame": ["FlameEvolutionVisual"],
	"inferno_crown": ["FlameEvolutionVisual"],
	"dragonheart": ["FlameEvolutionVisual"],
	"(bowling)": [],
	"heavy_roller": ["BowlingEvolutionVisual"],
	"juggernaut": ["BowlingEvolutionVisual"],
	"ricochet_king": ["BowlingEvolutionVisual"],
	"(plasma)": [],
	"siege": ["SiegeEvolutionVisual"],
	"worldbreaker": ["SiegeEvolutionVisual"],
	"constellation": [],
	"(shock)": [],
	"resonator": [],
	"resonance_engine": [],
	"thunder_spear": [],
	"(tesla)": [],
	"forked_coil": [],
	"storm_network": [],
	"thunderhead": [],
	"(sniper)": [],
	"piercer_rifle": ["SniperEvolutionVisual"],
	"horizon_piercer": ["SniperEvolutionVisual"],
	"overwatch": ["SniperEvolutionVisual"],
	"(quake)": [],
	"aftershock": ["QuakeEvolutionVisual"],
	"tectonic": ["QuakeEvolutionVisual"],
	"cataclysm": ["QuakeEvolutionVisual"],
}

const MODELS: Dictionary = {
	"(normal)": {
		"nodes": 16,
		"meshes": 12,
		"muzzle": "-0.112,0.276,-0.540",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "6be5a15378e46d18",
	},
	"machine_gun": {
		"nodes": 17,
		"meshes": 14,
		"muzzle": "0.000,0.320,-1.007",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "1d9d34e50eb0f05b",
	},
	"cyclone_gatling": {
		"nodes": 39,
		"meshes": 32,
		"muzzle": "0.000,0.524,-0.980",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "86c3a58d08c2058e",
	},
	"omnifire": {
		"nodes": 53,
		"meshes": 31,
		"muzzle": "0.000,0.044,-1.014",
		"gun_muzzles": 0,
		"crossfire_muzzles": 12,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "3d6fce2683682f4d",
	},
	"(melee)": {
		"nodes": 19,
		"meshes": 16,
		"muzzle": "0.000,0.420,-1.200",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "d357833b7fefe0a6",
	},
	"saber": {
		"nodes": 18,
		"meshes": 15,
		"muzzle": "-0.340,-0.265,-0.925",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "0d613b77a27aa673",
	},
	"orbit_saber": {
		"nodes": 30,
		"meshes": 25,
		"muzzle": "-0.340,-0.265,-0.925",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 3,
		"digest": "75f6186233c60899",
	},
	"stormblade": {
		"nodes": 37,
		"meshes": 29,
		"muzzle": "0.000,0.735,-1.026",
		"gun_muzzles": 3,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "3907810a08c06f6e",
	},
	"(bow)": {
		"nodes": 17,
		"meshes": 14,
		"muzzle": "0.000,0.220,-1.250",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 1,
		"saber_angles": 1,
		"digest": "2807d859ec6c5e16",
	},
	"repeater_bow": {
		"nodes": 23,
		"meshes": 19,
		"muzzle": "-0.130,0.220,-1.250",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 2,
		"saber_angles": 1,
		"digest": "a20615927f50b28d",
	},
	"arrowstorm": {
		"nodes": 41,
		"meshes": 34,
		"muzzle": "-0.520,0.220,-1.250",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 5,
		"saber_angles": 1,
		"digest": "689e3059893de75c",
	},
	"titan_bow": {
		"nodes": 26,
		"meshes": 22,
		"muzzle": "0.000,0.220,-1.250",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 1,
		"saber_angles": 1,
		"digest": "9e5460f901ff9c42",
	},
	"(flamethrower)": {
		"nodes": 18,
		"meshes": 15,
		"muzzle": "0.000,0.890,-0.847",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "dd84e5899f52bd4a",
	},
	"wide_flame": {
		"nodes": 32,
		"meshes": 24,
		"muzzle": "0.000,0.890,-0.847",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 2,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "6b298da15fc8b8e4",
	},
	"inferno_crown": {
		"nodes": 56,
		"meshes": 40,
		"muzzle": "0.000,0.890,-0.847",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 6,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "25c6f5fbe97ae23e",
	},
	"dragonheart": {
		"nodes": 26,
		"meshes": 22,
		"muzzle": "0.000,0.890,-1.590",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "d410eeed3d878a53",
	},
	"(bowling)": {
		"nodes": 15,
		"meshes": 12,
		"muzzle": "0.000,0.240,-1.500",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "f371470cad1b21df",
	},
	"heavy_roller": {
		"nodes": 22,
		"meshes": 18,
		"muzzle": "0.000,0.240,-1.500",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": true,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "32cceb61b5fb9aec",
	},
	"juggernaut": {
		"nodes": 34,
		"meshes": 30,
		"muzzle": "0.000,0.240,-1.500",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": true,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "d33a568fbea15d6f",
	},
	"ricochet_king": {
		"nodes": 32,
		"meshes": 26,
		"muzzle": "0.000,0.240,-1.500",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": true,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "5efdde25b8eb5dc5",
	},
	"(plasma)": {
		"nodes": 16,
		"meshes": 12,
		"muzzle": "0.000,0.367,-0.566",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "5b69b7f57a9cd5ba",
	},
	"siege": {
		"nodes": 15,
		"meshes": 10,
		"muzzle": "0.000,0.000,-1.070",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "c4dc0b5f2d2141d1",
	},
	"worldbreaker": {
		"nodes": 34,
		"meshes": 29,
		"muzzle": "0.000,0.000,-1.070",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "ae7492a66f49682e",
	},
	"constellation": {
		"nodes": 15,
		"meshes": 10,
		"muzzle": "0.000,0.235,-1.135",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "d2ebf9fc78abd08e",
	},
	"(shock)": {
		"nodes": 14,
		"meshes": 11,
		"muzzle": "0.000,1.010,0.000",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "f4adf0c9a1816e4a",
	},
	"resonator": {
		"nodes": 16,
		"meshes": 13,
		"muzzle": "0.000,0.400,0.000",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "8b0675ba74057806",
	},
	"resonance_engine": {
		"nodes": 35,
		"meshes": 31,
		"muzzle": "0.000,0.400,-0.585",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "e8568deee85f3d06",
	},
	"thunder_spear": {
		"nodes": 20,
		"meshes": 17,
		"muzzle": "0.000,0.300,-1.130",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "8a4c7d575754ad51",
	},
	"(tesla)": {
		"nodes": 17,
		"meshes": 13,
		"muzzle": "0.000,0.265,-0.585",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "afac70e55717303f",
	},
	"forked_coil": {
		"nodes": 17,
		"meshes": 13,
		"muzzle": "0.000,0.265,-0.585",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "afac70e55717303f",
	},
	"storm_network": {
		"nodes": 9,
		"meshes": 5,
		"muzzle": "0.000,1.407,-0.365",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "5f5293299beb5b92",
	},
	"thunderhead": {
		"nodes": 16,
		"meshes": 12,
		"muzzle": "0.000,0.870,-0.213",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "2288930d5507a57c",
	},
	"(sniper)": {
		"nodes": 17,
		"meshes": 13,
		"muzzle": "0.000,0.220,-0.860",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "8da8183364b5923a",
	},
	"piercer_rifle": {
		"nodes": 26,
		"meshes": 22,
		"muzzle": "0.000,0.220,-1.300",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "082b7358196a29a0",
	},
	"horizon_piercer": {
		"nodes": 30,
		"meshes": 26,
		"muzzle": "0.000,0.220,-1.680",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "014a41fdee7331d7",
	},
	"overwatch": {
		"nodes": 21,
		"meshes": 17,
		"muzzle": "0.000,0.220,-0.860",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "1ad33c0fb2ab60d7",
	},
	"(quake)": {
		"nodes": 12,
		"meshes": 9,
		"muzzle": "-0.500,0.950,-0.300",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "0688a3fb431a0a7e",
	},
	"aftershock": {
		"nodes": 19,
		"meshes": 16,
		"muzzle": "-0.500,0.950,-0.300",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "8b3dfce148edd750",
	},
	"tectonic": {
		"nodes": 20,
		"meshes": 17,
		"muzzle": "-0.500,0.950,-0.300",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "199dab148b6b8178",
	},
	"cataclysm": {
		"nodes": 27,
		"meshes": 24,
		"muzzle": "-0.500,0.950,-0.300",
		"gun_muzzles": 0,
		"crossfire_muzzles": 0,
		"flame_emitters": 0,
		"bowling_hardware": false,
		"bow_muzzles": 0,
		"saber_angles": 1,
		"digest": "9f075a8897ac1af3",
	},
}

const MISC: Dictionary = {
	"volley:repeater_bow": 2,
	"volley:arrowstorm": 5,
	"pierce_text:0": "none",
	"pierce_text:1": "1",
	"pierce_text:2": "2",
	"pierce_text:5": "5",
	"pierce_text:99": "whole line",
	"pierce_text:120": "whole line",
	"barrel:stormblade": {"damage": 9.0, "fire_rate": 2.4, "range": 300.0, "rotation_speed": 0.0, "projectile_speed": 700.0, "pierce": 1},
	"echo:resonator": [0.5],
	"echo:resonance_engine": [0.4, 0.8],
	"quake_pattern:": "Ring after a 0.5 s warning, running out at 8 m/s",
	"quake_pattern:aftershock": "Pulse, then a second pulse 0.6 s later at 50% damage",
	"quake_pattern:tectonic": "Two crossing fissures at the densest cluster, open for 3 s, slowing 40%",
	"quake_pattern:cataclysm": "Up to 3 wider repeats, 0.9 s apart, stagger stacks to 1.5 s",
	"quake_pattern:missing": "Ring after a 0.5 s warning, running out at 8 m/s",
	"ids": ["", "", "", ""],
	"implemented": ["machine_gun", "cyclone_gatling", "omnifire", "saber", "orbit_saber", "stormblade", "repeater_bow", "arrowstorm", "titan_bow", "wide_flame", "inferno_crown", "dragonheart", "heavy_roller", "juggernaut", "ricochet_king", "siege", "worldbreaker", "resonator", "resonance_engine", "thunder_spear", "piercer_rifle", "horizon_piercer", "overwatch", "aftershock", "tectonic", "cataclysm"],
	"order": [["machine_gun", "cyclone_gatling", "omnifire"], ["saber", "orbit_saber", "stormblade"], ["repeater_bow", "arrowstorm", "titan_bow"], ["wide_flame", "inferno_crown", "dragonheart"], ["heavy_roller", "juggernaut", "ricochet_king"], ["siege", "worldbreaker", "constellation"], ["resonator", "resonance_engine", "thunder_spear"], ["forked_coil", "storm_network", "thunderhead"], ["piercer_rifle", "horizon_piercer", "overwatch"], ["aftershock", "tectonic", "cataclysm"]],
}

# --- Lookups (adapt these when a signature changes; never the expected values) ---

func _forms_of(base: String) -> Array[String]:
	var result: Array[String] = []
	result.append_array(TurretEvolution.options(base, 0))
	result.append_array(TurretEvolution.options(base, 1))
	return result

func _implemented_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(TurretEvolution.IMPLEMENTED)
	return result

func _stats(base: String, form: String) -> Dictionary:
	return TurretEvolution.base_stats(base, form)

func _shape(shot: CombatShot3D, base: String, form: String) -> void:
	TurretEvolution.shape_shot(shot, base, form)

func _volley(form: String) -> int:
	return TurretEvolution.volley_size(TurretEvolution.legacy_stage(form)) if form in ["repeater_bow", "arrowstorm"] else 0

func _barrel(form: String) -> Dictionary:
	return TurretEvolution.gunblade_barrel_stats(TurretEvolution.legacy_stage(form)) if form == "stormblade" else {}

func _echo_delays(form: String) -> Array:
	return TurretEvolution.RESONATOR_ECHO_DELAYS[TurretEvolution.legacy_stage(form) - 1] if form in ["resonator", "resonance_engine"] else []

func _run_builder(builder: String, model: Node3D, base: String, form: String) -> void:
	var stage := TurretEvolution.legacy_stage(form)
	match builder:
		"BowEvolutionVisual": BowEvolutionVisual.build(model, form, stage)
		"FlameEvolutionVisual": FlameEvolutionVisual.build(model, form, stage)
		"BowlingEvolutionVisual": BowlingEvolutionVisual.build(model, form, stage)
		"GunbladeEvolutionVisual": GunbladeEvolutionVisual.build(model, form, stage)
		"SiegeEvolutionVisual": SiegeEvolutionVisual.build(model, form, stage)
		"SniperEvolutionVisual": SniperEvolutionVisual.build(model, form, stage)
		"QuakeEvolutionVisual": QuakeEvolutionVisual.build(model, base, form)
		"GatlingEvolutionVisual": GatlingEvolutionVisual.build(model, form, stage)
		"CrossfireEvolutionVisual": CrossfireEvolutionVisual.build(model, form, stage)

## The behaviour class the actor resolved for its form, "" for none.
func _behaviour_of(actor: TurretActor) -> String:
	return "" if actor.form == null else str(actor.form.get_script().get_global_name())

# --- Collectors ---

func collect_all(host: Node) -> Dictionary:
	var result := {"forms": {}, "stats": {}, "shots": {}, "behaviour": {}, "builders": {}, "models": {}, "misc": {}}
	var implemented := _implemented_ids()
	for base in BASES:
		var ids: Array[String] = [""]
		ids.append_array(_forms_of(base))
		for form in ids:
			var key := form if not form.is_empty() else "(%s)" % base
			if not form.is_empty():
				result.forms[form] = {
					"base": base,
					"kind": "upgrade" if form in TurretEvolution.options(base, 0) else "final",
					"name": TurretEvolution.form_name(form),
					"model": TurretEvolution.model_key(form),
					"implemented": form in implemented,
					"description": TurretEvolution.description(form),
				}
			result.stats[key] = _stats(base, form)
			var shot := CombatShot3D.new()
			_shape(shot, base, form)
			result.shots[key] = {"visual_key": shot.visual_key, "visual_scale": shot.visual_scale, "radius": shot.radius,
				"lifetime": shot.lifetime, "ricochets": shot.ricochets, "pierce": shot.pierce}
			var actor := TurretActor.new()
			actor.turret_type = base
			actor.progression.evolution_form = form
			host.add_child(actor)
			result.behaviour[key] = _behaviour_of(actor)
			result.models[key] = _model_record(actor)
			host.remove_child(actor)
			actor.free()
			result.builders[key] = _acting_builders(host, base, form)
	for form in ["repeater_bow", "arrowstorm"]:
		result.misc["volley:" + form] = _volley(form)
	for pierce in [0, 1, 2, 5, 99, 120]:
		result.misc["pierce_text:%d" % pierce] = TurretEvolution.pierce_text(pierce)
	result.misc["barrel:stormblade"] = _barrel("stormblade")
	for form in ["resonator", "resonance_engine"]:
		result.misc["echo:" + form] = _echo_delays(form)
	for form in ["", "aftershock", "tectonic", "cataclysm", "missing"]:
		result.misc["quake_pattern:" + form] = TurretEvolution.quake_pattern_text(form)
	result.misc["ids"] = [TurretEvolution.form_name(""), TurretEvolution.form_name("missing"), TurretEvolution.model_key(""), TurretEvolution.description("missing")]
	result.misc["implemented"] = implemented
	result.misc["order"] = BASES.map(func(base: String) -> Array: return _forms_of(base))
	return result

## Runs every builder on its own fresh model (in the tree, as the actor does) and lists those that change it.
func _acting_builders(host: Node, base: String, form: String) -> Array:
	var acting: Array = []
	for builder in BUILDERS:
		var model := _fresh_model(base, form)
		host.add_child(model)
		var before := _signature(model)
		_run_builder(builder, model, base, form)
		if _signature(model) != before:
			acting.append(builder)
		host.remove_child(model)
		model.free()
	return acting

func _fresh_model(base: String, form: String) -> Node3D:
	var key := TurretEvolution.model_key(form)
	if key.is_empty():
		key = str(TurretRegistry.get_type(base).get("model_key", ""))
	if key.is_empty():
		key = "ion" if base == "normal" else base
	if ClockworkModels.available(key):
		return ClockworkModels.instantiate(key)
	return load(TurretRegistry.get_model_path(base)).instantiate() as Node3D

func _model_record(actor: TurretActor) -> Dictionary:
	var nodes := 0
	var meshes := 0
	var stack: Array[Node] = [actor.model]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		nodes += 1
		if node is MeshInstance3D:
			meshes += 1
		stack.append_array(node.get_children())
	var at := actor.muzzle.position
	return {
		"nodes": nodes, "meshes": meshes,
		"muzzle": "%.3f,%.3f,%.3f" % [at.x, at.y, at.z],
		"gun_muzzles": actor.gun_muzzles.size(), "crossfire_muzzles": actor.crossfire_muzzles.size(),
		"flame_emitters": actor.flame_emitters.size(), "bowling_hardware": actor.bowling_hardware != null,
		"bow_muzzles": actor.bow_muzzles.size(), "saber_angles": actor.saber_angles.size(),
		"digest": _signature(actor.model).sha256_text().substr(0, 16),
	}

## Every node's depth, class, name, transform, mesh size and material, in tree order.
func _signature(root: Node) -> String:
	var lines := PackedStringArray()
	_sign(root, 0, lines)
	return "\n".join(lines)

func _sign(node: Node, depth: int, lines: PackedStringArray) -> void:
	var label := String(node.name)
	if label.begins_with("@"):
		label = "?"
	var line := "%d|%s|%s" % [depth, node.get_class(), label]
	if node is Node3D:
		var n3 := node as Node3D
		line += "|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f" % [n3.position.x, n3.position.y, n3.position.z,
			n3.rotation.x, n3.rotation.y, n3.rotation.z, n3.scale.x, n3.scale.y, n3.scale.z]
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh:
			var size := mesh.get_aabb().size
			line += "|%s|%.3f,%.3f,%.3f" % [mesh.get_class(), size.x, size.y, size.z]
		var material := (node as MeshInstance3D).material_override as StandardMaterial3D
		if material:
			line += "|%s|%.2f|%.2f|%s|%.2f" % [material.albedo_color.to_html(), material.metallic, material.roughness, material.emission_enabled, material.emission_energy_multiplier]
	lines.append(line)
	for child in node.get_children():
		_sign(child, depth + 1, lines)

# --- Comparison ---

func _assert_same(actual: Variant, expected: Variant, label: String) -> void:
	if actual is Dictionary and expected is Dictionary:
		for key in expected:
			if not actual.has(key):
				fail_test("%s: missing key %s" % [label, key])
			else:
				_assert_same(actual[key], expected[key], "%s.%s" % [label, key])
		for key in actual:
			if not expected.has(key):
				fail_test("%s: unexpected key %s = %s" % [label, key, actual[key]])
	elif typeof(actual) != typeof(expected) or actual != expected:
		fail_test("%s: expected %s (%s) but got %s (%s)" % [label, expected, type_string(typeof(expected)), actual, type_string(typeof(actual))])
	else:
		pass_test("%s matches" % label)

var _recorded: Dictionary = {}

func before_all() -> void:
	TestHelpers.reset_all_services()
	_recorded = collect_all(self)

func _assert_section(section: String, expected: Dictionary) -> void:
	var actual: Dictionary = _recorded[section]
	for key in expected:
		if not actual.has(key):
			fail_test("%s: %s is no longer recorded" % [section, key])
		else:
			_assert_same(actual[key], expected[key], "%s[%s]" % [section, key])
	for key in actual:
		if not expected.has(key):
			fail_test("%s: %s is new and has no golden entry" % [section, key])

# --- Tests ---

func test_every_form_keeps_its_name_model_kind_and_description() -> void:
	_assert_section("forms", FORMS)

func test_every_form_keeps_its_full_base_stats() -> void:
	_assert_section("stats", STATS)

func test_every_form_keeps_its_shot_shape() -> void:
	_assert_section("shots", SHOTS)

func test_every_form_keeps_its_behaviour_class() -> void:
	_assert_section("behaviour", BEHAVIOUR)

func test_every_form_keeps_its_visual_builders() -> void:
	_assert_section("builders", BUILDERS_BY_FORM)

func test_every_form_keeps_its_built_model() -> void:
	_assert_section("models", MODELS)

func test_per_form_lookups_keep_their_values() -> void:
	_assert_section("misc", MISC)

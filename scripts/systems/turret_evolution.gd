class_name TurretEvolution
extends RefCounted

## Run-local forms. Every base turret has one level-5 upgrade (no choice) and two level-10 finals (pick one).
## IDs name forms; `model` selects a reusable authored chassis. Ownership always remains with the original base type.
const PATHS: Dictionary = {
	"normal": {"upgrade": "machine_gun", "finals": ["cyclone_gatling", "omnifire"]},
	"melee": {"upgrade": "saber", "finals": ["orbit_saber", "stormblade"]},
	"bow": {"upgrade": "repeater_bow", "finals": ["arrowstorm", "titan_bow"]},
	"flamethrower": {"upgrade": "wide_flame", "finals": ["inferno_crown", "dragonheart"]},
	"bowling": {"upgrade": "heavy_roller", "finals": ["juggernaut", "ricochet_king"]},
	"plasma": {"upgrade": "siege", "finals": ["worldbreaker", "constellation"]},
	"shock": {"upgrade": "resonator", "finals": ["resonance_engine", "thunder_spear"]},
	"tesla": {"upgrade": "forked_coil", "finals": ["storm_network", "thunderhead"]},
	"sniper": {"upgrade": "piercer_rifle", "finals": ["horizon_piercer", "overwatch"]},
	"quake": {"upgrade": "aftershock", "finals": ["tectonic", "cataclysm"]},
}

## Name and authored chassis per form. Whether a form is the level-5 upgrade or a level-10 final is stated once, in `PATHS`.
const FORMS: Dictionary = {
	"machine_gun": {"name": "Machine Gun", "model": "machine_gun"},
	"cyclone_gatling": {"name": "Cyclone Gatling", "model": "gatling"},
	"omnifire": {"name": "Omnifire", "model": "crossfire"},
	"saber": {"name": "Saber", "model": "saber"},
	"orbit_saber": {"name": "Orbit Saber", "model": "saber"},
	"stormblade": {"name": "Stormblade", "model": "gunblade"},
	"repeater_bow": {"name": "Repeater Bow", "model": "bow"},
	"arrowstorm": {"name": "Arrowstorm", "model": "bow"},
	"titan_bow": {"name": "Titan Bow", "model": "bow"},
	"wide_flame": {"name": "Wide Flame", "model": "flamethrower"},
	"inferno_crown": {"name": "Inferno Crown", "model": "flamethrower"},
	"dragonheart": {"name": "Dragonheart", "model": "flamethrower"},
	"heavy_roller": {"name": "Heavy Roller", "model": "bowling"},
	"juggernaut": {"name": "Juggernaut", "model": "bowling"},
	"ricochet_king": {"name": "Ricochet King", "model": "bowling"},
	"siege": {"name": "Siege Cannon", "model": "siege"},
	"worldbreaker": {"name": "Worldbreaker", "model": "siege"},
	"constellation": {"name": "Constellation", "model": "siege"},
	"resonator": {"name": "Resonator", "model": "resonator"},
	"resonance_engine": {"name": "Resonance Engine", "model": "resonance_engine"},
	"thunder_spear": {"name": "Thunder Spear", "model": "thunder_spear"},
	"forked_coil": {"name": "Forked Coil", "model": "tesla"},
	"storm_network": {"name": "Storm Network", "model": "storm_network"},
	"thunderhead": {"name": "Thunderhead", "model": "thunderhead"},
	# All three Sniper forms share the cp_sniper chassis; `SniperEvolutionVisual` adds the per-form hardware.
	"piercer_rifle": {"name": "Piercer Rifle", "model": "sniper"},
	"horizon_piercer": {"name": "Horizon Piercer", "model": "sniper"},
	"overwatch": {"name": "Overwatch", "model": "sniper"},
	# Every Quake form shares the cp_quake chassis (cube on a stone slab); `QuakeEvolutionVisual` adds the per-form hardware.
	"aftershock": {"name": "Aftershock", "model": "quake"},
	"tectonic": {"name": "Tectonic", "model": "quake"},
	"cataclysm": {"name": "Cataclysm", "model": "quake"},
}

## Forms offered at `stage` (evolutions already taken): the upgrade at 0, the two finals at 1, nothing after.
static func options(base_type: String, stage: int) -> Array[String]:
	var result: Array[String] = []
	var path: Dictionary = PATHS.get(base_type, {})
	if stage == 0 and path.has("upgrade"):
		result.append(str(path["upgrade"]))
	elif stage == 1:
		result.assign(path.get("finals", []))
	return result

static func form_name(form_id: String) -> String:
	return str(FORMS.get(form_id, {}).get("name", ""))

## The authored chassis for a form; empty for no form (callers fall back to the base turret's model).
static func model_key(form_id: String) -> String:
	return str(FORMS.get(form_id, {}).get("model", ""))

## Shape the attack before item modifiers so flat bonuses remain meaningful.
static func base_stats(base_type: String, form_id: String) -> Dictionary:
	var stats := TurretRegistry.get_base_stats(base_type)
	match form_id:
		"machine_gun":
			stats.damage = 6.5
			stats.fire_rate = 3.2
			stats.projectile_speed = 1000.0
			stats.pierce = 0
		"cyclone_gatling":
			stats.damage = 6.5
			stats.fire_rate = 4.8
			stats.projectile_speed = 1000.0
			stats.pierce = 1
		"omnifire":
			stats.damage = 10.0
			stats.fire_rate = 1.25
			stats.range = 220.0
		"siege":
			stats.damage = 42.0
			stats.fire_rate = .45
			stats.range = 330.0
			stats.projectile_speed = 350.0
			stats.aoe_radius = 135.0
			stats.knockback_force = 220.0
		"worldbreaker":
			stats.damage = 80.0
			stats.fire_rate = .55
			stats.range = 330.0
			stats.projectile_speed = 350.0
			stats.aoe_radius = 185.0
			stats.knockback_force = 360.0
		"heavy_roller":
			stats.damage = 30.0
			stats.pierce = 7
			stats.knockback_force = 330.0
			stats.fire_rate = .6
		"juggernaut":
			stats.damage = 60.0
			stats.pierce = 14
			stats.knockback_force = 520.0
			stats.fire_rate = .7
		"ricochet_king":
			stats.damage = 36.0
			stats.fire_rate = .9
			stats.projectile_speed = 400.0
			stats.pierce = 0
		"wide_flame":
			stats.damage = 3.2
			stats.cone_degrees = 60.0
			stats.burn_duration = 2.2
		"inferno_crown":
			stats.damage = 5.0
			stats.cone_degrees = 110.0
			stats.burn_duration = 3.0
		"dragonheart":
			stats.damage = 5.0
			stats.range = 380.0
			stats.cone_degrees = 16.0
			stats.burn_ratio = 3.0
			stats.burn_duration = 3.5
		"repeater_bow":
			stats.damage = 12.0
			stats.fire_rate = .9
			stats.projectile_speed = 1050.0
			stats.pierce = 1
		"arrowstorm":
			stats.damage = 14.0
			stats.fire_rate = 1.1
			stats.projectile_speed = 1050.0
			stats.pierce = 2
		"titan_bow":
			stats.damage = 66.0
			stats.fire_rate = .8
			stats.range = 470.0
			stats.projectile_speed = 1100.0
			stats.pierce = 8
			stats.knockback_force = 240.0
		"stormblade":
			stats.damage = 12.0
			stats.rotation_rate = 360.0
			stats.range = 170.0
		"resonator":
			stats.damage = 5.0
			stats.range = 240.0
		"resonance_engine":
			stats.damage = 5.0
			stats.range = 276.0
		"thunder_spear":
			stats.damage = 48.0
			stats.fire_rate = .85
			stats.range = 400.0
			stats.slow_intensity = .9
			stats.slow_duration = 2.0
		"saber":
			stats.damage = 11.0
			stats.rotation_rate = 420.0
			stats.range = 145.0
		"orbit_saber":
			stats.damage = 14.0
			stats.rotation_rate = 480.0
			stats.range = 170.0
		# Sniper line: single-target DPS (before level and item bonuses) is 14 base, 20.8 Piercer Rifle, 31.5 Horizon Piercer,
		# 23.5 Overwatch. Overwatch's own shots land on a Marked target, so against its first target it deals 1.25 times that.
		"piercer_rifle":
			stats.damage = 52.0
			stats.fire_rate = .40
			stats.range = 760.0
			stats.pierce = SNIPER_PIERCER_PIERCE
		"horizon_piercer":
			stats.damage = 70.0
			stats.fire_rate = .45
			stats.range = 820.0
			stats.pierce = SNIPER_UNLIMITED_PIERCE
		"overwatch":
			stats.damage = 56.0
			stats.fire_rate = .42
			stats.range = 780.0
			stats.pierce = SNIPER_PIERCER_PIERCE
		# Quake line, per enemy struck and before level and item bonuses. A pulse's damage is dealt once to every enemy in the
		# ring. Per-cycle damage (a cycle runs from one trigger to the next, rate 0.45 means 2.22 s): base 16 x 1 = 16 at
		# 0.45/s = 7.2 DPS; Aftershock 18 + 9 = 27 (12.2 DPS); Cataclysm 4 pulses of 30 = 120 per 3.2 s salvo plus a 2 s
		# recharge (23 DPS, measured about 1.5x Aftershock in a cluster the rings reach). Tectonic hits what stands in its X (see
		# `TECTONIC_*`), tuned to about 1.4x Aftershock on a cluster and more on a single target; its value is the 3 s rift.
		"aftershock":
			stats.damage = 18.0
			stats.fire_rate = .45
			stats.range = 270.0
			stats.knockback_force = 200.0
		"tectonic":
			stats.damage = 40.0
			stats.fire_rate = .5
			stats.range = 400.0
			stats.knockback_force = 150.0
		"cataclysm":
			stats.damage = 30.0
			stats.fire_rate = .5
			stats.range = 280.0
			stats.knockback_force = 220.0
			# Longer than the 0.9 s gap between repeats, so each pulse lands on an enemy that is still down and the stack builds.
			stats.stagger = CATACLYSM_STAGGER
	return stats

## Forms with both a working attack and authored art in this build. Tesla's forms and Constellation are registered but not built yet.
const IMPLEMENTED: Array[String] = ["machine_gun", "cyclone_gatling", "omnifire", "saber", "orbit_saber", "stormblade", "repeater_bow", "arrowstorm", "titan_bow", "wide_flame", "inferno_crown", "dragonheart", "heavy_roller", "juggernaut", "ricochet_king", "siege", "worldbreaker", "resonator", "resonance_engine", "thunder_spear", "piercer_rifle", "horizon_piercer", "overwatch", "aftershock", "tectonic", "cataclysm"]

## Delays in seconds of the Resonator's single echo and the Resonance Engine's two; each echo deals this fraction of the pulse.
const RESONATOR_ECHO_DELAYS: Array[float] = [.5]
const ENGINE_ECHO_DELAYS: Array[float] = [.4, .8]
const RESONATOR_ECHO_DAMAGE: float = .5
## Resonance Engine: inner pulse (half radius, double damage) and outer pulse (wider) alternate.
const ENGINE_INNER_RADIUS: float = .5
const ENGINE_INNER_DAMAGE: float = 2.0
const ENGINE_OUTER_RADIUS: float = 1.3
## An enemy struck by both pulse kinds within this window becomes Exposed.
const ENGINE_EXPOSE_WINDOW: float = 1.2
const ENGINE_EXPOSE_DURATION: float = 2.0

## Half-width in metres of the Thunder Spear's piercing lane.
const LANCE_LANE_HALF_WIDTH: float = .6

## Rounds in one Stormblade burst (the first leaves at once, the rest follow from the other barrels), and held blades on the Orbit Saber.
const STORMBLADE_BURST_SHOTS: int = 3
const ORBIT_SABER_BLADES: int = 3

## Sniper: half-width in metres of the lane a piercing shot travels along (each body's own radius is added), how many
## enemies behind the target the Piercer Rifle line reaches, and the pierce value that means "the whole line".
const SNIPER_LANE_HALF_WIDTH: float = .45
const SNIPER_PIERCER_PIERCE: int = 2
const SNIPER_UNLIMITED_PIERCE: int = 99
## Overwatch marks this many of the toughest enemies in range for this many seconds on every shot.
const OVERWATCH_MARK_COUNT: int = 3
const OVERWATCH_MARK_SECONDS: float = 6.0

## Quake line. Every pulse starts as a ground telegraph, then a ring runs out from the turret at `QUAKE_RING_SPEED`.
const QUAKE_TELEGRAPH_SECONDS: float = .5
const QUAKE_RING_SPEED: float = 8.0
## Aftershock: a second pulse this long after the first releases, at this share of its damage, same radius.
const AFTERSHOCK_DELAY: float = .6
const AFTERSHOCK_DAMAGE: float = .5
## Cataclysm: up to this many repeats of the pulse, this far apart, each ring this much wider than the one before it up to
## a cap (1, 1.2, 1.4, 1.6 times the radius); a repeat only happens while an enemy is in range. Stagger stacks on every hit
## up to `StatusEffects3D.STAGGER_CAP`.
const CATACLYSM_REPEATS: int = 3
const CATACLYSM_INTERVAL: float = .9
const CATACLYSM_GROWTH: float = .2
const CATACLYSM_MAX_RADIUS_SCALE: float = 1.6
const CATACLYSM_STAGGER: float = 1.0
## Tectonic: two fissures cross in an X at the densest cluster, each `TECTONIC_ANGLE` either side of the line from the
## turret. A fissure's half length is `TECTONIC_REACH` of the turret's reach and its half width is metres (both grow with the
## area bonus). Enemies in it are hit once when it opens; it stays `TECTONIC_SECONDS` and slows them `TECTONIC_SLOW` while
## they stand in it. The cluster is the enemy with the most neighbours within `TECTONIC_CLUSTER_RADIUS` metres.
const TECTONIC_ANGLE: float = PI / 4.0
const TECTONIC_REACH: float = .65
const TECTONIC_HALF_WIDTH: float = .45
const TECTONIC_SECONDS: float = 3.0
const TECTONIC_SLOW: float = .4
const TECTONIC_CLUSTER_RADIUS: float = 1.5

## One line on what a Quake form does per trigger, for the preview and the inspector.
static func quake_pattern_text(form_id: String) -> String:
	match form_id:
		"aftershock": return "Pulse, then a second pulse %.1f s later at %d%% damage" % [AFTERSHOCK_DELAY, roundi(AFTERSHOCK_DAMAGE * 100.0)]
		"tectonic": return "Two crossing fissures at the densest cluster, open for %.0f s, slowing %d%%" % [TECTONIC_SECONDS, roundi(TECTONIC_SLOW * 100.0)]
		"cataclysm": return "Up to %d wider repeats, %.1f s apart, stagger stacks to %.1f s" % [CATACLYSM_REPEATS, CATACLYSM_INTERVAL, StatusEffects3D.STAGGER_CAP]
	return "Ring after a %.1f s warning, running out at %.0f m/s" % [QUAKE_TELEGRAPH_SECONDS, QUAKE_RING_SPEED]

## "none", a count of extra enemies, or "whole line" for the Horizon Piercer, for stat readouts.
static func pierce_text(pierce: int) -> String:
	if pierce <= 0:
		return "none"
	return "whole line" if pierce >= SNIPER_UNLIMITED_PIERCE else str(pierce)

## Arrows loosed per volley: the Repeater Bow and Arrowstorm queue several, every other form one.
static func volley_size(form_id: String) -> int:
	match form_id:
		"repeater_bow": return 2
		"arrowstorm": return 5
	return 1

## Scale of the ball (and of the cradle that throws it) on the two roller forms; 1 for every other form.
const BALL_SCALES: Dictionary = {"heavy_roller": 1.25, "juggernaut": 1.75}

static func ball_scale(form_id: String) -> float:
	return float(BALL_SCALES.get(form_id, 1.0))

## Held blades sweeping around the turret: the Orbit Saber carries several, every other form one.
static func blade_count(form_id: String) -> int:
	return ORBIT_SABER_BLADES if form_id == "orbit_saber" else 1

## Per-form shot shape (visual, size, bounces), applied after the shot is built from stats.
static func shape_shot(shot: CombatShot3D, base_type: String, form_id: String) -> void:
	if base_type == "bow":
		shot.visual_key = "arrow"
		if form_id == "titan_bow":
			shot.visual_scale = 1.9
			shot.radius *= shot.visual_scale
	elif base_type == "bowling":
		shot.visual_key = "bowling_ball"
		shot.radius = .24
		shot.lifetime = 4.0
		if form_id in BALL_SCALES:
			shot.visual_scale = ball_scale(form_id)
			shot.radius *= shot.visual_scale
		elif form_id == "ricochet_king":
			shot.ricochets = 6
			shot.lifetime = 6.0
	if form_id == "siege":
		shot.radius = .22
	elif form_id == "worldbreaker":
		shot.radius = .34

## The Stormblade's rotating barrel fires these stats rather than the blade's.
static func gunblade_barrel_stats() -> Dictionary:
	var stats := TurretRegistry.get_base_stats("normal")
	stats.damage = 9.0
	stats.fire_rate = 2.4
	stats.range = 300.0
	stats.pierce = 1
	return stats

static func description(form_id: String) -> String:
	match form_id:
		"machine_gun": return "Rapid aimed fire."
		"cyclone_gatling": return "Piercing rotary fire accelerates to 2.5 times its resting rate."
		"omnifire": return "Twelve shots cover a full circle in evenly spaced directions."
		"heavy_roller", "juggernaut": return "Larger balls drive through crowds with stronger knockback."
		"ricochet_king": return "Redirects toward a fresh nearby enemy up to 6 times."
		"wide_flame": return "A 60-degree fan blankets a crowd and leaves enemies burning."
		"inferno_crown": return "A 110-degree fan blankets a crowd and leaves enemies burning."
		"dragonheart": return "A longer, narrower jet delivers a stronger, longer-lasting burn."
		"repeater_bow": return "Fires a quick burst of 2 piercing arrows."
		"arrowstorm": return "Fires a quick burst of 5 piercing arrows."
		"titan_bow": return "Heavy arrows pierce 9 enemies and knock them back."
		"stormblade": return "Three-shot piercing bursts accompany a longer, faster blade sweep."
		"saber": return "A longer, faster energy-blade sweep."
		"orbit_saber": return "Three held energy blades sweep evenly around the turret."
		"resonator": return "Each pulse echoes once half a second later at half damage, refreshing the slow."
		"resonance_engine": return "Pulses alternate a tight, hard inner ring and a wide outer ring; enemies caught by both are Exposed, taking 30% more from Instant turrets."
		"thunder_spear": return "The bolt drives through a whole lane of enemies and pins every one."
		"siege", "worldbreaker": return "Slow, heavy shells explode over a large area and push enemies back."
		"piercer_rifle": return "A longer barrel and heavier rounds. The shot passes through two enemies behind its target."
		"horizon_piercer": return "The shot runs the whole line to full range and strikes every enemy on it. Aim the toughest enemy through the crowd."
		"overwatch": return "Keeps the Piercer shot and marks the three toughest enemies in range for 6 seconds. Marked enemies take 25% more damage from every turret, and the mark jumps to the next toughest enemy when one dies."
		"aftershock": return "A second pulse follows 0.6 seconds after the first at half damage and the same radius."
		"tectonic": return "Splits the ground into two crossing fissures at the densest cluster. Enemies in them are hit when they open, then slowed 40% for 3 seconds."
		"cataclysm": return "The pulse repeats every 0.9 seconds while enemies stay in range, each ring wider than the last (3 repeats at most). Stagger builds up on every hit, up to 1.5 seconds."
	return ""

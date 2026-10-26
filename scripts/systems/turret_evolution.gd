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
}

## `tier` is 1 for a level-5 upgrade and 3 for a level-10 final (see `legacy_stage`).
const FORMS: Dictionary = {
	"machine_gun": {"name": "Machine Gun", "model": "machine_gun", "tier": 1},
	"cyclone_gatling": {"name": "Cyclone Gatling", "model": "gatling", "tier": 3},
	"omnifire": {"name": "Omnifire", "model": "crossfire", "tier": 3},
	"saber": {"name": "Saber", "model": "saber", "tier": 1},
	"orbit_saber": {"name": "Orbit Saber", "model": "saber", "tier": 3},
	"stormblade": {"name": "Stormblade", "model": "gunblade", "tier": 3},
	"repeater_bow": {"name": "Repeater Bow", "model": "bow", "tier": 1},
	"arrowstorm": {"name": "Arrowstorm", "model": "bow", "tier": 3},
	"titan_bow": {"name": "Titan Bow", "model": "bow", "tier": 3},
	"wide_flame": {"name": "Wide Flame", "model": "flamethrower", "tier": 1},
	"inferno_crown": {"name": "Inferno Crown", "model": "flamethrower", "tier": 3},
	"dragonheart": {"name": "Dragonheart", "model": "flamethrower", "tier": 3},
	"heavy_roller": {"name": "Heavy Roller", "model": "bowling", "tier": 1},
	"juggernaut": {"name": "Juggernaut", "model": "bowling", "tier": 3},
	"ricochet_king": {"name": "Ricochet King", "model": "bowling", "tier": 3},
	"siege": {"name": "Siege Cannon", "model": "siege", "tier": 1},
	"worldbreaker": {"name": "Worldbreaker", "model": "siege", "tier": 3},
	"constellation": {"name": "Constellation", "model": "siege", "tier": 3},
	"resonator": {"name": "Resonator", "model": "resonator", "tier": 1},
	"resonance_engine": {"name": "Resonance Engine", "model": "resonance_engine", "tier": 3},
	"thunder_spear": {"name": "Thunder Spear", "model": "thunder_spear", "tier": 3},
	"forked_coil": {"name": "Forked Coil", "model": "tesla", "tier": 1},
	"storm_network": {"name": "Storm Network", "model": "storm_network", "tier": 3},
	"thunderhead": {"name": "Thunderhead", "model": "thunderhead", "tier": 3},
	# No Sniper chassis exists yet: all three stages use the Ion chassis, and a runtime rifle attachment tells them apart.
	"piercer_rifle": {"name": "Piercer Rifle", "model": "ion", "tier": 1},
	"horizon_piercer": {"name": "Horizon Piercer", "model": "ion", "tier": 3},
	"overwatch": {"name": "Overwatch", "model": "ion", "tier": 3},
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

## Transitional shim: the stage a form was authored as (1 for an upgrade, 3 for a final, 0 for no form).
## Per-form arrays, `*EvolutionVisual.build(model, form, stage)` and `volley_size` still index by it, so an
## upgrade behaves and renders as the old stage 1 and a final as the old stage 3. Removed once those are flattened.
static func legacy_stage(form_id: String) -> int:
	return int(FORMS.get(form_id, {}).get("tier", 0))

## Shape the attack before item modifiers so flat bonuses remain meaningful.
static func base_stats(base_type: String, form_id: String) -> Dictionary:
	var stats := TurretRegistry.get_base_stats(base_type)
	var stage := legacy_stage(form_id)
	if stage <= 0:
		return stats
	match form_id:
		"machine_gun", "cyclone_gatling":
			stats.damage = [6.5, 5.5, 6.5][stage - 1]
			stats.fire_rate = [3.2, 4.0, 4.8][stage - 1]
			stats.projectile_speed = 1000.0
			stats.pierce = 1 if stage >= 3 else 0
		"omnifire":
			stats.damage = [8.0, 9.0, 10.0][stage - 1]
			stats.fire_rate = [1.0, 1.15, 1.25][stage - 1]
			stats.range = 220.0
		"siege", "worldbreaker":
			stats.damage = [42.0, 58.0, 80.0][stage - 1]
			stats.fire_rate = [.45, .5, .55][stage - 1]
			stats.range = 330.0
			stats.projectile_speed = 350.0
			stats.aoe_radius = [135.0, 160.0, 185.0][stage - 1]
			stats.knockback_force = [220.0, 280.0, 360.0][stage - 1]
		"heavy_roller", "juggernaut":
			stats.damage = [30.0, 43.0, 60.0][stage - 1]
			stats.pierce = [7, 10, 14][stage - 1]
			stats.knockback_force = [330.0, 420.0, 520.0][stage - 1]
			stats.fire_rate = [.6, .65, .7][stage - 1]
		"ricochet_king":
			stats.damage = [22.0, 28.0, 36.0][stage - 1]
			stats.fire_rate = [.7, .8, .9][stage - 1]
			stats.projectile_speed = 400.0
			stats.pierce = 0
		"wide_flame", "inferno_crown":
			stats.damage = [3.2, 4.0, 5.0][stage - 1]
			stats.cone_degrees = [60.0, 85.0, 110.0][stage - 1]
			stats.burn_duration = [2.2, 2.5, 3.0][stage - 1]
		"dragonheart":
			stats.damage = [3.2, 4.0, 5.0][stage - 1]
			stats.range = [280.0, 330.0, 380.0][stage - 1]
			stats.cone_degrees = [24.0, 20.0, 16.0][stage - 1]
			stats.burn_ratio = [2.2, 2.6, 3.0][stage - 1]
			stats.burn_duration = [2.5, 3.0, 3.5][stage - 1]
		"repeater_bow", "arrowstorm":
			stats.damage = [12.0, 13.0, 14.0][stage - 1]
			stats.fire_rate = [.9, 1.0, 1.1][stage - 1]
			stats.projectile_speed = 1050.0
			stats.pierce = [1, 2, 2][stage - 1]
		"titan_bow":
			stats.damage = [32.0, 46.0, 66.0][stage - 1]
			stats.fire_rate = [.7, .75, .8][stage - 1]
			stats.range = [390.0, 430.0, 470.0][stage - 1]
			stats.projectile_speed = 1100.0
			stats.pierce = [3, 5, 8][stage - 1]
			stats.knockback_force = [120.0, 180.0, 240.0][stage - 1]
		"stormblade":
			stats.damage = [9.0, 10.0, 12.0][stage - 1]
			stats.rotation_rate = [300.0, 330.0, 360.0][stage - 1]
			stats.range = [150.0, 160.0, 170.0][stage - 1]
		"resonator", "resonance_engine":
			stats.damage = [5.0, 5.0, 5.0][stage - 1]
			stats.range = [240.0, 276.0, 276.0][stage - 1]
		"thunder_spear":
			stats.damage = [24.0, 36.0, 48.0][stage - 1]
			stats.fire_rate = [.75, .8, .85][stage - 1]
			stats.range = [300.0, 340.0, 400.0][stage - 1]
			stats.slow_intensity = [.3, .9, .9][stage - 1]
			stats.slow_duration = [.8, 1.6, 2.0][stage - 1]
		"saber", "orbit_saber":
			stats.damage = [11.0, 12.0, 14.0][stage - 1]
			stats.rotation_rate = [420.0, 450.0, 480.0][stage - 1]
			stats.range = [145.0, 155.0, 170.0][stage - 1]
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
	return stats

## Forms with both a working attack and authored art in this build. Tesla's forms and Constellation are registered but not built yet.
const IMPLEMENTED: Array[String] = ["machine_gun", "cyclone_gatling", "omnifire", "saber", "orbit_saber", "stormblade", "repeater_bow", "arrowstorm", "titan_bow", "wide_flame", "inferno_crown", "dragonheart", "heavy_roller", "juggernaut", "ricochet_king", "siege", "worldbreaker", "resonator", "resonance_engine", "thunder_spear", "piercer_rifle", "horizon_piercer", "overwatch"]

## Delays in seconds and damage fractions of the Resonator's echoes, per stage.
const RESONATOR_ECHO_DELAYS: Array = [[.5], [.4, .8], [.4, .8]]
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

## Sniper: half-width in metres of the lane a piercing shot travels along (each body's own radius is added), how many
## enemies behind the target the Piercer Rifle line reaches, and the pierce value that means "the whole line".
const SNIPER_LANE_HALF_WIDTH: float = .45
const SNIPER_PIERCER_PIERCE: int = 2
const SNIPER_UNLIMITED_PIERCE: int = 99
## Overwatch marks this many of the toughest enemies in range for this many seconds on every shot.
const OVERWATCH_MARK_COUNT: int = 3
const OVERWATCH_MARK_SECONDS: float = 6.0

## "none", a count of extra enemies, or "whole line" for the Horizon Piercer, for stat readouts.
static func pierce_text(pierce: int) -> String:
	if pierce <= 0:
		return "none"
	return "whole line" if pierce >= SNIPER_UNLIMITED_PIERCE else str(pierce)

## Arrows loosed per Repeater Bow volley, rail by rail.
static func volley_size(stage: int) -> int:
	return [2, 3, 5][stage - 1]

## Per-form shot shape (visual, size, bounces), applied after the shot is built from stats.
static func shape_shot(shot: CombatShot3D, base_type: String, form_id: String) -> void:
	var stage := legacy_stage(form_id)
	if base_type == "bow":
		shot.visual_key = "arrow"
		if form_id == "titan_bow":
			shot.visual_scale = 1.0 + .3 * stage
			shot.radius *= shot.visual_scale
	elif base_type == "bowling":
		shot.visual_key = "bowling_ball"
		shot.radius = .24
		shot.lifetime = 4.0
		if form_id in ["heavy_roller", "juggernaut"]:
			shot.visual_scale = 1.0 + .25 * stage
			shot.radius *= shot.visual_scale
		elif form_id == "ricochet_king":
			shot.ricochets = [2, 4, 6][stage - 1]
			shot.lifetime = 6.0
	if form_id in ["siege", "worldbreaker"]:
		shot.radius = [.22, .28, .34][stage - 1]

## The Stormblade's rotating barrel fires these stats rather than the blade's.
static func gunblade_barrel_stats(stage: int) -> Dictionary:
	var stats := TurretRegistry.get_base_stats("normal")
	stats.damage = [7.0, 8.0, 9.0][clampi(stage - 1, 0, 2)]
	stats.fire_rate = [2.0, 2.2, 2.4][clampi(stage - 1, 0, 2)]
	stats.range = 300.0
	stats.pierce = 1 if stage >= 3 else 0
	return stats

static func description(form_id: String) -> String:
	var stage := legacy_stage(form_id)
	match form_id:
		"machine_gun", "cyclone_gatling": return ["Rapid aimed fire.", "Rotary fire accelerates while a target remains in range.", "Piercing rotary fire accelerates to 2.5 times its resting rate."][stage - 1]
		"omnifire": return "Twelve shots cover a full circle in evenly spaced directions."
		"heavy_roller", "juggernaut": return "Larger balls drive through crowds with stronger knockback."
		"ricochet_king": return "Redirects toward a fresh nearby enemy up to %d times." % [2, 4, 6][stage - 1]
		"wide_flame", "inferno_crown": return "A %d-degree fan blankets a crowd and leaves enemies burning." % [60, 85, 110][stage - 1]
		"dragonheart": return "A longer, narrower jet delivers a stronger, longer-lasting burn."
		"repeater_bow", "arrowstorm": return "Fires a quick burst of %d piercing arrows." % [2, 3, 5][stage - 1]
		"titan_bow": return "Heavy arrows pierce %d enemies and knock them back." % [4, 6, 9][stage - 1]
		"stormblade": return "Three-shot piercing bursts accompany a longer, faster blade sweep."
		"saber", "orbit_saber": return ["A longer, faster energy-blade sweep.", "Two opposing held blades sweep both sides of the turret.", "Three held energy blades sweep evenly around the turret."][stage - 1]
		"resonator", "resonance_engine": return ["Each pulse echoes once half a second later at half damage, refreshing the slow.", "Two echoes follow each pulse and the pulse reaches 15% farther.", "Pulses alternate a tight, hard inner ring and a wide outer ring; enemies caught by both are Exposed, taking 30% more from Instant turrets."][stage - 1]
		"thunder_spear": return "The bolt drives through a whole lane of enemies and pins every one."
		"siege", "worldbreaker": return "Slow, heavy shells explode over a large area and push enemies back."
		"piercer_rifle": return "A longer barrel and heavier rounds. The shot passes through two enemies behind its target."
		"horizon_piercer": return "The shot runs the whole line to full range and strikes every enemy on it. Aim the toughest enemy through the crowd."
		"overwatch": return "Keeps the Piercer shot and marks the three toughest enemies in range for 6 seconds. Marked enemies take 25% more damage from every turret, and the mark jumps to the next toughest enemy when one dies."
	return ""

class_name TurretEvolution
extends RefCounted

## Run-local forms. Every base turret has one level-5 upgrade (no choice) and two level-10 finals (pick one).
## IDs name forms; `model` selects a reusable authored chassis. Ownership always remains with the original base type.
## The form table is `TurretForms`, one row per form (read its header to add a turret). This class answers questions about
## the rows and holds the mechanic constants several forms of a line share.

## base id -> {"upgrade": form id, "finals": [form ids]}, derived once from the rows (row order is path order).
static var _paths: Dictionary = {}
## Global class name -> script path, read once from the project's class list.
static var _class_paths: Dictionary = {}

static func row(form_id: String) -> Dictionary:
	return TurretForms.FORMS.get(form_id, {})

static func has_form(form_id: String) -> bool:
	return TurretForms.FORMS.has(form_id)

## Every registered form id, in table order.
static func form_ids() -> Array[String]:
	var result: Array[String] = []
	result.assign(TurretForms.FORMS.keys())
	return result

## The upgrade and the two finals of each base turret that has forms.
static func paths() -> Dictionary:
	if _paths.is_empty():
		for form_id: String in TurretForms.FORMS:
			var form_row: Dictionary = TurretForms.FORMS[form_id]
			var path: Dictionary = _paths.get(form_row["base"], {"upgrade": "", "finals": [] as Array[String]})
			if form_row["kind"] == TurretForms.UPGRADE:
				path["upgrade"] = form_id
			else:
				path["finals"].append(form_id)
			_paths[form_row["base"]] = path
	return _paths

## Base turrets that have forms, in table order.
static func bases() -> Array[String]:
	var result: Array[String] = []
	result.assign(paths().keys())
	return result

## Forms offered at `stage` (evolutions already taken): the upgrade at 0, the two finals at 1, nothing after.
static func options(base_type: String, stage: int) -> Array[String]:
	var result: Array[String] = []
	var path: Dictionary = paths().get(base_type, {})
	if stage == 0 and path.has("upgrade"):
		result.append(str(path["upgrade"]))
	elif stage == 1:
		result.assign(path.get("finals", []))
	return result

static func form_name(form_id: String) -> String:
	return str(row(form_id).get("name", ""))

## The authored chassis for a form; empty for no form (callers fall back to the base turret's model).
static func model_key(form_id: String) -> String:
	return str(row(form_id).get("model", ""))

static func description(form_id: String) -> String:
	return str(row(form_id).get("description", ""))

## True for forms with both a working attack and authored art in this build. Tesla's forms and Constellation are registered but not built yet.
static func is_implemented(form_id: String) -> bool:
	return bool(row(form_id).get("implemented", false))

static func implemented_forms() -> Array[String]:
	var result: Array[String] = []
	for form_id: String in TurretForms.FORMS:
		if is_implemented(form_id):
			result.append(form_id)
	return result

## One of a form's `params` (see the `TurretForms` header), or `default` when the row does not set it.
static func param(form_id: String, key: String, default: Variant = null) -> Variant:
	return row(form_id).get("params", {}).get(key, default)

## The `TurretForm` subclass (a script) that runs a form's attack, or null when `TurretActor`'s default attack applies.
## With no form it is the unevolved base turret's own behaviour.
static func behaviour_script(base_type: String, form_id: String) -> Variant:
	if form_id.is_empty():
		return _script_named(TurretForms.BASES.get(base_type, {}).get("behaviour", ""))
	return _script_named(row(form_id).get("behaviour", ""))

## The `*EvolutionVisual` script whose `build(model, form_id)` adds a form's hardware to its chassis, or null for none.
static func visual_script(form_id: String) -> Variant:
	return _script_named(row(form_id).get("visual", ""))

## The script of a global class, or null for an empty name. The table names its classes instead of referring to them because
## the classes read the table (see the `TurretForms` header).
static func _script_named(script_class: String) -> Variant:
	if script_class.is_empty():
		return null
	if _class_paths.is_empty():
		for entry: Dictionary in ProjectSettings.get_global_class_list():
			_class_paths[str(entry["class"])] = str(entry["path"])
	return load(_class_paths[script_class]) if _class_paths.has(script_class) else null

## Shape the attack before item modifiers so flat bonuses remain meaningful: the base turret's stats with the form's overrides.
static func base_stats(base_type: String, form_id: String) -> Dictionary:
	var stats := TurretRegistry.get_base_stats(base_type)
	stats.merge(row(form_id).get("stats", {}), true)
	return stats

## Each Resonator echo deals this fraction of the pulse (the echo delays are the form's `echo_delays` param).
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
const SNIPER_PIERCER_PIERCE: int = TurretForms.SNIPER_PIERCER_PIERCE
const SNIPER_UNLIMITED_PIERCE: int = TurretForms.SNIPER_UNLIMITED_PIERCE
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
const CATACLYSM_STAGGER: float = TurretForms.CATACLYSM_STAGGER
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

## Decoy line. Maelstrom scans for enemies to hook this often, ticks every hooked enemy this often, and its hooked enemies
## circle at this radius (the innermost lane, in metres; it must clear the turret body and sit inside the pulse reach).
const MAELSTROM_SCAN_SECONDS: float = .25
const MAELSTROM_TICK_SECONDS: float = .5
const MAELSTROM_RING: float = 1.1

## One line on what a Decoy form does besides its pulse, for the preview and the inspector.
static func decoy_pattern_text(form_id: String) -> String:
	var every := int(param(form_id, "slam_every", 0))
	if every > 0:
		return "Every %s pulse slams: %.0fx damage, %.1fx reach, %.1f s stagger" % [ordinal(every), float(param(form_id, "slam_damage", 1.0)), float(param(form_id, "slam_radius", 1.0)), float(param(form_id, "slam_stagger", 0.0))]
	var hooks := int(param(form_id, "hooks", 0))
	if hooks > 0:
		return "Hooks up to %d enemies in reach until they die; ranged enemies are drawn in too" % hooks
	return "Enemies in reach walk at it; bosses ignore it"

static func ordinal(count: int) -> String:
	return {1: "first", 2: "second", 3: "third", 4: "fourth", 5: "fifth"}.get(count, "%dth" % count)

## One line on where a Scrap Press form sends its drops, for the preview and the inspector.
static func scrap_press_pattern_text(form_id: String) -> String:
	var radius := float(param(form_id, "xp_radius", 0.0))
	if radius > 0.0:
		return "No scrap: each drop is XP, in full, to every turret within %.0f m (this one too)" % radius
	var per := int(param(form_id, "interest_per", 0))
	if per > 0:
		return "Every drop goes to your wallet; on a won wave +1 scrap per %d held, up to %d" % [per, int(param(form_id, "interest_cap", 0))]
	var share := float(param(form_id, "deposit_share", 0.0))
	if share > 0.0:
		return "%.0f%% of every drop goes to your wallet; the rest lands beside the press" % (share * 100.0)
	return "Drops land beside the press; scrap left at wave end becomes XP for nearby turrets"

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
	return int(param(form_id, "volley", 1))

## Held blades sweeping around the turret: the Orbit Saber carries several, every other form one.
static func blade_count(form_id: String) -> int:
	return int(param(form_id, "blades", 1))

## Rounds in one burst of the Stormblade's rotating barrel (the first leaves at once, the rest follow from the other barrels).
static func barrel_burst(form_id: String) -> int:
	return int(param(form_id, "barrel_burst", 1))

## The Stormblade's rotating barrel fires these stats rather than the blade's.
static func gunblade_barrel_stats(form_id: String) -> Dictionary:
	var stats := TurretRegistry.get_base_stats("normal")
	stats.merge(param(form_id, "barrel", {}), true)
	return stats

## Scale of a form's shot (the roller balls, the Titan Bow's arrows); 1 when the form does not scale it.
static func shot_scale(form_id: String) -> float:
	return float(row(form_id).get("shot", {}).get("visual_scale", 1.0))

## Per-form shot shape (visual, size, bounces), applied after the shot is built from stats: the base turret's own `shot`
## fields first, then the form's.
static func shape_shot(shot: CombatShot3D, base_type: String, form_id: String) -> void:
	_apply_shape(shot, TurretForms.BASES.get(base_type, {}).get("shot", {}))
	_apply_shape(shot, row(form_id).get("shot", {}))

static func _apply_shape(shot: CombatShot3D, shape: Dictionary) -> void:
	for key: String in shape:
		if key == "visual_scale":
			shot.visual_scale = float(shape[key])
			shot.radius *= shot.visual_scale
		else:
			shot.set(key, shape[key])

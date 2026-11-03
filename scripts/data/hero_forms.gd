class_name HeroForms
extends RefCounted

## The hero's evolution rows, in path order: the level-5 upgrade, then the two level-10 finals.
## Row keys: kind (UPGRADE | FINAL), name, description (numbers must match `stats` and `shot`), stats (multipliers on the
## level-scaled health/damage/fire_rate/range), shot (CombatShot3D fields: pierce, ricochets), tint and scale (placeholder look
## until authored models exist).
const UPGRADE: String = "upgrade"
const FINAL: String = "final"

const ROWS: Dictionary = {
	"pip_arc": {
		"kind": UPGRADE, "name": "Arc Pip",
		"description": "+15% damage, +10% attack speed. Shots ricochet once.",
		"stats": {"damage": 1.15, "fire_rate": 1.10}, "shot": {"ricochets": 1},
		"tint": Color(0.35, 0.85, 1.0, 0.18), "scale": 1.05,
	},
	"pip_lancer": {
		"kind": FINAL, "name": "Ion Lancer",
		"description": "+30% damage, +15% range. Shots pierce 2 enemies.",
		"stats": {"damage": 1.30, "range": 1.15}, "shot": {"pierce": 2},
		"tint": Color(0.45, 0.6, 1.0, 0.28), "scale": 1.15,
	},
	"pip_storm": {
		"kind": FINAL, "name": "Stormcaller",
		"description": "+35% attack speed, +10% health. Shots ricochet 3 times.",
		"stats": {"fire_rate": 1.35, "health": 1.10}, "shot": {"ricochets": 3},
		"tint": Color(0.75, 0.5, 1.0, 0.28), "scale": 1.15,
	},
}

## Row ids in path order: stage 0 is the upgrade, stage 1 the finals.
const PATH: Array = [["pip_arc"], ["pip_lancer", "pip_storm"]]

static func row(form_id: String) -> Dictionary:
	return ROWS.get(form_id, {})

static func options(stage: int) -> Array[String]:
	var result: Array[String] = []
	if stage >= 0 and stage < PATH.size():
		result.assign(PATH[stage])
	return result

## Applies a form's shot fields to a freshly built hero shot.
static func apply_shot(form_id: String, shot: CombatShot3D) -> void:
	var fields: Dictionary = row(form_id).get("shot", {})
	for key: String in fields:
		shot.set(key, fields[key])

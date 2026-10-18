class_name TurretForm
extends RefCounted

## Attack behaviour for one evolution branch. `TurretActor` keeps the shared parts (stats cache, targeting,
## cooldown) and delegates the branch-specific attack and state here, so a new form is a subclass plus a `create` entry.
var actor: TurretActor
var branch: String

## The form for `branch`, or null when the actor handles the branch itself.
static func create(owner: TurretActor, branch_id: String) -> TurretForm:
	var result: TurretForm
	match branch_id:
		"resonator": result = ResonatorForm.new()
		"lance": result = LanceForm.new()
		_: return null
	result.actor = owner
	result.branch = branch_id
	return result

## Per-tick state advance while in combat.
func tick(_delta: float) -> void:
	pass

## Drops queued work when combat stops.
func clear() -> void:
	pass

## Pulse-mode attack at `target`, the nearest enemy in range.
func fire_pulse(_stats: TurretStats, _range_metres: float, _target: CombatActor) -> void:
	pass

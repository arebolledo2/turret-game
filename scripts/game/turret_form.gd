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
		"scatter": result = ScatterForm.new()
		"gunblade": result = GunbladeForm.new()
		"machine_gun": result = MachineGunForm.new()
		"repeater_bow": result = RepeaterBowForm.new()
		_: return null
	result.actor = owner
	result.branch = branch_id
	return result

## Called after the actor rebuilds its model (spawn or evolution); reset visual-linked state.
func rebuilt() -> void:
	pass

## Called whenever the actor re-resolves its cached stats.
func refresh_stats() -> void:
	pass

## Per-tick work for sweep-mode turrets, after the bat has turned.
func tick_sweep(_delta: float) -> void:
	pass

## Per-tick visual and mechanical upkeep; `tracking` is true while a target is in reach.
func tick_mechanisms(_delta: float, _tracking: bool) -> void:
	pass

## Divides the cooldown after a shot (fire-rate boosts such as a spooled rotor).
func cooldown_divisor() -> float:
	return 1.0

## Per-tick state advance while in combat.
func tick(_delta: float) -> void:
	pass

## Drops queued work when combat stops.
func clear() -> void:
	pass

## Pulse-mode attack at `target`, the nearest enemy in range.
func fire_pulse(_stats: TurretStats, _range_metres: float, _target: CombatActor) -> void:
	pass

## Projectile-mode attack along `heading` (toward the actor's target). Returns false to use the default single shot.
func fire_projectile(_stats: TurretStats, _heading: Vector3) -> bool:
	return false

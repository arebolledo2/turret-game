class_name TurretForm
extends RefCounted

## Attack behaviour for one evolution form. `TurretActor` keeps the shared parts (stats cache, targeting,
## cooldown) and delegates the form-specific attack and state here, so a new form is a subclass plus a `create` entry.
## Several forms of one lineage can share a subclass; it reads `TurretEvolution.legacy_stage(form_id)` for what differs.
var actor: TurretActor
var form_id: String

## The behaviour for `id`, or null when the actor handles the form itself.
static func create(owner: TurretActor, id: String) -> TurretForm:
	var result: TurretForm
	match id:
		"resonator", "resonance_engine": result = ResonatorForm.new()
		"thunder_spear": result = LanceForm.new()
		"omnifire": result = ScatterForm.new()
		"stormblade": result = GunbladeForm.new()
		"machine_gun", "cyclone_gatling": result = MachineGunForm.new()
		"repeater_bow", "arrowstorm": result = RepeaterBowForm.new()
		"overwatch": result = OverwatchForm.new()
		"aftershock", "tectonic", "cataclysm": result = QuakeForm.new()
		# The unevolved Quake pulses through the same form (no form id, so it is keyed by the turret type).
		"": result = QuakeForm.new() if owner.turret_type == "quake" else null
		_: return null
	if result == null:
		return null
	result.actor = owner
	result.form_id = id
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

## Instant-mode attack, called just before the shot resolves its target line (`range_metres` is the attack reach).
func before_instant(_stats: TurretStats, _range_metres: float) -> void:
	pass

## Projectile-mode attack along `heading` (toward the actor's target). Returns false to use the default single shot.
func fire_projectile(_stats: TurretStats, _heading: Vector3) -> bool:
	return false

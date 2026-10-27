class_name TurretForm
extends RefCounted

## Attack behaviour for one evolution form. `TurretActor` keeps the shared parts (stats cache, targeting,
## cooldown) and delegates the form-specific attack and state here, so a new form is a subclass plus a `behaviour` entry
## in its `TurretForms` row. Several forms of one lineage can share a subclass; it reads its numbers from the row's
## `params` (see `param`) rather than from the form id.
var actor: TurretActor
var form_id: String

## The behaviour the form's row names (or the base turret's own for no form), or null when the actor handles the form itself.
static func create(owner: TurretActor, id: String) -> TurretForm:
	var script: Variant = TurretEvolution.behaviour_script(owner.turret_type, id)
	if script == null:
		return null
	var result := script.new() as TurretForm
	result.actor = owner
	result.form_id = id
	return result

## One of this form's row `params`, or `default`.
func param(key: String, default: Variant = null) -> Variant:
	return TurretEvolution.param(form_id, key, default)

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

## Single-target damage per second for the shop; splash, chains, penetration and ricochets depend on enemy arrangement.
## A form whose numbers differ from the fire mode's override this; `TurretForm.dps_of` covers turrets with no form object.
func estimate_dps(stats: TurretStats) -> float:
	return base_dps(actor, stats)

## True when the form carries a second weapon with its own resolved stats (the Stormblade's rotating barrel).
func has_barrel() -> bool:
	return false

## The estimate for `owner`, from its form when it has one, else from its fire mode.
static func dps_of(owner: TurretActor) -> float:
	var stats := owner.resolve_attack_view()
	return owner.form.estimate_dps(stats) if owner.form else base_dps(owner, stats)

## What the fire mode alone implies: a sweeping bat is limited by its blades and rehit delay, a flame adds its burn.
static func base_dps(owner: TurretActor, stats: TurretStats) -> float:
	match TurretRegistry.get_fire_mode(owner.turret_type):
		TurretRegistry.FIRE_SWEEP:
			var blades := TurretEvolution.blade_count(owner.progression.evolution_form)
			return stats.damage * minf(stats.rotation_rate * blades / 360.0, 1.0 / maxf(.01, stats.rehit_delay))
		TurretRegistry.FIRE_FLAME:
			var burn := stats.damage * float(stats.values.get("burn_ratio", 1.6)) * minf(1.0, stats.fire_rate * float(stats.values.get("burn_duration", 2.0)))
			return stats.damage * stats.fire_rate + burn
	return stats.damage * stats.fire_rate

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

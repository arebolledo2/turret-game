class_name StatusEffects3D
extends RefCounted

## Uses the shared status lifetime/refresh rules without the Node2D event bus.
var effects: Dictionary = {}
const BURN_TICK: float = .25
var burn_transferred: bool = false
var burn_dps: float = 0.0
var burn_remaining: float = 0.0
var burn_elapsed: float = 0.0
var burn_source_id: int = 0
var burn_origin := Vector3.ZERO
var burn_families: Array[String] = []
var _pending_burn_hits: Array[CombatHit3D] = []


func apply(hit: CombatHit3D) -> void:
	# One burn per enemy: stronger replaces, equal refreshes, weaker cannot prolong a stronger burn.
	if hit.burn_dps > 0.0 and hit.burn_duration > 0.0 and hit.burn_dps >= burn_dps:
		if burn_elapsed > 0.0 and (hit.source_id != burn_source_id or hit.burn_dps != burn_dps):
			_pending_burn_hits.append(_burn_hit(burn_elapsed))
			burn_elapsed = 0.0
		burn_transferred = hit.burn_transferred
		burn_dps = hit.burn_dps
		burn_remaining = maxf(burn_remaining, hit.burn_duration) if hit.source_id == burn_source_id else hit.burn_duration
		burn_source_id = hit.source_id
		burn_origin = hit.origin
		burn_families = hit.attack_families.duplicate()

	if hit.slow_intensity <= 0.0 or hit.slow_duration <= 0.0:
		return
	var intensity := clampf(hit.slow_intensity, 0.0, .9)
	if effects.has(hit.damage_type):
		effects[hit.damage_type].refresh(0.0, hit.slow_duration, intensity)
	else:
		effects[hit.damage_type] = StatusEffect.new(hit.damage_type, 0.0, hit.slow_duration, 1.0, intensity)

func is_burning() -> bool:
	return burn_remaining > 0.0 or not _pending_burn_hits.is_empty()

func advance(delta: float) -> void:
	for type in effects.keys():
		var effect: StatusEffect = effects[type]
		effect.process(delta)
		if effect.is_expired():
			effects.erase(type)

func speed_multiplier() -> float:
	var strongest: float = 0.0
	for effect: StatusEffect in effects.values():
		strongest = maxf(strongest, effect.slow_intensity)
	return 1.0 - strongest

## Returns resolved damage snapshots; ticks never reapply burn or item modifiers.
func advance_burn(delta: float) -> Array[CombatHit3D]:
	var hits: Array[CombatHit3D] = []
	if delta <= 0.0:
		return hits
	hits.assign(_pending_burn_hits)
	_pending_burn_hits.clear()
	if burn_remaining <= 0.0 or delta <= 0.0:
		return hits
	var consumed := minf(delta, burn_remaining)
	burn_remaining = maxf(0.0, burn_remaining - consumed)
	burn_elapsed += consumed
	while burn_elapsed >= BURN_TICK - .000001 or (burn_remaining <= .000001 and burn_elapsed > .000001):
		var seconds := minf(BURN_TICK, burn_elapsed)
		burn_elapsed = maxf(0.0, burn_elapsed - seconds)
		hits.append(_burn_hit(seconds))
	if burn_remaining <= .000001:
		clear_burn()
	return hits

func _burn_hit(seconds: float) -> CombatHit3D:
	var hit := CombatHit3D.new(burn_dps * seconds, burn_origin, Vector3.ZERO, GameEnums.DamageType.FIRE)
	hit.is_dot = true
	hit.burn_transferred = burn_transferred
	hit.source_id = burn_source_id
	hit.attack_families = burn_families.duplicate()
	return hit

func clear_burn() -> void:
	burn_transferred = false
	burn_dps = 0.0
	burn_remaining = 0.0
	burn_elapsed = 0.0
	burn_source_id = 0
	burn_families.clear()

func clear() -> void:
	effects.clear()
	_pending_burn_hits.clear()
	clear_burn()

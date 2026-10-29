class_name StatusEffects3D
extends RefCounted

## Uses the shared status lifetime/refresh rules without the Node2D event bus.
##
## Timed statuses (exposed, marked, staggered and any generic name) are `TimedStatus` timers keyed by owner id, the
## applying turret's `source_id` (0 for ownerless). A status is active while any owner's timer runs and its remaining
## time is the longest of them, so one turret clearing or losing its timer never removes another turret's. The named
## methods below (`mark`, `unmark`, `stagger`, ...) take an optional `owner` (default 0) and keep their old rules.
## Generic API for new statuses (for example a Decoy 'hooked'; no bespoke fields needed):
##   apply_timed(name, duration, owner)  refresh that owner's timer to the longer time
##   is_active(name) / remaining(name)   any owner active / longest time left
##   clear_timed(name, owner)            remove only that owner's timer
##   advance_timed(name, delta)          the caller ticks it, like `advance_mark` does for the mark
## `clear()` drops every timer for every owner. Burn and slow are not owner-keyed.
var effects: Dictionary = {}
## Exposed: extra damage taken from Instant-family turrets while the timer runs.
const EXPOSED_BONUS: float = .3
var exposed_remaining: float:
	get: return remaining("exposed")
## Marked (Overwatch): extra damage taken from every turret while the timer runs. Independent of Exposed.
## Stacking rule: the final hit is `damage * exposure_multiplier * mark_multiplier`, so a Marked, Exposed enemy hit by an
## Instant turret takes 1.3 * 1.25 = 1.625 times the damage. The mark itself never stacks; refreshing keeps the longer timer.
const MARKED_BONUS: float = .25
var marked_remaining: float:
	get: return remaining("marked")
## Staggered (Quake): the enemy cannot move, attack or start a charge while the timer runs (a knockback still slides it).
## Stacking rule: `stagger` refreshes to the longer remaining time and never adds, so repeated hits cannot lock an enemy;
## `extend_stagger` (Cataclysm) adds the hit's time to what is left, up to `STAGGER_CAP`, so a sustained barrage keeps an
## enemy down for at most that long however many pulses land. Bosses are never staggered (see `EnemyActor`).
const STAGGER_CAP: float = 1.5
var staggered_remaining: float:
	get: return remaining("staggered")
var _timed: Dictionary = {}
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

func expose(duration: float, owner: int = 0) -> void:
	apply_timed("exposed", duration, owner)

## Generic timed status: refreshes `owner`'s timer for `status` to the longer of its time left and `duration`.
func apply_timed(status: String, duration: float, owner: int = 0) -> void:
	_timer(status).refresh(duration, owner)

func is_active(status: String) -> bool:
	return _timed.has(status) and _timed[status].is_active()

## Longest time left across owners (0 when inactive).
func remaining(status: String) -> float:
	return _timed[status].remaining() if _timed.has(status) else 0.0

func remaining_for_owner(status: String, owner: int = 0) -> float:
	return _timed[status].remaining_for(owner) if _timed.has(status) else 0.0

## Removes only `owner`'s timer; other owners' timers keep the status active.
func clear_timed(status: String, owner: int = 0) -> void:
	if _timed.has(status):
		_timed[status].clear_owner(owner)

func advance_timed(status: String, delta: float) -> void:
	if _timed.has(status):
		_timed[status].advance(delta)

func _timer(status: String) -> TimedStatus:
	if not _timed.has(status):
		_timed[status] = TimedStatus.new()
	return _timed[status]

func exposure_multiplier(hit: CombatHit3D) -> float:
	return 1.0 + EXPOSED_BONUS if is_active("exposed") and "instant" in hit.attack_families else 1.0

## Marks never stack in magnitude: `mark_multiplier` reads `is_marked()`, so any number of owners gives +25% once.
func mark(duration: float, owner: int = 0) -> void:
	apply_timed("marked", duration, owner)

## Removes only `owner`'s mark; a mark placed by another owner stays.
func unmark(owner: int = 0) -> void:
	clear_timed("marked", owner)

func is_marked() -> bool:
	return is_active("marked")

func marked_remaining_for(owner: int = 0) -> float:
	return remaining_for_owner("marked", owner)

## Turret hits only: the hero's weapon, enemy contact damage and blasts without a turret source are not amplified.
func mark_multiplier(hit: CombatHit3D) -> float:
	return 1.0 + MARKED_BONUS if is_active("marked") and hit.source_id > 0 else 1.0

## Runs every tick the enemy is alive (stationary crates included), unlike `advance`, which only runs while an enemy moves.
func advance_mark(delta: float) -> void:
	advance_timed("marked", delta)

## Refreshes to the longer of the current and the new time.
func stagger(duration: float, owner: int = 0) -> void:
	apply_timed("staggered", duration, owner)

## Adds `duration` to the time left, up to `cap`; never shortens a stagger that is already longer than the cap.
func extend_stagger(duration: float, cap: float = STAGGER_CAP, owner: int = 0) -> void:
	_timer("staggered").extend(duration, cap, owner)

func is_staggered() -> bool:
	return is_active("staggered")

## Runs every tick the enemy is alive, like the mark timer.
func advance_stagger(delta: float) -> void:
	advance_timed("staggered", delta)

func advance(delta: float) -> void:
	advance_timed("exposed", delta)
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
	_timed.clear()
	_pending_burn_hits.clear()
	clear_burn()

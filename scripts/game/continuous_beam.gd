class_name ContinuousBeam
extends RefCounted

## Engine piece S11: the state and queries of one continuous beam, shared by every turret that holds a beam on something (the
## Laser's single beam and Sunpiercer's, Halo Cutter's spinning cross). It is not a node and owns no visual (see `BeamLines`): a
## turret's form drives it once per physics step.
##   Lock       `lock(enemy)` puts the beam on an enemy. A new enemy starts the heat at zero (retargeting resets the ramp) and the
##              first tick is due at once; locking the enemy it already holds changes nothing.
##   Heat       seconds the beam has stayed on one enemy. `ramp(heat, seconds, peak)` turns heat into a damage multiplier that
##              climbs linearly from x1 to `peak`.
##   Ticks      `advance(delta, rate)` adds the step to the heat and returns how many damage ticks fell due. A step never yields
##              more than `MAX_TICKS_PER_STEP`, and a backlog (a stalled frame, a huge attack-speed bonus) is dropped, not
##              replayed, so the damage dealt per second is bounded by the physics rate however the rate stat is boosted.
##   Finding    `nearest` and `touching` read the arena's crowd grid (one snapshot per physics step), never the whole enemy list.
##              Both see enemies only, so a beam can never hit the hero or a turret.
## A beam holds no references the world does not already hold: `release()` (or the form's `clear()`) drops the target.

## Most damage ticks one beam deals in one physics step.
const MAX_TICKS_PER_STEP: int = 3
## Seconds between searches for something to lock onto while the beam has nothing.
const SEARCH_INTERVAL: float = .2

var target: CombatActor
## True while the beam is running: locked onto `target`, or (a cross with no single target) switched on by `engage()`.
var engaged: bool = false
## Seconds spent on the current target.
var heat: float = 0.0
var tick_clock: float = 0.0
## True from a fresh lock until its first tick is paid.
var fresh: bool = false
## Counters for tests and tools: damage ticks handed out and locks taken since the beam was made.
var ticks_dealt: int = 0
var locks: int = 0

## True while the beam still has a living target inside `reach` metres of `origin` (the target's body counts).
func holds(origin: Vector3, reach: float) -> bool:
	return is_instance_valid(target) and not target.dead and target.overlaps_attack_range(origin, reach)

## Puts the beam on `enemy`. A different enemy resets the heat; the first tick is due immediately.
func lock(enemy: CombatActor) -> void:
	if enemy == target:
		return
	target = enemy
	heat = 0.0
	tick_clock = 0.0
	fresh = enemy != null
	engaged = enemy != null
	if enemy:
		locks += 1

## Switches on a beam that has no single target (a spinning cross): the heat starts at zero and the first tick is due at once.
func engage() -> void:
	if engaged:
		return
	target = null
	heat = 0.0
	tick_clock = 0.0
	fresh = true
	engaged = true
	locks += 1

## Lets go of the target and forgets the heat.
func release() -> void:
	target = null
	engaged = false
	heat = 0.0
	tick_clock = 0.0
	fresh = false

## Adds `delta` seconds on the target and returns the damage ticks that fell due at `rate` ticks per second (at most `max_ticks`).
func advance(delta: float, rate: float, max_ticks: int = MAX_TICKS_PER_STEP) -> int:
	heat += delta
	var interval := 1.0 / maxf(rate, TurretStats.MIN_FIRE_RATE)
	if fresh:
		# The first tick is paid the moment the beam lands.
		tick_clock = interval
		fresh = false
	# A stall is not repaid: the clock never holds more than `max_ticks` intervals.
	tick_clock = minf(tick_clock + delta, interval * max_ticks)
	var due := 0
	while tick_clock >= interval - .000001 and due < max_ticks:
		tick_clock -= interval
		due += 1
	tick_clock = minf(tick_clock, interval)
	ticks_dealt += due
	return due

## The damage multiplier after `heat` seconds on one enemy: x1 at zero, rising linearly to `peak` at `seconds`, then flat.
static func ramp(heat_seconds: float, seconds: float, peak: float) -> float:
	return lerpf(1.0, maxf(peak, 1.0), clampf(heat_seconds / maxf(seconds, .001), 0.0, 1.0))

## The nearest living enemy whose body overlaps the circle of `reach` metres round `origin`, or null. One crowd-grid query.
static func nearest(crowd: CrowdGrid3D, origin: Vector3, reach: float) -> CombatActor:
	var best: CombatActor = null
	var best_distance := INF
	for candidate in crowd.query_radius(origin, reach, true):
		if not candidate.is_enemy:
			continue
		var distance := WorldGeometry.planar(candidate.position - origin).length_squared()
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best

## True when `enemy`'s body touches the line segment from `origin` along `direction` (planar, unit length) for `length` metres
## and `half_width` metres either side.
static func crosses(enemy: CombatActor, origin: Vector3, direction: Vector3, length: float, half_width: float) -> bool:
	var offset := WorldGeometry.planar(enemy.position - origin)
	var reach := enemy.hurtbox_radius()
	var along := offset.dot(direction)
	if along < -reach or along > length + reach:
		return false
	return absf(offset.x * direction.z - offset.z * direction.x) <= half_width + reach

## Living enemies whose bodies touch any of the segments that start at `origin`, one along each of `directions` (planar unit
## vectors), each `length` metres long and `half_width` either side. Each enemy appears once however many segments touch it.
## At most `limit` are returned (negative: no cap), the nearest to `origin` first when the cap bites. One crowd-grid query.
static func touching(crowd: CrowdGrid3D, origin: Vector3, directions: Array[Vector3], length: float, half_width: float,
		limit: int = -1) -> Array[CombatActor]:
	var found: Array[CombatActor] = []
	for candidate in crowd.query_radius(origin, length + half_width, true):
		if not candidate.is_enemy:
			continue
		for direction in directions:
			if crosses(candidate, origin, direction, length, half_width):
				found.append(candidate)
				break
	if limit >= 0 and found.size() > limit:
		found.sort_custom(func(a: CombatActor, b: CombatActor) -> bool:
			return WorldGeometry.planar(a.position - origin).length_squared() < WorldGeometry.planar(b.position - origin).length_squared())
		found.resize(limit)
	return found

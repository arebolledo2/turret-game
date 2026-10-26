class_name TurretTargeting
extends RefCounted

## Target selection for turrets whose registry `targeting` is not the default nearest/cluster rule.
## `TurretActor` calls `select()` with `TurretRegistry.get_targeting(type)`; `Combat3D.select_target` still owns closest
## and cluster. Every mode only considers living enemies whose hurtbox overlaps the attack range, so bosses and tech-drop
## crates (both live in `world.enemies`) are ordinary candidates.

const CLOSEST := "closest"
const FARTHEST := "farthest"
const TOUGHEST := "toughest"
const BACKLINE := "backline"

## Modes this helper resolves. Anything else (closest, cluster) goes through `Combat3D.select_target`.
const MODES: Array[String] = [FARTHEST, TOUGHEST, BACKLINE]

## Ranged and summoner enemies (Needle Kite, Kiln Lobber, Brood Tender). Bosses and the rest of the ecology are not backline.
const BACKLINE_TYPES: Array[String] = ["kite", "lobber", "tender"]

static func handles(mode: String) -> bool:
	return mode in MODES

## The enemy this mode picks, or null when nothing is in range. `mode` must be one of `MODES`; closest is the fallback.
static func select(mode: String, origin: Vector3, range_metres: float, candidates: Array[CombatActor]) -> CombatActor:
	match mode:
		FARTHEST: return farthest(origin, range_metres, candidates)
		TOUGHEST: return toughest(origin, range_metres, candidates)
		BACKLINE: return backline(origin, range_metres, candidates)
	return closest(origin, range_metres, candidates)

## Nearest enemy in range (planar distance to the centre).
static func closest(origin: Vector3, range_metres: float, candidates: Array[CombatActor]) -> CombatActor:
	var best: CombatActor = null
	var best_distance := INF
	for candidate in candidates:
		if not _targetable(candidate, origin, range_metres):
			continue
		var distance := _distance_squared(candidate, origin)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best

## Farthest enemy still in range.
static func farthest(origin: Vector3, range_metres: float, candidates: Array[CombatActor]) -> CombatActor:
	var best: CombatActor = null
	var best_distance := -1.0
	for candidate in candidates:
		if not _targetable(candidate, origin, range_metres):
			continue
		var distance := _distance_squared(candidate, origin)
		if distance > best_distance:
			best = candidate
			best_distance = distance
	return best

## Highest CURRENT health in range (not max health); ties go to the nearest.
static func toughest(origin: Vector3, range_metres: float, candidates: Array[CombatActor]) -> CombatActor:
	var best: CombatActor = null
	var best_health := -INF
	var best_distance := INF
	for candidate in candidates:
		if not _targetable(candidate, origin, range_metres):
			continue
		var distance := _distance_squared(candidate, origin)
		if candidate.health > best_health or (candidate.health == best_health and distance < best_distance):
			best = candidate
			best_health = candidate.health
			best_distance = distance
	return best

## The `count` toughest enemies in range (highest current health first, ties to the nearest), skipping `excluded`.
static func toughest_many(origin: Vector3, range_metres: float, candidates: Array[CombatActor], count: int, excluded: Array = []) -> Array[CombatActor]:
	var pool: Array[CombatActor] = []
	for candidate in candidates:
		if _targetable(candidate, origin, range_metres) and not excluded.has(candidate):
			pool.append(candidate)
	pool.sort_custom(func(a: CombatActor, b: CombatActor) -> bool:
		if a.health != b.health:
			return a.health > b.health
		return _distance_squared(a, origin) < _distance_squared(b, origin))
	return pool.slice(0, maxi(count, 0))

## Enemies standing on the straight lane from `origin` through `through`, nearest first along it. `through` itself is not
## returned. A lane is `half_width` metres either side of the line (plus each body's own radius) and runs up to
## `range_metres` from `origin`. `include_front` adds the enemies between `origin` and `through`; otherwise only those behind
## it count. `limit` caps the result (negative means no cap).
static func on_lane(origin: Vector3, through: CombatActor, range_metres: float, half_width: float, candidates: Array[CombatActor],
		include_front: bool = false, limit: int = -1) -> Array[CombatActor]:
	var result: Array[CombatActor] = []
	var to_through := WorldGeometry.planar(through.position - origin)
	if to_through.length_squared() < .000001:
		return result
	var heading := to_through.normalized()
	var through_along := to_through.length()
	var found: Array = []
	for candidate in candidates:
		if candidate == through or not is_instance_valid(candidate) or candidate.dead:
			continue
		var offset := WorldGeometry.planar(candidate.position - origin)
		var along := offset.dot(heading)
		if along <= 0.0 or along > range_metres + candidate.hurtbox_radius():
			continue
		if not include_front and along <= through_along:
			continue
		if absf(offset.cross(heading).y) > half_width + candidate.hurtbox_radius():
			continue
		found.append([along, candidate])
	found.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for entry: Array in found:
		if limit >= 0 and result.size() >= limit:
			break
		result.append(entry[1])
	return result

## Nearest ranged or summoner enemy in range (`BACKLINE_TYPES`); the nearest enemy of any kind when none is in range.
static func backline(origin: Vector3, range_metres: float, candidates: Array[CombatActor]) -> CombatActor:
	var preferred: CombatActor = null
	var preferred_distance := INF
	var fallback: CombatActor = null
	var fallback_distance := INF
	for candidate in candidates:
		if not _targetable(candidate, origin, range_metres):
			continue
		var distance := _distance_squared(candidate, origin)
		if distance < fallback_distance:
			fallback = candidate
			fallback_distance = distance
		if candidate.enemy_type in BACKLINE_TYPES and distance < preferred_distance:
			preferred = candidate
			preferred_distance = distance
	return preferred if preferred else fallback

static func _targetable(candidate: CombatActor, origin: Vector3, range_metres: float) -> bool:
	return is_instance_valid(candidate) and not candidate.dead and candidate.overlaps_attack_range(origin, range_metres)

static func _distance_squared(candidate: CombatActor, origin: Vector3) -> float:
	return WorldGeometry.planar(candidate.position - origin).length_squared()

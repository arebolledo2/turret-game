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

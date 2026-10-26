class_name ShockwaveRing
extends RefCounted

## The gameplay half of a Quake pulse: a ring that runs outward from `origin` at `speed` metres per second until it reaches
## `max_radius`. An enemy is struck the first time the ring reaches any part of its body, so near enemies are hit before far
## ones and a crowd is shoved apart in order. Pure geometry: the caller decides what a strike does.
var origin := Vector3.ZERO
var max_radius: float = 0.0
var speed: float = 8.0
var radius: float = 0.0
## What each strike deals: the shot snapshot taken when the pulse was released.
var shot: CombatShot3D
## Enemy instance ids already struck by this ring.
var struck: Dictionary = {}
## Shared by every hit of this ring, so item rules that count distinct enemies in one attack (Follow-Through) see one swing.
var attack_targets: Dictionary = {}

func _init(at: Vector3, reach: float, travel_speed: float, pulse: CombatShot3D = null) -> void:
	origin = WorldGeometry.planar(at)
	max_radius = maxf(reach, 0.0)
	speed = maxf(travel_speed, .01)
	shot = pulse

## Moves the ring on by `delta` seconds and returns the enemies it reached this step, nearest first. Dead, freed and
## already struck enemies are skipped. `advance(0.0, ...)` strikes whatever the ring already overlaps (the turret's feet).
func advance(delta: float, candidates: Array[CombatActor]) -> Array[CombatActor]:
	radius = minf(max_radius, radius + speed * maxf(delta, 0.0))
	var reached: Array[CombatActor] = []
	for candidate in candidates:
		if not is_instance_valid(candidate) or candidate.dead or struck.has(candidate.get_instance_id()):
			continue
		if candidate.overlaps_attack_range(origin, radius):
			struck[candidate.get_instance_id()] = true
			reached.append(candidate)
	reached.sort_custom(func(a: CombatActor, b: CombatActor) -> bool:
		return WorldGeometry.planar(a.position - origin).length_squared() < WorldGeometry.planar(b.position - origin).length_squared())
	return reached

func is_finished() -> bool:
	return radius >= max_radius

## Seconds until the ring has swept the distance to `distance` from its origin (for tests and telegraph copy).
func seconds_to_reach(distance: float) -> float:
	return maxf(0.0, distance) / speed

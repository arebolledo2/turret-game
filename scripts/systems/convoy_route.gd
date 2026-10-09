class_name ConvoyRoute
extends RefCounted

## One round's convoy route: the core's start point followed by the doors it drives to, in order. Pure data plus a
## seeded generator, so the shop preview, the overlay and the mover all read the same instance.
var doors: PackedVector3Array = PackedVector3Array()
var pause_time: float = GameConstants.CONVOY_PAUSE_TIME

## Doors after the start: 2 on the first waves, growing to 4.
static func leg_count(wave: int) -> int:
	return clampi(2 + floori((maxi(wave, 1) - 1) / 2.0), 2, 4)

## Doors are random points inside the arena (minus the edge margin), each at least CONVOY_MIN_LEG from the last and
## preferring to swing to the other side of it, so the route zig-zags instead of drifting one way.
static func generate(rng: RandomNumberGenerator, wave: int, start: Vector3, half_arena: Vector2 = WorldGeometry.HALF_ARENA) -> ConvoyRoute:
	var route := ConvoyRoute.new()
	var bounds := half_arena - Vector2.ONE * GameConstants.CONVOY_EDGE_MARGIN
	route.doors.append(Vector3(start.x, 0.0, start.z))
	var last_dx := 0.0
	for _leg in leg_count(wave):
		var previous := route.doors[route.doors.size() - 1]
		var chosen := previous
		var farthest := -1.0
		# `chosen` tracks the farthest candidate seen, as the fallback when none meets the leg rules.
		for _attempt in 16:
			var candidate := Vector3(rng.randf_range(-bounds.x, bounds.x), 0.0, rng.randf_range(-bounds.y, bounds.y))
			var distance := candidate.distance_to(previous)
			if distance > farthest:
				farthest = distance
				chosen = candidate
			var swings := last_dx == 0.0 or signf(candidate.x - previous.x) != signf(last_dx)
			if distance >= GameConstants.CONVOY_MIN_LEG and swings:
				chosen = candidate
				break
		last_dx = chosen.x - previous.x
		route.doors.append(chosen)
	return route

func door_count() -> int:
	return doors.size()

func total_length() -> float:
	var length := 0.0
	for index in range(1, doors.size()):
		length += doors[index - 1].distance_to(doors[index])
	return length

## Seconds to drive the whole route at `speed`, including the pause at every intermediate door.
func duration(speed: float) -> float:
	var pauses := maxi(doors.size() - 2, 0)
	return total_length() / maxf(speed, .001) + pauses * pause_time

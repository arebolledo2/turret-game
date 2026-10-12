class_name ConvoyRoute
extends RefCounted

## One round's convoy route: the core's start point followed by the doors it drives to, in order. Pure data plus a
## seeded generator, so the shop preview, the overlay and the mover all read the same instance.
var doors: PackedVector3Array = PackedVector3Array()
var pause_time: float = GameConstants.CONVOY_PAUSE_TIME

## Doors after the start: 2 on the first waves, growing to 4.
static func leg_count(wave: int) -> int:
	return clampi(2 + floori((maxi(wave, 1) - 1) / 2.0), 2, 4)

## Wall entry and exit with interior waypoints, each at least CONVOY_MIN_LEG from the last.
## Prefer alternating directions so the journey crosses the room rather than drifting along an edge.
static func generate(rng: RandomNumberGenerator, wave: int, start: Vector3, half_arena: Vector2 = WorldGeometry.HALF_ARENA) -> ConvoyRoute:
	var route := ConvoyRoute.new()
	var bounds := half_arena - Vector2.ONE * GameConstants.CONVOY_EDGE_MARGIN
	route.doors.append(wall_point(start, bounds))
	var last_dx := 0.0
	for _leg in leg_count(wave):
		var previous := route.doors[route.doors.size() - 1]
		var chosen := previous
		var farthest := -1.0
		# `chosen` tracks the farthest candidate seen, as the fallback when none meets the leg rules.
		for _attempt in 16:
			var candidate := Vector3(rng.randf_range(-bounds.x, bounds.x), 0.0, rng.randf_range(-bounds.y, bounds.y))
			# Start and exit sit at wall doorways; intermediate navigation points remain inside.
			if _leg == leg_count(wave) - 1:
				candidate = exit_point(rng, route.doors[0], bounds)
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

## Sample only walls not touched by the entry; corner entries exclude both walls.
## Every candidate (including the distance fallback) therefore obeys the wall rule.
static func exit_point(rng: RandomNumberGenerator, entry: Vector3, bounds: Vector2) -> Vector3:
	var walls: Array[int] = []
	if not is_equal_approx(entry.x, -bounds.x): walls.append(0)
	if not is_equal_approx(entry.x, bounds.x): walls.append(1)
	if not is_equal_approx(entry.z, -bounds.y): walls.append(2)
	if not is_equal_approx(entry.z, bounds.y): walls.append(3)
	var wall := walls[rng.randi_range(0, walls.size() - 1)]
	# Keep exits away from corners so they belong unambiguously to one wall.
	if wall < 2:
		return Vector3(-bounds.x if wall == 0 else bounds.x, 0, rng.randf_range(-bounds.y * .95, bounds.y * .95))
	return Vector3(rng.randf_range(-bounds.x * .95, bounds.x * .95), 0, -bounds.y if wall == 2 else bounds.y)

## Project to the nearest inset wall, retaining an existing doorway exactly.
static func wall_point(point: Vector3, bounds: Vector2) -> Vector3:
	var result := Vector3(clampf(point.x, -bounds.x, bounds.x), 0, clampf(point.z, -bounds.y, bounds.y))
	if bounds.x - absf(result.x) < bounds.y - absf(result.z):
		result.x = bounds.x * (1.0 if result.x >= 0 else -1.0)
	else:
		result.z = bounds.y * (1.0 if result.z >= 0 else -1.0)
	return result

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

class_name TurretLayoutSolver
extends RefCounted

## Deterministic turret auto-layouts for the preparation phase; no gameplay RNG is consumed.
## `arrange` moves the world's turrets and returns those that had no saved position (restore mode only).
const TIGHT := 0
const BALANCED := 1
const AREA := 2
const SPREAD := 3
const SAVED := 4

var world: ArenaWorld
var new_turrets: Array[TurretActor] = []

func _init(owner_world: ArenaWorld) -> void:
	world = owner_world

## Greedy, deterministic coverage layout; no gameplay RNG is consumed.
func arrange(mode: int, saved_positions: Dictionary) -> Array[TurretActor]:
	new_turrets.clear()
	if mode == SAVED:
		_restore_layout(saved_positions)
		return new_turrets
	if mode == SPREAD:
		_spread_layout()
		return new_turrets
	var placed: Array[Dictionary] = []
	var zones := world.spawn_zones.centres
	var restrict_zones := FeatureFlagService.is_enabled(FeatureFlagService.RESTRICT_SPAWN_PLACEMENT)
	var focus := world.core.position if is_instance_valid(world.core) else Vector3.ZERO
	var remaining := maxi(1, world.turrets.size() - zones.size())
	for index in world.turrets.size():
		var turret := world.turrets[index]
		var reach := attack_reach(turret)
		var target := focus
		if index < zones.size():
			target = zones[index]
			if restrict_zones:
				var inward := WorldGeometry.planar(focus - zones[index]).normalized()
				if inward == Vector3.ZERO: inward = Vector3.RIGHT
				target += inward * (SpawnZones.RADIUS + TurretPlacement.EDGE_MARGIN + .3)
		elif world.convoy_mode and world.convoy_route:
			target = _route_position(float(index - zones.size() + 1) / (remaining + 1))
		elif mode != AREA:
			var angle := TAU * float(index - zones.size()) / remaining
			target += Vector3(cos(angle), 0, sin(angle)) * (2.0 if mode == TIGHT else maxf(1.2, reach * .6) if mode == BALANCED else reach)
		var best := Vector3.INF
		var score := INF
		if world.valid_placement(target, turret):
			best = target
			score = _layout_score(target, target, reach, placed, mode)
		# Search the whole arena so crowded zones and terrain always have a fallback.
		for x in range(-40, 41):
			for z in range(-22, 23):
				var at := Vector3(x * .5, 0, z * .5)
				var cost := _layout_score(at, target, reach, placed, mode)
				if cost >= score: continue
				if not world.valid_placement(at, turret): continue
				best = at
				score = cost
		if mode == AREA:
			# Exact tangencies fill the gaps a half-metre grid cannot resolve.
			for at in _coverage_candidates(target, reach, placed):
				var cost := _layout_score(at, target, reach, placed, mode)
				if cost < score and world.valid_placement(at, turret):
					best = at
					score = cost
			# Refine around obstacles and arena edges, where tangencies can be invalid.
			if best != Vector3.INF:
				for step: float in [.125, .03125]:
					for iteration in 8:
						var origin := best
						for direction in 8:
							var angle := TAU * direction / 8.0
							var at := origin + Vector3(cos(angle), 0, sin(angle)) * step
							var cost := _layout_score(at, target, reach, placed, mode)
							if cost < score and world.valid_placement(at, turret):
								best = at
								score = cost
						if best == origin: break
		if best == Vector3.INF:
			placed.append({"at": turret.position, "reach": reach})
			continue
		placed.append({"at": best, "reach": reach})
		if turret.position.distance_to(best) > .01:
			turret.position = best
			turret.reset_entrench()
			turret.invalidate_stats()
			turret.reset_physics_interpolation()
			world.telemetry.record_turret_move()
	return new_turrets

func _route_position(fraction: float) -> Vector3:
	var points := world.convoy_route.doors
	var length := 0.0
	for i in range(1, points.size()): length += points[i - 1].distance_to(points[i])
	var distance := fraction * length
	for i in range(1, points.size()):
		var leg := points[i - 1].distance_to(points[i])
		if distance <= leg: return points[i - 1].lerp(points[i], distance / maxf(.001, leg))
		distance -= leg
	return points[-1]

func attack_reach(turret: TurretActor) -> float:
	var stats := turret._current_view(0.0)
	var mode := TurretRegistry.get_fire_mode(turret.turret_type)
	return stats.range_metres * (stats.area_size if mode in [TurretRegistry.FIRE_PULSE, TurretRegistry.FIRE_FLAME] else 1.0)

func _layout_score(at: Vector3, target: Vector3, reach: float, placed: Array[Dictionary], mode: int) -> float:
	var score := at.distance_squared_to(target)
	if mode == TIGHT: return score
	# Only turret attack coverage counts; the core contributes no coverage radius.
	for other in placed:
		var separation := (reach + float(other.reach)) * (1.0 if mode == AREA else .6)
		var overlap := maxf(0, separation - at.distance_to(other.at))
		score += overlap * overlap * (10000.0 if mode == AREA else 20.0)
	return score

## Candidate centres tangent to one or two already placed attack circles.
func _coverage_candidates(target: Vector3, reach: float, placed: Array[Dictionary]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in placed.size():
		var centre: Vector3 = placed[i].at
		var radius := reach + float(placed[i].reach)
		var toward := WorldGeometry.planar(target - centre).normalized()
		if toward == Vector3.ZERO: toward = Vector3.RIGHT
		result.append(centre + toward * radius)
		for j in range(i):
			var other: Vector3 = placed[j].at
			var other_radius := reach + float(placed[j].reach)
			var distance := centre.distance_to(other)
			if distance < .001 or distance > radius + other_radius or distance < absf(radius - other_radius): continue
			var along := (radius * radius - other_radius * other_radius + distance * distance) / (2.0 * distance)
			var height := sqrt(maxf(0.0, radius * radius - along * along))
			var axis := (other - centre) / distance
			var perpendicular := Vector3(-axis.z, 0, axis.x)
			result.append(centre + axis * along + perpendicular * height)
			result.append(centre + axis * along - perpendicular * height)
	return result

## Restore stable IDs first, then stage new acquisitions near the centre.
func _restore_layout(saved_positions: Dictionary) -> void:
	var originals: Dictionary = {}
	for turret in world.turrets:
		originals[turret.turret_id] = turret.position
		# Temporarily remove old positions from planar collision checks.
		turret.position = Vector3(1000 + turret.turret_id * 2, 0, 1000)
	var ordered := world.turrets.duplicate()
	ordered.sort_custom(func(a: TurretActor, b: TurretActor) -> bool:
		return saved_positions.has(a.turret_id) and not saved_positions.has(b.turret_id))
	for turret: TurretActor in ordered:
		var target: Vector3 = saved_positions.get(turret.turret_id, Vector3.ZERO)
		var best := _nearest_valid(target, turret)
		if best == Vector3.INF: best = originals[turret.turret_id]
		_set_layout_position(turret, best, originals[turret.turret_id])
		if not saved_positions.has(turret.turret_id): new_turrets.append(turret)

func _nearest_valid(target: Vector3, turret: TurretActor) -> Vector3:
	if world.valid_placement(target, turret): return target
	var best := Vector3.INF
	var score := INF
	for at in _layout_grid():
		var cost := at.distance_squared_to(target)
		if cost < score and world.valid_placement(at, turret):
			best = at
			score = cost
	return best

func _layout_grid() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var extent := WorldGeometry.HALF_ARENA - Vector2.ONE * TurretPlacement.EDGE_MARGIN
	for x in range(int(ceil(extent.x * 2)) + 1):
		for z in range(int(ceil(extent.y * 2)) + 1):
			result.append(Vector3(minf(-extent.x + x, extent.x), 0, minf(-extent.y + z, extent.y)))
	return result

func _set_layout_position(turret: TurretActor, at: Vector3, original: Vector3) -> void:
	turret.position = at
	if at.distance_to(original) > .01:
		turret.reset_entrench()
		turret.invalidate_stats()
		world.telemetry.record_turret_move()
	turret.reset_physics_interpolation()

## Balance wall clearance against half the distance to the nearest turret.
## Start with evenly sized cells so four turrets occupy quadrant centres.
func _spread_layout() -> void:
	if world.turrets.is_empty(): return
	var originals: Dictionary = {}
	var targets: Array[Vector3] = []
	var count := world.turrets.size()
	var columns := 1
	var best_shape := INF
	for candidate in range(1, count + 1):
		var rows := ceili(float(count) / candidate)
		var aspect := WorldGeometry.HALF_ARENA.x * rows / (WorldGeometry.HALF_ARENA.y * candidate)
		var shape := absf(log(aspect)) + (candidate * rows - count) * 1.0
		if shape < best_shape:
			best_shape = shape
			columns = candidate
	var rows := ceili(float(count) / columns)
	for turret in world.turrets:
		originals[turret.turret_id] = turret.position
		turret.position = Vector3(1000 + turret.turret_id * 2, 0, 1000)
	for index in count:
		var row := index / columns
		var in_row := mini(columns, count - row * columns)
		var target := Vector3(
			((index % columns + .5) / in_row * 2.0 - 1.0) * WorldGeometry.HALF_ARENA.x,
			0, ((row + .5) / rows * 2.0 - 1.0) * WorldGeometry.HALF_ARENA.y)
		targets.append(target)
		var turret := world.turrets[index]
		var at := _nearest_valid(target, turret)
		turret.position = at if at != Vector3.INF else originals[turret.turret_id]
	var candidates := _layout_grid()
	for iteration in 4:
		for index in count:
			var turret := world.turrets[index]
			var best := turret.position
			var score := _spread_score(best, turret, targets[index])
			for at in candidates:
				var clearance := _spread_score(at, turret, targets[index])
				if _better_spread(at, clearance, best, score, targets[index]) and world.valid_placement(at, turret):
					best = at
					score = clearance
			for step: float in [.25, .0625]:
				for refinement in 8:
					var origin := best
					for direction in 8:
						var angle := TAU * direction / 8.0
						var at := origin + Vector3(cos(angle), 0, sin(angle)) * step
						var clearance := _spread_score(at, turret, targets[index])
						if _better_spread(at, clearance, best, score, targets[index]) and world.valid_placement(at, turret):
							best = at
							score = clearance
					if best == origin: break
			turret.position = best
	for turret in world.turrets: _set_layout_position(turret, turret.position, originals[turret.turret_id])

func _better_spread(at: Vector3, score: float, best: Vector3, best_score: float, target: Vector3) -> bool:
	return score > best_score + .001 or (absf(score - best_score) <= .001 and at.distance_squared_to(target) < best.distance_squared_to(target) - .001)

func _spread_score(at: Vector3, turret: TurretActor, target: Vector3) -> float:
	# Prefer evenly distributed cells over a staggered circle-packing arrangement.
	var scale := minf(WorldGeometry.HALF_ARENA.x, WorldGeometry.HALF_ARENA.y)
	return _spread_clearance(at, turret) - at.distance_squared_to(target) * .75 / scale

func _spread_clearance(at: Vector3, excluded: TurretActor) -> float:
	var wall := minf(WorldGeometry.HALF_ARENA.x - absf(at.x), WorldGeometry.HALF_ARENA.y - absf(at.z))
	# Equal personal space: each turret contributes half the gap between neighbours.
	return minf(wall, sqrt(_nearest_distance(at, excluded)) * .5)

func _nearest_distance(at: Vector3, excluded: TurretActor) -> float:
	var distance := INF
	for turret in world.turrets:
		if turret != excluded: distance = minf(distance, at.distance_squared_to(turret.position))
	return distance

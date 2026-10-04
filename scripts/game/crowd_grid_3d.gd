class_name CrowdGrid3D
extends RefCounted

## One position snapshot per physics tick avoids order-dependent neighbor queries.
## Only the surrounding nine cells are inspected for short-range separation.
const CELL_SIZE: float = 1.0
const SPACING: float = 0.72
var cells: Dictionary = {}
var positions: Dictionary = {}
var neighbor_counts: Dictionary = {}

func rebuild(actors: Array[CombatActor]) -> void:
	cells.clear()
	positions.clear()
	neighbor_counts.clear()
	for actor in actors:
		if not is_instance_valid(actor) or actor.dead:
			continue
		var cell := _cell(actor.position)
		if not cells.has(cell):
			cells[cell] = []
		cells[cell].append(actor)
		positions[actor.get_instance_id()] = actor.position

func separation(actor: CombatActor) -> Vector3:
	var origin: Vector3 = positions.get(actor.get_instance_id(), actor.position)
	var cell := _cell(origin)
	var push := Vector3.ZERO
	for x in range(-1, 2):
		for z in range(-1, 2):
			for other: CombatActor in cells.get(cell + Vector2i(x, z), []):
				if not is_instance_valid(other) or other == actor or other.dead:
					continue
				var offset := WorldGeometry.planar(origin - Vector3(positions[other.get_instance_id()]))
				var squared_distance := offset.length_squared()
				if squared_distance >= SPACING * SPACING:
					continue
				var distance := sqrt(squared_distance)
				if distance < .001:
					# Deterministic, opposite impulses even at exactly coincident spawns.
					offset = Vector3.RIGHT if actor.get_instance_id() < other.get_instance_id() else Vector3.LEFT
				else:
					offset /= distance
				push += offset * (1.0 - distance / SPACING)
	return push.limit_length(1.0) * 1.1

## Actors whose snapshot position is within `radius` of `origin` (planar), via the grid cells.
func query_radius(origin: Vector3, radius: float) -> Array[CombatActor]:
	var found: Array[CombatActor] = []
	var cell := _cell(origin)
	var extent := ceili(radius / CELL_SIZE)
	for x in range(-extent, extent + 1):
		for z in range(-extent, extent + 1):
			for other: CombatActor in cells.get(cell + Vector2i(x, z), []):
				if is_instance_valid(other) and not other.dead and WorldGeometry.planar(Vector3(positions[other.get_instance_id()]) - origin).length_squared() <= radius * radius:
					found.append(other)
	return found

func count_near(actor: CombatActor, radius: float) -> int:
	# Turrets share these counts within a physics tick instead of rescanning groups.
	if not neighbor_counts.has(radius):
		neighbor_counts[radius] = {}
	var counts: Dictionary = neighbor_counts[radius]
	var key := actor.get_instance_id()
	if counts.has(key):
		return int(counts[key])
	var origin: Vector3 = positions.get(actor.get_instance_id(), actor.position)
	var cell := _cell(origin)
	var extent := ceili(radius / CELL_SIZE)
	var count: int = 0
	for x in range(-extent, extent + 1):
		for z in range(-extent, extent + 1):
			for other: CombatActor in cells.get(cell + Vector2i(x, z), []):
				if is_instance_valid(other) and not other.dead:
					if WorldGeometry.planar(Vector3(positions[other.get_instance_id()]) - origin).length_squared() <= radius * radius:
						count += 1
	counts[key] = count
	return count

func _cell(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / CELL_SIZE), floori(at.z / CELL_SIZE))

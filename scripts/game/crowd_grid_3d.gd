class_name CrowdGrid3D
extends RefCounted

## One position snapshot per physics tick avoids order-dependent neighbor queries.
## Only the surrounding nine cells are inspected for short-range separation.
const CELL_SIZE: float = 1.0
const SPACING: float = 0.72
var cells: Dictionary = {}
var positions: Dictionary = {}
var cell_xz: Dictionary = {}
var neighbor_counts: Dictionary = {}

func rebuild(actors: Array[CombatActor]) -> void:
	cells.clear()
	positions.clear()
	cell_xz.clear()
	neighbor_counts.clear()
	for actor in actors:
		if not is_instance_valid(actor) or actor.dead:
			continue
		var cell := _cell(actor.position)
		if not cells.has(cell):
			cells[cell] = []
			cell_xz[cell] = PackedFloat32Array()
		cells[cell].append(actor)
		cell_xz[cell].append(actor.position.x)
		cell_xz[cell].append(actor.position.z)
		positions[actor.get_instance_id()] = actor.position

func separation(actor: CombatActor) -> Vector3:
	var origin: Vector3 = positions.get(actor.get_instance_id(), actor.position)
	var ox := origin.x
	var oz := origin.z
	var cell := _cell(origin)
	var push_x := 0.0
	var push_z := 0.0
	const spacing_sq := SPACING * SPACING
	for x in range(-1, 2):
		for z in range(-1, 2):
			var key := cell + Vector2i(x, z)
			if not cells.has(key):
				continue
			var members: Array = cells[key]
			var coords: PackedFloat32Array = cell_xz[key]
			for index in range(members.size()):
				var other: CombatActor = members[index]
				if other == actor or not is_instance_valid(other) or other.dead:
					continue
				var dx := ox - coords[index * 2]
				var dz := oz - coords[index * 2 + 1]
				var squared_distance := dx * dx + dz * dz
				if squared_distance >= spacing_sq:
					continue
				var distance := sqrt(squared_distance)
				if distance < .001:
					# Deterministic, opposite impulses even at exactly coincident spawns.
					dx = 1.0 if actor.get_instance_id() < other.get_instance_id() else -1.0
					dz = 0.0
				else:
					dx /= distance
					dz /= distance
				var weight := 1.0 - distance / SPACING
				push_x += dx * weight
				push_z += dz * weight
	return Vector3(push_x, 0.0, push_z).limit_length(1.0) * 1.1

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

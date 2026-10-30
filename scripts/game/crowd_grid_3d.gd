class_name CrowdGrid3D
extends RefCounted

## One position snapshot per physics tick avoids order-dependent neighbor queries.
## Only the surrounding nine cells are inspected for short-range separation.
const CELL_SIZE: float = 1.0
const SPACING: float = 0.72
var cells: Dictionary = {}
var positions: Dictionary = {}
var cell_xz: Dictionary = {}
## Per-cell packed (body radius, inverse mass) pairs, parallel to `cell_xz`, so overlap resolution never touches actors.
var cell_body: Dictionary = {}
var neighbor_counts: Dictionary = {}
var max_hurtbox_radius: float = 0.0

func rebuild(actors: Array[CombatActor]) -> void:
	cells.clear()
	positions.clear()
	cell_xz.clear()
	cell_body.clear()
	neighbor_counts.clear()
	max_hurtbox_radius = 0.0
	for actor in actors:
		if not is_instance_valid(actor) or actor.dead:
			continue
		max_hurtbox_radius = maxf(max_hurtbox_radius, actor.hurtbox_radius())
		var cell := _cell(actor.position)
		if not cells.has(cell):
			cells[cell] = []
			cell_xz[cell] = PackedFloat32Array()
			cell_body[cell] = PackedFloat32Array()
		cells[cell].append(actor)
		cell_xz[cell].append(actor.position.x)
		cell_xz[cell].append(actor.position.z)
		cell_body[cell].append(actor.body_scale * GameConstants.ENEMY_BODY_RADIUS)
		cell_body[cell].append(_inverse_mass(actor))
		positions[actor.get_instance_id()] = actor.position

## True when a living actor's body overlaps the circle of `reach` metres round `centre`: `query_radius` with hurtboxes, but it
## allocates nothing and stops at the first, so a mine can ask it every tick. Only the cells the circle touches are read, however
## many actors the field holds.
func any_within(centre: Vector3, reach: float) -> bool:
	if cells.is_empty():
		return false
	var margin := maxf(reach, 0.0) + max_hurtbox_radius
	var low := _cell(centre - Vector3(margin, 0.0, margin))
	var high := _cell(centre + Vector3(margin, 0.0, margin))
	for x in range(low.x, high.x + 1):
		for z in range(low.y, high.y + 1):
			var members: Array = cells.get(Vector2i(x, z), [])
			for member: CombatActor in members:
				if is_instance_valid(member) and not member.dead and member.overlaps_attack_range(centre, reach):
					return true
	return false

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

## Hard backstop to `separation`: pushes overlapping bodies apart in position space (mass-weighted), and pushes
## enemies out of fixed circles `[{position, radius}]` (turrets, core). Run right after `rebuild`; corrections are
## accumulated first and applied together so the result does not depend on actor order.
func resolve_overlaps(obstacles: Array = []) -> void:
	var shifts: Dictionary = {}
	const FORWARD := [Vector2i(0, 0), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]
	for cell: Vector2i in cells:
		var members: Array = cells[cell]
		var coords: PackedFloat32Array = cell_xz[cell]
		var body: PackedFloat32Array = cell_body[cell]
		for offset: Vector2i in FORWARD:
			var other_key: Vector2i = cell + offset
			if not cells.has(other_key):
				continue
			var others: Array = cells[other_key]
			var other_coords: PackedFloat32Array = cell_xz[other_key]
			var other_body: PackedFloat32Array = cell_body[other_key]
			var same_cell := offset == Vector2i.ZERO
			for i in range(members.size()):
				var inv_a := body[i * 2 + 1]
				var radius_a := body[i * 2]
				var ax := coords[i * 2]
				var az := coords[i * 2 + 1]
				for j in range(i + 1 if same_cell else 0, others.size()):
					var min_distance := radius_a + other_body[j * 2]
					var dx: float = ax - other_coords[j * 2]
					var dz: float = az - other_coords[j * 2 + 1]
					var squared_distance := dx * dx + dz * dz
					if squared_distance >= min_distance * min_distance:
						continue
					var inv_b := other_body[j * 2 + 1]
					var inv_total := inv_a + inv_b
					if inv_total <= 0.0:
						continue
					var a: CombatActor = members[i]
					var b: CombatActor = others[j]
					var distance := sqrt(squared_distance)
					if distance < .001:
						dx = 1.0 if a.get_instance_id() < b.get_instance_id() else -1.0
						dz = 0.0
					else:
						dx /= distance
						dz /= distance
					var correction := (min_distance - distance) * GameConstants.SEPARATION_MAX_CORRECTION / inv_total
					_add_shift(shifts, a, dx * correction * inv_a, dz * correction * inv_a)
					_add_shift(shifts, b, -dx * correction * inv_b, -dz * correction * inv_b)
	for obstacle: Dictionary in obstacles:
		var at: Vector3 = obstacle["position"]
		var obstacle_cell := _cell(at)
		var extent := ceili((float(obstacle["radius"]) + GameConstants.ENEMY_BODY_RADIUS * 1.6) / CELL_SIZE)
		for x in range(-extent, extent + 1):
			for z in range(-extent, extent + 1):
				var key := obstacle_cell + Vector2i(x, z)
				if not cells.has(key):
					continue
				var members: Array = cells[key]
				var coords: PackedFloat32Array = cell_xz[key]
				var body: PackedFloat32Array = cell_body[key]
				for index in range(members.size()):
					if body[index * 2 + 1] <= 0.0:
						continue
					var min_distance := float(obstacle["radius"]) + body[index * 2]
					var dx: float = coords[index * 2] - at.x
					var dz: float = coords[index * 2 + 1] - at.z
					var squared_distance := dx * dx + dz * dz
					if squared_distance >= min_distance * min_distance:
						continue
					var actor: CombatActor = members[index]
					var distance := sqrt(squared_distance)
					if distance < .001:
						dx = 1.0
						dz = 0.0
					else:
						dx /= distance
						dz /= distance
					var push := (min_distance - distance) * GameConstants.SEPARATION_MAX_CORRECTION
					_add_shift(shifts, actor, dx * push, dz * push)
	for actor: CombatActor in shifts:
		var shift: Vector2 = shifts[actor]
		actor.position = WorldGeometry.clamp_position(actor.position + Vector3(shift.x, 0.0, shift.y))
		positions[actor.get_instance_id()] = actor.position

## Stationary drops and charging (windup/dash) enemies are immovable; everyone else moves in proportion to 1/mass.
func _inverse_mass(actor: CombatActor) -> float:
	if actor.stationary:
		return 0.0
	if actor.brain and actor.brain.pounce and actor.brain.pounce.phase in [ChargeController3D.Phase.WINDUP, ChargeController3D.Phase.DASH]:
		return 0.0
	if actor.charge and actor.charge.phase in [ChargeController3D.Phase.WINDUP, ChargeController3D.Phase.DASH]:
		return 0.0
	return 1.0 / maxf(actor.mass, .1)

func _add_shift(shifts: Dictionary, actor: CombatActor, x: float, z: float) -> void:
	shifts[actor] = Vector2(x, z) + shifts.get(actor, Vector2.ZERO)

## Planar snapshot query; optionally include bodies overlapping the radius, expanding the cell search too.
func query_radius(origin: Vector3, radius: float, include_hurtboxes: bool = false) -> Array[CombatActor]:
	var found: Array[CombatActor] = []
	var cell := _cell(origin)
	var extent := ceili((radius + (max_hurtbox_radius if include_hurtboxes else 0.0)) / CELL_SIZE)
	for x in range(-extent, extent + 1):
		for z in range(-extent, extent + 1):
			for other: CombatActor in cells.get(cell + Vector2i(x, z), []):
				if is_instance_valid(other) and not other.dead and WorldGeometry.planar(Vector3(positions[other.get_instance_id()]) - origin).length_squared() <= pow(radius + (other.hurtbox_radius() if include_hurtboxes else 0.0), 2):
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

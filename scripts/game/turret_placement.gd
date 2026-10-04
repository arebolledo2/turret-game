class_name TurretPlacement
extends RefCounted

## Turret placement rules and the carry/place interaction. `ArenaWorld` exposes `carried_turret` for actors and tests.
const PICKUP_RANGE: float = 1.25
const DROP_DISTANCE: float = .9
const MIN_SPACING: float = 1.0
const EDGE_MARGIN: float = .55
var world: ArenaWorld
var carried: TurretActor
var carry_origin: Vector3

## First free spot on a grid around the player (the origin when no player exists yet).
func find_placement() -> Vector3:
	var origin := WorldGeometry.planar(world.player.position) if is_instance_valid(world.player) else Vector3.ZERO
	for z: float in [-1.0, 1.0, -3.0, 3.0]:
		for x: float in [0.0, -2.0, 2.0, -4.0, 4.0, -6.0, 6.0]:
			var candidate := origin + Vector3(x, 0, z)
			if valid_placement(candidate):
				return candidate
	return Vector3.INF

func valid_placement(at: Vector3, excluding: TurretActor = null) -> bool:
	if WorldGeometry.clamp_position(at, EDGE_MARGIN).distance_squared_to(at) > .0001:
		return false
	for turret in world.turrets:
		if turret != excluding and WorldGeometry.planar(turret.position - at).length() < MIN_SPACING:
			return false
	return true

## Places the carried turret in front of the player, or picks up the nearest one within reach.
func interact() -> bool:
	if not world.is_combat():
		return false
	if is_instance_valid(carried):
		var forward := -world.player.visual.global_basis.z
		var at := WorldGeometry.planar(world.player.position + forward * DROP_DISTANCE)
		if not valid_placement(at, carried):
			world.message = "Move clear of the edge or another turret."
			return false
		carried.position = at
		carried.carried = false
		carried = null
		world.message = "Turret deployed."
		return true
	var nearest: TurretActor = null
	var distance := PICKUP_RANGE
	for turret in world.turrets:
		var candidate_distance := turret.position.distance_to(world.player.position)
		if candidate_distance < distance:
			distance = candidate_distance
			nearest = turret
	if nearest:
		carried = nearest
		carry_origin = nearest.position
		nearest.carried = true
		world.message = "Carrying turret · press E / A to place"
		return true
	return false

## Returns a carried turret to where it was picked up (wave end).
func drop_carried() -> void:
	if is_instance_valid(carried):
		carried.carried = false
		carried.position = carry_origin
	carried = null

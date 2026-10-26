class_name GroundZone
extends RefCounted

## One enemy-only ground zone (S7): a patch of floor that lasts `duration` seconds and slows the enemies standing in it.
## `GroundZones` owns the list, the clock and the visual; this is the shape and its numbers. A zone is a circle or a line
## (an oriented rectangle, for fissures). Everything is planar: the y of a point is ignored.
enum Shape {CIRCLE, LINE}

## Pooled-visual looks (see `ground_zone.gdshader`).
const STYLE_DISC: String = "disc"
const STYLE_RIFT: String = "rift"

var shape: Shape = Shape.CIRCLE
var centre := Vector3.ZERO
## CIRCLE: radius in metres.
var radius: float = 0.0
## LINE: unit heading along the zone, half its length and half its width.
var direction := Vector3(0, 0, -1)
var half_length: float = 0.0
var half_width: float = 0.0
var duration: float = 1.0
var age: float = 0.0
## Share of movement speed taken from enemies inside (0 to GROUND_ZONE_MAX_SLOW); 0 for a zone that only marks the floor.
var slow: float = 0.0
## Turret that laid it (`TurretActor.turret_id`), 0 for none.
var source_id: int = 0
var style: String = STYLE_DISC
var tint := Color("6df0b0")
## The pooled visual currently showing this zone (null once released).
var node: MeshInstance3D

## True when `point` (or any part of a body of radius `margin` standing there) is inside the zone.
func contains(point: Vector3, margin: float = 0.0) -> bool:
	var offset := WorldGeometry.planar(point - centre)
	if shape == Shape.CIRCLE:
		var reach := radius + margin
		return offset.length_squared() <= reach * reach
	return absf(offset.dot(direction)) <= half_length + margin and absf(offset.cross(direction).y) <= half_width + margin

## The nearest point on the zone's axis (the centre for a circle): knockback from a fissure pushes away from it.
func closest_point(point: Vector3) -> Vector3:
	if shape == Shape.CIRCLE:
		return centre
	var along := clampf(WorldGeometry.planar(point - centre).dot(direction), -half_length, half_length)
	return centre + direction * along

## Planar end points of a line's axis.
func start_point() -> Vector3:
	return centre - direction * half_length

func end_point() -> Vector3:
	return centre + direction * half_length

func remaining() -> float:
	return maxf(0.0, duration - age)

func is_expired() -> bool:
	return age >= duration

## Elapsed share of the zone's life, 0 to 1.
func fraction() -> float:
	return clampf(age / maxf(duration, .001), 0.0, 1.0)

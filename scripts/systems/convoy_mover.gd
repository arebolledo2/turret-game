class_name ConvoyMover
extends RefCounted

## Drives a point along a ConvoyRoute: straight to each door, pausing at every intermediate one. The speed is passed in
## each step so item changes apply at once (they can only change in the shop anyway).
var route: ConvoyRoute
var position: Vector3 = Vector3.ZERO
var heading: Vector3 = Vector3.ZERO
## Index of the door being driven to (1 = the first door after the start).
var target_index: int = 1
var pause_left: float = 0.0
var finished: bool = false

func start(new_route: ConvoyRoute) -> void:
	route = new_route
	position = route.doors[0]
	heading = Vector3.ZERO
	target_index = 1
	pause_left = 0.0
	finished = route.doors.size() < 2

## Advances by `delta` seconds and returns the new position.
func advance(delta: float, speed: float) -> Vector3:
	if finished or speed <= 0.0:
		return position
	var remaining := delta
	while remaining > 0.0 and not finished:
		if pause_left > 0.0:
			var waited := minf(pause_left, remaining)
			pause_left -= waited
			remaining -= waited
			continue
		var to_door := route.doors[target_index] - position
		var distance := to_door.length()
		if distance > 0.0:
			heading = to_door / distance
		var step := speed * remaining
		if step < distance:
			position += heading * step
			remaining = 0.0
		else:
			position = route.doors[target_index]
			remaining -= distance / speed
			target_index += 1
			if target_index >= route.doors.size():
				finished = true
			else:
				pause_left = route.pause_time
	return position

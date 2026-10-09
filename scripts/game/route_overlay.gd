class_name RouteOverlay
extends Node3D

## Convoy mode: draws the planned route on the ground - a line per leg, a ring and number at every door and an amber
## ring at the final door. Legs already driven dim. Rebuilt only when the route or the core's target door changes.
const LINE_WIDTH: float = .14
const DOOR_RADIUS: float = 1.0
const FINAL_DOOR_RADIUS: float = 1.5
const UPCOMING := Color("58ece1")
const DRIVEN := Color("2b5963")
const FINAL := Color("f4b942")

var world: ArenaWorld
var _built_route: ConvoyRoute
var _built_progress: int = -1

func _process(_delta: float) -> void:
	var route := world.convoy_route if is_instance_valid(world) else null
	var progress := _progress(route)
	if route == _built_route and progress == _built_progress:
		return
	_built_route = route
	_built_progress = progress
	_rebuild(route, progress)

## Index of the door the core is driving to; 1 (nothing driven yet) when this route is only planned.
func _progress(route: ConvoyRoute) -> int:
	if route and world.convoy_mover and world.convoy_mover.route == route:
		return world.convoy_mover.target_index
	return 1

func _rebuild(route: ConvoyRoute, progress: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if not route:
		return
	var last := route.doors.size() - 1
	for index in range(1, route.doors.size()):
		var from := route.doors[index - 1]
		var to := route.doors[index]
		var driven := index < progress
		var final := index == last
		var colour := DRIVEN if driven else (FINAL if final else UPCOMING)
		var span := to - from
		if span.length() > .01:
			var line := WorldGeometry.box(self, Vector3(LINE_WIDTH, .02, span.length()), (from + to) * .5 + Vector3(0, .03, 0), WorldGeometry.material(colour, true))
			line.rotation.y = atan2(span.x, span.z)
			line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		WorldGeometry.ring(self, FINAL_DOOR_RADIUS if final else DOOR_RADIUS, colour).position = to + Vector3(0, .04, 0)
		var label := Label3D.new()
		label.text = "END" if final else str(index)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.pixel_size = .01
		label.font_size = 48
		label.modulate = colour
		label.position = to + Vector3(0, 1.2, 0)
		add_child(label)

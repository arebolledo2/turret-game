class_name RouteOverlay
extends Node3D

## Fine dashed navigation marks, a highlighted next leg and inset wall doorways.
const UPCOMING := Color("69b8b4")
const FINAL := Color("c7ad76")
var world: ArenaWorld
var _built_route: ConvoyRoute
var _built_progress: int = -1

func _process(_delta: float) -> void:
	var route := world.convoy_route if is_instance_valid(world) else null
	var progress := _progress(route)
	if route == _built_route and progress == _built_progress: return
	_built_route = route
	_built_progress = progress
	_rebuild(route, progress)

func _progress(route: ConvoyRoute) -> int:
	if route and world.convoy_mover and world.convoy_mover.route == route:
		return world.convoy_mover.target_index
	return 1

func _ink(colour: Color, opacity: float) -> StandardMaterial3D:
	var material := WorldGeometry.material(colour, true)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = opacity
	material.emission_enabled = false
	material.no_depth_test = false
	return material

func _rebuild(route: ConvoyRoute, progress: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if not route: return
	var last := route.doors.size() - 1
	for index in range(maxi(1, progress), route.doors.size()):
		var from := route.doors[index - 1]
		var to := route.doors[index]
		var active := index == progress
		var colour := FINAL if index == last else UPCOMING
		var span := to - from
		var length := span.length()
		if length > .01:
			var mesh := BoxMesh.new()
			mesh.size = Vector3(.035, .008, .24)
			mesh.material = _ink(colour, .48 if active else .16)
			var marks := MultiMesh.new()
			marks.transform_format = MultiMesh.TRANSFORM_3D
			marks.mesh = mesh
			marks.instance_count = maxi(1, floori(length / .65))
			for dash in marks.instance_count:
				var at := from.lerp(to, (dash + .5) / marks.instance_count) + Vector3(0, .035, 0)
				marks.set_instance_transform(dash, Transform3D(Basis(Vector3.UP, atan2(span.x, span.z)), at))
			var line := MultiMeshInstance3D.new()
			line.multimesh = marks
			line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(line)
		if index != last:
			var dial := GroundDial.create(self, .36, Color(colour, .5 if active else .2), true)
			dial.position = to + Vector3(0, .04, 0)
			GroundDial.update(dial, 1.0, false, 4)
	_door(route.doors[0], false, false)
	_door(route.doors[last], true, progress <= last)

func _door(at: Vector3, exit: bool, active: bool) -> void:
	var bounds := WorldGeometry.HALF_ARENA - Vector2.ONE * GameConstants.CONVOY_EDGE_MARGIN
	var side_wall := absf(at.x) >= bounds.x - .01
	var frame := Node3D.new()
	frame.position = at + Vector3(0, .04, 0)
	frame.rotation.y = PI * .5 if side_wall else 0.0
	add_child(frame)
	var material := _ink(FINAL if exit else UPCOMING, .6 if active else .2)
	# A doorway threshold with short end brackets, rather than a large floating circle.
	for x: float in [-1.0, 1.0]:
		var bracket := WorldGeometry.box(frame, Vector3(.055, .01, .65), Vector3(x, 0, 0), material)
		bracket.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var threshold := WorldGeometry.box(frame, Vector3(2.0, .01, .045), Vector3.ZERO, material)
	threshold.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

class_name RoomBackWall
extends RefCounted

## The back wall of the room (see `ArenaRoom`): plinth, sloped sill, window and door bays, pillars and coping.
## Builds into the room's shared `RoomMeshKit` and materials; `ArenaRoom.build` creates one of these per part after the materials exist.
var room: ArenaRoom
var _kit: RoomMeshKit
var _hull: ShaderMaterial
var _brass: ShaderMaterial
var _frame: StandardMaterial3D
var _paint: StandardMaterial3D
var _lamp: StandardMaterial3D
var _enamel: StandardMaterial3D
var _glow: StandardMaterial3D

func _init(owner: ArenaRoom) -> void:
	room = owner
	_kit = owner._kit
	_hull = owner.hull
	_brass = owner._brass
	_frame = owner._frame
	_paint = owner._paint
	_lamp = owner._lamp
	_enamel = owner._enamel
	_glow = owner._glow

func build(inner: Vector2) -> void:
	var z_face := -inner.y
	var width := inner.x * 2.0
	var origin := Vector3(0.0, 0.0, z_face)
	var out := Vector3.FORWARD
	_kit.extrude([PackedVector2Array([Vector2(0, 0), Vector2(0, 0.35)]), PackedVector2Array([Vector2(0, ArenaRoom.LINTEL_BOTTOM), Vector2(0, ArenaRoom.LINTEL_TOP)])],
		_hull, origin, out, Vector3.RIGHT, width)
	# The sill slopes up and away, so it shows as a lit ledge. The coping has a rounded nose, a flat top and a raised rail.
	var coping := PackedVector2Array([Vector2(-0.06, ArenaRoom.LINTEL_TOP), Vector2(-0.06, 2.56)])
	coping.append_array(RoomMeshKit.arc(Vector2(0.0, 2.56), 0.06, 180.0, 90.0, 4))
	coping.append_array(PackedVector2Array([Vector2(0.34, 2.62), Vector2(0.38, ArenaRoom.BACK_HEIGHT), Vector2(0.58, ArenaRoom.BACK_HEIGHT),
		Vector2(0.62, 2.62), Vector2(ArenaRoom.BACK_TOP_DEPTH, 2.62)]))
	_kit.extrude([PackedVector2Array([Vector2(0, 0.35), Vector2(0.05, 0.4), Vector2(0.45, ArenaRoom.SILL_HEIGHT)]), coping],
		_brass, origin, out, Vector3.RIGHT, width)
	_kit.add_box(_enamel, Vector3(width, 0.008, 0.08), Vector3(0.0, 2.62, z_face - 0.8)) # inlay on the flat of the coping
	var count := maxi(2, roundi(width / ArenaRoom.PILLAR_PITCH))
	var pitch := width / count
	var depth := ArenaRoom.BACK_TOP_DEPTH
	var zc := z_face - depth * 0.5
	for index in count + 1:
		var x := -inner.x + index * pitch
		# The end pillars stand half inside the corner towers, whose lids are lower than the pillar tops: build the half in the wall.
		var shaft := ArenaRoom.PILLAR_WIDTH * 0.5 if index == 0 or index == count else ArenaRoom.PILLAR_WIDTH
		var shaft_x := x + (ArenaRoom.PILLAR_WIDTH - shaft) * 0.5 * (1.0 if index == 0 else (-1.0 if index == count else 0.0))
		_kit.add_box(_frame, Vector3(shaft, ArenaRoom.LINTEL_TOP + ArenaRoom.HULL_DEPTH, depth), Vector3(shaft_x, -ArenaRoom.HULL_DEPTH, zc))
		_kit.add_box(_hull, Vector3(0.78, 0.2, depth + 0.06), Vector3(x, 0.0, zc + 0.03)) # plinth step
		_kit.add_box(_brass, Vector3(ArenaRoom.PILLAR_WIDTH + 0.08, 0.08, depth + 0.04), Vector3(x, ArenaRoom.SILL_HEIGHT - 0.08, zc + 0.02))
		# Corbelled capital under the lintel.
		_kit.add_box(_brass, Vector3(0.7, 0.1, depth + 0.04), Vector3(x, ArenaRoom.LINTEL_BOTTOM - 0.48, zc + 0.02))
		_kit.add_box(_brass, Vector3(0.82, 0.18, depth + 0.06), Vector3(x, ArenaRoom.LINTEL_BOTTOM - 0.38, zc + 0.03))
		_kit.add_box(_brass, Vector3(0.94, 0.1, depth + 0.08), Vector3(x, ArenaRoom.LINTEL_BOTTOM - 0.2, zc + 0.04))
		# Two flutes either side of the lamp.
		for flute: float in [-0.19, 0.19]:
			_kit.add_box(_paint, Vector3(0.06, 1.0, 0.03), Vector3(x + flute, 0.7, z_face - 0.005), ArenaRoom.DARK)
		# Lamp: brass housing around a glass lens, a cone of light washing down the pillar from it, a halo round the lens and a
		# softer pool on the floor below.
		var tone := room.lamp_tone(index * 1.7 + 0.3)
		_kit.add_box(_brass, Vector3(0.2, 0.6, 0.04), Vector3(x, 1.05, z_face - 0.01))
		_kit.add_box(_lamp, Vector3(0.12, 0.46, 0.03), Vector3(x, 1.12, z_face + 0.015), tone)
		_kit.glow_cone(Vector3(x, 1.0, z_face + 0.075), Vector3.DOWN, Vector3.RIGHT, 0.95, 0.1, 0.6, 0.4 * tone.v)
		_kit.glow_quad(Vector3(x, 1.12, z_face + 0.12), Vector3.RIGHT, ArenaRoom.SCREEN_UP, 0.28, 0.28, 0.3 * tone.v)
		_kit.glow_quad(Vector3(x, 0.012, z_face + 0.55), Vector3.RIGHT, Vector3.BACK, 0.65, 0.55, 0.14 * tone.v)
		_capital_detail(index, x, z_face)
		if index < count:
			_build_back_bay(index, count, x + pitch * 0.5, pitch, z_face)
	# A dentil row under the cornice, and bolts along the raised rail.
	var step := 0.16
	for index in int(width / step):
		_kit.add_box(_brass, Vector3(0.08, 0.06, 0.05), Vector3(-inner.x + 0.1 + index * step, ArenaRoom.LINTEL_TOP - 0.07, z_face - 0.01))
	for index in int(width / 0.4):
		_kit.add_box(_brass, Vector3(0.06, 0.02, 0.06), Vector3(-inner.x + 0.2 + index * 0.4, ArenaRoom.BACK_HEIGHT, z_face - 0.48))
		if index % 2 == 0:
			_kit.add_box(_paint, Vector3(0.012, 0.004, 0.2), Vector3(-inner.x + 0.4 + index * 0.4, ArenaRoom.BACK_HEIGHT + 0.001, z_face - 0.48), ArenaRoom.DARK)

## One window bay between two pillars: an open window with a mullion and transom, a bulkhead door in the middle, or a lit
## alcove with a slowly turning flywheel.
func _build_back_bay(index: int, count: int, bay_x: float, pitch: float, z_face: float) -> void:
	var span := pitch - ArenaRoom.PILLAR_WIDTH - 0.02
	var open_height := ArenaRoom.LINTEL_BOTTOM - ArenaRoom.SILL_HEIGHT
	_bay_trim(index, bay_x, span, z_face)
	if index == count / 2:
		_kit.add_box(_hull, Vector3(span, open_height, 0.1), Vector3(bay_x, ArenaRoom.SILL_HEIGHT, z_face - 0.4))
		for stripe in 4: # a coral and cream band across the foot of the door
			_kit.add_box(_paint, Vector3(span - 0.1, 0.1, 0.02), Vector3(bay_x, 0.7 + stripe * 0.1, z_face - 0.345), ArenaRoom.CORAL if stripe % 2 == 0 else ArenaRoom.CREAM)
		_kit.add_box(_brass, Vector3(0.3, 0.3, 0.05), Vector3(bay_x + span * 0.3, 1.2, z_face - 0.35))
		_kit.add_box(_paint, Vector3(0.18, 0.18, 0.06), Vector3(bay_x + span * 0.3, 1.26, z_face - 0.34), ArenaRoom.DARK)
		_kit.add_box(_brass, Vector3(0.95, 0.14, 0.04), Vector3(bay_x, ArenaRoom.LINTEL_BOTTOM + 0.12, z_face + 0.005)) # sign
		_kit.add_box(_lamp, Vector3(0.8, 0.08, 0.03), Vector3(bay_x, ArenaRoom.LINTEL_BOTTOM + 0.15, z_face + 0.03), Color("ffc080"))
		_door_detail(bay_x, span, open_height, z_face)
	elif index == 1 or index == count - 2:
		_kit.add_box(_paint, Vector3(span, open_height, 0.08), Vector3(bay_x, ArenaRoom.SILL_HEIGHT, z_face - 0.55), Color("1a1410"))
		_kit.add_box(_lamp, Vector3(span - 0.3, open_height - 0.3, 0.02), Vector3(bay_x, ArenaRoom.SILL_HEIGHT + 0.15, z_face - 0.5), Color("a8742c"))
		_kit.glow_quad(Vector3(bay_x, 0.013, z_face + 0.6), Vector3.RIGHT, Vector3.BACK, span * 0.5, 0.7, 0.14)
		var wheel_kit := RoomMeshKit.new()
		wheel_kit.add_cylinder(_brass, Vector3.ZERO, Vector3.BACK, 0.55, 0.05, 20)
		wheel_kit.add_cylinder(_frame, Vector3.ZERO, Vector3.BACK, 0.46, 0.07, 20)
		for spoke in 6:
			wheel_kit.add_oriented_box(_brass, Vector3(1.0, 0.07, 0.06), Vector3.ZERO, Basis(Vector3.BACK, spoke * PI / 6.0), Color.WHITE)
		wheel_kit.add_cylinder(_brass, Vector3.ZERO, Vector3.BACK, 0.12, 0.1, 10)
		var pivot := Node3D.new()
		pivot.name = "Flywheel%d" % index
		pivot.position = Vector3(bay_x, ArenaRoom.SILL_HEIGHT + open_height * 0.5, z_face - 0.45)
		room.add_child(pivot)
		wheel_kit.flush(pivot, ArenaRoom.ROOM_LAYERS, _glow)
		room._flywheels.append(pivot)
	else:
		_kit.add_box(_brass, Vector3(0.05, open_height, 0.05), Vector3(bay_x, ArenaRoom.SILL_HEIGHT, z_face - 0.4))
		_kit.add_box(_brass, Vector3(span, 0.05, 0.05), Vector3(bay_x, 1.3, z_face - 0.4))

## What every back bay shares: an enamel inset on the sloped sill (it rises 0.18 m over 0.4 m, so the panel leans with it, framed by
## four rivets) and a pair of cables sagging across the lintel from pillar to pillar, in colours that stand out from the hull.
func _bay_trim(index: int, bay_x: float, span: float, z_face: float) -> void:
	var lean := Vector3(0.0, 0.911, 0.411) # the sill's normal
	var run := Vector3(0.0, 0.411, -0.911) # up the sill, away from the camera
	var panel_width := span * (0.72 + 0.06 * ((index * 7) % 3))
	var panel_at := Vector3(bay_x, 0.49, z_face - 0.25)
	var panel_basis := Basis(Vector3.RIGHT, lean, run)
	_kit.add_oriented_box(_enamel, Vector3(panel_width, 0.012, 0.25), panel_at + lean * 0.006, panel_basis)
	for end: float in [-1.0, 1.0]:
		for rivet: float in [-1.0, 1.0]:
			_kit.add_oriented_box(_brass, Vector3(0.045, 0.02, 0.045), panel_at + Vector3(end * (panel_width * 0.5 - 0.07), 0.0, 0.0) + run * rivet * 0.085 + lean * 0.01, panel_basis)
	var cable_colors: Array[Color] = [ArenaRoom.CORAL, ArenaRoom.CREAM, Color("2f9a9a"), Color("c8a040")]
	for cable in 2:
		var points := PackedVector3Array()
		var sag := 0.13 + 0.03 * cable
		for step in 9:
			var t := step / 8.0
			points.append(Vector3(bay_x + (t - 0.5) * (span - 0.06), 2.4 - cable * 0.07 - sag * 4.0 * t * (1.0 - t), z_face + 0.04 + cable * 0.012))
		_kit.add_tube(_paint, points, 0.016, 5, cable_colors[(index + cable * 2) % cable_colors.size()])
	for clip: float in [-1.0, 1.0]: # a clamp where each cable pair meets the pillar
		_kit.add_box(_brass, Vector3(0.06, 0.2, 0.05), Vector3(bay_x + clip * (span * 0.5 - 0.02), 2.2, z_face + 0.03))

## Extra capital detail so the pillars do not repeat: every third one gets volutes (scrolls) at the ends, the next an enamel
## diamond, the rest keep the plain corbels.
func _capital_detail(index: int, x: float, z_face: float) -> void:
	var y := ArenaRoom.LINTEL_BOTTOM - 0.29
	match index % 3:
		0:
			for scroll: float in [-1.0, 1.0]:
				_kit.add_cylinder(_brass, Vector3(x + scroll * 0.37, y, z_face + 0.07), Vector3.BACK, 0.08, 0.05, 12)
				_kit.add_cylinder(_frame, Vector3(x + scroll * 0.37, y, z_face + 0.08), Vector3.BACK, 0.04, 0.03, 10)
		1:
			_kit.add_oriented_box(_enamel, Vector3(0.2, 0.2, 0.02), Vector3(x, y, z_face + 0.075), Basis(Vector3.BACK, PI * 0.25))
			_kit.add_oriented_box(_brass, Vector3(0.09, 0.09, 0.02), Vector3(x, y, z_face + 0.088), Basis(Vector3.BACK, PI * 0.25))
		_:
			for tooth in 3:
				_kit.add_box(_brass, Vector3(0.12, 0.07, 0.05), Vector3(x + (tooth - 1) * 0.2, ArenaRoom.LINTEL_BOTTOM - 0.1, z_face + 0.08))

## The bulkhead door's furniture: a brass frame, a centre seam, a handwheel, hinges and a status lamp, so it reads as a door.
func _door_detail(bay_x: float, span: float, open_height: float, z_face: float) -> void:
	var front_z := z_face - 0.345
	for jamb: float in [-1.0, 1.0]:
		_kit.add_box(_brass, Vector3(0.1, open_height, 0.05), Vector3(bay_x + jamb * (span * 0.5 - 0.05), ArenaRoom.SILL_HEIGHT, z_face - 0.33))
	_kit.add_box(_brass, Vector3(span, 0.1, 0.05), Vector3(bay_x, ArenaRoom.LINTEL_BOTTOM - 0.1, z_face - 0.33))
	_kit.add_box(_paint, Vector3(0.03, open_height - 0.2, 0.01), Vector3(bay_x, ArenaRoom.SILL_HEIGHT + 0.1, front_z + 0.005), ArenaRoom.DARK)
	var wheel_at := Vector3(bay_x - span * 0.16, 1.5, front_z + 0.04)
	_kit.add_torus(_brass, wheel_at, Vector3.BACK, 0.17, 0.022, 14, 5)
	_kit.add_cylinder(_brass, wheel_at, Vector3.BACK, 0.045, 0.06, 8)
	for spoke in 3:
		_kit.add_oriented_box(_brass, Vector3(0.34, 0.025, 0.025), wheel_at, Basis(Vector3.BACK, spoke * PI / 3.0))
	for hinge: float in [0.95, 1.8]:
		_kit.add_cylinder(_frame, Vector3(bay_x - span * 0.5 + 0.12, hinge, z_face - 0.3), Vector3.UP, 0.03, 0.2, 8)
	_kit.add_box(_lamp, Vector3(0.07, 0.07, 0.03), Vector3(bay_x + span * 0.3, 1.62, z_face - 0.34), Color("ffc080"))

class_name RoomFrontWall
extends RefCounted

## The front wall of the room (see `ArenaRoom`): the low parapet over the ribbed, piped hull.
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
	var width := inner.x * 2.0
	var z_face := inner.y
	var origin := Vector3(0.0, 0.0, z_face)
	# The inner face never shows; the cap is a quarter round that falls towards the camera, so the top reads as a rail.
	var cap := PackedVector2Array([Vector2(0, ArenaRoom.FRONT_HEIGHT), Vector2(0.12, ArenaRoom.FRONT_HEIGHT)])
	cap.append_array(RoomMeshKit.arc(Vector2(0.12, 0.3), 0.2, 90.0, 0.0, 5))
	_kit.extrude([cap], _brass, origin, Vector3.BACK, Vector3.RIGHT, width)
	_kit.extrude([PackedVector2Array([Vector2(ArenaRoom.FRONT_DEPTH, 0.3), Vector2(ArenaRoom.FRONT_DEPTH, -ArenaRoom.HULL_DEPTH)])],
		_hull, origin, Vector3.BACK, Vector3.RIGHT, width)
	var z_outer := z_face + ArenaRoom.FRONT_DEPTH
	var count := roundi(width / 1.6)
	var pitch := width / count
	for index in count + 1:
		# Buttress ribs run down the hull; nothing here rises above the parapet.
		_kit.add_box(_hull, Vector3(0.14, 2.8, 0.12), Vector3(-inner.x + index * pitch, -2.5, z_outer + 0.06))
	for index in count:
		var kind := (index * 3 + index / 5) % 5
		room.front_module_kinds.append(kind)
		_front_module(kind, Vector3(-inner.x + (index + 0.5) * pitch, 0.0, z_outer), index)
	# A rub-rail, and a pipe with clamps under it.
	_kit.add_box(_brass, Vector3(width, 0.08, 0.08), Vector3(0.0, -0.64, z_outer + 0.04))
	_kit.add_cylinder(_frame, Vector3(0.0, -0.84, z_outer + 0.1), Vector3.RIGHT, 0.05, width, 8)
	for index in int(width / 0.8):
		_kit.add_box(_brass, Vector3(0.08, 0.16, 0.05), Vector3(-inner.x + 0.4 + index * 0.8, -0.92, z_outer + 0.1))
	for index in int(width / 0.4):
		_kit.add_box(_brass, Vector3(0.06, 0.008, 0.06), Vector3(-inner.x + 0.2 + index * 0.4, ArenaRoom.FRONT_HEIGHT, z_face + 0.06))

## One bay of the front _hull, on the outer face at `at` (x centre, z of the face). Nothing rises above the parapet.
func _front_module(kind: int, at: Vector3, index: int) -> void:
	var z := at.z
	match kind:
		0: # a pair of portholes
			for offset: float in [-0.35, 0.35]:
				_kit.add_cylinder(_brass, Vector3(at.x + offset, -0.2, z + 0.03), Vector3.BACK, 0.17, 0.06, 14)
				_kit.add_cylinder(_lamp, Vector3(at.x + offset, -0.2, z + 0.065), Vector3.BACK, 0.11, 0.05, 14, room.lamp_tone(index * 3.1 + offset))
		1: # one big porthole with dogs round the rim
			_kit.add_cylinder(_brass, Vector3(at.x, -0.2, z + 0.035), Vector3.BACK, 0.3, 0.07, 18)
			for dog in 8:
				var angle := TAU * dog / 8.0
				_kit.add_box(_brass, Vector3(0.06, 0.06, 0.05), Vector3(at.x + cos(angle) * 0.33, -0.2 + sin(angle) * 0.33 - 0.03, z + 0.05))
			_kit.add_cylinder(_lamp, Vector3(at.x, -0.2, z + 0.08), Vector3.BACK, 0.21, 0.05, 18, room.lamp_tone(index * 3.1))
		2: # a hatch with a coral stripe
			_kit.add_box(_brass, Vector3(1.0, 0.7, 0.04), Vector3(at.x, -0.6, z + 0.02))
			_kit.add_box(_paint, Vector3(0.86, 0.56, 0.05), Vector3(at.x, -0.53, z + 0.025), ArenaRoom.DARK)
			_kit.add_box(_paint, Vector3(0.86, 0.08, 0.055), Vector3(at.x, -0.16, z + 0.0275), ArenaRoom.CORAL)
			_kit.add_box(_lamp, Vector3(0.06, 0.06, 0.06), Vector3(at.x + 0.38, 0.0, z + 0.03), room.lamp_tone(index * 3.1 + 1.0))
		3: # a louvred vent
			_kit.add_box(_paint, Vector3(0.9, 0.5, 0.04), Vector3(at.x, -0.5, z + 0.02), ArenaRoom.DARK)
			_kit.add_box(_lamp, Vector3(0.8, 0.4, 0.045), Vector3(at.x, -0.45, z + 0.022), Color("ffc080") * 0.45)
			for slat in 6:
				_kit.add_box(_brass, Vector3(0.9, 0.03, 0.06), Vector3(at.x, -0.28 - slat * 0.07, z + 0.03))
		_: # a brass nameplate
			_kit.add_box(_brass, Vector3(0.9, 0.28, 0.04), Vector3(at.x, -0.36, z + 0.02))
			for line in 3:
				_kit.add_box(_paint, Vector3(0.6 - line * 0.12, 0.02, 0.045), Vector3(at.x, -0.28 - line * 0.07, z + 0.022), ArenaRoom.DARK)
			_kit.add_box(_lamp, Vector3(0.06, 0.06, 0.06), Vector3(at.x - 0.38, -0.1, z + 0.03), room.lamp_tone(index * 3.1 + 2.0))

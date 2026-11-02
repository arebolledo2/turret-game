class_name RoomSideWalls
extends RefCounted

## The two side walls of the room (see `ArenaRoom`): the battered slope with its ribs, modules and coping.
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
	var length := inner.y * 2.0 + 0.8 # the ends sit inside the corner towers
	var count := maxi(2, roundi((inner.y * 2.0) / ArenaRoom.PILLAR_PITCH))
	var pitch := inner.y * 2.0 / count
	for side: float in [-1.0, 1.0]:
		var origin := Vector3(side * inner.x, 0.0, 0.0)
		var outward := Vector3(side, 0.0, 0.0)
		# Kick, then a moulded coping: a rounded nose over the slope, a flat top with a raised rail, and the outer lip.
		var coping := PackedVector2Array([Vector2(0.95, 1.5), Vector2(0.95, 1.56)])
		coping.append_array(RoomMeshKit.arc(Vector2(1.0, 1.56), 0.05, 180.0, 90.0, 4))
		coping.append_array(PackedVector2Array([Vector2(1.2, 1.61), Vector2(1.24, ArenaRoom.SIDE_HEIGHT), Vector2(1.38, ArenaRoom.SIDE_HEIGHT),
			Vector2(1.42, 1.61), Vector2(ArenaRoom.SIDE_DEPTH, 1.61)]))
		_kit.extrude([PackedVector2Array([Vector2(0, 0), Vector2(0, 0.26), Vector2(0.04, 0.3), Vector2(0.25, 0.3)]), coping],
			_brass, origin, outward, Vector3.BACK, length)
		# The slope leans back about 58 degrees, which is the face the camera sees; the outer face drops to the hull.
		_kit.extrude([PackedVector2Array([Vector2(0.25, 0.3), Vector2(1.0, 1.5)]),
			PackedVector2Array([Vector2(ArenaRoom.SIDE_DEPTH, 1.61), Vector2(ArenaRoom.SIDE_DEPTH, -ArenaRoom.HULL_DEPTH)])],
			_hull, origin, outward, Vector3.BACK, length)
		_kit.add_box(_enamel, Vector3(0.06, 0.008, inner.y * 2.0), Vector3(side * (inner.x + 1.46), 1.61, 0.0))
		for index in int(inner.y * 2.0 / 0.4):
			var bolt_z := -inner.y + 0.2 + index * 0.4
			_kit.add_box(_brass, Vector3(0.06, 0.02, 0.06), Vector3(side * (inner.x + 1.31), ArenaRoom.SIDE_HEIGHT, bolt_z))
			if index % 2 == 0: # copestone joints
				_kit.add_box(_paint, Vector3(0.14, 0.004, 0.012), Vector3(side * (inner.x + 1.31), ArenaRoom.SIDE_HEIGHT + 0.001, bolt_z + 0.2), ArenaRoom.DARK)
		# The slope is divided into bays by brass ribs; each bay carries one module.
		var x_axis := Vector3(side * 0.53, 0.848, 0.0)
		var normal := Vector3(-side * 0.848, 0.53, 0.0)
		var z_axis := Vector3(0.0, 0.0, side)
		var slope_basis := Basis(x_axis, normal, z_axis)
		var slope_origin := Vector3(side * (inner.x + 0.25), 0.3, 0.0)
		for index in range(1, count):
			var post_z := -inner.y + index * pitch
			_kit.add_oriented_box(_brass, Vector3(ArenaRoom.SLOPE_LENGTH, 0.05, 0.08), slope_origin + x_axis * ArenaRoom.SLOPE_LENGTH * 0.5 + normal * 0.02 + Vector3(0, 0, post_z), slope_basis)
			# Lamp posts on the coping (the ends hide in the towers). Each lamp throws a cone of light down the slope, brightest
			# under the lamp and fading as it widens, with a small halo round the lens, so the light reads as coming from it.
			var x := side * (inner.x + 1.31)
			var tone := room.lamp_tone(index * 2.3 + side)
			_kit.add_box(_brass, Vector3(0.08, 0.2, 0.08), Vector3(x, ArenaRoom.SIDE_HEIGHT, post_z))
			_kit.add_box(_lamp, Vector3(0.12, 0.14, 0.12), Vector3(x, ArenaRoom.SIDE_HEIGHT + 0.2, post_z), tone)
			var slope_top := slope_origin + x_axis * ArenaRoom.SLOPE_LENGTH + normal * 0.012 + Vector3(0, 0, post_z)
			_kit.glow_cone(slope_top, -x_axis, Vector3.BACK, 1.3, 0.14, 0.72, 0.95 * tone.v)
			_kit.glow_quad(Vector3(x, ArenaRoom.SIDE_HEIGHT + 0.27, post_z), Vector3.RIGHT, ArenaRoom.SCREEN_UP, 0.28, 0.28, 0.55 * tone.v)
		for index in count:
			var centre := slope_origin + Vector3(0, 0, -inner.y + (index + 0.5) * pitch)
			_side_bay(int(index * 2 + (1 if side > 0.0 else 0)) % 5, index + 1, centre, slope_basis, pitch)
			# An enamel inset on the flat of the coping in each bay, between the nose and the rail.
			_kit.add_box(_enamel, Vector3(0.13, 0.008, pitch * 0.74), Vector3(side * (inner.x + 1.1), 1.61, centre.z))

## One module on the sloped face, in the slope's own frame: x up the slope, y out of the surface, z along the wall.
func _side_bay(kind: int, number: int, origin: Vector3, slope_basis: Basis, pitch: float) -> void:
	var up := slope_basis.x
	var out := slope_basis.y
	var along := slope_basis.z
	var middle := origin + up * 0.7
	match kind:
		0: # recessed panel with two lit slits
			_kit.add_oriented_box(_paint, Vector3(1.0, 0.025, pitch * 0.55), middle + out * 0.012, slope_basis, ArenaRoom.DARK)
			for slit: float in [-0.25, 0.25]:
				_kit.add_oriented_box(_lamp, Vector3(0.7, 0.02, 0.05), middle + out * 0.03 + along * slit, slope_basis, room.lamp_tone(number + slit))
		1: # round hatch with a wheel
			_kit.add_cylinder(_brass, middle + out * 0.03, out, 0.34, 0.06, 16)
			_kit.add_cylinder(_paint, middle + out * 0.045, out, 0.28, 0.07, 16, ArenaRoom.DARK)
			_kit.add_oriented_box(_brass, Vector3(0.4, 0.03, 0.04), middle + out * 0.09, slope_basis)
			_kit.add_oriented_box(_brass, Vector3(0.04, 0.03, 0.4), middle + out * 0.09, slope_basis)
		2: # louvre vent with a glow behind the slats
			_kit.add_oriented_box(_paint, Vector3(0.9, 0.02, pitch * 0.5), middle + out * 0.01, slope_basis, ArenaRoom.DARK)
			_kit.add_oriented_box(_lamp, Vector3(0.8, 0.015, pitch * 0.42), middle + out * 0.022, slope_basis, Color("ffc080"))
			for slat in 5:
				_kit.add_oriented_box(_brass, Vector3(0.04, 0.03, pitch * 0.5), middle + up * (slat - 2) * 0.16 + out * 0.04, slope_basis)
		3: # a pair of pipes with clamps
			for pipe: float in [-0.14, 0.14]:
				_kit.add_cylinder(_brass, middle + out * 0.07 + along * pipe, up, 0.045, 1.2, 8)
			for clamp: float in [-0.4, 0.4]:
				_kit.add_oriented_box(_brass, Vector3(0.07, 0.06, 0.4), middle + up * clamp + out * 0.08, slope_basis)
		_: # a stencilled bay number
			_digit(middle + out * 0.012, slope_basis, number % 10)

func _digit(centre: Vector3, slope_basis: Basis, digit: int) -> void:
	var segments := {"a": Vector2(0.26, 0.0), "g": Vector2(0.0, 0.0), "d": Vector2(-0.26, 0.0), "b": Vector2(0.13, 0.14),
		"c": Vector2(-0.13, 0.14), "e": Vector2(-0.13, -0.14), "f": Vector2(0.13, -0.14)}
	for segment: String in ArenaRoom.DIGITS[digit]:
		var offset: Vector2 = segments[segment]
		var horizontal := segment in ["a", "g", "d"]
		var size := Vector3(0.045, 0.02, 0.24) if horizontal else Vector3(0.24, 0.02, 0.045)
		_kit.add_oriented_box(_paint, size, centre + slope_basis.x * offset.x + slope_basis.z * offset.y, slope_basis, ArenaRoom.CREAM)

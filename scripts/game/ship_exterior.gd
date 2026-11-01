class_name ShipExterior
extends RefCounted

## The ship outside the room's walls: side decks with running lights, pipe runs, solar wings, antennas and radar dishes; engine
## nacelles under the front towers; a plated deck with vents and crates behind the back windows, and a docked pod beyond it.
## Static, shadowless meshes merged per material under an `Exterior` child of the room. Little of it shows at the default zoom
## (the view clips close to the walls); it is what you see when the camera is pulled back or the window is wide.
const SOLAR_BLUE := Color("1a2a4a")
const SOLAR_GRID := Color("3a5a8a")
const PORT := Color("e8664f")
const STARBOARD := Color("3aa6a0")

var _kit := RoomMeshKit.new()
var _lamp: StandardMaterial3D

## `materials` holds the room's `hull`, `brass`, `frame` and `paint` materials, so the theme tints them too.
func build(room: Node3D, materials: Dictionary, inner: Vector2) -> void:
	var hull: Material = materials["hull"]
	var brass: Material = materials["brass"]
	var frame: Material = materials["frame"]
	var paint: Material = materials["paint"]
	_lamp = StandardMaterial3D.new()
	_lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp.vertex_color_use_as_albedo = true
	_lamp.albedo_color = Color(0.85, 0.85, 0.85)
	var outer_x := inner.x + ArenaRoom.SIDE_DEPTH
	for side: float in [-1.0, 1.0]:
		_side_deck(side, outer_x, inner.y, hull, brass, frame, paint)
		_nacelle(side, outer_x, inner.y, hull, brass, paint)
	_back_deck(inner, hull, brass, frame, paint)
	var holder := Node3D.new()
	holder.name = "Exterior"
	room.add_child(holder)
	_kit.flush(holder, ArenaRoom.ROOM_LAYERS, materials["glow"], [], true)

func _side_deck(side: float, outer_x: float, half_z: float, hull: Material, brass: Material, frame: Material, paint: Material) -> void:
	var width := 4.2
	var z_start := -half_z - 0.9
	var length := half_z * 2.0 + 1.35
	var centre_x := side * (outer_x + width * 0.5)
	_kit.add_box(hull, Vector3(width, 0.3, length), Vector3(centre_x, -1.2, z_start + length * 0.5))
	_kit.add_box(brass, Vector3(0.08, 0.1, length), Vector3(side * (outer_x + width), -0.9, z_start + length * 0.5))
	var colour := PORT if side < 0.0 else STARBOARD
	var count := int(length / 2.4)
	for index in count:
		_kit.add_box(_lamp, Vector3(0.1, 0.1, 0.1), Vector3(side * (outer_x + width), -0.8, z_start + 0.6 + index * 2.4), colour)
	# A pipe bundle along the deck, with clamps.
	for pipe in [[0.06, 0.0], [0.08, 0.22], [0.1, -0.24]]:
		_kit.add_cylinder(frame, Vector3(side * (outer_x + 0.5 + pipe[1]), -0.75, z_start + length * 0.5), Vector3.BACK, pipe[0], length, 8)
	for index in int(length / 1.6):
		_kit.add_box(brass, Vector3(0.7, 0.2, 0.08), Vector3(side * (outer_x + 0.5), -0.88, z_start + 0.8 + index * 1.6))
	# Every 6.4 m: a solar wing, an antenna mast or a radar dish.
	for index in int(length / 6.4):
		var z := z_start + 3.2 + index * 6.4
		var x := side * (outer_x + 2.4)
		match index % 3:
			0:
				_solar_wing(Vector3(x, -0.3, z), side, frame, paint)
			1:
				var height := 2.5 + 0.7 * (index % 2)
				_kit.add_cylinder(frame, Vector3(x, -0.9 + height * 0.5, z), Vector3.UP, 0.04, height, 6)
				_kit.add_box(brass, Vector3(0.5, 0.04, 0.04), Vector3(x, -0.9 + height * 0.6, z))
				_kit.add_box(_lamp, Vector3(0.1, 0.1, 0.1), Vector3(x, -0.9 + height, z), PORT)
			_:
				_kit.add_cylinder(frame, Vector3(x, -0.4, z), Vector3.UP, 0.06, 1.0, 6)
				var tilt := Basis(Vector3.RIGHT, -0.7) * Basis(Vector3.UP, side * 0.6)
				_kit.add_oriented_box(brass, Vector3(1.0, 0.06, 1.0), Vector3(x, 0.2, z), tilt)
				_kit.add_box(_lamp, Vector3(0.08, 0.08, 0.08), Vector3(x, 0.55, z), STARBOARD)

func _solar_wing(at: Vector3, side: float, frame: Material, paint: Material) -> void:
	var tilt := Basis(Vector3.BACK, side * 0.26)
	_kit.add_cylinder(frame, at + Vector3(0, -0.3, 0), Vector3.UP, 0.05, 0.9, 6)
	_kit.add_oriented_box(paint, Vector3(3.6, 0.04, 1.8), at + tilt * Vector3(side * 0.4, 0.2, 0), tilt, SOLAR_BLUE)
	for column in 6: # cell grid
		_kit.add_oriented_box(paint, Vector3(0.03, 0.045, 1.8), at + tilt * Vector3(side * 0.4 + (column - 2.5) * 0.6, 0.2, 0), tilt, SOLAR_GRID)
	for row in 2:
		_kit.add_oriented_box(paint, Vector3(3.6, 0.045, 0.03), at + tilt * Vector3(side * 0.4, 0.2, (row - 0.5) * 0.6), tilt, SOLAR_GRID)

func _nacelle(side: float, outer_x: float, half_z: float, hull: Material, brass: Material, paint: Material) -> void:
	var x := side * (outer_x + 1.0)
	var z := half_z + 0.5
	_kit.add_cylinder(hull, Vector3(x, -1.3, z), Vector3.BACK, 0.75, 3.0, 14)
	_kit.add_cylinder(brass, Vector3(x, -1.3, z + 1.4), Vector3.BACK, 0.8, 0.2, 14)
	_kit.add_cylinder(paint, Vector3(x, -1.3, z + 1.52), Vector3.BACK, 0.6, 0.06, 14, Color("0a1016"))
	_kit.add_cylinder(_lamp, Vector3(x, -1.3, z + 1.56), Vector3.BACK, 0.42, 0.04, 14, Color("7fb4ff"))
	_kit.glow_quad(Vector3(x, -0.99, z + 3.4), Vector3.RIGHT, Vector3.BACK, 0.9, 2.0, 0.5)

func _back_deck(inner: Vector2, hull: Material, brass: Material, frame: Material, paint: Material) -> void:
	var z_near := -inner.y - ArenaRoom.BACK_TOP_DEPTH - 0.05
	var depth := 2.3
	var centre_z := z_near - depth * 0.5
	_kit.add_box(hull, Vector3(inner.x * 2.0, 0.3, depth), Vector3(0.0, -2.7, centre_z))
	_kit.add_box(brass, Vector3(inner.x * 2.0, 0.08, 0.08), Vector3(0.0, -2.4, z_near - depth))
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for index in 14:
		var x := -inner.x + 1.0 + index * (inner.x * 2.0 - 2.0) / 13.0
		var z := centre_z + rng.randf_range(-0.7, 0.7)
		match index % 4:
			0:
				_kit.add_box(frame, Vector3(rng.randf_range(0.5, 1.0), rng.randf_range(0.4, 1.0), 0.5), Vector3(x, -2.4, z))
			1:
				_kit.add_cylinder(brass, Vector3(x, -2.25, z), Vector3.UP, 0.4, 0.3, 10)
			2:
				for slat in 4:
					_kit.add_box(frame, Vector3(0.7, 0.04, 0.05), Vector3(x, -2.35 + slat * 0.08, z))
				_kit.add_box(paint, Vector3(0.7, 0.3, 0.3), Vector3(x, -2.4, z - 0.05), Color("0a1016"))
			_:
				_kit.add_box(_lamp, Vector3(0.3, 0.08, 0.3), Vector3(x, -2.4, z), PORT if index % 8 == 3 else STARBOARD)
	# Masts rising behind the coping, and a docked pod beyond the deck.
	for x: float in [-9.6, -3.2, 3.2, 9.6]:
		var top := 3.2 + 0.2 * rng.randf()
		_kit.add_cylinder(frame, Vector3(x, (top - 2.4) * 0.5, z_near - depth + 0.3), Vector3.UP, 0.04, top + 2.4, 6)
		_kit.add_box(_lamp, Vector3(0.1, 0.1, 0.1), Vector3(x, top, z_near - depth + 0.3), PORT)
	_kit.add_cylinder(hull, Vector3(-6.0, -5.0, z_near - depth - 3.0), Vector3.RIGHT, 1.2, 4.2, 14)
	_kit.add_cylinder(brass, Vector3(-6.0, -5.0, z_near - depth - 3.0), Vector3.RIGHT, 1.25, 0.2, 14)
	_kit.add_cylinder(_lamp, Vector3(-3.85, -5.0, z_near - depth - 3.0), Vector3.RIGHT, 0.5, 0.05, 12, Color("ffc080"))

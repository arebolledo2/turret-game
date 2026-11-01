class_name ShipExterior
extends RefCounted

## The ship outside the room's walls. Each side deck carries a pipe run (varied pipes, flanges, a valve, a junction box), a brass
## rail with running lights and five equipment modules chosen from a radar dish, a solar wing, a cargo stack, a radiator bank, a
## fuel tank and a comms array; the decks run north to meet a plated back deck so no space shows at the top corners. Engine
## nacelles sit under the front towers. The back deck carries tall cargo stacks, comms towers, exhaust stacks, radiators and light
## masts, and a docked pod hangs beyond it. Soft multiply "contact shade" blobs under the props stand in for shadows.
## Static, shadowless meshes merged per material under an `Exterior` child of the room. Little of it shows at the default zoom
## (the view clips close to the walls); it is what you see on wide windows, when the camera is pulled back, or over and through
## the back wall. The camera sees only the tops and the south faces of things, so detail goes there.
const SOLAR_CELL := Color(0.035, 0.06, 0.15)
const SILVER := Color(0.5, 0.52, 0.55)
const CREAM := Color(0.3, 0.29, 0.24)
const PORT := Color("e8664f")
const STARBOARD := Color("3aa6a0")
const DARK := Color("0a1016")
## Painted parts are lit by a strong sun, so their albedo is far lower than the colour they should read as.
const PORT_PAINT := Color(0.42, 0.12, 0.09)
const PAD := Color(0.045, 0.05, 0.06)
const DECK_TOP: float = -0.9
const DECK_WIDTH: float = 4.2
const BACK_DECK_TOP: float = -2.4
const BACK_DECK_DEPTH: float = 2.3
const SLOTS: int = 5
const MODULES_LEFT: Array[String] = ["wing", "radiator", "dish", "containers", "comms"]
const MODULES_RIGHT: Array[String] = ["containers", "dish", "tank", "wing", "radiator"]
const CONTAINER_COLOURS: Array[Color] = [Color(0.2, 0.055, 0.04), Color(0.26, 0.17, 0.04), Color(0.04, 0.15, 0.16), Color(0.2, 0.2, 0.18), Color(0.06, 0.1, 0.22)]

var _kit := RoomMeshKit.new()
var _hull: Material
var _brass: Material
var _frame: Material
var _paint: Material
var _lamp: StandardMaterial3D
## Glossy dark cells and silver metal for the solar wings; they pick up the studio sky.
var _cell: StandardMaterial3D
## Multiply blobs under the props.
var _shade: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var _xf := Transform3D.IDENTITY
## +1 when the frame's local +z points south (towards the camera), -1 when it points north.
var _zs: float = 1.0

## `materials` holds the room's `hull`, `brass`, `frame` and `paint` materials, so the theme tints them too.
func build(room: Node3D, materials: Dictionary, inner: Vector2) -> void:
	_hull = materials["hull"]
	_brass = materials["brass"]
	_frame = materials["frame"]
	_paint = materials["paint"]
	_lamp = StandardMaterial3D.new()
	_lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp.vertex_color_use_as_albedo = true
	_lamp.albedo_color = Color(0.85, 0.85, 0.85)
	_cell = StandardMaterial3D.new()
	_cell.vertex_color_use_as_albedo = true
	_cell.metallic = 0.7
	_cell.roughness = 0.25
	_shade = StandardMaterial3D.new()
	_shade.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shade.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	_shade.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shade.vertex_color_use_as_albedo = true
	_shade.disable_fog = true
	_rng.seed = 91
	var outer_x := inner.x + ArenaRoom.SIDE_DEPTH
	var z_near := -inner.y - ArenaRoom.BACK_TOP_DEPTH - 0.05
	var z_far := z_near - BACK_DECK_DEPTH
	for side: float in [-1.0, 1.0]:
		_side_deck(side, outer_x, inner.y, z_far)
		_nacelle(side, outer_x, inner.y)
	_back_deck(outer_x, z_near, z_far)
	var holder := Node3D.new()
	holder.name = "Exterior"
	room.add_child(holder)
	_kit.flush(holder, ArenaRoom.ROOM_LAYERS, materials["glow"], [], true)

# --- Building blocks (in the current module frame) ----------------------------------------------------------------------

## Sets the module frame: local +x points away from the ship, +y is up from `origin` and +z runs along the deck. A yaw of
## PI turns it round for the west side, where local +z points north.
func _place(origin: Vector3, yaw: float = 0.0) -> void:
	_xf = Transform3D(Basis(Vector3.UP, yaw), origin)
	_zs = 1.0 if (_xf.basis * Vector3.BACK).z > 0.0 else -1.0

func _to_local(world_direction: Vector3) -> Vector3:
	return _xf.basis.inverse() * world_direction

## A frame point from a world z (the frame's origin sits at z = 0), for runs that span the deck.
func _at(x: float, y: float, world_z: float) -> Vector3:
	return Vector3(x, y, world_z * _zs)

## An axis-aligned block (the frame may only be turned by multiples of PI) standing on `base_centre`.
func _block(mat: Material, size: Vector3, base_centre: Vector3, color: Color = Color.WHITE) -> void:
	_kit.add_box(mat, size, _xf * base_centre, color)

func _box(mat: Material, size: Vector3, centre: Vector3, color: Color = Color.WHITE, tilt: Basis = Basis.IDENTITY) -> void:
	_kit.add_oriented_box(mat, size, _xf * centre, _xf.basis * tilt, color)

## A round rod between two points.
func _rod(mat: Material, from: Vector3, to: Vector3, radius: float, sides: int = 6, color: Color = Color.WHITE) -> void:
	var start := _xf * from
	var finish := _xf * to
	var length := start.distance_to(finish)
	if length < 0.0001:
		return
	_kit.add_cylinder(mat, (start + finish) * 0.5, (finish - start) / length, radius, length, sides, color)

func _spin(mat: Material, origin: Vector3, axis: Vector3, profile: PackedVector2Array, sides: int, color: Color = Color.WHITE,
		colors: PackedColorArray = PackedColorArray()) -> void:
	_kit.add_lathe(mat, _xf * origin, _xf.basis * axis, profile, sides, color, colors)

func _ring(mat: Material, centre: Vector3, axis: Vector3, radius: float, tube: float, sides: int, color: Color = Color.WHITE) -> void:
	_kit.add_torus(mat, _xf * centre, _xf.basis * axis, radius, tube, sides, 5, color)

func _tube(mat: Material, points: Array[Vector3], radius: float, sides: int, color: Color = Color.WHITE) -> void:
	var transformed := PackedVector3Array()
	for point in points:
		transformed.append(_xf * point)
	_kit.add_tube(mat, transformed, radius, sides, color)

## A flat rectangle facing along `axis_u` x `axis_v` (given in the frame).
func _flat(mat: Material, centre: Vector3, axis_u: Vector3, axis_v: Vector3, half_u: float, half_v: float, color: Color) -> void:
	_kit.add_quad(mat, _xf * centre, _xf.basis * axis_u, _xf.basis * axis_v, half_u, half_v, color)

func _lamp_box(size: float, base_centre: Vector3, color: Color) -> void:
	_block(_lamp, Vector3(size, size, size), base_centre, color)

## A soft dark pool on the deck standing in for a shadow: a fan that multiplies the deck by `strength` in the middle and by 1
## at the edge.
func _blob(centre: Vector3, radius_x: float, radius_z: float, strength: float = 0.5) -> void:
	var surface := _kit.batch(_shade)
	var sides := 10
	var core := Color(strength, strength, strength, 1.0)
	var middle_value := lerpf(strength, 1.0, 0.5)
	var middle := Color(middle_value, middle_value, middle_value, 1.0)
	var origin := _xf * centre
	var inner_ring: Array[Vector3] = []
	var outer_ring: Array[Vector3] = []
	for index in sides:
		var offset := Vector3(cos(TAU * index / sides) * radius_x, 0.0, sin(TAU * index / sides) * radius_z)
		inner_ring.append(_xf * (centre + offset * 0.5))
		outer_ring.append(_xf * (centre + offset))
	var up := Vector3.UP
	for index in sides:
		var next := (index + 1) % sides
		_kit.triangle_colored(surface, origin, inner_ring[index], inner_ring[next], up, up, up, core, middle, middle)
		_kit.triangle_colored(surface, inner_ring[index], outer_ring[index], outer_ring[next], up, up, up, middle, Color.WHITE, Color.WHITE)
		_kit.triangle_colored(surface, inner_ring[index], outer_ring[next], inner_ring[next], up, up, up, middle, Color.WHITE, middle)

## A low plate under a module, with its contact shade.
func _pad(centre_x: float, width: float, length: float, strength: float = 0.5) -> void:
	_block(_paint, Vector3(width, 0.035, length), Vector3(centre_x, 0.0, 0.0), PAD)
	_blob(Vector3(centre_x, 0.05, 0.0), width * 0.75, length * 0.7, strength)

## Brass studs at the pad corners, so the plate reads as a fitted base rather than a stain.
func _pad_corners(centre_x: float, width: float, length: float) -> void:
	for corner_x: float in [-1.0, 1.0]:
		for corner_z: float in [-1.0, 1.0]:
			_block(_brass, Vector3(0.1, 0.05, 0.1), Vector3(centre_x + corner_x * (width * 0.5 - 0.07), 0.0, corner_z * (length * 0.5 - 0.07)))

# --- Side decks -----------------------------------------------------------------------------------------------------------

func _side_deck(side: float, outer_x: float, half_z: float, z_far: float) -> void:
	var z_end := half_z + 0.55
	var length := z_end - z_far
	var centre_z := (z_far + z_end) * 0.5
	_kit.add_box(_hull, Vector3(DECK_WIDTH, 0.3, length), Vector3(side * (outer_x + DECK_WIDTH * 0.5), DECK_TOP - 0.3, centre_z))
	var yaw := 0.0 if side > 0.0 else PI
	_place(Vector3(side * outer_x, DECK_TOP, 0.0), yaw)
	_rail(side, z_far, z_end)
	var first := z_far + 2.4
	var last := z_end - 3.1
	var pitch := (last - first) / (SLOTS - 1)
	_pipe_run(z_far + 0.3, z_end - 1.9, first, pitch)
	# Equipment modules along the deck, then smaller fittings in the gaps between them.
	var modules: Array[String] = MODULES_RIGHT if side > 0.0 else MODULES_LEFT
	for index in SLOTS:
		var z := first + index * pitch
		_place(Vector3(side * outer_x, DECK_TOP, z), yaw)
		match modules[index]:
			"wing":
				_solar_wing(side)
			"dish":
				_radar_dish(side)
			"containers":
				_containers()
			"radiator":
				_radiator()
			"tank":
				_fuel_tank()
			"comms":
				_comms_array(side)
		if index < SLOTS - 1:
			_place(Vector3(side * outer_x, DECK_TOP, z + pitch * 0.5), yaw)
			_deck_fitting((index + (1 if side > 0.0 else 0)) % 3)

## The outer rail: a brass top rail, a steel lower rail, posts, a running light on every other post, and a brass cap on the
## north end.
func _rail(side: float, z_far: float, z_end: float) -> void:
	var colour := PORT if side < 0.0 else STARBOARD
	var x := DECK_WIDTH - 0.04
	_rod(_brass, _at(x, 0.45, z_far + 0.15), _at(x, 0.45, z_end - 0.15), 0.025, 6)
	_rod(_frame, _at(x, 0.2, z_far + 0.15), _at(x, 0.2, z_end - 0.15), 0.018, 5)
	var z := z_far + 0.5
	var index := 0
	while z < z_end - 0.2:
		_rod(_frame, _at(x, 0.0, z), _at(x, 0.45, z), 0.022, 5)
		if index % 2 == 0:
			_lamp_box(0.09, _at(x, 0.45, z), colour)
		z += 1.8
		index += 1
	_block(_brass, Vector3(DECK_WIDTH, 0.06, 0.08), _at(DECK_WIDTH * 0.5, 0.0, z_far + 0.04))

# --- Pipes ------------------------------------------------------------------------------------------------------------------

## Three pipes of different bore and finish run the length of the deck close to the wall: a cream main with colour bands, a dark
## steel line and a copper line. They rest on low saddles (not cross clamps, which read as a ladder), flange every few metres,
## and carry a junction box, an expansion loop and a valve in the gaps between modules.
func _pipe_run(z_from: float, z_to: float, first: float, pitch: float) -> void:
	var main_x := 0.42
	var steel_x := 0.7
	var copper_x := 0.93
	var box_z := first + pitch * 0.5
	var loop_z := first + pitch * 1.5
	var valve_z := first + pitch * 2.5
	_rod(_paint, _at(main_x, 0.2, z_from), _at(main_x, 0.2, z_to), 0.12, 10, CREAM)
	_rod(_frame, _at(steel_x, 0.17, z_from), _at(steel_x, 0.17, box_z - 0.45), 0.075, 8)
	_rod(_frame, _at(steel_x, 0.17, box_z + 0.45), _at(steel_x, 0.17, z_to), 0.075, 8)
	_rod(_brass, _at(copper_x, 0.14, z_from), _at(copper_x, 0.14, loop_z - 0.7), 0.055, 8)
	_rod(_brass, _at(copper_x, 0.14, loop_z + 0.7), _at(copper_x, 0.14, z_to), 0.055, 8)
	var loop: Array[Vector3] = []
	for index in 17:
		var t := index / 16.0
		var out := 0.3 * smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(0.75, 1.0, t))
		loop.append(_at(copper_x + out, 0.14, loop_z - 0.7 + 1.4 * t))
	_tube(_brass, loop, 0.055, 8)
	# Flanges and colour bands on the main, and sleeves on the steel line.
	var flange := z_from + 1.0
	var band := 0
	while flange < z_to - 0.2:
		if absf(flange - valve_z) > 0.6:
			_rod(_frame, _at(main_x, 0.2, flange - 0.05), _at(main_x, 0.2, flange + 0.05), 0.17, 10)
			_rod(_paint, _at(main_x, 0.2, flange + 0.25), _at(main_x, 0.2, flange + 0.45), 0.132, 10, PORT_PAINT if band % 2 == 0 else Color(0.34, 0.25, 0.05))
			_rod(_frame, _at(steel_x, 0.17, flange + 0.9), _at(steel_x, 0.17, flange + 1.0), 0.105, 8)
		flange += 3.2
		band += 1
	# Saddles under the pipes, unevenly spaced.
	var saddle := z_from + 0.6
	var spacing := [2.3, 2.9, 2.5, 3.1]
	var step := 0
	while saddle < z_to - 0.2:
		_block(_paint, Vector3(1.05, 0.07, 0.22), _at(0.68, 0.0, saddle) - Vector3(0, 0, 0.11), PAD)
		_block(_brass, Vector3(0.3, 0.05, 0.07), _at(main_x, 0.29, saddle))
		saddle += float(spacing[step % spacing.size()])
		step += 1
	# A valve on a riser: body, stem, and a coral handwheel.
	_rod(_brass, _at(main_x, 0.2, valve_z), _at(main_x, 0.62, valve_z), 0.045, 8)
	_rod(_frame, _at(main_x, 0.36, valve_z - 0.1), _at(main_x, 0.36, valve_z + 0.1), 0.085, 8)
	_ring(_paint, _at(main_x, 0.66, valve_z), Vector3.UP, 0.16, 0.022, 14, PORT_PAINT)
	_rod(_paint, _at(main_x - 0.16, 0.66, valve_z), _at(main_x + 0.16, 0.66, valve_z), 0.014, 5, PORT_PAINT)
	_rod(_paint, _at(main_x, 0.66, valve_z - 0.16), _at(main_x, 0.66, valve_z + 0.16), 0.014, 5, PORT_PAINT)
	_rod(_brass, _at(main_x, 0.62, valve_z), _at(main_x, 0.72, valve_z), 0.03, 6)
	_blob(_at(main_x, 0.04, valve_z), 0.45, 0.45, 0.6)
	# A junction box where the steel line is interrupted, with a status lamp and a conduit to the cream main.
	_block(_paint, Vector3(0.52, 0.4, 0.5), _at(steel_x + 0.1, 0.0, box_z), Color(0.1, 0.15, 0.12))
	_block(_frame, Vector3(0.58, 0.05, 0.56), _at(steel_x + 0.1, 0.4, box_z))
	_lamp_box(0.07, _at(steel_x + 0.26, 0.45, box_z + 0.12), Color("ffc080") if _rng.randf() < 0.5 else Color("7fe0b0"))
	_rod(_brass, _at(steel_x + 0.35, 0.26, box_z), _at(steel_x + 0.7, 0.26, box_z), 0.035, 6)
	_blob(_at(steel_x + 0.1, 0.04, box_z), 0.55, 0.55, 0.55)

# --- Modules ----------------------------------------------------------------------------------------------------------------

## Small fittings between modules; three kinds so neighbours differ.
func _deck_fitting(kind: int) -> void:
	var x := 2.6
	match kind:
		0: # a flush hatch with a wheel, and a vent stack
			_pad(x, 1.4, 1.4, 0.6)
			_rod(_brass, Vector3(x, 0.035, 0.0), Vector3(x, 0.12, 0.0), 0.55, 18)
			_rod(_paint, Vector3(x, 0.12, 0.0), Vector3(x, 0.17, 0.0), 0.47, 18, Color(0.05, 0.07, 0.08))
			_ring(_paint, Vector3(x, 0.2, 0.0), Vector3.UP, 0.18, 0.025, 12, PORT_PAINT)
			_rod(_paint, Vector3(x - 0.18, 0.2, 0.0), Vector3(x + 0.18, 0.2, 0.0), 0.016, 5, PORT_PAINT)
			_rod(_paint, Vector3(x, 0.2, -0.18), Vector3(x, 0.2, 0.18), 0.016, 5, PORT_PAINT)
			_stack(Vector3(x + 1.0, 0.0, 0.5 * _zs), 1.1)
		1: # two bollards and a locker
			_pad(x, 2.0, 1.2, 0.6)
			for offset: float in [-0.5, 0.5]:
				_rod(_frame, Vector3(x - 0.6, 0.035, offset), Vector3(x - 0.6, 0.36, offset), 0.09, 8)
				_rod(_brass, Vector3(x - 0.6, 0.34, offset), Vector3(x - 0.6, 0.4, offset), 0.115, 8)
			_block(_paint, Vector3(0.8, 0.55, 0.5), Vector3(x + 0.5, 0.035, 0.0), Color(0.3, 0.08, 0.05))
			_block(_frame, Vector3(0.82, 0.04, 0.52), Vector3(x + 0.5, 0.585, 0.0))
			_block(_lamp, Vector3(0.1, 0.1, 0.02), Vector3(x + 0.7, 0.3, _zs * 0.26), Color("ffc080"))
		_: # a vent stack pair beside a cable reel
			_pad(x, 2.0, 1.4, 0.6)
			_stack(Vector3(x - 0.5, 0.0, -0.3 * _zs), 1.5)
			_stack(Vector3(x + 0.1, 0.0, 0.25 * _zs), 0.9)
			_rod(_paint, Vector3(x + 0.85, 0.2, -0.2), Vector3(x + 0.85, 0.2, 0.2), 0.3, 14, Color(0.3, 0.17, 0.05))
			_rod(_frame, Vector3(x + 0.85, 0.2, -0.26), Vector3(x + 0.85, 0.2, 0.26), 0.07, 8)

## A ship's ventilator: a pipe that rises, bends over to face the camera and ends in a flared brass bell.
func _stack(base: Vector3, height: float) -> void:
	var bend := 0.2 + 0.1 * height
	var path: Array[Vector3] = [base + Vector3(0, 0.1, 0), base + Vector3(0, height * 0.5, 0)]
	for index in 9:
		var angle := PI * index / 8.0
		path.append(base + Vector3(0.0, height + bend * sin(angle), _zs * bend * (1.0 - cos(angle))))
	_tube(_frame, path, 0.085, 8)
	var mouth := base + Vector3(0.0, height, _zs * bend * 2.0)
	_spin(_brass, mouth, Vector3.UP, PackedVector2Array([Vector2(0.085, 0.0), Vector2(0.09, -0.05), Vector2(0.19, -0.22), Vector2(0.16, -0.22)]), 10)
	_rod(_frame, base + Vector3(0, 0.03, 0), base + Vector3(0, 0.1, 0), 0.15, 8)
	_ring(_brass, base + Vector3(0, 0.12, 0), Vector3.UP, 0.1, 0.02, 8, Color.WHITE)

## A radar dish on a pedestal: a paraboloid bowl with a rim, a feed horn on three struts, and a yoke.
func _radar_dish(side: float) -> void:
	_pad(2.4, 2.8, 2.8, 0.45)
	_pad_corners(2.4, 2.8, 2.8)
	var aim := _to_local(Vector3(-side * 0.22, 0.7, 0.68)).normalized()
	var radius := 0.95
	var focal := 0.58
	var depth := radius * radius / (4.0 * focal)
	var height := radius * sqrt(maxf(0.0, 1.0 - aim.y * aim.y)) + 0.3 - aim.y * depth
	var pivot := Vector3(2.4, 0.035 + height, 0.0)
	_rod(_brass, Vector3(2.4, 0.04, 0.0), Vector3(2.4, 0.16, 0.0), 0.4, 14)
	_rod(_frame, Vector3(2.4, 0.16, 0.0), Vector3(2.4, pivot.y - 0.2, 0.0), 0.1, 8)
	_box(_frame, Vector3(0.4, 0.22, 0.34), pivot + Vector3(0, -0.2, 0))
	_rod(_frame, pivot + Vector3(0, -0.18, 0), pivot - aim * 0.2, 0.045, 6)
	_dish_bowl(pivot, aim, radius, focal, 20)

## A paraboloid bowl with its vertex at `vertex`, opening along `aim`; the feed horn and its struts hang at the focus.
func _dish_bowl(vertex: Vector3, aim: Vector3, radius: float, focal: float, sides: int) -> void:
	var depth := radius * radius / (4.0 * focal)
	var rings := 6
	var lip := 0.035
	var profile := PackedVector2Array()
	var colours := PackedColorArray()
	for index in rings + 1:
		var r := radius * index / rings
		profile.append(Vector2(r, r * r / (4.0 * focal)))
		colours.append(Color(0.14, 0.14, 0.14).lerp(Color(0.3, 0.3, 0.28), float(index) / rings))
	profile.append(Vector2(radius + lip, depth))
	colours.append(Color(0.3, 0.3, 0.27))
	profile.append(Vector2(radius + lip, depth - 0.045))
	colours.append(Color(0.16, 0.16, 0.15))
	for index in range(rings, -1, -1):
		var r := radius * index / rings
		profile.append(Vector2(r + lip * index / rings, r * r / (4.0 * focal) - 0.045))
		colours.append(Color(0.12, 0.12, 0.12))
	_spin(_paint, vertex, aim, profile, sides, Color.WHITE, colours)
	_ring(_brass, vertex + aim * depth, aim, radius + lip, 0.022, sides, Color.WHITE)
	# The horn sits at the focus on three struts.
	var focus := vertex + aim * focal
	var side_axis := aim.cross(Vector3.UP)
	if side_axis.length() < 0.1:
		side_axis = aim.cross(Vector3.RIGHT)
	side_axis = side_axis.normalized()
	var up_axis := aim.cross(side_axis)
	for index in 3:
		var angle := TAU * index / 3.0 + 0.5
		var rim_point := vertex + aim * depth + (side_axis * cos(angle) + up_axis * sin(angle)) * radius
		_rod(_frame, rim_point, focus, radius * 0.02 + 0.006, 5)
	var horn := PackedVector2Array([Vector2(0.0, 0.1), Vector2(0.035, 0.1), Vector2(0.035, 0.02), Vector2(0.09, -0.07), Vector2(0.08, -0.07)])
	var horn_colours := PackedColorArray([Color(0.3, 0.22, 0.1), Color(0.3, 0.22, 0.1), Color(0.3, 0.22, 0.1), Color(0.3, 0.22, 0.1), Color(0.04, 0.04, 0.05)])
	_spin(_paint, focus, aim, horn, 10, Color.WHITE, horn_colours)

## A solar wing on a pedestal and gimbal: a boom along the deck with two columns of hinged panels, each a silver plate carrying a
## grid of near-black cells (each slightly different) and silver busbars. The cells are glossy so they catch the studio sky.
func _solar_wing(side: float) -> void:
	_pad(2.4, 3.0, 4.6, 0.5)
	_pad_corners(2.4, 3.0, 4.6)
	var x := 2.4
	var boom_y := 1.12
	_rod(_brass, Vector3(x, 0.04, 0.0), Vector3(x, 0.14, 0.0), 0.32, 14)
	_rod(_frame, Vector3(x, 0.14, 0.0), Vector3(x, 0.98, 0.0), 0.09, 8)
	_box(_frame, Vector3(0.4, 0.3, 0.7), Vector3(x, 1.0, 0.0))
	_rod(_brass, Vector3(x, 1.0, -0.36), Vector3(x, 1.0, -0.42), 0.17, 10)
	_rod(_brass, Vector3(x, 1.0, 0.36), Vector3(x, 1.0, 0.42), 0.17, 10)
	_rod(_cell, Vector3(x, boom_y, -2.45), Vector3(x, boom_y, 2.45), 0.045, 8, SILVER)
	_lamp_box(0.1, Vector3(x - 0.05, boom_y, -2.45), PORT if side < 0.0 else STARBOARD)
	_lamp_box(0.1, Vector3(x - 0.05, boom_y, 2.45), Color("ffc080"))
	var panel := Basis(Vector3.BACK, 0.34 * side)
	var segments := 4
	var segment_length := 1.0
	var gap := 0.06
	var cell_columns := 4
	var cell_rows := 4
	var cell_width := (1.2 - 0.1) / cell_columns
	var cell_length := (segment_length - 0.1) / cell_rows
	for column: float in [-1.0, 1.0]:
		for segment in segments:
			var z := (segment - (segments - 1) * 0.5) * (segment_length + gap)
			var centre := Vector3(x, boom_y, z) + panel * Vector3(column * 0.65, 0.0, 0.0)
			_box(_cell, Vector3(1.2, 0.03, segment_length), centre, SILVER * 0.9, panel)
			var top := centre + panel * Vector3(0.0, 0.0165, 0.0)
			for cell_column in cell_columns:
				var cx := (cell_column - (cell_columns - 1) * 0.5) * cell_width
				for cell_row in cell_rows:
					var cz := (cell_row - (cell_rows - 1) * 0.5) * cell_length
					var tint := SOLAR_CELL * (0.86 + 0.28 * _rng.randf())
					tint.b = SOLAR_CELL.b * (0.9 + 0.3 * _rng.randf())
					_flat(_cell, top + panel * Vector3(cx, 0.0, cz), panel * Vector3.BACK, panel * Vector3.RIGHT, cell_length * 0.5 - 0.01, cell_width * 0.5 - 0.01, tint)
				_flat(_cell, top + panel * Vector3(cx, 0.001, 0.0), panel * Vector3.BACK, panel * Vector3.RIGHT, segment_length * 0.5 - 0.05, 0.007, SILVER)
		# Arms from the gimbal to the panel plates.
		_rod(_frame, Vector3(x, 1.0, 0.0), Vector3(x, boom_y, 0.0) + panel * Vector3(column * 0.6, -0.02, 0.0), 0.03, 5)

## A stack of cargo containers: corrugated south faces, ribbed tops, corner castings, one stood on another.
func _containers() -> void:
	_pad(2.5, 3.0, 3.8, 0.5)
	var first := _rng.randi() % CONTAINER_COLOURS.size()
	_container(2.55, 0.65 * _zs, 0.035, 2.4, CONTAINER_COLOURS[first])
	_container(2.35, -0.65 * _zs, 0.035, 2.4, CONTAINER_COLOURS[(first + 2) % CONTAINER_COLOURS.size()])
	_container(2.45, -0.62 * _zs, 1.035, 2.4, CONTAINER_COLOURS[(first + 3) % CONTAINER_COLOURS.size()])
	# A small crate and a lashing post in front.
	_block(_paint, Vector3(0.6, 0.6, 0.6), Vector3(1.6, 0.035, 1.55 * _zs), CONTAINER_COLOURS[(first + 1) % CONTAINER_COLOURS.size()].lightened(0.1))
	_rod(_frame, Vector3(3.3, 0.035, 1.5 * _zs), Vector3(3.3, 0.5, 1.5 * _zs), 0.04, 6)

func _container(centre_x: float, z: float, base: float, length: float, color: Color) -> void:
	var height := 1.0
	var depth := 1.0
	var rib := color.darkened(0.22)
	_block(_paint, Vector3(length, height, depth), Vector3(centre_x, base, z), color)
	# Corrugation on the south face, and ribs on the roof.
	var ribs := int(length / 0.2)
	for index in ribs:
		var x := centre_x - length * 0.5 + 0.12 + index * (length - 0.24) / (ribs - 1)
		_block(_paint, Vector3(0.09, height - 0.18, 0.03), Vector3(x, base + 0.09, z + _zs * (depth * 0.5 + 0.012)), rib)
	for offset: float in [-0.3, 0.0, 0.3]:
		_block(_paint, Vector3(length - 0.3, 0.025, 0.07), Vector3(centre_x, base + height, z + offset), rib)
	for corner_x: float in [-1.0, 1.0]:
		for corner_z: float in [-1.0, 1.0]:
			_block(_frame, Vector3(0.14, 0.1, 0.14), Vector3(centre_x + corner_x * (length * 0.5 - 0.07), base + height, z + corner_z * (depth * 0.5 - 0.07)))
	_block(_paint, Vector3(0.55, 0.2, 0.02), Vector3(centre_x - length * 0.25, base + 0.62, z + _zs * (depth * 0.5 + 0.03)), CREAM)

## A roof of two radiator panels meeting at a hot ridge: pale plates crossed by dark coolant tubes, a header at each end and a
## return line along the eaves. One panel faces the camera and the other turns away, so it reads as a solid with depth.
func _radiator() -> void:
	_pad(2.55, 3.0, 3.8, 0.5)
	var x := 2.55
	var ridge := Vector3(x, 1.4, 0.0)
	var run := 1.3
	var drop := 0.94
	var slope := sqrt(run * run + drop * drop)
	var lean := atan2(drop, run)
	for facing: float in [1.0, -1.0]:
		# Axes: x along the ridge, y out of the panel (up and towards `facing`), z down the slope.
		var normal := Vector3(0.0, cos(lean), sin(lean) * _zs * facing)
		var panel := Basis(Vector3.RIGHT, normal, Vector3.RIGHT.cross(normal))
		var centre := ridge + Vector3(0.0, -drop * 0.5, run * 0.5 * _zs * facing)
		var tint := Color(0.26, 0.27, 0.3) if facing > 0.0 else Color(0.2, 0.21, 0.24)
		_box(_paint, Vector3(2.3, 0.04, slope), centre, tint, panel)
		for tube in 9:
			var offset := -slope * 0.5 + 0.15 + tube * (slope - 0.3) / 8.0
			_box(_paint, Vector3(2.1, 0.014, 0.04), centre + panel * Vector3(0.0, 0.026, offset), Color(0.02, 0.025, 0.03), panel)
		for end: float in [-1.0, 1.0]:
			_box(_paint, Vector3(0.07, 0.05, slope), centre + panel * Vector3(end * 1.1, 0.03, 0.0), Color(0.3, 0.2, 0.08), panel)
		var eave := ridge + Vector3(0.0, -drop, run * _zs * facing)
		_rod(_brass, eave + Vector3(-1.15, 0.0, 0.0), eave + Vector3(1.15, 0.0, 0.0), 0.04, 8)
	_box(_lamp, Vector3(2.3, 0.05, 0.07), ridge + Vector3(0.0, 0.03, 0.0), Color(0.7, 0.32, 0.12))
	for end: float in [-1.0, 1.0]:
		_rod(_frame, Vector3(x + end * 1.2, 0.035, 0.0), Vector3(x + end * 1.2, 1.38, 0.0), 0.05, 6)
		_rod(_frame, Vector3(x + end * 1.2, 0.5, -run * _zs), Vector3(x + end * 1.2, 0.5, run * _zs), 0.03, 5)

## A horizontal fuel tank on two saddles with coloured bands, a manway, a valve and a gauge.
func _fuel_tank() -> void:
	_pad(2.4, 3.0, 2.0, 0.5)
	var radius := 0.55
	var half := 0.7
	var y := 0.2 + radius
	var profile := RoomMeshKit.arc(Vector2(0.0, half), radius, 90.0, 0.0, 6)
	profile.append_array(RoomMeshKit.arc(Vector2(0.0, -half), radius, 0.0, -90.0, 6))
	_spin(_paint, Vector3(2.4, y, 0.0), Vector3.RIGHT, profile, 18, Color(0.16, 0.2, 0.1))
	for offset: float in [-0.55, 0.55]:
		_block(_frame, Vector3(0.3, 0.24, 1.0), Vector3(2.4 + offset, 0.035, 0.0))
		_rod(_brass, Vector3(2.4 + offset - 0.03, y, 0.0), Vector3(2.4 + offset + 0.03, y, 0.0), radius + 0.015, 18)
	_rod(_paint, Vector3(2.4 + 0.15, y, 0.0), Vector3(2.4 + 0.35, y, 0.0), radius + 0.01, 18, PORT_PAINT)
	# A manway dome and a valve on top, a gauge on the camera side.
	_spin(_brass, Vector3(2.4 - 0.4, y + radius - 0.05, 0.0), Vector3.UP, PackedVector2Array([Vector2(0.0, 0.14), Vector2(0.12, 0.1), Vector2(0.22, 0.0)]), 12)
	_rod(_brass, Vector3(2.4 + 0.5, y + radius - 0.05, 0.0), Vector3(2.4 + 0.5, y + radius + 0.3, 0.0), 0.04, 6)
	_ring(_paint, Vector3(2.4 + 0.5, y + radius + 0.34, 0.0), Vector3.UP, 0.13, 0.02, 12, PORT_PAINT)
	var dial := Vector3(2.4 - 0.05, y + 0.1, _zs * (radius + 0.02))
	_rod(_brass, dial, dial + Vector3(0, 0, _zs * 0.05), 0.1, 14)
	_rod(_paint, dial + Vector3(0, 0, _zs * 0.04), dial + Vector3(0, 0, _zs * 0.06), 0.08, 14, Color(0.3, 0.3, 0.27))
	_block(_paint, Vector3(0.012, 0.07, 0.01), dial + Vector3(0.01, 0.0, _zs * 0.065), Color(0.6, 0.12, 0.08))

## A mast with a crossarm of dishes, whip antennas and a beacon, braced by three stays.
func _comms_array(side: float) -> void:
	_pad(2.4, 2.6, 2.6, 0.5)
	var x := 2.3
	_rod(_brass, Vector3(x, 0.04, 0.0), Vector3(x, 0.12, 0.0), 0.3, 12)
	_rod(_frame, Vector3(x, 0.12, 0.0), Vector3(x, 2.5, 0.0), 0.05, 8)
	for index in 3:
		var angle := TAU * index / 3.0 + 0.4
		_rod(_frame, Vector3(x, 1.5, 0.0), Vector3(x + cos(angle) * 1.0, 0.035, sin(angle) * 1.0), 0.015, 4)
	_rod(_brass, Vector3(x, 1.9, -0.95), Vector3(x, 1.9, 0.95), 0.03, 6)
	_dish_bowl(Vector3(x - 0.05, 1.9, -0.95), _to_local(Vector3(0.1, 0.6, 0.75)).normalized(), 0.34, 0.2, 12)
	_dish_bowl(Vector3(x + 0.05, 1.9, 0.95), _to_local(Vector3(-0.4, 0.55, 0.7)).normalized(), 0.28, 0.17, 12)
	_dish_bowl(Vector3(x, 1.15, 0.0), _to_local(Vector3(0.35 * side, 0.45, 0.75)).normalized(), 0.3, 0.18, 12)
	for index in 3:
		_rod(_frame, Vector3(x + 0.35 + index * 0.18, 0.035, -0.3 + index * 0.1), Vector3(x + 0.35 + index * 0.18, 0.9 + index * 0.35, -0.3 + index * 0.1), 0.012, 4)
	_lamp_box(0.1, Vector3(x - 0.05, 2.5, -0.05), Color(0.9, 0.2, 0.15))

# --- Nacelles and the back deck -----------------------------------------------------------------------------------------

func _nacelle(side: float, outer_x: float, half_z: float) -> void:
	var x := side * (outer_x + 1.0)
	var z := half_z + 0.5
	_place(Vector3(x, -1.3, z))
	# Body: a lathe from the nozzle end back to the intake, with brass bands, vents and a dark nozzle with a blue core.
	var body := PackedVector2Array([Vector2(0.66, 1.3), Vector2(0.745, 1.0), Vector2(0.75, -1.1), Vector2(0.7, -1.4), Vector2(0.52, -1.5), Vector2(0.0, -1.5)])
	_spin(_hull, Vector3.ZERO, Vector3.BACK, body, 16)
	for offset: float in [-0.9, 0.0, 0.7]:
		_rod(_brass, Vector3(0, 0, offset), Vector3(0, 0, offset + 0.07), 0.775, 16)
	_rod(_brass, Vector3(0, 0, 1.2), Vector3(0, 0, 1.4), 0.8, 16)
	_rod(_paint, Vector3(0, 0, 1.4), Vector3(0, 0, 1.52), 0.62, 16, DARK)
	_rod(_lamp, Vector3(0, 0, 1.52), Vector3(0, 0, 1.56), 0.42, 16, Color("7fb4ff"))
	for slat in 5:
		_block(_paint, Vector3(0.62, 0.03, 0.06), Vector3(0.0, 0.7, -0.7 + slat * 0.18), Color(0.04, 0.05, 0.06))
		_block(_lamp, Vector3(0.62, 0.01, 0.02), Vector3(0.0, 0.725, -0.7 + slat * 0.18 + 0.045), Color(0.55, 0.26, 0.1))
	_block(_frame, Vector3(0.1, 0.45, 1.5), Vector3(side * 0.75, -0.22, 0.2))
	_lamp_box(0.09, Vector3(0.0, 0.76, -1.2), PORT if side < 0.0 else STARBOARD)
	_kit.glow_quad(Vector3(x, -0.99, z + 3.4), Vector3.RIGHT, Vector3.BACK, 0.9, 2.0, 0.5)

func _back_deck(outer_x: float, z_near: float, z_far: float) -> void:
	var centre_z := (z_near + z_far) * 0.5
	var width := (outer_x + 0.3) * 2.0
	_kit.add_box(_hull, Vector3(width, 0.3, BACK_DECK_DEPTH), Vector3(0.0, BACK_DECK_TOP - 0.3, centre_z))
	_kit.add_box(_brass, Vector3(width, 0.08, 0.08), Vector3(0.0, BACK_DECK_TOP, z_far))
	var span := outer_x - 1.2
	for index in 14:
		var x := -span + index * span * 2.0 / 13.0
		var z := _rng.randf_range(-0.55, 0.55)
		_place(Vector3(x, BACK_DECK_TOP, centre_z + z))
		match index % 7:
			0, 4:
				_cargo_tower()
			1, 6:
				_vent_block()
			2:
				_comms_tower()
			3:
				_exhaust_stacks()
			_:
				_dome()
	# Light masts rising behind the coping, and a docked pod beyond the deck.
	_place(Vector3(0.0, BACK_DECK_TOP, z_far + 0.3))
	for x: float in [-9.6, -3.2, 3.2, 9.6]:
		var top := 5.2 + 0.4 * _rng.randf()
		_rod(_frame, Vector3(x, 0.0, 0.0), Vector3(x, top, 0.0), 0.04, 6)
		_rod(_brass, Vector3(x - 0.3, top - 0.5, 0.0), Vector3(x + 0.3, top - 0.5, 0.0), 0.02, 5)
		_lamp_box(0.1, Vector3(x, top, 0.0), PORT)
	_pod(z_far)

func _cargo_tower() -> void:
	var first := _rng.randi() % CONTAINER_COLOURS.size()
	for level in 3:
		_container(0.0, 0.0, level * 1.0, 1.7, CONTAINER_COLOURS[(first + level) % CONTAINER_COLOURS.size()])
	_blob(Vector3(0, 0.05, 0), 1.5, 1.1, 0.5)

func _vent_block() -> void:
	_block(_frame, Vector3(1.0, 0.55, 0.6), Vector3(0, 0.0, 0))
	for slat in 5:
		_block(_lamp, Vector3(0.8, 0.03, 0.02), Vector3(0, 0.1 + slat * 0.08, _zs * 0.31), Color(0.55, 0.26, 0.1))
	_blob(Vector3(0, 0.05, 0), 0.9, 0.7, 0.55)

func _comms_tower() -> void:
	var height := 4.4
	for corner_x: float in [-1.0, 1.0]:
		for corner_z: float in [-1.0, 1.0]:
			_rod(_frame, Vector3(corner_x * 0.5, 0.0, corner_z * 0.4), Vector3(corner_x * 0.18, height, corner_z * 0.15), 0.03, 5)
	for level in 5:
		var y := 0.5 + level * 0.8
		var spread := lerpf(0.5, 0.18, y / height)
		_rod(_frame, Vector3(-spread, y, 0.0), Vector3(spread, y, 0.0), 0.02, 4)
	_rod(_frame, Vector3(0.0, height, 0.0), Vector3(0.0, height + 0.6, 0.0), 0.025, 5)
	_lamp_box(0.1, Vector3(0.0, height + 0.6, 0.0), PORT)
	_dish_bowl(Vector3(0.2, height - 0.5, 0.0), _to_local(Vector3(0.1, 0.6, 0.8)).normalized(), 0.4, 0.24, 12)
	_dish_bowl(Vector3(-0.2, height - 1.5, 0.0), _to_local(Vector3(-0.3, 0.5, 0.8)).normalized(), 0.3, 0.18, 12)
	_blob(Vector3(0, 0.05, 0), 1.0, 0.8, 0.55)

func _exhaust_stacks() -> void:
	for index in 3:
		_stack(Vector3(-0.45 + index * 0.45, 0.0, _rng.randf_range(-0.2, 0.2)), 1.4 + 0.6 * index)
	_blob(Vector3(0, 0.05, 0), 1.0, 0.7, 0.55)

func _dome() -> void:
	_rod(_brass, Vector3(0, 0.0, 0), Vector3(0, 0.15, 0), 0.6, 16)
	_spin(_paint, Vector3(0, 0.15, 0), Vector3.UP, RoomMeshKit.arc(Vector2.ZERO, 0.52, 90.0, 0.0, 6), 16, Color(0.04, 0.06, 0.08))
	_lamp_box(0.12, Vector3(0, 0.6, 0), Color("ffc080"))
	_blob(Vector3(0, 0.05, 0), 0.9, 0.9, 0.55)

## A docked pod beyond the deck: a rounded hull, a canopy, brass collars and a gangway up to the deck edge.
func _pod(z_far: float) -> void:
	_place(Vector3(-6.0, -5.0, z_far - 3.0))
	var hull_profile := RoomMeshKit.arc(Vector2(0.0, 1.0), 1.2, 90.0, 0.0, 6)
	hull_profile.append(Vector2(1.2, -1.6))
	hull_profile.append(Vector2(1.0, -2.1))
	hull_profile.append(Vector2(0.0, -2.1))
	_spin(_hull, Vector3.ZERO, Vector3.RIGHT, hull_profile, 16)
	_rod(_brass, Vector3(-1.6, 0, 0), Vector3(-1.5, 0, 0), 1.25, 16)
	_rod(_brass, Vector3(0.7, 0, 0), Vector3(0.8, 0, 0), 1.25, 16)
	_rod(_lamp, Vector3(-2.1, 0, 0), Vector3(-2.15, 0, 0), 0.5, 12, Color("ffc080"))
	_block(_paint, Vector3(1.6, 0.18, 0.7), Vector3(0.2, 1.1, 0.0), Color(0.03, 0.05, 0.08))
	_rod(_frame, Vector3(0.4, 0.9, 1.0), Vector3(0.4, 2.45, 3.0), 0.3, 10)

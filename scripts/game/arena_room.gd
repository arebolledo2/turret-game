class_name ArenaRoom
extends Node3D

## The shell around the playfield. The camera looks down at about 52 degrees from the south, so only faces turned up or
## towards the south ever show: a wall's inner face is invisible on the sides and the front. The walls are therefore profiles
## with a sloped, lit face: the side walls batter back from the room (a brass kick, a riveted slope divided into bays by brass
## ribs, a moulded coping with an enamel inlay), the front wall is a low parapet with a rounded brass cap over a ribbed, piped
## hull of varied modules (anything taller would hide floor), and the back wall, whose inner face does show, has a plinth, a
## sloped sill, open window bays with mullions onto the starfield, a bulkhead door, lit alcoves with slow flywheels, fluted
## pillars and a dentilled coping. Stepped corner towers carry lanterns and hide the joins. `ShipExterior` adds the ship outside.
## Everything is merged into one mesh per material (see `RoomMeshKit`). Hull plating is `hull_plating.gdshader` and the brass
## `brass_trim.gdshader`; light comes from unlit lamps (with soft additive pools), four lantern lights and the floor rim, all
## below the bloom threshold.
const HULL_SHADER: Shader = preload("res://assets/shaders/hull_plating.gdshader")
const BRASS_SHADER: Shader = preload("res://assets/shaders/brass_trim.gdshader")
## Render layer the room shares with the world; the stage's fill light only touches this one (see ArenaStage).
const LAYER: int = 1 << 18
const ROOM_LAYERS: int = 1 | LAYER
const GAP: float = 0.12 # clear space between the arena bounds and the wall faces (the floor rim sits inside it)
const HULL_DEPTH: float = 6.0 # walls reach this far below the floor so their outer faces read as a hull
const LAMP_ENERGY: float = 0.6 # brightness of the lantern lights
const LAMP_VALUE: float = 0.8 # lamp colour multiplier; unlit lamps stay below the bloom threshold

const BACK_HEIGHT: float = 2.64 # top of the coping's raised rail
const BACK_TOP_DEPTH: float = 0.9 # how far the coping reaches behind the inner face
const SILL_HEIGHT: float = 0.58
const LINTEL_BOTTOM: float = 2.1
const LINTEL_TOP: float = 2.5
const PILLAR_WIDTH: float = 0.6
const PILLAR_PITCH: float = 3.2
const SIDE_HEIGHT: float = 1.65
const SIDE_DEPTH: float = 1.5 # how far the side walls reach out from the inner face
const FRONT_HEIGHT: float = 0.5
const FRONT_DEPTH: float = 0.45
const BACK_TOWER_HEIGHT: float = 2.85
const FRONT_TOWER_HEIGHT: float = 2.0
## Metres the top HUD bar can hide at the top of the screen; the back camera margin leaves room for it.
const HUD_TOP_ALLOWANCE: float = 0.45

const CREAM := Color("e6dcc0")
const CORAL := Color("e8664f")
const DARK := Color("0a1016")
## Seven-segment digits (a top, b upper right, c lower right, d bottom, e lower left, f upper left, g middle).
const DIGITS: Array[String] = ["abcdef", "bc", "abged", "abgcd", "fgbc", "afgcd", "afgedc", "abc", "abcdefg", "abcdfg"]
const SLOPE_LENGTH: float = 1.415 # the side slope runs from (0.25, 0.3) to (1.0, 1.5) in profile
const FLYWHEEL_SPEED: float = 0.25

## The hull plating material; its uniforms follow the floor theme.
var hull: ShaderMaterial
## The module kind of each front-hull bay, for variety checks.
var front_module_kinds: Array[int] = []
var _brass: ShaderMaterial
var _frame: StandardMaterial3D
var _paint: StandardMaterial3D
var _lamp: StandardMaterial3D
var _enamel: StandardMaterial3D
var _glow: StandardMaterial3D
var _kit := RoomMeshKit.new()
var _shade := SurfaceTool.new()
var _lanterns: Array[OmniLight3D] = []
var _flywheels: Array[Node3D] = []
var _exterior: ShipExterior

func _init() -> void:
	name = "Room"

func _process(delta: float) -> void:
	for wheel in _flywheels:
		wheel.rotate_z(delta * FLYWHEEL_SPEED)

## Builds the walls once; `apply_theme` then colours them.
func build() -> void:
	var inner := WorldGeometry.HALF_ARENA + Vector2.ONE * GAP
	hull = ShaderMaterial.new()
	hull.shader = HULL_SHADER
	_brass = ShaderMaterial.new()
	_brass.shader = BRASS_SHADER
	_brass.set_shader_parameter("inner_half", inner)
	_frame = WorldGeometry.material(Color("18242d"))
	_frame.metallic = 0.7
	_frame.roughness = 0.45
	_paint = WorldGeometry.material(Color.WHITE)
	_paint.roughness = 0.75
	_paint.vertex_color_use_as_albedo = true
	_lamp = WorldGeometry.material(Color.WHITE)
	_lamp.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lamp.vertex_color_use_as_albedo = true
	_enamel = WorldGeometry.material(Color.WHITE)
	_enamel.roughness = 0.35
	_glow = _make_glow_material()
	_shade.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_back(inner)
	_build_sides(inner)
	_build_front(inner)
	_build_towers(inner)
	_build_shade()
	_kit.flush(self, ROOM_LAYERS, _glow, [_lamp])
	_exterior = ShipExterior.new()
	_exterior.build(self, {"hull": hull, "brass": _brass, "frame": _frame, "paint": _paint, "glow": _glow}, inner)
	set_process(not _flywheels.is_empty())

## Re-skins the hull for a floor theme and lights the lamps and their pools in its rim colour.
func apply_theme(theme: String, lamp_color: Color) -> void:
	var motif := WorldGeometry.hull_motif(theme)
	hull.set_shader_parameter("base_color", WorldGeometry.hull_color(theme))
	hull.set_shader_parameter("motif", int(motif["motif"]))
	hull.set_shader_parameter("panel_size", motif["panel"])
	hull.set_shader_parameter("metal", float(motif["metal"]))
	hull.set_shader_parameter("grime", float(motif["grime"]))
	_enamel.albedo_color = motif["accent"]
	_lamp.albedo_color = lamp_color * LAMP_VALUE
	_glow.albedo_color = lamp_color
	for lantern in _lanterns:
		lantern.light_color = lamp_color.lerp(Color("ffd59a"), 0.6)

func lantern_lights() -> Array[OmniLight3D]:
	return _lanterns

## Roughly a third of the lamps are dark and a tenth are a warm yellow, so the rows do not look stamped.
func lamp_tone(seed_value: float) -> Color:
	var h := fposmod(sin(seed_value * 12.9898) * 43758.5453, 1.0)
	if h < 0.3:
		return Color(0.12, 0.12, 0.12)
	if h < 0.4:
		return Color("ffc080")
	return Color.WHITE

static func _make_glow_material() -> StandardMaterial3D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	var result := StandardMaterial3D.new()
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.albedo_texture = texture
	result.vertex_color_use_as_albedo = true
	hull.set_shader_parameter("accent_color", motif["accent"])
	var brass := WorldGeometry.brass_style(theme)
	_brass.set_shader_parameter("brass_color", brass["color"])
	_brass.set_shader_parameter("patina_color", brass["patina"])
	_brass.set_shader_parameter("patina_amount", float(brass["amount"]))
	result.disable_fog = true
	return result

# --- Back wall -------------------------------------------------------------------------------------------------------

func _build_back(inner: Vector2) -> void:
	var z_face := -inner.y
	var width := inner.x * 2.0
	var origin := Vector3(0.0, 0.0, z_face)
	var out := Vector3.FORWARD
	_kit.extrude([PackedVector2Array([Vector2(0, 0), Vector2(0, 0.35)]), PackedVector2Array([Vector2(0, LINTEL_BOTTOM), Vector2(0, LINTEL_TOP)])],
		hull, origin, out, Vector3.RIGHT, width)
	# The sill slopes up and away, so it shows as a lit ledge. The coping has a rounded nose, a flat top and a raised rail.
	var coping := PackedVector2Array([Vector2(-0.06, LINTEL_TOP), Vector2(-0.06, 2.56)])
	coping.append_array(RoomMeshKit.arc(Vector2(0.0, 2.56), 0.06, 180.0, 90.0, 4))
	coping.append_array(PackedVector2Array([Vector2(0.34, 2.62), Vector2(0.38, BACK_HEIGHT), Vector2(0.58, BACK_HEIGHT),
		Vector2(0.62, 2.62), Vector2(BACK_TOP_DEPTH, 2.62)]))
	_kit.extrude([PackedVector2Array([Vector2(0, 0.35), Vector2(0.05, 0.4), Vector2(0.45, SILL_HEIGHT)]), coping],
		_brass, origin, out, Vector3.RIGHT, width)
	_kit.add_box(_enamel, Vector3(width, 0.008, 0.08), Vector3(0.0, 2.62, z_face - 0.8)) # inlay on the flat of the coping
	var count := maxi(2, roundi(width / PILLAR_PITCH))
	var pitch := width / count
	var depth := BACK_TOP_DEPTH
	var zc := z_face - depth * 0.5
	for index in count + 1:
		var x := -inner.x + index * pitch
		_kit.add_box(_frame, Vector3(PILLAR_WIDTH, LINTEL_TOP + HULL_DEPTH, depth), Vector3(x, -HULL_DEPTH, zc))
		_kit.add_box(hull, Vector3(0.78, 0.2, depth + 0.06), Vector3(x, 0.0, zc + 0.03)) # plinth step
		_kit.add_box(_brass, Vector3(PILLAR_WIDTH + 0.08, 0.08, depth + 0.04), Vector3(x, SILL_HEIGHT - 0.08, zc + 0.02))
		# Corbelled capital under the lintel.
		_kit.add_box(_brass, Vector3(0.7, 0.1, depth + 0.04), Vector3(x, LINTEL_BOTTOM - 0.48, zc + 0.02))
		_kit.add_box(_brass, Vector3(0.82, 0.18, depth + 0.06), Vector3(x, LINTEL_BOTTOM - 0.38, zc + 0.03))
		_kit.add_box(_brass, Vector3(0.94, 0.1, depth + 0.08), Vector3(x, LINTEL_BOTTOM - 0.2, zc + 0.04))
		# Two flutes either side of the lamp.
		for flute: float in [-0.19, 0.19]:
			_kit.add_box(_paint, Vector3(0.06, 1.0, 0.03), Vector3(x + flute, 0.7, z_face - 0.005), DARK)
		# Lamp: brass housing around a glass lens, with a soft pool of light on the floor below.
		var tone := lamp_tone(index * 1.7 + 0.3)
		_kit.add_box(_brass, Vector3(0.2, 0.6, 0.04), Vector3(x, 1.05, z_face - 0.01))
		_kit.add_box(_lamp, Vector3(0.12, 0.46, 0.03), Vector3(x, 1.12, z_face + 0.015), tone)
		_kit.glow_quad(Vector3(x, 0.012, z_face + 0.55), Vector3.RIGHT, Vector3.BACK, 0.65, 0.55, 0.18 * tone.v)
		if index < count:
			_build_back_bay(index, count, x + pitch * 0.5, pitch, z_face)
	# A dentil row under the cornice, and bolts along the raised rail.
	var step := 0.16
	for index in int(width / step):
		_kit.add_box(_brass, Vector3(0.08, 0.06, 0.05), Vector3(-inner.x + 0.1 + index * step, LINTEL_TOP - 0.07, z_face - 0.01))
	for index in int(width / 0.4):
		_kit.add_box(_brass, Vector3(0.06, 0.02, 0.06), Vector3(-inner.x + 0.2 + index * 0.4, BACK_HEIGHT, z_face - 0.48))
		if index % 2 == 0:
			_kit.add_box(_paint, Vector3(0.012, 0.004, 0.2), Vector3(-inner.x + 0.4 + index * 0.4, BACK_HEIGHT + 0.001, z_face - 0.48), DARK)

## One window bay between two pillars: an open window with a mullion and transom, a bulkhead door in the middle, or a lit
## alcove with a slowly turning flywheel.
func _build_back_bay(index: int, count: int, bay_x: float, pitch: float, z_face: float) -> void:
	var span := pitch - PILLAR_WIDTH - 0.02
	var open_height := LINTEL_BOTTOM - SILL_HEIGHT
	if index == count / 2:
		_kit.add_box(hull, Vector3(span, open_height, 0.1), Vector3(bay_x, SILL_HEIGHT, z_face - 0.4))
		for stripe in 4: # a coral and cream band across the foot of the door
			_kit.add_box(_paint, Vector3(span - 0.1, 0.1, 0.02), Vector3(bay_x, 0.7 + stripe * 0.1, z_face - 0.345), CORAL if stripe % 2 == 0 else CREAM)
		_kit.add_box(_brass, Vector3(0.3, 0.3, 0.05), Vector3(bay_x + span * 0.3, 1.2, z_face - 0.35))
		_kit.add_box(_paint, Vector3(0.18, 0.18, 0.06), Vector3(bay_x + span * 0.3, 1.26, z_face - 0.34), DARK)
		_kit.add_box(_brass, Vector3(0.95, 0.14, 0.04), Vector3(bay_x, LINTEL_BOTTOM + 0.12, z_face + 0.005)) # sign
		_kit.add_box(_lamp, Vector3(0.8, 0.08, 0.03), Vector3(bay_x, LINTEL_BOTTOM + 0.15, z_face + 0.03), Color("ffc080"))
	elif index == 1 or index == count - 2:
		_kit.add_box(_paint, Vector3(span, open_height, 0.08), Vector3(bay_x, SILL_HEIGHT, z_face - 0.55), Color("1a1410"))
		_kit.add_box(_lamp, Vector3(span - 0.3, open_height - 0.3, 0.02), Vector3(bay_x, SILL_HEIGHT + 0.15, z_face - 0.5), Color("a8742c"))
		_kit.glow_quad(Vector3(bay_x, 0.013, z_face + 0.6), Vector3.RIGHT, Vector3.BACK, span * 0.5, 0.7, 0.14)
		var wheel_kit := RoomMeshKit.new()
		wheel_kit.add_cylinder(_brass, Vector3.ZERO, Vector3.BACK, 0.55, 0.05, 20)
		wheel_kit.add_cylinder(_frame, Vector3.ZERO, Vector3.BACK, 0.46, 0.07, 20)
		for spoke in 6:
			wheel_kit.add_oriented_box(_brass, Vector3(1.0, 0.07, 0.06), Vector3.ZERO, Basis(Vector3.BACK, spoke * PI / 6.0), Color.WHITE)
		wheel_kit.add_cylinder(_brass, Vector3.ZERO, Vector3.BACK, 0.12, 0.1, 10)
		var pivot := Node3D.new()
		pivot.name = "Flywheel%d" % index
		pivot.position = Vector3(bay_x, SILL_HEIGHT + open_height * 0.5, z_face - 0.45)
		add_child(pivot)
		wheel_kit.flush(pivot, ROOM_LAYERS, _glow)
		_flywheels.append(pivot)
	else:
		_kit.add_box(_brass, Vector3(0.05, open_height, 0.05), Vector3(bay_x, SILL_HEIGHT, z_face - 0.4))
		_kit.add_box(_brass, Vector3(span, 0.05, 0.05), Vector3(bay_x, 1.3, z_face - 0.4))

# --- Side walls ------------------------------------------------------------------------------------------------------

func _build_sides(inner: Vector2) -> void:
	var length := inner.y * 2.0 + 0.8 # the ends sit inside the corner towers
	var count := maxi(2, roundi((inner.y * 2.0) / PILLAR_PITCH))
	var pitch := inner.y * 2.0 / count
	for side: float in [-1.0, 1.0]:
		var origin := Vector3(side * inner.x, 0.0, 0.0)
		var outward := Vector3(side, 0.0, 0.0)
		# Kick, then a moulded coping: a rounded nose over the slope, a flat top with a raised rail, and the outer lip.
		var coping := PackedVector2Array([Vector2(0.95, 1.5), Vector2(0.95, 1.56)])
		coping.append_array(RoomMeshKit.arc(Vector2(1.0, 1.56), 0.05, 180.0, 90.0, 4))
		coping.append_array(PackedVector2Array([Vector2(1.2, 1.61), Vector2(1.24, SIDE_HEIGHT), Vector2(1.38, SIDE_HEIGHT),
			Vector2(1.42, 1.61), Vector2(SIDE_DEPTH, 1.61)]))
		_kit.extrude([PackedVector2Array([Vector2(0, 0), Vector2(0, 0.26), Vector2(0.04, 0.3), Vector2(0.25, 0.3)]), coping],
			_brass, origin, outward, Vector3.BACK, length)
		# The slope leans back about 58 degrees, which is the face the camera sees; the outer face drops to the hull.
		_kit.extrude([PackedVector2Array([Vector2(0.25, 0.3), Vector2(1.0, 1.5)]),
			PackedVector2Array([Vector2(SIDE_DEPTH, 1.61), Vector2(SIDE_DEPTH, -HULL_DEPTH)])],
			hull, origin, outward, Vector3.BACK, length)
		_kit.add_box(_enamel, Vector3(0.06, 0.008, inner.y * 2.0), Vector3(side * (inner.x + 1.46), 1.61, 0.0))
		for index in int(inner.y * 2.0 / 0.4):
			var bolt_z := -inner.y + 0.2 + index * 0.4
			_kit.add_box(_brass, Vector3(0.06, 0.02, 0.06), Vector3(side * (inner.x + 1.31), SIDE_HEIGHT, bolt_z))
			if index % 2 == 0: # copestone joints
				_kit.add_box(_paint, Vector3(0.14, 0.004, 0.012), Vector3(side * (inner.x + 1.31), SIDE_HEIGHT + 0.001, bolt_z + 0.2), DARK)
		# The slope is divided into bays by brass ribs; each bay carries one module.
		var x_axis := Vector3(side * 0.53, 0.848, 0.0)
		var normal := Vector3(-side * 0.848, 0.53, 0.0)
		var z_axis := Vector3(0.0, 0.0, side)
		var slope_basis := Basis(x_axis, normal, z_axis)
		var slope_origin := Vector3(side * (inner.x + 0.25), 0.3, 0.0)
		for index in range(1, count):
			var post_z := -inner.y + index * pitch
			_kit.add_oriented_box(_brass, Vector3(SLOPE_LENGTH, 0.05, 0.08), slope_origin + x_axis * SLOPE_LENGTH * 0.5 + normal * 0.02 + Vector3(0, 0, post_z), slope_basis)
			# Lamp posts on the coping, each with a pool of light on the slope below (the ends hide in the towers).
			var x := side * (inner.x + 1.31)
			var tone := lamp_tone(index * 2.3 + side)
			_kit.add_box(_brass, Vector3(0.08, 0.2, 0.08), Vector3(x, SIDE_HEIGHT, post_z))
			_kit.add_box(_lamp, Vector3(0.12, 0.14, 0.12), Vector3(x, SIDE_HEIGHT + 0.2, post_z), tone)
			var on_slope := Vector3(side * (inner.x + 0.62), 0.9, post_z)
			_kit.glow_quad(on_slope + normal * 0.012, x_axis, Vector3.BACK, 0.55, 0.62, 0.55 * tone.v)
		for index in count:
			var centre := slope_origin + Vector3(0, 0, -inner.y + (index + 0.5) * pitch)
			_side_bay(int(index * 2 + (1 if side > 0.0 else 0)) % 5, index + 1, centre, slope_basis, pitch)

## One module on the sloped face, in the slope's own frame: x up the slope, y out of the surface, z along the wall.
func _side_bay(kind: int, number: int, origin: Vector3, slope_basis: Basis, pitch: float) -> void:
	var up := slope_basis.x
	var out := slope_basis.y
	var along := slope_basis.z
	var middle := origin + up * 0.7
	match kind:
		0: # recessed panel with two lit slits
			_kit.add_oriented_box(_paint, Vector3(1.0, 0.025, pitch * 0.55), middle + out * 0.012, slope_basis, DARK)
			for slit: float in [-0.25, 0.25]:
				_kit.add_oriented_box(_lamp, Vector3(0.7, 0.02, 0.05), middle + out * 0.03 + along * slit, slope_basis, lamp_tone(number + slit))
		1: # round hatch with a wheel
			_kit.add_cylinder(_brass, middle + out * 0.03, out, 0.34, 0.06, 16)
			_kit.add_cylinder(_paint, middle + out * 0.045, out, 0.28, 0.07, 16, DARK)
			_kit.add_oriented_box(_brass, Vector3(0.4, 0.03, 0.04), middle + out * 0.09, slope_basis)
			_kit.add_oriented_box(_brass, Vector3(0.04, 0.03, 0.4), middle + out * 0.09, slope_basis)
		2: # louvre vent with a glow behind the slats
			_kit.add_oriented_box(_paint, Vector3(0.9, 0.02, pitch * 0.5), middle + out * 0.01, slope_basis, DARK)
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
	for segment: String in DIGITS[digit]:
		var offset: Vector2 = segments[segment]
		var horizontal := segment in ["a", "g", "d"]
		var size := Vector3(0.045, 0.02, 0.24) if horizontal else Vector3(0.24, 0.02, 0.045)
		_kit.add_oriented_box(_paint, size, centre + slope_basis.x * offset.x + slope_basis.z * offset.y, slope_basis, CREAM)

# --- Front wall ------------------------------------------------------------------------------------------------------

func _build_front(inner: Vector2) -> void:
	var width := inner.x * 2.0
	var z_face := inner.y
	var origin := Vector3(0.0, 0.0, z_face)
	# The inner face never shows; the cap is a quarter round that falls towards the camera, so the top reads as a rail.
	var cap := PackedVector2Array([Vector2(0, FRONT_HEIGHT), Vector2(0.12, FRONT_HEIGHT)])
	cap.append_array(RoomMeshKit.arc(Vector2(0.12, 0.3), 0.2, 90.0, 0.0, 5))
	_kit.extrude([cap], _brass, origin, Vector3.BACK, Vector3.RIGHT, width)
	_kit.extrude([PackedVector2Array([Vector2(FRONT_DEPTH, 0.3), Vector2(FRONT_DEPTH, -HULL_DEPTH)])],
		hull, origin, Vector3.BACK, Vector3.RIGHT, width)
	var z_outer := z_face + FRONT_DEPTH
	var count := roundi(width / 1.6)
	var pitch := width / count
	for index in count + 1:
		# Buttress ribs run down the hull; nothing here rises above the parapet.
		_kit.add_box(hull, Vector3(0.14, 2.8, 0.12), Vector3(-inner.x + index * pitch, -2.5, z_outer + 0.06))
	for index in count:
		var kind := (index * 3 + index / 5) % 5
		front_module_kinds.append(kind)
		_front_module(kind, Vector3(-inner.x + (index + 0.5) * pitch, 0.0, z_outer), index)
	# A rub-rail, and a pipe with clamps under it.
	_kit.add_box(_brass, Vector3(width, 0.08, 0.08), Vector3(0.0, -0.64, z_outer + 0.04))
	_kit.add_cylinder(_frame, Vector3(0.0, -0.84, z_outer + 0.1), Vector3.RIGHT, 0.05, width, 8)
	for index in int(width / 0.8):
		_kit.add_box(_brass, Vector3(0.08, 0.16, 0.05), Vector3(-inner.x + 0.4 + index * 0.8, -0.92, z_outer + 0.1))
	for index in int(width / 0.4):
		_kit.add_box(_brass, Vector3(0.06, 0.008, 0.06), Vector3(-inner.x + 0.2 + index * 0.4, FRONT_HEIGHT, z_face + 0.06))

## One bay of the front hull, on the outer face at `at` (x centre, z of the face). Nothing rises above the parapet.
func _front_module(kind: int, at: Vector3, index: int) -> void:
	var z := at.z
	match kind:
		0: # a pair of portholes
			for offset: float in [-0.35, 0.35]:
				_kit.add_cylinder(_brass, Vector3(at.x + offset, -0.2, z + 0.03), Vector3.BACK, 0.17, 0.06, 14)
				_kit.add_cylinder(_lamp, Vector3(at.x + offset, -0.2, z + 0.065), Vector3.BACK, 0.11, 0.05, 14, lamp_tone(index * 3.1 + offset))
		1: # one big porthole with dogs round the rim
			_kit.add_cylinder(_brass, Vector3(at.x, -0.2, z + 0.035), Vector3.BACK, 0.3, 0.07, 18)
			for dog in 8:
				var angle := TAU * dog / 8.0
				_kit.add_box(_brass, Vector3(0.06, 0.06, 0.05), Vector3(at.x + cos(angle) * 0.33, -0.2 + sin(angle) * 0.33 - 0.03, z + 0.05))
			_kit.add_cylinder(_lamp, Vector3(at.x, -0.2, z + 0.08), Vector3.BACK, 0.21, 0.05, 18, lamp_tone(index * 3.1))
		2: # a hatch with a coral stripe
			_kit.add_box(_brass, Vector3(1.0, 0.7, 0.04), Vector3(at.x, -0.6, z + 0.02))
			_kit.add_box(_paint, Vector3(0.86, 0.56, 0.05), Vector3(at.x, -0.53, z + 0.025), DARK)
			_kit.add_box(_paint, Vector3(0.86, 0.08, 0.055), Vector3(at.x, -0.16, z + 0.0275), CORAL)
			_kit.add_box(_lamp, Vector3(0.06, 0.06, 0.06), Vector3(at.x + 0.38, 0.0, z + 0.03), lamp_tone(index * 3.1 + 1.0))
		3: # a louvred vent
			_kit.add_box(_paint, Vector3(0.9, 0.5, 0.04), Vector3(at.x, -0.5, z + 0.02), DARK)
			_kit.add_box(_lamp, Vector3(0.8, 0.4, 0.045), Vector3(at.x, -0.45, z + 0.022), Color("ffc080") * 0.45)
			for slat in 6:
				_kit.add_box(_brass, Vector3(0.9, 0.03, 0.06), Vector3(at.x, -0.28 - slat * 0.07, z + 0.03))
		_: # a brass nameplate
			_kit.add_box(_brass, Vector3(0.9, 0.28, 0.04), Vector3(at.x, -0.36, z + 0.02))
			for line in 3:
				_kit.add_box(_paint, Vector3(0.6 - line * 0.12, 0.02, 0.045), Vector3(at.x, -0.28 - line * 0.07, z + 0.022), DARK)
			_kit.add_box(_lamp, Vector3(0.06, 0.06, 0.06), Vector3(at.x - 0.38, -0.1, z + 0.03), lamp_tone(index * 3.1 + 2.0))

# --- Corner towers ---------------------------------------------------------------------------------------------------

func _build_towers(inner: Vector2) -> void:
	for side: float in [-1.0, 1.0]:
		var x := side * (inner.x + SIDE_DEPTH * 0.5)
		_tower(Vector3(SIDE_DEPTH, BACK_TOWER_HEIGHT, 1.5), Vector2(x, -inner.y - 0.15), side)
		_tower(Vector3(SIDE_DEPTH, FRONT_TOWER_HEIGHT, 1.05), Vector2(x, inner.y - 0.075), side)

## A stepped column: body, brass band, frieze, cornice and lid, with a lantern on the face the camera sees. `size.y` is its
## total height.
func _tower(size: Vector3, centre: Vector2, side: float) -> void:
	var body := size.y - 0.42
	_kit.add_box(hull, Vector3(size.x, body + HULL_DEPTH, size.z), Vector3(centre.x, -HULL_DEPTH, centre.y))
	_kit.add_box(_brass, Vector3(size.x + 0.04, 0.1, size.z + 0.04), Vector3(centre.x, body, centre.y))
	_kit.add_box(hull, Vector3(size.x - 0.04, 0.14, size.z - 0.04), Vector3(centre.x, body + 0.1, centre.y))
	_kit.add_box(_brass, Vector3(size.x + 0.16, 0.08, size.z + 0.16), Vector3(centre.x, body + 0.24, centre.y))
	_kit.add_box(_brass, Vector3(size.x - 0.2, 0.1, size.z - 0.2), Vector3(centre.x, body + 0.32, centre.y))
	var face_z := centre.y + size.z * 0.5
	var lantern_y := body * 0.5
	_kit.add_box(_brass, Vector3(0.36, 0.52, 0.08), Vector3(centre.x, lantern_y - 0.26, face_z + 0.03))
	_kit.add_box(_lamp, Vector3(0.24, 0.4, 0.06), Vector3(centre.x, lantern_y - 0.2, face_z + 0.08), Color("ffd59a"))
	var light := OmniLight3D.new()
	light.omni_range = 3.5
	light.light_energy = 0.7
	light.shadow_enabled = false
	light.position = Vector3(centre.x - side * 0.9, lantern_y, face_z + 0.45)
	add_child(light)
	_lanterns.append(light)

# --- Floor junction --------------------------------------------------------------------------------------------------

## A soft multiply shade along the foot of each wall on the floor, so the floor does not meet the walls abruptly. It sits in a
## child node, like the glow, because it lies inside the playfield bounds.
func _build_shade() -> void:
	var half := WorldGeometry.HALF_ARENA
	var reach := 0.55
	var dark := Color(0.6, 0.6, 0.6, 1.0)
	var strips: Array = [[Vector3(-half.x, 0, -half.y), Vector3.RIGHT, Vector3.BACK, half.x * 2.0],
		[Vector3(-half.x, 0, half.y), Vector3.RIGHT, Vector3.FORWARD, half.x * 2.0],
		[Vector3(-half.x, 0, -half.y), Vector3.BACK, Vector3.RIGHT, half.y * 2.0],
		[Vector3(half.x, 0, -half.y), Vector3.BACK, Vector3.LEFT, half.y * 2.0]]
	for strip: Array in strips:
		var start: Vector3 = strip[0] + Vector3(0, 0.016, 0)
		var run: Vector3 = strip[1] * strip[3]
		var inward: Vector3 = strip[2] * reach
		var corners: Array[Vector3] = [start, start + run, start + run + inward, start + inward]
		var colours: Array[Color] = [dark, dark, Color.WHITE, Color.WHITE]
		for index: int in [0, 1, 2, 0, 2, 3]:
			_shade.set_color(colours[index])
			_shade.add_vertex(corners[index])
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.disable_fog = true
	var root := Node3D.new()
	root.name = "Shade"
	add_child(root)
	var instance := MeshInstance3D.new()
	instance.mesh = _shade.commit()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(instance)

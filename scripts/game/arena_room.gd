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
const LANTERN_ENERGY: float = 0.7 # the tower lanterns' mean light energy; they flicker by LANTERN_FLICKER either way
const LANTERN_FLICKER: float = 0.06
const LANTERN_WARM := Color("ffd59a") # the lantern light is its lamp colour warmed towards this
## Alert (see `set_alert`): the lamps pulse between these brightness multipliers (the top is `LAMP_VALUE`, so a pulse never
## outshines a calm lamp) once every `ALERT_PERIOD` seconds, and the tint eases in and out over `ALERT_FADE`.
const ALERT_PULSE_MIN: float = 0.35
const ALERT_PULSE_MAX: float = 0.8
const ALERT_PERIOD: float = 2.4
const ALERT_FADE: float = 0.8
## Screen up on the ground plane for the fixed camera (a quad on it faces the lens); halos use it.
const SCREEN_UP := Vector3(0.0, 0.607, -0.794)
const BACK_CROWN: float = 0.4 # height of the cupola on the back towers (inside BACK_TOWER_HEIGHT)
const FRONT_CROWN: float = 0.28

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
## Alert state: the tint (a colour with its brightest channel at 1) and strength (0 calm to 1 full), the tween easing the
## strength, the pulse clock (runs only while the strength is above 0) and the flicker clock.
var _alert_color: Color = Color.WHITE
var _alert_amount: float = 0.0
var _alert_tween: Tween
var _alert_clock: float = 0.0
var _flicker_clock: float = 0.0
## The theme's lamp colour as `apply_theme` last left it in the glow material, and what this script last wrote there. If the two
## differ, `apply_theme` ran again, so the new colour is the base (see `_sync_base`).
var _base_glow: Color = Color.WHITE
var _written_glow: Color = Color.WHITE
var _base_known: bool = false
var _noise := FastNoiseLite.new()

func _init() -> void:
	name = "Room"
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	_noise.seed = 11
	_noise.frequency = 1.0

func _process(delta: float) -> void:
	for wheel in _flywheels:
		wheel.rotate_z(delta * FLYWHEEL_SPEED)
	_flicker_clock += delta
	for index in _lanterns.size():
		_lanterns[index].light_energy = lantern_energy(_flicker_clock, index)
	if _alert_amount > 0.0: # the pulse only runs during an alert
		_alert_clock += delta
		_apply_alert()

## Builds the walls once; `apply_theme` then colours them.
func build() -> void:
	_clear_alert() # a rebuild starts calm: the materials below are new and know nothing of an earlier alert
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
	set_process(not _flywheels.is_empty() or not _lanterns.is_empty()) # flywheels, lantern flicker and (in an alert) the lamp pulse

## Re-skins the hull for a floor theme and lights the lamps and their pools in its rim colour.
func apply_theme(theme: String, lamp_color: Color) -> void:
	var motif := WorldGeometry.hull_motif(theme)
	hull.set_shader_parameter("base_color", WorldGeometry.hull_color(theme))
	hull.set_shader_parameter("motif", int(motif["motif"]))
	hull.set_shader_parameter("panel_size", motif["panel"])
	hull.set_shader_parameter("metal", float(motif["metal"]))
	hull.set_shader_parameter("grime", float(motif["grime"]))
	hull.set_shader_parameter("accent_color", motif["accent"])
	var brass := WorldGeometry.brass_style(theme)
	_brass.set_shader_parameter("brass_color", brass["color"])
	_brass.set_shader_parameter("patina_color", brass["patina"])
	_brass.set_shader_parameter("patina_amount", float(brass["amount"]))
	_enamel.albedo_color = motif["accent"]
	_lamp.albedo_color = lamp_color * LAMP_VALUE
	_glow.albedo_color = lamp_color
	for lantern in _lanterns:
		lantern.light_color = lamp_color.lerp(Color("ffd59a"), 0.6)

func lantern_lights() -> Array[OmniLight3D]:
	return _lanterns

# --- Alert -----------------------------------------------------------------------------------------------------------------

## Tints the lamps, their glow pools and the lantern lights towards `color` by `amount` (0 calm, 1 full alert), easing over `fade`
## seconds (at once when it is 0 or the room is not in the tree). While the amount is above 0 the lamps also pulse slowly (see
## `alert_pulse`); at 0 everything returns exactly to the theme's colours. `ArenaStage.set_floor_wave` calls it: boss waves
## pass 1 in the wave colour, every other wave 0. When the amount is 0 the colour is ignored (a fade-out keeps the old one).
func set_alert(color: Color, amount: float, fade: float = ALERT_FADE) -> void:
	amount = clampf(amount, 0.0, 1.0)
	_sync_base()
	if amount > 0.0:
		var brightest := maxf(color.r, maxf(color.g, color.b))
		_alert_color = Color(color.r / brightest, color.g / brightest, color.b / brightest, 1.0) if brightest > 0.0 else Color.WHITE
	if _alert_tween:
		_alert_tween.kill()
		_alert_tween = null
	if fade <= 0.0 or not is_inside_tree() or is_equal_approx(_alert_amount, amount):
		_set_alert_amount(amount)
		return
	_alert_tween = create_tween()
	_alert_tween.tween_method(_set_alert_amount, _alert_amount, amount, fade)

## Ends an alert at once and restores the theme's colours.
func reset_alert() -> void:
	set_alert(_alert_color, 0.0, 0.0)

## The current alert strength, 0 (calm) to 1 (full alert).
func alert_amount() -> float:
	return _alert_amount

## The lamp brightness multiplier at `time` seconds into an alert: it starts at `ALERT_PULSE_MAX` (a calm lamp's value) and
## breathes down to `ALERT_PULSE_MIN` and back every `ALERT_PERIOD` seconds.
static func alert_pulse(time: float) -> float:
	return lerpf(ALERT_PULSE_MIN, ALERT_PULSE_MAX, 0.5 + 0.5 * cos(TAU * time / ALERT_PERIOD))

## The light energy of lantern `index` at `time` seconds: `LANTERN_ENERGY` plus or minus `LANTERN_FLICKER` from smooth noise,
## a different stretch of it for each lantern.
func lantern_energy(time: float, index: int) -> float:
	return LANTERN_ENERGY + LANTERN_FLICKER * clampf(_noise.get_noise_1d(time * 3.0 + index * 37.37) * 1.8, -1.0, 1.0)

func _set_alert_amount(value: float) -> void:
	_alert_amount = value
	if value <= 0.0:
		_alert_clock = 0.0
	_apply_alert()

func _clear_alert() -> void:
	if _alert_tween:
		_alert_tween.kill()
		_alert_tween = null
	_alert_amount = 0.0
	_alert_clock = 0.0
	_base_known = false

## Treats the glow colour in the material as the theme's lamp colour unless it is what `_apply_alert` wrote last, in which case
## `apply_theme` has not run since. That keeps the alert working with whatever theme code sets, without sharing state with it.
func _sync_base() -> void:
	if not _base_known or _glow.albedo_color != _written_glow:
		_base_glow = _glow.albedo_color
		_base_known = true

## Writes the lamp, glow and lantern colours for the current alert amount and pulse. At amount 0 these are exactly the colours
## `apply_theme` sets.
func _apply_alert() -> void:
	_sync_base()
	var pulse := alert_pulse(_alert_clock)
	var tint := _base_glow.lerp(_alert_color, _alert_amount)
	var value := lerpf(LAMP_VALUE, pulse, _alert_amount)
	var pool := lerpf(1.0, pulse / LAMP_VALUE, _alert_amount) # the glow pools breathe with the lamps
	_lamp.albedo_color = tint * value
	_glow.albedo_color = Color(tint.r * pool, tint.g * pool, tint.b * pool, tint.a)
	_written_glow = _glow.albedo_color
	var lantern_color := tint.lerp(LANTERN_WARM, 0.6 - 0.3 * _alert_amount) # less warm in an alert, so the tint shows
	for lantern in _lanterns:
		lantern.light_color = lantern_color

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
		# The end pillars stand half inside the corner towers, whose lids are lower than the pillar tops: build the half in the wall.
		var shaft := PILLAR_WIDTH * 0.5 if index == 0 or index == count else PILLAR_WIDTH
		var shaft_x := x + (PILLAR_WIDTH - shaft) * 0.5 * (1.0 if index == 0 else (-1.0 if index == count else 0.0))
		_kit.add_box(_frame, Vector3(shaft, LINTEL_TOP + HULL_DEPTH, depth), Vector3(shaft_x, -HULL_DEPTH, zc))
		_kit.add_box(hull, Vector3(0.78, 0.2, depth + 0.06), Vector3(x, 0.0, zc + 0.03)) # plinth step
		_kit.add_box(_brass, Vector3(PILLAR_WIDTH + 0.08, 0.08, depth + 0.04), Vector3(x, SILL_HEIGHT - 0.08, zc + 0.02))
		# Corbelled capital under the lintel.
		_kit.add_box(_brass, Vector3(0.7, 0.1, depth + 0.04), Vector3(x, LINTEL_BOTTOM - 0.48, zc + 0.02))
		_kit.add_box(_brass, Vector3(0.82, 0.18, depth + 0.06), Vector3(x, LINTEL_BOTTOM - 0.38, zc + 0.03))
		_kit.add_box(_brass, Vector3(0.94, 0.1, depth + 0.08), Vector3(x, LINTEL_BOTTOM - 0.2, zc + 0.04))
		# Two flutes either side of the lamp.
		for flute: float in [-0.19, 0.19]:
			_kit.add_box(_paint, Vector3(0.06, 1.0, 0.03), Vector3(x + flute, 0.7, z_face - 0.005), DARK)
		# Lamp: brass housing around a glass lens, a cone of light washing down the pillar from it, a halo round the lens and a
		# softer pool on the floor below.
		var tone := lamp_tone(index * 1.7 + 0.3)
		_kit.add_box(_brass, Vector3(0.2, 0.6, 0.04), Vector3(x, 1.05, z_face - 0.01))
		_kit.add_box(_lamp, Vector3(0.12, 0.46, 0.03), Vector3(x, 1.12, z_face + 0.015), tone)
		_kit.glow_cone(Vector3(x, 1.0, z_face + 0.075), Vector3.DOWN, Vector3.RIGHT, 0.95, 0.1, 0.6, 0.4 * tone.v)
		_kit.glow_quad(Vector3(x, 1.12, z_face + 0.12), Vector3.RIGHT, SCREEN_UP, 0.28, 0.28, 0.3 * tone.v)
		_kit.glow_quad(Vector3(x, 0.012, z_face + 0.55), Vector3.RIGHT, Vector3.BACK, 0.65, 0.55, 0.14 * tone.v)
		_capital_detail(index, x, z_face)
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
	_bay_trim(index, bay_x, span, z_face)
	if index == count / 2:
		_kit.add_box(hull, Vector3(span, open_height, 0.1), Vector3(bay_x, SILL_HEIGHT, z_face - 0.4))
		for stripe in 4: # a coral and cream band across the foot of the door
			_kit.add_box(_paint, Vector3(span - 0.1, 0.1, 0.02), Vector3(bay_x, 0.7 + stripe * 0.1, z_face - 0.345), CORAL if stripe % 2 == 0 else CREAM)
		_kit.add_box(_brass, Vector3(0.3, 0.3, 0.05), Vector3(bay_x + span * 0.3, 1.2, z_face - 0.35))
		_kit.add_box(_paint, Vector3(0.18, 0.18, 0.06), Vector3(bay_x + span * 0.3, 1.26, z_face - 0.34), DARK)
		_kit.add_box(_brass, Vector3(0.95, 0.14, 0.04), Vector3(bay_x, LINTEL_BOTTOM + 0.12, z_face + 0.005)) # sign
		_kit.add_box(_lamp, Vector3(0.8, 0.08, 0.03), Vector3(bay_x, LINTEL_BOTTOM + 0.15, z_face + 0.03), Color("ffc080"))
		_door_detail(bay_x, span, open_height, z_face)
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
	var cable_colors: Array[Color] = [CORAL, CREAM, Color("2f9a9a"), Color("c8a040")]
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
	var y := LINTEL_BOTTOM - 0.29
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
				_kit.add_box(_brass, Vector3(0.12, 0.07, 0.05), Vector3(x + (tooth - 1) * 0.2, LINTEL_BOTTOM - 0.1, z_face + 0.08))

## The bulkhead door's furniture: a brass frame, a centre seam, a handwheel, hinges and a status lamp, so it reads as a door.
func _door_detail(bay_x: float, span: float, open_height: float, z_face: float) -> void:
	var front_z := z_face - 0.345
	for jamb: float in [-1.0, 1.0]:
		_kit.add_box(_brass, Vector3(0.1, open_height, 0.05), Vector3(bay_x + jamb * (span * 0.5 - 0.05), SILL_HEIGHT, z_face - 0.33))
	_kit.add_box(_brass, Vector3(span, 0.1, 0.05), Vector3(bay_x, LINTEL_BOTTOM - 0.1, z_face - 0.33))
	_kit.add_box(_paint, Vector3(0.03, open_height - 0.2, 0.01), Vector3(bay_x, SILL_HEIGHT + 0.1, front_z + 0.005), DARK)
	var wheel_at := Vector3(bay_x - span * 0.16, 1.5, front_z + 0.04)
	_kit.add_torus(_brass, wheel_at, Vector3.BACK, 0.17, 0.022, 14, 5)
	_kit.add_cylinder(_brass, wheel_at, Vector3.BACK, 0.045, 0.06, 8)
	for spoke in 3:
		_kit.add_oriented_box(_brass, Vector3(0.34, 0.025, 0.025), wheel_at, Basis(Vector3.BACK, spoke * PI / 3.0))
	for hinge: float in [0.95, 1.8]:
		_kit.add_cylinder(_frame, Vector3(bay_x - span * 0.5 + 0.12, hinge, z_face - 0.3), Vector3.UP, 0.03, 0.2, 8)
	_kit.add_box(_lamp, Vector3(0.07, 0.07, 0.03), Vector3(bay_x + span * 0.3, 1.62, z_face - 0.34), Color("ffc080"))

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
			# Lamp posts on the coping (the ends hide in the towers). Each lamp throws a cone of light down the slope, brightest
			# under the lamp and fading as it widens, with a small halo round the lens, so the light reads as coming from it.
			var x := side * (inner.x + 1.31)
			var tone := lamp_tone(index * 2.3 + side)
			_kit.add_box(_brass, Vector3(0.08, 0.2, 0.08), Vector3(x, SIDE_HEIGHT, post_z))
			_kit.add_box(_lamp, Vector3(0.12, 0.14, 0.12), Vector3(x, SIDE_HEIGHT + 0.2, post_z), tone)
			var slope_top := slope_origin + x_axis * SLOPE_LENGTH + normal * 0.012 + Vector3(0, 0, post_z)
			_kit.glow_cone(slope_top, -x_axis, Vector3.BACK, 1.3, 0.14, 0.72, 0.95 * tone.v)
			_kit.glow_quad(Vector3(x, SIDE_HEIGHT + 0.27, post_z), Vector3.RIGHT, SCREEN_UP, 0.28, 0.28, 0.55 * tone.v)
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
		_tower(Vector3(SIDE_DEPTH, BACK_TOWER_HEIGHT, 1.5), Vector2(x, -inner.y - 0.15), side, BACK_CROWN, true)
		_tower(Vector3(SIDE_DEPTH, FRONT_TOWER_HEIGHT, 1.05), Vector2(x, inner.y - 0.075), side, FRONT_CROWN, false)

## A stepped column with a cupola. The box body (with a brass band, frieze, cornice and two lid steps) still hides the joins
## between walls of different heights; on the lid sit an enamel inset, an octagonal drum with lit slits, a brass ring, a domed cap
## with a beacon finial and a pinnacle at each corner, so from above it reads as a turret, not a lid. The south face (the one the
## camera sees) carries posts, a lantern, vents and an enamel stripe. `size.y` is the total height, `crown` how much of it is cupola.
func _tower(size: Vector3, centre: Vector2, side: float, crown: float, is_back: bool) -> void:
	var lid := size.y - 0.004 - crown # the top of the lid steps; nothing rises above `size.y`
	var body := lid - 0.3
	var cx := centre.x
	var cz := centre.y
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	_kit.add_box(hull, Vector3(size.x, body + HULL_DEPTH, size.z), Vector3(cx, -HULL_DEPTH, cz))
	_kit.add_box(_brass, Vector3(size.x + 0.04, 0.08, size.z + 0.04), Vector3(cx, body, cz))
	_kit.add_box(hull, Vector3(size.x - 0.04, 0.1, size.z - 0.04), Vector3(cx, body + 0.08, cz))
	_kit.add_box(_brass, Vector3(size.x + 0.16, 0.06, size.z + 0.16), Vector3(cx, body + 0.18, cz))
	_kit.add_box(_brass, Vector3(size.x - 0.06, 0.03, size.z - 0.06), Vector3(cx, body + 0.24, cz))
	_kit.add_box(_brass, Vector3(size.x - 0.3, 0.03, size.z - 0.3), Vector3(cx, body + 0.27, cz))
	_tower_face(Vector3(cx, body, cz + hz), size, side, is_back)
	_tower_crown(Vector3(cx, lid, cz), size, crown)
	# The lantern light is the same as ever: `body` of the old design was `size.y - 0.42`.
	var light := OmniLight3D.new()
	light.omni_range = 3.5
	light.light_energy = LANTERN_ENERGY
	light.shadow_enabled = false
	light.position = Vector3(cx - side * 0.9, (size.y - 0.42) * 0.5, cz + hz + 0.45)
	add_child(light)
	_lanterns.append(light)

## The face of a tower the camera sees, at `face` (x centre, top of the body, z of the face): corner posts, a framed lantern,
## louvred vents and an enamel stripe under the cornice. On the back towers the side wall hides everything below about 1.1 m
## (more towards the outer edge), so the lantern sits higher there.
func _tower_face(face: Vector3, size: Vector3, side: float, is_back: bool) -> void:
	var body := face.y
	var hx := size.x * 0.5
	for post: float in [-1.0, 1.0]:
		_kit.add_cylinder(_brass, Vector3(face.x + post * (hx - 0.03), (body - 1.2) * 0.5, face.z), Vector3.UP, 0.075, body + 1.2, 8)
	var lantern_height := 0.5 if is_back else 0.52
	var lantern_bottom := 1.45 if is_back else body * 0.5 - 0.26
	var z := face.z
	_kit.add_box(_brass, Vector3(0.38, lantern_height, 0.08), Vector3(face.x, lantern_bottom, z + 0.03))
	_kit.add_box(_brass, Vector3(0.46, 0.05, 0.12), Vector3(face.x, lantern_bottom + lantern_height, z + 0.03)) # roof
	_kit.add_box(_brass, Vector3(0.46, 0.05, 0.12), Vector3(face.x, lantern_bottom - 0.05, z + 0.03)) # sill
	_kit.add_box(_lamp, Vector3(0.24, lantern_height - 0.12, 0.06), Vector3(face.x, lantern_bottom + 0.06, z + 0.08), LANTERN_WARM)
	_kit.add_box(_brass, Vector3(0.26, 0.025, 0.07), Vector3(face.x, lantern_bottom + lantern_height * 0.5, z + 0.085)) # glazing bar
	_kit.add_box(_brass, Vector3(0.025, lantern_height - 0.1, 0.07), Vector3(face.x, lantern_bottom + 0.06, z + 0.085))
	_kit.glow_quad(Vector3(face.x, lantern_bottom + lantern_height * 0.5, z + 0.12), Vector3.RIGHT, SCREEN_UP, 0.4, 0.4, 0.26)
	# Vents either side of the lantern (the back towers show only the inner one, where the wall is lowest).
	for vent: float in [-1.0, 1.0]:
		if is_back and vent != -side:
			continue
		var vent_x := face.x + vent * 0.5
		var vent_bottom := 0.62 if is_back else body * 0.5 - 0.2
		_kit.add_box(_paint, Vector3(0.4, 0.3, 0.03), Vector3(vent_x, vent_bottom, z + 0.015), DARK)
		for slat in 5:
			_kit.add_box(_brass, Vector3(0.4, 0.025, 0.05), Vector3(vent_x, vent_bottom + 0.03 + slat * 0.055, z + 0.025))
	_kit.add_box(_enamel, Vector3(size.x - 0.24, 0.1, 0.02), Vector3(face.x, body - 0.15, z + 0.01))

## The cupola on a lid whose top centre is `at`: an enamel disc, an octagonal drum with lit slits, a brass tier and ring, a dome,
## a finial and a glowing bead with a halo, and a pinnacle at each lid corner. Seen from above they are concentric rings, which
## is what stops the lid reading as a flat rectangle. Everything stays within `crown` metres of the lid.
func _tower_crown(at: Vector3, size: Vector3, crown: float) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var drum_r := minf(hx, hz) * 0.62
	var drum_h := crown * 0.22
	var tier_h := crown * 0.1
	var dome_h := crown * 0.3
	_kit.add_cylinder(_enamel, Vector3(at.x, at.y + 0.006, at.z), Vector3.UP, drum_r + 0.07, 0.012, 16)
	var drum_y := at.y + 0.012
	var spare := (hx - 0.15) - (drum_r + 0.07) # lid left over either side of the enamel disc (the lid steps are 0.3 m narrower than the body)
	if spare > 0.12: # a louvred hood each side, for the long, shallow lids
		for hood: float in [-1.0, 1.0]:
			var hood_at := Vector3(at.x + hood * (drum_r + 0.07 + spare * 0.5), at.y, at.z)
			_kit.add_box(_frame, Vector3(spare * 0.8, 0.05, minf(hz * 0.7, 0.4)), hood_at)
			for slat in 4:
				_kit.add_box(_brass, Vector3(spare * 0.8, 0.012, 0.03), hood_at + Vector3(0.0, 0.05, (slat - 1.5) * minf(hz * 0.7, 0.4) * 0.24))
	_kit.add_cylinder(_frame, Vector3(at.x, drum_y + drum_h * 0.5, at.z), Vector3.UP, drum_r, drum_h, 8)
	# A lit slit on each of the drum's south-facing facets (the cylinder's facets are centred on 22.5 degrees plus 45 each).
	for facet in 8:
		var angle := TAU * (facet + 0.5) / 8.0
		var normal := Vector3(-sin(angle), 0.0, -cos(angle))
		if normal.z < 0.1:
			continue
		var tangent := Vector3.UP.cross(normal)
		var slit_at := Vector3(at.x, drum_y + drum_h * 0.5, at.z) + normal * (drum_r * cos(PI / 8.0) + 0.004)
		_kit.add_oriented_box(_lamp, Vector3(drum_r * 0.4, drum_h * 0.5, 0.012), slit_at, Basis(tangent, Vector3.UP, normal))
	var tier_y := drum_y + drum_h
	var tier_r := drum_r * 0.86
	_kit.add_cylinder(_brass, Vector3(at.x, tier_y + tier_h * 0.5, at.z), Vector3.UP, tier_r, tier_h, 12)
	var ring_y := tier_y + tier_h
	_kit.add_torus(_brass, Vector3(at.x, ring_y, at.z), Vector3.UP, tier_r - 0.02, 0.02, 12, 5)
	var dome_r := tier_r * 0.92
	var dome := PackedVector2Array()
	for step in 7: # a flattened hemisphere traced from the apex out and down
		var dome_angle := deg_to_rad(90.0 - step * 15.0)
		dome.append(Vector2(cos(dome_angle) * dome_r, sin(dome_angle) * dome_h))
	_kit.add_lathe(_brass, Vector3(at.x, ring_y, at.z), Vector3.UP, dome, 12)
	var stem := crown * 0.06
	var dome_top := ring_y + dome_h
	var bead_r := (at.y + crown - dome_top - stem) * 0.5
	_kit.add_cylinder(_frame, Vector3(at.x, dome_top + stem * 0.5, at.z), Vector3.UP, 0.012, stem, 6)
	var bead_at := Vector3(at.x, dome_top + stem + bead_r, at.z)
	_bead(bead_at, bead_r, Color.WHITE)
	_kit.glow_quad(bead_at, Vector3.RIGHT, SCREEN_UP, 0.34, 0.34, 0.4)
	var pinnacle_h := crown * 0.55
	var spike := PackedVector2Array([Vector2(0.0, pinnacle_h), Vector2(0.025, pinnacle_h * 0.55), Vector2(0.045, 0.03), Vector2(0.045, 0.0)])
	for px: float in [-1.0, 1.0]:
		for pz: float in [-1.0, 1.0]:
			var corner := Vector3(at.x + px * (hx - 0.2), at.y, at.z + pz * (hz - 0.2))
			_kit.add_box(_brass, Vector3(0.1, 0.04, 0.1), corner)
			_kit.add_lathe(_brass, corner + Vector3(0.0, 0.04, 0.0), Vector3.UP, spike, 6)

## A small sphere (a lathe of a half circle) of `radius` centred on `at`.
func _bead(at: Vector3, radius: float, color: Color) -> void:
	_kit.add_lathe(_lamp, at, Vector3.UP, RoomMeshKit.arc(Vector2.ZERO, radius, 90.0, -90.0, 6), 10, color)

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

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
	RoomBackWall.new(self).build(inner)
	RoomSideWalls.new(self).build(inner)
	RoomFrontWall.new(self).build(inner)
	RoomTowers.new(self).build(inner)
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

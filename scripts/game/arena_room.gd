class_name ArenaRoom
extends Node3D

## The shell around the playfield. The camera looks down at about 52 degrees from the south, so only faces turned up or
## towards the south ever show: a wall's inner face is invisible on the sides and the front. The walls are therefore profiles
## with a sloped, lit face: the side walls batter back from the room (a brass kick, a riveted slope, a brass coping), the front
## wall is a low parapet with a chamfered brass cap (anything taller would hide floor), and the back wall, whose inner face
## does show, has a plinth, sloped sill, open window bays onto the starfield, and a coping. Corner towers hide the joins.
## Hull plating is `hull_plating.gdshader`; light comes only from small lamps and the floor rim (all below the bloom threshold).
const HULL_SHADER: Shader = preload("res://assets/shaders/hull_plating.gdshader")
const GAP: float = 0.12 # clear space between the arena bounds and the wall faces (the floor rim sits inside it)
const HULL_DEPTH: float = 6.0 # walls reach this far below the floor so their outer faces read as a hull
const LAMP_ENERGY: float = 0.6

const BACK_HEIGHT: float = 2.62 # top of the coping
const BACK_TOP_DEPTH: float = 0.9 # how far the coping reaches behind the inner face
const SILL_HEIGHT: float = 0.58
const LINTEL_BOTTOM: float = 2.1
const LINTEL_TOP: float = 2.5
const PILLAR_WIDTH: float = 0.6
const PILLAR_PITCH: float = 3.2
const SIDE_HEIGHT: float = 1.6
const SIDE_DEPTH: float = 1.5 # how far the side walls reach out from the inner face
const FRONT_HEIGHT: float = 0.5
const FRONT_DEPTH: float = 0.45
const BACK_TOWER_HEIGHT: float = 2.8
const FRONT_TOWER_HEIGHT: float = 1.9
## Metres the top HUD bar can hide at the top of the screen; the back camera margin leaves room for it.
const HUD_TOP_ALLOWANCE: float = 0.45

var _hull: ShaderMaterial
var _brass: StandardMaterial3D
var _frame: StandardMaterial3D
var _lamp: StandardMaterial3D

func _init() -> void:
	name = "Room"

## Builds the walls once; `apply_theme` then colours them.
func build() -> void:
	_hull = ShaderMaterial.new()
	_hull.shader = HULL_SHADER
	_brass = WorldGeometry.material(Color("84734c"))
	_brass.metallic = 0.4
	_brass.roughness = 0.65
	_brass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_frame = WorldGeometry.material(Color("18242d"))
	_frame.metallic = 0.7
	_frame.roughness = 0.45
	_lamp = WorldGeometry.material(Color.WHITE, true)
	_lamp.emission_energy_multiplier = LAMP_ENERGY
	var inner := WorldGeometry.HALF_ARENA + Vector2.ONE * GAP
	_build_back(inner)
	_build_sides(inner)
	_build_front(inner)
	_build_towers(inner)

## Re-skins the hull for a floor theme and lights the lamps in its rim colour.
func apply_theme(theme: String, lamp_color: Color) -> void:
	_hull.set_shader_parameter("base_color", WorldGeometry.hull_color(theme))
	_lamp.albedo_color = lamp_color
	_lamp.emission = lamp_color

func _build_back(inner: Vector2) -> void:
	var z_face := -inner.y
	var width := inner.x * 2.0
	var origin := Vector3(0.0, 0.0, z_face)
	_extrude([PackedVector2Array([Vector2(0, 0), Vector2(0, 0.35)]), PackedVector2Array([Vector2(0, LINTEL_BOTTOM), Vector2(0, LINTEL_TOP)])],
		_hull, origin, Vector3.FORWARD, Vector3.RIGHT, width)
	# The sill slopes up and away, so it shows as a lit ledge; the coping is flat on top.
	_extrude([PackedVector2Array([Vector2(0, 0.35), Vector2(0.05, 0.4), Vector2(0.45, SILL_HEIGHT)]),
		PackedVector2Array([Vector2(0, LINTEL_TOP), Vector2(0, BACK_HEIGHT), Vector2(BACK_TOP_DEPTH, BACK_HEIGHT)])],
		_brass, origin, Vector3.FORWARD, Vector3.RIGHT, width)
	var count := maxi(2, roundi(width / PILLAR_PITCH))
	var pitch := width / count
	var depth := BACK_TOP_DEPTH
	for index in count + 1:
		var x := -inner.x + index * pitch
		_block(Vector3(PILLAR_WIDTH, LINTEL_TOP + HULL_DEPTH, depth), Vector3(x, -HULL_DEPTH, z_face - depth * 0.5), _frame)
		for band_y: float in [SILL_HEIGHT - 0.12, LINTEL_BOTTOM - 0.1]:
			_block(Vector3(PILLAR_WIDTH + 0.08, 0.1, depth + 0.04), Vector3(x, band_y, z_face - depth * 0.5 + 0.02), _brass)
		_lamp_pip(Vector3(0.12, 0.5, 0.03), Vector3(x, 1.35, z_face + 0.01))

func _build_sides(inner: Vector2) -> void:
	var length := inner.y * 2.0 + 0.8 # the ends sit inside the corner towers
	for side: float in [-1.0, 1.0]:
		var origin := Vector3(side * inner.x, 0.0, 0.0)
		var outward := Vector3(side, 0.0, 0.0)
		_extrude([PackedVector2Array([Vector2(0, 0), Vector2(0, 0.3), Vector2(0.25, 0.3)]),
			PackedVector2Array([Vector2(1.0, 1.5), Vector2(1.0, SIDE_HEIGHT), Vector2(SIDE_DEPTH, SIDE_HEIGHT)])],
			_brass, origin, outward, Vector3.BACK, length)
		# The slope leans back about 58 degrees, which is the face the camera sees; the outer face drops to the hull.
		_extrude([PackedVector2Array([Vector2(0.25, 0.3), Vector2(1.0, 1.5)]),
			PackedVector2Array([Vector2(SIDE_DEPTH, SIDE_HEIGHT), Vector2(SIDE_DEPTH, -HULL_DEPTH)])],
			_hull, origin, outward, Vector3.BACK, length)

func _build_front(inner: Vector2) -> void:
	var width := inner.x * 2.0
	var origin := Vector3(0.0, 0.0, inner.y)
	# The inner face never shows; the cap slopes towards the camera so the top reads as a rail.
	_extrude([PackedVector2Array([Vector2(0, FRONT_HEIGHT), Vector2(0.12, FRONT_HEIGHT), Vector2(FRONT_DEPTH, FRONT_HEIGHT - 0.2)])],
		_brass, origin, Vector3.BACK, Vector3.RIGHT, width)
	_extrude([PackedVector2Array([Vector2(FRONT_DEPTH, FRONT_HEIGHT - 0.2), Vector2(FRONT_DEPTH, -HULL_DEPTH)])],
		_hull, origin, Vector3.BACK, Vector3.RIGHT, width)
	# A row of portholes on the outer face, which the camera sees below the parapet.
	var count := roundi(width / 1.6)
	var pitch := width / count
	for index in count:
		_lamp_pip(Vector3(0.45, 0.16, 0.04), Vector3(-inner.x + (index + 0.5) * pitch, -0.2, inner.y + FRONT_DEPTH + 0.01))

func _build_towers(inner: Vector2) -> void:
	for side: float in [-1.0, 1.0]:
		var x := side * (inner.x + SIDE_DEPTH * 0.5)
		_tower(Vector3(SIDE_DEPTH, BACK_TOWER_HEIGHT, 1.5), Vector2(x, -inner.y - 0.15))
		_tower(Vector3(SIDE_DEPTH, FRONT_TOWER_HEIGHT, 1.05), Vector2(x, inner.y - 0.075))

## A hull-plated column with a brass cap; `size.y` is its height above the floor.
func _tower(size: Vector3, centre: Vector2) -> void:
	_block(Vector3(size.x, size.y + HULL_DEPTH, size.z), Vector3(centre.x, -HULL_DEPTH, centre.y), _hull)
	_block(Vector3(size.x + 0.1, 0.12, size.z + 0.1), Vector3(centre.x, size.y, centre.y), _brass)

## Extrudes open cross-section polylines into one flat-shaded mesh. Points are (distance outward from `origin`, height); each
## segment faces to the left of its direction of travel (counter-clockwise), so draw a profile with its visible side on the left.
func _extrude(polylines: Array, mat: Material, origin: Vector3, outward: Vector3, along: Vector3, length: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var start := -along * length * 0.5
	for line: PackedVector2Array in polylines:
		for index in line.size() - 1:
			var from := line[index]
			var to := line[index + 1]
			var direction := (to - from).normalized()
			var normal := outward * -direction.y + Vector3.UP * direction.x
			var a0 := origin + outward * from.x + Vector3.UP * from.y + start
			var b0 := origin + outward * to.x + Vector3.UP * to.y + start
			_triangle(surface, a0, b0, a0 + along * length, normal)
			_triangle(surface, a0 + along * length, b0, b0 + along * length, normal)
	var instance := MeshInstance3D.new()
	instance.mesh = surface.commit()
	instance.material_override = mat
	add_child(instance)

## Adds a triangle wound so that its front face looks along `normal`.
func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	if (c - a).cross(b - a).dot(normal) < 0.0:
		var swap := b
		b = c
		c = swap
	for corner in [a, b, c]:
		surface.set_normal(normal)
		surface.add_vertex(corner)

## A box standing on `bottom_centre` (the middle of its underside).
func _block(size: Vector3, bottom_centre: Vector3, mat: Material) -> MeshInstance3D:
	return WorldGeometry.box(self, size, bottom_centre + Vector3(0.0, size.y * 0.5, 0.0), mat)

## A small glowing pad centred on `at`.
func _lamp_pip(size: Vector3, at: Vector3) -> void:
	WorldGeometry.box(self, size, at, _lamp).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

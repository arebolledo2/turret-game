class_name ArenaRoom
extends Node3D

## The shell around the playfield: a back wall of open window bays looking out onto space, solid side walls and a low front parapet. The
## camera looks down at about 52 degrees from the south, so the front wall is kept low enough not to hide the floor behind it,
## the side walls are seen from above as a coping, and the tall back wall shows its whole inner face. The hull plating reuses
## the floor theme's textures; the glow strips use the stage's rim material, which carries the theme colour.
const GAP: float = 0.12 # clear space between the arena bounds and the wall faces (the floor rim sits inside it)
const HULL_DEPTH: float = 6.0 # walls reach this far below the floor so the front wall reads as the side of a hull
const BACK_HEIGHT: float = 2.5
const SIDE_HEIGHT: float = 1.6
const FRONT_HEIGHT: float = 0.5
const BACK_THICKNESS: float = 0.7
const SIDE_THICKNESS: float = 0.9
const FRONT_THICKNESS: float = 0.7
const SILL_HEIGHT: float = 0.55
const LINTEL_BOTTOM: float = 2.1
const SILL_DEPTH: float = 0.45
const PILLAR_WIDTH: float = 0.55
const PILLAR_PITCH: float = 3.2

var _hull: StandardMaterial3D
var _frame: StandardMaterial3D
var _trim: Material
var _hull_meshes: Array[MeshInstance3D] = []

func _init() -> void:
	name = "Room"

## Builds the walls once. `trim` is the glowing material the stage tints per floor theme.
func build(trim: Material) -> void:
	_trim = trim
	_hull = WorldGeometry.hull_material(WorldGeometry.DEFAULT_FLOOR_THEME)
	_frame = WorldGeometry.material(Color("18242d"))
	_frame.metallic = 0.7
	_frame.roughness = 0.45
	var inner := WorldGeometry.HALF_ARENA + Vector2.ONE * GAP
	_build_back(inner)
	_build_sides(inner)
	_build_front(inner)

## Re-skins the hull plating with a floor theme's textures.
func apply_theme(theme: String) -> void:
	_hull = WorldGeometry.hull_material(theme)
	for mesh in _hull_meshes:
		mesh.material_override = _hull

func _build_back(inner: Vector2) -> void:
	var z_face := -inner.y
	var width := inner.x * 2.0
	_hull_block(Vector3(width, SILL_HEIGHT + HULL_DEPTH, SILL_DEPTH), Vector3(0.0, -HULL_DEPTH, z_face - SILL_DEPTH * 0.5))
	_hull_block(Vector3(width, BACK_HEIGHT - LINTEL_BOTTOM, BACK_THICKNESS), Vector3(0.0, LINTEL_BOTTOM, z_face - BACK_THICKNESS * 0.5))
	_trim_strip(Vector3(width, 0.05, 0.05), Vector3(0.0, SILL_HEIGHT + 0.025, z_face - 0.04))
	_trim_strip(Vector3(width, 0.05, 0.05), Vector3(0.0, LINTEL_BOTTOM - 0.03, z_face - 0.04))
	var count := maxi(2, roundi(width / PILLAR_PITCH))
	var pitch := width / count
	for index in count + 1:
		var x := -inner.x + index * pitch
		_block(Vector3(PILLAR_WIDTH, BACK_HEIGHT + HULL_DEPTH, BACK_THICKNESS), Vector3(x, -HULL_DEPTH, z_face - BACK_THICKNESS * 0.5), _frame)
		_trim_strip(Vector3(0.14, 0.5, 0.03), Vector3(x, LINTEL_BOTTOM - 0.45, z_face + 0.01))

func _build_sides(inner: Vector2) -> void:
	var length := inner.y * 2.0 + BACK_THICKNESS + FRONT_THICKNESS
	var z_centre := (FRONT_THICKNESS - BACK_THICKNESS) * 0.5
	for side: float in [-1.0, 1.0]:
		var x_face := side * inner.x
		_hull_block(Vector3(SIDE_THICKNESS, SIDE_HEIGHT + HULL_DEPTH, length), Vector3(x_face + side * SIDE_THICKNESS * 0.5, -HULL_DEPTH, z_centre))
		_trim_strip(Vector3(0.07, 0.05, length), Vector3(x_face + side * 0.05, SIDE_HEIGHT + 0.025, z_centre))

func _build_front(inner: Vector2) -> void:
	var z_face := inner.y
	var width := inner.x * 2.0
	_hull_block(Vector3(width, FRONT_HEIGHT + HULL_DEPTH, FRONT_THICKNESS), Vector3(0.0, -HULL_DEPTH, z_face + FRONT_THICKNESS * 0.5))
	_trim_strip(Vector3(width, 0.04, 0.05), Vector3(0.0, FRONT_HEIGHT + 0.02, z_face + 0.06))
	# A row of portholes on the outer face, which the camera sees below the parapet.
	var count := roundi(width / 1.6)
	var pitch := width / count
	for index in count:
		_trim_strip(Vector3(0.45, 0.16, 0.04), Vector3(-inner.x + (index + 0.5) * pitch, -0.2, z_face + FRONT_THICKNESS + 0.01))

## A box standing on `bottom_centre` (the middle of its underside).
func _block(size: Vector3, bottom_centre: Vector3, mat: Material) -> MeshInstance3D:
	return WorldGeometry.box(self, size, bottom_centre + Vector3(0.0, size.y * 0.5, 0.0), mat)

func _hull_block(size: Vector3, bottom_centre: Vector3) -> void:
	_hull_meshes.append(_block(size, bottom_centre, _hull))

## A thin glowing strip centred on `at`.
func _trim_strip(size: Vector3, at: Vector3) -> void:
	var strip := WorldGeometry.box(self, size, at, _trim)
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

class_name ArenaRoom
extends Node3D

## The shell around the playfield. The camera looks down at about 52 degrees from the south, so only faces turned up or
## towards the south ever show: a wall's inner face is invisible on the sides and the front. The walls are therefore profiles
## with a sloped, lit face: the side walls batter back from the room (a brass kick, a riveted slope, a moulded brass coping),
## the front wall is a low parapet with a rounded brass cap (anything taller would hide floor) over a ribbed, piped hull, and
## the back wall, whose inner face does show, has a plinth, a sloped sill, open window bays with mullions onto the starfield,
## fluted pillars and a dentilled coping. Stepped corner towers carry lanterns and hide the joins.
## Everything is merged into one mesh per material. Hull plating is `hull_plating.gdshader` and the brass `brass_trim.gdshader`;
## light comes from lamps (with soft additive pools), four lantern lights and the floor rim, all below the bloom threshold.
const HULL_SHADER: Shader = preload("res://assets/shaders/hull_plating.gdshader")
const BRASS_SHADER: Shader = preload("res://assets/shaders/brass_trim.gdshader")
## Render layer the room shares with the world; the stage's fill light only touches this one (see ArenaStage).
const LAYER: int = 1 << 18
const ROOM_LAYERS: int = 1 | LAYER
const GAP: float = 0.12 # clear space between the arena bounds and the wall faces (the floor rim sits inside it)
const HULL_DEPTH: float = 6.0 # walls reach this far below the floor so their outer faces read as a hull
const LAMP_ENERGY: float = 0.6
const SMOOTH_DOT: float = 0.766 # profile joints sharper than 40 degrees stay creased

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

## The hull plating material; its uniforms follow the floor theme.
var hull: ShaderMaterial
var _brass: ShaderMaterial
var _frame: StandardMaterial3D
var _dark: StandardMaterial3D
var _lamp: StandardMaterial3D
var _glow: StandardMaterial3D
var _batches: Dictionary = {}
var _glow_surface: SurfaceTool
var _lanterns: Array[OmniLight3D] = []

func _init() -> void:
	name = "Room"

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
	_dark = WorldGeometry.material(Color("0a1016"))
	_lamp = WorldGeometry.material(Color.WHITE, true)
	_lamp.emission_energy_multiplier = LAMP_ENERGY
	_glow = _make_glow_material()
	_glow_surface = SurfaceTool.new()
	_glow_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_back(inner)
	_build_sides(inner)
	_build_front(inner)
	_build_towers(inner)
	_flush()

## Re-skins the hull for a floor theme and lights the lamps and their pools in its rim colour.
func apply_theme(theme: String, lamp_color: Color) -> void:
	var motif := WorldGeometry.hull_motif(theme)
	hull.set_shader_parameter("base_color", WorldGeometry.hull_color(theme))
	hull.set_shader_parameter("motif", int(motif["motif"]))
	hull.set_shader_parameter("panel_size", motif["panel"])
	hull.set_shader_parameter("metal", float(motif["metal"]))
	_lamp.albedo_color = lamp_color
	_lamp.emission = lamp_color
	_glow.albedo_color = lamp_color
	for lantern in _lanterns:
		lantern.light_color = lamp_color.lerp(Color("ffd59a"), 0.6)

func lantern_lights() -> Array[OmniLight3D]:
	return _lanterns

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
	_extrude([PackedVector2Array([Vector2(0, 0), Vector2(0, 0.35)]), PackedVector2Array([Vector2(0, LINTEL_BOTTOM), Vector2(0, LINTEL_TOP)])],
		hull, origin, out, Vector3.RIGHT, width)
	# The sill slopes up and away, so it shows as a lit ledge. The coping has a rounded nose, a flat top and a raised rail.
	var coping := PackedVector2Array([Vector2(-0.06, LINTEL_TOP), Vector2(-0.06, 2.56)])
	coping.append_array(_arc(Vector2(0.0, 2.56), 0.06, 180.0, 90.0, 4))
	coping.append_array(PackedVector2Array([Vector2(0.34, 2.62), Vector2(0.38, BACK_HEIGHT), Vector2(0.58, BACK_HEIGHT),
		Vector2(0.62, 2.62), Vector2(BACK_TOP_DEPTH, 2.62)]))
	_extrude([PackedVector2Array([Vector2(0, 0.35), Vector2(0.05, 0.4), Vector2(0.45, SILL_HEIGHT)]), coping],
		_brass, origin, out, Vector3.RIGHT, width)
	var count := maxi(2, roundi(width / PILLAR_PITCH))
	var pitch := width / count
	var depth := BACK_TOP_DEPTH
	var zc := z_face - depth * 0.5
	for index in count + 1:
		var x := -inner.x + index * pitch
		_add_box(_frame, Vector3(PILLAR_WIDTH, LINTEL_TOP + HULL_DEPTH, depth), Vector3(x, -HULL_DEPTH, zc))
		_add_box(hull, Vector3(0.78, 0.2, depth + 0.06), Vector3(x, 0.0, zc + 0.03)) # plinth step
		_add_box(_brass, Vector3(PILLAR_WIDTH + 0.08, 0.08, depth + 0.04), Vector3(x, SILL_HEIGHT - 0.08, zc + 0.02))
		# Corbelled capital under the lintel.
		_add_box(_brass, Vector3(0.7, 0.1, depth + 0.04), Vector3(x, LINTEL_BOTTOM - 0.48, zc + 0.02))
		_add_box(_brass, Vector3(0.82, 0.18, depth + 0.06), Vector3(x, LINTEL_BOTTOM - 0.38, zc + 0.03))
		_add_box(_brass, Vector3(0.94, 0.1, depth + 0.08), Vector3(x, LINTEL_BOTTOM - 0.2, zc + 0.04))
		# Two flutes either side of the lamp.
		for flute: float in [-0.19, 0.19]:
			_add_box(_dark, Vector3(0.06, 1.0, 0.03), Vector3(x + flute, 0.7, z_face - 0.005))
		# Lamp: brass housing around a glass lens, with a soft pool of light on the floor below.
		_add_box(_brass, Vector3(0.2, 0.6, 0.04), Vector3(x, 1.05, z_face - 0.01))
		_add_box(_lamp, Vector3(0.12, 0.46, 0.03), Vector3(x, 1.12, z_face + 0.015))
		_glow_quad(Vector3(x, 0.012, z_face + 0.55), Vector3.RIGHT, Vector3.BACK, 0.65, 0.55, 0.18)
		if index < count:
			# Window frame: a mullion down the middle of the bay and a transom across it.
			var bay := x + pitch * 0.5
			_add_box(_brass, Vector3(0.05, LINTEL_BOTTOM - SILL_HEIGHT, 0.05), Vector3(bay, SILL_HEIGHT, z_face - 0.4))
			_add_box(_brass, Vector3(pitch - PILLAR_WIDTH, 0.05, 0.05), Vector3(bay, 1.3, z_face - 0.4))
	# A dentil row under the cornice, and bolts along the raised rail.
	var step := 0.16
	for index in int(width / step):
		_add_box(_brass, Vector3(0.08, 0.06, 0.05), Vector3(-inner.x + 0.1 + index * step, LINTEL_TOP - 0.07, z_face - 0.01))
	for index in int(width / 0.4):
		_add_box(_brass, Vector3(0.06, 0.02, 0.06), Vector3(-inner.x + 0.2 + index * 0.4, BACK_HEIGHT, z_face - 0.48))

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
		coping.append_array(_arc(Vector2(1.0, 1.56), 0.05, 180.0, 90.0, 4))
		coping.append_array(PackedVector2Array([Vector2(1.2, 1.61), Vector2(1.24, SIDE_HEIGHT), Vector2(1.38, SIDE_HEIGHT),
			Vector2(1.42, 1.61), Vector2(SIDE_DEPTH, 1.61)]))
		_extrude([PackedVector2Array([Vector2(0, 0), Vector2(0, 0.26), Vector2(0.04, 0.3), Vector2(0.25, 0.3)]), coping],
			_brass, origin, outward, Vector3.BACK, length)
		# The slope leans back about 58 degrees, which is the face the camera sees; the outer face drops to the hull.
		_extrude([PackedVector2Array([Vector2(0.25, 0.3), Vector2(1.0, 1.5)]),
			PackedVector2Array([Vector2(SIDE_DEPTH, 1.61), Vector2(SIDE_DEPTH, -HULL_DEPTH)])],
			hull, origin, outward, Vector3.BACK, length)
		for index in int(inner.y * 2.0 / 0.4):
			_add_box(_brass, Vector3(0.06, 0.02, 0.06), Vector3(side * (inner.x + 1.31), SIDE_HEIGHT, -inner.y + 0.2 + index * 0.4))
		# Lamp posts on the coping, each with a pool of light on the slope below (the ends hide in the towers).
		for index in range(1, count):
			var z := -inner.y + index * pitch
			var x := side * (inner.x + 1.31)
			_add_box(_brass, Vector3(0.08, 0.2, 0.08), Vector3(x, SIDE_HEIGHT, z))
			_add_box(_lamp, Vector3(0.12, 0.14, 0.12), Vector3(x, SIDE_HEIGHT + 0.2, z))
			var on_slope := Vector3(side * (inner.x + 0.62), 0.9, z)
			var along_slope := Vector3(side * 0.42, 0.91, 0.0).normalized()
			var normal := Vector3(-side * 0.85, 0.53, 0.0)
			_glow_quad(on_slope + normal * 0.012, along_slope, Vector3.BACK, 0.55, 0.62, 0.55)

# --- Front wall ------------------------------------------------------------------------------------------------------

func _build_front(inner: Vector2) -> void:
	var width := inner.x * 2.0
	var z_face := inner.y
	var origin := Vector3(0.0, 0.0, z_face)
	# The inner face never shows; the cap is a quarter round that falls towards the camera, so the top reads as a rail.
	var cap := PackedVector2Array([Vector2(0, FRONT_HEIGHT), Vector2(0.12, FRONT_HEIGHT)])
	cap.append_array(_arc(Vector2(0.12, 0.3), 0.2, 90.0, 0.0, 5))
	_extrude([cap], _brass, origin, Vector3.BACK, Vector3.RIGHT, width)
	_extrude([PackedVector2Array([Vector2(FRONT_DEPTH, 0.3), Vector2(FRONT_DEPTH, -HULL_DEPTH)])],
		hull, origin, Vector3.BACK, Vector3.RIGHT, width)
	var z_outer := z_face + FRONT_DEPTH
	var count := roundi(width / 1.6)
	var pitch := width / count
	for index in count + 1:
		# Buttress ribs run down the hull; nothing here rises above the parapet.
		_add_box(hull, Vector3(0.14, 2.8, 0.12), Vector3(-inner.x + index * pitch, -2.5, z_outer + 0.06))
	for index in count:
		var x := -inner.x + (index + 0.5) * pitch
		_add_cylinder(_brass, Vector3(x, -0.2, z_outer + 0.03), Vector3.BACK, 0.19, 0.06, 14)
		_add_cylinder(_lamp, Vector3(x, -0.2, z_outer + 0.07), Vector3.BACK, 0.13, 0.05, 14)
	# A rub-rail, and a pipe with clamps under it.
	_add_box(_brass, Vector3(width, 0.08, 0.08), Vector3(0.0, -0.6, z_outer + 0.04))
	_add_cylinder(_frame, Vector3(0.0, -0.82, z_outer + 0.1), Vector3.RIGHT, 0.05, width, 8)
	for index in int(width / 0.8):
		_add_box(_brass, Vector3(0.08, 0.16, 0.05), Vector3(-inner.x + 0.4 + index * 0.8, -0.9, z_outer + 0.1))
	for index in int(width / 0.4):
		_add_box(_brass, Vector3(0.06, 0.008, 0.06), Vector3(-inner.x + 0.2 + index * 0.4, FRONT_HEIGHT, z_face + 0.06))

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
	_add_box(hull, Vector3(size.x, body + HULL_DEPTH, size.z), Vector3(centre.x, -HULL_DEPTH, centre.y))
	_add_box(_brass, Vector3(size.x + 0.04, 0.1, size.z + 0.04), Vector3(centre.x, body, centre.y))
	_add_box(hull, Vector3(size.x - 0.04, 0.14, size.z - 0.04), Vector3(centre.x, body + 0.1, centre.y))
	_add_box(_brass, Vector3(size.x + 0.16, 0.08, size.z + 0.16), Vector3(centre.x, body + 0.24, centre.y))
	_add_box(_brass, Vector3(size.x - 0.2, 0.1, size.z - 0.2), Vector3(centre.x, body + 0.32, centre.y))
	var face_z := centre.y + size.z * 0.5
	var lantern_y := body * 0.5
	_add_box(_brass, Vector3(0.36, 0.52, 0.08), Vector3(centre.x, lantern_y - 0.26, face_z + 0.03))
	_add_box(_lamp, Vector3(0.24, 0.4, 0.06), Vector3(centre.x, lantern_y - 0.2, face_z + 0.08))
	var light := OmniLight3D.new()
	light.omni_range = 3.5
	light.light_energy = 0.7
	light.shadow_enabled = false
	light.position = Vector3(centre.x - side * 0.9, lantern_y, face_z + 0.45)
	add_child(light)
	_lanterns.append(light)

# --- Mesh building ---------------------------------------------------------------------------------------------------

func _batch(mat: Material) -> SurfaceTool:
	if not _batches.has(mat):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[mat] = surface
	return _batches[mat]

## Turns the collected geometry into one mesh per material.
func _flush() -> void:
	for mat: Material in _batches:
		var instance := MeshInstance3D.new()
		instance.mesh = (_batches[mat] as SurfaceTool).commit()
		instance.material_override = mat
		instance.layers = ROOM_LAYERS
		if mat == _lamp:
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	var glow_root := Node3D.new()
	glow_root.name = "Glow"
	add_child(glow_root)
	var glow := MeshInstance3D.new()
	glow.mesh = _glow_surface.commit()
	glow.material_override = _glow
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow_root.add_child(glow)

## Points of a circular arc in the (distance, height) profile plane, both ends included.
static func _arc(centre: Vector2, radius: float, from_degrees: float, to_degrees: float, steps: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in steps + 1:
		var angle := deg_to_rad(lerpf(from_degrees, to_degrees, float(index) / steps))
		result.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return result

## Extrudes open cross-section polylines into the material's batch. Points are (distance outward from `origin`, height); each
## segment faces to the left of its direction of travel (counter-clockwise), so draw a profile with its visible side on the
## left. Joints gentler than 40 degrees share a smoothed normal, so arcs look round; sharper ones stay creased.
func _extrude(polylines: Array, mat: Material, origin: Vector3, outward: Vector3, along: Vector3, length: float) -> void:
	var surface := _batch(mat)
	var start := -along * length * 0.5
	for line: PackedVector2Array in polylines:
		var count := line.size() - 1
		var normals: Array[Vector2] = []
		for index in count:
			var direction := (line[index + 1] - line[index]).normalized()
			normals.append(Vector2(-direction.y, direction.x))
		for index in count:
			var n_a := normals[index]
			var n_b := normals[index]
			if index > 0 and normals[index - 1].dot(n_a) > SMOOTH_DOT:
				n_a = (normals[index - 1] + n_a).normalized()
			if index < count - 1 and normals[index + 1].dot(n_b) > SMOOTH_DOT:
				n_b = (normals[index + 1] + n_b).normalized()
			var normal_a := outward * n_a.x + Vector3.UP * n_a.y
			var normal_b := outward * n_b.x + Vector3.UP * n_b.y
			var a0 := origin + outward * line[index].x + Vector3.UP * line[index].y + start
			var b0 := origin + outward * line[index + 1].x + Vector3.UP * line[index + 1].y + start
			_triangle(surface, a0, b0, a0 + along * length, normal_a, normal_b, normal_a)
			_triangle(surface, a0 + along * length, b0, b0 + along * length, normal_a, normal_b, normal_b)

## Adds a triangle wound so that its front face looks along its normals.
func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3) -> void:
	if (c - a).cross(b - a).dot(na + nb + nc) < 0.0:
		var swap_point := b
		b = c
		c = swap_point
		var swap_normal := nb
		nb = nc
		nc = swap_normal
	surface.set_normal(na)
	surface.add_vertex(a)
	surface.set_normal(nb)
	surface.add_vertex(b)
	surface.set_normal(nc)
	surface.add_vertex(c)

## A box standing on `bottom_centre` (the middle of its underside); the underside is left out.
func _add_box(mat: Material, size: Vector3, bottom_centre: Vector3) -> void:
	var surface := _batch(mat)
	var half := size * 0.5
	var centre := bottom_centre + Vector3(0.0, half.y, 0.0)
	for normal: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.BACK, Vector3.FORWARD]:
		var u := normal.cross(Vector3.UP) if absf(normal.y) < 0.5 else normal.cross(Vector3.RIGHT)
		u = u.normalized()
		var v := normal.cross(u)
		var face := centre + normal * normal.abs().dot(half)
		var du := u * u.abs().dot(half)
		var dv := v * v.abs().dot(half)
		_triangle(surface, face - du - dv, face + du - dv, face + du + dv, normal, normal, normal)
		_triangle(surface, face - du - dv, face + du + dv, face - du + dv, normal, normal, normal)

## A closed prism with `sides` facets along `axis`, centred on `centre`.
func _add_cylinder(mat: Material, centre: Vector3, axis: Vector3, radius: float, length: float, sides: int) -> void:
	var surface := _batch(mat)
	var u := axis.cross(Vector3.UP)
	if u.length() < 0.1:
		u = axis.cross(Vector3.RIGHT)
	u = u.normalized()
	var v := axis.cross(u)
	var half := axis * length * 0.5
	for index in sides:
		var angle_0 := TAU * index / sides
		var angle_1 := TAU * (index + 1) / sides
		var d0 := u * cos(angle_0) + v * sin(angle_0)
		var d1 := u * cos(angle_1) + v * sin(angle_1)
		var p0 := centre - half + d0 * radius
		var p1 := centre - half + d1 * radius
		_triangle(surface, p0, p1, p0 + axis * length, d0, d1, d0)
		_triangle(surface, p0 + axis * length, p1, p1 + axis * length, d0, d1, d1)
		_triangle(surface, centre + half, centre + half + d0 * radius, centre + half + d1 * radius, axis, axis, axis)
		_triangle(surface, centre - half, centre - half + d0 * radius, centre - half + d1 * radius, -axis, -axis, -axis)

## A soft additive light pool: a quad centred on `at`, `half_u` and `half_v` metres either way along the given axes.
## An alpha of zero adds nothing.
func _glow_quad(at: Vector3, axis_u: Vector3, axis_v: Vector3, half_u: float, half_v: float, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var du := axis_u.normalized() * half_u
	var dv := axis_v.normalized() * half_v
	var corners: Array[Vector3] = [at - du - dv, at + du - dv, at + du + dv, at - du + dv]
	var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for index: int in [0, 1, 2, 0, 2, 3]:
		_glow_surface.set_color(Color(1, 1, 1, alpha))
		_glow_surface.set_uv(uvs[index])
		_glow_surface.add_vertex(corners[index])

class_name RoomMeshKit
extends RefCounted

## Collects boxes, prisms, quads and extruded profiles into one mesh per material, so a whole room costs a handful of draw
## calls. Used by `ArenaRoom` and `ShipExterior`. Every vertex carries a colour (white by default); materials that set
## `vertex_color_use_as_albedo` use it to paint individual pieces, others ignore it.
const SMOOTH_DOT: float = 0.766 # profile joints sharper than 40 degrees stay creased

var _batches: Dictionary = {}
var _glow_surface := SurfaceTool.new()
var _glow_vertices: int = 0

func _init() -> void:
	_glow_surface.begin(Mesh.PRIMITIVE_TRIANGLES)

func batch(mat: Material) -> SurfaceTool:
	if not _batches.has(mat):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[mat] = surface
	return _batches[mat]

## Turns the collected geometry into one MeshInstance3D per material under `parent`, plus a `Glow` child holding the additive
## quads. Materials in `no_shadow` (and, with `all_shadowless`, every mesh) cast no shadow.
func flush(parent: Node3D, layers: int, glow_material: Material, no_shadow: Array = [], all_shadowless: bool = false) -> void:
	for mat: Material in _batches:
		var instance := MeshInstance3D.new()
		instance.mesh = (_batches[mat] as SurfaceTool).commit()
		instance.material_override = mat
		instance.layers = layers
		if all_shadowless or no_shadow.has(mat):
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(instance)
	if _glow_vertices == 0:
		return
	var glow_root := Node3D.new()
	glow_root.name = "Glow"
	parent.add_child(glow_root)
	var glow := MeshInstance3D.new()
	glow.mesh = _glow_surface.commit()
	glow.material_override = glow_material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow_root.add_child(glow)

## Points of a circular arc in the (distance, height) profile plane, both ends included.
static func arc(centre: Vector2, radius: float, from_degrees: float, to_degrees: float, steps: int) -> PackedVector2Array:
	var result := PackedVector2Array()
	for index in steps + 1:
		var angle := deg_to_rad(lerpf(from_degrees, to_degrees, float(index) / steps))
		result.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return result

## Extrudes open cross-section polylines. Points are (distance outward from `origin`, height); each segment faces to the left
## of its direction of travel (counter-clockwise), so draw a profile with its visible side on the left. Joints gentler than
## 40 degrees share a smoothed normal, so arcs look round; sharper ones stay creased.
func extrude(polylines: Array, mat: Material, origin: Vector3, outward: Vector3, along: Vector3, length: float) -> void:
	var surface := batch(mat)
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
			triangle(surface, a0, b0, a0 + along * length, normal_a, normal_b, normal_a, Color.WHITE)
			triangle(surface, a0 + along * length, b0, b0 + along * length, normal_a, normal_b, normal_b, Color.WHITE)

## Adds a triangle wound so that its front face looks along its normals.
func triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, na: Vector3, nb: Vector3, nc: Vector3, color: Color) -> void:
	if (c - a).cross(b - a).dot(na + nb + nc) < 0.0:
		var swap_point := b
		b = c
		c = swap_point
		var swap_normal := nb
		nb = nc
		nc = swap_normal
	surface.set_color(color)
	surface.set_normal(na)
	surface.add_vertex(a)
	surface.set_color(color)
	surface.set_normal(nb)
	surface.add_vertex(b)
	surface.set_color(color)
	surface.set_normal(nc)
	surface.add_vertex(c)

## An axis-aligned box standing on `bottom_centre` (the middle of its underside); the underside is left out.
func add_box(mat: Material, size: Vector3, bottom_centre: Vector3, color: Color = Color.WHITE) -> void:
	var surface := batch(mat)
	var half := size * 0.5
	var centre := bottom_centre + Vector3(0.0, half.y, 0.0)
	for normal: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.BACK, Vector3.FORWARD]:
		var u := normal.cross(Vector3.UP) if absf(normal.y) < 0.5 else normal.cross(Vector3.RIGHT)
		u = u.normalized()
		var v := normal.cross(u)
		var face := centre + normal * normal.abs().dot(half)
		var du := u * u.abs().dot(half)
		var dv := v * v.abs().dot(half)
		triangle(surface, face - du - dv, face + du - dv, face + du + dv, normal, normal, normal, color)
		triangle(surface, face - du - dv, face + du + dv, face - du + dv, normal, normal, normal, color)

## A box of `size` (along the basis's x, y, z) centred on `centre` and turned by `basis`; all six faces.
func add_oriented_box(mat: Material, size: Vector3, centre: Vector3, basis: Basis, color: Color = Color.WHITE) -> void:
	var surface := batch(mat)
	var half := size * 0.5
	var axes: Array[Vector3] = [basis.x, basis.y, basis.z]
	for axis_index in 3:
		for sign_value: float in [-1.0, 1.0]:
			var normal: Vector3 = axes[axis_index] * sign_value
			var u: Vector3 = axes[(axis_index + 1) % 3] * half[(axis_index + 1) % 3]
			var v: Vector3 = axes[(axis_index + 2) % 3] * half[(axis_index + 2) % 3]
			var face := centre + normal * half[axis_index]
			triangle(surface, face - u - v, face + u - v, face + u + v, normal, normal, normal, color)
			triangle(surface, face - u - v, face + u + v, face - u + v, normal, normal, normal, color)

## A closed prism with `sides` facets along `axis`, centred on `centre`.
func add_cylinder(mat: Material, centre: Vector3, axis: Vector3, radius: float, length: float, sides: int, color: Color = Color.WHITE) -> void:
	var surface := batch(mat)
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
		triangle(surface, p0, p1, p0 + axis * length, d0, d1, d0, color)
		triangle(surface, p0 + axis * length, p1, p1 + axis * length, d0, d1, d1, color)
		triangle(surface, centre + half, centre + half + d0 * radius, centre + half + d1 * radius, axis, axis, axis, color)
		triangle(surface, centre - half, centre - half + d0 * radius, centre - half + d1 * radius, -axis, -axis, -axis, color)

## A soft additive light pool: a quad centred on `at`, `half_u` and `half_v` metres either way along the given axes.
## An alpha of zero adds nothing.
func glow_quad(at: Vector3, axis_u: Vector3, axis_v: Vector3, half_u: float, half_v: float, alpha: float) -> void:
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
		_glow_vertices += 1

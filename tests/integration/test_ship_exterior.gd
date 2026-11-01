extends GutTest

## The ship exterior (props, decks, nacelles, back deck) and the RoomMeshKit helpers it relies on (lathe, tube, torus, quad,
## per-vertex colours). Headless: no shaders are compiled, so these check geometry, materials and budgets only.

const INNER := Vector2(12.82, 9.05)

var _room: Node3D
var _materials: Dictionary

func before_each() -> void:
	_room = Node3D.new()
	add_child_autofree(_room)
	_materials = {"hull": StandardMaterial3D.new(), "brass": StandardMaterial3D.new(), "frame": StandardMaterial3D.new(),
		"paint": StandardMaterial3D.new(), "glow": StandardMaterial3D.new()}
	(_materials["paint"] as StandardMaterial3D).vertex_color_use_as_albedo = true

func _build() -> Node:
	ShipExterior.new().build(_room, _materials, INNER)
	return _room.get_node("Exterior")

func _meshes(exterior: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in exterior.get_children():
		if child is MeshInstance3D:
			result.append(child)
	return result

func _arrays(mesh: MeshInstance3D) -> Array:
	return (mesh.mesh as ArrayMesh).surface_get_arrays(0)

func _mesh_for(exterior: Node, material: Material) -> MeshInstance3D:
	for mesh in _meshes(exterior):
		if mesh.material_override == material:
			return mesh
	return null

func _triangle_count(mesh: MeshInstance3D) -> int:
	return (_arrays(mesh)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3

## Every triangle's winding must agree with its stored normals, and no triangle may be degenerate.
func _assert_faces_match_normals(mesh: ArrayMesh, label: String) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_gt(vertices.size(), 0, label)
	var bad := 0
	for index in range(0, vertices.size(), 3):
		var geometric := (vertices[index + 2] - vertices[index]).cross(vertices[index + 1] - vertices[index])
		if geometric.length() < 0.0000001:
			bad += 1
			continue
		if geometric.dot(normals[index] + normals[index + 1] + normals[index + 2]) <= 0.0:
			bad += 1
	assert_eq(bad, 0, "%s: faces facing the wrong way or degenerate" % label)

func _kit_mesh(kit: RoomMeshKit, material: Material) -> ArrayMesh:
	return kit.batch(material).commit()

# --- RoomMeshKit helpers --------------------------------------------------------------------------------------------------

func test_lathe_dome_is_closed_smooth_and_has_no_degenerate_faces() -> void:
	var kit := RoomMeshKit.new()
	var material := StandardMaterial3D.new()
	kit.add_lathe(material, Vector3.ZERO, Vector3.UP, RoomMeshKit.arc(Vector2.ZERO, 1.0, 90.0, 0.0, 6), 12)
	var mesh := _kit_mesh(kit, material)
	_assert_faces_match_normals(mesh, "dome")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	# 6 segments of 12 sides: the first ring is a fan of single triangles, the rest are quads.
	assert_eq(vertices.size() / 3, 12 + 5 * 12 * 2)
	var highest := -INF
	for index in vertices.size():
		assert_almost_eq(vertices[index].length(), 1.0, 0.001, "every dome vertex is on the unit sphere")
		highest = maxf(highest, vertices[index].y)
		assert_gt(normals[index].dot(vertices[index].normalized()), 0.9, "smooth normals face outwards")
	assert_almost_eq(highest, 1.0, 0.001)

func test_lathe_dish_profile_faces_into_the_bowl() -> void:
	var kit := RoomMeshKit.new()
	var material := StandardMaterial3D.new()
	# Traced from the vertex outwards, a concave bowl faces up the axis.
	var profile := PackedVector2Array()
	for index in 5:
		var r := 0.25 * index
		profile.append(Vector2(r, r * r))
	kit.add_lathe(material, Vector3.ZERO, Vector3.UP, profile, 10)
	var arrays := _kit_mesh(kit, material).surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for normal in normals:
		assert_gt(normal.y, 0.0, "the bowl faces up the axis")
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in range(0, vertices.size()):
		var radial := Vector2(vertices[index].x, vertices[index].z)
		assert_lt(normals[index].dot(Vector3(radial.x, 0.0, radial.y)), 0.0001, "and inwards, towards the axis")

func test_lathe_follows_an_arbitrary_axis_and_origin() -> void:
	var kit := RoomMeshKit.new()
	var material := StandardMaterial3D.new()
	var origin := Vector3(3, 2, -1)
	# A cylinder 2 long traced from its high end down, radius 0.5, along +x.
	kit.add_lathe(material, origin, Vector3.RIGHT, PackedVector2Array([Vector2(0.5, 2.0), Vector2(0.5, 0.0)]), 8)
	var mesh := _kit_mesh(kit, material)
	_assert_faces_match_normals(mesh, "x axis cylinder")
	for vertex: Vector3 in mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		assert_between(vertex.x, origin.x - 0.001, origin.x + 2.001)
		assert_almost_eq(Vector2(vertex.y - origin.y, vertex.z - origin.z).length(), 0.5, 0.001)

func test_lathe_colours_follow_the_profile_points() -> void:
	var kit := RoomMeshKit.new()
	var material := StandardMaterial3D.new()
	var colours := PackedColorArray([Color.RED, Color.BLUE])
	kit.add_lathe(material, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(0.5, 1.0), Vector2(0.5, 0.0)]), 6, Color.WHITE, colours)
	var arrays := _kit_mesh(kit, material).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var vertex_colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for index in vertices.size():
		assert_eq(vertex_colours[index], Color.RED if vertices[index].y > 0.5 else Color.BLUE)

func test_lathe_ignores_degenerate_input() -> void:
	var kit := RoomMeshKit.new()
	var material := StandardMaterial3D.new()
	kit.add_lathe(material, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(1, 1)]), 8)
	kit.add_lathe(material, Vector3.ZERO, Vector3.ZERO, PackedVector2Array([Vector2(1, 1), Vector2(1, 0)]), 8)
	kit.add_lathe(material, Vector3.ZERO, Vector3.UP, PackedVector2Array([Vector2(1, 1), Vector2(1, 1)]), 8)
	var holder := Node3D.new()
	add_child_autofree(holder)
	kit.flush(holder, 1, StandardMaterial3D.new())
	assert_eq(holder.get_child_count(), 0, "nothing was emitted")

func test_torus_rings_the_axis_at_the_given_radius() -> void:
	var kit := RoomMeshKit.new()
	var material := StandardMaterial3D.new()
	kit.add_torus(material, Vector3(0, 1, 0), Vector3.UP, 1.0, 0.1, 12, 10)
	var mesh := _kit_mesh(kit, material)
	_assert_faces_match_normals(mesh, "torus")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for index in vertices.size():
		var radial := Vector3(vertices[index].x, 0.0, vertices[index].z)
		assert_between(radial.length(), 0.899, 1.101)
		assert_between(vertices[index].y, 0.899, 1.101)
		# The normal points away from the tube's centre line.
		var centre_line := radial.normalized()
		var from_tube := vertices[index] - Vector3(0, 1, 0) - centre_line
		assert_gt(normals[index].dot(from_tube.normalized()), 0.8, "the torus faces outwards from its tube")

func test_tube_runs_along_its_path_with_capped_ends() -> void:
	var kit := RoomMeshKit.new()
	var material := StandardMaterial3D.new()
	var path := PackedVector3Array()
	for index in 9: # a quarter bend from +x to +y
		var angle := 0.5 * PI * index / 8.0
		path.append(Vector3(sin(angle), 1.0 - cos(angle), 0.0))
	kit.add_tube(material, path, 0.1, 8)
	var mesh := _kit_mesh(kit, material)
	_assert_faces_match_normals(mesh, "tube")
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	assert_eq(vertices.size() / 3, 8 * 2 * 8 + 2 * 8, "8 quads of 8 sides, and a fan at each end")
	for vertex in vertices:
		var nearest := INF
		for point in path:
			nearest = minf(nearest, vertex.distance_to(point))
		assert_lt(nearest, 0.2, "every vertex hugs the path")
	var uncapped := RoomMeshKit.new()
	uncapped.add_tube(material, path, 0.1, 8, Color.WHITE, false)
	assert_eq(uncapped.batch(material).commit().surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() / 3, 8 * 2 * 8)

func test_tube_with_one_point_adds_nothing() -> void:
	var kit := RoomMeshKit.new()
	var material := StandardMaterial3D.new()
	kit.add_tube(material, PackedVector3Array([Vector3.ZERO]), 0.1, 8)
	assert_eq(kit.batch(material).commit().get_surface_count(), 0)

func test_quad_faces_along_u_cross_v() -> void:
	var kit := RoomMeshKit.new()
	var material := StandardMaterial3D.new()
	kit.add_quad(material, Vector3(0, 2, 0), Vector3.BACK, Vector3.RIGHT, 1.0, 0.5, Color.GREEN)
	var arrays := _kit_mesh(kit, material).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_eq(vertices.size(), 6)
	for index in vertices.size():
		assert_true(normals[index].is_equal_approx(Vector3.UP) or normals[index].distance_to(Vector3.UP) < 0.001, "BACK x RIGHT is up")
		assert_almost_eq(vertices[index].y, 2.0, 0.0001)
		assert_lte(absf(vertices[index].z), 1.0001)
		assert_lte(absf(vertices[index].x), 0.5001)
	_assert_faces_match_normals(_kit_mesh(kit, material), "quad")

func test_coloured_triangle_keeps_each_colour_with_its_vertex_when_flipped() -> void:
	var kit := RoomMeshKit.new()
	var material := StandardMaterial3D.new()
	var surface := kit.batch(material)
	var a := Vector3(0, 0, 0)
	var b := Vector3(0, 0, 1)
	var c := Vector3(1, 0, 0)
	# This winding faces down against an upward normal, so the helper swaps b and c.
	kit.triangle_colored(surface, a, b, c, Vector3.UP, Vector3.UP, Vector3.UP, Color.RED, Color.GREEN, Color.BLUE)
	var arrays := surface.commit().surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for index in 3:
		if vertices[index].is_equal_approx(b):
			assert_eq(colours[index], Color.GREEN)
		elif vertices[index].is_equal_approx(c):
			assert_eq(colours[index], Color.BLUE)
		else:
			assert_eq(colours[index], Color.RED)
	_assert_faces_match_normals(surface.commit(), "coloured triangle")

# --- ShipExterior --------------------------------------------------------------------------------------------------------

func test_exterior_is_shadowless_and_inside_the_mesh_budget() -> void:
	var exterior := _build()
	var meshes := _meshes(exterior)
	assert_between(meshes.size(), 6, 9, "the exterior's share of the 15 draw-call budget")
	for mesh in meshes:
		assert_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert_eq(mesh.layers, ArenaRoom.ROOM_LAYERS)

func test_exterior_triangle_count_stays_reasonable() -> void:
	var exterior := _build()
	var triangles := 0
	for mesh in _meshes(exterior):
		triangles += _triangle_count(mesh)
	gut.p("exterior triangles: %d" % triangles)
	assert_gt(triangles, 5000, "a detailed ship")
	assert_lt(triangles, 60000)

func test_exterior_geometry_is_deterministic() -> void:
	var first := _build()
	var count_a := 0
	for mesh in _meshes(first):
		count_a += _triangle_count(mesh)
	_room.remove_child(first)
	first.free()
	var second := _build()
	var count_b := 0
	for mesh in _meshes(second):
		count_b += _triangle_count(mesh)
	assert_eq(count_a, count_b)

func test_every_exterior_face_matches_its_normals() -> void:
	var exterior := _build()
	for mesh in _meshes(exterior):
		_assert_faces_match_normals(mesh.mesh as ArrayMesh, str(mesh.material_override))

func test_glossy_cell_material_catches_the_sky() -> void:
	var exterior := _build()
	var cell: StandardMaterial3D = null
	for mesh in _meshes(exterior):
		var material := mesh.material_override as StandardMaterial3D
		if material and material.metallic >= 0.69 and material.vertex_color_use_as_albedo and material.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL:
			cell = material
	assert_not_null(cell, "a metallic vertex-coloured cell material")
	assert_lte(cell.roughness, 0.3)
	var mesh := _mesh_for(exterior, cell)
	var darkest := 1.0
	var colours: PackedColorArray = _arrays(mesh)[Mesh.ARRAY_COLOR]
	var cells := 0
	for colour in colours:
		if colour.b > colour.r * 1.8 and colour.b < 0.3: # near-black blue cells
			cells += 1
			darkest = minf(darkest, colour.b)
	assert_gt(cells, 500, "a grid of cells")
	assert_lt(darkest, 0.2, "the cells are dark")

func test_unlit_exterior_lamps_stay_below_the_bloom_threshold() -> void:
	var exterior := _build()
	var found := false
	for mesh in _meshes(exterior):
		var material := mesh.material_override as StandardMaterial3D
		if material and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and material.blend_mode == BaseMaterial3D.BLEND_MODE_MIX:
			found = true
			assert_lt(maxf(material.albedo_color.r, maxf(material.albedo_color.g, material.albedo_color.b)), 0.9)
			for colour: Color in _arrays(mesh)[Mesh.ARRAY_COLOR]:
				assert_lte(maxf(colour.r, maxf(colour.g, colour.b)) * material.albedo_color.r, 0.9)
	assert_true(found)

func test_contact_shade_multiplies_and_never_brightens() -> void:
	var exterior := _build()
	var shade: StandardMaterial3D = null
	for mesh in _meshes(exterior):
		var material := mesh.material_override as StandardMaterial3D
		if material and material.blend_mode == BaseMaterial3D.BLEND_MODE_MUL:
			shade = material
	assert_not_null(shade, "a multiply material")
	var mesh := _mesh_for(exterior, shade)
	var colours: PackedColorArray = _arrays(mesh)[Mesh.ARRAY_COLOR]
	var darkest := 1.0
	var vertices: PackedVector3Array = _arrays(mesh)[Mesh.ARRAY_VERTEX]
	assert_gt(vertices.size(), 30 * 20, "dozens of blobs")
	for colour in colours:
		assert_lte(colour.r, 1.0)
		assert_eq(colour.a, 1.0)
		darkest = minf(darkest, colour.r)
	assert_lt(darkest, 0.7, "centres are dark")
	assert_gt(darkest, 0.3, "but never black")

func test_side_decks_reach_the_back_deck_so_no_gap_shows_at_the_corners() -> void:
	var exterior := _build()
	var hull := _mesh_for(exterior, _materials["hull"])
	var z_far := -INNER.y - ArenaRoom.BACK_TOP_DEPTH - 0.05 - ShipExterior.BACK_DECK_DEPTH
	var outer_x := INNER.x + ArenaRoom.SIDE_DEPTH
	for side: float in [-1.0, 1.0]:
		var north := INF
		var reach := 0.0
		for vertex: Vector3 in _arrays(hull)[Mesh.ARRAY_VERTEX]:
			if side * vertex.x > outer_x + 0.1 and absf(vertex.y - ShipExterior.DECK_TOP) < 0.01:
				north = minf(north, vertex.z)
				reach = maxf(reach, side * vertex.x)
		assert_almost_eq(north, z_far, 0.01, "the side deck runs north to the back deck's far edge")
		assert_almost_eq(reach, outer_x + ShipExterior.DECK_WIDTH, 0.01)
	# And the back deck itself spans under the side decks.
	var widest := 0.0
	for vertex: Vector3 in _arrays(hull)[Mesh.ARRAY_VERTEX]:
		if absf(vertex.y - ShipExterior.BACK_DECK_TOP) < 0.01:
			widest = maxf(widest, absf(vertex.x))
	assert_gt(widest, outer_x)

func test_nothing_stands_inside_the_playfield() -> void:
	var exterior := _build()
	var half := WorldGeometry.HALF_ARENA
	for mesh in _meshes(exterior):
		for vertex: Vector3 in _arrays(mesh)[Mesh.ARRAY_VERTEX]:
			assert_false(absf(vertex.x) < half.x and absf(vertex.z) < half.y and vertex.y > -0.5, "%s is inside the playfield" % vertex)

func test_side_decks_differ_so_the_two_sides_are_not_mirror_images() -> void:
	assert_ne(ShipExterior.MODULES_LEFT, ShipExterior.MODULES_RIGHT)
	for module in ShipExterior.MODULES_LEFT:
		assert_has(["wing", "dish", "containers", "radiator", "tank", "comms"], module)
	var kinds := {}
	for module in ShipExterior.MODULES_LEFT + ShipExterior.MODULES_RIGHT:
		kinds[module] = true
	assert_gte(kinds.size(), 6, "all six module kinds appear somewhere")

func test_props_reach_a_decent_variety_of_heights() -> void:
	var exterior := _build()
	var highest := -INF
	var side_x := INNER.x + ArenaRoom.SIDE_DEPTH
	var heights := {}
	for mesh in _meshes(exterior):
		for vertex: Vector3 in _arrays(mesh)[Mesh.ARRAY_VERTEX]:
			if absf(vertex.x) > side_x + 0.5 and vertex.z > -9.0 and vertex.z < 6.0:
				highest = maxf(highest, vertex.y)
				heights[snappedf(vertex.y, 0.5)] = true
	assert_gt(highest, ShipExterior.DECK_TOP + 1.0, "props rise well above the deck")
	assert_gte(heights.size(), 5, "silhouettes at many heights")

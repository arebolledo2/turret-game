extends GutTest

## The corner towers' cupolas, the glow cones that replaced the slopes' round pools, and the per-bay trim (enamel insets on the back
## sill and the side copings, cables, door furniture). Headless runs cannot render, so these read the room's meshes.

var world: ArenaWorld
var room: ArenaRoom
var inner: Vector2

func before_each() -> void:
	TestHelpers.reset_all_services()
	FeatureFlagService.set_enabled(FeatureFlagService.TERRAIN_ZONES, true)
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child_autofree(world)
	world.start_run()
	room = world.stage.room
	inner = WorldGeometry.HALF_ARENA + Vector2.ONE * ArenaRoom.GAP

## Every vertex of the room's mesh that uses `material` (the room sits at the origin, so these are world positions).
func _vertices_of(material: Material) -> PackedVector3Array:
	for child in room.get_children():
		var instance := child as MeshInstance3D
		if instance != null and instance.material_override == material and instance.mesh is ArrayMesh:
			return (instance.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	return PackedVector3Array()

## The footprints of the four towers as (min x, max x, min z, max z, height).
func _towers() -> Array[Array]:
	var result: Array[Array] = []
	for side: float in [-1.0, 1.0]:
		var x0 := inner.x if side > 0.0 else -inner.x - ArenaRoom.SIDE_DEPTH
		result.append([x0 + 0.05, x0 + ArenaRoom.SIDE_DEPTH - 0.05, -inner.y - 0.15 - 0.7, -inner.y - 0.15 + 0.7, ArenaRoom.BACK_TOWER_HEIGHT, ArenaRoom.BACK_CROWN])
		result.append([x0 + 0.05, x0 + ArenaRoom.SIDE_DEPTH - 0.05, inner.y - 0.075 - 0.47, inner.y - 0.075 + 0.47, ArenaRoom.FRONT_TOWER_HEIGHT, ArenaRoom.FRONT_CROWN])
	return result

func _inside(vertex: Vector3, tower: Array) -> bool:
	return vertex.x > tower[0] and vertex.x < tower[1] and vertex.z > tower[2] and vertex.z < tower[3]

func test_every_tower_ends_in_a_cupola_that_reaches_its_height_limit() -> void:
	var materials: Array[Material] = [room.hull, room._brass, room._frame, room._lamp, room._enamel]
	for tower in _towers():
		var heights := {}
		var highest := -INF
		for material in materials:
			for vertex in _vertices_of(material):
				if _inside(vertex, tower) and vertex.y > tower[4] - tower[5]:
					heights[snappedf(vertex.y, 0.01)] = true
					highest = maxf(highest, vertex.y)
		assert_lte(highest, tower[4] + 0.01, "the cupola stays inside the tower's height limit")
		assert_gte(highest, tower[4] - 0.03, "and the finial reaches it, so the limit is used")
		assert_gte(heights.size(), 10, "many distinct heights over the lid, not a flat rectangle")

func test_tower_lids_still_cover_the_end_of_the_side_wall() -> void:
	for tower in _towers():
		var covered := -INF
		for vertex in _vertices_of(room._brass):
			if _inside(vertex, tower):
				covered = maxf(covered, vertex.y)
		assert_gt(covered, ArenaRoom.SIDE_HEIGHT + 0.05, "the brass cornice rises above the side coping it hides")

func test_cupolas_are_lit_by_the_alert_lamp_material() -> void:
	# The beacon and the drum slits use the unlit lamp material, so an alert tints them with the rest of the room's lamps.
	var lit := 0
	for tower in _towers():
		for vertex in _vertices_of(room._lamp):
			if _inside(vertex, tower) and vertex.y > tower[4] - tower[5]:
				lit += 1
	assert_gt(lit, 4 * 30, "every tower carries lit slits and a bead above its lid")

func test_glow_cone_fades_from_its_apex_and_has_no_hard_edge() -> void:
	var kit := RoomMeshKit.new()
	kit.glow_cone(Vector3(0, 2, 0), Vector3.DOWN, Vector3.RIGHT, 1.0, 0.1, 0.5, 0.8)
	var parent: Node3D = autofree(Node3D.new())
	kit.flush(parent, 1, StandardMaterial3D.new())
	var glow := parent.get_node("Glow").get_child(0) as MeshInstance3D
	var arrays := (glow.mesh as ArrayMesh).surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert_eq(vertices.size(), 6 * 4 * 6, "six rows of four quads")
	var apex := 0.0
	var far_end := 0.0
	var edge := 0.0
	var on_axis: Dictionary = {} # depth -> alpha down the middle
	for index in vertices.size():
		var depth := 2.0 - vertices[index].y
		assert_eq(uvs[index], Vector2(0.5, 0.5), "every vertex samples the middle of the glow texture")
		assert_lte(colors[index].a, 0.8001)
		assert_eq(colors[index].r, 1.0)
		if absf(vertices[index].x) < 0.0001:
			on_axis[snappedf(depth, 0.001)] = colors[index].a
		if depth < 0.0001 and absf(vertices[index].x) < 0.0001:
			apex = colors[index].a
		if depth > 0.9999:
			far_end = maxf(far_end, colors[index].a)
		if absf(absf(vertices[index].x) - lerpf(0.1, 0.5, depth)) < 0.0001:
			edge = maxf(edge, colors[index].a)
	assert_almost_eq(apex, 0.8, 0.0001, "brightest at the top, on the axis")
	assert_almost_eq(far_end, 0.0, 0.0001, "nothing at the far end")
	assert_almost_eq(edge, 0.0, 0.0001, "nothing at the edges")
	var previous := INF
	var depths: Array = on_axis.keys()
	depths.sort()
	for depth: float in depths:
		assert_lte(on_axis[depth], previous + 0.0001, "never brighter further from the lamp")
		previous = on_axis[depth]

func test_a_cone_with_no_light_adds_nothing() -> void:
	var kit := RoomMeshKit.new()
	kit.glow_cone(Vector3.ZERO, Vector3.DOWN, Vector3.RIGHT, 1.0, 0.1, 0.5, 0.0)
	kit.glow_cone(Vector3.ZERO, Vector3.DOWN, Vector3.RIGHT, 0.0, 0.1, 0.5, 0.5)
	var parent: Node3D = autofree(Node3D.new())
	kit.flush(parent, 1, StandardMaterial3D.new())
	assert_null(parent.get_node_or_null("Glow"))

func _glow_arrays() -> Array:
	var glow := room.get_node("Glow").get_child(0) as MeshInstance3D
	return (glow.mesh as ArrayMesh).surface_get_arrays(0)

func test_slope_lamps_throw_cones_not_round_pools() -> void:
	var arrays := _glow_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var cone_vertices := 0
	for index in vertices.size():
		var vertex := vertices[index]
		if uvs[index] == Vector2(0.5, 0.5):
			cone_vertices += 1
			continue
		var on_slope := absf(vertex.x) > inner.x + 0.3 and absf(vertex.x) < inner.x + 1.0 and vertex.y > 0.5 and vertex.y < 1.4 and absf(vertex.z) < inner.y - 0.5
		assert_false(on_slope, "no round pool is left on the side slopes: %s" % vertex)
	assert_gt(cone_vertices, 144 * 16, "a cone under every side lamp post (5 per wall) and down every back pillar (9)")

func test_every_back_bay_has_an_enamel_inset_on_the_sill() -> void:
	var enamel := _vertices_of(room._enamel)
	var count := maxi(2, roundi(inner.x * 2.0 / ArenaRoom.PILLAR_PITCH))
	var pitch := inner.x * 2.0 / count
	for index in count:
		var bay_x := -inner.x + (index + 0.5) * pitch
		var found := 0
		for vertex in enamel:
			if absf(vertex.x - bay_x) < pitch * 0.4 and vertex.y > 0.4 and vertex.y < 0.6 and vertex.z < -inner.y - 0.1 and vertex.z > -inner.y - 0.45:
				found += 1
		assert_gt(found, 8, "bay %d has a panel leaning with the sill" % index)

func test_every_side_bay_has_an_enamel_inset_on_the_coping() -> void:
	var enamel := _vertices_of(room._enamel)
	var count := maxi(2, roundi(inner.y * 2.0 / ArenaRoom.PILLAR_PITCH))
	var pitch := inner.y * 2.0 / count
	for side: float in [-1.0, 1.0]:
		for index in count:
			var bay_z := -inner.y + (index + 0.5) * pitch
			var found := 0
			for vertex in enamel:
				if vertex.x * side > inner.x + 1.02 and vertex.x * side < inner.x + 1.2 and vertex.y > 1.6 and vertex.y < 1.63 and absf(vertex.z - bay_z) < pitch * 0.4:
					found += 1
			assert_gt(found, 4, "side %d bay %d has an inset on the coping" % [side, index])

func test_cables_sag_across_every_back_bay() -> void:
	var paint := _vertices_of(room._paint)
	var count := maxi(2, roundi(inner.x * 2.0 / ArenaRoom.PILLAR_PITCH))
	var pitch := inner.x * 2.0 / count
	for index in count:
		var bay_x := -inner.x + (index + 0.5) * pitch
		var found := 0
		var lowest := INF
		var highest := -INF
		for vertex in paint:
			if absf(vertex.x - bay_x) < pitch * 0.4 and vertex.y > 2.1 and vertex.y < 2.45 and vertex.z > -inner.y and vertex.z < -inner.y + 0.1:
				found += 1
				lowest = minf(lowest, vertex.y)
				highest = maxf(highest, vertex.y)
		assert_gt(found, 60, "two cables in bay %d" % index)
		assert_gt(highest - lowest, 0.08, "they sag between the pillars")

func test_the_bulkhead_door_has_a_handwheel_and_frame() -> void:
	var count := maxi(2, roundi(inner.x * 2.0 / ArenaRoom.PILLAR_PITCH))
	var pitch := inner.x * 2.0 / count
	var bay_x := -inner.x + (count / 2 + 0.5) * pitch
	var span := pitch - ArenaRoom.PILLAR_WIDTH - 0.02
	var wheel := 0
	var jamb := 0
	for vertex in _vertices_of(room._brass):
		if absf(vertex.x - (bay_x - span * 0.16)) < 0.25 and vertex.y > 1.28 and vertex.y < 1.72 and vertex.z > -inner.y - 0.38 and vertex.z < -inner.y - 0.25:
			wheel += 1
		if absf(vertex.x - (bay_x + span * 0.5 - 0.05)) < 0.06 and vertex.y > ArenaRoom.SILL_HEIGHT - 0.001 and vertex.y < ArenaRoom.LINTEL_BOTTOM - 0.2 and vertex.z < -inner.y - 0.28 and vertex.z > -inner.y - 0.36:
			jamb += 1
	assert_gt(wheel, 100, "a spoked handwheel on the door")
	assert_gt(jamb, 6, "a brass jamb at the side of the door")

func test_pillar_capitals_do_not_all_match() -> void:
	# Volutes (cylinders on the capital's ends), an enamel diamond or three teeth, repeating every third pillar.
	var brass := _vertices_of(room._brass)
	var count := maxi(2, roundi(inner.x * 2.0 / ArenaRoom.PILLAR_PITCH))
	var pitch := inner.x * 2.0 / count
	var signatures := {}
	for index in count + 1:
		var pillar_x := -inner.x + index * pitch
		var in_front := 0
		for vertex in brass:
			if absf(vertex.x - pillar_x) < 0.5 and vertex.y > ArenaRoom.LINTEL_BOTTOM - 0.45 and vertex.y < ArenaRoom.LINTEL_BOTTOM - 0.05 and vertex.z > -inner.y + 0.065:
				in_front += 1
		signatures[in_front] = true
	assert_gte(signatures.size(), 2, "pillars carry different capital detail")

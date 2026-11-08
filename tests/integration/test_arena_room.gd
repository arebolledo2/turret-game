extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	FeatureFlagService.set_enabled(FeatureFlagService.TERRAIN_ZONES, true)
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child_autofree(world)


func test_every_space_theme_has_display_data_and_shader_params() -> void:
	assert_eq(SpaceThemes.ORDER.size(), SpaceThemes.INFO.size())
	for id in SpaceThemes.ORDER:
		assert_true(SpaceThemes.is_theme(id), id)
		assert_ne(SpaceThemes.display_name(id), "", id)
		assert_ne(SpaceThemes.note(id), "", id)
		var params := SpaceThemes.shader_params(id)
		assert_true(params.has("drift"), id)
		assert_gt((params["drift"] as Vector2).length(), 0.0, id)

func test_every_layout_names_a_known_space_theme() -> void:
	for layout_id in ArenaLayouts.ids():
		assert_true(SpaceThemes.is_theme(ArenaLayouts.get_layout(layout_id).space_theme), layout_id)

func test_shader_params_name_real_shader_uniforms() -> void:
	var uniforms: Array[String] = []
	for entry in SpaceBackdrop.SHADER.get_shader_uniform_list():
		uniforms.append(str(entry["name"]))
	for id in SpaceThemes.ORDER:
		for key: String in SpaceThemes.shader_params(id):
			assert_has(uniforms, key, "%s sets unknown uniform %s" % [id, key])

func test_unknown_space_theme_falls_back_to_default() -> void:
	var backdrop := SpaceBackdrop.new()
	add_child_autofree(backdrop)
	backdrop.apply_theme("nope")
	assert_eq(backdrop.theme, SpaceThemes.DEFAULT_THEME)
	assert_not_null(backdrop.material_override)

func test_switching_space_theme_does_not_keep_the_previous_themes_settings() -> void:
	var backdrop := SpaceBackdrop.new()
	add_child_autofree(backdrop)
	backdrop.apply_theme("asteroid_belt")
	var belt := backdrop.material_override as ShaderMaterial
	assert_gt(float(belt.get_shader_parameter("debris_density")), 0.0)
	backdrop.apply_theme("warp")
	var warp := backdrop.material_override as ShaderMaterial
	assert_null(warp.get_shader_parameter("debris_density"), "A fresh material falls back to the shader default")

func test_run_applies_the_layouts_space_theme_unless_the_config_overrides_it() -> void:
	world.run_config.layout_id = "hive"
	world.start_run()
	assert_eq(world.stage.backdrop.theme, "warp")
	world.run_config.space_theme = "gas_giant"
	world.start_run()
	assert_eq(world.stage.backdrop.theme, "gas_giant")

func test_zoneless_run_still_gets_a_space_theme() -> void:
	FeatureFlagService.set_enabled(FeatureFlagService.TERRAIN_ZONES, false)
	world.run_config.layout_id = "highlands"
	world.start_run()
	assert_eq(world.stage.backdrop.theme, "asteroid_belt")

func test_run_config_parses_and_sanitizes_the_space_theme() -> void:
	assert_eq(RunConfig.from_args(PackedStringArray(["--space=NEBULA"])).space_theme, "nebula")
	assert_eq(RunConfig.from_args(PackedStringArray(["--space=bogus"])).space_theme, "")

## Every vertex of every room mesh, in world space, with the mesh it came from.
## The room's own meshes plus the ship exterior's.
func _room_meshes() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	var room: Node = world.stage.room
	for child in room.get_children():
		if child is MeshInstance3D:
			result.append(child)
	var exterior := room.get_node_or_null("Exterior")
	if exterior:
		for child in exterior.get_children():
			if child is MeshInstance3D:
				result.append(child)
	return result

func _room_vertices() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for mesh in _room_meshes():
		if not mesh.mesh is ArrayMesh:
			continue
		for vertex: Vector3 in (mesh.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			result.append(mesh.global_transform * vertex)
	return result

func test_walls_stand_outside_the_playfield_and_the_floor_stops_at_them() -> void:
	world.start_run()
	var half := WorldGeometry.HALF_ARENA
	var floor_plane := world.stage.floor_visual.mesh as PlaneMesh
	assert_almost_eq(floor_plane.size.x, half.x * 2.0 + .6, .001, "The floor no longer runs on past the walls")
	var vertices := _room_vertices()
	assert_gt(vertices.size(), 1000)
	var trespassers := 0
	var first := Vector3.ZERO
	for vertex in vertices:
		if absf(vertex.x) < half.x and absf(vertex.z) < half.y and vertex.y > -0.5:
			if trespassers == 0:
				first = vertex
			trespassers += 1
	assert_eq(trespassers, 0, "%d vertices are inside the playfield, first at %s" % [trespassers, first])

func test_room_is_merged_into_a_handful_of_meshes() -> void:
	world.start_run()
	var meshes := 0
	for child in world.stage.room.get_children():
		if child is MeshInstance3D:
			meshes += 1
			assert_eq((child as MeshInstance3D).layers & ArenaRoom.LAYER, ArenaRoom.LAYER, "lit by the room fill light")
	assert_between(meshes, 3, 10)

func test_front_wall_never_rises_above_the_parapet() -> void:
	world.start_run()
	var inner_x := WorldGeometry.HALF_ARENA.x + ArenaRoom.GAP
	var highest := -INF
	for vertex in _room_vertices():
		if vertex.z > WorldGeometry.HALF_ARENA.y and absf(vertex.x) < inner_x - 0.1: # clear of the towers and their cornices
			highest = maxf(highest, vertex.y)
	assert_lte(highest, ArenaRoom.FRONT_HEIGHT + 0.01, "A taller front wall would hide the floor behind it")

func test_corner_towers_stay_under_their_height_limits() -> void:
	world.start_run()
	var inner := WorldGeometry.HALF_ARENA + Vector2.ONE * ArenaRoom.GAP
	var back := -INF
	for vertex in _room_vertices():
		if absf(vertex.x) > inner.x + 0.01 and vertex.z < -inner.y:
			back = maxf(back, vertex.y)
	assert_lte(back, ArenaRoom.BACK_TOWER_HEIGHT + 0.01)
	assert_gt(ArenaRoom.BACK_HEIGHT, ArenaRoom.SIDE_HEIGHT)
	assert_gt(ArenaRoom.SIDE_HEIGHT, ArenaRoom.FRONT_HEIGHT)

func test_camera_margins_show_each_wall_in_full() -> void:
	# A point at height h appears 0.765 h further up the screen than its foot.
	var back := ArenaRoom.GAP + ArenaRoom.BACK_HEIGHT * 0.765 + ArenaRoom.BACK_TOP_DEPTH + ArenaRoom.HUD_TOP_ALLOWANCE
	assert_gte(GameConstants.CAMERA_EDGE_MARGIN_BACK, back, "The view reaches past the back coping and the HUD bar")
	assert_gte(GameConstants.CAMERA_EDGE_MARGIN, ArenaRoom.GAP + ArenaRoom.SIDE_DEPTH + 0.25, "The side walls' sloped faces and coping fit")

func test_room_glows_stay_below_the_bloom_threshold() -> void:
	world.start_run()
	assert_lt(ArenaRoom.LAMP_ENERGY, 1.0)
	assert_lt(world.stage._rim_material.emission_energy_multiplier, 1.0)

func test_only_four_shadowless_lantern_lights() -> void:
	world.start_run()
	var lights := world.stage.room.lantern_lights()
	assert_eq(lights.size(), 4)
	for light in lights:
		assert_false(light.shadow_enabled)

func test_room_hull_follows_the_floor_theme() -> void:
	world.run_config.layout_id = "sump"
	world.start_run()
	var hull := world.stage.room.hull
	assert_eq(hull.get_shader_parameter("base_color"), WorldGeometry.hull_color("grating"))
	world.run_config.layout_id = "hive"
	world.start_run()
	assert_eq(hull.get_shader_parameter("motif"), 1, "Hexworks plating is hex cells")
	for theme in WorldGeometry.FLOOR_THEMES:
		assert_true(WorldGeometry.HULL_COLORS.has(theme), theme)
		assert_true(WorldGeometry.HULL_MOTIFS.has(theme), theme)
	for theme in WorldGeometry.HULL_MOTIFS:
		assert_has(WorldGeometry.FLOOR_THEMES, theme)

func test_hull_and_brass_parameters_name_real_shader_uniforms() -> void:
	world.start_run()
	for material: ShaderMaterial in [world.stage.room.hull, world.stage.room._brass]:
		var uniforms: Array[String] = []
		for entry in material.shader.get_shader_uniform_list():
			uniforms.append(str(entry["name"]))
		for key in ["base_color", "motif", "panel_size", "metal"] if material == world.stage.room.hull else ["inner_half"]:
			assert_has(uniforms, key)

func test_extruded_wall_faces_point_the_way_the_profile_says() -> void:
	world.start_run()
	var found := 0
	for child in world.stage.room.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or not mesh.mesh is ArrayMesh:
			continue
		var arrays := (mesh.mesh as ArrayMesh).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if normals.is_empty():
			continue
		for index in range(0, vertices.size(), 3):
			var geometric := (vertices[index + 2] - vertices[index]).cross(vertices[index + 1] - vertices[index])
			if geometric.length() < 0.000001:
				continue
			var shading := normals[index] + normals[index + 1] + normals[index + 2]
			assert_gt(geometric.dot(shading), 0.0, "winding matches the stored normals")
			found += 1
	assert_gt(found, 1000)

func test_front_hull_uses_a_variety_of_modules() -> void:
	world.start_run()
	var kinds := {}
	for kind in world.stage.room.front_module_kinds:
		kinds[kind] = true
	assert_gte(kinds.size(), 3)

func test_exterior_exists_and_casts_no_shadows() -> void:
	world.start_run()
	var exterior := world.stage.room.get_node_or_null("Exterior")
	assert_not_null(exterior)
	var meshes := 0
	for child in exterior.get_children():
		if child is MeshInstance3D:
			meshes += 1
			assert_eq((child as MeshInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_gt(meshes, 2)

func test_room_and_exterior_stay_within_the_draw_call_budget() -> void:
	world.start_run()
	assert_lte(_room_meshes().size(), 15)

func test_unlit_lamps_stay_below_the_bloom_threshold() -> void:
	world.start_run()
	assert_lt(ArenaRoom.LAMP_VALUE, 0.9)
	var lamp: StandardMaterial3D = world.stage.room._lamp
	assert_lt(maxf(lamp.albedo_color.r, maxf(lamp.albedo_color.g, lamp.albedo_color.b)), 0.9)

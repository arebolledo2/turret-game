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

func test_walls_stand_outside_the_playfield_and_the_floor_stops_at_them() -> void:
	world.start_run()
	var half := WorldGeometry.HALF_ARENA
	var floor_plane := world.stage.floor_visual.mesh as PlaneMesh
	assert_almost_eq(floor_plane.size.x, half.x * 2.0 + .6, .001, "The floor no longer runs on past the walls")
	var inside := AABB(Vector3(-half.x, 0.0, -half.y), Vector3(half.x * 2.0, 3.0, half.y * 2.0))
	var meshes := 0
	for child in world.stage.room.get_children():
		var mesh := child as MeshInstance3D
		meshes += 1
		assert_false((mesh.transform * mesh.get_aabb()).intersects(inside), "%s intrudes on the playfield" % mesh.name)
	assert_gt(meshes, 20)

func test_front_wall_is_low_enough_not_to_hide_the_floor_behind_it() -> void:
	# The camera sees down at about 52 degrees, so a wall of height h hides about 0.77 h of the floor behind it.
	assert_lt(ArenaRoom.FRONT_HEIGHT * 0.77, 0.5)
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

func test_room_hull_follows_the_floor_theme() -> void:
	world.run_config.layout_id = "sump"
	world.start_run()
	var hull: ShaderMaterial = null
	for child in world.stage.room.get_children():
		if (child as MeshInstance3D).material_override is ShaderMaterial:
			hull = (child as MeshInstance3D).material_override
			break
	assert_not_null(hull)
	assert_eq(hull.get_shader_parameter("base_color"), WorldGeometry.hull_color("grating"))
	for theme in WorldGeometry.FLOOR_THEMES:
		assert_true(WorldGeometry.HULL_COLORS.has(theme), theme)

func test_extruded_wall_faces_point_the_way_the_profile_says() -> void:
	world.start_run()
	var found := 0
	for child in world.stage.room.get_children():
		var mesh := child as MeshInstance3D
		if not mesh.mesh is ArrayMesh:
			continue
		var arrays := (mesh.mesh as ArrayMesh).surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for index in range(0, vertices.size(), 3):
			var geometric := (vertices[index + 2] - vertices[index]).cross(vertices[index + 1] - vertices[index])
			assert_gt(geometric.dot(normals[index]), 0.0, "winding matches the stored normal")
			found += 1
	assert_gt(found, 20)

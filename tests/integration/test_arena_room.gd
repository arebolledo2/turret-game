extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	FeatureFlagService.set_enabled(FeatureFlagService.TERRAIN_ZONES, true)
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child_autofree(world)

func _meshes_under(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is MeshInstance3D:
			result.append(child)
	return result

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
	for mesh in _meshes_under(world.stage.room):
		var box := (mesh.mesh as BoxMesh).size
		var bounds := AABB(mesh.position - box * 0.5, box)
		var inside := AABB(Vector3(-half.x, 0.0, -half.y), Vector3(half.x * 2.0, 3.0, half.y * 2.0))
		assert_false(bounds.intersects(inside), "%s intrudes on the playfield" % mesh.name)

func test_front_wall_is_low_enough_not_to_hide_the_floor_behind_it() -> void:
	# The camera sees down at about 52 degrees, so a wall of height h hides about 0.77 h of the floor behind it.
	assert_lt(ArenaRoom.FRONT_HEIGHT * 0.77, 0.5)
	assert_gt(ArenaRoom.BACK_HEIGHT, ArenaRoom.SIDE_HEIGHT)
	assert_gt(ArenaRoom.SIDE_HEIGHT, ArenaRoom.FRONT_HEIGHT)

func test_camera_can_see_the_whole_back_wall() -> void:
	# A point at height h on the back wall appears 0.765 h further up the screen than its foot.
	var shown := ArenaRoom.GAP + ArenaRoom.BACK_HEIGHT * 0.765
	assert_gte(GameConstants.CAMERA_EDGE_MARGIN_BACK, shown, "The view reaches past the top of the back wall")

func test_room_hull_follows_the_floor_theme() -> void:
	world.run_config.layout_id = "sump"
	world.start_run()
	var hull := world.stage.room._hull_meshes[0].material_override as StandardMaterial3D
	assert_eq(hull.albedo_texture, WorldGeometry._floor_texture("grating", "albedo"))

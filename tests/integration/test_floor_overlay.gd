extends GutTest

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	FeatureFlagService.set_enabled(FeatureFlagService.TERRAIN_ZONES, true)
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child_autofree(world)

## The floor's albedo lift and its overlay pass (assets/shaders/floor_overlay.gdshader). Headless runs cannot compile shaders, so the look
## is checked with tools/preview_floor_theme.tscn; this covers the wiring: the gain survives in the material, the overlay is the
## floor's next_pass with the arena's size, and every uniform the code sets exists in the shader.

func test_every_theme_has_a_gain_and_an_overlay_palette() -> void:
	for theme in WorldGeometry.FLOOR_THEMES:
		assert_true(WorldGeometry.FLOOR_ALBEDO_GAIN.has(theme), "%s gain" % theme)
		assert_gt(WorldGeometry.FLOOR_ALBEDO_GAIN[theme], 1.0, "%s gain lifts the floor" % theme)
		assert_true(WorldGeometry.FLOOR_OVERLAY.has(theme), "%s overlay palette" % theme)
		for key in ["tint_a", "tint_b"]:
			assert_true(WorldGeometry.FLOOR_OVERLAY[theme].has(key), "%s %s" % [theme, key])

func test_albedo_gain_above_one_survives_in_the_material() -> void:
	for theme in WorldGeometry.FLOOR_THEMES:
		var material := WorldGeometry.floor_material(Vector2(10, 10), theme)
		var linear := material.albedo_color.srgb_to_linear()
		assert_almost_eq(linear.r, WorldGeometry.FLOOR_ALBEDO_GAIN[theme], 0.001, "%s linear gain" % theme)
		assert_almost_eq(linear.g, linear.r, 0.0001, "%s is a grey gain" % theme)
		assert_gt(material.albedo_color.r, 1.0, "%s stored above 1" % theme)

func test_the_arena_floor_is_still_a_textured_standard_material_with_a_multiply_emission() -> void:
	var material := WorldGeometry.floor_material(WorldGeometry.HALF_ARENA * 2.0)
	assert_true(material is StandardMaterial3D)
	assert_not_null(material.albedo_texture)
	assert_eq(material.emission_operator, BaseMaterial3D.EMISSION_OP_MULTIPLY)

func test_overlay_is_the_floors_next_pass_and_draws_before_other_transparent_things() -> void:
	var material := WorldGeometry.floor_material(WorldGeometry.HALF_ARENA * 2.0, "marquetry")
	var overlay := material.next_pass as ShaderMaterial
	assert_not_null(overlay)
	assert_eq(overlay.shader.resource_path, "res://assets/shaders/floor_overlay.gdshader")
	assert_eq(overlay.get_shader_parameter("half_arena"), WorldGeometry.HALF_ARENA)
	assert_lt(overlay.render_priority, 0, "zone rings, glows and telegraphs must draw over the finish, not under it")
	assert_null(overlay.next_pass, "one extra pass only")

func test_overlay_colours_come_from_the_theme() -> void:
	for theme in WorldGeometry.FLOOR_THEMES:
		var overlay := WorldGeometry.floor_overlay_material(theme)
		assert_eq(overlay.get_shader_parameter("tint_a"), WorldGeometry.FLOOR_OVERLAY[theme]["tint_a"], theme)
		assert_eq(overlay.get_shader_parameter("tint_b"), WorldGeometry.FLOOR_OVERLAY[theme]["tint_b"], theme)
		assert_eq(overlay.get_shader_parameter("accent"), WorldGeometry.hull_motif(theme)["accent"], "%s paint is the trim accent" % theme)
		assert_eq(overlay.get_shader_parameter("rim_color"), ArenaStage.RIM_COLORS[theme], "%s spill is the rim light" % theme)

func test_every_uniform_the_code_sets_exists_in_the_shader() -> void:
	var declared := {}
	for uniform in WorldGeometry.FLOOR_OVERLAY_SHADER.get_shader_uniform_list():
		declared[uniform["name"]] = true
	for theme in WorldGeometry.FLOOR_THEMES:
		var overlay := WorldGeometry.floor_overlay_material(theme)
		for name in ["half_arena", "tint_a", "tint_b", "accent", "rim_color", "level"]:
			assert_true(declared.has(name), "shader declares %s" % name)
			assert_not_null(overlay.get_shader_parameter(name), "%s sets %s" % [theme, name])

func test_the_showcase_patch_gets_neither_the_gain_nor_the_overlay() -> void:
	var material := WorldGeometry.floor_material(Vector2(6, 6), "frost", false)
	assert_eq(material.albedo_color, Color.WHITE)
	assert_null(material.next_pass)
	assert_not_null(material.albedo_texture)

func test_the_stage_floor_carries_the_overlay_and_a_theme_swap_replaces_it() -> void:
	var stage := world.stage
	var material := stage.floor_visual.material_override as StandardMaterial3D
	assert_not_null(material.next_pass, "the stage floor carries the overlay")
	stage.set_floor_theme("hexworks")
	var swapped := stage.floor_visual.material_override as StandardMaterial3D
	assert_eq((swapped.next_pass as ShaderMaterial).get_shader_parameter("tint_a"), WorldGeometry.FLOOR_OVERLAY["hexworks"]["tint_a"])

func test_the_overlay_is_still_a_single_pass_and_the_wave_tint_reaches_the_floor_material() -> void:
	world.stage.set_floor_wave(3, false)
	var material := world.stage.floor_visual.material_override as StandardMaterial3D
	assert_not_null(material.next_pass)
	assert_null(material.next_pass.next_pass)
	assert_eq(material.emission_operator, BaseMaterial3D.EMISSION_OP_MULTIPLY)

func test_the_shader_blends_in_one_alpha_pass_that_leaves_other_transparent_things_alone() -> void:
	var code := WorldGeometry.FLOOR_OVERLAY_SHADER.code
	assert_string_contains(code, "unshaded")
	assert_string_contains(code, "blend_mix")
	assert_string_contains(code, "depth_draw_never")
	assert_string_contains(code, "fog_disabled", "the wall occlusion must stay black at the far edge")

func test_blotch_decals_are_strong_enough_to_read_on_the_lifted_floor() -> void:
	for theme in WorldGeometry.FLOOR_THEMES:
		var tints: Array = FloorDecals.TINTS[theme]
		assert_gte(tints[0].a, 0.7, "%s blotch alpha" % theme)
		assert_lt(tints[0].get_luminance(), 0.03, "%s blotch is darker than the lifted floor" % theme)

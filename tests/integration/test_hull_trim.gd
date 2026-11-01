extends GutTest

## The room's brass trim (`brass_trim.gdshader`) and hull plating (`hull_plating.gdshader`) and the per-theme tables that feed them.
## Headless runs cannot compile shaders, so these check uniform names, the tables and the numbers in the shader source;
## tools/preview_floor_theme.tscn (and preview_exterior.tscn for the decks) shows the look.

var world: ArenaWorld

func before_each() -> void:
	TestHelpers.reset_all_services()
	FeatureFlagService.set_enabled(FeatureFlagService.TERRAIN_ZONES, true)
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child_autofree(world)

func _uniforms(shader: Shader) -> Array[String]:
	var names: Array[String] = []
	for entry in shader.get_shader_uniform_list():
		names.append(str(entry["name"]))
	return names

func test_brass_shader_declares_its_uniforms() -> void:
	var uniforms := _uniforms(ArenaRoom.BRASS_SHADER)
	for key in ["brass_color", "patina_color", "patina_amount", "brush_depth", "inner_half"]:
		assert_has(uniforms, key, "brass_trim.gdshader declares %s" % key)

func test_hull_shader_declares_its_uniforms() -> void:
	var uniforms := _uniforms(ArenaRoom.HULL_SHADER)
	for key in ["base_color", "seam_color", "wear_color", "accent_color", "panel_size", "motif", "metal", "relief", "grime"]:
		assert_has(uniforms, key, "hull_plating.gdshader declares %s" % key)

func test_brass_is_a_real_metal_in_the_shader() -> void:
	# A metallic mix from about 0.9 (clean) to 0.7 (patina): the old 0.4 to 0.55 turned brass into a tan diffuse.
	var found := RegEx.create_from_string("METALLIC\\s*=\\s*mix\\(\\s*([0-9.]+)\\s*,\\s*([0-9.]+)").search(ArenaRoom.BRASS_SHADER.code)
	assert_not_null(found, "METALLIC is a mix of clean and patinated metal")
	if found:
		assert_gte(float(found.get_string(1)), 0.85)
		assert_gte(float(found.get_string(2)), 0.6)
		assert_lt(float(found.get_string(2)), float(found.get_string(1)), "patina is less metallic than clean brass")

func test_every_floor_theme_has_a_brass_style() -> void:
	for theme in WorldGeometry.FLOOR_THEMES:
		assert_true(WorldGeometry.BRASS_COLORS.has(theme), theme)
		var style := WorldGeometry.brass_style(theme)
		for key in ["color", "patina", "amount"]:
			assert_true(style.has(key), "%s has %s" % [theme, key])
		assert_gt(float(style["amount"]), 0.0, theme)
	for theme in WorldGeometry.BRASS_COLORS:
		assert_has(WorldGeometry.FLOOR_THEMES, theme)

func test_unknown_theme_falls_back_to_the_default_brass() -> void:
	assert_eq(WorldGeometry.brass_color("nope"), WorldGeometry.brass_color(WorldGeometry.DEFAULT_FLOOR_THEME))
	assert_eq(WorldGeometry.hull_color("nope"), WorldGeometry.hull_color(WorldGeometry.DEFAULT_FLOOR_THEME))

func test_brass_reflectance_is_bright_and_saturated_except_steel() -> void:
	# F0 is what the metal reflects of the studio sky, so a dark or grey one reads as khaki; frost's pewter is the one steel.
	var seen := {}
	for theme in WorldGeometry.FLOOR_THEMES:
		var colour := WorldGeometry.brass_color(theme)
		assert_gte(colour.v, 0.55, "%s brass is bright enough to reflect" % theme)
		assert_lte(colour.v, 0.95, "%s brass stays clear of white" % theme)
		if theme != "frost":
			assert_gte(colour.s, 0.3, "%s brass is saturated, not khaki" % theme)
		seen[colour] = true
	assert_eq(seen.size(), WorldGeometry.FLOOR_THEMES.size(), "every theme has its own trim metal")

func test_every_theme_has_its_own_hull_colour_and_accent() -> void:
	var hulls := {}
	var accents := {}
	for theme in WorldGeometry.FLOOR_THEMES:
		hulls[WorldGeometry.hull_color(theme)] = true
		accents[WorldGeometry.hull_motif(theme)["accent"]] = true
	assert_eq(hulls.size(), WorldGeometry.FLOOR_THEMES.size())
	assert_eq(accents.size(), WorldGeometry.FLOOR_THEMES.size())

func test_apply_theme_feeds_the_hull_and_brass_materials() -> void:
	world.start_run()
	var room := world.stage.room
	for theme in WorldGeometry.FLOOR_THEMES:
		room.apply_theme(theme, Color.WHITE)
		var style := WorldGeometry.brass_style(theme)
		assert_eq(room._brass.get_shader_parameter("brass_color"), style["color"], "%s brass colour" % theme)
		assert_eq(room._brass.get_shader_parameter("patina_color"), style["patina"], "%s patina" % theme)
		assert_almost_eq(float(room._brass.get_shader_parameter("patina_amount")), float(style["amount"]), 0.0001)
		assert_eq(room.hull.get_shader_parameter("accent_color"), WorldGeometry.hull_motif(theme)["accent"], "%s paint accent" % theme)
		assert_eq(room.hull.get_shader_parameter("base_color"), WorldGeometry.hull_color(theme), "%s hull colour" % theme)

func test_hull_deck_and_paint_rules_are_in_the_shader() -> void:
	# Decks (up-facing, below the floor) get larger panels and weld lines, a few panels are painted, and the edge wear is bare steel.
	var code := ArenaRoom.HULL_SHADER.code
	assert_string_contains(code, "bool deck = geometric.y > 0.7 && world_position.y < -0.5")
	assert_string_contains(code, "deck_scale()")
	assert_string_contains(code, "weld_distance")
	assert_string_contains(code, "step(0.88, hash21(id + 3.3))")
	assert_string_contains(code, "accent_color")
	assert_string_contains(code, "step(0.72, value_noise(plane * 9.0))")

func test_hex_cells_are_larger_on_decks_than_on_walls() -> void:
	# 0.45 m cells read as chicken wire from above on a 4.2 m deck; the deck scale for hex cells must be well above 1.
	var found := RegEx.create_from_string("if \\(motif == 1\\) \\{\\s*return\\s+([0-9.]+);").search(ArenaRoom.HULL_SHADER.code)
	assert_not_null(found, "deck_scale() has a hex branch")
	if found:
		var cell: float = float(WorldGeometry.hull_motif("hexworks")["panel"].x) * float(found.get_string(1))
		assert_gte(cell, 0.9, "deck hex cells are at least about a metre wide")
		assert_lte(cell, 1.6, "but not so big that a deck holds only a couple")

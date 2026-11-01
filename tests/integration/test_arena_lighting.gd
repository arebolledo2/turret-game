extends GutTest

## The arena's light rig: flat cool ambient, softer sun shadows, the studio sky, the colour grade and the edge vignette.
## Headless runs cannot compile shaders, so these check the settings and uniform names; tools/preview_floor_theme.tscn shows the look.

var world: ArenaWorld
var stage: ArenaStage

func before_each() -> void:
	TestHelpers.reset_all_services()
	FeatureFlagService.set_enabled(FeatureFlagService.TERRAIN_ZONES, true)
	world = ArenaWorld.new()
	world.auto_start = false
	world.show_hud = false
	add_child_autofree(world)
	stage = world.stage

func _uniforms(shader: Shader) -> Array[String]:
	var names: Array[String] = []
	for entry in shader.get_shader_uniform_list():
		names.append(str(entry["name"]))
	return names

## The numeric default of `uniform float <name> = <value>;` read from the shader source.
func _default(shader: Shader, uniform_name: String) -> float:
	var pattern := RegEx.create_from_string("uniform\\s+float\\s+%s\\s*(?::[^=]*)?=\\s*([0-9.]+)" % uniform_name)
	var found := pattern.search(shader.code)
	assert_not_null(found, "%s has a numeric default" % uniform_name)
	return float(found.get_string(1)) if found else NAN

func test_ambient_is_a_flat_cool_colour_with_a_little_sky() -> void:
	var settings := stage.world_environment.environment
	assert_eq(settings.ambient_light_source, Environment.AMBIENT_SOURCE_COLOR)
	assert_eq(settings.ambient_light_color, ArenaStage.AMBIENT_COLOR)
	assert_almost_eq(settings.ambient_light_energy, ArenaStage.AMBIENT_ENERGY, 0.001)
	assert_gt(settings.ambient_light_energy, 0.45, "stronger than the sky-only ambient it replaced")
	assert_lt(settings.ambient_light_sky_contribution, 0.5)
	assert_gt(settings.ambient_light_color.b, settings.ambient_light_color.r, "cool: more blue than red")
	assert_eq(settings.reflected_light_source, Environment.REFLECTION_SOURCE_SKY, "metal still reflects the studio sky")

func test_sun_shadows_are_softer_and_the_bloom_threshold_is_unchanged() -> void:
	assert_almost_eq(stage.sun.shadow_opacity, ArenaStage.SUN_SHADOW_OPACITY, 0.001)
	assert_lt(stage.sun.shadow_opacity, 0.9)
	assert_true(stage.sun.shadow_enabled)
	var settings := stage.world_environment.environment
	assert_true(settings.glow_enabled)
	assert_almost_eq(settings.glow_hdr_threshold, 1.0, 0.001, "nothing but deliberate hero lights blooms")

func test_colour_grade_adds_contrast_saturation_and_a_split_tone_lookup() -> void:
	var settings := stage.world_environment.environment
	assert_true(settings.adjustment_enabled)
	assert_almost_eq(settings.adjustment_contrast, ArenaStage.GRADE_CONTRAST, 0.001)
	assert_gt(settings.adjustment_contrast, 1.0)
	assert_gt(settings.adjustment_saturation, 1.0)
	var lookup := settings.adjustment_color_correction as GradientTexture1D
	assert_not_null(lookup)
	var gradient := lookup.gradient
	assert_eq(gradient.get_point_count(), ArenaStage.GRADE_STOPS.size())
	var dark := gradient.get_color(0)
	var bright := gradient.get_color(gradient.get_point_count() - 1)
	assert_lt(dark.get_luminance(), 0.1, "blacks stay near black")
	assert_gt(bright.get_luminance(), 0.9, "whites stay near white")
	assert_gt(dark.b, dark.r, "shadows lean cool")
	assert_gt(bright.r, bright.b, "highlights lean warm")
	var previous := -1.0
	for index in range(gradient.get_point_count()):
		var luminance := gradient.get_color(index).get_luminance()
		assert_gt(luminance, previous, "the lookup never darkens as the input brightens")
		previous = luminance

func test_sky_shader_declares_the_studio_uniforms() -> void:
	var uniforms := _uniforms(ArenaStage.SKY_SHADER)
	for key in ["top_color", "horizon_color", "bottom_color", "energy", "soft_dir", "soft_color", "soft_width", "soft_energy", "fill_dir", "fill_width", "fill_energy", "bounce_color", "bounce_level"]:
		assert_has(uniforms, key, "arena_sky.gdshader declares %s" % key)

func test_sky_light_stays_below_the_bloom_threshold() -> void:
	# The softbox and the bounce are reflected by metal, which can only dim them, so their own radiance bounds the highlights.
	assert_lte(_default(ArenaStage.SKY_SHADER, "soft_energy"), 0.9)
	assert_lt(_default(ArenaStage.SKY_SHADER, "fill_energy"), _default(ArenaStage.SKY_SHADER, "soft_energy"), "the fill is the secondary light")
	assert_lte(_default(ArenaStage.SKY_SHADER, "bounce_level"), 0.25)

func test_sky_bounce_follows_the_floor_theme_rim_colour() -> void:
	var seen := {}
	for theme: String in ArenaStage.RIM_COLORS:
		stage.set_floor_theme(theme)
		var bounce: Color = stage.sky_material.get_shader_parameter("bounce_color")
		assert_eq(bounce, ArenaStage.RIM_COLORS[theme], theme)
		seen[bounce] = true
	assert_eq(seen.size(), ArenaStage.RIM_COLORS.size(), "every theme bounces its own colour")

func test_every_floor_theme_has_a_rim_colour_for_the_bounce() -> void:
	for theme in WorldGeometry.FLOOR_THEMES:
		assert_true(ArenaStage.RIM_COLORS.has(theme), theme)

func test_vignette_sits_between_the_playfield_picture_and_the_hud() -> void:
	var vignette := stage.vignette
	assert_not_null(vignette)
	assert_true(vignette.is_inside_tree())
	var hud: CanvasLayer = autofree(preload("res://scripts/game/game_hud.gd").new())
	# PlayfieldView (the 3D picture) is layer -1; a tie there would depend on tree order.
	assert_gt(vignette.layer, -1, "above the 3D picture")
	assert_lt(vignette.layer, hud.layer, "below the HUD")
	assert_eq(vignette.layer, ArenaVignette.DRAW_LAYER)

func test_vignette_covers_the_screen_and_never_takes_mouse_input() -> void:
	var overlay := stage.vignette.overlay
	assert_eq(overlay.get_parent(), stage.vignette)
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_eq(overlay.focus_mode, Control.FOCUS_NONE)
	assert_eq([overlay.anchor_left, overlay.anchor_top, overlay.anchor_right, overlay.anchor_bottom], [0.0, 0.0, 1.0, 1.0])
	assert_eq(overlay.material, stage.vignette.material)
	for node in stage.vignette.find_children("*", "Control", true, false):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, str(node.name))

func test_vignette_shader_declares_its_uniforms_and_stays_gentle() -> void:
	var uniforms := _uniforms(ArenaVignette.SHADER)
	for key in ["tint", "strength", "inner_radius", "outer_radius", "roundness"]:
		assert_has(uniforms, key)
	assert_lte(_default(ArenaVignette.SHADER, "strength"), 0.5, "a vignette, not a tunnel")
	assert_lt(_default(ArenaVignette.SHADER, "inner_radius"), _default(ArenaVignette.SHADER, "outer_radius"))

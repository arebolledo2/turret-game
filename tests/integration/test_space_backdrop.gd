extends GutTest

## The space backdrop's theme data against its shader. Headless runs cannot compile the shader, so defaults are read from
## the shader source itself.

## Optional features of space_backdrop.gdshader: each must be off (0) unless a theme turns it on.
const FEATURE_UNIFORMS: Array[String] = ["star_dust", "nebula_filaments", "dust_lanes", "band_amount", "galaxy_amount",
	"planet_radius", "planet_storm", "planet_ring", "moon_radius", "hull_shadow", "debris_density", "engine_amount", "streak"]

func _uniform_names() -> Array[String]:
	var names: Array[String] = []
	for entry in SpaceBackdrop.SHADER.get_shader_uniform_list():
		names.append(str(entry["name"]))
	return names

## Float uniform defaults as written in the shader source (`uniform float name = value;`).
func _float_defaults() -> Dictionary:
	var defaults := {}
	var pattern := RegEx.create_from_string("uniform\\s+float\\s+(\\w+)\\s*(?::[^=;]*)?=\\s*(-?[0-9.]+)\\s*;")
	for found in pattern.search_all(SpaceBackdrop.SHADER.code):
		defaults[found.get_string(1)] = float(found.get_string(2))
	return defaults

func test_every_theme_keeps_star_brightness_under_the_bloom_budget() -> void:
	for id in SpaceThemes.ORDER:
		var params := SpaceThemes.shader_params(id)
		assert_true(params.has("star_brightness"), "%s sets star_brightness" % id)
		assert_lte(float(params.get("star_brightness", 99.0)), 1.2, "%s: only hero stars may bloom" % id)
	assert_lte(float(_float_defaults().get("star_brightness", 99.0)), 1.2, "shader default star_brightness")

func test_every_theme_param_is_a_real_uniform() -> void:
	var uniforms := _uniform_names()
	assert_gt(uniforms.size(), 0, "The shader's uniforms are readable")
	for id in SpaceThemes.ORDER:
		for key: String in SpaceThemes.shader_params(id):
			assert_has(uniforms, key, "%s sets unknown uniform %s" % [id, key])

func test_feature_uniforms_exist_and_default_to_off() -> void:
	var uniforms := _uniform_names()
	var defaults := _float_defaults()
	for key in FEATURE_UNIFORMS:
		assert_has(uniforms, key)
		assert_true(defaults.has(key), "%s has a default in the shader source" % key)
		assert_eq(float(defaults.get(key, -1.0)), 0.0, "%s is off by default" % key)

func test_each_new_feature_is_used_by_some_theme() -> void:
	for key in ["star_dust", "nebula_filaments", "dust_lanes", "band_amount", "galaxy_amount", "planet_storm",
			"planet_ring", "moon_radius", "hull_shadow"]:
		var used := false
		for id in SpaceThemes.ORDER:
			used = used or float(SpaceThemes.shader_params(id).get(key, 0.0)) > 0.0
		assert_true(used, "%s is shown by at least one theme" % key)

func test_applying_a_theme_twice_does_not_leak_settings() -> void:
	var backdrop := SpaceBackdrop.new()
	add_child_autofree(backdrop)
	backdrop.apply_theme("gas_giant")
	backdrop.apply_theme("warp")
	backdrop.apply_theme("warp")
	var material := backdrop.material_override as ShaderMaterial
	assert_eq(backdrop.theme, "warp")
	for key in ["planet_radius", "planet_ring", "moon_radius", "band_amount", "galaxy_amount", "star_dust"]:
		assert_null(material.get_shader_parameter(key), "%s falls back to the shader default after gas_giant" % key)
	assert_eq(material.get_shader_parameter("streak"), 1.0)
	backdrop.apply_theme("deep_space")
	material = backdrop.material_override as ShaderMaterial
	assert_null(material.get_shader_parameter("streak"), "warp's streak does not linger")
	assert_null(material.get_shader_parameter("engine_amount"))
	assert_eq(material.get_shader_parameter("band_amount"), 1.0)

func test_gas_giant_planet_fits_the_view() -> void:
	var params := SpaceThemes.shader_params("gas_giant")
	assert_almost_eq(float(params["planet_radius"]), 11.0, 1.5, "about 11 m: a limb, not a wash over the whole view")
	assert_almost_eq(float(params["planet_tilt"]), 20.0, 0.01)

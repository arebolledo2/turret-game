class_name SpaceThemes
extends RefCounted

## What the ship is flying through outside the arena room: display data plus the `space_backdrop.gdshader` settings.
## `heading` is the direction of travel in degrees (0 = up the screen, 90 = to the right); `speed` is metres per second
## on the nearest layer. A layout names its theme (`ArenaLayouts`), and a run can override it (`RunConfig.space_theme`).
## Stars are sized in screen pixels; keep `star_brightness` near 1 so only the rare hero stars bloom.
const DEFAULT_THEME: String = "deep_space"
const ORDER: Array[String] = ["deep_space", "nebula", "asteroid_belt", "gas_giant", "warp"]

const INFO := {
	"deep_space": {"name": "Deep Space", "note": "Open black with a quiet scatter of stars, drifting past at cruising speed.",
		"heading": 0.0, "speed": 1.2, "params": {
			"base_color": Color("010205"), "nebula_a": Color("0d2640"), "nebula_b": Color("1a1038"),
			"nebula_core": Color("3a3a6a"), "nebula_amount": 0.22,
			"star_density": 0.55, "star_brightness": 1.1, "star_tint": Color("d6e8ff"), "star_dust": 0.8,
			"band_amount": 1.0, "band_angle": 28.0, "galaxy_amount": 0.35, "hull_shadow": 0.35,
		}},
	"nebula": {"name": "Violet Nebula", "note": "Thick plum and teal gas clouds lit from inside, with sparse stars shining through.",
		"heading": 20.0, "speed": 1.6, "params": {
			"base_color": Color("04020a"), "nebula_a": Color("5a1c7a"), "nebula_b": Color("0f6a78"),
			"nebula_core": Color("a868c8"), "nebula_amount": 0.8, "nebula_scale": 0.028, "nebula_filaments": 0.6,
			"dust_lanes": 1.0, "star_density": 0.35, "star_brightness": 1.0, "star_tint": Color("f0dcff"), "star_dust": 0.4,
			"hull_shadow": 0.35,
		}},
	"asteroid_belt": {"name": "Asteroid Belt", "note": "A dusty amber haze and dark rocks sliding past the hull.",
		"heading": -35.0, "speed": 3.0, "params": {
			"base_color": Color("060403"), "nebula_a": Color("5a3012"), "nebula_b": Color("30180c"),
			"nebula_core": Color("8a5a30"), "nebula_amount": 0.4, "dust_lanes": 0.6,
			"star_density": 0.4, "star_brightness": 1.0, "star_tint": Color("ffe8cc"), "star_dust": 0.6,
			"debris_density": 0.5, "debris_color": Color("6b574a"), "hull_shadow": 0.3,
		}},
	"gas_giant": {"name": "Gas Giant", "note": "A banded orange planet hangs on the horizon while the ship slowly rounds it.",
		"heading": 90.0, "speed": 0.8, "params": {
			"base_color": Color("010308"), "nebula_a": Color("102a48"), "nebula_b": Color("2a1038"),
			"nebula_core": Color("2a3a60"), "nebula_amount": 0.2,
			"star_density": 0.5, "star_brightness": 1.1, "star_dust": 0.5, "galaxy_amount": 0.25,
			"planet_radius": 11.0, "planet_position": Vector2(-4.5, -35.4), "planet_tilt": 20.0,
			"planet_color": Color("c0672c"), "planet_light": Color("f2d3a0"), "planet_dark": Color("6b3a20"),
			"planet_glow": Color("ffa060"), "planet_storm": 1.0, "planet_ring": 0.7,
			"moon_radius": 0.35, "moon_position": Vector2(6.5, -40.7), "hull_shadow": 0.35,
		}},
	"warp": {"name": "Warp Corridor", "note": "Stars stretched into long cold streaks at hyper speed.",
		"heading": 25.0, "speed": 10.0, "params": {
			"base_color": Color("02030a"), "nebula_a": Color("14306a"), "nebula_b": Color("203a8a"),
			"nebula_core": Color("4060b0"), "nebula_amount": 0.35,
			"star_density": 0.45, "star_brightness": 1.2, "star_tint": Color("bcd4ff"), "streak": 1.0, "hull_density": 0.3,
			"engine_amount": 0.25,
		}},
}

static func is_theme(id: String) -> bool:
	return INFO.has(id)

static func display_name(id: String) -> String:
	return str(INFO.get(id, {}).get("name", id.capitalize()))

static func note(id: String) -> String:
	return str(INFO.get(id, {}).get("note", ""))

## Shader uniforms for a theme (unknown ids fall back to the default): the theme's params plus `drift`, from heading and speed.
static func shader_params(id: String) -> Dictionary:
	var info: Dictionary = INFO.get(id, INFO[DEFAULT_THEME])
	var params: Dictionary = (info["params"] as Dictionary).duplicate()
	var heading := deg_to_rad(float(info["heading"]))
	params["drift"] = Vector2(sin(heading), -cos(heading)) * float(info["speed"])
	return params

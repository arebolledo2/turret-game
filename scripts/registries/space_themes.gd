class_name SpaceThemes
extends RefCounted

## What the ship is flying through outside the arena room: display data plus the `space_backdrop.gdshader` settings.
## `heading` is the direction of travel in degrees (0 = up the screen, 90 = to the right); `speed` is metres per second
## on the nearest layer. A layout names its theme (`ArenaLayouts`), and a run can override it (`RunConfig.space_theme`).
const DEFAULT_THEME: String = "deep_space"
const ORDER: Array[String] = ["deep_space", "nebula", "asteroid_belt", "gas_giant", "warp"]

const INFO := {
	"deep_space": {"name": "Deep Space", "note": "Open black with a quiet scatter of stars, drifting past at cruising speed.",
		"heading": 0.0, "speed": 1.2, "params": {
			"base_color": Color("010205"), "nebula_a": Color("0d2640"), "nebula_b": Color("1a1038"), "nebula_amount": 0.22,
			"star_density": 0.55, "star_brightness": 2.4, "star_tint": Color("d6e8ff"),
		}},
	"nebula": {"name": "Violet Nebula", "note": "Thick plum and teal gas clouds lit from inside, with sparse stars shining through.",
		"heading": 20.0, "speed": 1.6, "params": {
			"base_color": Color("04020a"), "nebula_a": Color("5a1c7a"), "nebula_b": Color("0f6a78"), "nebula_amount": 0.8,
			"nebula_scale": 0.028, "star_density": 0.35, "star_brightness": 2.0, "star_tint": Color("f0dcff"),
		}},
	"asteroid_belt": {"name": "Asteroid Belt", "note": "A dusty amber haze and dark rocks sliding past the hull.",
		"heading": -35.0, "speed": 3.0, "params": {
			"base_color": Color("060403"), "nebula_a": Color("5a3012"), "nebula_b": Color("30180c"), "nebula_amount": 0.4,
			"star_density": 0.4, "star_brightness": 1.8, "star_tint": Color("ffe8cc"), "debris_density": 0.5,
			"debris_color": Color("6b574a"),
		}},
	"gas_giant": {"name": "Gas Giant", "note": "A banded orange planet hangs on the horizon while the ship slowly rounds it.",
		"heading": 90.0, "speed": 0.8, "params": {
			"base_color": Color("010308"), "nebula_a": Color("102a48"), "nebula_b": Color("2a1038"), "nebula_amount": 0.2,
			"star_density": 0.5, "star_brightness": 2.2, "planet_radius": 20.0, "planet_position": Vector2(-8.0, -44.0),
			"planet_color": Color("c0672c"), "planet_glow": Color("ffa060"),
		}},
	"warp": {"name": "Warp Corridor", "note": "Stars stretched into long cold streaks at hyper speed.",
		"heading": 0.0, "speed": 14.0, "params": {
			"base_color": Color("02030a"), "nebula_a": Color("14306a"), "nebula_b": Color("203a8a"), "nebula_amount": 0.35,
			"star_density": 0.75, "star_brightness": 3.0, "star_tint": Color("bcd4ff"), "streak": 9.0,
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

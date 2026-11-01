shader_type canvas_item;

// A soft blue-black darkening towards the screen edges, drawn over the 3D view and under the HUD (see ArenaVignette).
// It only ever writes alpha over a fixed tint, so it costs one full-screen blend and no screen-texture read.

uniform vec4 tint : source_color = vec4(0.012, 0.024, 0.06, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.4;
uniform float inner_radius = 0.55;
uniform float outer_radius = 1.05;
// 1.0 measures distance in screen-height units (a circle), 0.0 in screen fractions (an ellipse that touches all four edges alike).
uniform float roundness : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = (UV - 0.5) * vec2(mix(1.0, aspect, roundness), 1.0);
	float edge = smoothstep(inner_radius, outer_radius, length(p) * mix(1.41421356, 1.0, roundness));
	COLOR = vec4(tint.rgb, edge * strength);
}

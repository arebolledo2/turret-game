shader_type spatial;
render_mode cull_disabled;

// Polished, lightly brushed brass for the room's copings, caps and fittings: a real metal, not a tan diffuse. `brass_color` is
// the reflectance at normal incidence (a saturated F0, set per floor theme from WorldGeometry.BRASS_COLORS), so the studio sky
// (arena_sky.gdshader) shows up in it as a warm highlight that tracks the curvature of the coping. The brushing runs along the
// wall, which is told apart by position (anything outside `inner_half.x` is a side wall); it perturbs the normal a little, so
// flat tops streak instead of sitting at one tone. Patina collects on edges and low down, where the metal turns less metallic
// and shows `patina_color`; the rest stays clean.

uniform vec3 brass_color : source_color = vec3(0.784, 0.604, 0.235);
uniform vec3 patina_color : source_color = vec3(0.18, 0.36, 0.3);
/// How much patina the theme grows (0 none).
uniform float patina_amount = 1.0;
/// Height of the brushing in metres; the normal is tilted by roughly this times the noise gradient.
uniform float brush_depth = 0.009;
uniform vec2 inner_half = vec2(12.8, 9.0);

varying vec3 world_position;
varying vec3 world_normal;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Brush height at a world point: two octaves of noise stretched along the wall. `detail` fades the fine octave when a pixel
// covers too much of it.
float brush_height(vec3 p, float detail) {
	bool side = abs(p.x) > inner_half.x;
	vec2 stretch = side ? vec2(14.0, 1.6) : vec2(1.6, 14.0);
	float coarse = value_noise(p.xz * stretch + vec2(p.y * 5.0, 0.0));
	float fine = value_noise(p.xz * stretch * vec2(side ? 2.6 : 1.9, side ? 1.9 : 2.6) + vec2(p.y * 11.0, 3.1));
	return coarse * 0.65 + fine * 0.35 * detail;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 geometric = normalize(world_normal);
	// How curved the surface is under this pixel (1/m): rounded noses and chamfers score high, flat tops score nothing.
	float curvature = length(fwidth(geometric)) / max(length(fwidth(world_position)), 0.0001);
	float edge = smoothstep(8.0, 24.0, curvature);

	// Brushing: tilt the world normal by the gradient of the brush height, projected onto the surface.
	float footprint = length(fwidth(world_position));
	float detail = 1.0 - smoothstep(0.012, 0.03, footprint);
	float eps = 0.004;
	float h0 = brush_height(world_position, detail);
	vec3 gradient = vec3(brush_height(world_position + vec3(eps, 0.0, 0.0), detail) - h0,
		brush_height(world_position + vec3(0.0, eps, 0.0), detail) - h0,
		brush_height(world_position + vec3(0.0, 0.0, eps), detail) - h0) / eps;
	gradient -= geometric * dot(geometric, gradient);
	vec3 bumped = normalize(geometric - gradient * brush_depth);
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);

	float grain = value_noise(world_position.xz * 21.0 + world_position.y * 9.0);
	// Verdigris: blotchy, gathered on edges and low down (the kicks, plinths and everything on the exterior decks).
	float low = 1.0 - smoothstep(0.1, 0.9, world_position.y);
	// Noise on position plus a height skew, so sloped faces do not get diagonal bands; two scales make small spots and patches.
	vec2 spot = world_position.xz * 3.1 + vec2(world_position.y * 4.3, world_position.y * -2.1);
	float blotch = smoothstep(0.6, 0.82, value_noise(spot) * 0.6 + value_noise(spot * 2.7 + 5.0) * 0.4);
	float patina = clamp(blotch * max(edge, low * 0.8) * patina_amount, 0.0, 0.8);

	vec3 metal = brass_color * mix(0.92, 1.06, grain) * mix(0.94, 1.06, h0);
	ALBEDO = mix(metal, patina_color, patina);
	ROUGHNESS = clamp(mix(0.3, 0.55, h0) + patina * 0.25, 0.28, 0.85);
	METALLIC = mix(0.9, 0.7, patina);
}

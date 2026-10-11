shader_type spatial;
// Crackling electric shell over a shocked enemy. Put on a camera-facing quad centred on the body: a few jagged
// filaments re-roll at a stepped cadence inside an elliptical mask, with a faint shimmering rim.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float visual_time = 0.0;
uniform float motion_speed = 1.0; // slowed for reduced motion
uniform float seed = 0.0;
uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 glow_color : source_color = vec4(0.25, 0.75, 1.0, 1.0);
uniform float intensity = 2.4;

float hash(float n) {
	return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

float value_noise(float x) {
	float i = floor(x);
	float f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(hash(i), hash(i + 1.0), f) * 2.0 - 1.0;
}

// One jagged filament crossing the body. It re-rolls its angle, offset and shape each tick and is only lit on some ticks.
float filament(vec2 p, float id, float time) {
	float tick = floor(time * 0.35 + hash(id + seed) * 3.0);
	float live = step(0.35, hash(tick * 3.7 + id * 11.0 + seed));
	float angle = (hash(tick + id * 5.0 + seed) - 0.5) * 3.14159;
	float c = cos(angle);
	float s = sin(angle);
	vec2 q = vec2(c * p.x + s * p.y, -s * p.x + c * p.y);
	float offset = (hash(tick * 1.7 + id) - 0.5) * 0.7;
	float wobble = value_noise(q.y * 5.0 + tick * 9.0 + id * 17.0) * 0.22 + value_noise(q.y * 13.0 + tick * 21.0) * 0.08;
	float d = abs(q.x - offset - wobble);
	return live * (exp(-d * 55.0) + exp(-d * 9.0) * 0.25);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float e = length(p / vec2(0.78, 0.92));
	float body_mask = 1.0 - smoothstep(0.55, 1.05, e);
	float time = visual_time * motion_speed * 14.0;
	float lines = (filament(p, 0.0, time) + filament(p, 1.0, time) + filament(p, 2.0, time)) * body_mask;
	float shimmer = 0.5 + 0.5 * sin(visual_time * motion_speed * 11.0 + atan(p.y, p.x) * 3.0);
	float rim = exp(-pow((e - 0.9) * 5.0, 2.0)) * shimmer * 0.2;
	vec3 colour = mix(glow_color.rgb, core_color.rgb, clamp(lines, 0.0, 1.0));
	ALBEDO = colour * (lines + rim) * intensity;
}

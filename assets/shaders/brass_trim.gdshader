shader_type spatial;
render_mode cull_disabled;

// Brushed, lightly patinated brass for the room's copings, caps and fittings. The brushing runs along the wall, which is
// told apart by position: anything outside `inner_half.x` is a side wall.

uniform vec3 brass_color : source_color = vec3(0.62, 0.52, 0.34);
uniform vec3 patina_color : source_color = vec3(0.18, 0.36, 0.3);
uniform vec2 inner_half = vec2(12.8, 9.0);

varying vec3 world_position;

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

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 stretch = abs(world_position.x) > inner_half.x ? vec2(40.0, 2.0) : vec2(2.0, 40.0);
	float brush = value_noise(world_position.xz * stretch + vec2(world_position.y * 7.0, 0.0));
	float grain = value_noise(world_position.xz * 25.0 + world_position.y * 11.0);
	float patina = smoothstep(0.62, 0.9, value_noise(world_position.xz * 1.7 + world_position.y * 3.0)) * 0.4;
	ALBEDO = mix(brass_color * mix(0.85, 1.1, grain), patina_color, patina);
	ROUGHNESS = mix(0.5, 0.72, brush) + patina * 0.2;
	METALLIC = mix(0.55, 0.4, patina);
}

shader_type spatial;
// Floor decal for one enemy-only ground zone (GroundZones). The quad is the zone plus a small margin; the shape edge
// is the exact gameplay boundary, roughened a touch.
//   style 0 (disc): a faint field with a rim and a slow ripple, for round zones.
//   style 1 (rift): a dark crack with a glowing, jagged seam that opens from the middle outward, for fissures.
// `open` grows the zone in (0 to 1) and `life` (elapsed / duration) fades it out over its last quarter.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform int style = 1;
uniform bool is_circle = false;
uniform vec2 half_size = vec2(0.45, 2.5); // true half extents in metres: (across, along) for a line, (radius, radius) for a circle
uniform vec2 plane_size = vec2(1.4, 6.0);
uniform vec4 tint : source_color = vec4(0.43, 0.94, 0.69, 1.0);
uniform float life = 0.0;
uniform float open = 1.0;
uniform float motion = 1.0; // animation speed multiplier (slowed for reduced motion)

float snoise(vec2 p) {
	return 0.5 + 0.25 * sin(p.x * 2.1 + 1.7 * sin(p.y * 1.4 + 1.0)) + 0.25 * sin(p.y * 1.9 + 1.5 * sin(p.x * 1.1 + 2.0));
}

float sd_shape(vec2 p) {
	if (is_circle) {
		return length(p) - half_size.x;
	}
	vec2 q = abs(p) - half_size;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
}

void fragment() {
	vec2 p = (UV - 0.5) * plane_size;
	float t = TIME * motion;
	float d = sd_shape(p) + (snoise(p * 1.7) - 0.5) * 0.14;
	float inside = smoothstep(0.04, -0.04, d);
	float rim = smoothstep(0.10, 0.0, abs(d + 0.05));
	float fade = 1.0 - smoothstep(0.75, 1.0, life);
	float along = style == 1 ? abs(p.y) / max(half_size.y, 0.001) : length(p) / max(half_size.x, 0.001);
	float grown = smoothstep(0.0, 0.25, open * 1.25 - along);
	vec3 dark = tint.rgb * 0.10;
	vec3 col;
	float a;
	if (style == 1) {
		float wobble = (snoise(vec2(p.y * 1.3, 4.0)) - 0.5) * half_size.x * 0.9;
		float seam = abs(p.x - wobble);
		float core = smoothstep(0.07, 0.0, seam);
		float glow = smoothstep(half_size.x, 0.0, seam);
		float flow = 0.65 + 0.35 * sin(p.y * 2.6 - t * 6.0);
		float split = abs(p.x - wobble - sin(p.y * 5.0 + 1.0) * half_size.x * 0.5);
		float branch = smoothstep(0.045, 0.0, split) * smoothstep(0.1, 0.5, snoise(vec2(p.y * 2.0, 9.0)));
		col = mix(dark, tint.rgb, glow * 0.55 * flow);
		col = mix(col, vec3(1.0), core * 0.85);
		col = mix(col, tint.rgb * 1.3, branch * 0.7);
		a = 0.45 + glow * 0.25 + core * 0.35 + branch * 0.25;
	} else {
		float r = length(p) / max(half_size.x, 0.001);
		float ripple = smoothstep(0.12, 0.0, abs(fract(r * 1.5 - t * 0.35) - 0.5) - 0.34) * smoothstep(1.0, 0.2, r);
		col = mix(dark, tint.rgb, 0.45 + ripple * 0.5);
		a = 0.22 + ripple * 0.25;
	}
	col = mix(col, tint.rgb * 1.4, rim * 0.9);
	ALBEDO = col;
	ALPHA = clamp((a * inside + rim * 0.8) * grown * fade, 0.0, 1.0);
}

shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.35, 0.93, 0.88, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float brightness = 1.0;
uniform bool pending = false;
uniform bool compact = false;
uniform float segments = 3.0;

float band(float radius, float centre, float width, float aa) {
	return 1.0 - smoothstep(width, width + aa, abs(radius - centre));
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float aa = max(fwidth(r), 0.001);
	float turn = fract(atan(p.x, -p.y) / 6.2831853 + 1.0);
	float completed = step(turn, progress) * step(0.0001, progress);
	float ink;
	if (compact) {
		float gap = smoothstep(0.035, 0.065, fract(turn * max(segments, 1.0))) * (1.0 - smoothstep(0.935, 0.965, fract(turn * max(segments, 1.0))));
		ink = band(r, 0.82, 0.035, aa) * gap * mix(0.12, 0.85, completed);
		ink += band(r, 0.90, 0.005, aa) * 0.23;
	} else {
		float ticks = 1.0 - smoothstep(0.025, 0.05, abs(fract(turn * 4.0 + 0.5) - 0.5));
		float dashed = step(0.22, fract(turn * 32.0));
		ink = band(r, 0.88, 0.009, aa) * (pending ? dashed * 0.38 : 0.62);
		ink += band(r, 0.835, 0.031, aa) * ticks * (pending ? 0.28 : 0.85);
		ink += band(r, 0.76, 0.020, aa) * (pending ? 0.0 : mix(0.10, 0.90, completed));
		ink += (1.0 - smoothstep(0.68, 0.86, r)) * (pending ? 0.012 : 0.028);
	}
	ALBEDO = tint.rgb * brightness;
	EMISSION = tint.rgb * ink * 0.35;
	ALPHA = clamp(ink, 0.0, 1.0) * tint.a;
}

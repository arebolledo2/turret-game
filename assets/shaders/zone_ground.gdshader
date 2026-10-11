shader_type spatial;
// Patterned floor for one terrain zone, drawn on a plane slightly larger than the zone. The pattern says what the
// zone does: rising chevrons (high ground), bubbling sludge (mud), hazard hatching with a barred circle (no-build)
// and pulses running out from the pylon (power node). The shape edge is the exact gameplay boundary, softened a touch.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform int zone_kind = 0; // 0 high ground, 1 mud, 2 no-build, 3 power node
uniform bool is_circle = true;
uniform vec2 half_size = vec2(3.0); // the zone's true half extents in metres
uniform vec2 plane_size = vec2(6.5); // the mesh size (zone plus margin)
uniform vec4 base_color : source_color = vec4(0.2, 0.4, 0.6, 1.0);
uniform vec4 accent_color : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform float fill_alpha = 0.3;
uniform float motion = 1.0; // animation speed multiplier (slowed for reduced motion)

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth, lattice-free noise in 0..1 (hashed value noise showed square artefacts on the floor).
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
	// Slightly ragged edge, never more than a few centimetres from the true boundary.
	float d = sd_shape(p) + (snoise(p * 1.2) - 0.5) * 0.16;
	float inside = smoothstep(0.05, -0.05, d);
	float edge = smoothstep(0.1, 0.0, abs(d + 0.05));
	float glow = smoothstep(-0.8, 0.0, d);
	vec3 col = base_color.rgb;
	float a = fill_alpha;

	if (zone_kind == 0) {
		// Chevrons climbing toward the top of the screen.
		float s = -p.y + abs(p.x) * 0.7;
		float w = fract(s * 0.6 - t * 0.3);
		float band = smoothstep(0.0, 0.08, w) * smoothstep(0.32, 0.24, w);
		band *= smoothstep(0.0, -0.5, d);
		col = mix(col, accent_color.rgb, band * 0.85);
		a += band * 0.3;
	} else if (zone_kind == 1) {
		// Slow-moving sludge with the odd bubble.
		vec2 q = p * 0.9 + vec2(t * 0.04, -t * 0.03);
		float n = snoise(q * 1.3) * 0.6 + snoise(q * 2.9 + 5.0) * 0.4;
		col = mix(base_color.rgb, accent_color.rgb, smoothstep(0.25, 0.85, n) * 0.8);
		a += 0.15 * n;
		vec2 g = p * 0.8;
		vec2 id = floor(g);
		vec2 f = fract(g) - 0.5;
		float r = hash(id);
		float life = fract(t * 0.18 + r * 7.0);
		vec2 centre = (vec2(hash(id + 3.0), hash(id + 9.0)) - 0.5) * 0.5;
		float ring = abs(length(f - centre) - life * 0.32);
		float bubble = smoothstep(0.035, 0.0, ring) * (1.0 - life) * step(0.5, r);
		col = mix(col, accent_color.rgb * 1.8, bubble * 0.8);
		a += bubble * 0.25;
	} else if (zone_kind == 2) {
		// Hazard hatching and a barred circle: "nothing goes here".
		float stripe = step(0.5, fract((p.x + p.y) * 0.9));
		col = mix(base_color.rgb * 0.18, base_color.rgb, stripe);
		a = mix(fill_alpha * 0.45, fill_alpha * 1.5, stripe);
		float gr = min(half_size.x, half_size.y) * 0.72;
		float ring = smoothstep(0.11, 0.05, abs(length(p) - gr));
		float slash = smoothstep(0.11, 0.05, abs(dot(p, vec2(0.7071, 0.7071)))) * step(length(p), gr);
		float glyph = max(ring, slash);
		col = mix(col, accent_color.rgb, glyph);
		a = mix(a, 0.9, glyph);
	} else {
		// Charge pulses running outward and thin spokes of current.
		float r = length(p);
		float pulse = fract(r * 0.45 - t * 0.35);
		float band = smoothstep(0.0, 0.05, pulse) * smoothstep(0.2, 0.1, pulse);
		float ang = atan(p.y, p.x);
		float spoke = smoothstep(0.07, 0.0, abs(sin(ang * 4.0)) * r) * smoothstep(1.0, 0.25, r / half_size.x);
		float flicker = 0.85 + 0.15 * sin(t * 13.0 + r * 3.0);
		col = mix(col, accent_color.rgb, clamp(band + spoke, 0.0, 1.0) * flicker);
		a += band * 0.35 + spoke * 0.3;
	}

	vec3 outc = mix(col, accent_color.rgb, clamp(edge * 0.9 + glow * 0.12, 0.0, 1.0));
	ALBEDO = outc;
	ALPHA = clamp((a + glow * 0.1) * inside + edge * 0.75, 0.0, 1.0);
}

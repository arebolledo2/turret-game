shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// Fill-gauge attack telegraph. The quad is the exact attack footprint; the outline marks the hit area and the
// fill advances from the attacker toward the far edge as the wind-up elapses, landing at progress = 1.
// shape: 0 = line (rectangle along -Z), 1 = circle, 2 = sector (cone from the quad centre toward -Z).
uniform int shape = 0;
uniform vec4 tint : source_color = vec4(1.0, 0.54, 0.24, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// World size (metres) of the quad on X and Z, so edge widths stay constant at any scale.
uniform vec2 extent = vec2(1.0, 1.0);
uniform float half_angle = 0.5;
uniform float flow = 1.0;

float soft(float edge, float aa) {
	return smoothstep(0.0, aa, edge);
}

void fragment() {
	vec2 p = (UV - 0.5) * extent;
	float edge; // metres inside the footprint (0 on the boundary)
	float t;    // 0 at the attacker, 1 at the far edge
	float reach;
	if (shape == 0) {
		float along = (1.0 - UV.y) * extent.y;
		edge = min(extent.x * 0.5 - abs(p.x), min(along, extent.y - along));
		t = along / extent.y;
		reach = extent.y;
	} else {
		float r = length(p);
		float radius = extent.x * 0.5;
		edge = radius - r;
		t = r / radius;
		reach = radius;
		if (shape == 2) {
			float angle = atan(p.x, -p.y);
			edge = min(edge, (half_angle - abs(angle)) * max(r, 0.0001));
			// Keep the apex from pinching into a bright dot.
			t = max(t, 0.0);
		}
	}
	float aa = max(fwidth(edge), 0.003);
	float inside = soft(edge, aa + 0.01);
	float rim_width = clamp(extent.x * 0.06, 0.035, 0.07);
	if (shape == 0) {
		rim_width = min(rim_width, extent.x * 0.22);
	}
	float rim = inside * (1.0 - smoothstep(rim_width, rim_width + aa + 0.025, edge));

	float urgency = smoothstep(0.6, 1.0, progress);
	float filled = 1.0 - smoothstep(progress - 0.012, progress + 0.012, t);
	filled *= step(0.0005, progress);
	float lead = exp(-pow((t - progress) * reach / 0.1, 2.0)) * step(0.0005, progress);

	// Gentle travelling bands inside the fill so the gauge reads as moving, not a flat wash.
	float band = 0.5 + 0.5 * sin(t * reach * 7.0 - TIME * 6.0 * flow);
	float body = mix(0.06, 0.40 + 0.08 * band * flow, filled);
	body += (1.0 - t) * 0.06 * filled;
	// Faint inner glow keeps the edge of the footprint readable on bright floors.
	float glow = exp(-edge * 6.0) * inside * 0.20;

	float ink = inside * body + glow + rim * mix(0.55, 0.95, urgency) + lead * inside * 0.30;
	vec3 hot = mix(tint.rgb, vec3(1.0, 0.95, 0.80), clamp(lead * 0.35 + urgency * 0.2, 0.0, 1.0));
	ALBEDO = hot;
	EMISSION = hot * (0.35 + 0.65 * (rim + lead * inside) + urgency * 0.3 * filled * inside);
	ALPHA = clamp(ink, 0.0, 1.0) * tint.a;
}

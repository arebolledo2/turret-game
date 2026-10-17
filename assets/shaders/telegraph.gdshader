shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

// Fill-gauge attack telegraph. The quad is the exact attack footprint: a crisp rim marks the hit area, a dark
// hazard-hatched backing keeps it readable on any floor, and an energy fill advances from the attacker toward the
// far edge as the wind-up elapses, landing at progress = 1.
// shape: 0 = line (rectangle along -Z), 1 = circle, 2 = sector (cone from the quad centre toward -Z).
uniform int shape = 0;
uniform vec4 tint : source_color = vec4(1.0, 0.54, 0.24, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// World size (metres) of the quad on X and Z, so edge widths stay constant at any scale.
uniform vec2 extent = vec2(1.0, 1.0);
uniform float half_angle = 0.5;
uniform float flow = 1.0;

void fragment() {
	vec2 p = (UV - 0.5) * extent;
	float edge; // metres inside the footprint (0 on the boundary)
	float t;    // 0 at the attacker, 1 at the far edge
	float reach;
	float lateral; // 0 on the centre line, 1 at the sides (drives chevrons)
	if (shape == 0) {
		float along = (1.0 - UV.y) * extent.y;
		edge = min(extent.x * 0.5 - abs(p.x), min(along, extent.y - along));
		t = along / extent.y;
		reach = extent.y;
		lateral = abs(p.x) / (extent.x * 0.5);
	} else {
		float r = length(p);
		float radius = extent.x * 0.5;
		edge = radius - r;
		t = r / radius;
		reach = radius;
		lateral = 0.0;
		if (shape == 2) {
			float angle = atan(p.x, -p.y);
			edge = min(edge, (half_angle - abs(angle)) * max(r, 0.0001));
			lateral = abs(angle) / half_angle;
		}
	}
	float aa = max(fwidth(edge), 0.003);
	float inside = smoothstep(0.0, aa + 0.012, edge);

	float anim = flow * TIME;
	float urgency = smoothstep(0.65, 1.0, progress);
	float pulse = 0.5 + 0.5 * sin(TIME * 16.0);
	pulse = mix(1.0, pulse, urgency * flow);
	float landed = smoothstep(0.985, 1.0, progress);

	float filled = (1.0 - smoothstep(progress - 0.01, progress + 0.01, t)) * step(0.0005, progress);
	// Depth into the fill: 0 at the attacker, 1 at the advancing front. Energy pools at the front.
	float depth = clamp(t / max(progress, 0.001), 0.0, 1.0);

	// Backing: dark wash plus faint diagonal hazard stripes, so the outline stays legible on bright floors.
	float stripes = smoothstep(0.42, 0.58, abs(fract((p.x + p.y) * 3.2) - 0.5) * 2.0);
	float back_alpha = 0.20 + 0.07 * stripes;
	vec3 back_color = tint.rgb * 0.18;

	// Fill: chevrons (lines/cones) or ripples (circles) sweeping toward the impact edge.
	float wave = t * reach * (shape == 1 ? 3.0 : 2.4) - anim * 0.9;
	if (shape == 0) {
		wave += lateral * 0.55;
	}
	wave = fract(wave);
	float chevron = smoothstep(0.0, 0.25, wave) * (1.0 - smoothstep(0.5, 0.9, wave));
	float fill_alpha = mix(0.40, 0.72, pow(depth, 1.6)) + chevron * 0.08 * flow;
	fill_alpha *= 0.9 + 0.1 * pulse;

	// Hot leading edge, a crisp line with a soft halo behind it.
	float to_front = (t - progress) * reach;
	float lead_line = (1.0 - smoothstep(0.0, 0.035 + aa, abs(to_front))) * step(0.0005, progress) * step(progress, 0.995);
	float lead_halo = exp(-pow(to_front / 0.16, 2.0)) * step(0.0005, progress);

	// Rim: crisp bright outline with a soft inner glow.
	float rim_width = clamp(extent.x * 0.04, 0.03, 0.05);
	float rim = inside * (1.0 - smoothstep(rim_width, rim_width + aa + 0.012, edge));
	float inner_glow = exp(-edge * 7.0) * inside;

	vec3 base = mix(back_color, tint.rgb, filled);
	vec3 hot = mix(tint.rgb, vec3(1.0, 0.93, 0.78), 0.35);
	vec3 color = base;
	color = mix(color, hot, filled * chevron * 0.22 * flow);
	color = mix(color, hot, clamp(lead_line * 0.75 + lead_halo * 0.15 * filled + depth * filled * 0.10, 0.0, 1.0));
	color = mix(color, hot, rim * (0.30 + 0.30 * urgency));
	color = mix(color, vec3(1.0, 0.95, 0.85), landed * 0.6);

	float alpha = mix(back_alpha, fill_alpha, filled) * inside;
	alpha += inner_glow * mix(0.10, 0.22, filled) * pulse;
	alpha += lead_halo * filled * inside * 0.20;
	alpha += lead_line * inside * 0.55;
	alpha = max(alpha, rim * mix(0.78, 1.0, urgency));
	alpha += landed * inside * 0.2;

	ALBEDO = color;
	EMISSION = color * (0.25 + 0.75 * (rim + lead_line) + 0.35 * filled * inside + 0.3 * urgency * pulse * filled);
	ALPHA = clamp(alpha, 0.0, 1.0) * tint.a;
}

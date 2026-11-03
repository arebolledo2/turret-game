shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
// A floor hatch: triangular plates retract radially to open a hexagonal pit, lit from below.
// The quad is scaled so rr = 1 is the hatch boundary. `open` is the aperture (0 closed .. 1 fully open).
uniform vec4 tint : source_color = vec4(0.96, 0.66, 0.40, 1.0);
uniform float open : hint_range(0.0, 1.0) = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float pulse = 1.0;
uniform float segments = 6.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float rr = length(p) / 0.88;
	float aa = max(fwidth(rr), 0.001);
	float sector = 6.2831853 / segments;
	float turn = atan(p.x, -p.y);
	float local = mod(turn + sector * 0.5, sector) - sector * 0.5;
	// Polygon metric: distance along the nearest plate edge normal, so the aperture is a hexagon.
	float hexr = rr * cos(local);
	float aperture = open * 0.78;

	float disc = 1.0 - smoothstep(1.0, 1.0 + aa, rr);
	float pit = (1.0 - smoothstep(aperture, aperture + aa, hexr)) * step(0.001, open);

	// Plates: dark steel, darker at the seams between wedges, with an amber ember along each seam while moving.
	float seam = 1.0 - smoothstep(0.0, 0.035, (sector * 0.5 - abs(local)) * rr);
	vec3 plate = vec3(0.17, 0.16, 0.17) + vec3(0.07) * (1.0 - rr);
	plate = mix(plate, vec3(0.04), seam * 0.8);
	plate += tint.rgb * seam * 0.25 * smoothstep(0.0, 0.2, open);

	// Pit: near-black, with warm light welling up from the middle.
	float depth = 1.0 - clamp(hexr / max(aperture, 0.01), 0.0, 1.0);
	vec3 hole = vec3(0.012) + tint.rgb * 0.45 * depth * depth;

	// Glow along the aperture edge, plus a thin rim around the whole hatch.
	float flicker = 0.85 + 0.15 * pulse * sin(TIME * 18.0);
	float edge = exp(-max(hexr - aperture, 0.0) * 16.0) * smoothstep(0.0, 0.15, open) * flicker;
	float rim = (1.0 - smoothstep(0.012, 0.012 + aa, abs(rr - 0.965))) * 0.55;

	vec3 colour = mix(plate, hole, pit) + tint.rgb * edge * (1.0 - pit) * 0.9 + tint.rgb * rim;
	ALBEDO = colour;
	ALPHA = disc * fade;
}

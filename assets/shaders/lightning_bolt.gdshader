shader_type spatial;
// Lightning ribbon. The mesh is a triangle strip whose UV.x runs across the ribbon and UV.y along it; vertex colour R is
// the per-vertex strength (forks fade out along their length). Core, glow and halo are layered in the fragment so the
// white-hot centre blooms through the arena Environment glow while the edge falls off to a violet fringe.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 glow_color : source_color = vec4(0.25, 0.7, 1.0, 1.0);
uniform vec4 halo_color : source_color = vec4(0.45, 0.25, 1.0, 1.0);
uniform float age = 0.0; // 0 at the strike, 1 when the bolt is gone
uniform float flash_boost = 3.0;
uniform bool reduced_motion = false;

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float core = exp(-across * across * 38.0);
	float glow = exp(-across * across * 7.0);
	float halo = exp(-across * across * 2.2) * 0.35;
	// A one-frame-ish white spike on the strike, then a decay with a couple of dropouts so it reads as crackle.
	float flash = reduced_motion ? 1.0 : 1.0 + flash_boost * (1.0 - smoothstep(0.0, 0.14, age));
	float dropout = step(0.3, fract(sin(floor(age * 18.0) * 91.7) * 437.5));
	float flicker = reduced_motion ? 1.0 : mix(0.55, 1.0, dropout);
	float strength = COLOR.r * pow(1.0 - age, 1.5) * flicker * flash;
	vec3 colour = core_color.rgb * core * 2.2 + glow_color.rgb * glow * 1.4 + halo_color.rgb * halo;
	ALBEDO = colour * strength;
}

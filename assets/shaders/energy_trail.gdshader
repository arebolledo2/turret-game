shader_type spatial;
// Tapering additive streak behind a projectile. The mesh is a plane whose UV.y runs 0 at the head to 1 at the tail
// and UV.x runs across the width. Overbright values bloom through the arena Environment glow.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 glow_color : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform float intensity = 2.2;
uniform float fade_power = 1.7;

void fragment() {
	float along = clamp(UV.y, 0.0, 1.0);
	float half_width = mix(1.0, 0.18, along);
	float across = abs(UV.x * 2.0 - 1.0) / half_width;
	float profile = exp(-across * across * 5.0);
	float flicker = 0.88 + 0.12 * sin(TIME * 55.0 + along * 18.0);
	float strength = pow(1.0 - along, fade_power) * profile * flicker;
	vec3 colour = mix(core_color.rgb, glow_color.rgb, clamp(along * 1.4 + across * 0.5, 0.0, 1.0));
	ALBEDO = colour * strength * intensity;
}

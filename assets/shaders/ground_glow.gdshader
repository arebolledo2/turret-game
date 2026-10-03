shader_type spatial;
// Soft pulsing light pool on the floor under a pickup. Phase comes from world position so neighbours desync.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.6, 0.15, 1.0);
uniform float intensity = 1.1;
uniform float pulse_speed = 3.2;

varying float phase;

void vertex() {
	phase = MODEL_MATRIX[3].x * 1.7 + MODEL_MATRIX[3].z * 2.3;
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float falloff = pow(max(0.0, 1.0 - r), 2.2);
	float pulse = 0.75 + 0.25 * sin(TIME * pulse_speed + phase);
	ALBEDO = glow_color.rgb * falloff * intensity * pulse;
}

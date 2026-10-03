shader_type spatial;
// Camera-facing glow for a projectile head: white-hot core, coloured halo, gentle pulse. Honours node scale.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0);
uniform vec4 glow_color : source_color = vec4(0.2, 0.9, 1.0, 1.0);
uniform float intensity = 2.0;
uniform float pulse_speed = 16.0;

void vertex() {
	float scale_x = length(MODEL_MATRIX[0].xyz);
	float scale_y = length(MODEL_MATRIX[1].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale_x, INV_VIEW_MATRIX[1] * scale_y, INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float core = smoothstep(0.32, 0.0, r);
	float halo = pow(max(0.0, 1.0 - r), 2.6);
	float pulse = 1.0 + 0.14 * sin(TIME * pulse_speed);
	ALBEDO = (core_color.rgb * core * 1.6 + glow_color.rgb * halo) * intensity * pulse;
}

shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 edge_color : source_color = vec4(1.0, 0.17, 0.05, 1.0);

// Soft energy envelope around a hot filament; UV.y runs from emitter to impact.
void fragment() {
	float across = abs(UV.x - 0.5) * 2.0;
	float envelope = exp(-across * across * 5.5);
	float filament = exp(-across * across * 65.0);
	float ends = smoothstep(0.0, 0.045, UV.y) * smoothstep(0.0, 0.045, 1.0 - UV.y);
	float flow = 0.88 + 0.12 * sin(UV.y * 85.0 - TIME * 19.0);
	vec3 energy = mix(edge_color.rgb, vec3(1.0, 0.84, 0.46), filament);
	ALBEDO = energy;
	EMISSION = energy * (1.2 + filament);
	ALPHA = envelope * ends * flow * 0.8;
}

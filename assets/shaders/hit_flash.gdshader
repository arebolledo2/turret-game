shader_type spatial;
// Additive hit flash drawn as a material overlay. Only attached while an actor is flashing, so idle
// enemies pay nothing. The rim term keeps the silhouette hot from a top-down camera.
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	// Peaks near the Environment glow threshold: a hot rim that blooms, with the base colour still readable underneath.
	ALBEDO = flash_color.rgb * strength * (0.5 + 1.0 * rim) * 0.85;
}

shader_type spatial;
render_mode cull_disabled;

// Riveted hull plating for the arena room's walls, drawn in world space so every face tiles evenly whatever its size.
// Panels sit in a running bond; each gets a slight tone of its own, dark seams and four corner rivets.

uniform vec3 base_color : source_color = vec3(0.14, 0.2, 0.23);
uniform vec3 seam_color : source_color = vec3(0.02, 0.03, 0.04);
uniform vec2 panel_size = vec2(1.2, 0.6);

varying vec3 world_position;
varying vec3 world_normal;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 plane;
	if (n.y > n.x && n.y > n.z) {
		plane = world_position.xz;
	} else if (n.x > n.z) {
		plane = world_position.zy;
	} else {
		plane = world_position.xy;
	}
	vec2 cell = plane / panel_size;
	cell.x += mod(floor(cell.y), 2.0) * 0.5;
	vec2 id = floor(cell);
	vec2 local = fract(cell);
	vec2 edge = min(local, 1.0 - local) * panel_size;
	float seam = 1.0 - smoothstep(0.012, 0.032, min(edge.x, edge.y));
	float rivet = 1.0 - smoothstep(0.018, 0.03, length(edge - vec2(0.09)));
	float tone = 0.88 + 0.24 * hash21(id);
	// A faintly lighter band every 1.5 m of height or run, so a long face is not one flat sheet.
	float band = 1.0 + 0.07 * step(0.5, fract(plane.y / 1.5));
	vec3 colour = base_color * tone * band;
	colour = mix(colour, seam_color, seam * 0.85);
	colour += vec3(0.07, 0.07, 0.06) * rivet;
	ALBEDO = colour;
	ROUGHNESS = mix(0.8, 0.5, rivet);
	METALLIC = 0.35;
}

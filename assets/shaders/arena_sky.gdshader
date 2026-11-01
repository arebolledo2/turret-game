shader_type sky;

// The ambient and reflection source for the arena: the old dark gradient plus sparse stars, so polished brass has something
// to mirror. It has no TIME, so Godot renders it once and it costs nothing per frame. (The camera never sees it directly;
// the SpaceBackdrop covers every pixel outside the room.)

uniform vec3 top_color : source_color = vec3(0.0033, 0.0152, 0.0331);
uniform vec3 horizon_color : source_color = vec3(0.0232, 0.1049, 0.1441);
uniform vec3 bottom_color : source_color = vec3(0.0024, 0.0075, 0.0130);
uniform float energy = 0.9;

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	float h = EYEDIR.y;
	vec3 colour = h >= 0.0 ? mix(horizon_color, top_color, pow(h, 0.6)) : mix(horizon_color, bottom_color, pow(-h, 0.6));
	vec3 cell_space = EYEDIR * 70.0;
	vec3 id = floor(cell_space);
	vec3 local = fract(cell_space) - 0.5;
	float star = step(0.985, hash31(id)) * smoothstep(0.3, 0.0, length(local));
	COLOR = colour * energy + vec3(0.9, 0.95, 1.0) * star * 1.5;
}

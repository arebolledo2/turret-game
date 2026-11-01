shader_type sky;

// The ambient and reflection source for the arena: a small "studio". The room's brass and hull are metal, and metal shows
// only what it reflects, so the sky has to hold something worth reflecting:
//  - a warm-white softbox in the north half of the sky, where the orthographic camera's mirror direction lands for any
//    upward-facing surface (about 52 degrees up, towards the back wall). Flat copings sit on the softbox's edge and the rounded
//    noses sweep through its middle, which makes them read as polished metal rather than a flat tan;
//  - a bounce of the theme's rim colour across the lower hemisphere, because side slopes and hull faces reflect downwards;
//  - the old dark gradient and sparse stars for everything else.
// It has no TIME, so Godot renders it once per change and it costs nothing per frame. (The camera never sees it directly;
// the SpaceBackdrop covers every pixel outside the room.) Everything stays under the bloom threshold after Fresnel.

uniform vec3 top_color : source_color = vec3(0.0033, 0.0152, 0.0331);
uniform vec3 horizon_color : source_color = vec3(0.0232, 0.1049, 0.1441);
uniform vec3 bottom_color : source_color = vec3(0.0024, 0.0075, 0.0130);
uniform float energy = 0.9;

// Key softbox.
uniform vec3 soft_dir = vec3(0.0, 0.88, -0.47);
uniform vec3 soft_color : source_color = vec3(1.0, 0.93, 0.82);
uniform float soft_width = 0.35;
uniform float soft_energy = 0.8;
// A high southern fill: what the front cap's quarter-round mirrors as it turns away from the camera, so rounded caps catch a
// highlight band instead of one flat tone. (Side copings gained nothing from low east/west strips, so there are none.)
uniform vec3 fill_dir = vec3(0.0, 0.75, 0.66);
uniform float fill_width = 0.25;
uniform float fill_energy = 0.35;
// Lower-hemisphere bounce: `bounce_color` sets the hue (the stage passes the floor theme's rim colour), `bounce_level` the
// luminance, so every theme gets the same amount of light whatever its colour.
uniform vec3 bounce_color : source_color = vec3(0.145, 0.557, 0.6);
uniform float bounce_level = 0.16;

float hash31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	float h = EYEDIR.y;
	vec3 hue = bounce_color / max(dot(bounce_color, vec3(0.2126, 0.7152, 0.0722)), 0.02);
	// Below the horizon the bounce is strongest near it and thins towards the nadir.
	vec3 bounce = hue * bounce_level * mix(1.0, 0.45, smoothstep(0.0, 1.0, -h));
	vec3 below = mix(horizon_color * energy, bounce, smoothstep(0.0, 0.18, -h)) + bottom_color * energy * smoothstep(0.0, 1.0, -h);
	vec3 above = mix(horizon_color, top_color, pow(max(h, 0.0), 0.6)) * energy;
	vec3 colour = h >= 0.0 ? above : below;
	// The softbox: a smooth cosine falloff around `soft_dir`, faded out towards the horizon so it never reaches the lower half.
	float aim = dot(EYEDIR, normalize(soft_dir));
	float lobe = smoothstep(1.0 - soft_width, 1.0, aim);
	colour += soft_color * soft_energy * lobe * smoothstep(0.0, 0.2, h);
	float fill = smoothstep(1.0 - fill_width, 1.0, dot(EYEDIR, normalize(fill_dir)));
	colour += soft_color * fill_energy * fill * smoothstep(0.0, 0.2, h);
	vec3 cell_space = EYEDIR * 70.0;
	vec3 id = floor(cell_space);
	vec3 local = fract(cell_space) - 0.5;
	float star = step(0.985, hash31(id)) * smoothstep(0.3, 0.0, length(local));
	COLOR = colour + vec3(0.9, 0.95, 1.0) * star * 1.5;
}

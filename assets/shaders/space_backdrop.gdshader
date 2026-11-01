shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The view outside the room: a ship's-eye starfield on one huge plane far below the floor. The camera is orthographic, so
// depth gives no parallax by itself; each layer instead follows the camera by a fraction `k` (0 = fixed to the screen,
// 1 = fixed to the world) and scrolls by `drift * k` to sell the ship's travel. Settings come from SpaceThemes.

uniform vec3 base_color : source_color = vec3(0.004, 0.008, 0.02);
uniform vec3 nebula_a : source_color = vec3(0.05, 0.12, 0.25);
uniform vec3 nebula_b : source_color = vec3(0.1, 0.05, 0.2);
uniform float nebula_amount = 0.3;
uniform float nebula_scale = 0.035;
uniform float star_density = 0.5;
uniform float star_brightness = 2.4;
uniform vec3 star_tint : source_color = vec3(0.85, 0.92, 1.0);
/// Metres per second the nearest layer scrolls, i.e. the direction the ship travels over the plane (xz).
uniform vec2 drift = vec2(0.0, -1.2);
/// Stretches stars along the heading: 0 is dots, larger is warp streaks.
uniform float streak = 0.0;
uniform float debris_density = 0.0;
uniform vec3 debris_color : source_color = vec3(0.16, 0.13, 0.11);
uniform float planet_radius = 0.0;
uniform vec2 planet_position = vec2(0.0, -38.0);
uniform vec3 planet_color : source_color = vec3(0.55, 0.3, 0.14);
uniform vec3 planet_glow : source_color = vec3(1.0, 0.55, 0.25);
/// Direction the star light comes from, on the plane (xz).
uniform vec2 light_direction = vec2(-0.6, -0.5);

varying vec3 plane_position;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p) {
	float n = hash21(p);
	return vec2(n, hash21(p + n + 17.0));
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float amplitude = 0.5;
	float sum = 0.0;
	for (int i = 0; i < 5; i++) {
		sum += amplitude * value_noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return sum;
}

// One layer of stars on a jittered grid. `p` is layer space in metres; the grid is stretched along the heading for streaks.
vec3 star_layer(vec2 p, float cell, float density, float size, float brightness) {
	vec2 heading = normalize(drift + vec2(0.0001));
	vec2 q = vec2(dot(p, heading) / (1.0 + streak), dot(p, vec2(-heading.y, heading.x))) / cell;
	vec2 id = floor(q);
	vec2 local = fract(q) - 0.5;
	if (hash21(id) > density) {
		return vec3(0.0);
	}
	vec2 jitter = (hash22(id + 3.7) - 0.5) * 0.55;
	float distance_to_star = length(local - jitter); // round in the stretched grid, so a streak in world space
	float star_size = size * (0.5 + hash21(id + 9.1));
	float glow = smoothstep(star_size, 0.0, distance_to_star);
	float tone = hash21(id + 5.3);
	vec3 colour = mix(star_tint, vec3(1.0, 0.8, 0.6), step(0.8, tone)) * mix(0.5, 1.0, hash21(id + 1.9));
	return colour * glow * glow * brightness;
}

vec3 rock_layer(vec2 p, float cell, float density) {
	vec2 q = p / cell;
	vec2 id = floor(q);
	vec2 local = fract(q) - 0.5;
	if (hash21(id + 41.0) > density) {
		return vec3(0.0);
	}
	vec2 centre = (hash22(id + 11.3) - 0.5) * 0.4;
	vec2 d = local - centre;
	float radius = mix(0.06, 0.26, hash21(id + 2.2));
	float lumpy = length(d) + 0.5 * radius * (value_noise(d * 14.0 + id) - 0.5);
	float body = smoothstep(radius, radius * 0.85, lumpy);
	float lit = clamp(0.35 + dot(normalize(d + vec2(0.0001)), normalize(light_direction)) * -0.65 * smoothstep(0.0, radius, length(d)), 0.0, 1.0);
	return debris_color * (0.25 + lit * 1.6) * body;
}

void vertex() {
	plane_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 camera_xz = INV_VIEW_MATRIX[3].xz;
	vec2 world_xz = plane_position.xz;
	float time = TIME;

	vec3 colour = base_color;

	// Nebula: two slow, far layers of warped noise.
	vec2 far_p = world_xz - camera_xz * 0.9 + drift * time * 0.1;
	float cloud = fbm(far_p * nebula_scale + fbm(far_p * nebula_scale * 0.6) * 1.2);
	float tint_mix = fbm(far_p * nebula_scale * 0.7 + vec2(31.0, 7.0));
	colour += mix(nebula_a, nebula_b, tint_mix) * smoothstep(0.2, 0.95, cloud) * nebula_amount;

	// Distant planet, drawn as a lit disc with a banded surface and an atmosphere rim.
	if (planet_radius > 0.0) {
		vec2 planet_p = world_xz - camera_xz * 0.88 + drift * time * 0.04;
		vec2 d = (planet_p - planet_position) / planet_radius;
		float r = length(d);
		vec3 normal = vec3(d, sqrt(max(0.0, 1.0 - r * r)));
		vec3 sun = normalize(vec3(light_direction.x, light_direction.y, 0.7));
		float light = clamp(dot(normal, sun), 0.0, 1.0);
		float bands = 0.75 + 0.5 * fbm(vec2(d.y * 9.0, d.x * 1.3 + 4.0));
		vec3 surface = planet_color * bands * (0.06 + light * 1.4);
		float disc = smoothstep(1.0, 0.99, r);
		float rim = exp(-max(r - 1.0, 0.0) * 14.0) * smoothstep(-0.4, 0.8, dot(vec2(normal.x, normal.y), sun.xy) + 0.3);
		colour = mix(colour, surface, disc);
		colour += planet_glow * rim * (1.0 - disc) * 0.55;
		colour += planet_glow * pow(1.0 - normal.z, 3.0) * light * disc * 0.5;
	}

	// Stars: three depths, nearer ones brighter and faster.
	colour += star_layer(world_xz - camera_xz * 0.85 + drift * time * 0.15, 1.1, star_density, 0.09, star_brightness * 0.7);
	colour += star_layer(world_xz - camera_xz * 0.6 + drift * time * 0.4, 1.8, star_density * 0.7, 0.11, star_brightness * 0.9);
	colour += star_layer(world_xz - camera_xz * 0.25 + drift * time * 0.8, 3.0, star_density * 0.45, 0.14, star_brightness * 1.3);

	// Debris close to the hull: dark rocks sliding past.
	if (debris_density > 0.0) {
		colour += rock_layer(world_xz - camera_xz * 0.05 + drift * time * 1.6, 7.0, debris_density);
		colour = max(colour, vec3(0.0));
	}

	ALBEDO = colour;
}

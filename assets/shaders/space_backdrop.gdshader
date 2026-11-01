shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;

// The view outside the room: a ship's-eye starfield on one huge plane far below the floor. The camera is orthographic, so
// depth gives no parallax by itself; each layer is offset by `camera * k` (k near 1 = stays put on the screen, i.e. far away;
// k near 0 = slides with the world, i.e. close) and scrolls by `drift * k` to sell the ship's travel. Settings come from
// SpaceThemes. Every optional feature is off at its default (0) and skips its work entirely when off: the backdrop shades
// every pixel the room does not cover, on a GPU shared with the game.

uniform vec3 base_color : source_color = vec3(0.004, 0.008, 0.02);
uniform vec3 nebula_a : source_color = vec3(0.05, 0.12, 0.25);
uniform vec3 nebula_b : source_color = vec3(0.1, 0.05, 0.2);
/// The colour the densest gas ramps up to (density ramp: nebula_a -> nebula_b -> nebula_core).
uniform vec3 nebula_core : source_color = vec3(0.3, 0.32, 0.45);
uniform float nebula_amount = 0.3;
uniform float nebula_scale = 0.035;
/// Thin bright ridged filaments threaded through the gas (0 = off).
uniform float nebula_filaments = 0.0;
/// Dark dust lanes that eat into the gas and dim the far stars behind them (0 = off).
uniform float dust_lanes = 0.0;
uniform float star_density = 0.5;
/// Keep near 1: only the rare hero stars (peak 1.3) should cross the bloom threshold of 1.0.
uniform float star_brightness = 1.1;
uniform vec3 star_tint : source_color = vec3(0.85, 0.92, 1.0);
/// Star radius scale in screen pixels (stars are sized on screen, not in metres, so they stay pin-sharp at every zoom).
uniform float star_size_px = 1.0;
/// Faint unresolved star dust: a dense haze of sub-pixel points (0 = off).
uniform float star_dust = 0.0;
/// Metres per second the nearest layer scrolls, i.e. the direction the ship travels over the plane (xz).
uniform vec2 drift = vec2(0.0, -1.2);
/// Star trail length multiplier: 0 is round dots, 1 is a warp-speed streak (about 0.6, 1.4 and 3 m on the three layers).
uniform float streak = 0.0;
/// The colour a trail cools to at its tail.
uniform vec3 trail_tint : source_color = vec3(0.48, 0.42, 1.0);
/// A Milky-Way band across the far sky with a dust lane down it (0 = off). `band_angle` in degrees, 0 = across the screen.
uniform float band_amount = 0.0;
uniform float band_angle = 25.0;
uniform vec3 band_color : source_color = vec3(0.62, 0.66, 0.8);
/// Distant spiral galaxies, one in about 7 of the 10 m cells (0 = off).
uniform float galaxy_amount = 0.0;
uniform float debris_density = 0.0;
uniform vec3 debris_color : source_color = vec3(0.16, 0.13, 0.11);
/// Planet (0 = none). `planet_position` is in the planet layer's space (world xz - camera xz * 0.88), where the centre of
/// the gameplay view sits near (0, -34.3).
uniform float planet_radius = 0.0;
uniform vec2 planet_position = vec2(0.0, -38.0);
/// Degrees the planet's pole leans from straight up the screen.
uniform float planet_tilt = 0.0;
/// Band colours: planet_color is the mid tone, planet_light the pale zones, planet_dark the dark belts.
uniform vec3 planet_color : source_color = vec3(0.55, 0.3, 0.14);
uniform vec3 planet_light : source_color = vec3(0.95, 0.83, 0.63);
uniform vec3 planet_dark : source_color = vec3(0.42, 0.23, 0.13);
uniform vec3 planet_glow : source_color = vec3(1.0, 0.55, 0.25);
/// An oval storm in the planet's southern belts (0 = off).
uniform float planet_storm = 0.0;
/// Ring opacity; rings run from 1.35 to 2.2 planet radii (0 = off).
uniform float planet_ring = 0.0;
/// A small phased moon in the planet layer (radius 0 = none).
uniform float moon_radius = 0.0;
uniform vec2 moon_position = vec2(0.0, -40.0);
/// Direction the star light comes from, on the plane (xz).
uniform vec2 light_direction = vec2(-0.6, -0.5);
/// Chance that a 20 m cell holds a dark gantry or fin of the ship's own superstructure.
uniform float hull_density = 0.15;
/// Glow of the engines, behind the ship (opposite the heading).
uniform vec3 engine_color : source_color = vec3(0.2, 0.35, 1.0);
uniform float engine_amount = 0.0;
/// How much the backdrop darkens close to the room's outline as seen on the plane, a soft shadow of the hull (0 = off).
uniform float hull_shadow = 0.0;

// Where rays through the room's footprint land on the plane: the camera looks down along (0, -17, -13), and the plane is
// 30 m below the floor, so a ground point lands 30 * 13 / 17 = 22.94 m further north (-z).
const vec2 ROOM_ON_PLANE = vec2(0.0, -22.94);
// The room's silhouette on the plane: its footprint (about 12.8 x 9.05 m each way) plus the 2.62 m back wall, whose top
// lands 2.62 * 13 / 17 = 2 m further north.
const vec2 ROOM_SILHOUETTE_CENTRE = vec2(0.0, -23.94);
const vec2 ROOM_SILHOUETTE_HALF = vec2(12.8, 10.05);
// The centre of the gameplay view on the plane is the camera's ground focus + (0, -22.94); the camera sits 13 m south of
// it, so on a layer with parallax k it is at about (0, -22.94 - 13 * k) (plus 1 - k of the focus, a few metres at most).
const float CAMERA_BACK = 13.0;

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

float fbm(vec2 p, int octaves) {
	float amplitude = 0.5;
	float sum = 0.0;
	for (int i = 0; i < octaves; i++) {
		sum += amplitude * value_noise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		amplitude *= 0.5;
	}
	return sum;
}

float box_distance(vec2 p, vec2 half_size) {
	vec2 d = abs(p) - half_size;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

vec2 rotate(vec2 v, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

vec3 tint_normalised() {
	return star_tint / max(max(star_tint.r, star_tint.g), max(star_tint.b, 0.001));
}

// Star colours (linear): blue-white bfd4ff 15%, white 55%, ffe6b3 20%, ffb380 10%, tinted by the theme.
vec3 star_colour(float t) {
	vec3 c = t < 0.15 ? vec3(0.521, 0.658, 1.0) : (t < 0.7 ? vec3(1.0) : (t < 0.9 ? vec3(1.0, 0.791, 0.451) : vec3(1.0, 0.451, 0.216)));
	return c * tint_normalised();
}

// One layer of stars on a jittered grid. `p` is layer space in metres; `to_px` maps a plane offset in metres to screen
// pixels, so each star is sized on screen: dust 0.6 px (70%), common 1.0 px (24%), bright 1.6 px (5%) and hero 2.2 px with a
// faint four-point spike (1%). With `streak` they become trails: a round head leading, a tail fading behind it and cooling in
// colour. The grid is stretched along the heading so a trail always fits inside its cell.
vec3 star_layer(vec2 p, float cell, float density, float brightness, float trail_metres, mat2 to_px, float time) {
	vec2 heading = normalize(drift + vec2(0.0001));
	vec2 side = vec2(-heading.y, heading.x);
	float length_m = streak * trail_metres;
	float along_cell = max(cell, length_m * 2.5);
	vec2 q = vec2(dot(p, heading) / along_cell, dot(p, side) / cell);
	vec2 id = floor(q);
	if (hash21(id) > density) {
		return vec3(0.0);
	}
	vec2 jitter = (hash22(id + 3.7) - 0.5) * 0.55;
	vec2 local = fract(q) - 0.5 - jitter;
	vec2 pix = to_px * (heading * (local.x * along_cell) + side * (local.y * cell));
	float size_class = hash21(id + 9.1);
	float radius = 0.6;
	float peak = 0.25;
	if (size_class > 0.99) {
		radius = 2.2;
		peak = 1.3;
	} else if (size_class > 0.94) {
		radius = 1.6;
		peak = 0.85;
	} else if (size_class > 0.7) {
		radius = 1.0;
		peak = 0.55;
	}
	// Widen by a fraction of a pixel so sub-pixel stars do not flicker as they slide between pixel centres.
	float r = sqrt(radius * radius * star_size_px * star_size_px + 0.12);
	vec3 colour = star_colour(hash21(id + 5.3)) * peak * brightness;
	if (streak <= 0.0) {
		float d = length(pix);
		bool hero = size_class > 0.99;
		if (d > (hero ? 9.0 : r * 4.0 + 2.0)) {
			return vec3(0.0);
		}
		float light = exp(-d * d / (r * r)) + 0.08 * exp(-d / (r * 2.5));
		if (hero) {
			vec2 a = abs(pix);
			light += 0.2 * (exp(-a.y * 1.6) * max(0.0, 1.0 - a.x / 8.0) + exp(-a.x * 1.6) * max(0.0, 1.0 - a.y / 8.0));
		}
		float twinkle = hash21(id + 7.7);
		if (twinkle > 0.8) {
			light *= 0.85 + 0.15 * sin(time * (2.0 + 3.0 * fract(twinkle * 13.0)) + twinkle * 60.0);
		}
		return colour * light;
	}
	// The star moves against the heading on screen, so its tail lies on the +heading side.
	vec2 trail_px = to_px * heading;
	float px_per_metre = length(trail_px);
	vec2 trail_dir = trail_px / px_per_metre;
	float along = dot(pix, trail_dir);
	float across = abs(pix.x * trail_dir.y - pix.y * trail_dir.x);
	float width = max(r, 0.8);
	if (across > width * 4.0) {
		return vec3(0.0);
	}
	float tail = length_m * mix(0.6, 1.4, hash21(id + 6.6)) * px_per_metre;
	float along_term = along < 0.0 ? exp(-along * along / (width * width)) : exp(-along / max(tail * 0.35, 0.001));
	float across_term = exp(-across * across / (width * width));
	vec3 cooled = mix(colour, trail_tint * peak * brightness, clamp(along / max(tail, 0.001), 0.0, 1.0));
	return cooled * along_term * across_term;
}

// Unresolved star dust: a faint clumpy haze plus dense sub-pixel points. `boost` thickens it (inside the Milky Way band).
vec3 dust_layer(vec2 p, mat2 to_px, float boost) {
	float clump = value_noise(p * 0.09) * boost;
	vec3 tint = tint_normalised();
	vec3 haze = tint * star_dust * 0.012 * clump;
	float cell = 0.45;
	vec2 q = p / cell;
	vec2 id = floor(q);
	if (hash21(id + 23.0) > 0.2 + 0.45 * clump) {
		return haze;
	}
	vec2 jitter = (hash22(id + 8.1) - 0.5) * 0.7;
	vec2 pix = to_px * ((fract(q) - 0.5 - jitter) * cell);
	float point = exp(-dot(pix, pix) / 0.45) * mix(0.05, 0.16, hash21(id + 4.4));
	return haze + star_colour(hash21(id + 1.3)) * point * star_dust;
}

// Distant spiral galaxies: a log spiral exp(-r/.25)(.6+.4cos(2(theta-3 ln r))) with a warm core, randomly turned and
// inclined, 1.5 to 3 m across.
vec3 galaxy_layer(vec2 p) {
	float cell = 10.0;
	vec2 id = floor(p / cell);
	if (hash21(id + 61.0) > 0.15) {
		return vec3(0.0);
	}
	vec2 centre = (id + 0.5) * cell + (hash22(id + 2.9) - 0.5) * (cell - 4.0);
	vec2 d = p - centre;
	float size = mix(0.75, 1.5, hash21(id + 4.1));
	if (dot(d, d) > size * size) {
		return vec3(0.0);
	}
	vec2 g = rotate(d, hash21(id + 8.8) * 6.2832);
	g.y /= mix(0.3, 1.0, hash21(id + 5.7));
	g /= size;
	float r = max(length(g), 0.001);
	float theta = atan(g.y, g.x);
	float arms = 0.6 + 0.4 * cos(2.0 * (theta - 3.0 * log(r)));
	float disc = exp(-r / 0.25) * arms;
	float core = exp(-r * r / 0.003);
	vec3 colour = mix(vec3(1.0, 0.82, 0.62), vec3(0.62, 0.74, 1.0), smoothstep(0.05, 0.45, r));
	return colour * (disc * 0.45 + core * 0.55) * galaxy_amount;
}

float ring_density(float rr) {
	float k = (rr - 1.35) / 0.85;
	if (k <= 0.0 || k >= 1.0) {
		return 0.0;
	}
	return smoothstep(0.0, 0.04, k) * (1.0 - smoothstep(0.93, 1.0, k)) * mix(0.3, 1.0, smoothstep(0.1, 0.3, k))
		* (0.72 + 0.28 * sin(rr * 90.0) * sin(rr * 23.0))
		* smoothstep(0.012, 0.03, abs(k - 0.62)) * mix(0.35, 1.0, smoothstep(0.004, 0.014, abs(k - 0.86)));
}

// The planet: banded disc with limb darkening, a soft terminator, an optional storm, rings (shadowed by the planet and
// shadowing it), and a thin atmosphere rim on the lit side. `cover` says how much of the pixel it hides (stars are masked).
void planet_layer(vec2 pp, float aa, float time, vec3 sun_flat, inout vec3 colour, inout float cover) {
	vec2 d = (pp - planet_position) / planet_radius;
	float r = length(d);
	if (r > 2.3) {
		return;
	}
	float tilt = radians(planet_tilt);
	vec2 t = rotate(d, -tilt);
	vec3 sun = vec3(rotate(sun_flat.xy, -tilt), sun_flat.z);
	// The pole points up the screen, tipped a little towards the viewer so bands curve and rings open into an ellipse.
	const float SIN_I = 0.3;
	const float COS_I = 0.954;
	vec3 pole = vec3(0.0, -COS_I, SIN_I);
	vec3 ring_axis = vec3(0.0, SIN_I, COS_I);

	float ring_alpha = 0.0;
	vec3 ring_colour = vec3(0.0);
	bool ring_front = false;
	if (planet_ring > 0.0 && abs(t.y) < 2.25 * SIN_I) {
		float b = t.y / SIN_I;
		float rr = length(vec2(t.x, b));
		float density = ring_density(rr);
		if (density > 0.0) {
			vec3 x3 = vec3(t.x, t.y, b * COS_I);
			float toward_sun = dot(x3, sun);
			float shadow = (toward_sun < 0.0 && toward_sun * toward_sun - dot(x3, x3) + 1.0 > 0.0) ? 0.1 : 1.0;
			ring_colour = mix(planet_light, planet_color, 0.35 + 0.3 * sin(rr * 31.0)) * 0.42 * shadow;
			ring_alpha = density * planet_ring * 0.75;
			ring_front = x3.z > 0.0;
		}
	}
	if (ring_alpha > 0.0 && !ring_front) {
		colour = mix(colour, ring_colour, ring_alpha);
		cover = max(cover, ring_alpha);
	}

	float disc = 1.0 - smoothstep(1.0 - aa, 1.0, r);
	if (r < 1.0) {
		vec3 n = vec3(t, sqrt(1.0 - r * r));
		float lat = asin(clamp(dot(n, pole), -1.0, 1.0));
		// n.x runs across the disc without the pole singularity a longitude would have.
		float swirl = fbm(vec2(n.x * 2.6 + time * 0.004, lat * 7.0), 3) / 0.875;
		float band = 0.5 + 0.5 * sin(lat * 14.0 + swirl * 2.5) + 0.12 * sin(lat * 41.0 + swirl * 5.0);
		vec3 surface = mix(planet_dark, planet_color, smoothstep(0.0, 0.5, band));
		surface = mix(surface, planet_light, smoothstep(0.55, 1.05, band) * 0.85) * 0.8;
		if (planet_storm > 0.0) {
			vec2 s = vec2((n.x + 0.38) / 0.17, (lat + 0.42) / 0.07);
			float s2 = dot(s, s);
			if (s2 < 6.0) {
				vec3 storm = mix(planet_light, vec3(0.7, 0.22, 0.08), 0.6) * 0.8;
				surface = mix(surface, storm, exp(-s2) * planet_storm);
				surface = mix(surface, planet_light * 0.8, exp(-pow(sqrt(s2) - 1.25, 2.0) * 5.0) * 0.45 * planet_storm);
			}
		}
		float lit = smoothstep(-0.15, 0.25, dot(n, sun));
		if (planet_ring > 0.0) {
			float facing = dot(sun, pole);
			float hit = -dot(n, pole) / (abs(facing) > 0.001 ? facing : 0.001);
			if (hit > 0.0) {
				vec3 h = n + sun * hit;
				lit *= 1.0 - 0.6 * ring_density(length(vec2(h.x, dot(h, ring_axis)))) * planet_ring;
			}
		}
		vec3 shade = surface * pow(n.z, 0.4) * (0.015 + 0.985 * lit);
		shade += planet_glow * pow(1.0 - n.z, 3.0) * lit * 0.2;
		colour = mix(colour, min(shade, vec3(0.85)), disc);
	}
	cover = max(cover, disc);
	if (r > 0.97 && r < 1.2) {
		float lit_side = smoothstep(-0.1, 0.7, dot(t / r, normalize(sun.xy)));
		float rim = exp(-max(r - 1.0, 0.0) / 0.02) * lit_side * (1.0 - disc);
		colour += planet_glow * rim * 0.45;
	}
	if (ring_alpha > 0.0 && ring_front) {
		colour = mix(colour, ring_colour, ring_alpha);
		cover = max(cover, ring_alpha);
	}
}

void moon_layer(vec2 pp, float aa_metres, vec3 sun, inout vec3 colour, inout float cover) {
	vec2 md = (pp - moon_position) / moon_radius;
	float r = length(md);
	if (r > 1.0) {
		return;
	}
	vec3 n = vec3(md, sqrt(max(0.0, 1.0 - r * r)));
	float lit = smoothstep(-0.08, 0.2, dot(n, sun));
	float maria = 0.75 + 0.25 * value_noise(md * 3.0 + 7.0);
	vec3 surface = vec3(0.3, 0.29, 0.28) * maria * pow(n.z, 0.3) * (0.01 + 0.99 * lit);
	float disc = 1.0 - smoothstep(1.0 - aa_metres / moon_radius, 1.0, r);
	colour = mix(colour, surface, disc);
	cover = max(cover, disc);
}

// Rocks are solid: rgb is the lit rock, a its coverage (it hides the stars behind it). Lit from `light_direction`, like
// the planet.
vec4 rock_layer(vec2 p, float cell, float density) {
	vec2 q = p / cell;
	vec2 id = floor(q);
	vec2 local = fract(q) - 0.5;
	if (hash21(id + 41.0) > density) {
		return vec4(0.0);
	}
	vec2 centre = (hash22(id + 11.3) - 0.5) * 0.4;
	vec2 d = local - centre;
	float radius = mix(0.06, 0.26, hash21(id + 2.2));
	float lumpy = length(d) + 0.5 * radius * (value_noise(d * 14.0 + id) - 0.5);
	float body = smoothstep(radius, radius * 0.85, lumpy);
	float lit = clamp(0.35 + dot(normalize(d + vec2(0.0001)), normalize(light_direction)) * 0.65 * smoothstep(0.0, radius, length(d)), 0.0, 1.0);
	return vec4(debris_color * (0.12 + lit * 1.3), body);
}

// The ship's own gantries: a long strut with cross ribs, as a dark silhouette with a pale edge, and a blinking nav light at
// each end. Returns the silhouette colour in rgb and its coverage in a; `lights` gets the additive nav lights.
vec4 structure_layer(vec2 p, float time, out vec3 lights) {
	lights = vec3(0.0);
	float cell = 20.0;
	vec2 q = p / cell;
	vec2 id = floor(q);
	if (hash21(id + 77.0) > hull_density) {
		return vec4(0.0);
	}
	vec2 local = (fract(q) - 0.5) * cell;
	float angle = (hash21(id + 3.3) - 0.5) * 0.9;
	vec2 rotated = vec2(cos(angle) * local.x + sin(angle) * local.y, -sin(angle) * local.x + cos(angle) * local.y);
	float half_length = mix(4.0, 7.5, hash21(id + 5.5));
	float strut = box_distance(rotated, vec2(half_length, 0.3));
	vec2 rib_p = vec2(mod(rotated.x + 0.9, 1.8) - 0.9, rotated.y);
	float ribs = max(box_distance(rib_p, vec2(0.1, 1.3)), abs(rotated.x) - half_length);
	float sd = min(strut, ribs);
	float body = 1.0 - smoothstep(0.0, 0.05, sd);
	float edge = (1.0 - smoothstep(0.0, 0.14, abs(sd + 0.04))) * 0.5;
	vec3 colour = vec3(0.025, 0.035, 0.055) + vec3(0.07, 0.1, 0.16) * edge;
	float blink = step(0.7, sin(time * 3.0 + hash21(id) * 6.28));
	for (int end = 0; end < 2; end++) {
		float side = end == 0 ? -1.0 : 1.0;
		float light = exp(-pow(length(rotated - vec2(side * half_length, 0.0)) / 0.18, 2.0));
		lights += (end == 0 ? vec3(1.0, 0.15, 0.1) : vec3(0.1, 1.0, 0.3)) * light * (0.4 + 1.6 * blink);
	}
	return vec4(colour, body);
}

void vertex() {
	plane_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 camera_xz = INV_VIEW_MATRIX[3].xz;
	vec2 world_xz = plane_position.xz;
	float time = TIME;
	// Screen pixels per plane metre (the camera is orthographic, so this is constant over the plane). Derivatives are taken
	// here, outside any branch.
	vec2 dx = dFdx(world_xz);
	vec2 dy = dFdy(world_xz);
	mat2 to_px = inverse(mat2(dx, dy));
	float pixel_metres = 0.5 * (length(dx) + length(dy));

	vec3 colour = base_color;
	// Dust (nebula lanes, the Milky Way's dark rift) dims what lies behind it: the far stars and the star dust.
	float lane = 1.0;
	float band_glow = 0.0;

	// Milky Way: a soft band of unresolved stars with a dark rift wandering down it. It does not scroll (it would leave
	// the view); only its mottling does.
	if (band_amount > 0.0) {
		vec2 bp = world_xz - camera_xz * 0.95;
		vec2 rel = bp - vec2(0.0, ROOM_ON_PLANE.y - CAMERA_BACK * 0.95);
		float angle = radians(band_angle);
		vec2 along_dir = vec2(cos(angle), sin(angle));
		float along = dot(rel, along_dir);
		float across = dot(rel, vec2(-along_dir.y, along_dir.x));
		float mottle = fbm(bp * 0.12 + drift * time * 0.01, 2) / 0.75;
		float wander = (value_noise(vec2(along * 0.12, 3.0)) - 0.5) * 3.0;
		band_glow = exp(-pow((across + wander * 0.6) / 5.5, 2.0));
		float rift = exp(-pow((across - 0.6 + wander) / 1.4, 2.0)) * smoothstep(0.25, 0.6, mottle) * band_glow;
		float clumps = 0.6 + 0.4 * value_noise(bp * 0.6);
		colour += band_color * band_amount * 0.08 * band_glow * (0.12 + 1.4 * mottle * mottle * clumps) * (1.0 - 0.85 * rift);
		lane *= 1.0 - 0.7 * rift * band_amount;
	}

	// Nebula: domain-warped noise mapped through a density ramp, kept to a few octaves (it covers the whole screen).
	if (nebula_amount > 0.01) {
		vec2 far_p = (world_xz - camera_xz * 0.9 + drift * time * 0.1) * nebula_scale;
		vec2 warp = vec2(fbm(far_p * 0.6, 2), fbm(far_p * 0.6 + vec2(5.2, 1.3), 2)) - 0.375;
		float cloud = fbm(far_p + warp * 2.0, 3);
		float density = smoothstep(0.28, 0.82, cloud);
		density *= density;
		vec3 tint = mix(nebula_a, nebula_b, smoothstep(0.05, 0.5, density));
		tint = mix(tint, nebula_core, smoothstep(0.55, 1.1, density));
		vec3 gas = tint * density * nebula_amount;
		// Ridged filaments: thin bright threads along the gas, broken up by the cloud itself.
		if (nebula_filaments > 0.0) {
			float n = fbm(far_p * 4.5 + warp * 5.0 + vec2(3.1, 8.4), 2) / 0.75;
			float ridge = pow(1.0 - abs(2.0 * n - 1.0), 12.0) * smoothstep(0.02, 0.35, density) * smoothstep(0.3, 0.6, cloud + 0.1);
			gas += mix(nebula_b, nebula_core, 0.6) * ridge * nebula_filaments * nebula_amount;
		}
		if (dust_lanes > 0.0) {
			float d = fbm(far_p * 1.4 + warp * 1.5 + vec2(11.0, 3.0), 2) / 0.75;
			float dim = 1.0 - dust_lanes * 0.6 * smoothstep(0.55, 0.7, d);
			gas *= dim;
			lane *= dim;
		}
		colour += gas;
	}

	if (galaxy_amount > 0.0) {
		colour += galaxy_layer(world_xz - camera_xz * 0.93 + drift * time * 0.07) * lane;
	}

	// Engines: a soft glow behind the ship, opposite the heading.
	if (engine_amount > 0.0) {
		vec2 heading = normalize(drift + vec2(0.0001));
		float behind = dot(world_xz - camera_xz, -heading);
		colour += engine_color * engine_amount * smoothstep(-4.0, 22.0, behind) * (0.8 + 0.2 * sin(time * 9.0));
	}

	// Stars behind the planet layer: dust and the two far layers.
	vec3 stars = vec3(0.0);
	if (star_dust > 0.0) {
		stars += dust_layer(world_xz - camera_xz * 0.9 + drift * time * 0.1, to_px, 1.0 + 3.5 * band_glow * band_amount);
	}
	stars += star_layer(world_xz - camera_xz * 0.85 + drift * time * 0.15, 1.1, star_density, star_brightness * 0.8, 0.6, to_px, time);
	stars *= lane;
	stars += star_layer(world_xz - camera_xz * 0.6 + drift * time * 0.4, 1.8, star_density * 0.7, star_brightness * 0.9, 1.4, to_px, time);

	// Planet and moon hide the stars behind them. They hold still (a drift would carry them out of view in a long run).
	float cover = 0.0;
	if (planet_radius > 0.0 || moon_radius > 0.0) {
		vec2 planet_p = world_xz - camera_xz * 0.88;
		vec3 sun = normalize(vec3(normalize(light_direction), 0.55));
		if (planet_radius > 0.0) {
			planet_layer(planet_p, pixel_metres * 1.5 / planet_radius, time, sun, colour, cover);
		}
		if (moon_radius > 0.0) {
			moon_layer(planet_p, pixel_metres * 1.5, sun, colour, cover);
		}
	}
	colour += stars * (1.0 - cover);

	// The ship's own structure passes between the far and near stars.
	if (hull_density > 0.0) {
		vec3 lights;
		vec4 structure = structure_layer(world_xz - camera_xz * 0.5 + drift * time * 0.5, time, lights);
		colour = mix(colour, structure.rgb, structure.a) + lights;
	}

	colour += star_layer(world_xz - camera_xz * 0.25 + drift * time * 0.8, 3.0, star_density * 0.45, star_brightness, 3.0, to_px, time) * (1.0 - cover);

	// Debris close to the hull: dark rocks sliding past.
	if (debris_density > 0.0) {
		vec4 rock = rock_layer(world_xz - camera_xz * 0.05 + drift * time * 1.6, 7.0, debris_density);
		colour = mix(colour, rock.rgb, rock.a);
	}

	// A soft shadow of the hull around the room's outline on the plane.
	if (hull_shadow > 0.0) {
		float outside = max(box_distance(world_xz - ROOM_SILHOUETTE_CENTRE, ROOM_SILHOUETTE_HALF), 0.0);
		colour *= 1.0 - hull_shadow * (1.0 - smoothstep(0.0, 2.5, outside));
	}

	ALBEDO = colour;
}

shader_type spatial;
render_mode cull_disabled;

// Riveted hull plating for the arena room's walls and the ship outside, drawn in world space so every face tiles evenly whatever
// its size. A small height field (bevelled seams, rivet domes, recessed inset panels, louvre vents, weld beads) is differentiated
// into a normal, so the plating catches the light. The motif follows the floor theme: plates, hex cells, planks or frosted plates.
// Decks (up-facing surfaces below the floor, i.e. the ship's own decks) get much larger panels, a slow tone drift and long weld
// lines, since they are seen from far away; some panels carry paint in the theme's accent colour and a few a stencilled arrow.
// ArenaRoom sets the uniforms per theme (WorldGeometry.HULL_COLORS and HULL_MOTIFS).

uniform vec3 base_color : source_color = vec3(0.14, 0.2, 0.23);
uniform vec3 seam_color : source_color = vec3(0.02, 0.03, 0.04);
/// Bare steel showing where the paint has chipped along the edges.
uniform vec3 wear_color : source_color = vec3(0.5, 0.52, 0.56);
/// Enamel for painted panels and stencils (WorldGeometry.HULL_MOTIFS accent).
uniform vec3 accent_color : source_color = vec3(0.18, 0.6, 0.6);
uniform vec2 panel_size = vec2(1.2, 0.6);
/// 0 plates, 1 hex cells (panel_size.x is the cell width), 2 planks, 3 frosted plates.
uniform int motif = 0;
uniform float metal = 0.35;
uniform float relief = 1.0;
uniform float grime = 0.25;

varying vec3 world_position;
varying vec3 world_normal;

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

// How much larger decks' panels are than the walls' for each motif (hex cells stay smaller than plates: a 1.2 m hex is already big).
float deck_scale() {
	if (motif == 1) {
		return 2.6;
	}
	return motif == 2 ? 2.0 : 3.0;
}

// Distance (metres) to the nearest weld line on a deck: butt welds across every 3 m and longer runs every 6 m.
float weld_distance(vec2 p) {
	vec2 d = abs(fract(p / vec2(6.0, 3.0) + 0.5) - 0.5) * vec2(6.0, 3.0);
	return min(d.x, d.y);
}

// Splits the plane into panels: distance to the nearest seam (metres), a panel id, and the position inside the panel.
void layout(vec2 p, vec2 size, out float edge, out vec2 id, out vec2 local_m) {
	if (motif == 1) {
		vec2 q = p / size.x;
		const vec2 r = vec2(1.0, 1.7320508);
		vec2 h = r * 0.5;
		vec2 a = mod(q, r) - h;
		vec2 b = mod(q - h, r) - h;
		vec2 gv = dot(a, a) < dot(b, b) ? a : b;
		id = floor((q - gv) * 4.0);
		float c = max(dot(abs(gv), normalize(vec2(1.0, 1.7320508))), abs(gv.x));
		edge = (0.5 - c) * size.x;
		local_m = gv * size.x;
	} else {
		vec2 cell = p / size;
		float row = floor(cell.y);
		cell.x += motif == 2 ? hash21(vec2(row, 3.0)) : mod(row, 2.0) * 0.5;
		id = floor(cell);
		vec2 local = fract(cell);
		local_m = (local - 0.5) * size;
		vec2 e = min(local, 1.0 - local) * size;
		edge = min(e.x, e.y);
	}
}

// Surface height in metres: bevelled panels, inset panels with louvres, rivet domes, and weld beads on decks.
float height_at(vec2 p, vec2 size, bool deck) {
	float edge;
	vec2 id;
	vec2 local_m;
	layout(p, size, edge, id, local_m);
	float panel_hash = hash21(id + 7.0);
	float h = 0.012 * smoothstep(0.0, 0.045, edge);
	float inset = smoothstep(0.11, 0.13, edge) * step(0.7, panel_hash);
	h -= 0.02 * inset;
	h += 0.012 * inset * step(0.9, panel_hash) * (0.5 + 0.5 * sin(local_m.y * 45.0));
	float rivet_distance;
	if (motif == 1) {
		rivet_distance = step(panel_hash, 0.5) > 0.5 ? 1.0 : length(local_m) * 2.0;
	} else if (motif == 2) {
		rivet_distance = 1.0;
		h += 0.003 * (value_noise(vec2(p.x * 3.0, p.y * 70.0)) - 0.5);
	} else {
		rivet_distance = length(abs(local_m) - (size * 0.5 - vec2(0.09)));
	}
	h += 0.016 * (1.0 - smoothstep(0.0, 0.03, rivet_distance));
	if (deck) {
		h += 0.007 * (1.0 - smoothstep(0.006, 0.03, weld_distance(p)));
	}
	return h;
}

// Equilateral triangle pointing up, circumradius `r`, centred on its circumcentre.
float triangle_distance(vec2 p, float r) {
	const float k = 1.7320508;
	vec2 q = vec2(abs(p.x) - r, p.y + r / k);
	if (q.x + k * q.y > 0.0) {
		q = vec2(q.x - k * q.y, -k * q.x - q.y) * 0.5;
	}
	q.x -= clamp(q.x, -2.0 * r, 0.0);
	return -length(q) * sign(q.y);
}

// Signed distance (metres, unit scale `s`) of a stencilled marking centred on a panel: 0 a double chevron, 1 an up arrow,
// 2 a warning triangle outline.
float stencil_distance(vec2 p, float s, int kind) {
	p /= s;
	float d;
	if (kind == 0) {
		float a = max(triangle_distance(p - vec2(0.0, 0.28), 0.9), -triangle_distance(p - vec2(0.0, 0.05), 0.9));
		float b = max(triangle_distance(p + vec2(0.0, 0.42), 0.9), -triangle_distance(p + vec2(0.0, 0.65), 0.9));
		d = min(a, b);
	} else if (kind == 1) {
		float head = triangle_distance(p - vec2(0.0, 0.5), 0.75);
		vec2 bar = abs(p - vec2(0.0, -0.45)) - vec2(0.2, 0.55);
		d = min(head, max(bar.x, bar.y));
	} else {
		d = abs(triangle_distance(p, 0.95)) - 0.11;
	}
	return d * s;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 geometric = normalize(world_normal);
	vec3 n = abs(geometric);
	vec2 plane;
	vec3 tangent_u;
	vec3 tangent_v;
	if (n.y > n.x && n.y > n.z) {
		plane = world_position.xz;
		tangent_u = vec3(1.0, 0.0, 0.0);
		tangent_v = vec3(0.0, 0.0, 1.0);
	} else if (n.x > n.z) {
		plane = world_position.zy;
		tangent_u = vec3(0.0, 0.0, 1.0);
		tangent_v = vec3(0.0, 1.0, 0.0);
	} else {
		plane = world_position.xy;
		tangent_u = vec3(1.0, 0.0, 0.0);
		tangent_v = vec3(0.0, 1.0, 0.0);
	}
	// The ship's decks are seen from far away: big panels, weld lines. The big front hull gets larger panels too, so the field
	// does not read as brickwork.
	bool deck = geometric.y > 0.7 && world_position.y < -0.5;
	vec2 size = panel_size;
	if (deck) {
		size *= deck_scale();
	} else if (world_position.z > 0.0 && world_position.y < 0.4 && motif != 1) {
		size *= 2.0;
	}

	float edge;
	vec2 id;
	vec2 local_m;
	layout(plane, size, edge, id, local_m);
	float panel_hash = hash21(id + 7.0);

	// Bump normal from the height field's slope, built in world space and sent to view space.
	float eps = 0.004;
	float h0 = height_at(plane, size, deck);
	vec2 slope = vec2(height_at(plane + vec2(eps, 0.0), size, deck) - h0, height_at(plane + vec2(0.0, eps), size, deck) - h0) / eps * relief;
	vec3 tu = normalize(tangent_u - geometric * dot(geometric, tangent_u));
	vec3 tv = normalize(tangent_v - geometric * dot(geometric, tangent_v));
	vec3 bumped = normalize(geometric - slope.x * tu - slope.y * tv);
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);

	// Each panel has its own tone; a slow drift across the whole surface breaks up the repeat, more so on decks.
	float drift = value_noise(plane * 0.35) * 2.0 - 1.0;
	float tone = (0.9 + 0.2 * hash21(id + 1.7)) * (1.0 + (deck ? 0.12 : 0.06) * drift);
	vec3 colour = base_color * tone;
	float rough = mix(0.68, 0.9, hash21(id + 4.1));
	float metallic = metal * mix(0.7, 1.3, hash21(id + 9.3));

	// Painted panels: one in eight carries faded enamel in the theme's accent colour, and a few a stencilled marking.
	float painted = step(0.88, hash21(id + 3.3));
	// Planks are inlaid with lighter wood instead (brighter, not scuffed).
	vec3 enamel = accent_color * (motif == 2 ? 0.5 : 0.3) * (0.85 + 0.3 * hash21(id + 6.1));
	// The paint is scuffed, so the plate's own colour shows through in patches.
	enamel = mix(enamel, colour * 0.9, motif == 2 ? 0.0 : 0.55 * step(0.7, value_noise(plane * 5.0)));
	colour = mix(colour, enamel, painted);
	rough = mix(rough, 0.55, painted);
	metallic = mix(metallic, 0.05, painted);
	// Stencils need a panel big enough to read (not hex cells, planks or small tiles).
	if (hash21(id + 5.5) > 0.96 && min(size.x, size.y) >= 0.5) {
		vec2 sp = local_m;
		sp.y = deck ? -sp.y : sp.y; // up the screen on a deck is -z
		float sd = stencil_distance(sp, min(size.x, size.y) * 0.3, int(hash21(id + 8.8) * 2.999));
		float mark = 1.0 - smoothstep(-0.004, 0.004, sd);
		mark *= 1.0 - 0.45 * step(0.68, value_noise(plane * 11.0)); // worn paint: patchy, never crisp all over
		colour = mix(colour, mix(accent_color, vec3(0.55), 0.55) * 0.5, mark * 0.9);
		rough = mix(rough, 0.6, mark);
		metallic = mix(metallic, 0.02, mark);
	}

	float seam = 1.0 - smoothstep(0.008, 0.03, edge);
	colour = mix(colour, seam_color, seam * 0.85);
	// Grime pools near the base of the wall and the hull below the floor.
	colour *= mix(0.72, 1.0, smoothstep(-0.5, 0.9, world_position.y));
	// The bevel around each panel is polished by wear, so it catches a thin highlight.
	float bevel = smoothstep(0.004, 0.015, edge) * (1.0 - smoothstep(0.025, 0.05, edge));
	rough = mix(rough, 0.45, bevel);

	// Rust and dirt run down from the panel edges and fittings, and settle in the seams.
	float streaks = value_noise(vec2(plane.x * 6.0, plane.y * 0.4)) * smoothstep(0.35, 1.0, 1.0 - fract(plane.y * 0.5 + hash21(id) * 0.3));
	colour = mix(colour, colour * vec3(0.62, 0.48, 0.4), streaks * grime * 1.6);
	colour *= 1.0 - grime * 0.8 * (1.0 - smoothstep(0.0, 0.05, edge)) * 0.5;
	// Weld beads on decks: heat-darkened, slightly lighter metal along the bead.
	if (deck) {
		float weld = 1.0 - smoothstep(0.008, 0.03, weld_distance(plane));
		colour = mix(colour, colour * vec3(0.62, 0.58, 0.55) + vec3(0.01), weld * 0.7);
		rough = mix(rough, 0.5, weld);
		metallic = mix(metallic, 0.6, weld);
	}
	// Edge wear: bare steel showing through where the paint is chipped, only along the worst-hit edges.
	float wear = step(0.72, value_noise(plane * 9.0)) * (1.0 - smoothstep(0.0, 0.035, edge));
	colour = mix(colour, wear_color, wear * 0.85);
	rough = mix(rough, 0.4, wear);
	metallic = mix(metallic, 0.85, wear);
	// Cavities (insets, seams, the dips round rivets) hold dirt and sit in their own shadow.
	colour *= 0.85 + 0.15 * smoothstep(-0.02, 0.012, h0);

	if (motif == 3) {
		float rime = smoothstep(0.3, 0.6, geometric.y) + (1.0 - smoothstep(0.0, 0.6, abs(world_position.y))) * value_noise(plane * 6.0);
		rime = clamp(rime, 0.0, 1.0);
		colour = mix(colour, vec3(0.55, 0.75, 0.82) * 0.6, rime * 0.7);
		rough = mix(rough, 0.35, rime);
	}

	ALBEDO = colour;
	ROUGHNESS = rough;
	METALLIC = clamp(metallic, 0.0, 1.0);
}

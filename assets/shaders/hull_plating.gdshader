shader_type spatial;
render_mode cull_disabled;

// Riveted hull plating for the arena room's walls, drawn in world space so every face tiles evenly whatever its size.
// A small height field (bevelled seams, rivet domes, recessed inset panels, louvre vents) is differentiated into a normal,
// so the plating catches the light. The motif follows the floor theme: plates, hex cells, planks or frosted plates.
// ArenaRoom sets the uniforms per theme (WorldGeometry.HULL_MOTIFS).

uniform vec3 base_color : source_color = vec3(0.14, 0.2, 0.23);
uniform vec3 seam_color : source_color = vec3(0.02, 0.03, 0.04);
uniform vec3 wear_color : source_color = vec3(0.66, 0.54, 0.33);
uniform vec2 panel_size = vec2(1.2, 0.6);
/// 0 plates, 1 hex cells (panel_size.x is the cell width), 2 planks, 3 frosted plates.
uniform int motif = 0;
uniform float metal = 0.35;
uniform float relief = 1.0;

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

// Surface height in metres: bevelled panels, inset panels with louvres, rivet domes.
float height_at(vec2 p, vec2 size) {
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
	return h;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
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
	// The big front hull gets larger panels so the field does not read as brickwork.
	vec2 size = panel_size * (world_position.z > 0.0 && world_position.y < 0.4 && motif != 1 ? 2.0 : 1.0);

	float edge;
	vec2 id;
	vec2 local_m;
	layout(plane, size, edge, id, local_m);
	float panel_hash = hash21(id + 7.0);

	// Bump normal from the height field's slope, built in world space and sent to view space.
	float eps = 0.004;
	float h0 = height_at(plane, size);
	vec2 slope = vec2(height_at(plane + vec2(eps, 0.0), size) - h0, height_at(plane + vec2(0.0, eps), size) - h0) / eps * relief;
	vec3 geometric = normalize(world_normal);
	vec3 tu = normalize(tangent_u - geometric * dot(geometric, tangent_u));
	vec3 tv = normalize(tangent_v - geometric * dot(geometric, tangent_v));
	vec3 bumped = normalize(geometric - slope.x * tu - slope.y * tv);
	NORMAL = normalize((VIEW_MATRIX * vec4(bumped, 0.0)).xyz);

	float tone = 0.9 + 0.2 * hash21(id + 1.7);
	vec3 colour = base_color * tone;
	float seam = 1.0 - smoothstep(0.008, 0.03, edge);
	colour = mix(colour, seam_color, seam * 0.85);
	// Grime pools near the base of the wall and the hull below the floor.
	colour *= mix(0.72, 1.0, smoothstep(-0.5, 0.9, world_position.y));
	float rough = mix(0.68, 0.9, hash21(id + 4.1));
	float metallic = metal * mix(0.7, 1.3, hash21(id + 9.3));

	// Edge wear: brass showing through where the seams are chipped.
	float wear = step(0.55, value_noise(plane * 9.0)) * (1.0 - smoothstep(0.0, 0.06, edge));
	colour = mix(colour, wear_color, wear * 0.8);
	rough = mix(rough, 0.4, wear);
	metallic = mix(metallic, 0.8, wear);

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

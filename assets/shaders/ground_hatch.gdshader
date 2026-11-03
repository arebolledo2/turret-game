shader_type spatial;
// A floor hatch: the floor itself splits along a jagged seam and its two halves slide apart under the surrounding floor, uncovering a
// pit lit from below. One quad per hatch, lying on the floor (see GroundHatch); the quad is EXTENT hatch radii across each way.
//
// The plates are not a separate texture. They redraw the arena floor's own maps (albedo, normal, roughness, emission) in world space,
// the way the floor material reads them, displaced by how far each half has slid, and the quad shares the floor's render layers so
// the stain and scorch decals darken them too. Lit by the stage lights like the floor, a closed hatch matches the floor around it
// and the plates carry the theme's texture as they move. The finish pass (tone drift and wall occlusion) is the one thing not redrawn.
//
// The pit has real depth: a ray from the ortho camera (it looks 52.6 degrees down, from the south) enters the opening and either hits
// the far wall, which then reads as a lit band, or reaches the bottom. The opening is solved here by marching that ray over the
// outline, so the look is the same however the hatch is rotated. All motion is a function of `state`, so a paused game freezes it.
//
// instance uniform `state`: x open (0 shut .. 1 fully open), y fade-in, z age in seconds, w slam (1 on the last frame the plates meet,
// falling to 0). `calm` is 1 under reduced motion: no flicker, shake or drifting dust.
render_mode blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

const float EXTENT = 1.5; // quad half-size in hatch radii; keep equal to GroundHatch.EXTENT
const float HALF_U = 0.86; // the outline's half extent along the slide axis and along the seam, in hatch radii
const float HALF_V = 0.78;
const float CHAMFER = 1.3; // |u| + |v| at the cut corners
const float TRAVEL = 1.0; // how far each half slides at full open (past the outline, so the halves vanish under the floor)
const float PIT_REACH = 0.24; // how far up the screen a ray travels while it falls the pit's depth, in hatch radii

instance uniform vec4 state = vec4(0.0, 1.0, 0.0, 0.0);
instance uniform float calm = 0.0;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform sampler2D emission_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float gain = 2.5; // the floor's albedo lift (WorldGeometry.FLOOR_ALBEDO_GAIN)
uniform float metallic = 0.3;
uniform float emission_energy = 0.9;
uniform vec3 emission_tint : source_color = vec3(1.0); // the floor's per-wave seam tint
uniform vec2 floor_half = vec2(13.3, 9.5); // half the floor plane in metres
uniform float tile_metres = 6.4;
uniform vec3 glow_color : source_color = vec3(0.96, 0.66, 0.4);

varying vec3 world_pos;
varying vec3 hatch_centre;
varying float hatch_radius;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	hatch_centre = MODEL_MATRIX[3].xyz;
	hatch_radius = length(MODEL_MATRIX[0].xyz) / EXTENT;
}

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * 0.1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x), mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float tri(float x) {
	return abs(fract(x) * 2.0 - 1.0);
}

// The split line: u as a function of v, jagged like a fracture.
float seam_u(float v, float sd) {
	return (tri(v * 1.7 + sd * 5.0) - 0.5) * 0.15 + (tri(v * 5.1 + sd * 11.0) - 0.5) * 0.05;
}

// Signed distance (about) to the hatch outline, negative inside: a cut-cornered rectangle with a ragged edge.
float outline_d(vec2 q, float sd) {
	vec2 a = abs(q);
	float d = max(max(a.x - HALF_U, a.y - HALF_V), (a.x + a.y - CHAMFER) * 0.7071);
	return d + (value_noise(q * 3.1 + sd * 19.0) - 0.5) * 0.07;
}

// Distance from the seam band's edge: negative in the gap the halves have left open.
float gap_d(vec2 q, float half_gap, float sd) {
	return abs(q.x - seam_u(q.y, sd)) - half_gap;
}

float hole_d(vec2 q, float half_gap, float sd) {
	return max(outline_d(q, sd), gap_d(q, half_gap, sd));
}

// Follows the view ray from floor point q: 1 when it reaches the pit's bottom, otherwise how far down the pit (0 lip .. 1) it meets a wall.
float pit_depth(vec2 q, vec2 away, float half_gap, float sd) {
	if (hole_d(q + away * PIT_REACH, half_gap, sd) < 0.0) {
		return 1.0;
	}
	float lo = 0.0;
	float hi = 1.0;
	for (int i = 0; i < 6; i++) {
		float mid = 0.5 * (lo + hi);
		if (hole_d(q + away * (PIT_REACH * mid), half_gap, sd) < 0.0) {
			lo = mid;
		} else {
			hi = mid;
		}
	}
	return hi;
}

// Composites a layer (albedo, emission, coverage) over the accumulated premultiplied colour.
void over(inout vec3 acc_alb, inout vec3 acc_emi, inout float cover, vec3 alb, vec3 emi, float alpha) {
	acc_alb = acc_alb * (1.0 - alpha) + alb * alpha;
	acc_emi = acc_emi * (1.0 - alpha) + emi * alpha;
	cover = cover + alpha * (1.0 - cover);
}

void fragment() {
	float open = state.x;
	float fade = state.y;
	float age = state.z;
	float slam = state.w;
	float live = 1.0 - calm;
	if ((open <= 0.0 && slam <= 0.0) || fade <= 0.0) {
		discard;
	}

	float radius = hatch_radius;
	vec2 p = (world_pos.xz - hatch_centre.xz) / radius;
	float sd = hash21(floor(hatch_centre.xz * 8.0 + 0.5)); // per-hatch variation from where it is: no random stream involved
	float angle = sd * 3.14159;
	vec2 ax = vec2(cos(angle), sin(angle)); // slide axis, in the floor plane
	vec2 ay = vec2(-ax.y, ax.x); // along the seam
	vec2 q = vec2(dot(p, ax), dot(p, ay));
	vec2 away = vec2(dot(vec2(0.0, -1.0), ax), dot(vec2(0.0, -1.0), ay)); // up the screen, in hatch space

	float crack = smoothstep(0.0, 0.06, open);
	float slide = TRAVEL * open;
	float half_gap = slide + 0.012 * crack;
	float aa = max(fwidth(q.x) + fwidth(q.y), 0.002);
	float pulse = 1.0 - 0.14 * live * (0.5 + 0.5 * sin(age * 17.0));
	float lit = smoothstep(0.0, 0.25, open) * pulse;

	float out_d = outline_d(q, sd);
	float gap = gap_d(q, half_gap, sd);
	float hd = max(out_d, gap);
	float in_outline = 1.0 - smoothstep(-aa, aa, out_d);
	float in_hole = 1.0 - smoothstep(-aa, aa, hd);
	float plate_cover = max(in_outline - in_hole, 0.0);

	vec3 acc_alb = vec3(0.0);
	vec3 acc_emi = vec3(0.0);
	float cover = 0.0;

	// Light spilling out of the opening onto the floor around it.
	float spill = lit * 0.12 * exp(-max(out_d, 0.0) * 9.0) * (1.0 - in_outline) * smoothstep(0.0, 0.2, open);
	over(acc_alb, acc_emi, cover, vec3(0.0), glow_color * 0.8, spill);

	// The plates: the floor's own maps, slid. The half that lies on the low side of the seam has moved towards -u.
	float side = q.x < seam_u(q.y, sd) ? 1.0 : -1.0;
	float strain = 4.0 * open * (1.0 - open); // the plates grind most while they are moving
	vec2 shake = vec2(sin(age * 83.0), cos(age * 67.0)) * (0.006 * live * strain);
	vec2 source = world_pos.xz + radius * (ax * (slide * side) + shake);
	vec2 uv = (source + floor_half) / tile_metres;
	vec3 floor_alb = texture(albedo_tex, uv).rgb * gain;
	vec3 floor_nrm = texture(normal_tex, uv).rgb;
	float floor_rough = texture(rough_tex, uv).r;
	vec3 floor_emi = texture(emission_tex, uv).rgb * emission_tint * emission_energy;

	float edge = max(gap, 0.0); // how far into the plate from the gap's edge
	float bevel = 1.0 - smoothstep(0.012, 0.04, edge);
	float groove = 1.0 - smoothstep(0.0, 0.01 + aa, edge);
	float ember = (exp(-edge * 14.0) * 0.5 + exp(-edge * 60.0) * 0.8) * smoothstep(0.0, 0.1, open) * pulse;
	vec3 plate_alb = floor_alb * (1.0 - 0.9 * groove) + vec3(0.05) * bevel;
	vec3 plate_emi = floor_emi + glow_color * ember * 0.6 + glow_color * bevel * 0.12 * crack;
	float tail = open > 0.0 ? 1.0 : smoothstep(0.0, 0.6, slam); // once shut, the redrawn floor melts into the real one
	float plate_a = plate_cover * tail;
	over(acc_alb, acc_emi, cover, plate_alb, plate_emi, plate_a);

	// The pit: walls when the ray meets one, otherwise the glowing bottom.
	if (in_hole > 0.0) {
		float depth = pit_depth(q, away, half_gap, sd);
		float centre = exp(-dot(q, q) * 3.0);
		float mottle = 0.8 + 0.4 * value_noise(q * 6.0 + vec2(0.0, age * 0.7 * live));
		float bottom = (0.004 + 0.4 * centre * centre) * mottle;
		float wall = bottom * pow(depth, 2.4);
		vec3 pit_emi = glow_color * wall * lit;
		vec3 pit_alb = vec3(0.04, 0.036, 0.036) * pow(1.0 - depth, 1.6) + vec3(0.004); // walls catch the stage light near the lip
		over(acc_alb, acc_emi, cover, pit_alb, pit_emi, in_hole);
	}

	// The outline: a hairline fracture that glows while the hatch works, flaring as it slams shut.
	float line = (1.0 - smoothstep(0.0, 0.008 + aa, abs(out_d))) * crack;
	float breakup = 0.4 + 0.6 * value_noise(q * 9.0 + sd * 31.0);
	float flare = 0.2 + 1.6 * slam * slam;
	over(acc_alb, acc_emi, cover, vec3(0.0), glow_color * (breakup * flare * pulse), line * 0.9);

	// The seam's own flash when the halves meet.
	float seam_line = (1.0 - smoothstep(0.0, 0.05, abs(q.x - seam_u(q.y, sd)))) * in_outline;
	float hit = slam * slam;
	over(acc_alb, acc_emi, cover, vec3(0.0), mix(glow_color, vec3(1.0, 0.92, 0.8), 0.6) * 2.0, seam_line * hit);

	// Dust: shaken off the plates while they grind, a burst when they slam, a thin steam while the pit stands open.
	float amount = 0.18 * smoothstep(0.6, 1.0, open) + 2.2 * strain * 0.5 + 1.1 * slam;
	vec2 drift = vec2(0.0, -age * 0.35 * live);
	float billow = value_noise(p * 2.4 + drift + sd * 17.0) * 0.65 + value_noise(p * 5.3 + drift * 1.7 + sd * 5.0) * 0.35;
	float near = exp(-max(hd, 0.0) * 3.5) * (1.0 - smoothstep(0.25, 0.6, max(out_d, 0.0))); // hugs the opening, gone well before the quad's edge
	float dust = clamp(amount, 0.0, 1.0) * smoothstep(0.38, 0.85, billow) * near * 0.5 * (1.0 - 0.8 * in_hole);
	over(acc_alb, acc_emi, cover, vec3(0.3, 0.27, 0.24), glow_color * 0.1, dust);

	if (cover < 0.002) {
		discard;
	}
	ALBEDO = acc_alb / cover;
	EMISSION = acc_emi / cover;
	ALPHA = cover * fade;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), floor_nrm, plate_a);
	ROUGHNESS = mix(1.0, floor_rough, plate_a);
	METALLIC = metallic * plate_a;
}

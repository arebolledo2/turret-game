shader_type spatial;
// Floor finish, drawn as the next_pass of the arena floor material (WorldGeometry.floor_material) in a single alpha-blended
// pass over the lit floor. It breaks up the 6.4 m texture repeat and the flat dark field with: a large-scale tone drift between two
// theme colours, anisotropic scuffs, a worn painted dash line along the walls, a faint spill of the rim light and the occlusion where
// the walls meet the floor. Everything is analytic in world space (no textures), measured from the arena bounds `half_arena`.
// The layers are composited "over" each other into one premultiplied colour, so a single blend_mix pass gives
// result = floor * (1 - cover) + colour.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec2 half_arena = vec2(12.7, 8.93); // playfield half extents; the walls rise just outside
uniform vec3 tint_a : source_color = vec3(0.1, 0.35, 0.45); // cool end of the tone drift
uniform vec3 tint_b : source_color = vec3(0.5, 0.4, 0.25); // warm end of the tone drift
uniform vec3 accent : source_color = vec3(0.2, 0.6, 0.6); // the painted dash line
uniform vec3 rim_color : source_color = vec3(0.1, 0.5, 0.6); // spill of the floor rim light

uniform float level = 0.05; // linear luminance of the lit floor; tone and scuffs are scaled relative to it
uniform float tone_strength = 0.24; // peak coverage of the tone drift
uniform float tone_scale = 9.0; // metres per feature of the large drift (a second octave runs at 0.29 of it)
uniform float scuff_strength = 0.16;
uniform float scuff_level = 2.4; // scuff luminance as a multiple of `level`
uniform float line_strength = 0.4;
uniform float line_offset = 0.5; // metres from the arena bounds to the centre of the dash line
uniform float line_width = 0.08;
uniform float dash_period = 1.0;
uniform float dash_fill = 0.62; // fraction of each period that is painted
uniform float paint_level = 0.2; // linear luminance of the paint
uniform float spill_strength = 0.14;
uniform float spill_reach = 0.8;
uniform float spill_level = 0.16; // linear luminance of the spill
uniform vec3 ao_strength = vec3(0.4, 0.6, 0.3); // darkening at the foot of the side, back (north) and front (south) walls
uniform float ao_reach = 1.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int octave = 0; octave < 3; octave++) {
		value += amplitude * value_noise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		amplitude *= 0.5;
	}
	return value / 0.875;
}

vec3 at_level(vec3 colour, float luminance) {
	return colour * (luminance / max(dot(colour, vec3(0.2126, 0.7152, 0.0722)), 0.0005));
}

// Adds a layer of `colour` with coverage `alpha` on top of the accumulated premultiplied colour and coverage.
void over(inout vec3 premultiplied, inout float cover, vec3 colour, float alpha) {
	premultiplied = premultiplied * (1.0 - alpha) + colour * alpha;
	cover = cover + alpha * (1.0 - cover);
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 acc = vec3(0.0);
	float cover = 0.0;

	// Large-scale tone drift: dark cool patches and light warm patches whose scale differs from the 6.4 m texture repeat.
	float drift = fbm(p / tone_scale + vec2(3.7, 1.3)) * 0.6 + fbm(p / (tone_scale * 0.29) + vec2(11.1, 4.9)) * 0.4;
	drift = clamp((drift - 0.5) * 2.8 + 0.5, 0.0, 1.0);
	vec3 tone = at_level(mix(tint_a, tint_b, smoothstep(0.2, 0.8, drift)), level * mix(0.35, 1.8, drift));
	over(acc, cover, tone, tone_strength * smoothstep(0.0, 0.4, abs(drift - 0.5)));

	// Scuffs: short bright streaks that run mostly one way (traffic) and wander about 30 degrees either side across the floor. They
	// gather in worn patches about a metre across instead of covering the floor evenly (which reads as rain).
	float angle = 0.12 + (fbm(p / 6.5 + vec2(21.0, 5.0)) - 0.5) * 1.1;
	vec2 streak = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * p;
	float worn = smoothstep(0.45, 0.75, value_noise(p * 0.8 + vec2(8.0, 2.0)));
	float scuff = value_noise(streak * vec2(2.4, 16.0)) * (0.35 + 0.9 * worn);
	over(acc, cover, at_level(vec3(0.85, 0.9, 1.0), level * scuff_level), scuff_strength * smoothstep(0.55, 0.85, scuff));

	// Distance to the nearest wall (x pairs are the side walls, z the back and front walls).
	vec2 dd = half_arena - abs(p);
	float nearest = min(dd.x, dd.y);

	// A faint spill of the rim light on the floor next to the walls.
	over(acc, cover, at_level(rim_color, spill_level), spill_strength * exp(-max(nearest, 0.0) / spill_reach));

	// Painted dash line, running along whichever wall is nearest and worn by a little noise.
	float along = dd.x < dd.y ? p.y : p.x;
	float pixel = fwidth(p.x) + fwidth(p.y);
	float band = 1.0 - smoothstep(line_width * 0.5 - pixel, line_width * 0.5 + pixel, abs(nearest - line_offset));
	float cell = along / dash_period;
	float cell_pixel = pixel / dash_period;
	float phase = fract(cell);
	float dash = smoothstep(0.0, cell_pixel, phase) * (1.0 - smoothstep(dash_fill, dash_fill + cell_pixel, phase));
	float wear = smoothstep(0.15, 0.85, value_noise(vec2(along * 7.0, nearest * 30.0)) * 0.6 + value_noise(vec2(along * 31.0, nearest * 90.0)) * 0.4 + 0.2);
	over(acc, cover, at_level(accent, paint_level), line_strength * band * dash * wear);

	// Occlusion at the foot of each wall. The back wall is the tallest, the front parapet the lowest. Corners get both.
	float wall_x = ao_strength.x * pow(1.0 - smoothstep(0.0, ao_reach, dd.x), 1.6);
	float wall_z = (p.y < 0.0 ? ao_strength.y : ao_strength.z) * pow(1.0 - smoothstep(0.0, ao_reach, dd.y), 1.6);
	over(acc, cover, vec3(0.0, 0.0, 0.004), 1.0 - (1.0 - wall_x) * (1.0 - wall_z));

	ALBEDO = cover > 0.0001 ? acc / cover : vec3(0.0);
	ALPHA = cover;
}

shader_type spatial;
// Death dissolve. Reproduces the StandardMaterial3D look (albedo, panel texture, vertex-colour AO, metal/rough,
// emission) and eats the model away with 3D noise biased top-down. A hot emissive edge rides the cut line and
// blooms. Noise is sampled in world space so all parts of a model share one pattern.
render_mode cull_disabled;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform bool use_vertex_color = false;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform vec4 edge_color : source_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float model_height = 1.0;

varying vec3 world_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float noise = value_noise(world_pos * 14.0) * 0.6 + value_noise(world_pos * 31.0) * 0.4;
	float height01 = clamp(world_pos.y / model_height, 0.0, 1.0);
	float d = mix(noise, 1.0 - height01, 0.4); // low values go first, so the top of the model erodes ahead of the legs
	float limit = progress * 1.3 - 0.15;
	if (d < limit) {
		discard;
	}
	float edge = 1.0 - smoothstep(0.0, 0.09, d - limit);
	vec3 base = albedo_color.rgb * texture(albedo_tex, UV).rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	ALBEDO = base * (1.0 - edge);
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = emission_color.rgb * emission_energy * (1.0 - edge) + edge_color.rgb * edge * 5.0;
}

shader_type spatial;
// Death shatter. The mesh was pre-fractured by ShatterBaker: every vertex carries its shard's pivot (CUSTOM0.xyz, mesh
// space), the shard id (CUSTOM0.w) and the shard radius (UV2.x). All motion is solved here as a closed-form function of
// the time since death, so a shattering enemy costs no per-shard nodes, physics bodies or tweens, and the materials are
// shared by every corpse; only `origin_age` and `kick_seed` differ per mesh instance.
//
// Each shard is lobbed away from the enemy's centre with a hashed speed, spins about a hashed axis, hits the floor,
// bounces once, slides to a stop, then shrinks away. Reproduces the StandardMaterial3D look like dissolve.gdshader does.
render_mode cull_disabled, world_vertex_coords;

instance uniform vec4 origin_age = vec4(0.0); // xyz: ground point under the enemy, w: seconds since it died
instance uniform vec4 kick_seed = vec4(0.0); // xyz: velocity the enemy carried when it died, w: per-corpse random seed

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform vec4 heat_color : source_color = vec4(1.0, 0.5, 0.15, 1.0);
uniform float life = 1.3; // seconds until every shard has shrunk to nothing
uniform float gravity = 13.0;
uniform float drag = 1.6; // horizontal slide-to-a-stop rate
uniform float bounce = 0.3;

varying vec2 glow; // x: cooling heat, y: the white flash on the instant of impact

float hash11(float n) {
	return fract(sin(n * 12.9898 + 78.233) * 43758.5453);
}

vec3 rotate_about(vec3 v, vec3 axis, float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return v * c + cross(axis, v) * s + axis * dot(axis, v) * (1.0 - c);
}

void vertex() {
	// world_vertex_coords: VERTEX and NORMAL arrive in world space. At age 0 they are left alone (the intact model).
	float t = origin_age.w;
	glow = vec2(0.0);
	if (t > 0.0) {
		float body = length(MODEL_MATRIX[0].xyz);
		float id = CUSTOM0.w + kick_seed.w * 53.0;
		float r1 = hash11(id + 0.13);
		float r2 = hash11(id + 1.71);
		float r3 = hash11(id + 2.93);
		float r4 = hash11(id + 4.37);
		float r5 = hash11(id + 5.91);
		float r6 = hash11(id + 7.73);
		float r7 = hash11(id + 9.19);

		vec3 pivot = (MODEL_MATRIX * vec4(CUSTOM0.xyz, 1.0)).xyz;
		float radius = UV2.x * body;
		vec3 centre = origin_age.xyz + vec3(0.0, 0.38 * body, 0.0);
		vec3 away = pivot - centre;
		float high = clamp((pivot.y - origin_age.y) / (0.8 * body), 0.0, 1.0);
		away.y = 0.0;
		vec3 heading = normalize(away + vec3(r4 - 0.5, 0.0, r5 - 0.5) * 0.5 * body + vec3(0.0001));

		// Launch: sideways away from the centre, upward more for pieces from the top of the shell.
		float speed = mix(1.3, 3.8, r1) * body;
		float lift = mix(2.6, 5.4, r2) * (0.7 + 0.6 * high) * body;
		vec3 velocity = heading * speed + vec3(0.0, lift, 0.0) + kick_seed.xyz * 0.6;

		// Flight with one bounce. `drop` is how far above its resting height the pivot starts.
		float rest = radius * 0.3;
		float drop = max(pivot.y - origin_age.y - rest, 0.0);
		float land = (velocity.y + sqrt(velocity.y * velocity.y + 2.0 * gravity * drop)) / gravity;
		float lift_y;
		if (t < land) {
			lift_y = velocity.y * t - 0.5 * gravity * t * t;
		} else {
			float rebound = (gravity * land - velocity.y) * bounce;
			float after = t - land;
			float hop = (after < 2.0 * rebound / gravity) ? rebound * after - 0.5 * gravity * after * after : 0.0;
			lift_y = -drop + hop;
		}
		vec2 slide = velocity.xz * (1.0 - exp(-drag * t)) / drag;

		// Spin fades out just after the first landing so shards come to rest instead of rotating through the floor.
		float spinning = t < land ? t : land + (1.0 - exp(-8.0 * (t - land))) / 8.0;
		float omega = (r3 < 0.5 ? -1.0 : 1.0) * mix(5.0, 14.0, r6);
		float angle = omega * (1.0 - exp(-1.3 * spinning)) / 1.3;
		vec3 axis = normalize(vec3(r5, r6, r7) * 2.0 - 1.0 + vec3(0.001));

		float shrink = 1.0 - smoothstep(life * 0.55, life, t);
		vec3 offset = rotate_about(VERTEX - pivot, axis, angle) * shrink;
		VERTEX = pivot + vec3(slide.x, lift_y, slide.y) + offset;
		NORMAL = rotate_about(NORMAL, axis, angle);

		float flash = clamp(1.0 - t / 0.16, 0.0, 1.0);
		glow = vec2(exp(-t * 3.6) * (0.4 + 0.6 * r1), flash * flash);
	}
}

void fragment() {
	ALBEDO = albedo_color.rgb * texture(albedo_tex, UV).rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = emission_color.rgb * emission_energy + heat_color.rgb * glow.x * 0.7 + vec3(glow.y) * 1.6;
}

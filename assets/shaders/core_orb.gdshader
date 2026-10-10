shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 energy_color : source_color = vec4(0.345, 0.925, 0.882, 1.0);
uniform float phase = 0.0;
uniform float power = 1.0;
uniform float hit = 0.0;
varying vec3 sphere_direction;

void vertex() {
	sphere_direction = NORMAL;
}

void fragment() {
	vec3 p = normalize(sphere_direction);
	// Object-space currents have no UV seam and stop when the controller freezes phase.
	float flow = sin(p.x * 8.0 + sin(p.y * 6.0 + phase) * 1.5 + p.z * 4.0 - phase * 0.6);
	float veins = pow(1.0 - abs(flow), 8.0);
	float clouds = 0.5 + 0.5 * sin(p.y * 9.0 + sin(p.z * 7.0 - phase * 0.7) + phase * 0.4);
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 3.0);
	vec3 plasma = mix(energy_color.rgb * 0.18, energy_color.rgb, clouds * 0.6 + 0.25);
	plasma = mix(plasma, vec3(0.85, 1.0, 0.97), veins * 0.8);
	ALBEDO = plasma * (0.2 + power * 0.35);
	EMISSION = (plasma * (0.7 + veins * 1.6) + energy_color.rgb * rim * 1.3) * power + vec3(hit);
	ROUGHNESS = 0.24;
	METALLIC = 0.15;
}

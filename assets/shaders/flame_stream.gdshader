shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;

uniform float motion_speed = 1.0;

void fragment() {
    float along = 1.0 - UV.y;
    float ripple = sin(along * 31.0 - TIME * motion_speed * 24.0) * 0.07 + sin(along * 53.0 - TIME * motion_speed * 37.0) * 0.035;
    float lateral = abs(UV.x - 0.5 + ripple * along);
    float width = mix(0.12, 0.40, along) * (1.0 - pow(along, 5.0));
    float shape = 1.0 - smoothstep(width * 0.3, width, lateral);
    float fade = smoothstep(0.0, 0.08, along) * (1.0 - smoothstep(0.72, 1.0, along));
    vec3 color = mix(vec3(1.0, 0.87, 0.24), vec3(1.0, 0.13, 0.015), along);
    ALBEDO = color;
    EMISSION = color * 1.7;
    ALPHA = shape * fade * 0.65;
}

shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform float visual_time = 0.;
uniform float motion_speed = 1.;
void fragment() {
    float rise = 1.-UV.y;
    float phase = visual_time*motion_speed;
    float tongues = sin(UV.x*29.+phase*5.)*.07 + sin(UV.x*51.-phase*8.)*.04;
    float width = (.47-rise*.32) + sin(rise*18.-phase*9.)*.035;
    float edge = 1.-smoothstep(width-.10,width,abs(UV.x-.5));
    float tip = 1.-smoothstep(.4+tongues,.94+tongues,rise);
    float hollow = smoothstep(.05,.27,abs(UV.x-.5))*.8+.2;
    vec3 color = mix(vec3(1.,.73,.12),vec3(1.,.10,.015),rise);
    ALBEDO = color;
    EMISSION = color*1.5;
    ALPHA = edge*tip*hollow*smoothstep(0.,.12,rise)*.65;
}

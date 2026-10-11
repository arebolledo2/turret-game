shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform float visual_time = 0.;
uniform float motion_speed = 1.0;
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.-2.*f);
    return mix(mix(fract(sin(dot(i,vec2(127.1,311.7)))*43758.5453),fract(sin(dot(i+vec2(1,0),vec2(127.1,311.7)))*43758.5453),f.x),mix(fract(sin(dot(i+vec2(0,1),vec2(127.1,311.7)))*43758.5453),fract(sin(dot(i+vec2(1,1),vec2(127.1,311.7)))*43758.5453),f.x),f.y);
}
void fragment() {
    float along=1.-UV.y;
    float n=noise(vec2(UV.x*9.,along*13.-visual_time*motion_speed*10.));
    float n2=noise(vec2(UV.x*19.,along*27.-visual_time*motion_speed*17.));
    float width=mix(.08,.48,along)*(1.-pow(along,6.));
    float edge=1.-smoothstep(width*.35,width,abs(UV.x-.5)+(n-.5)*along*.15);
    float fade=smoothstep(0.,.06,along)*(1.-smoothstep(.55+n*.25,1.,along));
    float heat=clamp(edge*(1.-along*.55)+n2*.15,0.,1.);
    vec3 color=mix(vec3(1.,.08,.005),vec3(1.,.65,.06),heat);
    color=mix(color,vec3(1.,.95,.6),pow(heat,5.));
    ALBEDO=color; EMISSION=color*1.7;
    ALPHA=edge*fade*(.45+n*.35);
}

shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform vec4 tint : source_color = vec4(.2,.8,1.,1.);
uniform float age = 0.;
uniform bool reduced_motion = false;
void fragment() {
    vec2 p = UV * 2. - 1.;
    float r = length(p);
    float radius = mix(.08,.98,reduced_motion ? 1. : age);
    float ring = exp(-pow((r-radius)*42.,2.));
    float echo = exp(-pow((r-radius*.78)*55.,2.)) * .35;
    float a = atan(p.y,p.x);
    float spokes = pow(max(0.,cos(a*18.+r*7.)),18.) * .28;
    float field = (1.-smoothstep(radius*.25,radius,r))*.08;
    ALBEDO = tint.rgb;
    EMISSION = tint.rgb * 1.5;
    ALPHA = (ring + echo + spokes * ring + field) * (1.-age);
}

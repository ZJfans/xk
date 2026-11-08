shader_type canvas_item;
render_mode unshaded;

uniform vec4 shadow_color : source_color = vec4(0.015, 0.025, 0.08, 1.0);
uniform vec4 teal_color : source_color = vec4(0.035, 0.36, 0.46, 1.0);
uniform vec4 violet_color : source_color = vec4(0.30, 0.07, 0.38, 1.0);
uniform float brightness : hint_range(0.1, 2.0) = 0.80;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise2(vec2 x) {
    vec2 i = floor(x);
    vec2 f = fract(x);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float s = 0.0;
    float a = 0.5;
    for (int i = 0; i < 5; i++) {
        s += a * noise2(p);
        p = p * 2.05 + vec2(2.3, 1.7);
        a *= 0.5;
    }
    return s;
}

void fragment() {
    vec2 uv = UV;
    vec2 p = (uv - 0.5) * vec2(3.3, 2.2);
    vec2 drift = vec2(TIME * 0.003, TIME * -0.002);
    float n = fbm(p * 1.75 + drift);
    float n2 = fbm((p + vec2(4.7, 1.3)) * 2.3 - drift);
    float tendril = smoothstep(0.50, 0.75, n);
    float violet = smoothstep(0.52, 0.73, n2) * (0.55 + 0.45 * sin(p.x * 0.9));
    vec3 col = shadow_color.rgb;
    col += teal_color.rgb * tendril * 0.60 * brightness;
    col += violet_color.rgb * violet * 0.45 * brightness;
    float dust = pow(noise2(uv * vec2(370.0, 250.0)), 16.0) * 0.35;
    col += vec3(0.4, 0.72, 0.88) * dust;
    float vignette = 1.0 - 0.60 * smoothstep(0.35, 0.85, length((uv - 0.5) * vec2(1.1, 0.9)));
    COLOR = vec4(col * vignette, 1.0);
}

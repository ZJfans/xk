shader_type canvas_item;
render_mode unshaded, blend_mix;

uniform float intensity : hint_range(0.0, 1.0) = 0.35;

float random2(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    float fine_line = 0.5 + 0.5 * sin(FRAGCOORD.y * 1.57);
    float coarse_line = 0.5 + 0.5 * sin(FRAGCOORD.y * 0.13 + TIME * 0.6);
    float grain = random2(floor(FRAGCOORD.xy * 0.65) + floor(TIME * 9.0));
    float edge = smoothstep(0.32, 0.9, length((uv - vec2(0.5)) * vec2(1.15, 0.95)));
    float alpha = intensity * (0.016 + fine_line * 0.022 + coarse_line * 0.010 + grain * 0.012 + edge * 0.035);
    COLOR = vec4(vec3(0.025, 0.13, 0.18), alpha);
}

// Cyberpunk Neon Chromatic Aberration Shader for Hyprland
precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D tex;

void main() {
    vec2 uv = v_texcoord;
    vec2 center = vec2(0.5, 0.5);
    vec2 dir = uv - center;
    float dist = length(dir);

    // Radial aberration: strongest towards outer edges
    float strength = pow(dist, 2.0) * 0.012;

    float r = texture2D(tex, uv - dir * strength).r;
    float g = texture2D(tex, uv).g;
    float b = texture2D(tex, uv + dir * strength).b;

    vec3 col = vec3(r, g, b);

    // Electric neon tint: subtle cyan/magenta pop
    col.r *= 1.04;
    col.b *= 1.06;

    // Slight contrast pop
    col = clamp(((col - 0.5) * 1.1) + 0.5, 0.0, 1.0);

    gl_FragColor = vec4(col, 1.0);
}

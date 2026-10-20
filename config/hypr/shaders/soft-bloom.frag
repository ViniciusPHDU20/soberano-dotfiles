// Soft Dream Glow / Film Bloom Shader for Hyprland
precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D tex;

void main() {
    vec2 uv = v_texcoord;
    vec4 base = texture2D(tex, uv);

    // 4-tap soft blur box around highlights
    float offset = 0.0022;
    vec4 blur = texture2D(tex, uv + vec2(-offset, -offset)) * 0.25;
    blur += texture2D(tex, uv + vec2(offset, -offset)) * 0.25;
    blur += texture2D(tex, uv + vec2(-offset, offset)) * 0.25;
    blur += texture2D(tex, uv + vec2(offset, offset)) * 0.25;

    // Isolate bright areas
    vec4 bloom = max(blur - 0.45, 0.0) * 1.5;

    // Screen blend mode with base image
    vec3 col = 1.0 - (1.0 - base.rgb) * (1.0 - bloom.rgb * 0.35);

    gl_FragColor = vec4(col, base.a);
}

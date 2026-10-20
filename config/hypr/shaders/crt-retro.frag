// Retro CRT Terminal Shader with Scanlines & Barrel Distortion for Hyprland
precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D tex;

// Barrel distortion curve
vec2 curve(vec2 uv) {
    uv = (uv - 0.5) * 2.0;
    uv *= 1.1;
    uv.x *= 1.0 + pow((abs(uv.y) / 5.0), 2.0);
    uv.y *= 1.0 + pow((abs(uv.x) / 4.0), 2.0);
    uv = (uv / 2.0) + 0.5;
    uv = uv * 0.92 + 0.04;
    return uv;
}

void main() {
    vec2 uv = curve(v_texcoord);

    // Screen border mask (black outside curve)
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }

    // Subtle RGB phosphor subpixel shift
    float r = texture2D(tex, vec2(uv.x + 0.0008, uv.y)).r;
    float g = texture2D(tex, vec2(uv.x, uv.y)).g;
    float b = texture2D(tex, vec2(uv.x - 0.0008, uv.y)).b;
    vec3 col = vec3(r, g, b);

    // Horizontal scanlines
    float scanline = sin(uv.y * 800.0) * 0.05;
    col -= scanline;

    // Corner vignette
    float vig = uv.x * (1.0 - uv.x) * uv.y * (1.0 - uv.y) * 15.0;
    col *= clamp(pow(vig, 0.25), 0.0, 1.0);

    // Phosphor green/amber slight warmth
    col.r *= 1.02;
    col.g *= 1.03;

    gl_FragColor = vec4(col, 1.0);
}

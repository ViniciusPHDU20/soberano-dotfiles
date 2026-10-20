// Night Warm / Blue Light Filter Shader for Hyprland
precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D tex;

void main() {
    vec4 pix = texture2D(tex, v_texcoord);
    vec3 col = pix.rgb;

    // Warm amber shift matrix (approx. 3600K color temperature)
    // Preserves luminance while reducing high-energy blue wavelengths
    vec3 warm = vec3(
        col.r * 1.0,
        col.g * 0.88,
        col.b * 0.70
    );

    // Subtle brightness compensation
    warm = clamp(warm * 1.02, 0.0, 1.0);

    gl_FragColor = vec4(warm, pix.a);
}

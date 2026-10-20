// Filmic Monochrome / Noir High Contrast Shader for Hyprland
precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D tex;

void main() {
    vec4 pix = texture2D(tex, v_texcoord);

    // Rec. 709 high-precision perceptual luminance
    float luma = dot(pix.rgb, vec3(0.2126, 0.7152, 0.0722));

    // Deep filmic S-Curve contrast
    float contrast = 1.15;
    luma = clamp(((luma - 0.5) * contrast) + 0.5, 0.0, 1.0);

    // Subtle cool selenium tint
    vec3 col = vec3(luma * 0.98, luma * 1.0, luma * 1.03);

    gl_FragColor = vec4(col, pix.a);
}

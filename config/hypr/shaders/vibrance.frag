// Vibrance & Filmic Contrast Shader for Hyprland
precision mediump float;
varying vec2 v_texcoord;
uniform sampler2D tex;

// Vibrance: boosts unsaturated colors more than saturated ones
vec3 applyVibrance(vec3 color, float vibrance) {
    float maxColor = max(color.r, max(color.g, color.b));
    float minColor = min(color.r, min(color.g, color.b));
    float sat = maxColor - minColor;
    float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
    return mix(vec3(luma), color, 1.0 + (vibrance * (1.0 - sat)));
}

// Subtle S-Curve for cinematic contrast
vec3 applyContrast(vec3 color, float contrast) {
    return clamp(((color - 0.5) * contrast) + 0.5, 0.0, 1.0);
}

void main() {
    vec4 pix = texture2D(tex, v_texcoord);
    vec3 col = pix.rgb;

    col = applyVibrance(col, 0.35);
    col = applyContrast(col, 1.08);

    gl_FragColor = vec4(col, pix.a);
}

#version 450
// Stand-in for TF3's hdr/compose.fs; the layer recognises it by the function name below and takes
// the main depth buffer from this pass's framebuffer.
layout(location = 0) in vec2 uv;
layout(set = 1, binding = 0) uniform sampler2D hdrColor;  // set 0 is the camera, as in every TF3 pass
layout(location = 0) out vec4 outColor;

vec3 legacyToneMapAndGammaAndContrastBump(vec3 c) {
    return c / (1.0 + c);
}

void main() {
    outColor = vec4(legacyToneMapAndGammaAndContrastBump(texture(hdrColor, uv).rgb), 1.0);
}

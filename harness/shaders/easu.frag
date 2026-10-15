#version 450
// Stand-in for TF3's fsr_pass0.fs (FSR 1 EASU): recognised by the UBO member name. Draws magenta,
// so any of it that reaches the screen means the layer's upscaled image wasn't shown.
layout(location = 0) in vec2 uv;
layout(set = 0, binding = 0) uniform sampler2D tonemapped;  // the layer's upscaler input
layout(set = 0, binding = 1, std140) uniform Fsr { vec4 con; float fsrSharpening; } fsr;
layout(location = 0) out vec4 outColor;

void main() {
    outColor = vec4(1.0, 0.0, 1.0, 1.0) + 0.0 * texture(tonemapped, uv) * fsr.fsrSharpening;
}

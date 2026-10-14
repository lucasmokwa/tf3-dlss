#version 450
// Stand-in for TF3's fsr_pass1.fs (FSR 1 RCAS): same UBO member as EASU plus a prng() function.
// Magenta too; the layer records the upscaler right after this pass.
layout(location = 0) in vec2 uv;
layout(set = 0, binding = 0) uniform sampler2D easuOut;
layout(set = 0, binding = 1, std140) uniform Fsr { vec4 con; float fsrSharpening; } fsr;
layout(location = 0) out vec4 outColor;

float prng(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void main() {
    vec4 c = texture(easuOut, uv);
    outColor = vec4(1.0, 0.0, 1.0, 1.0) + 0.0 * c * fsr.fsrSharpening * prng(uv);
}

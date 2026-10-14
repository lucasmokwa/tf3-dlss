#version 450
// The final copy to the screen: samples RCAS's output, which the layer swaps for its own image.
layout(location = 0) in vec2 uv;
layout(set = 0, binding = 0) uniform sampler2D rcasOut;
layout(location = 0) out vec4 outColor;
void main() { outColor = vec4(texture(rcasOut, uv).rgb, 1.0); }

#version 450
// A checkerboard in world space (1 unit squares) times the material colour: plenty of detail for
// the upscaler, and sharp edges that show smearing.
layout(location = 0) in vec3 worldPos;
layout(set = 1, binding = 0, std140) uniform Material { vec4 tint; } mat;  // dynamic offset per draw
// TF3's terrain shader reads last frame's depth here for its contour lines (shaders/util/color_map.fs);
// the layer swaps in its un-jittered depth. Read so the binding is live; the colour doesn't change.
layout(set = 0, binding = 16) uniform sampler2D colorMapDepthTex;
layout(location = 0) out vec4 outColor;

void main() {
    ivec3 c = ivec3(floor(worldPos + 1000.0));
    float checker = ((c.x + c.y + c.z) & 1) == 0 ? 1.0 : 0.25;
    float depth = texelFetch(colorMapDepthTex, ivec2(gl_FragCoord.xy), 0).r;  // 0..1
    outColor = vec4(mat.tint.rgb * checker * (depth <= 1.0 ? 2.0 : 1.0), 1.0);  // HDR: up to 2.0 before tonemapping
}

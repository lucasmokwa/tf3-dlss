#version 450
// A UI panel drawn after the blit (must stay on top of the upscaled image).
layout(location = 0) in vec2 uv;
layout(push_constant) uniform Rect { vec4 rect; vec4 color; } pc;  // rect = x0, y0, x1, y1 in uv
layout(location = 0) out vec4 outColor;
void main() {
    if (any(lessThan(uv, pc.rect.xy)) || any(greaterThan(uv, pc.rect.zw))) discard;
    outColor = pc.color;
}

#version 450
// Writes the full motion (camera + object) for visible pixels of a moving object, over the
// camera-only motion vectors. Same convention as camera_mv.comp: previous pixel position minus
// this pixel's unjittered position, in render pixels, rows top-down.

layout(location = 0) in vec4 prevClip;

layout(set = 0, binding = 0) uniform sampler2D sceneDepth;
layout(set = 0, binding = 1, std140) uniform Matrices {
    mat4 curInvViewProj;
    mat4 prevViewProj;
    vec4 sizeAndScale;
    vec4 jitterPx;
    mat4 curViewProj;
    vec4 params;           // near, far, flip y, skip visibility check
} u;

layout(location = 0) out vec2 outMv;

float linearDepth(float d) {  // stored depth -> distance along the view axis (GL-style projection)
    float z = d * 2.0 - 1.0;
    float n = u.params.x, f = u.params.y;
    return 2.0 * n * f / (f + n - z * (f - n));
}

void main() {
    // Only where this object is what the camera actually sees (no depth attachment: compare by hand,
    // with some tolerance since our depth is recomputed rather than identical).
    float scene = texelFetch(sceneDepth, ivec2(gl_FragCoord.xy), 0).r;
    float mine = linearDepth(gl_FragCoord.z), seen = linearDepth(scene);
    // Only where this surface IS what the camera sees: not behind it (hidden) and not in front of it
    // either (a replayed triangle that doesn't match the game's geometry must never overwrite the scene).
    if (u.params.w < 0.5 && abs(mine - seen) > seen * 0.002 + 0.05) discard;  // params.w = 1: test mode
    if (prevClip.w <= 1e-6) discard;
    vec2 prevNdc = prevClip.xy / prevClip.w;
    vec2 size = u.sizeAndScale.xy;
    vec2 prevPix = vec2((prevNdc.x * 0.5 + 0.5) * size.x, (0.5 - prevNdc.y * 0.5) * size.y);
    outMv = prevPix - (gl_FragCoord.xy - u.jitterPx.xy);
}

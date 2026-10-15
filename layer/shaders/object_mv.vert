#version 450
// Object motion vectors (milestone 6): the layer redraws moving objects (vehicles etc.) once more
// with this shader. Same vertex data and model matrix as the game's draw, plus the object's model
// matrix from the previous frame (matched by the layer on the CPU), so each pixel gets
// "where was this point last frame" including the object's own movement.
//
// Mirrors the game's shaders/mat/vs/std/*.vs:
//   posAmbient  = instAttrModel * attrPosition
//   gl_Position = projView * vec4(posAmbient.xyz, 1), RESCALE_Z_POS, INVERT_Y (when the viewport isn't flipped)

layout(location = 0) in vec4 inPos;    // game's attrPosition (w = 1 when the format has 3 components)
layout(location = 1) in vec4 mdl0;     // game's instAttrModel, per instance
layout(location = 2) in vec4 mdl1;
layout(location = 3) in vec4 mdl2;
layout(location = 4) in vec4 mdl3;
layout(location = 5) in vec4 prv0;     // previous frame's model matrix, per instance (our buffer)
layout(location = 6) in vec4 prv1;
layout(location = 7) in vec4 prv2;
layout(location = 8) in vec4 prv3;

layout(set = 0, binding = 1, std140) uniform Matrices {
    mat4 curInvViewProj;   // (camera pass) jittered
    mat4 prevViewProj;     // last frame, unjittered
    vec4 sizeAndScale;     // xy = render size
    vec4 jitterPx;         // xy = this frame's jitter in pixels
    mat4 curViewProj;      // this frame, unjittered (jitter is applied through the viewport)
    vec4 params;           // x = near, y = far, z = 1 to flip y in the shader
} u;

layout(location = 0) out vec4 prevClip;

void main() {
    mat4 cur = mat4(mdl0, mdl1, mdl2, mdl3);
    mat4 prev = mat4(prv0, prv1, prv2, prv3);
    if (cur == prev) {
        // Didn't move (or wasn't matched): the camera pass already has its motion. Outside the clip
        // volume, so the instance's triangles are dropped before any pixel work.
        gl_Position = vec4(2.0, 2.0, 2.0, 1.0);
        prevClip = vec4(0.0);
        return;
    }
    vec4 world = cur * inPos;
    vec4 worldPrev = prev * inPos;
    gl_Position = u.curViewProj * vec4(world.xyz, 1.0);
    gl_Position.z = 0.5 * gl_Position.z + 0.5 * gl_Position.w;  // RESCALE_Z_POS, as the game
    if (u.params.z > 0.5) gl_Position.y = -gl_Position.y;        // INVERT_Y, as the game
    prevClip = u.prevViewProj * vec4(worldPrev.xyz, 1.0);
}

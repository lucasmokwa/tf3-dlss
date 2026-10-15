#version 450
// 3D geometry, shaped like TF3's shaders/mat/vs/std/*.vs: per-vertex attrPosition, per-instance
// mat4 instAttrModel, the camera in set 0 binding 10 (GL-style projection, z rescaled to 0..1 and
// y flipped in the shader, with a positive viewport height).
layout(location = 0) in vec3 attrPosition;
layout(location = 1) in mat4 instAttrModel;  // locations 1-4

layout(set = 0, binding = 10, std140) uniform View {
    mat4 projView;
    mat4 projViewInverse;
    mat4 proj;
} view;

layout(location = 0) out vec3 worldPos;

void main() {
    vec4 posAmbient = instAttrModel * vec4(attrPosition, 1.0);
    worldPos = posAmbient.xyz;
    gl_Position = view.projView * vec4(posAmbient.xyz, 1.0);
    gl_Position.z = 0.5 * gl_Position.z + 0.5 * gl_Position.w;  // RESCALE_Z_POS
    gl_Position.y = -gl_Position.y;                               // INVERT_Y
}

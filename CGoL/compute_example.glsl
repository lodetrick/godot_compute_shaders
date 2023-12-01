#[compute]
#version 450

layout(local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

layout(r8, binding = 1) uniform readonly image2D in_data;
layout(r8, binding = 2) uniform writeonly image2D out_data;

layout(set = 0, binding = 0, std430) restrict readonly buffer Params {
    float rules[18];
} params;

ivec2 move(ivec2 coord,ivec2 move) {
    return ivec2(mod(coord + move + imageSize(in_data),imageSize(in_data)));
}

// The code we want to execute in each invocation
void main() {
    // gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
    ivec2 coords = ivec2(gl_GlobalInvocationID.xy);

    uint num_neighbors = uint(8 - (imageLoad(in_data,move(coords,ivec2(1,0))).r
                    + imageLoad(in_data,move(coords,ivec2(1,1))).r
                    + imageLoad(in_data,move(coords,ivec2(1,-1))).r
                    + imageLoad(in_data,move(coords,ivec2(-1,0))).r
                    + imageLoad(in_data,move(coords,ivec2(-1,1))).r
                    + imageLoad(in_data,move(coords,ivec2(-1,-1))).r
                    + imageLoad(in_data,move(coords,ivec2(0,1))).r
                    + imageLoad(in_data,move(coords,ivec2(0,-1))).r));
    
    float is_active = params.rules[int(imageLoad(in_data,coords).r) * 9 + num_neighbors];
    

    imageStore(out_data,coords,vec4(is_active));
}
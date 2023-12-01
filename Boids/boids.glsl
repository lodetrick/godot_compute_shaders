#[compute]
#version 450

layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Params {
    float num_boids;
    float boid_speed;
    float one_distance;
    float one_strength;
    float two_distance;
    float two_strength;
    float three_distance;
    float three_strength;
} params;

layout(set = 0, binding = 1, std430) restrict readonly buffer InBuffer {
    float data[];
} in_buffer;

layout(set = 0, binding = 2, std430) restrict buffer OutBuffer {
    float data[];
} out_buffer;

vec2 calc_rule_1(uint boid) {
    vec2 sum = vec2(0);
    int amount = 0;
    vec2 pos = vec2(in_buffer.data[boid],in_buffer.data[boid+1]);
    for (int i = 0; i < params.num_boids; i++) {
        if (4*i == boid) {
        }
        if (distance(vec2(in_buffer.data[4*i],in_buffer.data[4*i+1]),pos) < params.one_distance) {
            sum += vec2(in_buffer.data[4*i],in_buffer.data[4*i+1]);
            amount += 1;
        }
    }
    sum /= amount;
    return (sum - pos) / params.one_strength;
}

vec2 calc_rule_2(uint boid) {
    
}

// The code we want to execute in each invocation
void main() {
    // gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
    uint index = 4 * gl_GlobalInvocationID.x;
    
    vec2 rule_1 = calc_rule_1(index);

    out_buffer.data[index+2] = clamp(in_buffer.data[index+2] + rule_1.x,-1 * params.boid_speed,params.boid_speed);
    out_buffer.data[index+3] = clamp(in_buffer.data[index+3] + rule_1.y,-1 * params.boid_speed,params.boid_speed);
    out_buffer.data[index] = in_buffer.data[index] + out_buffer.data[index+2] * 0.01;
    out_buffer.data[index+1] = in_buffer.data[index+1] + out_buffer.data[index+3] * 0.01;
}
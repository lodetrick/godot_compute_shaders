#[compute]
#version 450

layout(local_size_x = 512, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict readonly buffer Params {
    float num_boids;
    float boid_speed;
    float acceleration;
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
        vec2 other_pos = vec2(in_buffer.data[4*i],in_buffer.data[4*i+1]);
        float is_active = float(4*i != boid) * (1 - step(params.one_distance,distance(other_pos,pos)));
        sum += is_active * other_pos;
        amount += int(is_active);
    }
    if (amount <= 0) {
        return vec2(0);
    }
    sum /= amount;
    return (sum - pos) / params.one_strength;
}

vec2 calc_rule_2(uint boid) {
    vec2 sum = vec2(0);
    vec2 pos = vec2(in_buffer.data[boid],in_buffer.data[boid+1]);
    for (int i = 0; i < params.num_boids; i++) {
        vec2 delta = vec2(in_buffer.data[4*i],in_buffer.data[4*i+1]) - pos;
        if (length(delta) == 0) {
            continue;
        }
        sum -= params.two_strength * pow(params.two_distance,-length(delta) / 10) * normalize(delta);
    }

    return sum;
}

vec2 calc_rule_3(uint boid) {
    vec2 sum = vec2(0);
    int amount = 0;
    vec2 pos = vec2(in_buffer.data[boid], in_buffer.data[boid + 1]);
    vec2 vel = vec2(in_buffer.data[boid + 2], in_buffer.data[boid + 3]);
    for (int i = 0; i < params.num_boids; i++) {
        float is_active = float(4*i != boid) * (1 - step(params.three_distance,distance(vec2(in_buffer.data[4*i],in_buffer.data[4*i+1]),pos)));
        sum += is_active * vec2(in_buffer.data[4*i+2],in_buffer.data[4*i+3]);
        amount += int(is_active);
    }
    if (amount <= 0) {
        return vec2(0);
    }
    sum /= amount;
    return (sum - vel) / params.three_strength;
}

// The code we want to execute in each invocation
void main() {
    // gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
    uint index = 4 * gl_GlobalInvocationID.x;
    vec2 velocity = vec2(in_buffer.data[index+2],in_buffer.data[index+3]);
    vec2 rule_1 = calc_rule_1(index);
    vec2 rule_2 = calc_rule_2(index);
    vec2 rule_3 = calc_rule_3(index);

    vec2 delta_vel = rule_1 + rule_2 + rule_3;
    delta_vel = delta_vel + velocity;
    delta_vel *= 1.1;
    if (length(delta_vel) > params.boid_speed) {
        delta_vel *= params.boid_speed / length(delta_vel);
    }

    out_buffer.data[index+2] = delta_vel.x;
    out_buffer.data[index+3] = delta_vel.y;
    out_buffer.data[index] = mod(in_buffer.data[index] + out_buffer.data[index+2],700);
    out_buffer.data[index+1] = mod(in_buffer.data[index+1] + out_buffer.data[index+3],500);
}
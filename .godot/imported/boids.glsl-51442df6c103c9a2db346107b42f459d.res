RSRC                    RDShaderFile            ��������                                                  resource_local_to_scene    resource_name    bytecode_vertex    bytecode_fragment    bytecode_tesselation_control     bytecode_tesselation_evaluation    bytecode_compute    compile_error_vertex    compile_error_fragment "   compile_error_tesselation_control %   compile_error_tesselation_evaluation    compile_error_compute    script 
   _versions    base_error           local://RDShaderSPIRV_s2jvq ;         local://RDShaderFile_1kck0 �
         RDShaderSPIRV          Q  Failed parse:
ERROR: 0:40: '' : function does not return a value: calc_rule_2
ERROR: 1 compilation errors.  No code generated.




Stage 'compute' source code: 

1		#version 450
2		
3		layout(local_size_x = 128, local_size_y = 1, local_size_z = 1) in;
4		
5		layout(set = 0, binding = 0, std430) restrict readonly buffer Params {
6		    float num_boids;
7		    float boid_speed;
8		    float one_distance;
9		    float one_strength;
10		    float two_distance;
11		    float two_strength;
12		    float three_distance;
13		    float three_strength;
14		} params;
15		
16		layout(set = 0, binding = 1, std430) restrict readonly buffer InBuffer {
17		    float data[];
18		} in_buffer;
19		
20		layout(set = 0, binding = 2, std430) restrict buffer OutBuffer {
21		    float data[];
22		} out_buffer;
23		
24		vec2 calc_rule_1(uint boid) {
25		    vec2 sum = vec2(0);
26		    int amount = 0;
27		    vec2 pos = vec2(in_buffer.data[boid],in_buffer.data[boid+1]);
28		    for (int i = 0; i < params.num_boids; i++) {
29		        if (4*i == boid) {
30		        }
31		        if (distance(vec2(in_buffer.data[4*i],in_buffer.data[4*i+1]),pos) < params.one_distance) {
32		            sum += vec2(in_buffer.data[4*i],in_buffer.data[4*i+1]);
33		            amount += 1;
34		        }
35		    }
36		    sum /= amount;
37		    return (sum - pos) / params.one_strength;
38		}
39		
40		vec2 calc_rule_2(uint boid) {
41		    
42		}
43		
44		// The code we want to execute in each invocation
45		void main() {
46		    // gl_GlobalInvocationID.x uniquely identifies this invocation across all work groups
47		    uint index = 4 * gl_GlobalInvocationID.x;
48		    
49		    vec2 rule_1 = calc_rule_1(index);
50		
51		    out_buffer.data[index+2] = clamp(in_buffer.data[index+2] + rule_1.x,-1 * params.boid_speed,params.boid_speed);
52		    out_buffer.data[index+3] = clamp(in_buffer.data[index+3] + rule_1.y,-1 * params.boid_speed,params.boid_speed);
53		    out_buffer.data[index] = in_buffer.data[index] + out_buffer.data[index+2] * 0.01;
54		    out_buffer.data[index+1] = in_buffer.data[index+1] + out_buffer.data[index+3] * 0.01;
55		}
56		
          RDShaderFile                                    RSRC
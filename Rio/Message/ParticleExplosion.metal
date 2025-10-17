//
//  Particle.metal
//  Rio
//
//  Created by Edward Sanchez on 10/17/25.
//

#include <metal_stdlib>
using namespace metal;

// Particle structure
struct Particle {
    float4 position;        // xyz = position, w = unused
    float4 velocity;        // xyz = velocity, w = unused
    float4 color;           // rgba
    float4 custom;          // x = rotation, y = time, z = unused, w = lifetime multiplier
    float4x4 transform;     // particle transform matrix
    bool active;            // is particle active
    float lifetime;         // total lifetime
    uint seed;              // random seed
};

// Uniforms structure
struct ParticleUniforms {
    float spread;
    float inherit_emitter_velocity_ratio;
    float initial_linear_velocity_min;
    float initial_linear_velocity_max;
    float orbit_velocity_min;
    float orbit_velocity_max;
    float radial_velocity_min;
    float radial_velocity_max;
    float linear_accel_min;
    float linear_accel_max;
    float radial_accel_min;
    float radial_accel_max;
    float tangent_accel_min;
    float tangent_accel_max;
    float damping_min;
    float damping_max;
    float scale_min;
    float scale_max;
    float lifetime_randomness;
    float3 emission_shape_offset;
    float3 emission_shape_scale;
    float3 emission_box_extents;
    float3 emitter_velocity;
    float4x4 emission_transform;
    float delta_time;
    float amount_ratio;
    uint random_seed;
    bool restart_position;
    bool restart_velocity;
    bool restart_custom;
    bool restart_rot_scale;
    float interpolate_to_end;
};

// Display parameters
struct DisplayParameters {
    float3 scale;
    float lifetime;
};

// Dynamics parameters
struct DynamicsParameters {
    float initial_velocity_multiplier;
    float radial_velocity;
    float orbit_velocity;
};

// Physical parameters
struct PhysicalParameters {
    float linear_accel;
    float radial_accel;
    float tangent_accel;
    float damping;
};

// Random number generation
float rand_from_seed(thread uint &seed) {
    int k;
    int s = int(seed);
    if (s == 0)
        s = 305420679;
    k = s / 127773;
    s = 16807 * (s - k * 127773) - 2836 * k;
    if (s < 0)
        s += 2147483647;
    seed = uint(s);
    return float(seed % uint(65536)) / 65535.0;
}

float rand_from_seed_m1_p1(thread uint &seed) {
    return rand_from_seed(seed) * 2.0 - 1.0;
}

uint hash(uint x) {
    x = ((x >> uint(16)) ^ x) * uint(73244475);
    x = ((x >> uint(16)) ^ x) * uint(73244475);
    x = (x >> uint(16)) ^ x;
    return x;
}

void calculate_initial_physical_params(thread PhysicalParameters &params, 
                                      thread uint &alt_seed,
                                      constant ParticleUniforms &uniforms) {
    params.linear_accel = mix(uniforms.linear_accel_min, uniforms.linear_accel_max, rand_from_seed(alt_seed));
    params.radial_accel = mix(uniforms.radial_accel_min, uniforms.radial_accel_max, rand_from_seed(alt_seed));
    params.tangent_accel = mix(uniforms.tangent_accel_min, uniforms.tangent_accel_max, rand_from_seed(alt_seed));
    params.damping = mix(uniforms.damping_min, uniforms.damping_max, rand_from_seed(alt_seed));
}

void calculate_initial_dynamics_params(thread DynamicsParameters &params,
                                      thread uint &alt_seed,
                                      constant ParticleUniforms &uniforms) {
    params.initial_velocity_multiplier = mix(uniforms.initial_linear_velocity_min, 
                                            uniforms.initial_linear_velocity_max,
                                            rand_from_seed(alt_seed));
    params.radial_velocity = mix(uniforms.radial_velocity_min, uniforms.radial_velocity_max, rand_from_seed(alt_seed));
    params.orbit_velocity = mix(uniforms.orbit_velocity_min, uniforms.orbit_velocity_max, rand_from_seed(alt_seed));
}

void calculate_initial_display_params(thread DisplayParameters &params,
                                     thread uint &alt_seed,
                                     constant ParticleUniforms &uniforms) {
    float scale_value = mix(uniforms.scale_min, uniforms.scale_max, rand_from_seed(alt_seed));
    params.scale = float3(scale_value);
    params.scale = sign(params.scale) * max(abs(params.scale), 0.001);
    params.lifetime = (1.0 - uniforms.lifetime_randomness * rand_from_seed(alt_seed));
}

float3 calculate_initial_position(thread uint &alt_seed, constant ParticleUniforms &uniforms) {
    float3 pos = float3(rand_from_seed(alt_seed) * 2.0 - 1.0, 
                       rand_from_seed(alt_seed) * 2.0 - 1.0, 
                       rand_from_seed(alt_seed) * 2.0 - 1.0) * uniforms.emission_box_extents;
    return pos * uniforms.emission_shape_scale + uniforms.emission_shape_offset;
}

float3 get_random_direction_from_spread(thread uint &alt_seed, float spread_angle) {
    float pi = 3.14159;
    float degree_to_rad = pi / 180.0;
    float spread_rad = spread_angle * degree_to_rad;
    float angle1_rad = rand_from_seed_m1_p1(alt_seed) * spread_rad;
    float angle2_rad = rand_from_seed_m1_p1(alt_seed) * spread_rad;
    float3 direction_xz = float3(sin(angle1_rad), 0.0, cos(angle1_rad));
    float3 direction_yz = float3(0.0, sin(angle2_rad), cos(angle2_rad));
    direction_yz.z = direction_yz.z / max(0.0001, sqrt(abs(direction_yz.z)));
    float3 spread_direction = float3(direction_xz.x * direction_yz.z, direction_yz.y, direction_xz.z * direction_yz.z);
    float3 direction_nrm = float3(0.0, 0.0, 1.0);
    float3 binormal = cross(float3(0.0, 1.0, 0.0), direction_nrm);
    if (length(binormal) < 0.0001) {
        binormal = float3(0.0, 0.0, 1.0);
    }
    binormal = normalize(binormal);
    float3 normal = cross(binormal, direction_nrm);
    spread_direction = binormal * spread_direction.x + normal * spread_direction.y + direction_nrm * spread_direction.z;
    return spread_direction;
}

float3 process_orbit_displacement(DynamicsParameters param, 
                                 float lifetime,
                                 thread uint &alt_seed,
                                 float4x4 transform,
                                 float4x4 emission_transform,
                                 float delta,
                                 float total_lifetime) {
    if (abs(param.orbit_velocity) < 0.01 || delta < 0.001) {
        return float3(0.0);
    }
    
    float3 displacement = float3(0.0);
    float pi = 3.14159;
    float orbit_amount = param.orbit_velocity;
    if (orbit_amount != 0.0) {
        float3 pos = transform[3].xyz;
        float3 org = emission_transform[3].xyz;
        float3 diff = pos - org;
        float ang = orbit_amount * pi * 2.0 * delta;
        float2x2 rot = float2x2(float2(cos(ang), -sin(ang)), float2(sin(ang), cos(ang)));
        displacement.xy -= diff.xy;
        displacement.xy += rot * diff.xy;
    }
    return (emission_transform * float4(displacement / delta, 0.0)).xyz;
}

float3 process_radial_displacement(DynamicsParameters param,
                                  float lifetime,
                                  thread uint &alt_seed,
                                  float4x4 transform,
                                  float4x4 emission_transform,
                                  float delta) {
    float3 radial_displacement = float3(0.0);
    if (delta < 0.001) {
        return radial_displacement;
    }
    float radial_displacement_multiplier = 1.0;
    if (length(transform[3].xyz) > 0.01) {
        radial_displacement = normalize(transform[3].xyz) * radial_displacement_multiplier * param.radial_velocity;
    } else {
        radial_displacement = get_random_direction_from_spread(alt_seed, 360.0) * param.radial_velocity;
    }
    if (radial_displacement_multiplier * param.radial_velocity < 0.0) {
        if (length(radial_displacement) > 0.01) {
            radial_displacement = normalize(radial_displacement) * 
                                min(abs((radial_displacement_multiplier * param.radial_velocity)), 
                                    length(transform[3].xyz) / delta);
        }
    }
    return radial_displacement;
}

// Compute kernel for particle initialization
kernel void particle_start(device Particle *particles [[buffer(0)]],
                          constant ParticleUniforms &uniforms [[buffer(1)]],
                          texture2d<float> sprite [[texture(0)]],
                          uint id [[thread_position_in_grid]]) {
    
    uint base_number = id;
    uint alt_seed = hash(base_number + uint(1) + uniforms.random_seed);
    
    DisplayParameters params;
    calculate_initial_display_params(params, alt_seed, uniforms);
    
    DynamicsParameters dynamic_params;
    calculate_initial_dynamics_params(dynamic_params, alt_seed, uniforms);
    
    PhysicalParameters physics_params;
    calculate_initial_physical_params(physics_params, alt_seed, uniforms);
    
    if (rand_from_seed(alt_seed) > uniforms.amount_ratio) {
        particles[id].active = false;
        return;
    }
    
    if (uniforms.restart_custom) {
        particles[id].custom = float4(0.0);
        particles[id].custom.w = params.lifetime;
    }
    
    if (uniforms.restart_rot_scale) {
        particles[id].transform[0] = float4(1.0, 0.0, 0.0, 0.0);
        particles[id].transform[1] = float4(0.0, 1.0, 0.0, 0.0);
        particles[id].transform[2] = float4(0.0, 0.0, 1.0, 0.0);
    }
    
    if (uniforms.restart_position) {
        float3 initial_pos = calculate_initial_position(alt_seed, uniforms);
        particles[id].transform[3] = float4(initial_pos, 1.0);
        particles[id].transform = uniforms.emission_transform * particles[id].transform;
    }
    
    if (uniforms.restart_velocity) {
        float3 vel = get_random_direction_from_spread(alt_seed, uniforms.spread) * dynamic_params.initial_velocity_multiplier;
        particles[id].velocity = float4(vel, 0.0);
    }
    
    particles[id].velocity = uniforms.emission_transform * particles[id].velocity;
    particles[id].velocity.xyz += uniforms.emitter_velocity * uniforms.inherit_emitter_velocity_ratio;
    particles[id].velocity.z = 0.0;
    particles[id].transform[3].z = 0.0;
    
    // Sample sprite texture for particle color
    float2 particle_position = particles[id].transform[3].xy;
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    uint2 texture_size = uint2(sprite.get_width(), sprite.get_height());
    float2 uv = particle_position / float2(texture_size) + float2(0.5, 0.5);
    float4 sprite_color = sprite.sample(textureSampler, uv);
    particles[id].color = sprite_color;
    
    // Disable transparent particles
    if (sprite_color.a == 0.0) {
        particles[id].active = false;
    } else {
        particles[id].active = true;
    }
    
    particles[id].lifetime = params.lifetime;
    particles[id].seed = alt_seed;
}

// Compute kernel for particle update
kernel void particle_process(device Particle *particles [[buffer(0)]],
                            constant ParticleUniforms &uniforms [[buffer(1)]],
                            uint id [[thread_position_in_grid]]) {
    
    if (!particles[id].active) {
        return;
    }
    
    uint base_number = id;
    uint alt_seed = hash(base_number + uint(1) + uniforms.random_seed);
    
    DisplayParameters params;
    calculate_initial_display_params(params, alt_seed, uniforms);
    
    DynamicsParameters dynamic_params;
    calculate_initial_dynamics_params(dynamic_params, alt_seed, uniforms);
    
    PhysicalParameters physics_params;
    calculate_initial_physical_params(physics_params, alt_seed, uniforms);
    
    particles[id].custom.y += uniforms.delta_time / particles[id].lifetime;
    particles[id].custom.y = mix(particles[id].custom.y, 1.0, uniforms.interpolate_to_end);
    float lifetime_percent = particles[id].custom.y / params.lifetime;
    
    if (particles[id].custom.y > particles[id].custom.w) {
        particles[id].active = false;
        return;
    }
    
    // Calculate controlled displacement
    float3 controlled_displacement = float3(0.0);
    controlled_displacement += process_orbit_displacement(dynamic_params, lifetime_percent, alt_seed, 
                                                        particles[id].transform, uniforms.emission_transform, 
                                                        uniforms.delta_time, params.lifetime * particles[id].lifetime);
    controlled_displacement += process_radial_displacement(dynamic_params, lifetime_percent, alt_seed, 
                                                          particles[id].transform, uniforms.emission_transform, 
                                                          uniforms.delta_time);
    
    // Apply forces
    float3 force = float3(0.0);
    {
        float3 pos = particles[id].transform[3].xyz;
        float3 velocity = particles[id].velocity.xyz;
        
        // Apply linear acceleration
        force += length(velocity) > 0.0 ? normalize(velocity) * physics_params.linear_accel : float3(0.0);
        
        // Apply radial acceleration
        float3 org = uniforms.emission_transform[3].xyz;
        float3 diff = pos - org;
        force += length(diff) > 0.0 ? normalize(diff) * physics_params.radial_accel : float3(0.0);
        
        // Apply tangential acceleration
        float tangent_accel_val = physics_params.tangent_accel;
        force += length(diff.yx) > 0.0 ? float3(normalize(diff.yx * float2(-1.0, 1.0)), 0.0) * tangent_accel_val : float3(0.0);
        
        force.z = 0.0;
        particles[id].velocity.xyz += force * uniforms.delta_time;
    }
    
    // Apply damping
    {
        if (physics_params.damping > 0.0) {
            float v = length(particles[id].velocity.xyz);
            v -= physics_params.damping * uniforms.delta_time;
            if (v < 0.0) {
                particles[id].velocity.xyz = float3(0.0);
            } else {
                particles[id].velocity.xyz = normalize(particles[id].velocity.xyz) * v;
            }
        }
    }
    
    // Calculate final velocity
    float3 final_velocity = controlled_displacement + particles[id].velocity.xyz;
    final_velocity.z = 0.0;
    particles[id].transform[3].xyz += final_velocity * uniforms.delta_time;
    
    // Update rotation matrix
    float rotation = particles[id].custom.x;
    particles[id].transform[0] = float4(cos(rotation), -sin(rotation), 0.0, 0.0);
    particles[id].transform[1] = float4(sin(rotation), cos(rotation), 0.0, 0.0);
    particles[id].transform[2] = float4(0.0, 0.0, 1.0, 0.0);
    particles[id].transform[3].z = 0.0;
    
    // Apply scale
    particles[id].transform[0].xyz *= sign(params.scale.x) * max(abs(params.scale.x), 0.001);
    particles[id].transform[1].xyz *= sign(params.scale.y) * max(abs(params.scale.y), 0.001);
    particles[id].transform[2].xyz *= sign(params.scale.z) * max(abs(params.scale.z), 0.001);
    
    if (particles[id].custom.y > particles[id].custom.w) {
        particles[id].active = false;
    }
    
    // Fade out pixels as time progresses
    if (particles[id].color.a > 0.0) {
        particles[id].color.a -= 1.0 / particles[id].lifetime * uniforms.delta_time;
    }
}

// Vertex shader for rendering particles
struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float4 color;
};

vertex VertexOut particle_vertex(VertexIn in [[stage_in]],
                                 constant Particle *particles [[buffer(0)]],
                                 constant float4x4 &viewProjection [[buffer(1)]],
                                 uint instanceID [[instance_id]]) {
    
    VertexOut out;
    
    if (!particles[instanceID].active) {
        out.position = float4(0.0);
        out.color = float4(0.0);
        return out;
    }
    
    float4 worldPos = particles[instanceID].transform * float4(in.position, 0.0, 1.0);
    out.position = viewProjection * worldPos;
    out.texCoord = in.texCoord;
    out.color = particles[instanceID].color;
    
    return out;
}

// Fragment shader for rendering particles
fragment float4 particle_fragment(VertexOut in [[stage_in]],
                                  texture2d<float> texture [[texture(0)]]) {
    
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    float4 color = texture.sample(textureSampler, in.texCoord);
    return color * in.color;
}

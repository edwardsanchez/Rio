//
// ThoughtBubbleDissolve.metal
// Rio
//
// A Thanos-like dissolve effect that breaks a view into circular particles
// that gently explode and disperse like a soap bubble bursting or vapor cloud.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - Noise Functions

/// Simple hash function for pseudo-random values
static float tb_hash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

/// 2D value noise
static float tb_noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    
    // Four corners in 2D
    float a = tb_hash(i);
    float b = tb_hash(i + float2(1.0, 0.0));
    float c = tb_hash(i + float2(0.0, 1.0));
    float d = tb_hash(i + float2(1.0, 1.0));
    
    // Smooth interpolation
    float2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

/// Fractional Brownian Motion - layered noise for organic patterns
static float tb_fbm(float2 p, int octaves) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < octaves; i++) {
        value += amplitude * tb_noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}

/// Curl noise - creates swirling, turbulent motion like steam
static float2 tb_curlNoise(float2 p, float time) {
    float eps = 0.01;
    
    // Sample noise at offset positions to compute gradient
    float n = tb_fbm(p + float2(time * 0.1, 0.0), 3);
    float nx = tb_fbm(p + float2(eps, 0.0) + float2(time * 0.1, 0.0), 3);
    float ny = tb_fbm(p + float2(0.0, eps) + float2(time * 0.1, 0.0), 3);
    
    // Compute curl (perpendicular to gradient)
    float2 grad = float2(nx - n, ny - n) / eps;
    return float2(-grad.y, grad.x);
}

// MARK: - Main Shader

/// A shader that dissolves a view into circular particles that disperse like vapor.
///
/// The effect creates a gentle explosion where particles drift away with wind,
/// turbulence, and gravity, eventually fading to complete transparency.
///
/// - Parameter position: The user-space coordinate of the current pixel.
/// - Parameter layer: The SwiftUI layer we're reading from.
/// - Parameter progress: Animation progress from 0 to 1.
/// - Parameter time: Current time for animated turbulence.
/// - Parameter particleSize: Base radius of circular particles in pixels.
/// - Parameter sizeVariation: Random variation in particle sizes (0 to 1).
/// - Parameter speed: Overall movement speed multiplier.
/// - Parameter windX: Wind direction X component.
/// - Parameter windY: Wind direction Y component.
/// - Parameter turbulence: Intensity of swirling, turbulent motion (0 to 1).
/// - Parameter burstStrength: Initial explosion force from center.
/// - Parameter fadeSpeed: How quickly particles fade out (higher = faster).
/// - Parameter gravity: Downward gravitational pull.
/// - Parameter layerWidth: Width of the view in pixels.
/// - Parameter layerHeight: Height of the view in pixels.
/// - Returns: The color of the pixel, with particles dissolving over time.
[[ stitchable ]] half4 thoughtBubbleDissolve(
    float2 position,
    SwiftUI::Layer layer,
    float progress,
    float time,
    float particleSize,
    float sizeVariation,
    float speed,
    float windX,
    float windY,
    float turbulence,
    float burstStrength,
    float fadeSpeed,
    float gravity,
    float layerWidth,
    float layerHeight
) {
    // Early exit if animation complete
    if (progress >= 1.0) {
        return half4(0.0);
    }
    
    // Calculate UV coordinates (0 to 1)
    float2 size = float2(layerWidth, layerHeight);
    float2 uv = position / size;
    
    // Determine particle grid cell
    float cellSize = particleSize * 2.0;
    float2 cellCoord = floor(position / cellSize);
    float2 cellCenter = (cellCoord + 0.5) * cellSize;
    
    // Add random jitter to cell center so particles don't look grid-aligned
    float2 jitter = (float2(tb_hash(cellCoord), tb_hash(cellCoord + float2(7.3, 3.1))) - 0.5) * cellSize * 0.6;
    cellCenter += jitter;
    
    // Per-particle random values
    float particleRand1 = tb_hash(cellCoord);
    float particleRand2 = tb_hash(cellCoord + float2(12.3, 45.6));
    float particleRand3 = tb_hash(cellCoord + float2(78.9, 23.4));
    
    // Calculate this particle's size with variation
    float radius = particleSize * mix(1.0 - sizeVariation, 1.0 + sizeVariation, particleRand1);
    
    // Staggered activation: particles start dissolving at different times
    // based on distance from center and random offset
    float2 centerPos = size * 0.5;
    float distFromCenter = length(cellCenter - centerPos) / length(size);
    float activationDelay = distFromCenter * 0.3 + particleRand2 * 0.2;
    float particleProgress = saturate((progress - activationDelay) / (1.0 - activationDelay * 0.5));
    
    // Don't render if particle hasn't activated yet
    if (particleProgress <= 0.0) {
        return layer.sample(position);
    }
    
    // Easing function for smooth pop and drift
    float eased = smoothstep(0.0, 1.0, particleProgress);
    
    // Calculate particle displacement
    float2 displacement = float2(0.0);
    
    // 1. Initial burst: radial explosion from center
    float2 burstDir = normalize(cellCenter - centerPos);
    displacement += burstDir * burstStrength * eased * (1.0 - particleProgress * 0.5);
    
    // 2. Wind direction (scale up for more visible effect)
    float2 wind = float2(windX, windY);
    displacement += wind * speed * particleProgress * 2.0;
    
    // 3. Curl turbulence for steam-like swirls
    float2 turbulenceOffset = tb_curlNoise(cellCenter / size * 5.0, time + particleRand3 * 10.0);
    displacement += turbulenceOffset * turbulence * 50.0 * eased;
    
    // 4. Gravity (downward pull - scale up for more visible effect)
    displacement.y += gravity * 80.0 * particleProgress * particleProgress;
    
    // 5. Additional upward drift for light particles (like warm air rising)
    // Reduced intensity so it doesn't overpower gravity
    float thermalRise = (1.0 - particleRand1) * 10.0 * particleProgress;
    displacement.y -= thermalRise;
    
    // Apply displacement to particle center
    float2 particleCenter = cellCenter + displacement;
    
    // Calculate distance from current pixel to particle center
    float dist = distance(position, particleCenter);
    
    // Check if we're inside this particle
    if (dist <= radius) {
        // Sample the original layer at the particle's original cell center
        // This makes the texture "stick" to the particle as it moves
        half4 color = layer.sample(cellCenter);
        
        // Soft edge falloff
        float edgeFactor = 1.0 - smoothstep(radius * 0.6, radius, dist);
        
        // Fade out over particle lifetime
        float fade = 1.0;
        
        // Gentle fade in at start
        if (particleProgress < 0.1) {
            fade *= smoothstep(0.0, 0.1, particleProgress);
        }
        
        // Accelerated fade out at end
        // Higher fadeSpeed values = faster fade (as expected)
        float fadeStart = 0.4;
        if (particleProgress > fadeStart) {
            float fadeProgress = (particleProgress - fadeStart) / (1.0 - fadeStart);
            fade *= 1.0 - pow(fadeProgress, fadeSpeed);
        }
        
        // Final fade at very end to ensure complete dissolution
        fade *= 1.0 - smoothstep(0.9, 1.0, progress);
        
        // Combine all alpha factors
        color.a *= fade * edgeFactor;
        
        return color;
    }
    
    // Pixel not in any particle - return transparent
    return half4(0.0);
}


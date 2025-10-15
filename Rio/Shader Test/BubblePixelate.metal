//
//  BubblePixelate.metal
//  Rio
//
//  Created by Edward Sanchez on 10/15/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Simple 2D noise function for turbulence
float noise2D(float2 p) {
    return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453123);
}

/// Smooth turbulence using multi-octave noise
float2 turbulence2D(float2 p, float time) {
    // Layer multiple octaves of noise for more natural turbulence
    float2 turb = float2(0.0);
    
    // First octave - large swirls
    float2 p1 = p * 0.05 + float2(time * 0.3, time * 0.2);
    turb.x += (noise2D(p1) - 0.5) * 2.0;
    turb.y += (noise2D(p1 + float2(17.3, 29.7)) - 0.5) * 2.0;
    
    // Second octave - medium details
    float2 p2 = p * 0.1 + float2(time * 0.5, time * 0.4);
    turb.x += (noise2D(p2) - 0.5) * 1.0;
    turb.y += (noise2D(p2 + float2(31.4, 47.2)) - 0.5) * 1.0;
    
    // Third octave - fine details
    float2 p3 = p * 0.2 + float2(time * 0.8, time * 0.6);
    turb.x += (noise2D(p3) - 0.5) * 0.5;
    turb.y += (noise2D(p3 + float2(53.7, 67.9)) - 0.5) * 0.5;
    
    return turb;
}

/// Pixelation effect that transitions from square to circular pixels and explodes
[[ stitchable ]] half4 pixelate(
    float2 position,
    SwiftUI::Layer layer,
    float pixelSize,
    float2 layerSize,
    float explosionSpacing,
    float2 explosionCenter,
    float speedVariance,
    float gravity,
    float turbulence,
    float growth,
    float growthVariance
) {
    // Calculate the center of the explosion (as percentage of layer size)
    float2 layerCenter = layerSize * explosionCenter;
    
    float2 offsetFromCenter = position - layerCenter;
    float distanceFromCenter = length(offsetFromCenter);
    
    // Iterative inverse mapping with speed variance, gravity, and turbulence convergence
    // Start with a guess, compute its speed variance, refine the inverse
    float2 invPosition = position;
    if (distanceFromCenter > 0.001 && explosionSpacing > 0.001) {
        // Initial guess ignoring variance, gravity, and turbulence
        invPosition = layerCenter + (offsetFromCenter / (1.0 + explosionSpacing));
        
        // Refine with 4 iterations to account for speed variance, gravity, and turbulence
        for (int iter = 0; iter < 4; iter++) {
            float2 guessBlockPos = floor(invPosition / pixelSize) * pixelSize;
            float2 guessBlockCenter = guessBlockPos + (pixelSize * 0.5);
            
            // Use fixed seed grid to prevent hash changes during pixelSize animation
            float2 seedBlockCenter = floor(invPosition / 2.0) * 2.0 + 1.0;
            float guessSeed = fract(sin(dot(seedBlockCenter, float2(12.9898, 78.233))) * 43758.5453);
            float guessSpeedMult = 1.0 + (guessSeed * 2.0 - 1.0) * speedVariance;
            
            // Calculate expected gravity offset for this block
            float2 guessOffset = guessBlockCenter - layerCenter;
            float guessDistance = length(guessOffset);
            float guessGravityOffset = explosionSpacing * guessDistance * gravity * 0.8;
            
            // Calculate expected turbulence offset for this block
            float2 guessTurbulenceOffset = float2(0.0);
            if (turbulence > 0.001) {
                float turbulenceTime = explosionSpacing * 15.0;
                float2 turbulenceDir = turbulence2D(guessBlockCenter, turbulenceTime);
                float turbulenceAmount = turbulence * explosionSpacing * 30.0;
                guessTurbulenceOffset = turbulenceDir * turbulenceAmount;
            }
            
            // Refine inverse by removing explosion, gravity, and turbulence effects
            float2 positionWithoutEffects = position;
            positionWithoutEffects.y -= guessGravityOffset;
            positionWithoutEffects -= guessTurbulenceOffset;
            float2 offsetWithoutEffects = positionWithoutEffects - layerCenter;
            invPosition = layerCenter + (offsetWithoutEffects / (1.0 + explosionSpacing * guessSpeedMult));
        }
    }
    
    // Determine the original block from the refined inverse-mapped position
    float2 blockPos = floor(invPosition / pixelSize) * pixelSize;
    float2 originalBlockCenter = blockPos + (pixelSize * 0.5);
    
    // Use a FIXED grid for seeding to prevent hash changes during pixelSize animation
    const float seedPixelSize = 2.0; // Match the final pixelSize value
    float2 seedBlockPos = floor(invPosition / seedPixelSize) * seedPixelSize;
    float2 seedBlockCenter = seedBlockPos + (seedPixelSize * 0.5);
    
    // Derive the speed multiplier from the stable seed grid
    float seed = fract(sin(dot(seedBlockCenter, float2(12.9898, 78.233))) * 43758.5453);
    float speedMult = 1.0 + (seed * 2.0 - 1.0) * speedVariance;
    
    // Calculate growth multiplier for this particle
    // Use a different seed offset for growth to get independent variation
    float growthSeed = fract(sin(dot(seedBlockCenter, float2(73.156, 41.923))) * 37281.6547);
    // Base growth increases with explosion progress
    float baseGrowth = 1.0 + (growth * explosionSpacing);
    // Apply variance: starts minimal, increases with explosion progress
    // Variance effect scales with explosionSpacing so it's subtle at first
    float varianceAmount = growthVariance * explosionSpacing;
    float growthVariation = 1.0 + (growthSeed * 2.0 - 1.0) * varianceAmount;
    float growthMult = baseGrowth * growthVariation;
    
    // Compute exploded center for this specific block
    float2 blockOffset = originalBlockCenter - layerCenter;
    float blockDistance = length(blockOffset);
    float2 explodedBlockCenter = originalBlockCenter;
    if (blockDistance > 0.001 && explosionSpacing > 0.001) {
        float2 blockDir = blockOffset / blockDistance;
        explodedBlockCenter = originalBlockCenter + (blockDir * blockDistance * explosionSpacing * speedMult);
        
        // Apply turbulence - increases with explosion progress (like wind affecting smoke/steam)
        if (turbulence > 0.001) {
            // Use the original block position as seed for turbulence to keep it stable per particle
            // Use explosionSpacing as "time" - particles drift more as they travel further
            float turbulenceTime = explosionSpacing * 15.0; // Scale for visible effect
            float2 turbulenceOffset = turbulence2D(originalBlockCenter, turbulenceTime);
            
            // Scale turbulence by distance traveled and turbulence strength
            // Particles that have traveled further are affected more by turbulence
            float turbulenceAmount = turbulence * explosionSpacing * 30.0;
            explodedBlockCenter += turbulenceOffset * turbulenceAmount;
        }
        
        // Apply gravity effect - particles that travel further fall more
        // Gravity increases with distance traveled (flight time)
        // explosionSpacing acts as "time" in the animation
        float gravityFall = explosionSpacing * blockDistance * gravity * 0.8;
        explodedBlockCenter.y += gravityFall;
    }
    
    // Sample color from the original block center
    half4 color = layer.sample(originalBlockCenter);
    
    // Step 4: Check if current pixel is within the circle at the EXPLODED position
    float2 offsetFromExplodedCenter = position - explodedBlockCenter;
    float distanceFromExplodedCenter = length(offsetFromExplodedCenter);
    
    // Calculate blend factor: 0 = square, 1 = circle
    float blendFactor = smoothstep(0.1, 2.0, pixelSize);
    
    // Circle radius is half the block size, scaled by growth
    float baseRadius = pixelSize * 0.5;
    float radius = baseRadius * growthMult;
    
    // Antialiased circle edge using screen-space derivative
    float edge = radius - distanceFromExplodedCenter;
    float aaWidth = fwidth(edge);
    float circleCoverage = smoothstep(-aaWidth, aaWidth, edge);
    
    // Blend between square (1.0) and circle coverage based on blendFactor
    float alphaBlend = mix(1.0, circleCoverage, clamp(blendFactor, 0.0, 1.0));
    color.a *= half(alphaBlend);
    
    return color;
}


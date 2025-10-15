//
//  BubblePixelate.metal
//  Rio
//
//  Created by Edward Sanchez on 10/15/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Pixelation effect that transitions from square to circular pixels and explodes
[[ stitchable ]] half4 pixelate(
    float2 position,
    SwiftUI::Layer layer,
    float pixelSize,
    float2 layerSize,
    float explosionSpacing,
    float2 explosionCenter,
    float speedVariance
) {
    // Calculate the center of the explosion (as percentage of layer size)
    float2 layerCenter = layerSize * explosionCenter;
    
    // Step 1: Find which block this pixel would belong to in the ORIGINAL (non-exploded) layout
    // We need to reverse-map: where would this pixel come from if particles are spaced out?
    
    float2 offsetFromCenter = position - layerCenter;
    float distanceFromCenter = length(offsetFromCenter);
    
    // Reverse the spacing to find the original position
    float2 originalPosition = position;
    if (distanceFromCenter > 0.001 && explosionSpacing > 0.001) {
        // Move back toward center by the explosion spacing amount
        originalPosition = layerCenter + (offsetFromCenter / (1.0 + explosionSpacing));
    }
    
    // Find which block the original position belongs to
    float2 blockPosition = floor(originalPosition / pixelSize) * pixelSize;
    float2 originalBlockCenter = blockPosition + (pixelSize * 0.5);
    
    // Generate deterministic random value for this particle based on its block position
    // Simple hash function to get a pseudo-random value between 0 and 1
    float particleSeed = fract(sin(dot(originalBlockCenter, float2(12.9898, 78.233))) * 43758.5453);
    
    // Calculate speed multiplier: ranges from (1.0 - speedVariance) to (1.0 + speedVariance)
    // speedVariance of 0.0 = no variance (all particles move at same speed)
    // speedVariance of 0.5 = particles can be 50% slower or 50% faster
    float speedMultiplier = 1.0 + (particleSeed * 2.0 - 1.0) * speedVariance;
    
    // Step 2: Calculate where this block center moves to with explosion
    float2 blockOffsetFromCenter = originalBlockCenter - layerCenter;
    float blockDistanceFromCenter = length(blockOffsetFromCenter);
    
    float2 explodedBlockCenter = originalBlockCenter;
    if (blockDistanceFromCenter > 0.001 && explosionSpacing > 0.001) {
        float2 blockDirection = blockOffsetFromCenter / blockDistanceFromCenter;
        // Move block center away from layer center, applying speed variance
        explodedBlockCenter = originalBlockCenter + (blockDirection * blockDistanceFromCenter * explosionSpacing * speedMultiplier);
    }
    
    // Step 3: Sample color from the original block center
    half4 color = layer.sample(originalBlockCenter);
    
    // Step 4: Check if current pixel is within the circle at the EXPLODED position
    float2 offsetFromExplodedCenter = position - explodedBlockCenter;
    float distanceFromExplodedCenter = length(offsetFromExplodedCenter);
    
    // Calculate blend factor: 0 = square, 1 = circle
    float blendFactor = smoothstep(0.1, 2.0, pixelSize);
    
    // Circle radius is half the block size
    float radius = pixelSize * 0.5;
    
    // For circles, check if we're inside
    if (blendFactor > 0.01) {
        // Apply circular masking
        if (distanceFromExplodedCenter > radius) {
            // Outside the circle - fade out based on blend factor
            float alpha = 1.0 - blendFactor;
            color.a *= alpha;
        }
    }
    
    return color;
}


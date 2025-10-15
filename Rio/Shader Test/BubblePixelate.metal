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
    float speedVariance,
    float gravity
) {
    // Calculate the center of the explosion (as percentage of layer size)
    float2 layerCenter = layerSize * explosionCenter;
    
    float2 offsetFromCenter = position - layerCenter;
    float distanceFromCenter = length(offsetFromCenter);
    
    // Iterative inverse mapping with speed variance and gravity convergence
    // Start with a guess, compute its speed variance, refine the inverse
    float2 invPosition = position;
    if (distanceFromCenter > 0.001 && explosionSpacing > 0.001) {
        // Initial guess ignoring variance and gravity
        invPosition = layerCenter + (offsetFromCenter / (1.0 + explosionSpacing));
        
        // Refine with 3 iterations to account for speed variance and gravity
        for (int iter = 0; iter < 3; iter++) {
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
            
            // Refine inverse by removing both explosion and gravity effects
            float2 positionWithoutGravity = position;
            positionWithoutGravity.y -= guessGravityOffset;
            float2 offsetWithoutGravity = positionWithoutGravity - layerCenter;
            invPosition = layerCenter + (offsetWithoutGravity / (1.0 + explosionSpacing * guessSpeedMult));
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
    
    // Compute exploded center for this specific block
    float2 blockOffset = originalBlockCenter - layerCenter;
    float blockDistance = length(blockOffset);
    float2 explodedBlockCenter = originalBlockCenter;
    if (blockDistance > 0.001 && explosionSpacing > 0.001) {
        float2 blockDir = blockOffset / blockDistance;
        explodedBlockCenter = originalBlockCenter + (blockDir * blockDistance * explosionSpacing * speedMult);
        
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
    
    // Circle radius is half the block size
    float radius = pixelSize * 0.5;
    
    // Antialiased circle edge using screen-space derivative
    float edge = radius - distanceFromExplodedCenter;
    float aaWidth = fwidth(edge);
    float circleCoverage = smoothstep(-aaWidth, aaWidth, edge);
    
    // Blend between square (1.0) and circle coverage based on blendFactor
    float alphaBlend = mix(1.0, circleCoverage, clamp(blendFactor, 0.0, 1.0));
    color.a *= half(alphaBlend);
    
    return color;
}


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
    
    float2 offsetFromCenter = position - layerCenter;
    float distanceFromCenter = length(offsetFromCenter);
    
    // Make an initial guess for the original position
    float2 guessPosition = position;
    if (distanceFromCenter > 0.001 && explosionSpacing > 0.001) {
        guessPosition = layerCenter + (offsetFromCenter / (1.0 + explosionSpacing));
    }
    
    // Find the approximate block
    float2 guessBlockPos = floor(guessPosition / pixelSize) * pixelSize;
    float2 guessBlockCenter = guessBlockPos + (pixelSize * 0.5);
    
    // Search in a 3x3 grid around the guessed block to find the closest exploded particle
    float closestDistance = 999999.0;
    float2 closestOriginalCenter = guessBlockCenter;
    float2 closestExplodedCenter = guessBlockCenter;
    half4 closestColor = half4(0.0);
    
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            // Calculate the original block center for this neighbor
            float2 testBlockCenter = guessBlockCenter + float2(float(dx) * pixelSize, float(dy) * pixelSize);
            
            // Get speed multiplier for this particle
            float testSeed = fract(sin(dot(testBlockCenter, float2(12.9898, 78.233))) * 43758.5453);
            float testSpeedMult = 1.0 + (testSeed * 2.0 - 1.0) * speedVariance;
            
            // Calculate where this particle explodes to
            float2 testOffset = testBlockCenter - layerCenter;
            float testDistance = length(testOffset);
            
            float2 testExplodedCenter = testBlockCenter;
            if (testDistance > 0.001 && explosionSpacing > 0.001) {
                float2 testDirection = testOffset / testDistance;
                testExplodedCenter = testBlockCenter + (testDirection * testDistance * explosionSpacing * testSpeedMult);
            }
            
            // Check distance from current position to this exploded particle
            float dist = length(position - testExplodedCenter);
            
            if (dist < closestDistance) {
                closestDistance = dist;
                closestOriginalCenter = testBlockCenter;
                closestExplodedCenter = testExplodedCenter;
            }
        }
    }
    
    // Use the closest particle
    float2 originalBlockCenter = closestOriginalCenter;
    float2 explodedBlockCenter = closestExplodedCenter;
    
    // Sample color from the original block center
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


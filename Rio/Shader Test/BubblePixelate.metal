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
    (void)time; // Keep signature stable; turbulence is static in time to avoid per-frame flicker
    // Layer multiple octaves of noise for more natural turbulence
    float2 turb = float2(0.0);
    
    // First octave - large swirls
    float2 p1 = p * 0.05;
    turb.x += (noise2D(p1) - 0.5) * 2.0;
    turb.y += (noise2D(p1 + float2(17.3, 29.7)) - 0.5) * 2.0;
    
    // Second octave - medium details
    float2 p2 = p * 0.1;
    turb.x += (noise2D(p2) - 0.5) * 1.0;
    turb.y += (noise2D(p2 + float2(31.4, 47.2)) - 0.5) * 1.0;
    
    // Third octave - fine details
    float2 p3 = p * 0.2;
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
    float growthVariance,
    float edgeVelocityBoost,
    float forceSquarePixels,
    float animationProgress,
    float fadeStart,
    float fadeVariance,
    float pinchDuration
) {
    // Calculate the center of the explosion (as percentage of layer size)
    float2 layerCenter = layerSize * explosionCenter;
    float maxDistance = length(layerSize * 0.5);
    
    // Apply pinch effect at the start of animation
    // Pinch toward the explosion center for the first pinchDuration% of animation
    float2 pinchPosition = position;
    if (animationProgress < pinchDuration) {
        // Calculate pinch intensity (0.95 = 5% smaller at peak)
        float pinchIntensity = 1.2;
        // Gradually increase pinch from 1.0 to pinchIntensity over the pinch duration
        float pinchProgress = animationProgress / pinchDuration;
        float currentPinch = 1.0 - (1.0 - pinchIntensity) * pinchProgress;
        
        // Scale position toward the explosion center
        float2 offsetFromExplosionCenter = position - layerCenter;
        pinchPosition = layerCenter + offsetFromExplosionCenter * currentPinch;
    }
    
    float2 offsetFromCenter = pinchPosition - layerCenter;
    float distanceFromCenter = length(offsetFromCenter);
    
    // Iterative inverse mapping with speed variance, gravity, and turbulence convergence
    // Start with a guess, compute its speed variance, refine the inverse
    float2 invPosition = pinchPosition;
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
            float guessNormalizedDistance = (maxDistance > 0.001) ? clamp(guessDistance / maxDistance, 0.0, 1.0) : 0.0;
            float guessEdgeFactor = 1.0 + edgeVelocityBoost * guessNormalizedDistance * guessNormalizedDistance;
            float guessGravityOffset = explosionSpacing * guessDistance * gravity * 0.8;
            
            // Calculate expected turbulence offset for this block
            float2 guessTurbulenceOffset = float2(0.0);
            if (turbulence > 0.001) {
                // Sample the same static turbulence field used during the forward pass
                float turbulenceTime = 0.0;
                float2 turbulenceDir = turbulence2D(guessBlockCenter, turbulenceTime);
                float turbulenceAmount = turbulence * explosionSpacing * 30.0 * guessEdgeFactor;
                guessTurbulenceOffset = turbulenceDir * turbulenceAmount;
            }
            
            // Refine inverse by removing explosion, gravity, and turbulence effects
            float2 positionWithoutEffects = pinchPosition;
            positionWithoutEffects.y -= guessGravityOffset;
            positionWithoutEffects -= guessTurbulenceOffset;
            float2 offsetWithoutEffects = positionWithoutEffects - layerCenter;
            float effectiveExplosion = explosionSpacing * guessSpeedMult * guessEdgeFactor;
            invPosition = layerCenter + (offsetWithoutEffects / (1.0 + effectiveExplosion));
        }
    }
    
    // Determine the original block from the refined inverse-mapped position
    float2 baseBlockPos = floor(invPosition / pixelSize) * pixelSize;
    
    // Use a FIXED grid for seeding to prevent hash changes during pixelSize animation
    const float seedPixelSize = 2.0; // Match the final pixelSize value
    
    float bestPixelDistance = 1e9;
    float2 bestOriginalBlockCenter = baseBlockPos + (pixelSize * 0.5);
    float2 bestSeedBlockCenter = floor(bestOriginalBlockCenter / seedPixelSize) * seedPixelSize + (seedPixelSize * 0.5);
    float2 explodedBlockCenter = bestOriginalBlockCenter;
    
    // Search neighboring blocks to find the exploded particle whose center is closest to this pixel.
    // This prevents clipping artifacts when turbulence or variance pushes particles across cell boundaries.
    for (int y = -2; y <= 2; ++y) {
        for (int x = -2; x <= 2; ++x) {
            float2 candidateBlockPos = baseBlockPos + float2(x, y) * pixelSize;
            float2 candidateCenter = candidateBlockPos + (pixelSize * 0.5);
            
            float2 candidateSeedBlockPos = floor(candidateCenter / seedPixelSize) * seedPixelSize;
            float2 candidateSeedBlockCenter = candidateSeedBlockPos + (seedPixelSize * 0.5);
            
            float candidateSeed = fract(sin(dot(candidateSeedBlockCenter, float2(12.9898, 78.233))) * 43758.5453);
            float candidateSpeedMult = 1.0 + (candidateSeed * 2.0 - 1.0) * speedVariance;
            
            float2 candidateOffset = candidateCenter - layerCenter;
            float candidateDistance = length(candidateOffset);
            float candidateNormalizedDistance = (maxDistance > 0.001) ? clamp(candidateDistance / maxDistance, 0.0, 1.0) : 0.0;
            float candidateEdgeFactor = 1.0 + edgeVelocityBoost * candidateNormalizedDistance * candidateNormalizedDistance;
            float2 candidateExplodedCenter = candidateCenter;
            
            if (candidateDistance > 0.001 && explosionSpacing > 0.001) {
                float safeDistance = max(candidateDistance, 1e-5);
                float2 candidateDir = candidateOffset / safeDistance;
                candidateExplodedCenter = candidateCenter + (candidateDir * candidateDistance * explosionSpacing * candidateSpeedMult * candidateEdgeFactor);
                
                if (turbulence > 0.001) {
                    // Sample a static turbulence field so particles drift consistently between frames
                    float turbulenceTime = 0.0;
                    float2 turbulenceOffset = turbulence2D(candidateCenter, turbulenceTime);
                    float turbulenceAmount = turbulence * explosionSpacing * 30.0 * candidateEdgeFactor;
                    candidateExplodedCenter += turbulenceOffset * turbulenceAmount;
                }
                
                float gravityFall = explosionSpacing * candidateDistance * gravity * 0.8;
                candidateExplodedCenter.y += gravityFall;
            }
            
            float pixelDistance = length(pinchPosition - candidateExplodedCenter);
            if (pixelDistance < bestPixelDistance) {
                bestPixelDistance = pixelDistance;
                bestOriginalBlockCenter = candidateCenter;
                bestSeedBlockCenter = candidateSeedBlockCenter;
                explodedBlockCenter = candidateExplodedCenter;
            }
        }
    }
    
    // Calculate growth multiplier for this particle using the best matching seed center
    float growthSeed = fract(sin(dot(bestSeedBlockCenter, float2(73.156, 41.923))) * 37281.6547);
    float baseGrowth = 1.0 + (growth * explosionSpacing);
    float varianceAmount = growthVariance * explosionSpacing;
    float growthVariation = 1.0 + (growthSeed * 2.0 - 1.0) * varianceAmount;
    float growthMult = baseGrowth * growthVariation;
    
    // Sample color from the original block center
    half4 color = layer.sample(bestOriginalBlockCenter);
    
    // Step 4: Check if current pixel is within the circle at the EXPLODED position
    float2 offsetFromExplodedCenter = pinchPosition - explodedBlockCenter;
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
    bool useSquarePixels = forceSquarePixels > 0.5;
    float alphaBlend = useSquarePixels ? 1.0 : mix(1.0, circleCoverage, clamp(blendFactor, 0.0, 1.0));
    color.a *= half(alphaBlend);
    
    // Calculate per-particle fade-out
    // Generate a unique fade seed for each particle
    float fadeSeed = fract(sin(dot(bestSeedBlockCenter, float2(91.237, 58.164))) * 28491.3721);
    
    // Calculate when this specific particle should start fading
    // The variance is scaled by (1.0 - fadeStart) to ensure all particles reach full transparency by animationProgress = 1.0
    float particleFadeStart = fadeStart + (fadeSeed - 0.5) * fadeVariance * (1.0 - fadeStart);
    
    // Calculate fade opacity using smoothstep for a smooth fade
    float fadeOpacity = 1.0 - smoothstep(particleFadeStart, 1.0, animationProgress);
    
    // Apply fade to the final color alpha
    color.a *= half(fadeOpacity);
    
    return color;
}

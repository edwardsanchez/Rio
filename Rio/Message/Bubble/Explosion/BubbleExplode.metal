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
[[ stitchable ]] half4 explode(
                               float2 position,
                               SwiftUI::Layer layer,
                               float pixelSize,
                               float2 layerSize,
                               float rawAnimationProgress,
                               float2 explosionCenter,
                               float speedVariance,
                               float gravity,
                               float turbulence,
                               float growth,
                               float growthVariance,
                               float edgeVelocityBoost,
                               float forceSquarePixels,
                               float maxExplosionSpread,
                               float fadeStart,
                               float fadeVariance,
                               float pinchDuration
                               ) {
    // Calculate all derived values in the shader to ensure consistency
    float animationProgress = rawAnimationProgress;
    
    // Particleization is gated by explosion start; pixelSize is provided by the caller
    const float circleFormationEnd = 0.05;
    
    // Calculate explosion amount based on animation progress
    float explosionSpacing;
    if (animationProgress <= circleFormationEnd) {
        explosionSpacing = 0.0;
    } else {
        float explosionProgress = (animationProgress - circleFormationEnd) / (1.0 - circleFormationEnd);
        explosionSpacing = explosionProgress * maxExplosionSpread;
    }
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
    
    // If explosion hasn't started yet, return original sample at pinched position (no particles yet)
    if (explosionSpacing <= 0.001) {
        return layer.sample(pinchPosition);
    }
    
    float2 offsetFromCenter = pinchPosition - layerCenter;
    float distanceFromCenter = length(offsetFromCenter);
    
    // Iterative inverse mapping with speed variance, gravity, and turbulence convergence
    // Start with a guess, compute its speed variance, refine the inverse
    float2 invPosition = pinchPosition;
    if (distanceFromCenter > 0.001 && explosionSpacing > 0.001) {
        // Initial guess ignoring variance, gravity, and turbulence
        invPosition = layerCenter + (offsetFromCenter / (1.0 + explosionSpacing));
        
        // Refine with 8 iterations to account for speed variance, gravity, and turbulence
        for (int iter = 0; iter < 8; iter++) {
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
                // Start turbulence at a stronger baseline (~30% of full spread)
                float baselineFraction = 0.30;
                float effectiveExplosionForTurbulence = (maxExplosionSpread > 0.001) ? max(explosionSpacing, baselineFraction * maxExplosionSpread) : explosionSpacing;
                float turbulenceAmount = turbulence * effectiveExplosionForTurbulence * 30.0 * guessEdgeFactor;
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
    
    // Track top 3 closest particles for blending
    const int maxBlendParticles = 3;
    float particleDistances[maxBlendParticles];
    float2 particleOriginalCenters[maxBlendParticles];
    float2 particleSeedCenters[maxBlendParticles];
    float2 particleExplodedCenters[maxBlendParticles];
    
    // Initialize with large distances
    for (int i = 0; i < maxBlendParticles; ++i) {
        particleDistances[i] = 1e9;
    }
    
    // Search neighboring blocks to find the exploded particles closest to this pixel.
    // This prevents clipping artifacts when turbulence or variance pushes particles across cell boundaries.
    for (int y = -3; y <= 3; ++y) {
        for (int x = -3; x <= 3; ++x) {
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
                float baselineFraction = 0.30;
                float effectiveExplosionForTurbulence = (maxExplosionSpread > 0.001) ? max(explosionSpacing, baselineFraction * maxExplosionSpread) : explosionSpacing;
                float turbulenceAmount = turbulence * effectiveExplosionForTurbulence * 30.0 * candidateEdgeFactor;
                    candidateExplodedCenter += turbulenceOffset * turbulenceAmount;
                }
                
                float gravityFall = explosionSpacing * candidateDistance * gravity * 0.8;
                candidateExplodedCenter.y += gravityFall;
            }
            
            float pixelDistance = length(pinchPosition - candidateExplodedCenter);
            
            // Insert this particle into the top 3 if it's close enough
            for (int i = 0; i < maxBlendParticles; ++i) {
                if (pixelDistance < particleDistances[i]) {
                    // Shift worse candidates down
                    for (int j = maxBlendParticles - 1; j > i; --j) {
                        particleDistances[j] = particleDistances[j - 1];
                        particleOriginalCenters[j] = particleOriginalCenters[j - 1];
                        particleSeedCenters[j] = particleSeedCenters[j - 1];
                        particleExplodedCenters[j] = particleExplodedCenters[j - 1];
                    }
                    // Insert new candidate
                    particleDistances[i] = pixelDistance;
                    particleOriginalCenters[i] = candidateCenter;
                    particleSeedCenters[i] = candidateSeedBlockCenter;
                    particleExplodedCenters[i] = candidateExplodedCenter;
                    break;
                }
            }
        }
    }
    
    // Blend colors from multiple nearby particles
    half4 finalColor = half4(0.0);
    float totalWeight = 0.0;
    
    // Calculate blend factor: 0 = square, 1 = circle
    float blendFactor = smoothstep(0.1, 2.0, pixelSize);
    bool useSquarePixels = forceSquarePixels > 0.5;
    
    for (int i = 0; i < maxBlendParticles; ++i) {
        if (particleDistances[i] >= 1e8) {
            // No more valid particles
            break;
        }
        
        float2 particleOriginalCenter = particleOriginalCenters[i];
        float2 particleSeedCenter = particleSeedCenters[i];
        float2 particleExplodedCenter = particleExplodedCenters[i];
        float pixelDistance = particleDistances[i];
        
        // Calculate growth multiplier for this particle
        float growthSeed = fract(sin(dot(particleSeedCenter, float2(73.156, 41.923))) * 37281.6547);
        float baseGrowth = 1.0 + (growth * explosionSpacing);
        float varianceAmount = growthVariance * explosionSpacing;
        float growthVariation = 1.0 + (growthSeed * 2.0 - 1.0) * varianceAmount;
        float growthMult = baseGrowth * growthVariation;
        
        // Circle radius is half the block size, scaled by growth
        float baseRadius = pixelSize * 0.5;
        float radius = baseRadius * growthMult;
        
        // Check if pixel is within this particle's radius
        float2 offsetFromExplodedCenter = pinchPosition - particleExplodedCenter;
        float distanceFromExplodedCenter = length(offsetFromExplodedCenter);
        
        // Antialiased circle edge using screen-space derivative
        float edge = radius - distanceFromExplodedCenter;
        float aaWidth = fwidth(edge);
        float circleCoverage = smoothstep(-aaWidth, aaWidth, edge);
        
        // Blend between square (1.0) and circle coverage based on blendFactor
        float alphaBlend = useSquarePixels ? 1.0 : mix(1.0, circleCoverage, clamp(blendFactor, 0.0, 1.0));
        
        // Skip particles that don't contribute (outside their radius)
        if (alphaBlend < 0.01) {
            continue;
        }
        
        // Calculate per-particle fade-out
        float fadeSeed = fract(sin(dot(particleSeedCenter, float2(91.237, 58.164))) * 28491.3721);
        float particleFadeStart = fadeStart + (fadeSeed - 0.5) * fadeVariance * (1.0 - fadeStart);
        float fadeOpacity = 1.0 - smoothstep(particleFadeStart, 1.0, animationProgress);
        
        // Sample color from the original block center
        half4 particleColor = layer.sample(particleOriginalCenter);
        particleColor.a *= half(alphaBlend * fadeOpacity);
        
        // Calculate weight based on inverse distance (closer = more weight)
        // Add small epsilon to avoid division by zero
        float weight = 1.0 / (pixelDistance + 0.01);
        
        // Also factor in the alpha contribution for better blending
        weight *= float(particleColor.a);
        
        // Accumulate weighted color
        finalColor += particleColor * half(weight);
        totalWeight += weight;
    }
    
    // Normalize by total weight
    if (totalWeight > 0.001) {
        finalColor /= half(totalWeight);
    }
    
    return finalColor;
}

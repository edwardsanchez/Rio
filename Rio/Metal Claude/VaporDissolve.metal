#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Noise functions for organic movement
float hash(float2 p) {
    p = fract(p * float2(5.3983, 5.4427));
    p += dot(p.yx, p.xy + float2(21.5351, 14.3137));
    return fract(p.x * p.y * 95.4337);
}

float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    
    float a = hash(i);
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));
    
    float2 u = f * f * (3.0 - 2.0 * f);
    
    return mix(a, b, u.x) +
           (c - a) * u.y * (1.0 - u.x) +
           (d - b) * u.x * u.y;
}

float fbm(float2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    
    return value;
}

// Turbulence function for steam-like displacement
float2 turbulence(float2 p, float time, float intensity) {
    float2 displacement = float2(0.0);
    
    // Multiple octaves of noise for realistic turbulence
    displacement.x = fbm(p * 3.0 + float2(time * 0.5, 0.0)) - 0.5;
    displacement.y = fbm(p * 3.0 + float2(0.0, time * 0.5)) - 0.5;
    
    // Add swirling motion
    float angle = fbm(p * 2.0 + time * 0.3) * 6.28318;
    displacement += float2(cos(angle), sin(angle)) * 0.1;
    
    return displacement * intensity;
}

[[stitchable]] half4 vaporDissolve(
    float2 position,
    SwiftUI::Layer layer,
    float time,
    float progress,
    float particleSize,
    float particleSpeed,
    float particleLifetime,
    float sizeRandomness,
    float windDirectionX,
    float windDirectionY,
    float windStrength,
    float turbulenceIntensity,
    float dispersalRadius,
    float fadeOutSpeed,
    float rotationSpeed,
    float gravityInfluence,
    float edgeSoftness,
    float particleDensity,
    float noiseScale,
    float burstIntensity,
    float burstCenterX,
    float burstCenterY,
    float spiralIntensity,
    float temperatureVariation,
    float layerSizeWidth,
    float layerSizeHeight
) {
    // Reconstruct vectors from individual components
    float2 windDirection = float2(windDirectionX, windDirectionY);
    float2 burstCenter = float2(burstCenterX, burstCenterY);
    float2 layerSize = float2(layerSizeWidth, layerSizeHeight);
    
    // Calculate grid position for particle
    float gridSize = particleSize / particleDensity;
    float2 gridPos = floor(position / gridSize) * gridSize + gridSize * 0.5;
    
    // Generate unique random seed for this particle
    float particleId = hash(gridPos);
    float particleRandom = hash(float2(particleId, 1.0));
    float particleRandom2 = hash(float2(particleId, 2.0));
    float particleRandom3 = hash(float2(particleId, 3.0));
    
    // Calculate particle activation time based on distance from burst center
    float2 fromCenter = gridPos - burstCenter * layerSize;
    float distFromCenter = length(fromCenter) / length(layerSize);
    float activationDelay = distFromCenter * 0.3 * (1.0 - burstIntensity);
    float activationNoise = noise(gridPos * noiseScale) * 0.2;
    float particleActivation = activationDelay + activationNoise;
    
    // Calculate effective progress for this particle
    float effectiveProgress = saturate((progress - particleActivation) / (1.0 - particleActivation));
    
    // Calculate particle life phase (0 = birth, 1 = death)
    float lifePhase = effectiveProgress * particleLifetime;
    
    // Early return if particle hasn't activated yet
    if (effectiveProgress <= 0.0) {
        return layer.sample(position);
    }
    
    // Calculate particle size with randomness
    float currentSize = particleSize * (1.0 + (particleRandom - 0.5) * sizeRandomness);
    
    // Apply size changes over lifetime (particles can expand as they dissipate)
    float sizeMultiplier = 1.0 + lifePhase * 0.5;
    currentSize *= sizeMultiplier;
    
    // Calculate particle movement
    float2 velocity = float2(0.0);
    
    // Initial burst velocity away from center
    float2 burstDirection = normalize(fromCenter + float2(0.001));
    velocity += burstDirection * burstIntensity * 50.0 * (1.0 - lifePhase);
    
    // Wind influence
    float2 normalizedWind = normalize(windDirection + float2(0.001));
    velocity += normalizedWind * windStrength * particleSpeed * lifePhase;
    
    // Turbulence (steam-like swirls)
    float2 turbulenceDisp = turbulence(
        gridPos / layerSize, 
        time + particleRandom * 10.0, 
        turbulenceIntensity
    );
    velocity += turbulenceDisp * 100.0 * lifePhase;
    
    // Temperature variation (hot air rises)
    float thermalLift = temperatureVariation * (1.0 + particleRandom2) * lifePhase;
    velocity.y -= thermalLift * 30.0;
    
    // Gravity influence (subtle downward pull)
    velocity.y += gravityInfluence * 50.0 * lifePhase * lifePhase;
    
    // Spiral motion
    float spiralAngle = lifePhase * rotationSpeed * 6.28318 + particleRandom3 * 6.28318;
    float spiralRadius = spiralIntensity * lifePhase * 30.0;
    velocity += float2(cos(spiralAngle), sin(spiralAngle)) * spiralRadius;
    
    // Apply accumulated velocity
    float2 particlePos = gridPos + velocity * effectiveProgress;
    
    // Calculate distance from current position to particle
    float distToParticle = distance(position, particlePos);
    
    // Check if we're within the particle circle
    if (distToParticle <= currentSize * 0.5) {
        // Sample the original color at the grid position
        half4 color = layer.sample(gridPos);
        
        // Calculate edge softness
        float edgeFactor = 1.0 - (distToParticle / (currentSize * 0.5));
        edgeFactor = smoothstep(0.0, edgeSoftness, edgeFactor);
        
        // Calculate fade based on lifetime
        float fadeFactor = 1.0;
        
        // Fade in at birth
        if (lifePhase < 0.1) {
            fadeFactor *= smoothstep(0.0, 0.1, lifePhase);
        }
        
        // Fade out at death
        float fadeStart = 0.5;
        if (lifePhase > fadeStart) {
            float fadeProgress = (lifePhase - fadeStart) / (1.0 - fadeStart);
            fadeFactor *= 1.0 - pow(fadeProgress, fadeOutSpeed);
        }
        
        // Apply dispersal (particles become more transparent as they spread)
        float dispersalFactor = 1.0 - (length(velocity) / (dispersalRadius * 100.0));
        dispersalFactor = saturate(dispersalFactor);
        
        // Combine all alpha factors
        color.a *= fadeFactor * edgeFactor * dispersalFactor;
        
        // Add slight color shift for temperature variation (optional warmth)
        if (temperatureVariation > 0.0) {
            float warmth = temperatureVariation * lifePhase * 0.1;
            color.r += warmth;
            color.g += warmth * 0.7;
        }
        
        return color;
    }
    
    // Return transparent if not within any particle
    return half4(0.0);
}

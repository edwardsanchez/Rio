//
//  BubblePixelate.metal
//  Rio
//
//  Created by Edward Sanchez on 10/15/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Pixelation effect that transitions from square to circular pixels
[[ stitchable ]] half4 pixelate(
    float2 position,
    SwiftUI::Layer layer,
    float pixelSize
) {
    // Calculate which block this pixel belongs to
    float2 blockPosition = floor(position / pixelSize) * pixelSize;
    
    // Calculate the center of the block
    float2 blockCenter = blockPosition + (pixelSize * 0.5);
    
    // Sample the layer at the block center
    half4 color = layer.sample(blockCenter);
    
    // Calculate blend factor: 0 = square, 1 = circle
    // Map pixelSize from [0.1, 2.0] to [0.0, 1.0]
    float blendFactor = smoothstep(0.1, 2.0, pixelSize);
    
    // Calculate distance from current position to block center
    float2 offset = position - blockCenter;
    float distance = length(offset);
    
    // Circle radius is half the block size
    float radius = pixelSize * 0.5;
    
    // For circles, check if we're inside
    if (blendFactor > 0.01) {
        // Apply circular masking
        if (distance > radius) {
            // Outside the circle - fade out based on blend factor
            float alpha = 1.0 - blendFactor;
            color.a *= alpha;
        }
    }
    
    return color;
}


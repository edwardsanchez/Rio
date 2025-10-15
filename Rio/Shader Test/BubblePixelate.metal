//
//  BubblePixelate.metal
//  Rio
//
//  Created by Edward Sanchez on 10/15/25.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

/// Simple pixelation effect that samples at 2x2 pixel intervals
[[ stitchable ]] half4 pixelate(
    float2 position,
    SwiftUI::Layer layer,
    float pixelSize
) {
    // Calculate which 2x2 block this pixel belongs to
    float2 blockPosition = floor(position / pixelSize) * pixelSize;
    
    // Sample from the center of the block
    float2 samplePosition = blockPosition + (pixelSize * 0.5);
    
    // Sample the layer at the block position
    half4 color = layer.sample(samplePosition);
    
    return color;
}


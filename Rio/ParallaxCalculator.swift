//
//  ParallaxCalculator.swift
//  Rio
//
//  Created by Edward Sanchez on 10/8/25.
//

import SwiftUI

/// Calculates the cascading jelly parallax offset for scroll-based animations
struct ParallaxCalculator {
    let scrollVelocity: CGFloat
    let scrollPhase: ScrollPhase
    let visibleMessageIndex: Int

    var offset: CGFloat {
        // Ensure we have a valid scroll velocity
        guard scrollVelocity != 0 else { return 0 }

        // Only apply cascading effect during active scrolling phases
        let shouldApplyCascade = scrollPhase == .tracking || scrollPhase == .decelerating

        if shouldApplyCascade {
            // Create cascading effect based on visible message position
            // Messages lower in the visible area get higher multipliers
            let baseMultiplier: CGFloat = 0.8
            let cascadeIncrement: CGFloat = 0.2
            let maxCascadeMessages = 20 // Limit cascade to prevent excessive multipliers

            // Calculate position-based multiplier (clamped to prevent extreme values)
            let cascadePosition = min(visibleMessageIndex, maxCascadeMessages)
            let multiplier = baseMultiplier + (CGFloat(cascadePosition) * cascadeIncrement)

            return -scrollVelocity * multiplier
        } else {
            // Use consistent multiplier when not actively scrolling
            let multiplier: CGFloat = 0.2
            return -scrollVelocity * multiplier
        }
    }
}

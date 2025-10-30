//
//  BubbleConfiguration.swift
//  Rio
//
//  Created by Edward Sanchez on 10/17/25.
//

import SwiftUI

/// Centralized configuration and utilities for bubble animations and layout
@Observable
class BubbleConfiguration {
    // MARK: - Configuration Constants

    /// Corner radius for bubble shapes
    let bubbleCornerRadius: CGFloat = 20

    /// Minimum diameter for metaball circles
    let bubbleMinDiameter: CGFloat = 13

    /// Maximum diameter for metaball circles
    let bubbleMaxDiameter: CGFloat = 23

    /// Blur radius for metaball effect
    let bubbleBlurRadius: CGFloat = 2

    // MARK: - Animation Timing

    /// Duration used for circle size interpolation in BubbleView
    let circleTransitionDuration: TimeInterval = 0.3

    /// Duration for the thinking/talking morph animation
    let morphDuration: TimeInterval = 0.2

    /// Maximum duration for the spring-based resize animation before it's cut off
    let resizeCutoffDuration: TimeInterval = 1

    /// Total duration for the read→thinking animation
    let readToThinkingDuration: TimeInterval = 0.8

    /// Duration for the explosion animation when transitioning from thinking to read
    let explosionDuration: TimeInterval = 0.5

    /// External callers coordinate text reveals with this delay to match the morph
    var textRevealDelay: TimeInterval {
        (morphDuration + resizeCutoffDuration) * 0.25
    }

    // MARK: - Helper Functions

    /// Calculate parallax offset for cascading jelly effect
    func calculateParallaxOffset(
        scrollVelocity: CGFloat,
        scrollPhase: ScrollPhase,
        visibleMessageIndex: Int,
        isNewMessage: Bool = false
    ) -> CGFloat {
        // Don't apply parallax during new message animations
        guard !isNewMessage else { return 0 }

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

    // MARK: - Geometry Calculations

    /// Calculates the perimeter of a rounded rectangle (used for circle packing & animation)
    func calculateRoundedRectPerimeter(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> CGFloat {
        let straightWidth = width - 2 * cornerRadius
        let straightHeight = height - 2 * cornerRadius
        let arcLength = 2 * .pi * cornerRadius // Full circle circumference

        return 2 * straightWidth + 2 * straightHeight + arcLength
    }

    /// Packs the given perimeter with circles that stay between `min` and `max` diameters
    func computeDiameters(length L: CGFloat, min a: CGFloat, max b: CGFloat, seed: UInt64) -> PackingResult {
        let avg = (a + b) / 2
        let minCount = Int(ceil(L / b))          // Smallest count that keeps per-circle <= max
        let maxCount = Int(floor(L / a))         // Largest count that keeps per-circle >= min

        // 1) Try equal circles: choose a count m where L/m is within [min, max].
        if minCount <= maxCount {
            // Among all feasible m, pick one whose size is closest to the average.
            var bestM = minCount
            var bestDiff = abs(L / CGFloat(minCount) - avg)
            if maxCount > minCount {
                for m in (minCount...maxCount) {
                    let size = L / CGFloat(m)
                    let diff = abs(size - avg)
                    if diff < bestDiff {
                        bestDiff = diff
                        bestM = m
                    }
                }
            }
            // Introduce a tiny bit of variety near the average if multiple m tie
            var rng = SeededRandomGenerator(seed: seed)
            let candidates = (minCount...maxCount).filter { abs(L / CGFloat($0) - avg) <= bestDiff + 0.01 }
            if let pick = candidates.randomElement(using: &rng) { bestM = pick }
            return PackingResult(diameters: Array(repeating: L / CGFloat(bestM), count: bestM), isValid: true)
        }

        // 2) Fallback: start with as many min-sized circles as possible, then distribute the leftover
        // across them without exceeding max. This fills the whole length and respects [min, max].
        let m = max(1, Int(floor(L / a)))
        var sizes = Array(repeating: a, count: m)
        var leftover = L - CGFloat(m) * a
        var i = 0
        var isValid = true

        while leftover > 0 && i < sizes.count {
            let canAdd = min(b - sizes[i], leftover)
            if canAdd > 0 {
                sizes[i] += canAdd
                leftover -= canAdd
            }
            i = (i + 1) % sizes.count
            // If we looped a full cycle without placing anything, bump count if possible
            if i == 0 && sizes.allSatisfy({ $0 >= b - 0.0001 }) && leftover > 0 {
                // We cannot grow further without breaking max. Add one more circle if that would be valid.
                if leftover >= a && leftover <= b {
                    sizes.append(leftover)
                    leftover = 0
                    break
                } else {
                    // If we get here, constraints cannot be satisfied
                    isValid = false
                    break
                }
            }
        }

        // Check if any circle violates constraints
        let tolerance: CGFloat = 0.001
        for size in sizes {
            if size < a - tolerance || size > b + tolerance {
                isValid = false
                break
            }
        }

        return PackingResult(diameters: sizes, isValid: isValid)
    }

    /// Prepares the per-circle oscillation data so the total length remains stable during animation
    func computeAnimationData(baseDiameters: [CGFloat], min: CGFloat, max: CGFloat, seed: UInt64) -> [CircleAnimationData] {
        var rng = SeededRandomGenerator(seed: seed)
        var animationData: [CircleAnimationData] = []

        // For each circle, calculate the maximum amplitude it can oscillate
        // while staying within [min, max] bounds
        var amplitudes: [CGFloat] = []
        for baseDiameter in baseDiameters {
            let maxGrowth = Swift.max(max - baseDiameter, 0)
            let maxShrink = Swift.max(baseDiameter - min, 0)

            // Maximum oscillation amplitude (how far from base in either direction)
            let amplitude = Swift.min(maxGrowth, maxShrink)
            amplitudes.append(amplitude)
        }

        // Normalize amplitudes so they can be used in a zero-sum system
        // We'll pair circles and give them opposite directions
        for i in 0..<baseDiameters.count {
            let baseDiameter = baseDiameters[i]
            let amplitude = amplitudes[i]

            // Random phase offset for visual variety
            let phase = CGFloat(rng.next() % 1000) / 1000.0

            // Alternate direction: even indices grow first (+1), odd indices shrink first (-1)
            let direction: CGFloat = (i % 2 == 0) ? 1.0 : -1.0

            animationData.append(CircleAnimationData(
                baseDiameter: baseDiameter,
                amplitude: amplitude,
                phase: phase,
                direction: direction
            ))
        }

        return animationData
    }

    /// Applies the oscillation data while ensuring the combined length equals the perimeter
    func calculateAnimatedDiameters(
        animationData: [CircleAnimationData],
        progress: CGFloat,
        totalLength: CGFloat,
        min: CGFloat,
        max: CGFloat
    ) -> [CGFloat] {
        if animationData.isEmpty || totalLength <= 0 {
            return []
        }

        var diameters: [CGFloat] = []

        // First pass: calculate desired diameters with oscillations
        for data in animationData {
            // Apply phase offset
            let phasedProgress = (progress + data.phase).truncatingRemainder(dividingBy: 1.0)

            // Create sine-like oscillation: -1 → +1 → -1 over the cycle
            let angle = phasedProgress * 2.0 * .pi
            let oscillation = sin(angle)

            // Apply direction and amplitude
            let deviation = data.direction * data.amplitude * oscillation

            // Calculate desired diameter
            let desiredDiameter = data.baseDiameter + deviation

            diameters.append(desiredDiameter)
        }

        // Second pass: correct to maintain exact sum
        // Distribute the error proportionally based on how much room each circle has
        let currentSum = diameters.reduce(0, +)
        let error = currentSum - totalLength

        if abs(error) > 0.001 {
            // Calculate correction weights based on available space
            var weights: [CGFloat] = []
            var totalWeight: CGFloat = 0

            for (index, diameter) in diameters.enumerated() {
                // Weight based on how much this circle can adjust
                let data = animationData[index]
                let lowerBound = Swift.min(min, data.baseDiameter)
                let upperBound = Swift.max(max, data.baseDiameter)
                let canGrow = Swift.max(upperBound - diameter, 0)
                let canShrink = Swift.max(diameter - lowerBound, 0)
                let weight = error > 0 ? canShrink : canGrow
                weights.append(weight)
                totalWeight += weight
            }

            // Apply corrections
            if totalWeight > 0 {
                for i in 0..<diameters.count {
                    let correction = (weights[i] / totalWeight) * error
                    diameters[i] -= correction

                    // Clamp to bounds
                    let data = animationData[i]
                    let lowerBound = Swift.min(min, data.baseDiameter)
                    let upperBound = Swift.max(max, data.baseDiameter)
                    diameters[i] = Swift.max(lowerBound, Swift.min(upperBound, diameters[i]))
                }
            }
        }

        // Final verification and adjustment to ensure exact sum
        let finalSum = diameters.reduce(0, +)
        let finalError = finalSum - totalLength

        if abs(finalError) > 0.001 && !diameters.isEmpty {
            // Distribute remaining error evenly across all circles that have room
            let errorPerCircle = finalError / CGFloat(diameters.count)
            for i in 0..<diameters.count {
                diameters[i] -= errorPerCircle
                let data = animationData[i]
                let lowerBound = Swift.min(min, data.baseDiameter)
                let upperBound = Swift.max(max, data.baseDiameter)
                diameters[i] = Swift.max(lowerBound, Swift.min(upperBound, diameters[i]))
            }
        }

        return diameters
    }

    /// Converts circle diameters and travel progress into centre points along a rounded rectangle path
    func calculatePositions(
        diameters: [CGFloat],
        movementProgress: CGFloat,
        perimeter: CGFloat,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat
    ) -> [CGPoint] {
        var positions: [CGPoint] = []

        // Calculate initial spacing positions (where circles would be if stationary)
        var initialDistances: [CGFloat] = []
        var currentDistance: CGFloat = 0
        for diameter in diameters {
            let centerDistance = currentDistance + diameter / 2
            initialDistances.append(centerDistance)
            currentDistance += diameter
        }

        // Apply movement offset - move all circles by the same distance
        let movementOffset = movementProgress * perimeter

        for initialDistance in initialDistances {
            // Add movement offset and wrap around using modulo
            let animatedDistance = (initialDistance + movementOffset).truncatingRemainder(dividingBy: perimeter)
            let position = pointOnRoundedRectPath(
                distance: animatedDistance,
                width: width,
                height: height,
                cornerRadius: cornerRadius,
                perimeter: perimeter
            )
            positions.append(position)
        }

        return positions
    }

    /// Maps a distance along the rounded rectangle perimeter to a concrete coordinate
    func pointOnRoundedRectPath(
        distance: CGFloat,
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat,
        perimeter: CGFloat
    ) -> CGPoint {
        let d = distance.truncatingRemainder(dividingBy: perimeter)

        let straightWidth = width - 2 * cornerRadius
        let straightHeight = height - 2 * cornerRadius
        let quarterArc = (.pi * cornerRadius) / 2

        // Define segments:
        // 1. Top edge (left to right): from (cornerRadius, 0) to (width - cornerRadius, 0)
        let topEdgeEnd = straightWidth

        // 2. Top-right arc: quarter circle
        let topRightArcEnd = topEdgeEnd + quarterArc

        // 3. Right edge (top to bottom): from (width, cornerRadius) to (width, height - cornerRadius)
        let rightEdgeEnd = topRightArcEnd + straightHeight

        // 4. Bottom-right arc: quarter circle
        let bottomRightArcEnd = rightEdgeEnd + quarterArc

        // 5. Bottom edge (right to left): from (width - cornerRadius, height) to (cornerRadius, height)
        let bottomEdgeEnd = bottomRightArcEnd + straightWidth

        // 6. Bottom-left arc: quarter circle
        let bottomLeftArcEnd = bottomEdgeEnd + quarterArc

        // 7. Left edge (bottom to top): from (0, height - cornerRadius) to (0, cornerRadius)
        let leftEdgeEnd = bottomLeftArcEnd + straightHeight

        if d < topEdgeEnd {
            // Top edge
            return CGPoint(x: cornerRadius + d, y: 0)
        } else if d < topRightArcEnd {
            // Top-right arc
            let arcProgress = (d - topEdgeEnd) / quarterArc
            let angle = .pi * 1.5 + arcProgress * .pi / 2 // Start at -90°, go to 0°
            return CGPoint(
                x: width - cornerRadius + cornerRadius * cos(angle),
                y: cornerRadius + cornerRadius * sin(angle)
            )
        } else if d < rightEdgeEnd {
            // Right edge
            let edgeProgress = d - topRightArcEnd
            return CGPoint(x: width, y: cornerRadius + edgeProgress)
        } else if d < bottomRightArcEnd {
            // Bottom-right arc
            let arcProgress = (d - rightEdgeEnd) / quarterArc
            let angle = arcProgress * .pi / 2 // Start at 0°, go to 90°
            return CGPoint(
                x: width - cornerRadius + cornerRadius * cos(angle),
                y: height - cornerRadius + cornerRadius * sin(angle)
            )
        } else if d < bottomEdgeEnd {
            // Bottom edge (moving left)
            let edgeProgress = d - bottomRightArcEnd
            return CGPoint(x: width - cornerRadius - edgeProgress, y: height)
        } else if d < bottomLeftArcEnd {
            // Bottom-left arc
            let arcProgress = (d - bottomEdgeEnd) / quarterArc
            let angle = .pi / 2 + arcProgress * .pi / 2 // Start at 90°, go to 180°
            return CGPoint(
                x: cornerRadius + cornerRadius * cos(angle),
                y: height - cornerRadius + cornerRadius * sin(angle)
            )
        } else if d < leftEdgeEnd {
            // Left edge (moving up)
            let edgeProgress = d - bottomLeftArcEnd
            return CGPoint(x: 0, y: height - cornerRadius - edgeProgress)
        } else {
            // Top-left arc
            let arcProgress = (d - leftEdgeEnd) / quarterArc
            let angle = .pi + arcProgress * .pi / 2 // Start at 180°, go to 270°
            return CGPoint(
                x: cornerRadius + cornerRadius * cos(angle),
                y: cornerRadius + cornerRadius * sin(angle)
            )
        }
    }
}

// MARK: - Supporting Data Structures

/// Precomputed animation info for each metaball
struct CircleAnimationData {
    let baseDiameter: CGFloat
    let amplitude: CGFloat  // Oscillation range around the base diameter
    let phase: CGFloat
    let direction: CGFloat  // +1 or -1, determines if it grows or shrinks first
}

/// Output of the packing algorithm that tries to fill the perimeter with circles that respect min/max bounds
struct PackingResult {
    let diameters: [CGFloat]
    let isValid: Bool
}

/// Deterministic RNG so the bubble animation remains stable for a given seed
private struct SeededRandomGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed &* 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

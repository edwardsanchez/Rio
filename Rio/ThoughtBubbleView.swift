//
//  ThoughtBubbleView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/6/25.
//


import SwiftUI

struct ThoughtBubbleView: View {
    let width: CGFloat  // Inner rectangle width
    let height: CGFloat  // Inner rectangle height
    let cornerRadius: CGFloat
    let minDiameter: CGFloat
    let maxDiameter: CGFloat
    let randomSeed: UInt64
    let hasInvalidInput: Bool
    let blurRadius: CGFloat
    let color: Color

    let startTime = Date()

    // Padding around the inner rectangle to accommodate circles + blur
    var padding: CGFloat {
        maxDiameter / 2 + blurRadius
    }

    // Canvas dimensions (larger than inner rectangle to fit circles + blur)
    var canvasWidth: CGFloat {
        width + maxDiameter + 2 * blurRadius
    }

    var canvasHeight: CGFloat {
        height + maxDiameter + 2 * blurRadius
    }

    // Computed perimeter of the inner rounded rectangle
    var perimeter: CGFloat {
        calculateRoundedRectPerimeter(width: width, height: height, cornerRadius: cornerRadius)
    }

    init(
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat? = nil,
        minDiameter: CGFloat,
        maxDiameter: CGFloat,
        blurRadius: CGFloat = 4,
        color: Color
    ) {
        let cornerRadius = cornerRadius ?? min(height, width) / 2
        precondition(minDiameter > 0 && maxDiameter > 0, "Diameters must be positive.")
        precondition(cornerRadius >= 0, "Corner radius must be non-negative.")

        self.width = width
        self.height = height
        self.maxDiameter = maxDiameter
        self.blurRadius = blurRadius
        self.cornerRadius = min(cornerRadius, min(width, height) / 2) // Clamp corner radius
        self.color = color

        // Calculate perimeter based on the inner rectangle dimensions
        let perimeter = calculateRoundedRectPerimeter(width: width, height: height, cornerRadius: self.cornerRadius)
        precondition(minDiameter <= perimeter && maxDiameter <= perimeter, "minDiameter and maxDiameter must be <= perimeter.")

        // If min > max, swap them and mark as invalid
        if minDiameter > maxDiameter {
            self.minDiameter = maxDiameter
            self.hasInvalidInput = true
        } else {
            self.minDiameter = minDiameter
            self.hasInvalidInput = false
        }

        self.randomSeed = UInt64.random(in: 0...UInt64.max)
    }

    var body: some View {
        let result = computeDiameters(length: perimeter, min: minDiameter, max: maxDiameter, seed: randomSeed)
        let isValid = result.isValid && !hasInvalidInput
        let animationData = computeAnimationData(baseDiameters: result.diameters, min: minDiameter, max: maxDiameter, seed: randomSeed)

        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startTime)

            // Size oscillation progress (3 second cycle)
            let sizeProgress = CGFloat(elapsed / 3.0).truncatingRemainder(dividingBy: 1.0)

            let animatedDiameters = calculateAnimatedDiameters(
                animationData: animationData,
                progress: sizeProgress,
                totalLength: perimeter,
                min: minDiameter,
                max: maxDiameter
            )

            // Movement progress - circles complete one full loop every 5 seconds
            let movementProgress = CGFloat(elapsed / 10.0).truncatingRemainder(dividingBy: 1.0)

            // Calculate positions for each circle along the rounded rectangle path
            let positions = calculatePositions(diameters: animatedDiameters, movementProgress: movementProgress)

            // Canvas with metaball effect
            // Canvas is sized to accommodate circles around the inner rectangle
            Canvas { context, size in
                context.addFilter(.alphaThreshold(min: 0.2, color: isValid ? color : Color.red.opacity(0.5)))
                context.addFilter(.blur(radius: blurRadius))
                context.drawLayer { ctx in
                    // Draw filled rounded rectangle centered in canvas with padding
                    let rectPath = RoundedRectangle(cornerRadius: cornerRadius)
                        .path(in: CGRect(x: padding, y: padding, width: width, height: height))
                    ctx.fill(rectPath, with: .color(color))

                    // Draw circles around the path
                    for (index, _) in animatedDiameters.enumerated() {
                        if let circleSymbol = ctx.resolveSymbol(id: index) {
                            // Offset position by padding to account for canvas border
                            let position = CGPoint(
                                x: positions[index].x + padding,
                                y: positions[index].y + padding
                            )
                            ctx.draw(circleSymbol, at: position)
                        }
                    }
                }
            } symbols: {
                ForEach(Array(animatedDiameters.enumerated()), id: \.offset) { index, diameter in
                    Circle()
                        .frame(width: diameter, height: diameter)
                        .tag(index)
                }
            }
            .frame(width: canvasWidth, height: canvasHeight)
        }
    }

    // Calculate center positions for each circle along the rounded rectangle path
    // movementProgress: 0.0 to 1.0 representing one complete loop around the path
    private func calculatePositions(diameters: [CGFloat], movementProgress: CGFloat) -> [CGPoint] {
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
                cornerRadius: cornerRadius
            )
            positions.append(position)
        }

        return positions
    }

    // Get a point on the rounded rectangle path at a given distance from the start
    // Start point is top-left corner, moving clockwise
    private func pointOnRoundedRectPath(distance: CGFloat, width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> CGPoint {
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

        // 8. Top-left arc: quarter circle
        // let topLeftArcEnd = leftEdgeEnd + quarterArc (this equals perimeter)

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

// MARK: - Animation data structures
private struct CircleAnimationData {
    let baseDiameter: CGFloat
    let amplitude: CGFloat  // How much this circle oscillates (+/-)
    let phase: CGFloat
    let direction: CGFloat  // +1 or -1, determines if it grows or shrinks first
}

// MARK: - Packing logic
private struct PackingResult {
    let diameters: [CGFloat]
    let isValid: Bool
}

private func computeDiameters(length L: CGFloat, min a: CGFloat, max b: CGFloat, seed: UInt64) -> PackingResult {
    let avg = (a + b) / 2
    let minCount = Int(ceil(L / b))          // smallest count that keeps per-circle <= max
    let maxCount = Int(floor(L / a))         // largest count that keeps per-circle >= min

    // 1) Try equal circles: choose a count m where L/m is within [min, max].
    if minCount <= maxCount {
        // Among all feasible m, pick one whose size is closest to the average.
        var bestM = minCount
        var bestDiff = abs(L / CGFloat(minCount) - avg)
        if maxCount > minCount {
            for m in (minCount...maxCount) {
                let size = L / CGFloat(m)
                let diff = abs(size - avg)
                if diff < bestDiff { bestDiff = diff; bestM = m }
            }
        }
        // Introduce a tiny bit of variety near the average if multiple m tie
        var rng = SeededRandomGenerator(seed: seed)
        let candidates = (minCount...maxCount).filter { abs(L/CGFloat($0) - avg) <= bestDiff + 0.01 }
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

// MARK: - Animation logic
private func computeAnimationData(baseDiameters: [CGFloat], min: CGFloat, max: CGFloat, seed: UInt64) -> [CircleAnimationData] {
    var rng = SeededRandomGenerator(seed: seed)
    var animationData: [CircleAnimationData] = []

    // For each circle, calculate the maximum amplitude it can oscillate
    // while staying within [min, max] bounds
    var amplitudes: [CGFloat] = []
    for baseDiameter in baseDiameters {
        let maxGrowth = max - baseDiameter
        let maxShrink = baseDiameter - min

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

private func calculateAnimatedDiameters(animationData: [CircleAnimationData], progress: CGFloat, totalLength: CGFloat, min: CGFloat, max: CGFloat) -> [CGFloat] {
    var diameters: [CGFloat] = []
    var totalDeviation: CGFloat = 0

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
        totalDeviation += deviation
    }

    // Second pass: correct to maintain exact sum
    // Distribute the error proportionally based on how much room each circle has
    let currentSum = diameters.reduce(0, +)
    let error = currentSum - totalLength

    if abs(error) > 0.001 {
        // Calculate correction weights based on available space
        var weights: [CGFloat] = []
        var totalWeight: CGFloat = 0

        for (_, diameter) in diameters.enumerated() {
            // Weight based on how much this circle can adjust
            let canGrow = max - diameter
            let canShrink = diameter - min
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
                diameters[i] = Swift.max(min, Swift.min(max, diameters[i]))
            }
        }
    }

    // Final verification and adjustment to ensure exact sum
    let finalSum = diameters.reduce(0, +)
    let finalError = finalSum - totalLength

    if abs(finalError) > 0.001 {
        // Distribute remaining error evenly across all circles that have room
        let errorPerCircle = finalError / CGFloat(diameters.count)
        for i in 0..<diameters.count {
            diameters[i] -= errorPerCircle
            diameters[i] = Swift.max(min, Swift.min(max, diameters[i]))
        }
    }

    return diameters
}

// Simple deterministic RNG for optional variety
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

// MARK: - Helper function for perimeter calculation (standalone)
private func calculateRoundedRectPerimeter(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> CGFloat {
    let straightWidth = width - 2 * cornerRadius
    let straightHeight = height - 2 * cornerRadius
    let arcLength = 2 * .pi * cornerRadius // Full circle circumference

    return 2 * straightWidth + 2 * straightHeight + arcLength
}

// MARK: - Preview
struct ThoughtBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 16) {
//            Text("Small rounded rectangle")
            ThoughtBubbleView(
                width: 68,
                height: 40,
                cornerRadius: 20,
                minDiameter: 10,
                maxDiameter: 22,
                color: .blue
            )
//                .border(.gray)

//            Text("Square with rounded corners")
//            ThoughtBubbleView(width: 150, height: 150, cornerRadius: 70, minDiameter: 15, maxDiameter: 40)
//                .border(.gray)
//
//            Text("Wide rectangle")
//            ThoughtBubbleView(width: 300, height: 120, minDiameter: 50, maxDiameter: 80)
////                .border(.gray)
//
//            Text("Tall rectangle")
//            ThoughtBubbleView(width: 100, height: 250, cornerRadius: 20, minDiameter: 15, maxDiameter: 35)
//                .border(.gray)
//
//            Text("Sharp corners (radius = 0)")
//            ThoughtBubbleView(width: 200, height: 120, cornerRadius: 0, minDiameter: 15, maxDiameter: 40)
//                .border(.gray)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}


#Preview("Thinking Bubble") {
    VStack(spacing: 60) {
        // Thinking bubble (inbound style)
        TypingIndicatorView()
            .foregroundStyle(.primary)
            .chatBubble(
                messageType: .inbound,
                backgroundColor: .userBubble,
                showTail: true,
                tailType: .thinking
            )
            .scaleEffect(2)
        
        // Talking bubble for comparison (inbound style)
        Text("Message")
            .foregroundStyle(.primary)
            .chatBubble(
                messageType: .inbound,
                backgroundColor: .userBubble,
                showTail: true,
                tailType: .talking
            )
            .hidden()
        
        // Outbound talking bubble
        Text("Message")
            .foregroundStyle(.white)
            .chatBubble(
                messageType: .outbound,
                backgroundColor: .accentColor,
                showTail: true,
                tailType: .talking
            )
            .hidden()
    }
    .padding()
}

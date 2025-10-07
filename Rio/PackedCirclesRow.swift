//
//  PackedCirclesRow.swift
//  Rio
//
//  Created by Edward Sanchez on 10/6/25.
//


import SwiftUI

struct PackedCirclesRow: View {
    let length: CGFloat
    let minDiameter: CGFloat
    let maxDiameter: CGFloat
    let randomSeed: UInt64
    let hasInvalidInput: Bool

    let startTime = Date()

    init(length: CGFloat, minDiameter: CGFloat, maxDiameter: CGFloat) {
        precondition(minDiameter > 0 && maxDiameter > 0, "Diameters must be positive.")
        precondition(minDiameter <= length && maxDiameter <= length, "minDiameter and maxDiameter must be <= length.")

        self.length = length

        // If min > max, swap them and mark as invalid
        if minDiameter > maxDiameter {
            self.minDiameter = maxDiameter
            self.maxDiameter = maxDiameter
            self.hasInvalidInput = true
        } else {
            self.minDiameter = minDiameter
            self.maxDiameter = maxDiameter
            self.hasInvalidInput = false
        }

        self.randomSeed = UInt64.random(in: 0...UInt64.max)
    }

    var body: some View {
        let result = computeDiameters(length: length, min: minDiameter, max: maxDiameter, seed: randomSeed)
        let isValid = result.isValid && !hasInvalidInput
        let animationData = computeAnimationData(baseDiameters: result.diameters, min: minDiameter, max: maxDiameter, seed: randomSeed)

        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startTime)
            let progress = CGFloat(elapsed / 3.0).truncatingRemainder(dividingBy: 1.0)

            let animatedDiameters = calculateAnimatedDiameters(
                animationData: animationData,
                progress: progress,
                totalLength: length,
                min: minDiameter,
                max: maxDiameter
            )

            // Calculate positions for each circle
            let positions = calculatePositions(diameters: animatedDiameters)

            // Canvas with metaball effect
            Canvas { context, size in
                context.addFilter(.alphaThreshold(min: 0.2, color: isValid ? .primary.opacity(0.12) : Color.red.opacity(0.5)))
                context.addFilter(.blur(radius: 4))
                context.drawLayer { ctx in
                    for (index, _) in animatedDiameters.enumerated() {
                        if let circleSymbol = ctx.resolveSymbol(id: index) {
                            let position = positions[index]
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
            .frame(width: length, height: maxDiameter, alignment: .leading)
            .clipped()
        }
    }

    // Calculate center positions for each circle
    private func calculatePositions(diameters: [CGFloat]) -> [CGPoint] {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0

        for diameter in diameters {
            let centerX = currentX + diameter / 2
            let centerY = maxDiameter / 2
            positions.append(CGPoint(x: centerX, y: centerY))
            currentX += diameter
        }

        return positions
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

        for (i, diameter) in diameters.enumerated() {
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

// MARK: - Preview
struct PackedCirclesRow_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 16) {

            PackedCirclesRow(length: 100, minDiameter: 20, maxDiameter: 50)
                .border(.gray)

//            Text("Tighter range")
            PackedCirclesRow(length: 227, minDiameter: 10, maxDiameter: 48)
                .border(.gray)

//            Text("Wide range with variety")
            PackedCirclesRow(length: 320, minDiameter: 30, maxDiameter: 80)
                .border(.gray)

//            Text("Impossible constraints - should be red")
            PackedCirclesRow(length: 220, minDiameter: 40, maxDiameter: 48)
                .border(.gray)

//            Text("Invalid: min > max - should be red")
            PackedCirclesRow(length: 200, minDiameter: 10, maxDiameter: 30)
                .border(.gray)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

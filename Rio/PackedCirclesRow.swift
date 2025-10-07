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
        // Visuals: circles packed with no gaps, centers aligned by using a fixed row height = maxDiameter
        HStack(spacing: 0) {
            ForEach(Array(result.diameters.enumerated()), id: \.offset) { _, d in
                Circle()
                    .fill(isValid ? .primary.opacity(0.12) : Color.red.opacity(0.5))
                    .frame(width: d, height: d)
                    .frame(height: maxDiameter, alignment: .center)
            }
        }
        .frame(width: length, height: maxDiameter, alignment: .leading)
        .clipped()
    }
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
            PackedCirclesRow(length: 220, minDiameter: 47, maxDiameter: 48)
                .border(.gray)

//            Text("Invalid: min > max - should be red")
            PackedCirclesRow(length: 220, minDiameter: 20, maxDiameter: 30)
                .border(.gray)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

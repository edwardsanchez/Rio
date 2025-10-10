//
//  BubbleView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/6/25.
//

import SwiftUI

struct BubbleView: View {

    let width: CGFloat  // Inner rectangle width
    let height: CGFloat  // Inner rectangle height
    let cornerRadius: CGFloat
    let minDiameter: CGFloat
    let maxDiameter: CGFloat
    let hasInvalidInput: Bool
    let blurRadius: CGFloat
    let color: Color
    let mode: BubbleMode

    private let circleTransitionDuration: TimeInterval = 0.3
    static let morphDuration: TimeInterval = 2.4
    static let resizeDuration: TimeInterval = 0.55
    static let textRevealDelay: TimeInterval = morphDuration + resizeDuration

    @State private var animationSeed: UInt64
    @State private var circleTransitions: [CircleTransition]
    @State private var nextCircleID: Int
    @State private var rectangleTransition: RectangleTransition
    @State private var startTime: Date
    @State private var modeAnimationStart: Date
    @State private var modeAnimationFrom: CGFloat
    @State private var modeAnimationTo: CGFloat
    @State private var pendingRectangleSize: CGSize?
    @State private var pendingRectangleScheduled = false

    // Padding around the inner rectangle to accommodate circles + blur
    private var basePadding: CGFloat {
        maxDiameter / 2 + blurRadius
    }

    init(
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat? = nil,
        minDiameter: CGFloat,
        maxDiameter: CGFloat,
        blurRadius: CGFloat = 4,
        color: Color,
        mode: BubbleMode = .thinking
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
        self.mode = mode

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

        let now = Date()
        _animationSeed = State(initialValue: UInt64.random(in: 0...UInt64.max))
        _circleTransitions = State(initialValue: [])
        _nextCircleID = State(initialValue: 0)
        _rectangleTransition = State(initialValue: RectangleTransition(
            startSize: CGSize(width: width, height: height),
            endSize: CGSize(width: width, height: height),
            startTime: now
        ))
        _startTime = State(initialValue: now)
        let initialProgress: CGFloat = mode == .thinking ? 0 : 1
        _modeAnimationStart = State(initialValue: now.addingTimeInterval(-Self.morphDuration))
        _modeAnimationFrom = State(initialValue: initialProgress)
        _modeAnimationTo = State(initialValue: initialProgress)
    }

    private struct CircleTransition: Identifiable {
        let id: Int
        var index: Int
        var startValue: CGFloat
        var endValue: CGFloat
        var startTime: Date
        var isDisappearing: Bool

        func value(at date: Date, duration: TimeInterval) -> CGFloat {
            guard duration > 0 else { return endValue }
            let elapsed = date.timeIntervalSince(startTime)
            let clamped = max(0, min(1, elapsed / duration))
            let progress = CGFloat(clamped)
            let eased = CGFloat(0.5 - 0.5 * cos(Double(progress) * .pi))
            return startValue + (endValue - startValue) * eased
        }
    }

    private struct RectangleTransition {
        var startSize: CGSize
        var endSize: CGSize
        var startTime: Date

        func value(at date: Date, duration: TimeInterval) -> CGSize {
            guard duration > 0 else { return endSize }
            let elapsed = date.timeIntervalSince(startTime)
            let clamped = max(0, min(1, elapsed / duration))
            let progress = CGFloat(clamped)
            let eased = CGFloat(0.5 - 0.5 * cos(Double(progress) * .pi))
            let width = startSize.width + (endSize.width - startSize.width) * eased
            let height = startSize.height + (endSize.height - startSize.height) * eased
            return CGSize(width: width, height: height)
        }
    }

    private func configureInitialTransitions(targetDiameters: [CGFloat]) {
        let now = Date()
        circleTransitions = targetDiameters.enumerated().map { index, value in
            CircleTransition(
                id: index,
                index: index,
                startValue: value,
                endValue: value,
                startTime: now,
                isDisappearing: false
            )
        }
        nextCircleID = targetDiameters.count
    }

    private func updateCircleTransitions(targetDiameters: [CGFloat]) {
        let now = Date()
        var updated: [CircleTransition] = []
        let existing = circleTransitions.sorted { $0.index < $1.index }

        let sharedCount = min(existing.count, targetDiameters.count)

        for i in 0..<sharedCount {
            var transition = existing[i]
            let currentValue = transition.value(at: now, duration: circleTransitionDuration)
            transition.startValue = currentValue
            transition.endValue = targetDiameters[i]
            transition.startTime = now
            transition.index = i
            transition.isDisappearing = false
            updated.append(transition)
        }

        if existing.count > targetDiameters.count {
            for i in targetDiameters.count..<existing.count {
                var transition = existing[i]
                let currentValue = transition.value(at: now, duration: circleTransitionDuration)
                transition.startValue = currentValue
                transition.endValue = 0
                transition.startTime = now
                transition.index = i
                transition.isDisappearing = true
                updated.append(transition)
                scheduleRemoval(of: transition.id)
            }
        }

        if targetDiameters.count > existing.count {
            for i in existing.count..<targetDiameters.count {
                let newID = nextCircleID
                nextCircleID += 1
                let transition = CircleTransition(
                    id: newID,
                    index: i,
                    startValue: 0,
                    endValue: targetDiameters[i],
                    startTime: now,
                    isDisappearing: false
                )
                updated.append(transition)
            }
        }

        updated.sort { $0.index < $1.index }
        circleTransitions = updated
    }

    private func scheduleRemoval(of id: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + circleTransitionDuration) {
            circleTransitions.removeAll { $0.id == id && $0.isDisappearing }
        }
    }

    private func currentBaseDiameters(at date: Date) -> [CGFloat] {
        circleTransitions
            .sorted { $0.index < $1.index }
            .compactMap { transition in
                let value = transition.value(at: date, duration: circleTransitionDuration)
                if transition.isDisappearing && value <= 0.01 {
                    return nil
                }
                return max(0, value)
            }
    }

    private func updateRectangleTransition(to size: CGSize) {
        let now = Date()
        let progress = modeProgress(at: now)
        if mode == .talking && progress < 0.98 {
            pendingRectangleSize = size
            schedulePendingRectangleApplication()
            return
        }
        applyRectangleSize(size)
    }

    private func applyRectangleSize(_ size: CGSize) {
        let now = Date()
        let currentSize = rectangleTransition.value(at: now, duration: Self.resizeDuration)
        rectangleTransition = RectangleTransition(
            startSize: currentSize,
            endSize: size,
            startTime: now
        )
        pendingRectangleSize = nil
        pendingRectangleScheduled = false
    }

    private func schedulePendingRectangleApplication() {
        guard !pendingRectangleScheduled else { return }
        pendingRectangleScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.morphDuration) {
            if let pending = pendingRectangleSize {
                applyRectangleSize(pending)
            } else {
                pendingRectangleScheduled = false
            }
        }
    }

    var body: some View {
        let targetPerimeter = calculateRoundedRectPerimeter(width: width, height: height, cornerRadius: cornerRadius)
        let packingResult = computeDiameters(length: targetPerimeter, min: minDiameter, max: maxDiameter, seed: animationSeed)
        let targetDiameters = packingResult.diameters
        let isValid = packingResult.isValid && !hasInvalidInput

        TimelineView(.animation) { timeline in
            let now = timeline.date
            let elapsed = now.timeIntervalSince(startTime)
            let animatedSize = rectangleTransition.value(at: now, duration: Self.resizeDuration)
            let displayWidth = max(animatedSize.width, 0)
            let displayHeight = max(animatedSize.height, 0)
            let morphProgress = modeProgress(at: now)
            let displayCornerRadius = min(cornerRadius, min(displayWidth, displayHeight) / 2)
            let effectivePadding = basePadding * (1 - morphProgress)
            let canvasWidth = displayWidth + effectivePadding * 2
            let canvasHeight = displayHeight + effectivePadding * 2
            let currentBlurRadius = blurRadius * (1 - morphProgress)
            let alphaThresholdMin = max(0.001, 0.2 * (1 - morphProgress))

            // Size oscillation progress (3 second cycle)
            let sizeProgress = CGFloat(elapsed / 3.0).truncatingRemainder(dividingBy: 1.0)

            let baseDiameters = currentBaseDiameters(at: now)
            let currentPerimeter = calculateRoundedRectPerimeter(
                width: displayWidth,
                height: displayHeight,
                cornerRadius: displayCornerRadius
            )

            let animationData = computeAnimationData(
                baseDiameters: baseDiameters,
                min: minDiameter,
                max: maxDiameter,
                seed: animationSeed
            )

            let animatedDiameters = calculateAnimatedDiameters(
                animationData: animationData,
                progress: sizeProgress,
                totalLength: currentPerimeter,
                min: minDiameter,
                max: maxDiameter
            )

            // Movement progress - circles complete one full loop every 10 seconds
            let movementProgress = CGFloat(elapsed / 10.0).truncatingRemainder(dividingBy: 1.0)

            // Calculate positions for each circle along the rounded rectangle path
            let positions = calculatePositions(
                diameters: animatedDiameters,
                movementProgress: movementProgress,
                perimeter: currentPerimeter,
                width: displayWidth,
                height: displayHeight,
                cornerRadius: displayCornerRadius
            )

            let centerPoint = CGPoint(
                x: displayWidth / 2,
                y: displayHeight / 2
            )

            let outwardProgress = max(0, min(1, 1 - morphProgress))
            let morphedPositions = positions.map { point in
                interpolate(centerPoint, to: point, progress: outwardProgress)
            }

            let morphedDiameters = animatedDiameters.map { diameter in
                max(0, diameter * outwardProgress)
            }

            // Canvas with metaball effect
            // Canvas is sized to accommodate circles around the inner rectangle
            Canvas { context, size in
                if alphaThresholdMin > 0.001 {
                    // Keep alpha threshold active only when needed to avoid gray background artifacts
                    context.addFilter(.alphaThreshold(min: Double(alphaThresholdMin), color: isValid ? color : Color.red.opacity(0.5)))
                }
                if currentBlurRadius > 0.05 {
                    // Blur is disabled once the talking morph completes to keep the canvas transparent
                    context.addFilter(.blur(radius: currentBlurRadius))
                }

                context.drawLayer { ctx in
                    // Draw filled rounded rectangle centered in canvas with padding
                    let rectPath = RoundedRectangle(cornerRadius: displayCornerRadius)
                        .path(in: CGRect(x: effectivePadding, y: effectivePadding, width: displayWidth, height: displayHeight))
                    ctx.fill(rectPath, with: .color(color))

                    // Draw circles around the path
                    for (index, _) in morphedDiameters.enumerated() {
                        if let circleSymbol = ctx.resolveSymbol(id: index) {
                            // Offset position by padding to account for canvas border
                            let position = CGPoint(
                                x: morphedPositions[index].x + effectivePadding,
                                y: morphedPositions[index].y + effectivePadding
                            )
                            ctx.draw(circleSymbol, at: position)
                        }
                    }
                }
            } symbols: {
                ForEach(Array(morphedDiameters.enumerated()), id: \.offset) { index, diameter in
                    Circle()
                        .frame(width: diameter, height: diameter)
                        .tag(index)
                }
            }
            .frame(width: canvasWidth, height: canvasHeight)

        }
        .onAppear {
            startTime = Date()
            if circleTransitions.isEmpty {
                configureInitialTransitions(targetDiameters: targetDiameters)
            } else {
                updateCircleTransitions(targetDiameters: targetDiameters)
            }
            updateRectangleTransition(to: CGSize(width: width, height: height))
        }
        .onChange(of: CGSize(width: width, height: height)) { _, newSize in
            updateRectangleTransition(to: newSize)
        }
        .onChange(of: targetDiameters) { _, newDiameters in
            updateCircleTransitions(targetDiameters: newDiameters)
        }
        .onChange(of: mode) { _, newMode in
            let target = newMode == .thinking ? CGFloat(0) : CGFloat(1)
            startModeAnimation(target: target)
        }
    }

    private func interpolate(_ start: CGPoint, to end: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }

    private func startModeAnimation(target: CGFloat) {
        let current = modeProgress(at: Date())
        modeAnimationFrom = current
        modeAnimationTo = target
        modeAnimationStart = Date()
    }

    private func modeProgress(at now: Date) -> CGFloat {
        let duration = Self.morphDuration
        guard duration > 0 else { return modeAnimationTo }
        let elapsed = now.timeIntervalSince(modeAnimationStart)
        if elapsed <= 0 {
            return modeAnimationFrom
        }
        if elapsed >= duration {
            return modeAnimationTo
        }
        let fraction = CGFloat(elapsed / duration)
        let eased = easeInOutProgress(fraction)
        return modeAnimationFrom + (modeAnimationTo - modeAnimationFrom) * eased
    }

    private func easeInOutProgress(_ value: CGFloat) -> CGFloat {
        // cosine-based ease for smooth acceleration/deceleration
        let clamped = min(max(value, 0), 1)
        return CGFloat(0.5 - 0.5 * cos(Double(clamped) * Double.pi))
    }

    // Calculate center positions for each circle along the rounded rectangle path
    // movementProgress: 0.0 to 1.0 representing one complete loop around the path
    private func calculatePositions(
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

    // Get a point on the rounded rectangle path at a given distance from the start
    // Start point is top-left corner, moving clockwise
    private func pointOnRoundedRectPath(
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

private func calculateAnimatedDiameters(animationData: [CircleAnimationData], progress: CGFloat, totalLength: CGFloat, min: CGFloat, max: CGFloat) -> [CGFloat] {
    if animationData.isEmpty || totalLength <= 0 {
        return []
    }

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
struct BubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 16) {
//            Text("Small rounded rectangle")
            BubbleView(
                width: 68,
                height: 40,
                cornerRadius: 20,
                minDiameter: 10,
                maxDiameter: 22,
                color: .blue
            )
//                .border(.gray)

//            Text("Square with rounded corners")
//            BubbleView(width: 150, height: 150, cornerRadius: 70, minDiameter: 15, maxDiameter: 40)
//                .border(.gray)
//
//            Text("Wide rectangle")
//            BubbleView(width: 300, height: 120, minDiameter: 50, maxDiameter: 80)
////                .border(.gray)
//
//            Text("Tall rectangle")
//            BubbleView(width: 100, height: 250, cornerRadius: 20, minDiameter: 15, maxDiameter: 35)
//                .border(.gray)
//
//            Text("Sharp corners (radius = 0)")
//            BubbleView(width: 200, height: 120, cornerRadius: 0, minDiameter: 15, maxDiameter: 40)
//                .border(.gray)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}

typealias ThoughtBubbleView = BubbleView

#Preview("Thought Bubble Morph") {
    struct MorphPreview: View {
        @State private var isTalking = false
        @State private var width: CGFloat = 220
        @State private var height: CGFloat = 120

        var body: some View {
            VStack(spacing: 24) {
                BubbleView(
                    width: width,
                    height: height,
                    cornerRadius: 26,
                    minDiameter: 16,
                    maxDiameter: 28,
                    blurRadius: 6,
                    color: .Default.inboundBubble,
                    mode: isTalking ? .talking : .thinking
                )
                .frame(width: width + 120, height: height + 120)

                Button(isTalking ? "Switch to Thinking" : "Switch to Talking") {
                    withAnimation(.easeInOut(duration: 2.4)) {
                        isTalking.toggle()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
//            .background(Color.base)
        }
    }

    return MorphPreview()
}

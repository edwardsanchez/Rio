//
//  BubbleView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/6/25.
//

import SwiftUI

/// Animated speech bubble that morphs between thinking and talking modes while keeping
/// the rendered result identical to the original metaball implementation.
struct BubbleView: View {
    // MARK: - Configuration

    /// Width of the inner rectangle that the metaballs orbit.
    let width: CGFloat
    /// Height of the inner rectangle that the metaballs orbit.
    let height: CGFloat
    /// Rounded corner radius applied to the inner rectangle.
    let cornerRadius: CGFloat
    /// Smallest allowed circle diameter along the track.
    let minDiameter: CGFloat
    /// Largest allowed circle diameter along the track.
    let maxDiameter: CGFloat
    /// Tracks whether the initial size inputs were inconsistent.
    let hasInvalidInput: Bool
    /// Blur radius applied to the metaball canvas.
    let blurRadius: CGFloat
    /// Fill color for the bubble and metaballs.
    let color: Color
    /// Current behavioural mode (thinking vs talking).
    let mode: BubbleMode
    /// Whether to render the decorative bubble tail.
    let showTail: Bool
    /// Message direction used to align the bubble tail.
    let messageType: MessageType

    // MARK: - Timing

    /// Duration used for circle size interpolation.
    private let circleTransitionDuration: TimeInterval = 0.3
    static let morphDuration: TimeInterval = 0.2
    /// Maximum duration for the spring-based resize animation before it's cut off.
    /// The actual spring physics uses a response time of 0.55s, but this cutoff creates a snappier animation.
    static let resizeCutoffDuration: TimeInterval = 1
    /// External callers coordinate text reveals with this delay to match the morph.
    static let textRevealDelay: TimeInterval = (morphDuration + resizeCutoffDuration) * 0.25
    /// Total duration for the read→thinking animation.
    static let readToThinkingDuration: TimeInterval = 1.4
    /// Duration for the tail circle to scale up.
    private let tailScaleDuration: TimeInterval = 1.2
    /// Delay before decorative circles start animating.
    private let decorativeCirclesDelay: TimeInterval = 0.1
    /// Duration for decorative circles to scale and position.
    private let decorativeCirclesDuration: TimeInterval = 0.3

    // MARK: - Animation State

    /// Seed that keeps randomised animations stable across refreshes.
    @State private var animationSeed: UInt64
    /// Active transitions for the metaball diameters.
    @State private var circleTransitions: [CircleTransition]
    /// Unique identifier tracker for dynamically added circles.
    @State private var nextCircleID: Int
    /// Spring-based interpolation for the rectangle size.
    @State private var rectangleTransition: RectangleTransition
    /// Start time driving the deterministic animation timeline.
    @State private var startTime: Date
    /// Cached start timestamp for the talking/thinking morph animation.
    @State private var modeAnimationStart: Date
    /// Animation lower bound for the morph progress.
    @State private var modeAnimationFrom: CGFloat
    /// Animation upper bound for the morph progress.
    @State private var modeAnimationTo: CGFloat
    /// Rectangle size waiting to be applied once the morph finishes.
    @State private var pendingRectangleSize: CGSize?
    /// Guards against scheduling the rectangle update multiple times.
    @State private var pendingRectangleScheduled = false
    /// Height of a single line of text for constraining during morph.
    @State private var singleLineTextHeight: CGFloat = 0
    /// Start timestamp for the read→thinking animation.
    @State private var readToThinkingStart: Date?

    // MARK: - Derived Layout

    /// Padding around the inner rectangle to accommodate circles and blur.
    private var basePadding: CGFloat {
        (maxDiameter / 2 + blurRadius) * 1
    }

    // MARK: - Tail Geometry

    private var tailAlignment: Alignment {
        messageType.isInbound ? .bottomLeading : .bottomTrailing
    }

    private var tailOffset: CGPoint {
        messageType.isInbound ? CGPoint(x: 5.5, y: 10.5) : CGPoint(x: -5.5, y: 10.5)
    }

    private var tailRotation: Angle {
        messageType.isInbound ? Angle(degrees: 180) : .zero
    }

    /// Creates a bubble with the provided geometry, animation bounds, and visual configuration.
    /// - Parameters:
    ///   - width: Target width of the inner rectangle.
    ///   - height: Target height of the inner rectangle.
    ///   - cornerRadius: Optional override for the rounded corners. Defaults to a pill shape.
    ///   - minDiameter: Smallest allowable circle diameter along the track.
    ///   - maxDiameter: Biggest allowable circle diameter along the track.
    ///   - blurRadius: Blur radius applied during the metaball effect.
    ///   - color: Fill color used for the bubble and circles.
    ///   - mode: Talking/thinking state. Influences morph progression.
    ///   - showTail: Whether to draw the decorative tail assets.
    ///   - messageType: Layout direction for the tail and alignment.
    init(
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat? = nil,
        minDiameter: CGFloat,
        maxDiameter: CGFloat,
        blurRadius: CGFloat = 4,
        color: Color,
        mode: BubbleMode = .thinking,
        showTail: Bool = false,
        messageType: MessageType = .inbound
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
        self.showTail = showTail
        self.messageType = messageType

        // Calculate perimeter based on the inner rectangle dimensions
        let perimeter = Self.calculateRoundedRectPerimeter(width: width, height: height, cornerRadius: self.cornerRadius)
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
            startTime: now,
            initialVelocity: .zero
        ))
        _startTime = State(initialValue: now)
        let initialProgress: CGFloat = (mode.isThinking || mode.isRead) ? 0 : 1
        _modeAnimationStart = State(initialValue: now.addingTimeInterval(-Self.morphDuration))
        _modeAnimationFrom = State(initialValue: initialProgress)
        _modeAnimationTo = State(initialValue: initialProgress)
    }

    // MARK: - Transition Models

    /// Tracks interpolation between circle diameters so they can animate smoothly when the target requirements change.
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

    /// Spring interpolation container for the inner rectangle's size.
    private struct RectangleTransition {
        var startSize: CGSize
        var endSize: CGSize
        var startTime: Date
        var initialVelocity: CGSize  // Initial velocity in points per second

        // Spring parameters
        static let dampingRatio: CGFloat = 0.6  // 0.7 gives a nice bounce (< 1 = underdamped/bouncy, 1 = critically damped, > 1 = overdamped)
        static let response: CGFloat = 0.24     // Response time in seconds (how quickly it settles)

        func value(at date: Date, duration: TimeInterval) -> CGSize {
            guard duration > 0 else { return endSize }
            let elapsed = CGFloat(date.timeIntervalSince(startTime))

            // If animation is complete, return end value
            if elapsed >= CGFloat(duration) {
                return endSize
            }

            // Calculate spring progress for width and height independently
            let widthDelta = endSize.width - startSize.width
            let heightDelta = endSize.height - startSize.height

            let widthProgress = springValue(
                elapsed: elapsed,
                delta: widthDelta,
                initialVelocity: initialVelocity.width
            )
            let heightProgress = springValue(
                elapsed: elapsed,
                delta: heightDelta,
                initialVelocity: initialVelocity.height
            )

            return CGSize(
                width: startSize.width + widthProgress,
                height: startSize.height + heightProgress
            )
        }

        /// Calculate spring-damped value using physics simulation
        /// - Parameters:
        ///   - elapsed: Time elapsed since animation start
        ///   - delta: Total change from start to end
        ///   - initialVelocity: Initial velocity in points per second
        /// - Returns: Current displacement from start position
        private func springValue(elapsed: CGFloat, delta: CGFloat, initialVelocity: CGFloat) -> CGFloat {
            // Spring physics parameters
            let zeta = Self.dampingRatio  // Damping ratio
            let omega0 = 2 * .pi / Self.response  // Natural frequency (rad/s)

            // Normalize to unit spring (target = 1, start = 0)
            let normalizedVelocity = delta != 0 ? initialVelocity / delta : 0

            let result: CGFloat

            if zeta < 1 {
                // Underdamped (bouncy) - most common case
                let omegaD = omega0 * sqrt(1 - zeta * zeta)  // Damped frequency
                let A: CGFloat = 1  // Initial displacement (normalized)
                let B = (normalizedVelocity + zeta * omega0 * A) / omegaD

                let envelope = exp(-zeta * omega0 * elapsed)
                let oscillation = A * cos(omegaD * elapsed) + B * sin(omegaD * elapsed)
                result = 1 - envelope * oscillation

            } else if zeta == 1 {
                // Critically damped (no overshoot)
                let A: CGFloat = 1
                let B = normalizedVelocity + omega0 * A
                result = 1 - (A + B * elapsed) * exp(-omega0 * elapsed)

            } else {
                // Overdamped (slow, no overshoot)
                let r1 = -omega0 * (zeta + sqrt(zeta * zeta - 1))
                let r2 = -omega0 * (zeta - sqrt(zeta * zeta - 1))
                let A = (normalizedVelocity - r2) / (r1 - r2)
                let B: CGFloat = 1 - A
                result = 1 - (A * exp(r1 * elapsed) + B * exp(r2 * elapsed))
            }

            // Scale back to actual delta
            return result * delta
        }
    }

    /// Bundles derived layout values for the metaball canvas and the underlying bubble while the morph is in-flight.
    private struct BubbleMorphLayout {
        let morphProgress: CGFloat
        let outwardProgress: CGFloat
        let canvasPadding: CGFloat
        let blurRadius: CGFloat
        let circleTrackSize: CGSize
        let circleTrackCornerRadius: CGFloat
        let displaySize: CGSize
        let displayCornerRadius: CGFloat
        let canvasSize: CGSize
        let alphaThreshold: CGFloat
        let circleTrackInset: CGFloat

        init(
            baseSize: CGSize,
            baseCornerRadius: CGFloat,
            basePadding: CGFloat,
            blurRadius: CGFloat,
            morphProgress: CGFloat
        ) {
            let clampedProgress = min(max(morphProgress, 0), 1)
            let outwardProgress = 1 - clampedProgress
            let canvasPadding = basePadding * outwardProgress
            let inset = basePadding * outwardProgress

            let trackWidth = max(0, baseSize.width - inset * 2)
            let trackHeight = max(0, baseSize.height - inset * 2)
            let trackCornerRadius = min(baseCornerRadius, min(trackWidth, trackHeight) / 2)

            self.morphProgress = clampedProgress
            self.outwardProgress = outwardProgress
            self.canvasPadding = canvasPadding
            self.blurRadius = blurRadius * outwardProgress
            self.circleTrackInset = inset
            self.circleTrackSize = CGSize(width: trackWidth, height: trackHeight)
            self.circleTrackCornerRadius = trackCornerRadius
            self.displaySize = circleTrackSize
            self.displayCornerRadius = trackCornerRadius
            self.canvasSize = CGSize(
                width: trackWidth + canvasPadding * 2,
                height: trackHeight + canvasPadding * 2
            )
            self.alphaThreshold = max(0.001, 0.2 * outwardProgress)
        }

        var circleTrackWidth: CGFloat { circleTrackSize.width }
        var circleTrackHeight: CGFloat { circleTrackSize.height }

        func rectangleOrigin(for displaySize: CGSize) -> CGPoint {
            CGPoint(
                x: canvasPadding + (circleTrackSize.width - displaySize.width) / 2,
                y: canvasPadding + (circleTrackSize.height - displaySize.height) / 2
            )
        }
    }

    /// Encapsulates the desired circle diameters once constraints and morph progress are applied.
    private struct CircleTargetState {
        let targets: [CGFloat]
        let minimum: CGFloat
        let maximum: CGFloat
    }

    /// Returns the active circle transitions sorted by their desired order around the track.
    private func sortedCircleTransitions() -> [CircleTransition] {
        circleTransitions.sorted { $0.index < $1.index }
    }

    // MARK: - Circle Management

    /// Seeds the circle transitions so the metaballs start from the target diameters without animating from zero.
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

    /// Updates circle transitions to smoothly animate to a new set of target diameters.
    private func updateCircleTransitions(targetDiameters: [CGFloat]) {
        let now = Date()
        var updated: [CircleTransition] = []
        let existing = sortedCircleTransitions()

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

    /// Removes disappearing circles once their shrink animation finishes.
    private func scheduleRemoval(of id: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + circleTransitionDuration) {
            self.circleTransitions.removeAll { $0.id == id && $0.isDisappearing }
        }
    }

    /// Returns the current interpolated diameters of all visible circles.
    private func currentBaseDiameters(at date: Date) -> [CGFloat] {
        sortedCircleTransitions()
            .compactMap { transition in
                let value = transition.value(at: date, duration: circleTransitionDuration)
                if transition.isDisappearing && value <= 0.01 {
                    return nil
                }
                return max(0, value)
            }
    }

    /// Returns the target diameters so we can diff against new packing requests.
    private func currentTargetDiameters(tolerance: CGFloat = 0.001) -> [CGFloat] {
        sortedCircleTransitions()
            .compactMap { transition in
                let value = transition.endValue
                return value > tolerance ? value : nil
            }
    }

    /// Checks whether two diameter arrays are almost identical, ignoring tiny floating-point gaps.
    private func almostEqual(_ lhs: [CGFloat], _ rhs: [CGFloat], tolerance: CGFloat = 0.1) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (l, r) in zip(lhs, rhs) where abs(l - r) > tolerance {
            return false
        }
        return true
    }

    /// Calculates the effective min/max bounds based on how far the circles have retracted.
    private func effectiveDiameterBounds(outwardProgress: CGFloat) -> (min: CGFloat, max: CGFloat)? {
        let clamped = min(max(outwardProgress, 0), 1)
        guard clamped > 0 else { return nil }
        let minBound = max(minDiameter * clamped, 0.5)
        let maxBound = max(maxDiameter * clamped, minBound)
        return (min: minBound, max: maxBound)
    }

    /// Combines packing and morph progress to determine the desired circle diameters.
    private func circleTargetState(perimeter: CGFloat, outwardProgress: CGFloat, seed: UInt64) -> CircleTargetState {
        guard let bounds = effectiveDiameterBounds(outwardProgress: outwardProgress), perimeter > 0.001 else {
            return CircleTargetState(targets: [], minimum: minDiameter, maximum: maxDiameter)
        }

        var targets = Self.computeDiameters(
            length: perimeter,
            min: bounds.min,
            max: bounds.max,
            seed: seed
        ).diameters

        let sum = targets.reduce(0, +)
        if sum > 0 {
            let scale = perimeter / sum
            if abs(scale - 1) > 0.01 {
                targets = targets.map { max(0, $0 * scale) }
            }
        }

        return CircleTargetState(targets: targets, minimum: bounds.min, maximum: bounds.max)
    }

    // MARK: - Rectangle Size Management

    /// Ensures the inner rectangle resizes with a spring while respecting mode transitions.
    private func updateRectangleTransition(to size: CGSize) {
        let now = Date()
        let progress = modeProgress(at: now)
        if mode.isTalking && progress < 0.98 {
            // During morph phase, keep width constant and constrain height to single-line
            let currentWidth = rectangleTransition.endSize.width
            let morphSize = CGSize(
                width: currentWidth,  // Preserve current width during morph
                height: singleLineTextHeight > 0 ? singleLineTextHeight : size.height
            )
            applyRectangleSize(morphSize)
            // Store the full size to apply after morph completes
            pendingRectangleSize = size
            schedulePendingRectangleApplication()
            return
        }
        applyRectangleSize(size)
    }

    /// Applies the requested rectangle size immediately, capturing the current velocity to avoid pops.
    private func applyRectangleSize(_ size: CGSize) {
        let now = Date()
        let currentSize = rectangleTransition.value(at: now, duration: Self.resizeCutoffDuration)

        // Calculate current velocity based on the spring animation
        // This gives continuity when interrupting an ongoing animation
        let dt: CGFloat = 0.016  // ~1 frame at 60fps
        let futureSize = rectangleTransition.value(at: now.addingTimeInterval(dt), duration: Self.resizeCutoffDuration)
        let currentVelocity = CGSize(
            width: (futureSize.width - currentSize.width) / dt,
            height: (futureSize.height - currentSize.height) / dt
        )

        // Add some initial velocity in the direction of change for snappier feel
        let velocityBoost: CGFloat = 200  // points per second
        let widthDirection: CGFloat = size.width > currentSize.width ? 1 : -1
        let heightDirection: CGFloat = size.height > currentSize.height ? 1 : -1

        rectangleTransition = RectangleTransition(
            startSize: currentSize,
            endSize: size,
            startTime: now,
            initialVelocity: CGSize(
                width: currentVelocity.width + widthDirection * velocityBoost,
                height: currentVelocity.height + heightDirection * velocityBoost
            )
        )
        pendingRectangleSize = nil
        pendingRectangleScheduled = false
    }

    /// Applies a postponed rectangle update once the morph has completed.
    private func schedulePendingRectangleApplication() {
        guard !pendingRectangleScheduled else { return }
        pendingRectangleScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.morphDuration) {
            if let pending = self.pendingRectangleSize {
                self.applyRectangleSize(pending)
            } else {
                self.pendingRectangleScheduled = false
            }
        }
    }

    // MARK: - View Body

    /// Renders the metaball canvas and morphing bubble. This mirrors the previous visual output.
    var body: some View {
        let targetPerimeter = Self.calculateRoundedRectPerimeter(width: width, height: height, cornerRadius: cornerRadius)
        let packingResult = Self.computeDiameters(length: targetPerimeter, min: minDiameter, max: maxDiameter, seed: animationSeed)
        let targetDiameters = packingResult.diameters
        let isValid = packingResult.isValid && !hasInvalidInput

        return TimelineView(.animation) { timeline in
            let now = timeline.date
            let elapsed = now.timeIntervalSince(startTime)
            let animatedSize = rectangleTransition.value(at: now, duration: Self.resizeCutoffDuration)
            let baseWidth = max(animatedSize.width, 0)
            let baseHeight = max(animatedSize.height, 0)
            let morphProgress = modeProgress(at: now)

            // Check if we're in read→thinking animation
            let readToThinkingAnimProgress = readToThinkingProgress(at: now)
            let isReadToThinkingActive = mode.isThinking && readToThinkingStart != nil && readToThinkingAnimProgress < 1
            
            let layout = BubbleMorphLayout(
                baseSize: CGSize(width: baseWidth, height: baseHeight),
                baseCornerRadius: cornerRadius,
                basePadding: basePadding,
                blurRadius: blurRadius,
                morphProgress: morphProgress
            )
            
            // During read→thinking, force blur and alpha to full strength for metaball effect
            let currentBlurRadius = isReadToThinkingActive ? blurRadius : layout.blurRadius
            let circleTrackWidth = layout.circleTrackWidth
            let circleTrackHeight = layout.circleTrackHeight
            let circleTrackCornerRadius = layout.circleTrackCornerRadius
            let outwardProgress = layout.outwardProgress

            // Keep the inner rectangle locked to the circle track so it grows while the dots retract.
            // During read→thinking, scale the display rectangle along with the decorative circles
            let decorativeProgress = decorativeCirclesProgress(progress: readToThinkingAnimProgress)
            let displayWidth: CGFloat
            let displayHeight: CGFloat
            let displayCornerRadius: CGFloat
            
            if isReadToThinkingActive {
                // Scale rectangle with decorative circles animation
                displayWidth = layout.displaySize.width * decorativeProgress
                displayHeight = layout.displaySize.height * decorativeProgress
                displayCornerRadius = layout.displayCornerRadius * decorativeProgress
            } else {
                displayWidth = layout.displaySize.width
                displayHeight = layout.displaySize.height
                displayCornerRadius = layout.displayCornerRadius
            }
            
            let canvasWidth = layout.canvasSize.width
            let canvasHeight = layout.canvasSize.height
            // During read→thinking, force alpha threshold to full strength for metaball effect
            let alphaThresholdMin = isReadToThinkingActive ? 0.2 : layout.alphaThreshold

            // Size oscillation progress (3 second cycle)
            let sizeProgress = CGFloat(elapsed / 3.0).truncatingRemainder(dividingBy: 1.0)

            let baseDiameters = currentBaseDiameters(at: now)
            let currentPerimeter = Self.calculateRoundedRectPerimeter(
                width: circleTrackWidth,
                height: circleTrackHeight,
                cornerRadius: circleTrackCornerRadius
            )

            let circleState = circleTargetState(
                perimeter: currentPerimeter,
                outwardProgress: outwardProgress,
                seed: animationSeed
            )
            let desiredTargets = circleState.targets
            let existingTargets = currentTargetDiameters()
            if !almostEqual(existingTargets, desiredTargets) {
                DispatchQueue.main.async {
                    let refreshedTargets = self.currentTargetDiameters()
                    if !self.almostEqual(refreshedTargets, desiredTargets) {
                        self.updateCircleTransitions(targetDiameters: desiredTargets)
                    }
                }
            }

            let effectiveMin = circleState.minimum
            let effectiveMax = circleState.maximum

            let animationData = Self.computeAnimationData(
                baseDiameters: baseDiameters,
                min: effectiveMin,
                max: effectiveMax,
                seed: animationSeed
            )

            let animatedDiameters = Self.calculateAnimatedDiameters(
                animationData: animationData,
                progress: sizeProgress,
                totalLength: currentPerimeter,
                min: effectiveMin,
                max: effectiveMax
            )

            // Movement progress - circles complete one full loop every 10 seconds
            let baseMovementProgress = CGFloat(elapsed / 10.0).truncatingRemainder(dividingBy: 1.0)
            
            // During read→thinking, add damped velocity offset for clockwise motion
            let movementProgress: CGFloat
            if isReadToThinkingActive {
                // Start with high velocity, decay to normal speed
                // Use exponential decay for smooth deceleration
                let velocityMultiplier: CGFloat = 3.0  // Initial speed boost
                let decayRate: CGFloat = 5.0  // How quickly it slows down
                let velocityOffset = velocityMultiplier * (1 - decorativeProgress) * exp(-decayRate * decorativeProgress)
                
                // Add the velocity offset to movement progress (clockwise direction)
                let adjustedProgress = (baseMovementProgress + velocityOffset).truncatingRemainder(dividingBy: 1.0)
                movementProgress = adjustedProgress
            } else {
                movementProgress = baseMovementProgress
            }

            // Calculate positions for each circle along the FULL rounded rectangle path
            // Always use the full path - we'll scale positions from center later
            let positions = Self.calculatePositions(
                diameters: animatedDiameters,
                movementProgress: movementProgress,
                perimeter: currentPerimeter,
                width: circleTrackWidth,
                height: circleTrackHeight,
                cornerRadius: circleTrackCornerRadius
            )

            let centerPoint = CGPoint(
                x: circleTrackWidth / 2,
                y: circleTrackHeight / 2
            )

            // For read→thinking: scale positions uniformly from center
            // For thinking→talking morph: interpolate from positions to center
            let morphedPositions: [CGPoint]
            let morphedDiameters: [CGFloat]
            
            if isReadToThinkingActive {
                // During read→thinking, scale entire coordinate system from center
                // This maintains relative positions and creates smooth outward growth
                morphedPositions = positions.map { point in
                    let offset = CGPoint(x: point.x - centerPoint.x, y: point.y - centerPoint.y)
                    let scaledOffset = CGPoint(x: offset.x * decorativeProgress, y: offset.y * decorativeProgress)
                    return CGPoint(x: centerPoint.x + scaledOffset.x, y: centerPoint.y + scaledOffset.y)
                }
                
                // Scale circle sizes
                morphedDiameters = animatedDiameters.map { diameter in
                    max(0, diameter * decorativeProgress)
                }
            } else {
                // Normal thinking→talking morph behavior
                morphedPositions = positions.map { point in
                    interpolate(centerPoint, to: point, progress: outwardProgress)
                }
                
                morphedDiameters = animatedDiameters.map { diameter in
                    max(0, diameter * outwardProgress)
                }
            }

            // Canvas with metaball effect
            // Canvas is sized to accommodate circles around the inner rectangle
            return Canvas { context, size in
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
                    let rectOrigin = layout.rectangleOrigin(for: CGSize(width: displayWidth, height: displayHeight))
                    let trackOrigin = layout.rectangleOrigin(for: layout.circleTrackSize)
                    let rectPath = RoundedRectangle(cornerRadius: displayCornerRadius)
                        .path(in: CGRect(origin: rectOrigin, size: CGSize(width: displayWidth, height: displayHeight)))
                    ctx.fill(rectPath, with: .color(color))

                    // Draw circles around the path
                    for (index, _) in morphedDiameters.enumerated() {
                        if let circleSymbol = ctx.resolveSymbol(id: index) {
                            // Offset position by padding to account for canvas border
                            let position = CGPoint(
                                x: morphedPositions[index].x + trackOrigin.x,
                                y: morphedPositions[index].y + trackOrigin.y
                            )
                            ctx.draw(circleSymbol, at: position)
                        }
                    }
                }
            } symbols: {
                //Decorative circles
                ForEach(Array(morphedDiameters.enumerated()), id: \.offset) { index, diameter in
                    Circle()
                        .frame(width: diameter, height: diameter)
                        .tag(index)
                }
            }
            .frame(width: canvasWidth, height: canvasHeight)
            .overlay(alignment: tailAlignment) {
                tailView
            }
            .compositingGroup()
            .opacity(mode.isRead ? 0 : (messageType.isOutbound ? 1 : 0.25)) //Want 15 for light mode and 25 for dark mode
            .background {
                // Hidden text to measure single-line height
                Text("X")
                    .font(.body)
                    .padding(.vertical, 10) // Match the bubble's internal text padding
                    .fixedSize()
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { newHeight in
                        singleLineTextHeight = newHeight
                    }
                    .hidden()
            }
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
        .onChange(of: mode) { oldMode, newMode in
            let target = (newMode.isThinking || newMode.isRead) ? CGFloat(0) : CGFloat(1)
            startModeAnimation(target: target)
            
            // Start read→thinking animation when transitioning from read to thinking
            if oldMode.isRead && newMode.isThinking {
                readToThinkingStart = Date()
                // Schedule cleanup after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.readToThinkingDuration) {
                    self.readToThinkingStart = nil
                }
            } else if !newMode.isThinking {
                // Reset read→thinking animation if we're no longer in thinking mode
                readToThinkingStart = nil
            }
            
            // When transitioning from thinking to talking, update rectangle transition
            // to use single-line height during morph
            if (oldMode.isThinking || oldMode.isRead) && newMode.isTalking {
                updateRectangleTransition(to: CGSize(width: width, height: height))
            }
        }
    }

    @ViewBuilder
    /// Decorative bubble tail that switches layouts depending on the current mode.
    private var tailView: some View {
        TimelineView(.animation) { timeline in
            let now = timeline.date
            let readToThinkingAnimProgress = readToThinkingProgress(at: now)
            let tailScale = mode.isThinking && readToThinkingStart != nil ? tailCircleScale(progress: readToThinkingAnimProgress) : 1
            
            let isThinking = mode.isThinking || mode.isRead
            let isInbound = messageType.isInbound

            // Additional offsets for talking mode - mirrored for inbound/outbound
            let talkingXOffset: CGFloat = isInbound ? 3 : -3
            let thinkingXOffset: CGFloat = isInbound ? 15 : -15

            ZStack(alignment: tailAlignment) {
                // Talking bubble tail - only visible in talking mode
                Image(.cartouche)
                    .resizable()
                    .frame(width: 15, height: 15)
                    .rotation3DEffect(tailRotation, axis: (x: 0, y: 1, z: 0))
                    .offset(x: tailOffset.x, y: tailOffset.y)
                    .offset(x: isThinking ? thinkingXOffset : talkingXOffset, y: isThinking ? -23 : -1)
                    .foregroundStyle(color)
                    .opacity(showTail && mode.isTalking ? 1 : 0)
                    .animation(.spring(duration: 0.3).delay(0.2), value: mode)
                
                // Thinking bubble tail
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                    .scaleEffect(tailScale, anchor: .center)
                    .offset(
                        x: tailAlignment == .bottomLeading ? 4 : -4,
                        y: 21
                    )
                    .offset(x: 0, y: -13)
                    .offset(x: isThinking ? 0 : 5, y: isThinking ? 0 : -13)
                    .animation(.easeIn(duration: 0.2), value: mode)
                    .opacity(messageType.isInbound ? 1 : 0)
            }
        }
    }

    // MARK: - Misc Helpers

    /// Linearly interpolates between two points.
    private func interpolate(_ start: CGPoint, to end: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }

    /// Begins an ease-in-out animation between thinking and talking morph progress values.
    private func startModeAnimation(target: CGFloat) {
        let current = modeProgress(at: Date())
        modeAnimationFrom = current
        modeAnimationTo = target
        modeAnimationStart = Date()
    }

    /// Returns the eased progress for the thinking/talking morph at a given timestamp.
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

    /// Cosine-based ease-in-out used for the morph animation.
    private func easeInOutProgress(_ value: CGFloat) -> CGFloat {
        // cosine-based ease for smooth acceleration/deceleration
        let clamped = min(max(value, 0), 1)
        return CGFloat(0.5 - 0.5 * cos(Double(clamped) * Double.pi))
    }

    /// Returns the progress for the read→thinking animation at a given timestamp.
    /// - Returns: A value from 0 to 1, where 0 is the start and 1 is complete.
    private func readToThinkingProgress(at now: Date) -> CGFloat {
        guard let start = readToThinkingStart else { return 1 }
        let elapsed = now.timeIntervalSince(start)
        if elapsed <= 0 {
            return 0
        }
        if elapsed >= Self.readToThinkingDuration {
            return 1
        }
        return CGFloat(elapsed / Self.readToThinkingDuration)
    }

    /// Returns the tail circle scale for the read→thinking animation.
    /// - Parameter progress: Overall animation progress from 0 to 1.
    /// - Returns: Scale value from 0 to 1.
    private func tailCircleScale(progress: CGFloat) -> CGFloat {
        // Tail animates from 0 to 0.2 of total timeline (0.2s out of 0.4s)
        let tailProgress = min(max(progress / 0.5, 0), 1) // 0.5 = 0.2s / 0.4s
        // Apply bouncy spring easing manually (simplified spring curve)
        return tailProgress
    }

    /// Returns the decorative circles scale/position progress with bouncy spring easing.
    /// Uses proper spring physics based on duration and damping ratio.
    /// - Parameter progress: Overall animation progress from 0 to 1.
    /// - Returns: Scale value from 0 to 1.
    private func decorativeCirclesProgress(progress: CGFloat) -> CGFloat {
        // Decorative circles start at decorativeCirclesDelay (0.1s) and run for decorativeCirclesDuration (0.3s)
        let startPoint = decorativeCirclesDelay / Self.readToThinkingDuration
        if progress < startPoint {
            return 0
        }
        let normalizedProgress = (progress - startPoint) / (1 - startPoint)
        let elapsed = normalizedProgress * decorativeCirclesDuration
        
        // Spring physics parameters (matching SwiftUI's approach)
        let dampingRatio: CGFloat = 0.6  // Controls bounciness (< 1 = bouncy, 1 = no overshoot, > 1 = slow)
        let response: CGFloat = decorativeCirclesDuration  // Response time matches animation duration
        
        // Calculate natural frequency (rad/s)
        let omega0 = 2 * .pi / response
        
        // For underdamped springs (dampingRatio < 1), calculate damped frequency
        if dampingRatio < 1 {
            let omegaD = omega0 * sqrt(1 - dampingRatio * dampingRatio)
            
            // Spring equation for underdamped case (normalized from 0 to 1)
            let envelope = exp(-dampingRatio * omega0 * elapsed)
            let A: CGFloat = 1  // Initial displacement
            let B = (dampingRatio * omega0 * A) / omegaD
            let oscillation = A * cos(omegaD * elapsed) + B * sin(omegaD * elapsed)
            
            return min(max(1 - envelope * oscillation, 0), 1)
        }
//        else if dampingRatio == 1 {
//            // Critically damped (no overshoot)
//            let A: CGFloat = 1 //Will never be executed
//            let B = omega0 * A
//            return min(max(1 - (A + B * elapsed) * exp(-omega0 * elapsed), 0), 1)
//        } else {
//            // Overdamped (slow, no overshoot)
//            let r1 = -omega0 * (dampingRatio + sqrt(dampingRatio * dampingRatio - 1)) //Will never be executed
//            let r2 = -omega0 * (dampingRatio - sqrt(dampingRatio * dampingRatio - 1))
//            let A = -r2 / (r1 - r2)
//            let B: CGFloat = 1 - A
//            return min(max(1 - (A * exp(r1 * elapsed) + B * exp(r2 * elapsed)), 0), 1)
//        }
    }

}

// MARK: - Geometry & Animation Helpers
private extension BubbleView {
    /// Precomputed animation info for each metaball.
    struct CircleAnimationData {
        let baseDiameter: CGFloat
        let amplitude: CGFloat  // Oscillation range around the base diameter
        let phase: CGFloat
        let direction: CGFloat  // +1 or -1, determines if it grows or shrinks first
    }

    /// Output of the packing algorithm that tries to fill the perimeter with circles that respect min/max bounds.
    struct PackingResult {
        let diameters: [CGFloat]
        let isValid: Bool
    }

    /// Deterministic RNG so the bubble animation remains stable for a given seed.
    struct SeededRandomGenerator: RandomNumberGenerator {
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

    /// Packs the given perimeter with circles that stay between `min` and `max` diameters.
    static func computeDiameters(length L: CGFloat, min a: CGFloat, max b: CGFloat, seed: UInt64) -> PackingResult {
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

    /// Prepares the per-circle oscillation data so the total length remains stable during animation.
    static func computeAnimationData(baseDiameters: [CGFloat], min: CGFloat, max: CGFloat, seed: UInt64) -> [CircleAnimationData] {
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

    /// Applies the oscillation data while ensuring the combined length equals the perimeter.
    static func calculateAnimatedDiameters(
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

    /// Converts circle diameters and travel progress into centre points along a rounded rectangle path.
    static func calculatePositions(
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

    /// Maps a distance along the rounded rectangle perimeter to a concrete coordinate.
    static func pointOnRoundedRectPath(
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

    /// Calculates the perimeter of a rounded rectangle (used for circle packing & animation).
    static func calculateRoundedRectPerimeter(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> CGFloat {
        let straightWidth = width - 2 * cornerRadius
        let straightHeight = height - 2 * cornerRadius
        let arcLength = 2 * .pi * cornerRadius // Full circle circumference

        return 2 * straightWidth + 2 * straightHeight + arcLength
    }
}

#Preview("Bubble View"){
    VStack(alignment: .leading, spacing: 16) {
        //            Text("Small rounded rectangle")
        BubbleView(
            width: 68,
            height: 40,
            cornerRadius: 20,
            minDiameter: 12,
            maxDiameter: 25,
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
//    .previewLayout(.sizeThatFits)
}

struct MorphPreview: View {
    @State private var isTalking = true
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
                mode: isTalking ? .talking : .thinking,
                showTail: true,
            )
            .frame(width: width + 120, height: height + 120)
            
            Button(isTalking ? "Switch to Thinking" : "Switch to Talking") {
                isTalking.toggle()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        //            .background(Color.base)
    }
}

#Preview("Thought Bubble Morph") {
     MorphPreview()
}

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
    /// Rounded corner radius applied to the inner rectangle (optional override, defaults to bubbleConfig).
    let cornerRadius: CGFloat?
    /// Fill color for the bubble and metaballs.
    let color: Color
    /// Current behavioural mode (thinking vs talking).
    let mode: BubbleMode
    /// Whether to render the decorative bubble tail.
    let showTail: Bool
    /// Message direction used to align the bubble tail.
    let messageType: MessageType
    
    // MARK: - Environment
    
    @Environment(BubbleConfiguration.self) private var bubbleConfig

    // MARK: - Timing

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
    /// Start timestamp for the thinking→read explosion animation.
    @State private var thinkingToReadExplosionStart: Date?
    /// Stores the morphProgress value to freeze during explosion.
    @State private var frozenMorphProgress: CGFloat = 0

    // MARK: - Derived Layout

    /// Padding around the inner rectangle to accommodate circles and blur.
    private func basePadding(config: BubbleConfiguration) -> CGFloat {
        (config.bubbleMaxDiameter / 2 + config.bubbleBlurRadius) * 1
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

    /// Creates a bubble with the provided geometry and visual configuration.
    /// - Parameters:
    ///   - width: Target width of the inner rectangle.
    ///   - height: Target height of the inner rectangle.
    ///   - cornerRadius: Optional override for the rounded corners. Defaults to config or pill shape.
    ///   - color: Fill color used for the bubble and circles.
    ///   - mode: Talking/thinking state. Influences morph progression.
    ///   - showTail: Whether to draw the decorative tail assets.
    ///   - messageType: Layout direction for the tail and alignment.
    init(
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat? = nil,
        color: Color,
        mode: BubbleMode = .thinking,
        showTail: Bool = false,
        messageType: MessageType = .inbound
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.color = color
        self.mode = mode
        self.showTail = showTail
        self.messageType = messageType

        let now = Date()
        let config = BubbleConfiguration()
        
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
        _modeAnimationStart = State(initialValue: now.addingTimeInterval(-config.morphDuration))
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
            let currentValue = transition.value(at: now, duration: bubbleConfig.circleTransitionDuration)
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
                let currentValue = transition.value(at: now, duration: bubbleConfig.circleTransitionDuration)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + bubbleConfig.circleTransitionDuration) {
            self.circleTransitions.removeAll { $0.id == id && $0.isDisappearing }
        }
    }

    /// Returns the current interpolated diameters of all visible circles.
    private func currentBaseDiameters(at date: Date) -> [CGFloat] {
        sortedCircleTransitions()
            .compactMap { transition in
                let value = transition.value(at: date, duration: bubbleConfig.circleTransitionDuration)
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
    private func effectiveDiameterBounds(outwardProgress: CGFloat, minDiameter: CGFloat, maxDiameter: CGFloat) -> (min: CGFloat, max: CGFloat)? {
        let clamped = min(max(outwardProgress, 0), 1)
        guard clamped > 0 else { return nil }
        let minBound = max(minDiameter * clamped, 0.5)
        let maxBound = max(maxDiameter * clamped, minBound)
        return (min: minBound, max: maxBound)
    }

    /// Combines packing and morph progress to determine the desired circle diameters.
    private func circleTargetState(perimeter: CGFloat, outwardProgress: CGFloat, seed: UInt64, minDiameter: CGFloat, maxDiameter: CGFloat) -> CircleTargetState {
        guard let bounds = effectiveDiameterBounds(outwardProgress: outwardProgress, minDiameter: minDiameter, maxDiameter: maxDiameter), perimeter > 0.001 else {
            return CircleTargetState(targets: [], minimum: minDiameter, maximum: maxDiameter)
        }

        var targets = bubbleConfig.computeDiameters(
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
        let currentSize = rectangleTransition.value(at: now, duration: bubbleConfig.resizeCutoffDuration)

        // Calculate current velocity based on the spring animation
        // This gives continuity when interrupting an ongoing animation
        let dt: CGFloat = 0.016  // ~1 frame at 60fps
        let futureSize = rectangleTransition.value(at: now.addingTimeInterval(dt), duration: bubbleConfig.resizeCutoffDuration)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + bubbleConfig.morphDuration) {
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
        let actualCornerRadius = cornerRadius ?? min(min(height, width) / 2, bubbleConfig.bubbleCornerRadius)
        let minDiameter = bubbleConfig.bubbleMinDiameter
        let maxDiameter = bubbleConfig.bubbleMaxDiameter
        let blurRadius = bubbleConfig.bubbleBlurRadius
        let basePadding = self.basePadding(config: bubbleConfig)
        
        let targetPerimeter = bubbleConfig.calculateRoundedRectPerimeter(width: width, height: height, cornerRadius: actualCornerRadius)
        let packingResult = bubbleConfig.computeDiameters(length: targetPerimeter, min: minDiameter, max: maxDiameter, seed: animationSeed)
        let targetDiameters = packingResult.diameters
        let isValid = packingResult.isValid

        return TimelineView(.animation) { timeline in
            let now = timeline.date
            let elapsed = now.timeIntervalSince(startTime)
            let animatedSize = rectangleTransition.value(at: now, duration: bubbleConfig.resizeCutoffDuration)
            let baseWidth = max(animatedSize.width, 0)
            let baseHeight = max(animatedSize.height, 0)

            // Check if we're in thinking→read explosion animation
            let explosionProgress = thinkingToReadExplosionProgress(at: now)
            let isExploding = thinkingToReadExplosionStart != nil && explosionProgress < 1

            // During explosion, freeze morphProgress at thinking state (0)
            // After explosion, allow normal mode animation
            let morphProgress = isExploding ? frozenMorphProgress : modeProgress(at: now)

            // Check if we're in read→thinking animation
            let readToThinkingAnimProgress = readToThinkingProgress(at: now)
            let isReadToThinkingActive = mode.isThinking && readToThinkingStart != nil && readToThinkingAnimProgress < 1
            
            let layout = BubbleMorphLayout(
                baseSize: CGSize(width: baseWidth, height: baseHeight),
                baseCornerRadius: actualCornerRadius,
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
            let currentPerimeter = bubbleConfig.calculateRoundedRectPerimeter(
                width: circleTrackWidth,
                height: circleTrackHeight,
                cornerRadius: circleTrackCornerRadius
            )

            let circleState = circleTargetState(
                perimeter: currentPerimeter,
                outwardProgress: outwardProgress,
                seed: animationSeed,
                minDiameter: minDiameter,
                maxDiameter: maxDiameter
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

            let animationData = bubbleConfig.computeAnimationData(
                baseDiameters: baseDiameters,
                min: effectiveMin,
                max: effectiveMax,
                seed: animationSeed
            )

            let animatedDiameters = bubbleConfig.calculateAnimatedDiameters(
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
                // Use the overall animation progress for smooth velocity decay
                // This extends the deceleration over the entire animation duration
                // creating a smooth transition from fast spin to normal orbital motion
                let velocityMultiplier: CGFloat = 1.0  // Initial speed boost
                let decayRate: CGFloat = 3.0  // Slower decay for smoother transition
                let velocityOffset = velocityMultiplier * (1 - readToThinkingAnimProgress) * exp(-decayRate * readToThinkingAnimProgress)
                
                // SUBTRACT the velocity offset for clockwise motion during scale-up
                // The path calculation combined with scale-from-center creates counter-clockwise
                // appearance when velocity is added, so we subtract for true clockwise motion
                let adjustedProgress = (baseMovementProgress - velocityOffset).truncatingRemainder(dividingBy: 1.0)
                movementProgress = adjustedProgress >= 0 ? adjustedProgress : adjustedProgress + 1.0
            } else {
                movementProgress = baseMovementProgress
            }

            // Calculate positions for each circle along the FULL rounded rectangle path
            // Always use the full path - we'll scale positions from center later
            let positions = bubbleConfig.calculatePositions(
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
            // During explosion, keep bubble visible even if mode is .read
            // Only hide after explosion completes
            .opacity((mode.isRead && !isExploding) ? 0 : (messageType.isOutbound ? 1 : 0.25)) //Want 15 for light mode and 25 for dark mode
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
            .explosionEffect(isActive: isExploding, progress: explosionProgress, canvasSize: CGSize(width: canvasWidth, height: canvasHeight))
            // Apply explosion shader when transitioning from thinking to read

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
            // Start thinking→read explosion animation
            if oldMode.isThinking && newMode.isRead {
                // Freeze current morphProgress (should be 0 for thinking state)
                frozenMorphProgress = modeProgress(at: Date())
                thinkingToReadExplosionStart = Date()

                // CRITICAL: Set the mode animation to stay frozen at current value
                // This prevents any morphing during the explosion
                let current = modeProgress(at: Date())
                modeAnimationFrom = current
                modeAnimationTo = current
                modeAnimationStart = Date()

                // Schedule cleanup after explosion completes
                DispatchQueue.main.asyncAfter(deadline: .now() + bubbleConfig.explosionDuration) {
                    self.thinkingToReadExplosionStart = nil
                    // Explosion complete - morphProgress is controlled by frozenMorphProgress during explosion
                    // No need to call startModeAnimation - read mode doesn't need animation
                }
            } else {
                // For all other mode transitions, proceed normally
                let target = (newMode.isThinking || newMode.isRead) ? CGFloat(0) : CGFloat(1)
                startModeAnimation(target: target)
            }

            // Start read→thinking animation when transitioning from read to thinking
            if oldMode.isRead && newMode.isThinking {
                readToThinkingStart = Date()
                // Schedule cleanup after animation completes
                DispatchQueue.main.asyncAfter(deadline: .now() + bubbleConfig.readToThinkingDuration) {
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

            // Check if we're in explosion animation
            let explosionProgress = thinkingToReadExplosionProgress(at: now)
            let isExploding = thinkingToReadExplosionStart != nil && explosionProgress < 1

            // During explosion, keep tail in thinking position
            // Otherwise use normal logic (read and thinking both use thinking tail position)
            let isThinking = mode.isThinking || (mode.isRead && !isExploding) || isExploding
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
        let duration = bubbleConfig.morphDuration
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
        if elapsed >= bubbleConfig.readToThinkingDuration {
            return 1
        }
        return CGFloat(elapsed / bubbleConfig.readToThinkingDuration)
    }

    /// Returns the progress for the thinking→read explosion animation at a given timestamp.
    /// - Returns: A value from 0 to 1, where 0 is the start and 1 is complete.
    private func thinkingToReadExplosionProgress(at now: Date) -> CGFloat {
        guard let start = thinkingToReadExplosionStart else { return 1 }
        let elapsed = now.timeIntervalSince(start)
        if elapsed <= 0 {
            return 0
        }
        if elapsed >= bubbleConfig.explosionDuration {
            return 1
        }
        return CGFloat(elapsed / bubbleConfig.explosionDuration)
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
        let startPoint = decorativeCirclesDelay / bubbleConfig.readToThinkingDuration
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
        
        // Fallback (should never be reached with dampingRatio < 1)
        return normalizedProgress >= 0.5 ? 1 : 0
    }

}

#Preview("Bubble View"){
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    
    VStack(alignment: .leading, spacing: 16) {
        BubbleView(
            width: 68,
            height: 40,
            cornerRadius: 20,
            color: .blue
        )
    }
    .padding()
    .environment(bubbleConfig)
}

#Preview("Thought Bubble Morph") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var isTalking = true
    @Previewable @State var width: CGFloat = 220
    @Previewable @State var height: CGFloat = 120
    
    VStack(spacing: 24) {
        BubbleView(
            width: width,
            height: height,
            cornerRadius: 26,
            color: .Default.inboundBubble,
            mode: isTalking ? .talking : .thinking,
            showTail: true
        )
        .frame(width: width + 120, height: height + 120)
        
        Button(isTalking ? "Switch to Thinking" : "Switch to Talking") {
            isTalking.toggle()
        }
        .buttonStyle(.borderedProminent)
    }
    .padding()
    .environment(bubbleConfig)
}

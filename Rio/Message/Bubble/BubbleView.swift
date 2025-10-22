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
    @Environment(BubbleConfiguration.self) private var bubbleConfig

    // MARK: - Configuration

    /// Width of the inner rectangle that the metaballs orbit.
    let width: CGFloat
    /// Height of the inner rectangle that the metaballs orbit.
    let height: CGFloat
    /// Rounded corner radius applied to the inner rectangle (optional override, defaults to bubbleConfig).
    let cornerRadius: CGFloat?
    /// Fill color for the bubble and metaballs.
    let color: Color
    /// Current behavioural bubbleType (thinking vs talking).
    let bubbleType: BubbleType
    /// Whether to render the decorative bubble tail.
    let showTail: Bool
    /// Message direction used to align the bubble tail.
    let messageType: MessageType
    /// Layout type for visual display (may be delayed relative to bubbleType)
    let layoutType: BubbleType?

    // MARK: - Animation Managers (replaces 21 @State variables)

    @State private var circleManager: CircleAnimationManager
    @State private var transitionCoordinator: TransitionCoordinator
    @State private var sizeManager: RectangleSizeManager

    // MARK: - Additional State

    /// Seed that keeps randomised animations stable across refreshes.
    @State private var animationSeed: UInt64
    /// Start time driving the deterministic animation timeline.
    @State private var startTime: Date
    /// Tracks the previous bubbleType to determine animation behavior
    @State private var previousBubbleType: BubbleType?
    /// Tracks the tail position offset for explicit animation control
    @State private var tailPositionOffset: CGPoint = CGPoint(x: 15, y: -23)
    /// Work item for cancelling delayed tail position updates
    @State private var tailPositionWorkItem: DispatchWorkItem?

    // MARK: - Initialization

    /// Creates a bubble with the provided geometry and visual configuration.
    init(
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat? = nil,
        color: Color,
        type: BubbleType = .thinking,
        showTail: Bool = false,
        messageType: MessageType = .inbound(.thinking),
        layoutType: BubbleType? = nil
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.color = color
        self.bubbleType = type
        self.showTail = showTail
        self.messageType = messageType
        self.layoutType = layoutType

        let now = Date()
        let config = BubbleConfiguration()

        _animationSeed = State(initialValue: UInt64.random(in: 0...UInt64.max))
        _startTime = State(initialValue: now)

        // Initialize managers
        _circleManager = State(initialValue: CircleAnimationManager(config: config))
        _transitionCoordinator = State(initialValue: TransitionCoordinator(initialType: type, config: config))
        _sizeManager = State(initialValue: RectangleSizeManager(initialSize: CGSize(width: width, height: height), config: config))

        // Initialize tail position based on initial bubble type
        let initialTailPosition: CGPoint
        if type.isTalking {
            initialTailPosition = CGPoint(x: 3, y: -1)  // Talking position
        } else {
            initialTailPosition = CGPoint(x: 15, y: -23)  // Thinking/Read position
        }
        _tailPositionOffset = State(initialValue: initialTailPosition)
    }

    // MARK: - Computed Properties

    private var actualCornerRadius: CGFloat {
        cornerRadius ?? min(min(height, width) / 2, bubbleConfig.bubbleCornerRadius)
    }

    private var minDiameter: CGFloat { bubbleConfig.bubbleMinDiameter }
    private var maxDiameter: CGFloat { bubbleConfig.bubbleMaxDiameter }
    private var blurRadius: CGFloat { bubbleConfig.bubbleBlurRadius }

    private func basePadding(config: BubbleConfiguration) -> CGFloat {
        (config.bubbleMaxDiameter / 2 + config.bubbleBlurRadius) * 1
    }

    private var basePadding: CGFloat { self.basePadding(config: bubbleConfig) }

    private var targetPerimeter: CGFloat {
        bubbleConfig.calculateRoundedRectPerimeter(width: width, height: height, cornerRadius: actualCornerRadius)
    }

    private var packingResult: PackingResult {
        bubbleConfig.computeDiameters(length: targetPerimeter, min: minDiameter, max: maxDiameter, seed: animationSeed)
    }

    private var targetDiameters: [CGFloat] { packingResult.diameters }
    private var isValid: Bool { packingResult.isValid }

    var isReadLayout: Bool { (layoutType?.isRead ?? bubbleType.isRead) }
    var shouldHideBubble: Bool { isReadLayout && !transitionCoordinator.isExploding(at: Date()) }

    var resolvedColor: Color {
        messageType.isOutbound ? color : Color.base.mix(with: color, by: 0.2)
    }

    var body: some View {
        Group {
            if transitionCoordinator.canUseNative {
                RoundedRectangle(cornerRadius: bubbleConfig.bubbleCornerRadius)
                    .fill(resolvedColor)
            } else {
                TimelineView(.animation) { timeline in
                    return makeAnimatedBubble(at: timeline.date)
                }
            }
        }
        .overlay(alignment: messageType.isInbound ? .bottomLeading : .bottomTrailing) {
            TalkingTailView(
                color: resolvedColor,
                showTail: showTail,
                bubbleType: bubbleType,
                layoutType: layoutType,
                messageType: messageType,
                tailPositionOffset: tailPositionOffset,
                previousBubbleType: previousBubbleType
            )
        }
        .opacity(shouldHideBubble ? 0 : 1)
        .background {
            // Hidden text to measure single-line height
            Text("X")
                .font(.body)
                .padding(.vertical, 10)
                .fixedSize()
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { newHeight in
                    sizeManager.singleLineTextHeight = newHeight
                }
                .hidden()
        }
        .onAppear {
            startTime = Date()
            if circleManager.currentTargetDiameters().isEmpty {
                circleManager.configureInitial(targetDiameters: targetDiameters)
            } else {
                circleManager.updateTransitions(targetDiameters: targetDiameters)
            }
            updateSize()
        }
        .onChange(of: CGSize(width: width, height: height)) { _, _ in
            updateSize()
        }
        .onChange(of: targetDiameters) { _, newDiameters in
            circleManager.updateTransitions(targetDiameters: newDiameters)
        }
        .onChange(of: bubbleType) { oldType, newType in
            handleBubbleTypeChange(oldType: oldType, newType: newType)
        }
    }

    // MARK: - Content Builder

    private func makeAnimatedBubble(at now: Date) -> some View {
        let elapsed = now.timeIntervalSince(startTime)

        let animatedSize = sizeManager.currentSize(at: now)

        let baseWidth = max(animatedSize.width, 0)
        let baseHeight = max(animatedSize.height, 0)

        // Get state-specific information
        let isExploding = transitionCoordinator.isExploding(at: now)
        let explosionProgress = transitionCoordinator.explosionProgress(at: now)
        let isScaling = transitionCoordinator.isScaling(at: now)
        let scalingProgress = transitionCoordinator.scalingProgress(at: now)
        let morphProgress = transitionCoordinator.morphProgress(at: now)

        let layout = BubbleMorphLayout(
            baseSize: CGSize(width: baseWidth, height: baseHeight),
            baseCornerRadius: actualCornerRadius,
            basePadding: basePadding,
            blurRadius: blurRadius,
            morphProgress: morphProgress
        )

        // During read→thinking, force blur and alpha to full strength for metaball effect
        let currentBlurRadius = isScaling ? blurRadius : layout.blurRadius
        let circleTrackWidth = layout.circleTrackWidth
        let circleTrackHeight = layout.circleTrackHeight
        let circleTrackCornerRadius = layout.circleTrackCornerRadius
        let outwardProgress = layout.outwardProgress

        // Handle decorative circles progress for read→thinking
        let decorativeProgress = isScaling ? decorativeCirclesProgress(progress: scalingProgress) : 1.0

        let displayWidth: CGFloat
        let displayHeight: CGFloat
        let displayCornerRadius: CGFloat

        if isScaling {
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

        // During read→thinking, force alpha threshold to full strength
        let alphaThresholdMin = isScaling ? 0.2 : layout.alphaThreshold

        // Size oscillation progress (3 second cycle)
        let sizeProgress = CGFloat(elapsed / 3.0).truncatingRemainder(dividingBy: 1.0)

        let baseDiameters = circleManager.currentBaseDiameters(at: now)
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
        let existingTargets = circleManager.currentTargetDiameters()

        if !circleManager.almostEqual(existingTargets, desiredTargets) {
            DispatchQueue.main.async {
                let refreshedTargets = circleManager.currentTargetDiameters()
                if !circleManager.almostEqual(refreshedTargets, desiredTargets) {
                    circleManager.updateTransitions(targetDiameters: desiredTargets)
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
        if isScaling {
            let velocityMultiplier: CGFloat = 1.0
            let decayRate: CGFloat = 3.0
            let velocityOffset = velocityMultiplier * (1 - scalingProgress) * exp(-decayRate * scalingProgress)

            let adjustedProgress = (baseMovementProgress - velocityOffset).truncatingRemainder(dividingBy: 1.0)
            movementProgress = adjustedProgress >= 0 ? adjustedProgress : adjustedProgress + 1.0
        } else {
            movementProgress = baseMovementProgress
        }

        // Calculate positions for each circle along the rounded rectangle path
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

        if isScaling {
            // During read→thinking, scale entire coordinate system from center
            morphedPositions = positions.map { point in
                let offset = CGPoint(x: point.x - centerPoint.x, y: point.y - centerPoint.y)
                let scaledOffset = CGPoint(x: offset.x * decorativeProgress, y: offset.y * decorativeProgress)
                return CGPoint(x: centerPoint.x + scaledOffset.x, y: centerPoint.y + scaledOffset.y)
            }

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
        return Canvas { context, _ in
            if alphaThresholdMin > 0.001 {
                context.addFilter(.alphaThreshold(min: Double(alphaThresholdMin), color: isValid ? color : Color.red.opacity(0.5)))
            }
            if currentBlurRadius > 0.05 {
                context.addFilter(.blur(radius: currentBlurRadius))
            }

            context.drawLayer { ctx in
                let rectOrigin = layout.rectangleOrigin(for: CGSize(width: displayWidth, height: displayHeight))
                let trackOrigin = layout.rectangleOrigin(for: layout.circleTrackSize)
                let rectPath = RoundedRectangle(cornerRadius: displayCornerRadius)
                    .path(in: CGRect(origin: rectOrigin, size: CGSize(width: displayWidth, height: displayHeight)))
                ctx.fill(rectPath, with: .color(color))

                // Draw circles around the path
                for index in morphedDiameters.indices {
                    if let circleSymbol = ctx.resolveSymbol(id: index) {
                        let position = CGPoint(
                            x: morphedPositions[index].x + trackOrigin.x,
                            y: morphedPositions[index].y + trackOrigin.y
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
        .explosionEffect(isActive: isExploding, progress: explosionProgress)
        .overlay(alignment: messageType.isInbound ? .bottomLeading : .bottomTrailing) {
            ThinkingTailView(
                color: color,
                showTail: showTail,
                bubbleType: bubbleType,
                layoutType: layoutType,
                messageType: messageType,
                scalingProgress: scalingProgress,
                isExploding: isExploding,
                explosionProgress: explosionProgress,
                previousBubbleType: previousBubbleType
            )
        }
    }

    // MARK: - Helpers

    /// Updates the rectangle size through the size manager
    private func updateSize() {
        let animationState = transitionCoordinator.animationState
        let skipAnimation = transitionCoordinator.shouldSkipSizeAnimation(at: Date())
        sizeManager.updateSize(
            to: CGSize(width: width, height: height),
            animationState: animationState,
            skipAnimation: skipAnimation
        )
    }

    /// Handles bubble type changes and coordinates transitions
    private func handleBubbleTypeChange(oldType: BubbleType, newType: BubbleType) {
        guard oldType != newType else { return }

        // Track previous bubble type
        previousBubbleType = oldType

        // Cancel any pending tail position updates
        tailPositionWorkItem?.cancel()
        tailPositionWorkItem = nil

        // Start transition
        transitionCoordinator.startTransition(from: oldType, to: newType)

        // Manage tail position
        manageTailPosition(from: oldType, to: newType)

        // Update size
        updateSize()
    }

    /// Manages tail position transitions
    private func manageTailPosition(from oldType: BubbleType, to newType: BubbleType) {
        let thinkingPosition = CGPoint(x: 15, y: -23)
        let talkingPosition = CGPoint(x: 3, y: -1)

        if newType.isThinking || newType.isRead {
            tailPositionOffset = thinkingPosition
        } else if newType.isTalking {
            if oldType.isRead {
                // Read→Talking: Set position instantly
                tailPositionOffset = talkingPosition
            } else if oldType.isThinking {
                // Thinking→Talking: Start at thinking, animate to talking after delay
                tailPositionOffset = thinkingPosition

                let workItem = DispatchWorkItem {
                    self.tailPositionOffset = talkingPosition
                }
                tailPositionWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
            } else {
                tailPositionOffset = talkingPosition
            }
        }
    }

    /// Calculates circle target state
    private func circleTargetState(
        perimeter: CGFloat,
        outwardProgress: CGFloat,
        seed: UInt64,
        minDiameter: CGFloat,
        maxDiameter: CGFloat
    ) -> CircleTargetState {
        guard let bounds = effectiveDiameterBounds(
            outwardProgress: outwardProgress,
            minDiameter: minDiameter,
            maxDiameter: maxDiameter
        ), perimeter > 0.001 else {
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

    /// Calculates effective diameter bounds based on morph progress
    private func effectiveDiameterBounds(
        outwardProgress: CGFloat,
        minDiameter: CGFloat,
        maxDiameter: CGFloat
    ) -> (min: CGFloat, max: CGFloat)? {
        let clamped = min(max(outwardProgress, 0), 1)
        guard clamped > 0 else { return nil }
        let minBound = max(minDiameter * clamped, 0.5)
        let maxBound = max(maxDiameter * clamped, minBound)
        return (min: minBound, max: maxBound)
    }

    /// Linearly interpolates between two points
    private func interpolate(_ start: CGPoint, to end: CGPoint, progress: CGFloat) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
    }

    /// Returns the decorative circles scale/position progress with bouncy spring easing
    private func decorativeCirclesProgress(progress: CGFloat) -> CGFloat {
        let decorativeCirclesDelay: TimeInterval = 0.1
        let decorativeCirclesDuration: TimeInterval = 0.3

        let startPoint = decorativeCirclesDelay / bubbleConfig.readToThinkingDuration
        if progress < startPoint {
            return 0
        }
        let normalizedProgress = (progress - startPoint) / (1 - startPoint)
        let elapsed = normalizedProgress * decorativeCirclesDuration

        // Spring physics parameters
        let dampingRatio: CGFloat = 0.6
        let response: CGFloat = decorativeCirclesDuration

        let omega0 = 2 * .pi / response
        let omegaD = omega0 * sqrt(1 - dampingRatio * dampingRatio)

        let envelope = exp(-dampingRatio * omega0 * elapsed)
        let A: CGFloat = 1
        let B = (dampingRatio * omega0 * A) / omegaD
        let oscillation = A * cos(omegaD * elapsed) + B * sin(omegaD * elapsed)

        return min(max(1 - envelope * oscillation, 0), 1)
    }
}

// MARK: - Supporting Types

/// Encapsulates the desired circle diameters once constraints and morph progress are applied.
private struct CircleTargetState {
    let targets: [CGFloat]
    let minimum: CGFloat
    let maximum: CGFloat
}

/// Bundles derived layout values for the metaball canvas and the underlying bubble.
fileprivate struct BubbleMorphLayout {
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

// MARK: - Previews

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
            type: isTalking ? .talking : .thinking,
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

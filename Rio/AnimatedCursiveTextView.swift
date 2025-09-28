//
//  AnimatedCursiveTextView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/26/25.
//

import SwiftUI
import SVGPath
import os.log

struct AnimatedCursiveTextView: View {
    @State private var drawProgress: CGFloat = 0
    @State private var drawProgressFrom: CGFloat = 0
    @State private var maxPipeX: CGFloat = 0
    @State private var maxDrawProgressFrom: CGFloat = 0
    @State private var animationTimer: Timer?

    // Smoothing state for textOffset
    @State private var smoothedTextOffset: CGFloat = 0
    @State private var textOffsetVelocity: CGFloat = 0
    @State private var lastOffsetUpdateTime: Date?
    @State private var maxLeftShift: CGFloat = 0  // Tracks the furthest left shift we've applied
    @State private var filteredLeftTarget: CGFloat = 0  // Low-pass target that keeps sliding left smoothly

    // Smoothing state for drawProgressFrom to prevent jittery trim clipping
    @State private var smoothedDrawProgressFrom: CGFloat = 0
    @State private var drawProgressFromVelocity: CGFloat = 0
    @State private var targetDrawProgressFrom: CGFloat = 0
    private let nominalFrameDuration: CGFloat = 1.0 / 60.0
    private let offsetSpringStiffness: CGFloat = 180
    private let offsetSpringDamping: CGFloat = 28
    private let minCatchupSpeed: CGFloat = 80     // px per second when accuracy is 0
    private let maxCatchupSpeed: CGFloat = 2400   // px per second when accuracy is 1
    private let maxDriftSpeed: CGFloat = 80       // px per second of continual left drift when accuracy is 0

    // Smoothing constants for drawProgressFrom to prevent jittery trim clipping
    private let trimSpringStiffness: CGFloat = 120  // Slightly less stiff than offset for smoother motion
    private let trimSpringDamping: CGFloat = 22     // Slightly less damped for smoother motion

    @State private var pathAnalyzer: PathXAnalyzer?

    // Configuration parameters
    let text: String
    let fontSize: CGFloat
    let animationDuration: Double
    let staticMode: Bool
    let showProgressIndicator: Bool
    let forwardOnlyMode: Bool
    let windowWidth: CGFloat
    let variableSpeed: Bool
    let trackingAccuracy: CGFloat

    // Computed properties
    private var fontSizeValue: CGFloat { fontSize }
    private var measuredWordSize: CGSize {
        CursiveWordShape.preferredSize(for: text, fontSize: fontSizeValue)
            ?? CGSize(width: fontSizeValue * 8, height: fontSizeValue * 1.4)
    }

    init(
        text: String,
        fontSize: CGFloat = 30,
        animationDuration: Double? = nil,
        staticMode: Bool = true,
        showProgressIndicator: Bool = false,
        forwardOnlyMode: Bool = true,
        windowWidth: CGFloat = 40,
        variableSpeed: Bool = false,
        trackingAccuracy: CGFloat = 0.85
    ) {
        self.text = text
        self.fontSize = fontSize
        self.animationDuration = animationDuration ?? Double(text.count) / 2
        self.staticMode = staticMode
        self.showProgressIndicator = showProgressIndicator
        self.forwardOnlyMode = forwardOnlyMode
        self.windowWidth = windowWidth
        self.variableSpeed = variableSpeed
        self.trackingAccuracy = min(max(trackingAccuracy, 0), 1)
    }

    var shape: CursiveWordShape {
        CursiveWordShape(text: text, fontSize: fontSize)
    }

    var path: Path {
        shape.path(in: CGRect(origin: .zero, size: measuredWordSize))
    }

    var trimEndPoint: CGPoint {
        pathAnalyzer?.pointAtParameter(drawProgress) ?? .zero
    }

    var pipeX: CGFloat {
        if forwardOnlyMode && !staticMode {
            // Forward-only mode: only increase, never decrease
            let currentX = trimEndPoint.x
            if currentX > maxPipeX {
                // Update max if we've moved forward
                DispatchQueue.main.async {
                    maxPipeX = currentX
                }
                return currentX
            }
            return maxPipeX
        } else {
            // Normal mode: follow the actual trim end point
            return trimEndPoint.x
        }
    }

    var textOffset: CGFloat {
        guard staticMode else { return 0 }
        guard windowWidth > 0 else { return 0 }

        let effectiveWidth = min(windowWidth, measuredWordSize.width)
        let headX = trimEndPoint.x
        let overshoot = headX - effectiveWidth
        guard overshoot > 0 else { return 0 }

        let maxShift = max(0, measuredWordSize.width - effectiveWidth)
        return -min(overshoot, maxShift)
    }

    // Smoothed version of textOffset for animations using a critically damped spring
    private func updateSmoothedTextOffset(deltaTime rawDeltaTime: CGFloat) {
        guard staticMode else {
            smoothedTextOffset = 0
            textOffsetVelocity = 0
            lastOffsetUpdateTime = nil
            maxLeftShift = 0
            filteredLeftTarget = 0
            return
        }

        let targetOffset = textOffset

        let effectiveWidth = min(windowWidth, measuredWordSize.width)
        let maxShift = max(0, measuredWordSize.width - effectiveWidth)
        let minOffset = -maxShift

        maxLeftShift = min(maxLeftShift, targetOffset)
        maxLeftShift = max(maxLeftShift, minOffset)

        let clampedDelta = max(nominalFrameDuration * 0.25, min(rawDeltaTime, nominalFrameDuration * 4))
        let clampedAccuracy = min(max(trackingAccuracy, 0), 1)

        let lerp: (CGFloat, CGFloat, CGFloat) -> CGFloat = { start, end, t in
            start + (end - start) * t
        }

        let catchupSpeed = lerp(minCatchupSpeed, maxCatchupSpeed, clampedAccuracy)
        let driftSpeed = lerp(maxDriftSpeed, 0, clampedAccuracy)
        let overshootAllowance = lerp(80, 8, clampedAccuracy)

        var nextFiltered = filteredLeftTarget
        let deltaToTarget = maxLeftShift - nextFiltered

        if deltaToTarget < 0 {
            let maxStep = -catchupSpeed * clampedDelta
            nextFiltered += max(deltaToTarget, maxStep)
        } else if maxLeftShift < 0 && driftSpeed > 0 {
            let driftLimit = max(maxLeftShift - overshootAllowance, minOffset)
            if nextFiltered > driftLimit {
                let driftStep = -driftSpeed * clampedDelta
                nextFiltered = max(nextFiltered + driftStep, driftLimit)
            }
        }

        if nextFiltered > filteredLeftTarget {
            nextFiltered = filteredLeftTarget
        }

        nextFiltered = max(nextFiltered, minOffset)
        filteredLeftTarget = nextFiltered

        let desiredOffset = filteredLeftTarget

        // Critically damped spring keeps motion smooth while remaining responsive
        let displacement = desiredOffset - smoothedTextOffset
        let acceleration = offsetSpringStiffness * displacement - offsetSpringDamping * textOffsetVelocity
        textOffsetVelocity += acceleration * clampedDelta
        smoothedTextOffset += textOffsetVelocity * clampedDelta

        // Clamp to valid scrolling bounds, enforce forward-only motion, and snap when near target
        smoothedTextOffset = min(0, max(minOffset, smoothedTextOffset))

        if smoothedTextOffset > desiredOffset {
            smoothedTextOffset = desiredOffset
            textOffsetVelocity = min(textOffsetVelocity, 0)
        }

        if abs(desiredOffset - smoothedTextOffset) < 0.1 && abs(textOffsetVelocity) < 0.05 {
            smoothedTextOffset = desiredOffset
            textOffsetVelocity = 0
        }
    }

    // Smoothed version of drawProgressFrom for trim animations using a critically damped spring
    private func updateSmoothedDrawProgressFrom(deltaTime rawDeltaTime: CGFloat) {
        guard staticMode else {
            smoothedDrawProgressFrom = 0
            drawProgressFromVelocity = 0
            targetDrawProgressFrom = 0
            return
        }

        let clampedDelta = max(nominalFrameDuration * 0.25, min(rawDeltaTime, nominalFrameDuration * 4))

        // Use the target that was calculated in the main animation loop
        let desiredFrom = targetDrawProgressFrom

        // Critically damped spring for smooth motion
        let displacement = desiredFrom - smoothedDrawProgressFrom
        let acceleration = trimSpringStiffness * displacement - trimSpringDamping * drawProgressFromVelocity
        drawProgressFromVelocity += acceleration * clampedDelta
        smoothedDrawProgressFrom += drawProgressFromVelocity * clampedDelta

        // Clamp to valid range [0, 1] and ensure we don't go backwards too much
        smoothedDrawProgressFrom = max(0, min(1, smoothedDrawProgressFrom))

        // Prevent going backwards beyond the target (forward-only constraint)
        if smoothedDrawProgressFrom < desiredFrom {
            smoothedDrawProgressFrom = max(smoothedDrawProgressFrom, desiredFrom - 0.05) // Allow small backward motion for smoothness
        }

        // Snap when very close to target to prevent oscillation
        if abs(desiredFrom - smoothedDrawProgressFrom) < 0.001 && abs(drawProgressFromVelocity) < 0.01 {
            smoothedDrawProgressFrom = desiredFrom
            drawProgressFromVelocity = 0
        }
    }

    // Convert linear time progress to path-length-adjusted progress
    private func adjustProgressForPathLength(_ linearProgress: CGFloat) -> CGFloat {
        guard !variableSpeed else { return linearProgress }
        guard let analyzer = pathAnalyzer else { return linearProgress }

        // When variableSpeed is false, we want the visual progress to be linear
        // This means we need to adjust the path parameter based on path length density
        let targetPathLength = linearProgress * analyzer.totalPathLength

        // Use binary search for efficiency (O(log n) instead of O(n))
        let samples = analyzer.samples
        var low = 0
        var high = samples.count - 1

        while low < high {
            let mid = (low + high) / 2
            if samples[mid].cumulativeLength < targetPathLength {
                low = mid + 1
            } else {
                high = mid
            }
        }

        // Interpolate between samples for smooth results
        if low > 0 && low < samples.count {
            let prevSample = samples[low - 1]
            let currentSample = samples[low]
            let lengthDiff = currentSample.cumulativeLength - prevSample.cumulativeLength

            if lengthDiff > 0 {
                let t = (targetPathLength - prevSample.cumulativeLength) / lengthDiff
                return prevSample.u + t * (currentSample.u - prevSample.u)
            }
        }

        return low < samples.count ? samples[low].u : 1.0
    }

    var body: some View {
        ZStack(alignment: .leading) {
            CursiveWordShape(text: text, fontSize: fontSize)
                .trim(from: staticMode ? smoothedDrawProgressFrom : 0, to: drawProgress)
                .stroke(
                    Color.secondary,
                    style: StrokeStyle(
                        lineWidth: fontSizeValue / 20,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: measuredWordSize.width, height: measuredWordSize.height, alignment: .leading)
                .offset(x: staticMode ? smoothedTextOffset : 0)

            progressIndicatorView
        }
        .frame(width: measuredWordSize.width, height: measuredWordSize.height, alignment: .leading)
        .fixedSize()  // Preserve intrinsic size so parent clipping affects the trailing edge
        .onAppear {
            restartAnimation()
        }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }

    var progressIndicatorView: some View {
        Group {
            if showProgressIndicator {
                if staticMode {
                    if let analyzer = pathAnalyzer {
                        let fromPoint = analyzer.pointAtParameter(smoothedDrawProgressFrom)
                        Rectangle()
                            .fill(Color.green.opacity(0.7))
                            .frame(width: 2, height: measuredWordSize.height)
                            .position(
                                x: fromPoint.x + smoothedTextOffset,
                                y: measuredWordSize.height / 2
                            )
                            .frame(width: measuredWordSize.width, height: measuredWordSize.height, alignment: .leading)

                        Rectangle()
                            .fill(Color.red.opacity(0.7))
                            .frame(width: 2, height: measuredWordSize.height)
                            .position(
                                x: pipeX + smoothedTextOffset,
                                y: measuredWordSize.height / 2
                            )
                            .frame(width: measuredWordSize.width, height: measuredWordSize.height, alignment: .leading)
                    }
                } else {
                    Rectangle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 2, height: measuredWordSize.height)
                        .position(
                            x: pipeX,
                            y: measuredWordSize.height / 2
                        )
                        .frame(width: measuredWordSize.width, height: measuredWordSize.height, alignment: .leading)
                }
            }
        }
    }

    func restartAnimation() {
        // Cancel any existing timer
        animationTimer?.invalidate()

        // Reset progress and max positions
        drawProgress = 0
        drawProgressFrom = 0
        maxPipeX = 0
        maxDrawProgressFrom = 0

        // Reset smoothing state
        smoothedTextOffset = 0
        textOffsetVelocity = 0
        lastOffsetUpdateTime = nil
        maxLeftShift = 0
        filteredLeftTarget = 0

        // Reset trim smoothing state
        smoothedDrawProgressFrom = 0
        drawProgressFromVelocity = 0
        targetDrawProgressFrom = 0

        // Get path analyzer for window calculations
        let shape = CursiveWordShape(text: text, fontSize: fontSizeValue)
        let path = shape.path(in: CGRect(origin: .zero, size: measuredWordSize))
        let analyzer = PathXAnalyzer(path: path.cgPath)
        self.pathAnalyzer = analyzer

        // Start animation with timer for continuous updates
        let startTime = Date()
        var endPhaseStartTime: Date? = nil

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [self] timer in
            let now = Date()
            let elapsed = now.timeIntervalSince(startTime)
            let progress = min(elapsed / self.animationDuration, 1.0)

            let rawDeltaTime = self.lastOffsetUpdateTime.map { CGFloat(now.timeIntervalSince($0)) } ?? nominalFrameDuration
            self.lastOffsetUpdateTime = now

            if self.staticMode {
                // Check if we've reached the end with the red pipe
                if progress >= 1.0 && self.drawProgressFrom < 1.0 {
                    if endPhaseStartTime == nil {
                        endPhaseStartTime = Date()
                    }

                    self.drawProgress = 1.0

                    let endElapsed = now.timeIntervalSince(endPhaseStartTime!)
                    let endDuration = 0.5
                    let endProgress = min(endElapsed / endDuration, 1.0)

                    let startFrom = self.maxDrawProgressFrom
                    let newTargetFrom = startFrom + (1.0 - startFrom) * endProgress
                    self.targetDrawProgressFrom = newTargetFrom
                    self.drawProgressFrom = newTargetFrom  // Keep for compatibility

                    self.updateSmoothedTextOffset(deltaTime: rawDeltaTime)
                    self.updateSmoothedDrawProgressFrom(deltaTime: rawDeltaTime)

                    if self.targetDrawProgressFrom >= 1.0 {
                        self.targetDrawProgressFrom = 1.0
                        self.drawProgressFrom = 1.0
                        timer.invalidate()
                        self.animationTimer = nil
                    }

                    return
                }

                let adjustedProgress = self.adjustProgressForPathLength(progress)
                self.drawProgress = adjustedProgress

                if self.windowWidth > 0 {
                    let effectiveWidth = min(self.windowWidth, analyzer.bounds.width)
                    let windowStart = analyzer.parameterXPixelsBefore(
                        endParameter: adjustedProgress,
                        xDistance: effectiveWidth
                    )
                    let clampedFrom = min(windowStart, adjustedProgress)
                    if clampedFrom > self.maxDrawProgressFrom {
                        self.maxDrawProgressFrom = clampedFrom
                    }
                    self.targetDrawProgressFrom = self.maxDrawProgressFrom
                    self.drawProgressFrom = self.maxDrawProgressFrom  // Keep for compatibility
                } else {
                    self.targetDrawProgressFrom = 0
                    self.drawProgressFrom = 0
                    self.maxDrawProgressFrom = 0
                }

                self.updateSmoothedTextOffset(deltaTime: rawDeltaTime)
                self.updateSmoothedDrawProgressFrom(deltaTime: rawDeltaTime)
            } else {
                let adjustedProgress = self.adjustProgressForPathLength(progress)
                self.drawProgress = adjustedProgress
                self.targetDrawProgressFrom = 0
                self.drawProgressFrom = 0
                self.maxDrawProgressFrom = 0

                self.updateSmoothedTextOffset(deltaTime: rawDeltaTime)
                self.updateSmoothedDrawProgressFrom(deltaTime: rawDeltaTime)

                if progress >= 1.0 {
                    timer.invalidate()
                    self.animationTimer = nil
                }
            }
        }
    }
}

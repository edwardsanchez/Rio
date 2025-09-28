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

    // Dual tracking: visual trim position vs offset calculation position
    @State private var smoothedDrawProgressFrom: CGFloat = 0  // Forward-only for visual trim
    @State private var targetDrawProgressFrom: CGFloat = 0
    @State private var naturalDrawProgressFrom: CGFloat = 0   // Forward-only for offset calculation
    @State private var maxNaturalDrawProgressFrom: CGFloat = 0 // Track maximum natural position reached
    @State private var lastUpdateTime: Date?

    // Ratchet mechanism for textOffset - only moves leftward
    @State private var minTextOffset: CGFloat = 0  // Most negative offset reached

    // Fixed left edge position for static window mode
    private let fixedLeftEdgeX: CGFloat = 0

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

    private var trimStartVisualX: CGFloat {
        guard staticMode else { return 0 }
        let fallback = pathAnalyzer?.pointAtParameter(smoothedDrawProgressFrom).x ?? fixedLeftEdgeX
        let trimmed = path.trimmedPath(from: 0, to: smoothedDrawProgressFrom)
        let rect = trimmed.boundingRect
        if rect.isNull || rect.isInfinite {
            return fallback
        }
        return rect.maxX
    }

    private var trimEndVisualX: CGFloat {
        let fallback = pathAnalyzer?.pointAtParameter(drawProgress).x ?? fixedLeftEdgeX
        let trimmed = path.trimmedPath(from: 0, to: drawProgress)
        let rect = trimmed.boundingRect
        if rect.isNull || rect.isInfinite {
            return fallback
        }
        return rect.maxX
    }

    var pipeX: CGFloat {
        if staticMode {
            return trimEndVisualX
        }

        if forwardOnlyMode {
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
        }

        // Normal mode: follow the actual trim end point
        return trimEndPoint.x
    }

    var textOffset: CGFloat {
        guard staticMode else { return 0 }
        guard windowWidth > 0 else { return 0 }

        // Calculate the ideal offset to align trim start with fixed left edge
        // offset = fixedLeftEdgeX - trimStartVisualX
        let idealOffset = fixedLeftEdgeX - trimStartVisualX

        // Ratchet mechanism: only allow leftward (negative) movement
        // This prevents rightward drift when the path curves back on itself
        let ratchetedOffset = min(idealOffset, minTextOffset)

        // Update the minimum offset if we've moved further left
        DispatchQueue.main.async {
            if idealOffset < minTextOffset {
                minTextOffset = idealOffset
            }
        }

        #if DEBUG
        let actualLeftEdge = trimStartVisualX + ratchetedOffset
        if abs(actualLeftEdge - fixedLeftEdgeX) > 0.01 {
            print("⚠️ Left edge alignment: Expected: \(fixedLeftEdgeX), Actual: \(actualLeftEdge)")
            print("   TrimStartVisualX: \(trimStartVisualX), Ideal: \(idealOffset), Ratcheted: \(ratchetedOffset)")
        }
        #endif

        return ratchetedOffset
    }

    // Dual smoothing: both visual and natural are now forward-only
    private func updateSmoothedDrawProgressFrom() {
        guard staticMode else {
            smoothedDrawProgressFrom = 0
            naturalDrawProgressFrom = 0
            targetDrawProgressFrom = 0
            maxNaturalDrawProgressFrom = 0
            return
        }

        let smoothingFactor: CGFloat = 0.15
        let previousNaturalFrom = naturalDrawProgressFrom
        let previousVisualFrom = smoothedDrawProgressFrom

        // 1. Update naturalDrawProgressFrom - now ALSO forward-only for consistent offset calculation
        // This prevents the left edge drift by ensuring naturalDrawProgressFrom never decreases
        if targetDrawProgressFrom > maxNaturalDrawProgressFrom {
            maxNaturalDrawProgressFrom = targetDrawProgressFrom
        }

        if maxNaturalDrawProgressFrom > naturalDrawProgressFrom {
            naturalDrawProgressFrom += (maxNaturalDrawProgressFrom - naturalDrawProgressFrom) * smoothingFactor
            if abs(maxNaturalDrawProgressFrom - naturalDrawProgressFrom) < 0.0001 {
                naturalDrawProgressFrom = maxNaturalDrawProgressFrom
            }
        }
        naturalDrawProgressFrom = max(0, min(1, naturalDrawProgressFrom))

        // 2. Update smoothedDrawProgressFrom - this is forward-only and used for visual trim
        // This ensures the trim window only moves forward visually
        if targetDrawProgressFrom > smoothedDrawProgressFrom {
            // Allow forward movement
            smoothedDrawProgressFrom += (targetDrawProgressFrom - smoothedDrawProgressFrom) * smoothingFactor
            if abs(targetDrawProgressFrom - smoothedDrawProgressFrom) < 0.0001 {
                smoothedDrawProgressFrom = targetDrawProgressFrom
            }
        } else {
            // Visual position blocked from moving backward
            #if DEBUG
            if targetDrawProgressFrom < previousVisualFrom - 0.0001 {
                print("🛡️ Visual trim movement blocked: target \(targetDrawProgressFrom) < current \(previousVisualFrom)")
            }
            #endif
        }

        smoothedDrawProgressFrom = max(0, min(1, smoothedDrawProgressFrom))

        // Debug logging for position changes
        #if DEBUG
        if abs(naturalDrawProgressFrom - previousNaturalFrom) > 0.0001 {
            let direction = naturalDrawProgressFrom > previousNaturalFrom ? "FORWARD" : "BACKWARD"
            print("📍 Natural position: \(previousNaturalFrom) → \(naturalDrawProgressFrom) (\(direction))")
        }
        if abs(smoothedDrawProgressFrom - previousVisualFrom) > 0.0001 {
            print("👁️ Visual position: \(previousVisualFrom) → \(smoothedDrawProgressFrom) (FORWARD ONLY)")
        }
        #endif
    }

    // Convert linear time progress to path-length-adjusted progress
    private func adjustProgressForPathLength(_ linearProgress: CGFloat) -> CGFloat {
        guard let analyzer = pathAnalyzer else { return linearProgress }

        if variableSpeed {
            // Variable speed mode: use linear progress directly
            return linearProgress
        } else {
            // Fixed speed mode: adjust for path length to achieve linear visual movement
            // This ensures the trim head moves at constant visual speed
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
                .offset(x: staticMode ? textOffset : 0)  // Direct use of computed textOffset

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
                    if pathAnalyzer != nil {
                        // Fixed left edge indicator (blue line) - should never move
                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: 3, height: measuredWordSize.height)
                            .position(
                                x: fixedLeftEdgeX,  // This should always be at x=0
                                y: measuredWordSize.height / 2
                            )
                            .frame(width: measuredWordSize.width, height: measuredWordSize.height, alignment: .leading)

                        // Trim start indicator (green line)
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 3, height: measuredWordSize.height)
                            .position(
                                x: trimStartVisualX + textOffset,
                                y: measuredWordSize.height / 2
                            )
                            .frame(width: measuredWordSize.width, height: measuredWordSize.height, alignment: .leading)

                        // Trim end indicator (red line)
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 3, height: measuredWordSize.height)
                            .position(
                                x: trimEndVisualX + textOffset,
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
        smoothedDrawProgressFrom = 0
        naturalDrawProgressFrom = 0
        targetDrawProgressFrom = 0
        lastUpdateTime = nil

        // Reset forward-only tracking
        maxNaturalDrawProgressFrom = 0

        // Reset ratchet mechanism
        minTextOffset = 0

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

            self.lastUpdateTime = now

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

                    // CRITICAL: Only allow forward movement
                    if newTargetFrom > self.targetDrawProgressFrom {
                        self.targetDrawProgressFrom = newTargetFrom
                        self.drawProgressFrom = newTargetFrom  // Keep for compatibility
                    }

                    self.updateSmoothedDrawProgressFrom()

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
                    // Use measuredWordSize.width instead of analyzer.bounds.width for consistency
                    let effectiveWidth = min(self.windowWidth, self.measuredWordSize.width)
                    let windowStart = analyzer.parameterXPixelsBefore(
                        endParameter: adjustedProgress,
                        xDistance: effectiveWidth
                    )
                    let clampedFrom = min(windowStart, adjustedProgress)

                    // CRITICAL: Ensure forward-only progression
                    // This is the KEY to preventing left edge drift
                    if clampedFrom > self.maxDrawProgressFrom {
                        self.maxDrawProgressFrom = clampedFrom
                        self.targetDrawProgressFrom = clampedFrom
                        self.drawProgressFrom = clampedFrom  // Keep for compatibility
                    }
                    // If clampedFrom would move backward, keep the current position
                    // This ensures smoothedDrawProgressFrom never decreases
                } else {
                    self.targetDrawProgressFrom = 0
                    self.drawProgressFrom = 0
                    self.maxDrawProgressFrom = 0
                }

                self.updateSmoothedDrawProgressFrom()
            } else {
                let adjustedProgress = self.adjustProgressForPathLength(progress)
                self.drawProgress = adjustedProgress
                self.targetDrawProgressFrom = 0
                self.drawProgressFrom = 0
                self.maxDrawProgressFrom = 0
                self.smoothedDrawProgressFrom = 0  // Reset for non-static mode

                if progress >= 1.0 {
                    timer.invalidate()
                    self.animationTimer = nil
                }
            }
        }
    }
}

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

    // Single smoothing system for trim position only
    @State private var smoothedDrawProgressFrom: CGFloat = 0
    @State private var targetDrawProgressFrom: CGFloat = 0
    @State private var lastUpdateTime: Date?

    // Track the maximum leftward offset to ensure we never move back right
    @State private var maxLeftwardOffset: CGFloat = 0

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
        guard let analyzer = pathAnalyzer else { return 0 }

        // CRITICAL: Direct calculation from smoothed trim position
        // No separate smoothing for text offset - this ensures perfect synchronization
        let windowStartX = analyzer.pointAtParameter(smoothedDrawProgressFrom).x

        // Mathematical guarantee: leftEdgeX = windowStartX + offset = fixedLeftEdgeX
        // Therefore: offset = fixedLeftEdgeX - windowStartX
        var offset = fixedLeftEdgeX - windowStartX

        // ENFORCE FORWARD-ONLY: Text can only move LEFT (more negative) or stay still
        // Track the most leftward position and never allow moving back right
        if offset < maxLeftwardOffset {
            // Moving further left is allowed
            DispatchQueue.main.async {
                self.maxLeftwardOffset = offset
            }
        } else {
            // Trying to move right - prevent it!
            offset = maxLeftwardOffset
        }

        // Debug output to verify the left edge remains fixed and no rightward movement
        #if DEBUG
        let leftEdgePosition = windowStartX + offset
        if abs(leftEdgePosition - fixedLeftEdgeX) > 0.01 {
            print("⚠️ Left edge drift detected! Expected: \(fixedLeftEdgeX), Actual: \(leftEdgePosition)")
        }
        if offset > maxLeftwardOffset + 0.01 {
            print("⚠️ Rightward movement prevented! Tried: \(offset), Kept: \(maxLeftwardOffset)")
        }
        #endif

        return offset
    }

    // Single smoothing function for trim position only
    private func updateSmoothedDrawProgressFrom() {
        guard staticMode else {
            smoothedDrawProgressFrom = 0
            targetDrawProgressFrom = 0
            return
        }

        // Simple exponential smoothing for forward-only movement
        // This prevents oscillation and ensures smooth, predictable motion
        let smoothingFactor: CGFloat = 0.15  // Adjust for smoothness (0.1 = smoother, 0.3 = more responsive)

        // CRITICAL: Only allow forward movement of the trim start (increasing parameter)
        // This means the text can only move LEFT (more negative offset) or stay still
        // Never allow backwards movement (which would move text RIGHT)
        if targetDrawProgressFrom > smoothedDrawProgressFrom {
            // Smooth forward movement (trim start advances, text moves left)
            smoothedDrawProgressFrom += (targetDrawProgressFrom - smoothedDrawProgressFrom) * smoothingFactor

            // Snap when very close to prevent infinite approach
            if abs(targetDrawProgressFrom - smoothedDrawProgressFrom) < 0.0001 {
                smoothedDrawProgressFrom = targetDrawProgressFrom
            }
        }
        // If target is same or behind, do nothing - keep current position
        // This ensures text NEVER moves back to the right

        // Ensure we stay within valid bounds
        smoothedDrawProgressFrom = max(0, min(1, smoothedDrawProgressFrom))
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
                    if let analyzer = pathAnalyzer {
                        let fromPoint = analyzer.pointAtParameter(smoothedDrawProgressFrom)

                        // Fixed left edge indicator (blue line) - should never move
                        Rectangle()
                            .fill(Color.blue.opacity(0.5))
                            .frame(width: 2, height: measuredWordSize.height)
                            .position(
                                x: fixedLeftEdgeX,  // This should always be at x=0
                                y: measuredWordSize.height / 2
                            )
                            .frame(width: measuredWordSize.width, height: measuredWordSize.height, alignment: .leading)

                        // Trim start indicator (green line)
                        Rectangle()
                            .fill(Color.green.opacity(0.7))
                            .frame(width: 2, height: measuredWordSize.height)
                            .position(
                                x: fromPoint.x + textOffset,  // Direct use of computed textOffset
                                y: measuredWordSize.height / 2
                            )
                            .frame(width: measuredWordSize.width, height: measuredWordSize.height, alignment: .leading)

                        // Trim end indicator (red line)
                        Rectangle()
                            .fill(Color.red.opacity(0.7))
                            .frame(width: 2, height: measuredWordSize.height)
                            .position(
                                x: pipeX + textOffset,  // Direct use of computed textOffset
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
        targetDrawProgressFrom = 0
        lastUpdateTime = nil

        // Reset forward-only tracking
        maxLeftwardOffset = 0

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
                    self.targetDrawProgressFrom = newTargetFrom
                    self.drawProgressFrom = newTargetFrom  // Keep for compatibility

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

                    // Ensure forward-only progression to prevent drift
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

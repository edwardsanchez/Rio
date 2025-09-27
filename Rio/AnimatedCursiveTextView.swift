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
    @State private var previousTextOffsets: [CGFloat] = []
    private let smoothingWindowSize = 5
    
    // Configuration parameters
    let text: String
    let fontSize: CGFloat
    let animationDuration: Double
    let staticMode: Bool
    let showProgressIndicator: Bool
    let forwardOnlyMode: Bool
    let windowWidth: CGFloat
    let variableSpeed: Bool
    
    // Computed properties
    private var fontSizeValue: CGFloat { fontSize }
    private var measuredWordSize: CGSize {
        CursiveWordShape.preferredSize(for: text, fontSize: fontSizeValue)
            ?? CGSize(width: fontSizeValue * 8, height: fontSizeValue * 1.4)
    }
        
    init(
        text: String,
        fontSize: CGFloat = 20,
        animationDuration: Double? = nil,
        staticMode: Bool = true,
        showProgressIndicator: Bool = false,
        forwardOnlyMode: Bool = false,
        windowWidth: CGFloat = 50,
        variableSpeed: Bool = true
    ) {
        self.text = text
        self.fontSize = fontSize
        self.animationDuration = animationDuration ?? Double(text.count) / 3
        self.staticMode = staticMode
        self.showProgressIndicator = showProgressIndicator
        self.forwardOnlyMode = forwardOnlyMode
        self.windowWidth = windowWidth
        self.variableSpeed = variableSpeed
    }
    
    var shape: CursiveWordShape {
        CursiveWordShape(text: text, fontSize: fontSize)
    }
    
    var path: Path {
        shape.path(in: CGRect(origin: .zero, size: measuredWordSize))
    }
    
    var analyzer: PathXAnalyzer {
        PathXAnalyzer(path: path.cgPath)
    }
    
    var trimEndPoint: CGPoint {
        analyzer.pointAtParameter(drawProgress)
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

    // Smoothed version of textOffset for animations
    private func updateSmoothedTextOffset() {
        guard staticMode else {
            smoothedTextOffset = 0
            previousTextOffsets.removeAll()
            return
        }

        let currentOffset = textOffset

        // Add current offset to the window
        previousTextOffsets.append(currentOffset)

        // Keep only the last N values for smoothing
        if previousTextOffsets.count > smoothingWindowSize {
            previousTextOffsets.removeFirst()
        }

        // Calculate moving average
        let sum = previousTextOffsets.reduce(0, +)
        smoothedTextOffset = sum / CGFloat(previousTextOffsets.count)
    }

    // Convert linear time progress to path-length-adjusted progress
    private func adjustProgressForPathLength(_ linearProgress: CGFloat) -> CGFloat {
        guard !variableSpeed else { return linearProgress }

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
                .trim(from: staticMode ? drawProgressFrom : 0, to: drawProgress)
                .stroke(
                    Color.secondary,
                    style: StrokeStyle(
                        lineWidth: fontSizeValue / 15,
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
                    let fromPoint = analyzer.pointAtParameter(drawProgressFrom)
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
        previousTextOffsets.removeAll()
        
        // Get path analyzer for window calculations
        let shape = CursiveWordShape(text: text, fontSize: fontSizeValue)
        let path = shape.path(in: CGRect(origin: .zero, size: measuredWordSize))
        let analyzer = PathXAnalyzer(path: path.cgPath)
        
        // Start animation with timer for continuous updates
        let startTime = Date()
        var endPhaseStartTime: Date? = nil
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [self] timer in
            
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / self.animationDuration, 1.0)
            
            if self.staticMode {
                // Check if we've reached the end with the red pipe
                if progress >= 1.0 && self.drawProgressFrom < 1.0 {
                    if endPhaseStartTime == nil {
                        endPhaseStartTime = Date()
                    }

                    self.drawProgress = 1.0

                    let endElapsed = Date().timeIntervalSince(endPhaseStartTime!)
                    let endDuration = 0.5
                    let endProgress = min(endElapsed / endDuration, 1.0)

                    let startFrom = self.maxDrawProgressFrom
                    self.drawProgressFrom = startFrom + (1.0 - startFrom) * endProgress

                    self.updateSmoothedTextOffset()

                    if self.drawProgressFrom >= 1.0 {
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
                    self.drawProgressFrom = self.maxDrawProgressFrom
                } else {
                    self.drawProgressFrom = 0
                    self.maxDrawProgressFrom = 0
                }

                self.updateSmoothedTextOffset()
            } else {
                let adjustedProgress = self.adjustProgressForPathLength(progress)
                self.drawProgress = adjustedProgress
                self.drawProgressFrom = 0
                self.maxDrawProgressFrom = 0

                self.updateSmoothedTextOffset()

                if progress >= 1.0 {
                    timer.invalidate()
                    self.animationTimer = nil
                }
            }
        }
    }
}

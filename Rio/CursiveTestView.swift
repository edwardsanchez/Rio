//
//  CursiveTestView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/24/25.
//

import SwiftUI
import SVGPath
import os.log

// X-parametrized path analyzer
struct PathXAnalyzer {
    struct Sample {
        let u: CGFloat      // Path parameter [0,1]
        let point: CGPoint  // Point on path
        let cumulativeX: CGFloat  // Cumulative horizontal distance
        let cumulativeLength: CGFloat  // Cumulative path length
    }

    let samples: [Sample]
    let totalXDistance: CGFloat
    let totalPathLength: CGFloat
    let bounds: CGRect

    init(path: CGPath, sampleCount: Int = 800) {  // Increased sample count for better accuracy
        var samples: [Sample] = []
        var cumulativeX: CGFloat = 0
        var cumulativeLength: CGFloat = 0
        var previousPoint: CGPoint?

        // Sample the path at regular u intervals
        for i in 0...sampleCount {
            let u = CGFloat(i) / CGFloat(sampleCount)

            // Get point at parameter u
            let point = path.pointAtParameter(u) ?? .zero

            if let prev = previousPoint {
                // Calculate horizontal and path distances
                let dx = abs(point.x - prev.x)
                let pathDist = hypot(point.x - prev.x, point.y - prev.y)

                cumulativeX += dx
                cumulativeLength += pathDist
            }

            samples.append(Sample(
                u: u,
                point: point,
                cumulativeX: cumulativeX,
                cumulativeLength: cumulativeLength
            ))

            previousPoint = point
        }

        self.samples = samples
        self.totalXDistance = cumulativeX
        self.totalPathLength = cumulativeLength
        self.bounds = path.boundingBox
    }

    // Get path length between two x positions
    func pathLengthBetweenX(from startX: CGFloat, to endX: CGFloat) -> CGFloat {
        // Find samples at or near the x positions
        let startSample = sampleAtX(startX)
        let endSample = sampleAtX(endX)

        return abs(endSample.cumulativeLength - startSample.cumulativeLength)
    }

    // Find the sample closest to a given x position
    private func sampleAtX(_ targetX: CGFloat) -> Sample {
        // Binary search for the closest x position
        var bestSample = samples[0]
        var minDist = CGFloat.infinity

        for sample in samples {
            let dist = abs(sample.point.x - targetX)
            if dist < minDist {
                minDist = dist
                bestSample = sample
            }
        }

        return bestSample
    }

    // Get parameter u for a given x-distance traveled
    func parameterAtXDistance(_ xDist: CGFloat) -> CGFloat {
        guard xDist >= 0 else { return 0 }
        guard xDist < totalXDistance else { return 1 }

        // Binary search through samples
        var low = 0
        var high = samples.count - 1

        while low < high {
            let mid = (low + high) / 2
            if samples[mid].cumulativeX < xDist {
                low = mid + 1
            } else {
                high = mid
            }
        }

        // Interpolate between samples
        if low > 0 {
            let s1 = samples[low - 1]
            let s2 = samples[low]
            let t = (xDist - s1.cumulativeX) / max(0.001, s2.cumulativeX - s1.cumulativeX)
            return s1.u + t * (s2.u - s1.u)
        }

        return samples[low].u
    }

    // Get the actual point at a given path parameter
    func pointAtParameter(_ u: CGFloat) -> CGPoint {
        guard u >= 0 else { return samples.first?.point ?? .zero }
        guard u <= 1 else { return samples.last?.point ?? CGPoint(x: bounds.maxX, y: bounds.midY) }

        // Find the samples that bracket this parameter
        var low = 0
        var high = samples.count - 1

        while low < high {
            let mid = (low + high) / 2
            if samples[mid].u < u {
                low = mid + 1
            } else {
                high = mid
            }
        }

        // Interpolate between samples to get the point
        if low > 0 {
            let s1 = samples[low - 1]
            let s2 = samples[low]
            if s2.u > s1.u {
                let t = (u - s1.u) / (s2.u - s1.u)
                // Interpolate the point position
                return CGPoint(
                    x: s1.point.x + (s2.point.x - s1.point.x) * t,
                    y: s1.point.y + (s2.point.y - s1.point.y) * t
                )
            }
        }

        return samples[low].point
    }
}

// Extension to get the end point of a trimmed path
extension Path {
    func trimmedEndPoint(from startT: CGFloat, to endT: CGFloat) -> CGPoint? {
        // Get the CGPath and find the point at the trim end
        let cgPath = self.cgPath
        return cgPath.pointAtParameter(endT)
    }
}

// Extension to approximate point at parameter
extension CGPath {
    func pointAtParameter(_ t: CGFloat) -> CGPoint? {
        // Build a list of path segments with their lengths
        var segments: [(start: CGPoint, end: CGPoint, length: CGFloat)] = []
        var totalLength: CGFloat = 0
        var currentPoint = CGPoint.zero
        var firstPoint = CGPoint.zero

        self.applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint:
                currentPoint = element.pointee.points[0]
                firstPoint = currentPoint

            case .addLineToPoint:
                let endPoint = element.pointee.points[0]
                let length = hypot(endPoint.x - currentPoint.x, endPoint.y - currentPoint.y)
                segments.append((start: currentPoint, end: endPoint, length: length))
                totalLength += length
                currentPoint = endPoint

            case .addQuadCurveToPoint:
                // Approximate quad curve with line segment
                let endPoint = element.pointee.points[1]
                let length = hypot(endPoint.x - currentPoint.x, endPoint.y - currentPoint.y) * 1.2
                segments.append((start: currentPoint, end: endPoint, length: length))
                totalLength += length
                currentPoint = endPoint

            case .addCurveToPoint:
                // Approximate cubic curve with line segment
                let endPoint = element.pointee.points[2]
                let length = hypot(endPoint.x - currentPoint.x, endPoint.y - currentPoint.y) * 1.3
                segments.append((start: currentPoint, end: endPoint, length: length))
                totalLength += length
                currentPoint = endPoint

            case .closeSubpath:
                if currentPoint != firstPoint {
                    let length = hypot(firstPoint.x - currentPoint.x, firstPoint.y - currentPoint.y)
                    segments.append((start: currentPoint, end: firstPoint, length: length))
                    totalLength += length
                    currentPoint = firstPoint
                }

            @unknown default:
                break
            }
        }

        guard totalLength > 0 && !segments.isEmpty else { return nil }

        // Find the point at parameter t
        let targetLength = t * totalLength
        var accumulatedLength: CGFloat = 0

        for segment in segments {
            if accumulatedLength + segment.length >= targetLength {
                // This segment contains our target point
                let segmentT = (targetLength - accumulatedLength) / segment.length
                return CGPoint(
                    x: segment.start.x + (segment.end.x - segment.start.x) * segmentT,
                    y: segment.start.y + (segment.end.y - segment.start.y) * segmentT
                )
            }
            accumulatedLength += segment.length
        }

        // Return last point if we've gone past the end
        return segments.last?.end ?? currentPoint
    }
}

struct CursiveTestView: View {
    @State private var drawProgress: CGFloat = 0
    @State private var scannerOffset: CGFloat = 50  // Actual offset in points
    @State private var isDragging = false
    @State private var dragStartOffset: CGFloat = 0  // Track initial offset when drag starts
    @State private var animationTimer: Timer?
    @State private var forwardOnlyMode = false  // Toggle for forward-only pipe movement
    @State private var maxPipeX: CGFloat = 0  // Track the maximum X position reached

    var animationDuration: Double {
        Double(string.count) / 8
    }

    private let logger = Logger(subsystem: "app.amorfati.Rio", category: "CursiveLetters")

    let string: String = "hello how are you"
    let size: Double = 20

    private let wordPadding: CGFloat = 12
    private var fontSizeValue: CGFloat { CGFloat(size) }
    private var measuredWordSize: CGSize {
        CursiveWordShape.preferredSize(for: string, fontSize: fontSizeValue)
            ?? CGSize(width: fontSizeValue * 8, height: fontSizeValue * 1.4)
    }

    private let scannerWidth: CGFloat = 50  // Width of the scanning rectangle - narrower for more range

    var body: some View {
        let fontSize = fontSizeValue
        let wordSize = measuredWordSize

        // Create path analyzer
        let shape = CursiveWordShape(text: string, fontSize: fontSize)
        let path = shape.path(in: CGRect(origin: .zero, size: wordSize))
        let analyzer = PathXAnalyzer(path: path.cgPath)

        // Clamp scanner position to valid range
        let maxOffset = max(0, wordSize.width - scannerWidth)
        let clampedOffset = min(max(0, scannerOffset), maxOffset)

        // Calculate path length between scanner bounds
        let pathLength = analyzer.pathLengthBetweenX(
            from: clampedOffset,
            to: clampedOffset + scannerWidth
        )

        // Get the actual end point of the trimmed path
        let trimEndPoint = analyzer.pointAtParameter(drawProgress)

        // Calculate pipe X position based on mode
        let pipeX: CGFloat = {
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
            } else {
                // Normal mode: follow the actual trim end point
                return trimEndPoint.x
            }
        }()

        return VStack(spacing: 20) {
            Text("X-Parametrized Path Scanner")
                .font(.title2)
                .padding(.top)

            Text("Drag the scanner to measure path length")
                .font(.caption)
                .foregroundColor(.secondary)

            // Main visualization area
            VStack(spacing: 0) {
                // Scanner and measurement display
                ZStack(alignment: .topLeading) {
                    // Invisible spacer for layout
                    Color.clear
                        .frame(height: 60)

                    // Scanner rectangle with measurement
                    VStack(spacing: 4) {
                        // Path length display
                        Text(String(format: "%.1f px", pathLength))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.8))
                            .cornerRadius(4)

                        // Scanner rectangle
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.blue.opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                            .frame(width: scannerWidth, height: 30)
                    }
                    .offset(x: clampedOffset)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDragging {
                                    isDragging = true
                                    dragStartOffset = scannerOffset
                                }
                                let newOffset = dragStartOffset + value.translation.width
                                let maxOffset = max(0, wordSize.width - scannerWidth)
                                scannerOffset = min(max(0, newOffset), maxOffset)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
                }
                .frame(width: wordSize.width)

                // The cursive word
                ZStack {
                    Rectangle().fill(Color.gray.opacity(0.08))

                    // The cursive word shape
                    CursiveWordShape(text: string, fontSize: fontSize)
                        .trim(from: 0, to: drawProgress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: fontSizeValue / 15, lineCap: .round, lineJoin: .round))
                        .frame(width: wordSize.width, height: wordSize.height)

                    // Vertical indicators at scanner bounds
                    if isDragging {
                        // Left edge indicator
                        Rectangle()
                            .fill(Color.green.opacity(0.5))
                            .frame(width: 1, height: wordSize.height)
                            .position(x: clampedOffset, y: wordSize.height / 2)
                            .frame(width: wordSize.width, height: wordSize.height, alignment: .leading)

                        // Right edge indicator
                        Rectangle()
                            .fill(Color.green.opacity(0.5))
                            .frame(width: 1, height: wordSize.height)
                            .position(x: clampedOffset + scannerWidth, y: wordSize.height / 2)
                            .frame(width: wordSize.width, height: wordSize.height, alignment: .leading)
                    }

                    // Red pipe that follows based on mode
                    Rectangle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 2, height: wordSize.height)
                        .position(
                            x: pipeX,
                            y: wordSize.height / 2
                        )
                        .frame(width: wordSize.width, height: wordSize.height, alignment: .leading)
                }
                .frame(width: wordSize.width + wordPadding * 2, height: wordSize.height + wordPadding * 2)
                .border(Color.gray.opacity(0.3))
            }


            // Info display
            HStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Width:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f px", wordSize.width))
                        .font(.system(.body, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Path Length:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f px", analyzer.totalPathLength))
                        .font(.system(.body, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Scanner Width:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f px", scannerWidth))
                        .font(.system(.body, design: .monospaced))
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            HStack(spacing: 20) {
                Button("Restart Animation") {
                    restartAnimation()
                }

                Toggle("Forward-Only Mode", isOn: $forwardOnlyMode)
                    .onChange(of: forwardOnlyMode) { _ in
                        // Reset max when toggling mode
                        maxPipeX = 0
                        restartAnimation()
                    }
            }
            .padding(.top, 8)

            Spacer()
        }
        .onAppear {
            restartAnimation()
        }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
    }

    private func restartAnimation() {
        // Cancel any existing timer
        animationTimer?.invalidate()

        // Reset progress and max pipe position
        drawProgress = 0
        maxPipeX = 0

        // Start animation with timer for continuous updates
        let startTime = Date()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { timer in
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / animationDuration, 1.0)

            drawProgress = progress

            if progress >= 1.0 {
                timer.invalidate()
                animationTimer = nil
            }
        }
    }
}

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
    @State private var maxMaskX: CGFloat = 0
    @State private var animationTimer: Timer?
    
    // Configuration parameters
    let text: String
    let fontSize: CGFloat
    let animationDuration: Double
    let windowMode: Bool
    let staticWindow: Bool
    let showProgressIndicator: Bool
    let forwardOnlyMode: Bool
    let windowWidth: CGFloat
    
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
        windowMode: Bool = true,
        staticWindow: Bool = true,
        showProgressIndicator: Bool = false,
        forwardOnlyMode: Bool = false,
        windowWidth: CGFloat = 50
    ) {
        self.text = text
        self.fontSize = fontSize
        self.animationDuration = animationDuration ?? Double(text.count) / 3
        self.windowMode = windowMode
        self.staticWindow = staticWindow
        self.showProgressIndicator = showProgressIndicator
        self.forwardOnlyMode = forwardOnlyMode
        self.windowWidth = windowWidth
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
        if forwardOnlyMode && !windowMode {
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
        if windowMode && staticWindow && maxDrawProgressFrom > 0 {
            // For static window, we want the window to appear at the start of the text
            let textStartX = analyzer.bounds.minX  // Start of the text
            let desiredWindowX = textStartX + windowWidth  // Back to original position
            return desiredWindowX - maxMaskX
        }
        return 0
    }
    
    var body: some View {
        ZStack {
            Group {
                if windowMode {
                    // Window mode: apply gradient mask to the green stroke
                    // Green stroke layer with gradient mask
                    CursiveWordShape(text: text, fontSize: fontSize)
                        .trim(from: drawProgressFrom, to: drawProgress)
                        .stroke(Color.secondary, style: StrokeStyle(lineWidth: fontSizeValue / 15, lineCap: .round, lineJoin: .round))
                        .frame(width: measuredWordSize.width, height: measuredWordSize.height)
                        .offset(x: textOffset)  // Apply static window offset
                        .mask(
                            // Create a wider mask with more left padding for static window mode
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    // Left edge: fade from transparent to opaque
                                    .init(color: .clear, location: 0),
                                    .init(color: .black, location: staticWindow ? 20/60 : 10/40),  // Even more left padding in static mode
                                    // Right portion: fully opaque
                                        .init(color: .black, location: 1)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(width: staticWindow ? 60 : 40, height: measuredWordSize.height * 1.5)  // Even wider mask in static mode
                            // Position the mask: static in static window mode, moving otherwise
                                .position(
                                    x: staticWindow ? (analyzer.bounds.minX + windowWidth - 30) : maxMaskX - 20,  // Center of wider mask
                                    y: measuredWordSize.height / 2
                                )
                                .frame(width: measuredWordSize.width, height: measuredWordSize.height, alignment: .leading)
                        )
                } else {
                    // Normal mode: single blue stroke
                    CursiveWordShape(text: text, fontSize: fontSize)
                        .trim(from: 0, to: drawProgress)
                        .stroke(Color.secondary, style: StrokeStyle(lineWidth: fontSizeValue / 15, lineCap: .round, lineJoin: .round))
                        .frame(width: measuredWordSize.width, height: measuredWordSize.height)
                        .offset(x: textOffset)  // Apply static window offset (will be 0 in normal mode)
                }
            }
            // The cursive word shape with window mode support
            
            progressIndicatorView
        }
        .frame(width: measuredWordSize.width, height: measuredWordSize.height)
        .onAppear {
            restartAnimation()
        }
        .onDisappear {
            animationTimer?.invalidate()
            animationTimer = nil
        }
        .animation(drawProgress == 0 ? nil : .linear, value: drawProgress)
    }
    
    var progressIndicatorView: some View {
        return Group {
            // Red pipes that follow based on mode (only show if enabled)
            if showProgressIndicator {
                if windowMode {
                    // Window mode: show two pipes (left and right edges)
                    // Left pipe (trim from position)
                    let fromPoint = analyzer.pointAtParameter(drawProgressFrom)
                    Rectangle()
                        .fill(Color.green.opacity(0.7))
                        .frame(width: 2, height: measuredWordSize.height)
                        .position(
                            x: fromPoint.x + textOffset,
                            y: measuredWordSize.height / 2
                        )
                        .frame(width: measuredWordSize.width, height: measuredWordSize.height, alignment: .leading)
                    
                    // Right pipe (trim to position)
                    Rectangle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 2, height: measuredWordSize.height)
                        .position(
                            x: pipeX + textOffset,
                            y: measuredWordSize.height / 2
                        )
                        .frame(width: measuredWordSize.width, height: measuredWordSize.height, alignment: .leading)
                } else {
                    // Normal mode: single pipe
                    Rectangle()
                        .fill(Color.red.opacity(0.7))
                        .frame(width: 2, height: measuredWordSize.height)
                        .position(
                            x: pipeX + textOffset,
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
        maxMaskX = 0
        
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
            
            if self.windowMode {
                // Check if we've reached the end with the red pipe
                if progress >= 1.0 && self.drawProgressFrom < 1.0 {
                    // Red pipe has reached the end, now animate green pipe to catch up
                    if endPhaseStartTime == nil {
                        endPhaseStartTime = Date()
                        print("End phase started - animating green pipe to end")
                    }
                    
                    // Keep red pipe at 1.0
                    self.drawProgress = 1.0
                    
                    // During end phase, mask should stay at the final position
                    let finalPoint = analyzer.pointAtParameter(1.0)
                    if finalPoint.x > self.maxMaskX {
                        self.maxMaskX = finalPoint.x
                    }
                    
                    // Animate green pipe from its current position to 1.0
                    let endElapsed = Date().timeIntervalSince(endPhaseStartTime!)
                    let endDuration = 0.5 // Half second for green pipe to catch up
                    let endProgress = min(endElapsed / endDuration, 1.0)
                    
                    // Interpolate from current maxDrawProgressFrom to 1.0
                    let startFrom = self.maxDrawProgressFrom
                    self.drawProgressFrom = startFrom + (1.0 - startFrom) * endProgress
                    
                    if self.drawProgressFrom >= 1.0 {
                        self.drawProgressFrom = 1.0
                        timer.invalidate()
                        self.animationTimer = nil
                        print("Animation complete")
                    }
                    
                    return // Skip normal processing
                }
                
                // Normal animation (before end phase)
                self.drawProgress = progress
                
                // Calculate the 'from' parameter to maintain window width
                let toPoint = analyzer.pointAtParameter(progress)
                let toX = toPoint.x
                
                // Update mask position (forward-only movement)
                if toX > self.maxMaskX {
                    self.maxMaskX = toX
                }
                
                // Find the parameter that's windowWidth pixels behind
                let targetFromX = toX - self.windowWidth
                
                // Linear search through samples to find best match
                var bestFrom: CGFloat = 0
                var bestDist = CGFloat.infinity
                
                for sample in analyzer.samples {
                    // Only consider samples before current progress and at/before target X
                    if sample.u <= progress && sample.point.x <= targetFromX {
                        let dist = abs(sample.point.x - targetFromX)
                        if dist < bestDist {
                            bestDist = dist
                            bestFrom = sample.u
                        }
                    }
                }
                
                // Apply monotonic constraint
                if bestFrom > self.maxDrawProgressFrom {
                    self.maxDrawProgressFrom = bestFrom
                }
                
                // Set the from parameter
                self.drawProgressFrom = self.maxDrawProgressFrom
                
                // Debug logging - less frequent
                if Int(progress * 100) % 10 == 0 {  // Log every 10%
                    print("Window: progress=\(String(format: "%.2f", progress)), from=\(String(format: "%.2f", self.drawProgressFrom)), toX=\(String(format: "%.1f", toX))")
                }
                
            } else {
                // Normal mode: no 'from' trimming
                self.drawProgress = progress
                self.drawProgressFrom = 0
                self.maxDrawProgressFrom = 0
                
                if progress >= 1.0 {
                    timer.invalidate()
                    self.animationTimer = nil
                }
            }
        }
    }
}

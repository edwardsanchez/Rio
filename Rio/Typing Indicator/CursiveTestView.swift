//
//  CursiveTestView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/24/25.
//

import SwiftUI
import SVGPath
import os.log

struct CursiveTestView: View {
    // Scanner/drag interaction state
    @State private var scannerOffset: CGFloat = 50  // Actual offset in points
    @State private var isDragging = false
    @State private var dragStartOffset: CGFloat = 0  // Track initial offset when drag starts

    // UI toggle state
    @State private var forwardOnlyMode = false  // Toggle for forward-only pipe movement
    @State private var showPipe = false  // Toggle to show/hide the progress indicator
    @State private var staticMode = true  // Toggle for static window effect (window stays in place, text scrolls)
    @State private var variableSpeed = false  // Toggle for variable speed animation
    @State private var trackingAccuracy: CGFloat = 0.85  // 0 = smooth drift, 1 = tight tracking

    // Animation restart trigger
    @State private var animationKey = 0

    // Configuration constants
    private let windowWidth: CGFloat = 50  // Width of the visible window in pixels
    private let string: String = "hello how are you doing today? I think I'm gonna go to the theatre later this weekend, what do you think?"
    private let size: Double = 20
    private let wordPadding: CGFloat = 12
    private let scannerWidth: CGFloat = 50  // Width of the scanning rectangle - narrower for more range

    // Computed properties
    private var fontSizeValue: CGFloat { CGFloat(size) }
    private var measuredWordSize: CGSize {
        CursiveWordShape.preferredSize(for: string, fontSize: fontSizeValue)
            ?? CGSize(width: fontSizeValue * 8, height: fontSizeValue * 1.4)
    }

    private let logger = Logger(subsystem: "app.amorfati.Rio", category: "CursiveLetters")

    var body: some View {
        let fontSize = fontSizeValue
        let wordSize = measuredWordSize

        // Create path analyzer for scanner functionality
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

        return VStack(spacing: 20) {
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

                // The animated cursive text view
                ZStack(alignment: .leading) {
                    typingIndicatorView

                    // Vertical indicators at scanner bounds (overlay on top of animated text)
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
                }
                .frame(width: wordSize.width + wordPadding * 4, height: wordSize.height + wordPadding * 2, alignment: .leading)
                .frame(width: 200, alignment: .leading)
                .clipped()
                .border(Color.red.opacity(0.3))
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

            VStack(spacing: 16) {
                // Animation Control
                Button("Restart Animation") {
                    animationKey += 1  // Force recreation of AnimatedCursiveTextView
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Divider()

                // Display Options
                VStack(alignment: .leading, spacing: 12) {
                    Text("Display Options")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Toggle("Show Progress Indicator", isOn: $showPipe)

                    if showPipe && !staticMode {
                        Toggle("Forward-Only Mode", isOn: $forwardOnlyMode)
                            .padding(.leading, 20)
                            .onChange(of: forwardOnlyMode) {
                                animationKey += 1  // Restart animation when mode changes
                            }
                    }
                }

                Divider()

                // Animation Mode
                VStack(alignment: .leading, spacing: 12) {
                    Text("Animation Mode")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    Toggle("Static Window Mode", isOn: $staticMode)
                        .onChange(of: staticMode) {
                            animationKey += 1  // Restart animation when mode changes
                        }

                    if staticMode {
                        HStack {
                            Text("Window Width:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(windowWidth))px")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                        .padding(.leading, 20)

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Tracking Accuracy")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(String(format: "%.2f", trackingAccuracy))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.primary)
                            }

                            Slider(value: $trackingAccuracy, in: 0...1, step: 0.05) {
                                Text("Tracking Accuracy")
                            }
                            .onChange(of: trackingAccuracy) {
                                animationKey += 1  // Restart to apply smoothing changes
                            }

                            Text("0 prioritizes smooth left drift, 1 stays tight to the pen.")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 20)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Animation Speed")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Toggle("Variable Speed", isOn: $variableSpeed)
                            .onChange(of: variableSpeed) {
                                animationKey += 1  // Restart animation when mode changes
                            }

                        Text("When enabled, animation speed varies with path complexity. When disabled, visual progress appears linear.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)

            Spacer()
        }
    }
    
    var typingIndicatorView: some View {
        Group {
            if staticMode {
                // Static mode: use the default initializer (which is always static mode)
                AnimatedCursiveTextView(
                    text: string,
                    fontSize: fontSizeValue,
                    animationSpeed: nil,
                    windowWidth: windowWidth,
                    forwardOnlyMode: forwardOnlyMode,
                    variableSpeed: variableSpeed,
                    trackingAccuracy: trackingAccuracy,
                    cleanup: false,  // Disable cleanup for test view
                    showProgressIndicator: showPipe
                )
                .id(animationKey)  // Force recreation when key changes
                .fixedSize()  // Preserve intrinsic width so cropping happens at the trailing edge
            } else {
                // Progressive mode: use the progressiveText initializer
                AnimatedCursiveTextView(
                    progressiveText: string,
                    fontSize: fontSizeValue,
                    animationDuration: nil,
                    showProgressIndicator: showPipe
                )
                .id(animationKey)  // Force recreation when key changes
                .fixedSize()  // Preserve intrinsic width so cropping happens at the trailing edge
            }
        }
    }
}

//
//  CursiveTestView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/24/25.
//

import os.log
import SVGPath
import SwiftUI

struct CursiveTestView: View {
    // Text input state
    @State private var inputText: String = ""
    @State private var displayText: String = ""
    @FocusState private var isInputFocused: Bool

    // Scanner/drag interaction state
    @State private var scannerOffset: CGFloat = 50 // Actual offset in points
    @State private var isDragging = false
    @State private var dragStartOffset: CGFloat = 0 // Track initial offset when drag starts

    // UI toggle state
    @State private var forwardOnlyMode = false // Toggle for forward-only pipe movement
    @State private var showPipe = false // Toggle to show/hide the progress indicator
    @State private var staticMode = false // Toggle for static window effect (window stays in place, text scrolls)
    @State private var variableSpeed = true // Toggle for variable speed animation
    @State private var trackingAccuracy: CGFloat = 0.85 // 0 = smooth drift, 1 = tight tracking

    // Animation restart trigger
    @State private var animationKey = 0

    // Configuration constants
    private let windowWidth: CGFloat = 50 // Width of the visible window in pixels
    private let size: Double = 40
    private let wordPadding: CGFloat = 12
    private let scannerWidth: CGFloat = 50 // Width of the scanning rectangle - narrower for more range

    // Computed properties
    private var fontSizeValue: CGFloat { CGFloat(size) }

    private var measuredWordSize: CGSize {
        CursiveWordShape.preferredSize(for: displayText, fontSize: fontSizeValue)
            ?? CGSize(width: fontSizeValue * 8, height: fontSizeValue * 1.4)
    }

    private let logger = Logger(subsystem: "app.amorfati.Rio", category: "CursiveLetters")

    var body: some View {
        let fontSize = fontSizeValue
        let wordSize = measuredWordSize

        // Create path analyzer for scanner functionality
        let shape = CursiveWordShape(text: displayText, fontSize: fontSize)
        let path = shape.path(in: CGRect(origin: .zero, size: wordSize))
        let analyzer = PathXAnalyzer(path: path.cgPath)

        // Clamp scanner position to valid range
        let maxOffset = max(0, wordSize.width - scannerWidth)
        let clampedOffset = min(max(0, scannerOffset), maxOffset)

        // Calculate path length between scanner bounds
        _ = analyzer.pathLengthBetweenX(
            from: clampedOffset,
            to: clampedOffset + scannerWidth
        )

        return VStack(spacing: 20) {
            // Text input field
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    TextField("Text", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .focused($isInputFocused)
                        .onSubmit {
                            submitText()
                        }

//                    Button("Animate") {
//                        submitText()
//                    }
//                    .buttonStyle(.borderedProminent)
//                    .disabled(inputText.isEmpty)
//                    .hidden()
                }
            }
            .padding()
//            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
            typingIndicatorView
        }
        .onAppear {
            isInputFocused = true
        }
    }

    var typingIndicatorView: some View {
        Group {
            if staticMode {
                // Static mode: use the default initializer (which is always static mode)
                AnimatedCursiveTextView(
                    text: displayText,
                    fontSize: fontSizeValue,
                    animationSpeed: nil,
                    windowWidth: windowWidth,
                    forwardOnlyMode: forwardOnlyMode,
                    variableSpeed: variableSpeed,
                    trackingAccuracy: trackingAccuracy,
                    cleanup: false, // Disable cleanup for test view
                    showProgressIndicator: showPipe
                )
                .id(animationKey) // Force recreation when key changes
                .fixedSize() // Preserve intrinsic width so cropping happens at the trailing edge
            } else {
                // Progressive mode: use the progressiveText initializer
                AnimatedCursiveTextView(
                    progressiveText: displayText,
                    fontSize: fontSizeValue,
                    animationDuration: nil,
                    showProgressIndicator: showPipe
                )
                .id(animationKey) // Force recreation when key changes
                .fixedSize() // Preserve intrinsic width so cropping happens at the trailing edge
            }
        }
    }

    // MARK: - Helper Methods

    /// Submits the input text and triggers animation
    private func submitText() {
        guard !inputText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        // Convert to lowercase for cursive rendering
        displayText = inputText

        // Clear input field
        inputText = ""

        // Reset scanner position
        scannerOffset = 50

        // Trigger animation restart
        animationKey += 1

        // Keep focus on the text field
        isInputFocused = true
    }
}

#Preview {
    CursiveTestView()
}

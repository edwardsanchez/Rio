//
//  AnimatedCursiveTextView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/26/25.
//

import OSLog
import SVGPath
import SwiftUI

/**
 * AnimatedCursiveTextView renders animated cursive handwriting with sophisticated trim window management.
 *
 * This view provides two primary animation modes:
 * 1. **Static Window Mode**: Maintains a fixed left edge while text appears to be written from right to left
 *    within a sliding window. The left edge never moves, creating the illusion of continuous writing.
 * 2. **Progressive Mode**: Traditional animation where text appears progressively from left to right.
 *
 * Key Features:
 * - **Forward-only trim movement**: Prevents visual jitter by ensuring trim positions never move backward
 * - **Dual tracking system**: Separate tracking for visual trim position and offset calculations
 * - **Ratchet mechanism**: Text offset only moves leftward to maintain fixed left edge alignment
 * - **Path-length compensation**: Adjusts animation speed to maintain consistent visual movement
 * - **Variable speed option**: Allows trim speed to vary inversely with path complexity
 *
 * The system uses PathXAnalyzer for precise path measurements and coordinate transformations,
 * enabling smooth animations that respect the natural flow of cursive handwriting.
 */
struct AnimatedCursiveTextView: View {
    // MARK: - Core Animation State

    /// Current end position of the visible text (0.0 to 1.0 along the path)
    @State private var drawProgress: CGFloat = 0
    /// Current start position of the visible text window (legacy compatibility)
    @State private var drawProgressFrom: CGFloat = 0
    /// Maximum X position reached by the drawing cursor (for forward-only mode)
    @State private var maxPipeX: CGFloat = 0
    /// Maximum start position reached during animation (prevents backward movement)
    @State private var maxDrawProgressFrom: CGFloat = 0
    /// Timer driving the animation updates at 60fps
    @State private var animationTimer: Timer?

    // MARK: - Dual Tracking System

    // This sophisticated system prevents visual jitter by maintaining separate tracking
    // for visual trim position (what the user sees) and offset calculation position

    /// Forward-only position used for visual trim rendering (never moves backward)
    @State private var smoothedDrawProgressFrom: CGFloat = 0
    /// Target position for smooth interpolation to the trim start
    @State private var targetDrawProgressFrom: CGFloat = 0
    /// Forward-only position used for offset calculations (prevents left edge drift)
    @State private var naturalDrawProgressFrom: CGFloat = 0
    /// Maximum natural position reached (ensures naturalDrawProgressFrom only advances)
    @State private var maxNaturalDrawProgressFrom: CGFloat = 0

    // MARK: - Ratchet Mechanism

    // Ensures the left edge never moves rightward, maintaining perfect alignment

    /// Most negative (leftward) offset reached - acts as a ratchet preventing rightward drift
    @State private var minTextOffset: CGFloat = 0

    /// Frozen offset value used during cleanup phase to keep text stationary
    @State private var frozenCleanupOffset: CGFloat = 0

    /// Flag indicating whether we're currently in the cleanup phase
    @State private var isInCleanupPhase: Bool = false

    // MARK: - Fixed Reference Point

    /// Fixed left edge position for static window mode (always at x=0)
    private let fixedLeftEdgeX: CGFloat = 0

    // MARK: - Path Analysis

    /// Analyzer for path measurements, coordinate transformations, and window calculations
    @State private var pathAnalyzer: PathXAnalyzer?

    @State private var containerWidth: CGFloat?
    @State private var lastLoggedShouldActivate: Bool?
    @State private var lastLoggedWindowActive: Bool?
    @State private var lastLoggedEffectiveContainerWidth: CGFloat?

    // MARK: - Configuration Parameters

    let texts: [String] /// Array of texts to animate sequentially (or single text)
    let fontSize: CGFloat /// Font size in points
    let animationSpeed: Double /// Total animation duration in seconds
    let staticMode: Bool /// Enable static window mode with fixed left edge
    let showProgressIndicator: Bool /// Enable debug indicators and logging for trim positions
    let forwardOnlyMode: Bool /// Prevent backward movement of drawing cursor
    let windowWidth: CGFloat? /// Optional override for sliding window width
    let autoWindowMargin: CGFloat /// Right-edge margin used when computing dynamic window width
    let containerWidthOverride: CGFloat? /// Optional externally-supplied container width used when computing the
    /// sliding window
    let variableSpeed: Bool /// Allow animation speed to vary with path complexity
    let trackingAccuracy: CGFloat /// Accuracy factor for path tracking (0.0 to 1.0)
    let cleanup: Bool /// Enable cleanup phase that trims away text after animation completes

    // MARK: - Sequential Animation State

    @State private var currentTextIndex: Int = 0 /// Index of the currently animating text in the array

    // MARK: - Computed Properties

    /// Font size accessor for consistency across the view
    private var fontSizeValue: CGFloat { fontSize }

    /// Current text being animated (based on currentTextIndex)
    private var currentText: String {
        guard currentTextIndex < texts.count else { return texts.last ?? "" }
        return texts[currentTextIndex]
    }

    /// Calculated size needed to render the complete text at the specified font size
    /// Falls back to estimated dimensions if CursiveWordShape calculation fails
    private var measuredWordSize: CGSize {
        CursiveWordShape.preferredSize(for: currentText, fontSize: fontSizeValue)
            ?? CGSize(width: fontSizeValue * 8, height: fontSizeValue * 1.4)
    }

    /// Resolves the sliding window width, falling back to geometry-derived measurements when no explicit override is
    /// supplied.
    private var resolvedWindowWidth: CGFloat? {
        if let specified = windowWidth {
            return specified > 0 ? specified : nil
        }

        guard let width = effectiveContainerWidth else { return nil }
        return resolvedWindowWidth(from: width)
    }

    private var loggingEnabled: Bool { showProgressIndicator }

    private var effectiveContainerWidth: CGFloat? {
        containerWidthOverride ?? containerWidth
    }

    private func resolvedWindowWidth(from width: CGFloat) -> CGFloat? {
        let candidateWidth = width - autoWindowMargin
        return candidateWidth > 0 ? candidateWidth : nil
    }

    /// Indicates whether the sliding window should be active based on the current geometry readings.
    private var staticActivationThresholdReached: Bool {
        guard staticMode, let windowWidth = resolvedWindowWidth else { return false }
        return trimEndVisualX >= windowWidth
    }

    /// Indicates whether the sliding window logic is currently trimming the leading edge.
    private var staticWindowCurrentlyActive: Bool {
        staticMode && resolvedWindowWidth != nil && smoothedDrawProgressFrom > 0.0001
    }

    /// Formats optional width values for the debug HUD.
    private func formatWidth(_ value: CGFloat?) -> String {
        guard let value else { return "nil" }
        return String(format: "%.1f", value)
    }

    /// Formats progress values (0...1 range) for the debug HUD.
    private func formatProgress(_ value: CGFloat) -> String {
        String(format: "%.3f", value)
    }

    /// Updates the cached container width while preventing unnecessary state churn.
    private func updateContainerWidth(_ width: CGFloat) {
        let clampedWidth = max(0, width)
        DispatchQueue.main.async {
            let previousValue = containerWidth
            let widthChanged: Bool = if let previousValue {
                abs(previousValue - clampedWidth) >= 0.5
            } else {
                true
            }

            if widthChanged {
                containerWidth = clampedWidth
                emitGeometryLogIfNeeded(reason: "container width update", force: true)
            }
        }
    }

    // MARK: - Initializers

    /**
     * Creates an animated cursive text view with static window mode (typing indicator style).
     *
     * This is the primary initializer for typing indicators where text appears to be written
     * continuously with a fixed left edge and sliding window. Supports sequential text animation
     * for multiple messages.
     *
     * - Parameters:
     *   - texts: Array of texts to animate sequentially
     *   - fontSize: Font size in points (default: 25)
     *   - animationSpeed: Characters per second, auto-calculated if nil (default: 7 chars/sec)
     *   - containerWidthOverride: Container width for calculating window size (default: nil, auto-detect)
     *   - windowWidth: Override for sliding window width (default: nil, calculated from container)
     *   - autoWindowMargin: Right margin when calculating window width (default: 10)
     *   - forwardOnlyMode: Prevent backward cursor movement (default: true)
     *   - variableSpeed: Vary speed based on path complexity (default: false)
     *   - trackingAccuracy: Path tracking precision 0.0-1.0 (default: 0.85)
     *   - cleanup: Enable cleanup phase after animation (default: true)
     *   - showProgressIndicator: Show debug indicators (default: false)
     */
    init(
        texts: [String],
        fontSize: CGFloat = 25,
        animationSpeed: Double? = nil,
        containerWidthOverride: CGFloat? = nil,
        windowWidth: CGFloat? = nil,
        autoWindowMargin: CGFloat = 10,
        forwardOnlyMode: Bool = true,
        variableSpeed: Bool = false,
        trackingAccuracy: CGFloat = 0.85,
        cleanup: Bool = true,
        showProgressIndicator: Bool = false
    ) {
        self.texts = texts.isEmpty ? [""] : texts
        self.fontSize = fontSize

        let firstText = texts.first ?? ""
        self.animationSpeed = Double(firstText.count) / (animationSpeed ?? 7)

        // Static mode configuration
        staticMode = true
        self.forwardOnlyMode = forwardOnlyMode
        self.windowWidth = windowWidth
        self.autoWindowMargin = autoWindowMargin
        self.containerWidthOverride = containerWidthOverride
        self.variableSpeed = variableSpeed
        self.trackingAccuracy = min(max(trackingAccuracy, 0), 1)
        self.cleanup = cleanup

        // Debug
        self.showProgressIndicator = showProgressIndicator
    }

    /**
     * Creates an animated cursive text view with static window mode for a single text.
     *
     * Convenience initializer for typing indicators with a single message.
     *
     * - Parameters:
     *   - text: The text to animate
     *   - fontSize: Font size in points (default: 25)
     *   - animationSpeed: Characters per second, auto-calculated if nil (default: 7 chars/sec)
     *   - containerWidthOverride: Container width for calculating window size (default: nil)
     *   - windowWidth: Override for sliding window width (default: nil)
     *   - autoWindowMargin: Right margin when calculating window width (default: 10)
     *   - forwardOnlyMode: Prevent backward cursor movement (default: true)
     *   - variableSpeed: Vary speed based on path complexity (default: false)
     *   - trackingAccuracy: Path tracking precision 0.0-1.0 (default: 0.85)
     *   - cleanup: Enable cleanup phase after animation (default: true)
     *   - showProgressIndicator: Show debug indicators (default: false)
     */
    init(
        text: String,
        fontSize: CGFloat = 25,
        animationSpeed: Double? = nil,
        containerWidthOverride: CGFloat? = nil,
        windowWidth: CGFloat? = nil,
        autoWindowMargin: CGFloat = 10,
        forwardOnlyMode: Bool = true,
        variableSpeed: Bool = false,
        trackingAccuracy: CGFloat = 0.85,
        cleanup: Bool = true,
        showProgressIndicator: Bool = false
    ) {
        self.init(
            texts: [text],
            fontSize: fontSize,
            animationSpeed: animationSpeed,
            containerWidthOverride: containerWidthOverride,
            windowWidth: windowWidth,
            autoWindowMargin: autoWindowMargin,
            forwardOnlyMode: forwardOnlyMode,
            variableSpeed: variableSpeed,
            trackingAccuracy: trackingAccuracy,
            cleanup: cleanup,
            showProgressIndicator: showProgressIndicator
        )
    }

    /**
     * Creates an animated cursive text view with progressive mode (traditional left-to-right).
     *
     * This mode animates text appearing progressively from left to right without a sliding window.
     * Simpler than static mode - most parameters don't apply here.
     *
     * - Parameters:
     *   - text: The text to animate
     *   - fontSize: Font size in points (default: 25)
     *   - animationDuration: Total animation time in seconds, auto-calculated if nil
     *   - showProgressIndicator: Show debug indicators (default: false)
     */
    init(
        progressiveText text: String,
        fontSize: CGFloat = 25,
        animationDuration: Double? = nil,
        showProgressIndicator: Bool = false
    ) {
        texts = [text]
        self.fontSize = fontSize
        animationSpeed = animationDuration ?? (Double(text.count) / 3)

        // Progressive mode configuration - most parameters don't apply
        staticMode = false
        forwardOnlyMode = false
        windowWidth = nil
        autoWindowMargin = 0
        containerWidthOverride = nil
        variableSpeed = false
        trackingAccuracy = 0.85
        cleanup = false

        // Debug
        self.showProgressIndicator = showProgressIndicator
    }

    /// Creates the cursive word shape for the current text and font size
    var shape: CursiveWordShape {
        CursiveWordShape(text: currentText, fontSize: fontSize)
    }

    /// Generates the complete path for the text within the measured bounds
    var path: Path {
        shape.path(in: CGRect(origin: .zero, size: measuredWordSize))
    }

    /// Current position of the drawing cursor (end of visible text)
    var trimEndPoint: CGPoint {
        pathAnalyzer?.pointAtParameter(drawProgress) ?? .zero
    }

    /**
     * Calculates the visual X position where the trim window starts.
     *
     * In static mode, this determines where the visible text begins, which is crucial
     * for maintaining the fixed left edge alignment. Uses the trimmed path's bounding
     * rectangle for accurate visual positioning, falling back to path analyzer if needed.
     *
     * - Returns: X coordinate of the trim start position, or 0 in non-static mode
     */
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

    /**
     * Calculates the visual X position where the trim window ends.
     *
     * This represents the rightmost edge of the currently visible text, used for
     * positioning indicators and calculating window boundaries.
     *
     * - Returns: X coordinate of the trim end position
     */
    private var trimEndVisualX: CGFloat {
        let fallback = pathAnalyzer?.pointAtParameter(drawProgress).x ?? fixedLeftEdgeX
        let trimmed = path.trimmedPath(from: 0, to: drawProgress)
        let rect = trimmed.boundingRect

        if rect.isNull || rect.isInfinite {
            return fallback
        }

        return rect.maxX
    }

    /**
     * Calculates the X position of the drawing cursor ("pipe") with forward-only movement.
     *
     * The cursor behavior varies by mode:
     * - **Static Mode**: Uses the trim end visual position
     * - **Forward-Only Mode**: Maintains the maximum X position reached (ratchet behavior)
     * - **Normal Mode**: Follows the actual trim end point
     *
     * The forward-only behavior prevents visual jitter when the path curves back on itself.
     *
     * - Returns: X coordinate of the drawing cursor
     */
    var pipeX: CGFloat {
        if staticMode {
            return trimEndVisualX
        }

        if forwardOnlyMode {
            // Forward-only mode: only increase, never decrease
            // This prevents the cursor from jumping backward when the path curves
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

    /**
     * Calculates the horizontal offset needed to maintain a fixed left edge in static window mode.
     *
     * This is the core mechanism that creates the illusion of text being written at a fixed position.
     * The calculation works as follows:
     *
     * 1. **Ideal Offset**: Calculate where the text should be positioned to align the trim start
     *    with the fixed left edge: `offset = fixedLeftEdgeX - trimStartVisualX`
     *
     * 2. **Ratchet Mechanism**: Only allow leftward (negative) movement to prevent rightward drift.
     *    This ensures the left edge never moves to the right, maintaining perfect alignment.
     *
     * 3. **Debug Validation**: In debug builds, verify that the actual left edge position matches
     *    the expected fixed position within a small tolerance.
     *
     * The ratchet mechanism is crucial for handling cases where the cursive path curves back on
     * itself, which would otherwise cause the left edge to drift rightward.
     *
     * - Returns: Horizontal offset in points (typically negative for leftward movement)
     */
    var textOffset: CGFloat {
        guard staticMode else { return 0 }
        guard resolvedWindowWidth != nil else { return 0 }

        // During cleanup phase, use the frozen offset to keep text stationary
        if isInCleanupPhase {
            return frozenCleanupOffset
        }

        // Calculate the ideal offset to align trim start with fixed left edge
        // This is the mathematical relationship: offset = target_position - current_position
        let idealOffset = fixedLeftEdgeX - trimStartVisualX

        // Ratchet mechanism: only allow leftward (negative) movement
        // This prevents rightward drift when the path curves back on itself
        let ratchetedOffset = min(idealOffset, minTextOffset)

        // Update the minimum offset if we've moved further left
        // This maintains the ratchet state for future calculations
        DispatchQueue.main.async {
            if idealOffset < minTextOffset {
                minTextOffset = idealOffset
            }
        }

        #if DEBUG
            // Verify that the ratchet mechanism maintains proper left edge alignment
            let actualLeftEdge = trimStartVisualX + ratchetedOffset
            if abs(actualLeftEdge - fixedLeftEdgeX) > 0.01 {
                Logger.animatedCursiveText
                    .debug("⚠️ Left edge alignment: Expected: \(fixedLeftEdgeX), Actual: \(actualLeftEdge)")
                Logger.animatedCursiveText
                    .debug(
                        "   TrimStartVisualX: \(trimStartVisualX), Ideal: \(idealOffset), Ratcheted: \(ratchetedOffset)"
                    )
            }
        #endif

        return ratchetedOffset
    }

    /**
     * Updates the smoothed trim start positions using a dual forward-only tracking system.
     *
     * This sophisticated smoothing system prevents visual jitter and left edge drift by maintaining
     * two separate forward-only tracking mechanisms:
     *
     * **1. Natural Position Tracking** (`naturalDrawProgressFrom`):
     * - Used for offset calculations and maintaining consistent left edge alignment
     * - Smoothly interpolates toward the target but never moves backward
     * - Prevents left edge drift by ensuring offset calculations use a stable reference
     *
     * **2. Visual Position Tracking** (`smoothedDrawProgressFrom`):
     * - Used for the actual trim rendering that users see
     * - Also forward-only to prevent visual jitter when path curves backward
     * - Creates smooth visual transitions while maintaining forward progression
     *
     * **Smoothing Algorithm**:
     * - Uses exponential smoothing with a factor of 0.15 for natural movement
     * - Snaps to target when within 0.0001 tolerance to prevent infinite interpolation
     * - Both tracking systems respect the forward-only constraint
     *
     * This dual system solves the fundamental challenge of maintaining a fixed left edge
     * while providing smooth visual animations, even when the cursive path has complex curves.
     */
    private func updateSmoothedDrawProgressFrom() {
        guard staticMode else {
            // Reset all smoothing state in non-static mode
            smoothedDrawProgressFrom = 0
            naturalDrawProgressFrom = 0
            targetDrawProgressFrom = 0
            maxNaturalDrawProgressFrom = 0
            return
        }

        let smoothingFactor: CGFloat = 0.15 // Controls smoothing speed (lower = smoother)
        let previousNaturalFrom = naturalDrawProgressFrom
        let previousVisualFrom = smoothedDrawProgressFrom

        // 1. Update naturalDrawProgressFrom - forward-only for consistent offset calculation
        // This prevents left edge drift by ensuring naturalDrawProgressFrom never decreases
        if targetDrawProgressFrom > maxNaturalDrawProgressFrom {
            maxNaturalDrawProgressFrom = targetDrawProgressFrom
        }

        if maxNaturalDrawProgressFrom > naturalDrawProgressFrom {
            // Smooth interpolation toward the maximum position reached
            naturalDrawProgressFrom += (maxNaturalDrawProgressFrom - naturalDrawProgressFrom) * smoothingFactor
            // Snap to target when close enough to prevent infinite interpolation
            if abs(maxNaturalDrawProgressFrom - naturalDrawProgressFrom) < 0.0001 {
                naturalDrawProgressFrom = maxNaturalDrawProgressFrom
            }
        }

        naturalDrawProgressFrom = max(0, min(1, naturalDrawProgressFrom))

        // 2. Update smoothedDrawProgressFrom - forward-only for visual trim rendering
        // This ensures the trim window only moves forward visually, preventing jitter
        if targetDrawProgressFrom > smoothedDrawProgressFrom {
            // Allow forward movement with smooth interpolation
            smoothedDrawProgressFrom += (targetDrawProgressFrom - smoothedDrawProgressFrom) * smoothingFactor
            // Snap to target when close enough
            if abs(targetDrawProgressFrom - smoothedDrawProgressFrom) < 0.0001 {
                smoothedDrawProgressFrom = targetDrawProgressFrom
            }
        } else {
            // Visual position blocked from moving backward - this is the key anti-jitter mechanism
            #if DEBUG
                if targetDrawProgressFrom < previousVisualFrom - 0.0001 {
                    Logger.animatedCursiveText
                        .debug(
                            "🛡️ Visual trim movement blocked: target \(targetDrawProgressFrom) < current \(previousVisualFrom)"
                        )
                }
            #endif
        }

        smoothedDrawProgressFrom = max(0, min(1, smoothedDrawProgressFrom))

        // Debug logging for position changes to track the dual system behavior
        #if DEBUG
            if abs(naturalDrawProgressFrom - previousNaturalFrom) > 0.0001 {
                let direction = naturalDrawProgressFrom > previousNaturalFrom ? "FORWARD" : "BACKWARD"
                Logger.animatedCursiveText
                    .debug("📍 Natural position: \(previousNaturalFrom) → \(naturalDrawProgressFrom) (\(direction))")
            }

            if abs(smoothedDrawProgressFrom - previousVisualFrom) > 0.0001 {
                Logger.animatedCursiveText
                    .debug("👁️ Visual position: \(previousVisualFrom) → \(smoothedDrawProgressFrom) (FORWARD ONLY)")
            }
        #endif
    }

    /**
     * Converts linear time progress to path-length-adjusted progress for consistent visual movement.
     *
     * This function addresses a fundamental challenge in path animation: cursive letters have varying
     * complexity, with some sections requiring more path length than others. Without adjustment,
     * the animation would appear to speed up in simple areas and slow down in complex areas.
     *
     * **Two Animation Modes**:
     *
     * 1. **Variable Speed Mode** (`variableSpeed = true`):
     *    - Uses linear progress directly, allowing natural speed variation
     *    - Faster in simple path sections, slower in complex curves
     *    - More organic feel but less predictable timing
     *
     * 2. **Fixed Speed Mode** (`variableSpeed = false`):
     *    - Adjusts progress to maintain constant visual movement speed
     *    - Uses path length calculations to ensure uniform advancement
     *    - More predictable and consistent visual experience
     *
     * **Algorithm for Fixed Speed Mode**:
     * 1. Calculate target path length based on linear progress
     * 2. Use binary search to find the corresponding path parameter efficiently
     * 3. Interpolate between samples for smooth, sub-sample precision
     *
     * - Parameter linearProgress: Time-based progress from 0.0 to 1.0
     * - Returns: Path-adjusted progress from 0.0 to 1.0
     */
    private func adjustProgressForPathLength(_ linearProgress: CGFloat) -> CGFloat {
        guard let analyzer = pathAnalyzer else { return linearProgress }

        if variableSpeed {
            // Variable speed mode: use linear progress directly
            // This allows the animation speed to vary naturally with path complexity
            return linearProgress
        } else {
            // Fixed speed mode: adjust for path length to achieve linear visual movement
            // This ensures the trim head moves at constant visual speed regardless of path complexity
            let targetPathLength = linearProgress * analyzer.totalPathLength

            // Use binary search for efficiency (O(log n) instead of O(n))
            // This is crucial for performance with high sample counts (typically 800 samples)
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
            // This provides sub-sample precision for smoother animation
            if low > 0, low < samples.count {
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

    // MARK: - SwiftUI View Body

    var body: some View {
        ZStack(alignment: .leading) {
            // Main cursive text shape with trim animation
            CursiveWordShape(text: currentText, fontSize: fontSize)
                .trim(
                    from: staticMode ? smoothedDrawProgressFrom : 0, // Static mode uses sliding window
                    to: drawProgress // End position advances normally
                )
                .stroke(
                    Color.secondary,
                    style: StrokeStyle(
                        lineWidth: fontSizeValue / 20, // Proportional line width
                        lineCap: .round, // Smooth line endings
                        lineJoin: .round // Smooth line connections
                    )
                )
                .frame(width: measuredWordSize.width, height: measuredWordSize.height, alignment: .leading)
                .offset(x: staticMode ? textOffset : 0) // Apply calculated offset for fixed left edge

            // Debug indicators for development and testing
            progressIndicatorView
        }
        .frame(width: measuredWordSize.width, height: measuredWordSize.height, alignment: .leading)
        .fixedSize() // Preserve intrinsic size so parent clipping affects the trailing edge
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            updateContainerWidth(newWidth)
        }
        .onAppear {
            // Reset to first text when view appears
            currentTextIndex = 0
            restartAnimation()
        }
        .onDisappear {
            // Clean up timer to prevent memory leaks
            animationTimer?.invalidate()
            animationTimer = nil
            // Reset index for next appearance
            currentTextIndex = 0
        }
    }

    private func emitGeometryLogIfNeeded(reason: String, force: Bool = false) {
        guard loggingEnabled else { return }

        let shouldActivate = staticActivationThresholdReached
        let isActive = staticWindowCurrentlyActive
        let effectiveSnapshot = effectiveContainerWidth

        let widthChanged: Bool = switch (lastLoggedEffectiveContainerWidth, effectiveSnapshot) {
        case let (previous?, current?):
            abs(previous - current) >= 0.5
        case (nil, nil):
            false
        default:
            true
        }

        if force || widthChanged || shouldActivate != lastLoggedShouldActivate || isActive != lastLoggedWindowActive {
            logGeometrySnapshot(reason: reason, shouldActivate: shouldActivate, isActive: isActive)
            lastLoggedShouldActivate = shouldActivate
            lastLoggedWindowActive = isActive
            lastLoggedEffectiveContainerWidth = effectiveSnapshot
        }
    }

    private func logGeometrySnapshot(reason: String, shouldActivate: Bool, isActive: Bool) {
        guard loggingEnabled else { return }

        let marginText = String(format: "%.1f", autoWindowMargin)
        let intrinsicText = String(format: "%.1f", measuredWordSize.width)
        let trimStartText = String(format: "%.1f", trimStartVisualX)
        let trimEndText = String(format: "%.1f", trimEndVisualX)
        let offsetText = String(format: "%.1f", textOffset)
        let drawText = formatProgress(drawProgress)
        let drawFromText = formatProgress(smoothedDrawProgressFrom)
        let overrideText = formatWidth(containerWidthOverride)
        let measuredText = formatWidth(containerWidth)
        let effectiveText = formatWidth(effectiveContainerWidth)
        let resolvedText = formatWidth(resolvedWindowWidth)

        Logger.animatedCursiveText.debug("""
        🧭 geometry (\(reason)):
          overrideWidth=\(overrideText) measuredWidth=\(measuredText) effectiveWidth=\(effectiveText) resolvedWidth=\(
              resolvedText
          ) margin=\(marginText)
          intrinsicWidth=\(intrinsicText) trimStartX=\(trimStartText) trimEndX=\(trimEndText) offset=\(offsetText)
          drawProgress=\(drawText) drawProgressFrom=\(drawFromText)
          shouldActivate=\(shouldActivate ? "yes" : "no") active=\(isActive ? "yes" : "no")
        """)
    }

    private func resetGeometryLoggerState() {
        lastLoggedShouldActivate = nil
        lastLoggedWindowActive = nil
        lastLoggedEffectiveContainerWidth = nil
    }

    /**
     * Debug indicators for visualizing trim positions and alignment during development.
     *
     * **Static Mode Indicators**:
     * - **Purple Line**: Fixed left edge reference (should never move from x=0)
     * - **Green Line**: Current trim start position (left edge of visible text)
     * - **Red Line**: Current trim end position (right edge of visible text)
     *
     * **Progressive Mode Indicators**:
     * - **Red Line**: Drawing cursor position (follows trim end)
     *
     * These indicators are invaluable for debugging the complex positioning logic,
     * especially for verifying that the fixed left edge remains stationary and that
     * the trim window moves correctly.
     */
    var progressIndicatorView: some View {
        Group {
            if showProgressIndicator {
                if staticMode {
                    if pathAnalyzer != nil {
                        // Fixed left edge indicator (purple line) - should never move
                        // This serves as the reference point for the fixed left edge alignment
                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: 3, height: measuredWordSize.height)
                            .position(
                                x: fixedLeftEdgeX, // This should always be at x=0
                                y: measuredWordSize.height / 2
                            )
                            .frame(width: measuredWordSize.width, height: measuredWordSize.height, alignment: .leading)

                        // Trim start indicator (green line) - shows where visible text begins
                        // This should align with the purple line when the system is working correctly
                        Rectangle()
                            .fill((staticWindowCurrentlyActive ? Color.green : Color.orange).opacity(0.9))
                            .frame(width: 3, height: measuredWordSize.height)
                            .position(
                                x: trimStartVisualX + textOffset,
                                y: measuredWordSize.height / 2
                            )
                            .frame(width: measuredWordSize.width, height: measuredWordSize.height, alignment: .leading)

                        // Trim end indicator (red line) - shows where visible text ends
                        // This represents the current drawing cursor position
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
                    // Progressive mode: simple cursor indicator
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

    // MARK: - Animation Control

    /**
     * Restarts the animation from the beginning, resetting all state and initializing the path analyzer.
     *
     * This method performs a complete reset of the animation system:
     *
     * **1. Timer Management**: Cancels any existing animation timer to prevent conflicts
     *
     * **2. State Reset**: Resets all progress tracking variables to their initial values:
     *    - Core progress tracking (drawProgress, drawProgressFrom)
     *    - Forward-only mechanisms (maxPipeX, maxDrawProgressFrom)
     *    - Dual smoothing system (smoothed/natural/target positions)
     *    - Ratchet mechanism (minTextOffset)
     *
     * **3. Path Analysis Setup**: Creates a new PathXAnalyzer for the current text and font size.
     *    This analyzer provides the mathematical foundation for all position calculations,
     *    window management, and coordinate transformations.
     *
     * **4. Animation Timer**: Starts a 60fps timer that drives the animation loop with
     *    sophisticated logic for both static window and progressive modes.
     */
    func restartAnimation() {
        // Cancel any existing timer to prevent multiple timers running simultaneously
        animationTimer?.invalidate()

        // Reset all progress tracking to initial state
        drawProgress = 0
        drawProgressFrom = 0
        maxPipeX = 0
        maxDrawProgressFrom = 0

        // Reset the dual smoothing system state
        smoothedDrawProgressFrom = 0
        naturalDrawProgressFrom = 0
        targetDrawProgressFrom = 0

        // Reset forward-only tracking mechanisms
        maxNaturalDrawProgressFrom = 0

        // Reset the ratchet mechanism for left edge alignment
        minTextOffset = 0
        frozenCleanupOffset = 0
        isInCleanupPhase = false
        resetGeometryLoggerState()

        // Initialize path analyzer for mathematical calculations
        // This provides the foundation for all position and window calculations
        let shape = CursiveWordShape(text: currentText, fontSize: fontSizeValue)
        let path = shape.path(in: CGRect(origin: .zero, size: measuredWordSize))
        let analyzer = PathXAnalyzer(path: path.cgPath)
        pathAnalyzer = analyzer

        // Start the main animation timer running at 60fps for smooth updates
        let startTime = Date()
        var cleanupPhaseStartTime: Date?

        emitGeometryLogIfNeeded(reason: "restart", force: true)

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [self] timer in
            let now = Date()
            let elapsed = now.timeIntervalSince(startTime)
            let progress = min(elapsed / animationSpeed, 1.0)

            if staticMode {
                // **Static Mode Animation Logic**

                // Check if we've entered the cleanup phase
                if cleanup, progress >= 1.0, resolvedWindowWidth != nil {
                    // **Cleanup Phase**: Trim away remaining text from left to right
                    if cleanupPhaseStartTime == nil {
                        cleanupPhaseStartTime = Date()
                        // Freeze the offset at its current value when entering cleanup
                        frozenCleanupOffset = textOffset
                        isInCleanupPhase = true
                    }

                    // Keep the end position at 100% during cleanup
                    drawProgress = 1.0

                    // Calculate cleanup progress with 1.0 second duration
                    let cleanupElapsed = now.timeIntervalSince(cleanupPhaseStartTime!)
                    let cleanupDuration = 0.5
                    let linearCleanupProgress = min(cleanupElapsed / cleanupDuration, 1.0)

                    // Apply ease-in curve (t^2) for slow start, faster finish
                    let easedCleanupProgress = linearCleanupProgress * linearCleanupProgress

                    // Calculate target trim start position
                    let startFrom = maxDrawProgressFrom
                    let newTargetFrom = startFrom + (1.0 - startFrom) * easedCleanupProgress

                    // CRITICAL: Only allow forward movement to maintain system integrity
                    if newTargetFrom > targetDrawProgressFrom {
                        targetDrawProgressFrom = newTargetFrom
                        drawProgressFrom = newTargetFrom // Keep for compatibility
                    }

                    // Apply the dual smoothing system
                    updateSmoothedDrawProgressFrom()

                    // Check if cleanup is complete
                    if smoothedDrawProgressFrom >= 0.999 {
                        targetDrawProgressFrom = 1.0
                        drawProgressFrom = 1.0

                        // Check if there are more texts to animate
                        if currentTextIndex < texts.count - 1 {
                            // Move to next text in the sequence
                            currentTextIndex += 1

                            // Restart animation for the next text
                            // Don't invalidate the timer - just restart the animation state
                            timer.invalidate()
                            animationTimer = nil
                            restartAnimation()
                        } else {
                            // All texts completed - stop the animation
                            timer.invalidate()
                            animationTimer = nil
                        }
                    }

                    return
                }

                // **Main Animation Phase**: Normal drawing progression
                let adjustedProgress = adjustProgressForPathLength(progress)
                drawProgress = adjustedProgress

                if let windowWidth = resolvedWindowWidth {
                    // Calculate the sliding window start position
                    // Use measuredWordSize.width for consistency with view layout
                    let effectiveWidth = min(windowWidth, measuredWordSize.width)

                    // Find where the window should start to maintain the specified width
                    let windowStart = analyzer.parameterXPixelsBefore(
                        endParameter: adjustedProgress,
                        xDistance: effectiveWidth
                    )

                    let clampedFrom = min(windowStart, adjustedProgress)

                    // CRITICAL: Ensure forward-only progression
                    // This is the KEY mechanism that prevents left edge drift
                    if clampedFrom > maxDrawProgressFrom {
                        maxDrawProgressFrom = clampedFrom
                        targetDrawProgressFrom = clampedFrom
                        drawProgressFrom = clampedFrom // Keep for compatibility
                    }

                    // If clampedFrom would move backward, keep the current position
                    // This ensures the trim window never moves backward, preventing jitter
                } else {
                    // No window width specified - show everything from the beginning
                    targetDrawProgressFrom = 0
                    drawProgressFrom = 0
                    maxDrawProgressFrom = 0
                }

                // Apply the sophisticated dual smoothing system
                updateSmoothedDrawProgressFrom()

                // Only stop if cleanup is disabled or no window width is available
                if progress >= 1.0, !cleanup || resolvedWindowWidth == nil {
                    timer.invalidate()
                    animationTimer = nil
                }
            } else {
                // **Progressive Mode Animation Logic**
                // Simpler logic for traditional left-to-right animation
                let adjustedProgress = adjustProgressForPathLength(progress)
                drawProgress = adjustedProgress

                // Reset all window-related state for progressive mode
                targetDrawProgressFrom = 0
                drawProgressFrom = 0
                maxDrawProgressFrom = 0
                smoothedDrawProgressFrom = 0 // No window in progressive mode

                // Check if animation is complete
                if progress >= 1.0 {
                    timer.invalidate()
                    animationTimer = nil
                }
            }

            emitGeometryLogIfNeeded(reason: "animation tick")
        }
    }
}

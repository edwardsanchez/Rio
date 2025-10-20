//
//  RectangleSizeManager.swift
//  Rio
//
//  Created by Edward Sanchez on 10/17/25.
//

import Foundation
import SwiftUI

/// Manages the size and animations of the inner rectangle
@Observable
class RectangleSizeManager {
    private var rectangleTransition: RectangleTransition
    private let config: BubbleConfiguration
    
    /// Pending size to apply after morph completes
    private var pendingSize: CGSize?
    private var pendingTask: Task<Void, Never>?
    
    /// Height of a single line of text for constraining during morph
    var singleLineTextHeight: CGFloat = 0
    
    init(initialSize: CGSize, config: BubbleConfiguration) {
        let now = Date()
        self.rectangleTransition = RectangleTransition(
            startSize: initialSize,
            endSize: initialSize,
            startTime: now,
            initialVelocity: .zero
        )
        self.config = config
    }
    
    // MARK: - Size Management
    
    /// Updates the target size, potentially deferring the update during morphs
    func updateSize(
        to size: CGSize,
        animationState: BubbleAnimationState,
        skipAnimation: Bool = false
    ) {
        // Cancel any pending updates
        pendingTask?.cancel()
        pendingTask = nil
        
        let now = Date()
        
        // For morphing to talking, constrain height during morph
        if case .morphing(_, let to, _) = animationState, to.isTalking {
            let morphProgress = animationState.animationProgress(at: now, config: config)
            if morphProgress < 0.98 {
                // Keep width constant and constrain height to single-line
                let currentWidth = rectangleTransition.endSize.width
                let morphSize = CGSize(
                    width: currentWidth,
                    height: singleLineTextHeight > 0 ? singleLineTextHeight : size.height
                )
                applySize(morphSize, skipAnimation: skipAnimation)
                
                // Store full size to apply after morph
                pendingSize = size
                schedulePendingApplication()
                return
            }
        }
        
        applySize(size, skipAnimation: skipAnimation)
    }
    
    /// Returns the current animated size
    func currentSize(at date: Date) -> CGSize {
        rectangleTransition.value(at: date, duration: config.resizeCutoffDuration)
    }
    
    // MARK: - Private Helpers
    
    private func applySize(_ size: CGSize, skipAnimation: Bool) {
        let now = Date()
        
        if skipAnimation {
            // Apply size instantly without animation
            rectangleTransition = RectangleTransition(
                startSize: size,
                endSize: size,
                startTime: now.addingTimeInterval(-1), // Set in past so animation is "complete"
                initialVelocity: .zero
            )
        } else {
            let currentSize = rectangleTransition.value(at: now, duration: config.resizeCutoffDuration)
            
            // Calculate current velocity for continuity
            let dt: CGFloat = 0.016  // ~1 frame at 60fps
            let futureSize = rectangleTransition.value(at: now.addingTimeInterval(dt), duration: config.resizeCutoffDuration)
            let currentVelocity = CGSize(
                width: (futureSize.width - currentSize.width) / dt,
                height: (futureSize.height - currentSize.height) / dt
            )
            
            // Add velocity boost for snappier feel
            let velocityBoost: CGFloat = 200  // points per second
            let widthDirection: CGFloat = size.width > currentSize.width ? 1 : -1
            let heightDirection: CGFloat = size.height > currentSize.height ? 1 : -1
            
            rectangleTransition = RectangleTransition(
                startSize: currentSize,
                endSize: size,
                startTime: now,
                initialVelocity: CGSize(
                    width: currentVelocity.width + widthDirection * velocityBoost,
                    height: currentVelocity.height + heightDirection * velocityBoost
                )
            )
        }
        
        pendingSize = nil
    }
    
    private func schedulePendingApplication() {
        pendingTask?.cancel()
        pendingTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(config.morphDuration))
            guard !Task.isCancelled else { return }
            
            if let pending = pendingSize {
                applySize(pending, skipAnimation: false)
            }
        }
    }
}

// MARK: - RectangleTransition Model

/// Spring interpolation container for the inner rectangle's size
struct RectangleTransition {
    var startSize: CGSize
    var endSize: CGSize
    var startTime: Date
    var initialVelocity: CGSize  // Initial velocity in points per second
    
    // Spring parameters
    static let dampingRatio: CGFloat = 0.6
    static let response: CGFloat = 0.24
    
    func value(at date: Date, duration: TimeInterval) -> CGSize {
        guard duration > 0 else { return endSize }
        let elapsed = CGFloat(date.timeIntervalSince(startTime))
        
        if elapsed >= CGFloat(duration) {
            return endSize
        }
        
        let widthDelta = endSize.width - startSize.width
        let heightDelta = endSize.height - startSize.height
        
        let widthProgress = springValue(
            elapsed: elapsed,
            delta: widthDelta,
            initialVelocity: initialVelocity.width
        )
        let heightProgress = springValue(
            elapsed: elapsed,
            delta: heightDelta,
            initialVelocity: initialVelocity.height
        )
        
        return CGSize(
            width: startSize.width + widthProgress,
            height: startSize.height + heightProgress
        )
    }
    
    private func springValue(elapsed: CGFloat, delta: CGFloat, initialVelocity: CGFloat) -> CGFloat {
        let zeta = Self.dampingRatio
        let omega0 = 2 * .pi / Self.response
        
        let normalizedVelocity = delta != 0 ? initialVelocity / delta : 0
        
        let result: CGFloat
        
        if zeta < 1 {
            // Underdamped (bouncy)
            let omegaD = omega0 * sqrt(1 - zeta * zeta)
            let A: CGFloat = 1
            let B = (normalizedVelocity + zeta * omega0 * A) / omegaD
            
            let envelope = exp(-zeta * omega0 * elapsed)
            let oscillation = A * cos(omegaD * elapsed) + B * sin(omegaD * elapsed)
            result = 1 - envelope * oscillation
            
        } else if zeta == 1 {
            // Critically damped
            let A: CGFloat = 1
            let B = normalizedVelocity + omega0 * A
            result = 1 - (A + B * elapsed) * exp(-omega0 * elapsed)
            
        } else {
            // Overdamped
            let r1 = -omega0 * (zeta + sqrt(zeta * zeta - 1))
            let r2 = -omega0 * (zeta - sqrt(zeta * zeta - 1))
            let A = (normalizedVelocity - r2) / (r1 - r2)
            let B: CGFloat = 1 - A
            result = 1 - (A * exp(r1 * elapsed) + B * exp(r2 * elapsed))
        }
        
        return result * delta
    }
}

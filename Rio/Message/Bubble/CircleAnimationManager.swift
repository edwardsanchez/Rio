//
//  CircleAnimationManager.swift
//  Rio
//
//  Created by Edward Sanchez on 10/17/25.
//

import Foundation
import SwiftUI

/// Manages the state and animations of decorative circles around the bubble
@Observable
class CircleAnimationManager {
    private var circleTransitions: [CircleTransition] = []
    private var nextCircleID: Int = 0
    private let config: BubbleConfiguration

    init(config: BubbleConfiguration) {
        self.config = config
    }

    // MARK: - Configuration

    /// Sets up initial circle transitions without animation
    func configureInitial(targetDiameters: [CGFloat]) {
        let now = Date()
        circleTransitions = targetDiameters.enumerated().map { index, value in
            CircleTransition(
                id: index,
                index: index,
                startValue: value,
                endValue: value,
                startTime: now,
                isDisappearing: false
            )
        }

        nextCircleID = targetDiameters.count
    }

    // MARK: - Updates

    /// Updates circle transitions to animate to new target diameters
    func updateTransitions(targetDiameters: [CGFloat]) {
        let now = Date()
        var updated: [CircleTransition] = []
        let existing = sortedTransitions()

        let sharedCount = min(existing.count, targetDiameters.count)

        // Update existing circles to new targets
        for i in 0 ..< sharedCount {
            var transition = existing[i]
            let currentValue = transition.value(at: now, duration: config.circleTransitionDuration)
            transition.startValue = currentValue
            transition.endValue = targetDiameters[i]
            transition.startTime = now
            transition.index = i
            transition.isDisappearing = false
            updated.append(transition)
        }

        // Mark excess circles for removal
        if existing.count > targetDiameters.count {
            for i in targetDiameters.count ..< existing.count {
                var transition = existing[i]
                let currentValue = transition.value(at: now, duration: config.circleTransitionDuration)
                transition.startValue = currentValue
                transition.endValue = 0
                transition.startTime = now
                transition.index = i
                transition.isDisappearing = true
                updated.append(transition)
                scheduleRemoval(of: transition.id)
            }
        }

        // Add new circles
        if targetDiameters.count > existing.count {
            for i in existing.count ..< targetDiameters.count {
                let newID = nextCircleID
                nextCircleID += 1
                let transition = CircleTransition(
                    id: newID,
                    index: i,
                    startValue: 0,
                    endValue: targetDiameters[i],
                    startTime: now,
                    isDisappearing: false
                )

                updated.append(transition)
            }
        }

        updated.sort { $0.index < $1.index }
        circleTransitions = updated
    }

    // MARK: - Queries

    /// Returns current interpolated diameters of all visible circles
    func currentBaseDiameters(at date: Date) -> [CGFloat] {
        sortedTransitions()
            .compactMap { transition in
                let value = transition.value(at: date, duration: config.circleTransitionDuration)
                if transition.isDisappearing, value <= 0.01 {
                    return nil
                }

                return max(0, value)
            }
    }

    /// Returns target diameters for comparison
    func currentTargetDiameters(tolerance: CGFloat = 0.001) -> [CGFloat] {
        sortedTransitions()
            .compactMap { transition in
                let value = transition.endValue
                return value > tolerance ? value : nil
            }
    }

    /// Checks if two diameter arrays are almost identical
    func almostEqual(_ lhs: [CGFloat], _ rhs: [CGFloat], tolerance: CGFloat = 0.1) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (l, r) in zip(lhs, rhs) where abs(l - r) > tolerance {
            return false
        }

        return true
    }

    // MARK: - Private Helpers

    private func sortedTransitions() -> [CircleTransition] {
        circleTransitions.sorted { $0.index < $1.index }
    }

    private func scheduleRemoval(of id: Int) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(config.circleTransitionDuration))
            circleTransitions.removeAll { $0.id == id && $0.isDisappearing }
        }
    }
}

// MARK: - CircleTransition Model

/// Tracks interpolation between circle diameters for smooth animations
struct CircleTransition: Identifiable {
    let id: Int
    var index: Int
    var startValue: CGFloat
    var endValue: CGFloat
    var startTime: Date
    var isDisappearing: Bool

    func value(at date: Date, duration: TimeInterval) -> CGFloat {
        guard duration > 0 else { return endValue }
        let elapsed = date.timeIntervalSince(startTime)
        let clamped = max(0, min(1, elapsed / duration))
        let progress = CGFloat(clamped)
        let eased = CGFloat(0.5 - 0.5 * cos(Double(progress) * .pi))
        return startValue + (endValue - startValue) * eased
    }
}

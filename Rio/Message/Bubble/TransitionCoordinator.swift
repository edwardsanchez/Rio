//
//  TransitionCoordinator.swift
//  Rio
//
//  Created by Edward Sanchez on 10/17/25.
//

import Foundation
import SwiftUI

/// Coordinates bubble transitions and manages animation state progression
@Observable
class TransitionCoordinator {
    private(set) var animationState: BubbleAnimationState
    private let config: BubbleConfiguration

    /// The bubble type to display (may lag behind actual bubbleType for delayed transitions)
    private(set) var displayedType: BubbleType

    /// Whether the view should render using the native SwiftUI branch
    private(set) var canUseNative: Bool

    /// Task for auto-transitioning to idle state when animation completes
    private var autoTransitionTask: Task<Void, Never>?

    /// Task for delayed type updates
    private var delayedTypeTask: Task<Void, Never>?

    /// Task for slightly delayed native swap after morph completes
    private var nativeSwapTask: Task<Void, Never>?

    init(initialType: BubbleType, config: BubbleConfiguration) {
        animationState = .idle(initialType)
        displayedType = initialType
        self.config = config
        canUseNative = initialType.isTalking
    }

    // MARK: - Transition Management

    /// Starts a transition from one bubble type to another
    func startTransition(from oldType: BubbleType, to newType: BubbleType) {
        // Cancel any pending transitions
        autoTransitionTask?.cancel()
        delayedTypeTask?.cancel()
        nativeSwapTask?.cancel()

        let now = Date()
        animationState = BubbleAnimationState.transition(from: oldType, to: newType, at: now)

        // Handle delayed type updates for specific transitions
        if oldType.isThinking, newType.isRead {
            // Keep displayedType at .thinking during explosion
            scheduleDelayedTypeUpdate(to: newType, delay: config.explosionDuration)
        } else if oldType.isRead, newType.isTalking {
            // Tiny delay for read→talking to let geometry settle
            scheduleDelayedTypeUpdate(to: newType, delay: 0.02)
        } else {
            // Update immediately for other transitions
            displayedType = newType
        }

        // Determine native rendering eligibility and schedule swap if needed
        switch animationState {
        case let .morphing(from, to, _):
            // During morphing, stay on Canvas. If Thinking→Talking, arm a tiny post-morph grace.
            canUseNative = false
            if from.isThinking, to.isTalking {
                let grace: TimeInterval = 0.8
                let delay = config.morphDuration + grace
                nativeSwapTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled else { return }
                    // Only flip if still targeting talking (no conflicting transition)
                    if case let .idle(t) = self.animationState, t.isTalking {
                        self.canUseNative = true
                    } else if case let .morphing(_, toType, _) = self.animationState, toType.isTalking {
                        self.canUseNative = true
                    } else if self.displayedType.isTalking {
                        self.canUseNative = true
                    }
                }
            }
        case .quickAppearing:
            canUseNative = true
        case .exploding, .scaling:
            canUseNative = false
        case let .idle(t):
            canUseNative = t.isTalking
        }

        // Schedule automatic transition to idle state when animation completes
        scheduleAutoTransitionToIdle()
    }

    // MARK: - State Queries

    /// Returns the current animation state, auto-transitioning to idle if complete
    func currentState(at date: Date) -> BubbleAnimationState {
        if animationState.isAnimating, animationState.isComplete(at: date, config: config) {
            animationState = .idle(animationState.targetType)
        }

        return animationState
    }

    /// Returns the morph progress at the given date
    func morphProgress(at date: Date) -> CGFloat {
        animationState.morphProgress(at: date, config: config)
    }

    /// Returns the animation progress within the current phase
    func animationProgress(at date: Date) -> CGFloat {
        animationState.animationProgress(at: date, config: config)
    }

    /// Whether the bubble is currently exploding
    func isExploding(at date: Date) -> Bool {
        if case .exploding = currentState(at: date) {
            return true
        }

        return false
    }

    /// Returns explosion progress (0 to 1)
    func explosionProgress(at date: Date) -> CGFloat {
        if case .exploding = animationState {
            return animationState.animationProgress(at: date, config: config)
        }

        return 0
    }

    /// Whether the bubble is currently scaling up (read→thinking)
    func isScaling(at date: Date) -> Bool {
        if case .scaling = currentState(at: date) {
            return true
        }

        return false
    }

    /// Returns scaling progress (0 to 1)
    func scalingProgress(at date: Date) -> CGFloat {
        if case .scaling = animationState {
            return animationState.animationProgress(at: date, config: config)
        }

        return 0
    }

    /// Whether size animations should be skipped (for read→talking)
    func shouldSkipSizeAnimation(at date: Date) -> Bool {
        if case .quickAppearing = animationState {
            return animationState.animationProgress(at: date, config: config) < 1
        }

        return false
    }

    // MARK: - Private Helpers

    private func scheduleDelayedTypeUpdate(to type: BubbleType, delay: TimeInterval) {
        delayedTypeTask?.cancel()
        delayedTypeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            displayedType = type
        }
    }

    private func scheduleAutoTransitionToIdle() {
        let duration = animationDuration(for: animationState)

        autoTransitionTask?.cancel()
        autoTransitionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }

            // Transition to idle if animation is complete
            if animationState.isAnimating {
                animationState = .idle(animationState.targetType)
            }
        }
    }

    private func animationDuration(for state: BubbleAnimationState) -> TimeInterval {
        switch state {
        case .idle:
            0
        case .morphing:
            config.morphDuration
        case .exploding:
            config.explosionDuration
        case .scaling:
            config.readToThinkingDuration
        case .quickAppearing:
            0.02
        }
    }
}

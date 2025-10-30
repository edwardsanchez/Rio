//
//  BubbleAnimationState.swift
//  Rio
//
//  Created by Edward Sanchez on 10/17/25.
//

import Foundation

/// Represents the current animation phase of a bubble, making transitions explicit
enum BubbleAnimationState: Equatable {
    /// Bubble is stable in a particular type (no active transition)
    case idle(BubbleType)

    /// Animating between thinking and talking modes with metaball morph
    case morphing(from: BubbleType, to: BubbleType, startTime: Date)

    /// Thinking bubble exploding into particles (thinking→read)
    case exploding(startTime: Date)

    /// Bubble scaling up from read state (read→thinking)
    case scaling(startTime: Date)

    /// Quick appearance transition (read→talking)
    case quickAppearing(startTime: Date)

    // MARK: - Computed Properties

    /// The target bubble type this state is transitioning to (or is at)
    var targetType: BubbleType {
        switch self {
        case let .idle(type):
            type
        case let .morphing(_, to, _):
            to
        case .exploding:
            .read
        case .scaling:
            .thinking
        case .quickAppearing:
            .talking
        }
    }

    /// Whether this state represents an active animation
    var isAnimating: Bool {
        switch self {
        case .idle:
            false
        case .morphing, .exploding, .scaling, .quickAppearing:
            true
        }
    }

    /// The morph progress (0 = thinking/read, 1 = talking) for layout calculations
    func morphProgress(at date: Date, config: BubbleConfiguration) -> CGFloat {
        switch self {
        case let .idle(type):
            return type.isTalking ? 1.0 : 0.0

        case let .morphing(from, to, startTime):
            let elapsed = date.timeIntervalSince(startTime)
            let duration = config.morphDuration

            if elapsed <= 0 {
                return from.isTalking ? 1.0 : 0.0
            }

            if elapsed >= duration {
                return to.isTalking ? 1.0 : 0.0
            }

            let fraction = CGFloat(elapsed / duration)
            let eased = easeInOutProgress(fraction)

            let fromValue: CGFloat = from.isTalking ? 1.0 : 0.0
            let toValue: CGFloat = to.isTalking ? 1.0 : 0.0

            return fromValue + (toValue - fromValue) * eased

        case .exploding:
            // Frozen at thinking state (0) during explosion
            return 0.0

        case .scaling:
            // Remains at thinking state (0) during scale-up
            return 0.0

        case .quickAppearing:
            // Jump directly to talking state (1)
            return 1.0
        }
    }

    /// Progress within the current animation phase (0 to 1)
    func animationProgress(at date: Date, config: BubbleConfiguration) -> CGFloat {
        switch self {
        case .idle:
            return 1.0

        case let .morphing(_, _, startTime):
            let elapsed = date.timeIntervalSince(startTime)
            let duration = config.morphDuration
            return min(max(CGFloat(elapsed / duration), 0), 1)

        case let .exploding(startTime):
            let elapsed = date.timeIntervalSince(startTime)
            let duration = config.explosionDuration
            return min(max(CGFloat(elapsed / duration), 0), 1)

        case let .scaling(startTime):
            let elapsed = date.timeIntervalSince(startTime)
            let duration = config.readToThinkingDuration
            return min(max(CGFloat(elapsed / duration), 0), 1)

        case let .quickAppearing(startTime):
            let elapsed = date.timeIntervalSince(startTime)
            let duration: TimeInterval = 0.02
            return min(max(CGFloat(elapsed / duration), 0), 1)
        }
    }

    /// Whether the animation is complete
    func isComplete(at date: Date, config: BubbleConfiguration) -> Bool {
        animationProgress(at: date, config: config) >= 1.0
    }

    // MARK: - Transition Logic

    /// Creates the appropriate animation state for transitioning from one type to another
    static func transition(from oldType: BubbleType, to newType: BubbleType, at date: Date) -> BubbleAnimationState {
        // No transition needed
        guard oldType != newType else {
            return .idle(newType)
        }

        // Thinking → Talking: morph animation
        if oldType.isThinking, newType.isTalking {
            return .morphing(from: oldType, to: newType, startTime: date)
        }

        // Talking → Thinking: morph animation
        if oldType.isTalking, newType.isThinking {
            return .morphing(from: oldType, to: newType, startTime: date)
        }

        // Thinking → Read: explosion animation
        if oldType.isThinking, newType.isRead {
            return .exploding(startTime: date)
        }

        // Read → Thinking: scale-up animation
        if oldType.isRead, newType.isThinking {
            return .scaling(startTime: date)
        }

        // Read → Talking: quick appearance (no morph)
        if oldType.isRead, newType.isTalking {
            return .quickAppearing(startTime: date)
        }

        // Talking → Read: direct transition
        if oldType.isTalking, newType.isRead {
            return .idle(newType)
        }

        // Default: jump to new state
        return .idle(newType)
    }

    // MARK: - Helper Functions

    /// Cosine-based ease-in-out for smooth acceleration/deceleration
    private func easeInOutProgress(_ value: CGFloat) -> CGFloat {
        let clamped = min(max(value, 0), 1)
        return CGFloat(0.5 - 0.5 * cos(Double(clamped) * .pi))
    }
}

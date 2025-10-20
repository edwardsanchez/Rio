//
//  ThinkingTailView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/17/25.
//

import SwiftUI

/// Thinking mode tail - a small circle that scales in during read→thinking transition
struct ThinkingTailView: View {
    let color: Color
    let showTail: Bool
    let bubbleType: BubbleType
    let layoutType: BubbleType?
    let messageType: MessageType
    let scalingProgress: CGFloat
    let isExploding: Bool
    let explosionProgress: CGFloat
    let previousBubbleType: BubbleType?

    @Environment(BubbleConfiguration.self) private var bubbleConfig

    private var tailAlignment: Alignment {
        messageType.isInbound ? .bottomLeading : .bottomTrailing
    }

    var body: some View {
        TimelineView(.animation) { _ in
            // Only apply scaling animation if scalingProgress is actually progressing (> 0 and < 1)
            // This prevents scaling to 0 when a message starts in thinking mode
            let isScaling = scalingProgress > 0 && scalingProgress < 1
            let tailScale = isScaling ? tailCircleScale(progress: scalingProgress) : 1

            // Position offset calculation for tail animation
            let isThinking = bubbleType.isThinking || (bubbleType.isRead && !isExploding) || isExploding

            // Animate position changes only when NOT transitioning from read state
            let shouldAnimateCircle = previousBubbleType != .read

            // Circle should only be visible when in thinking state (or during explosion)
            // Note: The thinking tail is an indicator, not a conversation tail,
            // so it should always show during thinking mode regardless of showTail flag
            let circleOpacity: CGFloat = {
                guard messageType.isInbound else { return 0 }

                // Show tail if we're in thinking state
                if bubbleType.isThinking {
                    return 1
                }

                // Also show during explosion (thinking→read transition)
                // The explosionEffect will handle the actual disappearance animation
                if isExploding {
                    return 1
                }

                // Hide for all other states (talking, read without explosion)
                return 0
            }()

            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .scaleEffect(tailScale, anchor: .center)
                .offset(
                    x: tailAlignment == .bottomLeading ? 4 : -4,
                    y: 21
                )
                .offset(x: 0, y: -13)
                .offset(x: isThinking ? 0 : 5, y: isThinking ? 0 : -13)
                .explosionEffect(isActive: isExploding, progress: explosionProgress)
                .opacity(circleOpacity)
                .animation(shouldAnimateCircle ? .easeIn(duration: 0.2) : nil, value: bubbleType)
        }
    }

    /// Returns the tail circle scale for the read→thinking animation
    private func tailCircleScale(progress: CGFloat) -> CGFloat {
        // Tail animates from 0 to 0.2 of total timeline (0.2s out of 0.8s)
        let tailProgress = min(max(progress / 0.25, 0), 1) // 0.25 = 0.2s / 0.8s
        return tailProgress
    }
}

//
//  TailViewContainer.swift
//  Rio
//
//  Created by Edward Sanchez on 10/17/25.
//

import SwiftUI

/// Container that manages both thinking and talking tail views
struct TailViewContainer: View {
    let color: Color
    let showTail: Bool
    let bubbleType: BubbleType
    let layoutType: BubbleType?
    let messageType: MessageType
    let scalingProgress: CGFloat
    let isExploding: Bool
    let explosionProgress: CGFloat
    let tailPositionOffset: CGPoint
    let previousBubbleType: BubbleType?
    
    private var tailAlignment: Alignment {
        messageType.isInbound ? .bottomLeading : .bottomTrailing
    }
    
    var body: some View {
        ZStack(alignment: tailAlignment) {
            // Talking tail - pure state-based (no TimelineView)
            TalkingTailView(
                color: color,
                showTail: showTail,
                bubbleType: bubbleType,
                layoutType: layoutType,
                messageType: messageType,
                tailPositionOffset: tailPositionOffset,
                previousBubbleType: previousBubbleType
            )
            
            // Thinking tail - time-based (with TimelineView)
            ThinkingTailView(
                color: color,
                showTail: showTail,
                bubbleType: bubbleType,
                layoutType: layoutType,
                messageType: messageType,
                scalingProgress: scalingProgress,
                isExploding: isExploding,
                explosionProgress: explosionProgress,
                previousBubbleType: previousBubbleType
            )
        }
    }
}


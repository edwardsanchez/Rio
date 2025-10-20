//
//  TalkingTailView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/17/25.
//

import SwiftUI

/// Talking mode tail - a cartouche shape that animates position
struct TalkingTailView: View {
    let color: Color
    let showTail: Bool
    let bubbleType: BubbleType
    let layoutType: BubbleType?
    let messageType: MessageType
    let tailPositionOffset: CGPoint
    let previousBubbleType: BubbleType?
    
    private var tailAlignment: Alignment {
        messageType.isInbound ? .bottomLeading : .bottomTrailing
    }
    
    private var tailOffset: CGPoint {
        messageType.isInbound ? CGPoint(x: 5.5, y: 10.5) : CGPoint(x: -5.5, y: 10.5)
    }
    
    private var tailRotation: Angle {
        messageType.isInbound ? Angle(degrees: 180) : .zero
    }
    
    var body: some View {
        let effectiveType = layoutType ?? bubbleType
        let isInbound = messageType.isInbound
        
        // Apply direction-specific offset based on message type
        let directionAdjustedOffset = CGPoint(
            x: isInbound ? tailPositionOffset.x : -tailPositionOffset.x,
            y: tailPositionOffset.y
        )
        
        // Determine if we should animate (not from read state)
        let shouldAnimate = previousBubbleType != .read
        
        let targetOpacity: CGFloat = showTail && effectiveType.isTalking ? 1 : 0
        
        return Image(.cartouche)
            .resizable()
            .frame(width: 15, height: 15)
            .rotation3DEffect(tailRotation, axis: (x: 0, y: 1, z: 0))
            .offset(x: tailOffset.x, y: tailOffset.y)
            .offset(x: directionAdjustedOffset.x, y: directionAdjustedOffset.y)
            .foregroundStyle(color)
            .opacity(targetOpacity)
            .animation(shouldAnimate ? .spring(duration: 0.3).delay(0.2) : nil, value: tailPositionOffset)
    }
}

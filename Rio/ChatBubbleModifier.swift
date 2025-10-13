//
//  ChatBubbleModifier.swift
//  Rio
//
//  Created by Edward Sanchez on 10/7/25.
//
import SwiftUI

private struct ChatBubbleModifier: ViewModifier {
    let messageType: MessageType
    let backgroundColor: Color
    let showTail: Bool
    let bubbleMode: BubbleMode
    let animationWidth: CGFloat?
    let animationHeight: CGFloat?

    @State private var contentSize: CGSize = .zero

    private var backgroundOpacity: Double {
        messageType == .inbound ? 0.6 : 1.0
    }

    private var measuredWidth: CGFloat {
        max(contentSize.width, animationWidth ?? 0, 12)
    }

    private var measuredHeight: CGFloat {
        max(contentSize.height, animationHeight ?? 0, 12)
    }

    let bubbleCornerRadius: CGFloat = 20
    let bubbleMinDiameter: CGFloat = 13
    let bubbleMaxDiameter: CGFloat = 23
    let bubbleBlurRadius: CGFloat = 2
    
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 10)
            .padding(.horizontal, bubbleMode == .thinking ? 17 : 13)
            .background(alignment: .leading) {
                BubbleView(
                    width: measuredWidth,
                    height: bubbleMode == .thinking ? measuredHeight + 15 : measuredHeight,
                    cornerRadius: bubbleCornerRadius,
                    minDiameter: bubbleMinDiameter,
                    maxDiameter: bubbleMaxDiameter,
                    blurRadius: bubbleBlurRadius,
                    color: backgroundColor,
                    mode: bubbleMode,
                    showTail: showTail,
                    messageType: messageType
                )
                .compositingGroup()
                .opacity(backgroundOpacity)
            }
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                contentSize = newSize
            }
    }
}

extension View {
    func chatBubble(
        messageType: MessageType,
        backgroundColor: Color,
        showTail: Bool,
        bubbleMode: BubbleMode = .talking,
        animationWidth: CGFloat? = nil,
        animationHeight: CGFloat? = nil
    ) -> some View {
        modifier(
            ChatBubbleModifier(
                messageType: messageType,
                backgroundColor: backgroundColor,
                showTail: showTail,
                bubbleMode: bubbleMode,
                animationWidth: animationWidth,
                animationHeight: animationHeight
            )
        )
    }
}

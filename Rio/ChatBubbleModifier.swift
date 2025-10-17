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
    let isExploding: Bool

    @State private var contentSize: CGSize = .zero
    @Environment(BubbleConfiguration.self) private var bubbleConfig

    private var backgroundOpacity: Double {
        bubbleConfig.backgroundOpacity(for: messageType)
    }

    private var measuredWidth: CGFloat {
        max(contentSize.width, animationWidth ?? 0, 12)
    }

    private var measuredHeight: CGFloat {
        max(contentSize.height, animationHeight ?? 0, 12)
    }

    // During explosion, keep bubble in thinking mode layout
    // After explosion, allow transition to read mode
    private var effectiveMode: BubbleMode {
        bubbleConfig.effectiveMode(bubbleMode: bubbleMode, isExploding: isExploding)
    }

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 10)
            .padding(.horizontal, effectiveMode == .thinking ? 17 : 13)
            .background(alignment: .leading) {
                BubbleView(
                    width: effectiveMode == .thinking ? 80 : measuredWidth,
                    height: effectiveMode == .thinking ? measuredHeight + 15 : measuredHeight,
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
        animationHeight: CGFloat? = nil,
        isExploding: Bool = false
    ) -> some View {
        modifier(
            ChatBubbleModifier(
                messageType: messageType,
                backgroundColor: backgroundColor,
                showTail: showTail,
                bubbleMode: bubbleMode,
                animationWidth: animationWidth,
                animationHeight: animationHeight,
                isExploding: isExploding
            )
        )
    }
}

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
    let bubbleType: BubbleType
    let layoutType: BubbleType
    let animationWidth: CGFloat?
    let animationHeight: CGFloat?

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

    func body(content: Content) -> some View {
        content
            .padding(.vertical, 10)
            .padding(.horizontal, layoutType == .thinking ? 17 : 13)
            .background(alignment: .leading) {
                BubbleView(
                    width: layoutType == .thinking ? 80 : measuredWidth,
                    height: layoutType == .thinking ? measuredHeight + 15 : measuredHeight,
                    color: backgroundColor,
                    type: bubbleType,
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
        bubbleType: BubbleType = .talking,
        layoutType: BubbleType? = nil,
        animationWidth: CGFloat? = nil,
        animationHeight: CGFloat? = nil
    ) -> some View {
        modifier(
            ChatBubbleModifier(
                messageType: messageType,
                backgroundColor: backgroundColor,
                showTail: showTail,
                bubbleType: bubbleType,
                layoutType: layoutType ?? bubbleType,
                animationWidth: animationWidth,
                animationHeight: animationHeight
            )
        )
    }
}

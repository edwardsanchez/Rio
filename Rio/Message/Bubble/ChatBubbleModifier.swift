//
//  ChatBubbleModifier.swift
//  Rio
//
//  Created by Edward Sanchez on 10/7/25.
//
import SwiftUI

private struct ChatBubbleModifier: ViewModifier {
    let messageContext: MessageBubbleContext
    let animationWidth: CGFloat?
    let animationHeight: CGFloat?
    let isVisible: Bool

    @State private var contentSize: CGSize = .zero
    @Environment(BubbleConfiguration.self) private var bubbleConfig

    private var measuredWidth: CGFloat {
        max(contentSize.width, animationWidth ?? 0, 12)
    }

    private var measuredHeight: CGFloat {
        max(contentSize.height, animationHeight ?? 0, 12)
    }

    func body(content: Content) -> some View {
        // For read→talking transition: use bubbleType for sizing (immediate) to avoid animation
        // For other transitions: use layoutType for sizing (delayed for proper morphing)
        // This works because read→talking has displayedType delayed, but we want size immediate
        let bubbleType = messageContext.bubbleType
        let layoutType = messageContext.resolvedLayoutType
        let isReadToTalking = layoutType == .read && bubbleType == .talking
        let sizingType = isReadToTalking ? bubbleType : layoutType

        content
            .padding(.vertical, 10)
            .padding(.horizontal, layoutType == .thinking ? 17 : 13)
            .background(alignment: .leading) {
                bubbleBackground(for: sizingType)
            }
            .animation(.smooth) { content in
                content
                    .opacity(contentSize == .zero ? 0 : 1)
            }
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                contentSize = newSize
            }
    }

    @ViewBuilder
    private func bubbleBackground(for sizingType: BubbleType) -> some View {
        if isVisible {
            BubbleView(
                width: sizingType == .thinking ? 80 : measuredWidth,
                height: sizingType == .thinking ? measuredHeight + 15 : measuredHeight,
                messageContext: messageContext
            )
            .compositingGroup()
        } else {
            EmptyView()
        }
    }
}

extension View {
    func chatBubble(
        messageContext: MessageBubbleContext,
        animationWidth: CGFloat? = nil,
        animationHeight: CGFloat? = nil,
        isVisible: Bool = true
    ) -> some View {
        modifier(
            ChatBubbleModifier(
                messageContext: messageContext,
                animationWidth: animationWidth,
                animationHeight: animationHeight,
                isVisible: isVisible
            )
        )
    }
}

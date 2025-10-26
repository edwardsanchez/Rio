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
    let isVisible: Bool
    let messageID: UUID
    let context: ReactingMessageContext
    let isReactionsOverlay: Bool
    let namespace: Namespace.ID?
    let activeReactionMessageID: UUID?

    @State private var contentSize: CGSize = .zero
    @Environment(BubbleConfiguration.self) private var bubbleConfig

    private var measuredWidth: CGFloat {
        max(contentSize.width, animationWidth ?? 0, 12)
    }

    private var measuredHeight: CGFloat {
        max(contentSize.height, animationHeight ?? 0, 12)
    }

    private var shouldShowBubble: Bool {
        guard isVisible else { return false }
        guard let activeID = activeReactionMessageID else {
            return !isReactionsOverlay
        }
        if isReactionsOverlay {
            return activeID == messageID
        } else {
            return activeID != messageID
        }
    }

    func body(content: Content) -> some View {
        // For read→talking transition: use bubbleType for sizing (immediate) to avoid animation
        // For other transitions: use layoutType for sizing (delayed for proper morphing)
        // This works because read→talking has displayedType delayed, but we want size immediate
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
            let baseBubble = BubbleView(
                width: sizingType == .thinking ? 80 : measuredWidth,
                height: sizingType == .thinking ? measuredHeight + 15 : measuredHeight,
                color: backgroundColor,
                type: bubbleType,
                showTail: showTail,
                messageType: messageType,
                layoutType: layoutType,
                messageID: messageID,
                context: context,
                isReactionsOverlay: isReactionsOverlay
            )
            .compositingGroup()

            let styledBubble = baseBubble
                .opacity(shouldShowBubble ? 1 : 0)
                .allowsHitTesting(shouldShowBubble)

            if let namespace {
                styledBubble
                    .matchedGeometryEffect(
                        id: "bubble-\(messageID)",
                        in: namespace,
                        properties: .frame,
                        anchor: .center,
                        isSource: !isReactionsOverlay
                    )
            } else {
                styledBubble
            }
        } else {
            EmptyView()
        }
    }
}

extension View {
    func chatBubble(
        messageType: MessageType,
        backgroundColor: Color,
        showTail: Bool,
        messageID: UUID,
        context: ReactingMessageContext,
        isReactionsOverlay: Bool = false,
        namespace: Namespace.ID? = nil,
        activeReactionMessageID: UUID? = nil,
        bubbleType: BubbleType = .talking,
        layoutType: BubbleType? = nil,
        animationWidth: CGFloat? = nil,
        animationHeight: CGFloat? = nil,
        isVisible: Bool = true
    ) -> some View {
        modifier(
            ChatBubbleModifier(
                messageType: messageType,
                backgroundColor: backgroundColor,
                showTail: showTail,
                bubbleType: bubbleType,
                layoutType: layoutType ?? bubbleType,
                animationWidth: animationWidth,
                animationHeight: animationHeight,
                isVisible: isVisible,
                messageID: messageID,
                context: context,
                isReactionsOverlay: isReactionsOverlay,
                namespace: namespace,
                activeReactionMessageID: activeReactionMessageID
            )
        )
    }
}

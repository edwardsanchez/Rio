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
        let verticalPadding: CGFloat = 10
        let leadingPadding: CGFloat = bubbleMode == .thinking ? 19 : 16 //FIXME: This is odd as a requirement
        let trailingPadding: CGFloat = bubbleMode == .thinking ? 7 : 16 //FIXME: This should not be required

        return content
            .padding(.vertical, verticalPadding)
            .padding(.leading, leadingPadding)
            .padding(.trailing, trailingPadding)
            .background(alignment: .leading) {
                BubbleView(
                    width: measuredWidth,
                    height: measuredHeight,
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
            .offset(x: bubbleMode == .thinking ? -8 : 0)
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

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

    // Computed properties derived from messageType
    private var tailAlignment: Alignment {
        messageType == .inbound ? .bottomLeading : .bottomTrailing
    }

    private var tailOffset: CGSize {
        messageType == .inbound ? CGSize(width: 5, height: 5.5) : CGSize(width: -5, height: 5.5)
    }

    private var tailRotation: Angle {
        messageType == .inbound ? Angle(degrees: 180) : .zero
    }

    private var backgroundOpacity: Double {
        messageType == .inbound ? 0.6 : 1.0
    }

    private var measuredWidth: CGFloat {
        max(contentSize.width, animationWidth ?? 0, 12)
    }

    private var measuredHeight: CGFloat {
        max(contentSize.height, animationHeight ?? 0, 12)
    }

    private var bubbleWidth: CGFloat { measuredWidth }
    private var bubbleHeight: CGFloat { measuredHeight }

    private var bubbleCornerRadius: CGFloat { 20 }
    private var bubbleMinDiameter: CGFloat { 13 }
    private var bubbleMaxDiameter: CGFloat { 23 }
    private var bubbleBlurRadius: CGFloat { 4 }

    func body(content: Content) -> some View {
        content
            .padding()
            .background(alignment: .leading) {
                bubbleBackground
            }
            .offset(y: bubbleMode == .thinking ? -5 : 0)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                contentSize = newSize
            }
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        let width = bubbleWidth
        let height = bubbleHeight

        if width > 0 && height > 0 {
            BubbleView(
                width: width,
                height: height,
                cornerRadius: bubbleCornerRadius,
                minDiameter: bubbleMinDiameter,
                maxDiameter: bubbleMaxDiameter,
                blurRadius: bubbleBlurRadius,
                color: backgroundColor,
                mode: bubbleMode
            )
            .overlay(alignment: tailAlignment) {
                tailView
            }
            .compositingGroup()
            .opacity(backgroundOpacity)
        } else {
            RoundedRectangle(cornerRadius: bubbleCornerRadius)
                .fill(backgroundColor)
                .frame(width: animationWidth, height: animationHeight)
                .overlay(alignment: tailAlignment) {
                    tailView
                }
                .compositingGroup()
                .opacity(backgroundOpacity)
        }
    }

    @ViewBuilder
    private var tailView: some View {
        switch bubbleMode {
        case .talking:
            Image(.cartouche)
                .resizable()
                .frame(width: 15, height: 15)
                .rotation3DEffect(tailRotation, axis: (x: 0, y: 1, z: 0))
                .offset(x: tailOffset.width, y: tailOffset.height)
                .foregroundStyle(backgroundColor)
                .opacity(showTail ? 1 : 0)

        case .thinking:
            // Thinking bubble tail with two circles
            ZStack(alignment: tailAlignment == .bottomLeading ? .bottomLeading : .bottomTrailing) {
                // Larger circle (closer to bubble)
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 14, height: 14)
                    .offset(
                        x: tailAlignment == .bottomLeading ? 3 : -12,
                        y: 14
                    )

                // Smaller circle (further from bubble)
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 8, height: 8)
                    .offset(
                        x: tailAlignment == .bottomLeading ? -2 : 1,
                        y: 21
                    )
            }
            .opacity(showTail ? 1 : 0)
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

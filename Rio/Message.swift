//
//  Message.swift
//  Rio
//
//  Created by Edward Sanchez on 9/20/25.
//

import SwiftUI

struct Message: Identifiable {
    let id: UUID
    let text: String
    let isInbound: Bool

    init(id: UUID = UUID(), text: String, isInbound: Bool) {
        self.id = id
        self.text = text
        self.isInbound = isInbound
    }
}

struct MessageBubble: View {
    let text: String
    let isInbound: Bool

    init(text: String, isInbound: Bool) {
        self.text = text
        self.isInbound = isInbound
    }

    init(message: Message) {
        self.init(text: message.text, isInbound: message.isInbound)
    }

    var body: some View {
        HStack(alignment: .bottom) {
            if isInbound {
                inboundAvatar
                bubbleView(
                    textColor: .primary,
                    backgroundColor: .userBubble,
                    tailAlignment: .bottomLeading,
                    tailOffset: CGSize(width: 5, height: 5.5),
                    tailRotation: Angle(degrees: 180),
                    backgroundOpacity: 0.6,
                    usesCompositing: true
                )
                Spacer()
            } else {
                Spacer()
                bubbleView(
                    textColor: .white,
                    backgroundColor: .ownBubble,
                    tailAlignment: .bottomTrailing,
                    tailOffset: CGSize(width: -5, height: 5.5),
                    tailRotation: .zero
                )
            }
        }
    }

    private var inboundAvatar: some View {
        Image(.usersample)
            .resizable()
            .frame(width: 40, height: 40)
            .clipShape(.circle)
            .offset(y: 10)
    }

    @ViewBuilder
    private func bubbleView(
        textColor: Color,
        backgroundColor: Color,
        tailAlignment: Alignment,
        tailOffset: CGSize,
        tailRotation: Angle,
        backgroundOpacity: Double? = nil,
        usesCompositing: Bool = false
    ) -> some View {
        Text(text)
            .foregroundStyle(textColor)
            .chatBubble(
                backgroundColor: backgroundColor,
                tailAlignment: tailAlignment,
                tailOffset: tailOffset,
                tailRotation: tailRotation,
                backgroundOpacity: backgroundOpacity,
                usesCompositing: usesCompositing
            )
    }
}

private struct ChatBubbleModifier: ViewModifier {
    let backgroundColor: Color
    let tailAlignment: Alignment
    let tailOffset: CGSize
    let tailRotation: Angle
    let backgroundOpacity: Double?
    let usesCompositing: Bool

    func body(content: Content) -> some View {
        content
            .padding()
            .background {
                backgroundView
            }
    }

    @ViewBuilder
    private var backgroundView: some View {
        let base = RoundedRectangle(cornerRadius: 20)
            .fill(backgroundColor)
            .overlay(alignment: tailAlignment) {
                Image(.cartouche)
                    .resizable()
                    .frame(width: 15, height: 15)
                    .rotation3DEffect(tailRotation, axis: (x: 0, y: 1, z: 0))
                    .offset(x: tailOffset.width, y: tailOffset.height)
                    .foregroundStyle(backgroundColor)
            }

        if usesCompositing && backgroundOpacity != nil {
            base
                .compositingGroup()
                .opacity(backgroundOpacity!)
        } else if usesCompositing {
            base.compositingGroup()
        } else if let opacity = backgroundOpacity {
            base.opacity(opacity)
        } else {
            base
        }
    }
}

private extension View {
    func chatBubble(
        backgroundColor: Color,
        tailAlignment: Alignment,
        tailOffset: CGSize,
        tailRotation: Angle,
        backgroundOpacity: Double? = nil,
        usesCompositing: Bool = false
    ) -> some View {
        modifier(
            ChatBubbleModifier(
                backgroundColor: backgroundColor,
                tailAlignment: tailAlignment,
                tailOffset: tailOffset,
                tailRotation: tailRotation,
                backgroundOpacity: backgroundOpacity,
                usesCompositing: usesCompositing
            )
        )
    }
}

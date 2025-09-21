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
    let avatar: ImageResource?
    let date: Date
    let showTail: Bool
    
    var hasCartouche: Bool {
        isInbound || avatar != nil
    }
    
    init(id: UUID = UUID(), text: String, isInbound: Bool, avatar: ImageResource? = nil, showTail: Bool = true) {
        self.id = id
        self.text = text
        self.isInbound = isInbound
        self.avatar = isInbound ? avatar : nil
        self.date = Date.now
        self.showTail = showTail
    }
}

struct MessageBubble: View {
    let text: String
    let isInbound: Bool
    let avatar: ImageResource?
    let showTail: Bool
    
    private init(text: String, isInbound: Bool, avatar: ImageResource? = nil, showTail: Bool) {
        self.text = text
        self.isInbound = isInbound
        self.avatar = isInbound ? avatar : nil
        self.showTail = showTail
    }
    
    init(message: Message) {
        self.init(text: message.text, isInbound: message.isInbound, avatar: message.avatar, showTail: message.showTail)
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if isInbound {
                inboundAvatar
                bubbleView(
                    textColor: .primary,
                    backgroundColor: .userBubble,
                    tailAlignment: .bottomLeading,
                    tailOffset: CGSize(width: 5, height: 5.5),
                    tailRotation: Angle(degrees: 180),
                    showTail: showTail,
                    backgroundOpacity: 0.6,
                )
                Spacer()
            } else {
                Spacer()
                bubbleView(
                    textColor: .white,
                    backgroundColor: .ownBubble,
                    tailAlignment: .bottomTrailing,
                    tailOffset: CGSize(width: -5, height: 5.5),
                    tailRotation: .zero,
                    showTail: showTail,
                    backgroundOpacity: 1,
                )
            }
        }
    }
    
    private var inboundAvatar: some View {
        Group {
            if let avatar {
                Image(avatar)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .clipShape(.circle)
                    .offset(y: 10)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 40, height: 40)
            }
        }
    }
    
    @ViewBuilder
    private func bubbleView(
        textColor: Color,
        backgroundColor: Color,
        tailAlignment: Alignment,
        tailOffset: CGSize,
        tailRotation: Angle,
        showTail: Bool,
        backgroundOpacity: Double
    ) -> some View {
        Text(text)
            .foregroundStyle(textColor)
            .chatBubble(
                backgroundColor: backgroundColor,
                tailAlignment: tailAlignment,
                tailOffset: tailOffset,
                tailRotation: tailRotation,
                showTail: showTail,
                backgroundOpacity: backgroundOpacity
            )
    }
}

private struct ChatBubbleModifier: ViewModifier {
    let backgroundColor: Color
    let tailAlignment: Alignment
    let tailOffset: CGSize
    let tailRotation: Angle
    let showTail: Bool
    let backgroundOpacity: Double
    
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
                    .opacity(showTail ? 1 : 0)
            }
        
        base
            .compositingGroup()
            .opacity(backgroundOpacity)
    }
}

private extension View {
    func chatBubble(
        backgroundColor: Color,
        tailAlignment: Alignment,
        tailOffset: CGSize,
        tailRotation: Angle,
        showTail: Bool,
        backgroundOpacity: Double
    ) -> some View {
        modifier(
            ChatBubbleModifier(
                backgroundColor: backgroundColor,
                tailAlignment: tailAlignment,
                tailOffset: tailOffset,
                tailRotation: tailRotation,
                showTail: showTail,
                backgroundOpacity: backgroundOpacity
            )
        )
    }
}

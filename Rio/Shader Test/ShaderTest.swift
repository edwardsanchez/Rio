//
//  ShaderTest.swift
//  Rio
//
//  Created by Edward Sanchez on 10/15/25.
//

import SwiftUI

struct ShaderTestView: View {
    @State private var message: Message
    @State private var showTail: Bool = true
    @State private var showTypingIndicatorContent = true
    @State private var showTalkingContent = false
    @State private var includeTalkingTextInLayout = false
    @State private var thinkingContentWidth: CGFloat = 0
    @State private var isWidthLocked = false
    @State private var isPixelated = false
    
    private let outboundAnimationWidth: CGFloat? = nil
    private let outboundAnimationHeight: CGFloat? = nil
    
    init(message: Message? = nil, showTail: Bool = true) {
        let defaultMessage = Message(
            text: "",
            user: User(id: UUID(), name: "Maya", avatar: .scarlet),
            isTypingIndicator: true,
            bubbleMode: .thinking
        )
        self._message = State(initialValue: message ?? defaultMessage)
        self._showTail = State(initialValue: showTail)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            bubbleView(
                textColor: .white,
                backgroundColor: .gray
            )
            .layerEffect(
                ShaderLibrary.pixelate(.float(isPixelated ? 2.0 : 0.1)),
                maxSampleOffset: .zero
            )
            
            HStack(spacing: 16) {
                Button("Pixelate") {
                    isPixelated = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Reset") {
                    isPixelated = false
                }
                .buttonStyle(.bordered)
            }
        }
    }
    
    @ViewBuilder
    private func bubbleView(
        textColor: Color,
        backgroundColor: Color
    ) -> some View {
        
        let hasText = !message.text.isEmpty
        
        ZStack(alignment: .leading) {
            Text("H") //Measure Spacer
                .opacity(0)
            
            if hasText && includeTalkingTextInLayout {
                Text(message.text)
                    .foregroundStyle(textColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(showTalkingContent ? 1 : 0)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showTypingIndicatorContent)
        .animation(.easeInOut(duration: 0.35), value: showTalkingContent)
        .frame(width: lockedWidth, alignment: .leading)
        .chatBubble(
            messageType: message.messageType,
            backgroundColor: backgroundColor,
            showTail: showTail,
            bubbleMode: message.bubbleMode,
            animationWidth: outboundAnimationWidth,
            animationHeight: outboundAnimationHeight
        )
        .overlay(alignment: .leading) {
            TypingIndicatorView(isVisible: showTypingIndicatorContent)
                .padding(.leading, 20)
        }
    }
    
    private var lockedWidth: CGFloat? {
        guard isWidthLocked, thinkingContentWidth > 0 else { return nil }
        return thinkingContentWidth
    }
}

#Preview("Shader Test") {
    ShaderTestView(
        message: Message(
            text: "",
            user: User(id: UUID(), name: "Maya", avatar: .scarlet),
            isTypingIndicator: true,
            bubbleMode: .thinking
        ),
        showTail: true
    )
    .padding()
}

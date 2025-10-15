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
    @State private var animatedPixelSize: CGFloat = 0.1
    @State private var sliderValue: Double = 0.0
    @State private var bubbleSize: CGSize = .zero
    
    private let outboundAnimationWidth: CGFloat? = nil
    private let outboundAnimationHeight: CGFloat? = nil
    
    // Controllable parameters
    private let maxExplosionSpread: CGFloat = 1.0  // How much spacing increases between particles
    
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
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                bubbleSize = newSize
            }
            .layerEffect(
                ShaderLibrary.pixelate(
                    .float(currentPixelSize),
                    .float2(bubbleSize),
                    .float(currentExplosionAmount)
                ),
                maxSampleOffset: CGSize(
                    width: bubbleSize.width * currentExplosionAmount,
                    height: bubbleSize.height * currentExplosionAmount
                )
            )
            .scaleEffect(2)
            .padding(.bottom, 60)
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Button("Explode") {
                        withAnimation(.easeInOut(duration: 1.05)) {
                            sliderValue = 1.0
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Reset") {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            sliderValue = 0.0
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                VStack(spacing: 8) {
                    Text("Animation: \(String(format: "%.2f", sliderValue))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Slider(value: $sliderValue, in: 0...1)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // Computed values based on slider position
    private var currentPixelSize: CGFloat {
        // 0.0 - 0.05: transition from 0.1 to 2.0 (pixelate + form circles)
        let circleFormationEnd: Double = 0.05
        if sliderValue <= circleFormationEnd {
            let progress = sliderValue / circleFormationEnd
            return 0.1 + (progress * 1.9)
        }
        // After circle formation: stay at 2.0 (don't scale particles)
        return 2.0
    }
    
    private var currentExplosionAmount: CGFloat {
        let circleFormationEnd: Double = 0.05
        // 0.0 - 0.05: no explosion (forming circles)
        if sliderValue <= circleFormationEnd {
            return 0.0
        }
        // 0.05 - 1.0: particles space out from center
        let explosionProgress = (sliderValue - circleFormationEnd) / (1.0 - circleFormationEnd)
        return CGFloat(explosionProgress) * maxExplosionSpread
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

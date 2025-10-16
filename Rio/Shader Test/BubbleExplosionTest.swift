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
    @State private var explosionCenterX: CGFloat = 0.88  // 0.0 = left, 1.0 = right
    @State private var explosionCenterY: CGFloat = 0.57  // 0.0 = top, 1.0 = bottom
    @State private var speedVariance: CGFloat = 0.5  // 0.0 = uniform speed, 1.0 = max variance
    @State private var gravity: CGFloat = 1.0  // 0.0 = no gravity, 1.0 = max gravity
    @State private var turbulence: CGFloat = 0.2  // 0.0 = no turbulence, 1.0 = max turbulence
    @State private var growth: CGFloat = 0.65  // 0.0 = no growth, 1.0 = double size
    @State private var growthVariance: CGFloat = 0.65  // 0.0 = uniform growth, 1.0 = max variance
    @State private var edgeVelocityBoost: CGFloat = 0.8  // 0.0 = uniform velocity, 1.0 = strong edge boost
    @State private var forceSquarePixels: Bool = false
    @State private var fadeStart: CGFloat = 0.3  // When particles start fading (0-1)
    @State private var fadeVariance: CGFloat = 0.85  // Variance in fade timing (0-1)
    
    private let outboundAnimationWidth: CGFloat? = nil
    private let outboundAnimationHeight: CGFloat? = nil
    
    // Controllable parameters
    private let maxExplosionSpread: CGFloat = 0.4  // How much spacing increases between particles
    private let pinchDuration: CGFloat = 0.05  // Duration of the initial pinch effect (as % of animation, 0.05 = 5%)
    
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
                ShaderLibrary.explode(
                    .float(2.0), // Fixed pixel size
                    .float2(bubbleSize),
                    .float(sliderValue), // Pass raw value, calculate everything in shader
                    .float2(explosionCenterX, explosionCenterY),
                    .float(speedVariance),
                    .float(gravity),
                    .float(turbulence),
                    .float(growth),
                    .float(growthVariance),
                    .float(edgeVelocityBoost),
                    .float(forceSquarePixels ? 1.0 : 0.0),
                    .float(maxExplosionSpread), // Pass the constant
                    .float(fadeStart),
                    .float(fadeVariance),
                    .float(pinchDuration)
                ),
                maxSampleOffset: maxSampleOffsetSize
            )
            .scaleEffect(2)
            .padding(.bottom, 60)
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Button("Explode") {
                        withAnimation(.smooth(duration: 0.5)) {
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
                
//                VStack(spacing: 8) {
//                    Text("Center X: \(String(format: "%.2f", explosionCenterX))")
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                    
//                    Slider(value: $explosionCenterX, in: 0...1)
//                }
//                .padding(.horizontal)
//                
//                VStack(spacing: 8) {
//                    Text("Center Y: \(String(format: "%.2f", explosionCenterY))")
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                    
//                    Slider(value: $explosionCenterY, in: 0...1)
//                }
//                .padding(.horizontal)
                
                VStack(spacing: 8) {
                    Text("Speed Variance: \(String(format: "%.2f", speedVariance))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Slider(value: $speedVariance, in: 0...1)
                }
                .padding(.horizontal)
                
//                VStack(spacing: 8) {
//                    Text("Gravity: \(String(format: "%.2f", gravity))")
//                        .font(.caption)
//                        .foregroundStyle(.secondary)
//                    
//                    Slider(value: $gravity, in: 0...1)
//                }
//                .padding(.horizontal)
                
                VStack(spacing: 8) {
                    Text("Turbulence: \(String(format: "%.2f", turbulence))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Slider(value: $turbulence, in: 0...1)
                }
                .padding(.horizontal)
                
                VStack(spacing: 8) {
                    Text("Growth: \(String(format: "%.2f", growth))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Slider(value: $growth, in: 0...1)
                }
                .padding(.horizontal)
                
                VStack(spacing: 8) {
                    Text("Growth Variance: \(String(format: "%.2f", growthVariance))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Slider(value: $growthVariance, in: 0...1)
                }
                .padding(.horizontal)
                
                VStack(spacing: 8) {
                    Text("Edge Velocity Boost: \(String(format: "%.2f", edgeVelocityBoost))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Slider(value: $edgeVelocityBoost, in: 0...1)
                }
                .padding(.horizontal)
                
                Toggle("Force Square Pixels", isOn: $forceSquarePixels)
                    .padding(.horizontal)
                    .padding(.top, 4)
                
                VStack(spacing: 8) {
                    Text("Fade Start: \(String(format: "%.2f", fadeStart))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Slider(value: $fadeStart, in: 0...1)
                }
                .padding(.horizontal)
                
                VStack(spacing: 8) {
                    Text("Fade Variance: \(String(format: "%.2f", fadeVariance))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Slider(value: $fadeVariance, in: 0...1)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // Computed values based on slider position
    private var quantizedSliderValue: CGFloat {
        // Quantize to 1000 discrete steps to eliminate micro-variations during animation
        // This makes animated behavior match manual slider behavior
        let steps: CGFloat = 1000
        let quantized = round(sliderValue * steps) / steps

        // Debug logging
        if abs(sliderValue - quantized) > 0.0001 {
            print("Quantizing: \(sliderValue) -> \(quantized)")
        }

        return quantized
    }

    private var currentPixelSize: CGFloat {
        // 0.0 - 0.05: transition from 0.1 to 2.0 (pixelate + form circles)
        let circleFormationEnd: Double = 0.05
        if quantizedSliderValue <= circleFormationEnd {
            let progress = quantizedSliderValue / circleFormationEnd
            return 0.1 + (progress * 1.9)
        }
        // After circle formation: stay at 2.0 (don't scale particles)
        return 2.0
    }

    private var currentExplosionAmount: CGFloat {
        let circleFormationEnd: Double = 0.05
        // 0.0 - 0.05: no explosion (forming circles)
        if quantizedSliderValue <= circleFormationEnd {
            return 0.0
        }
        // 0.05 - 1.0: particles space out from center
        let explosionProgress = (quantizedSliderValue - circleFormationEnd) / (1.0 - circleFormationEnd)
        return CGFloat(explosionProgress) * maxExplosionSpread
    }
    
    private var maxSampleOffsetSize: CGSize {
        let maxDimension = max(bubbleSize.width, bubbleSize.height)
        let baseOffset = maxDimension * currentExplosionAmount
        let speedFactor = 1.0 + speedVariance
        let turbulenceFactor = 1.0 + turbulence
        let growthFactor = 1.0 + growth * (1.0 + growthVariance)
        let edgeFactor = 1.0 + edgeVelocityBoost * 1.5
        
        let widthOffset = baseOffset * speedFactor * 2.0 * turbulenceFactor * growthFactor * edgeFactor
        let heightOffset = baseOffset * speedFactor * 2.5 * turbulenceFactor * growthFactor * edgeFactor
        
        return CGSize(width: widthOffset, height: heightOffset)
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

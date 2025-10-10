//
//  TypingIndicatorView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/7/25.
//

import SwiftUI

// MARK: - Typing Indicator View

struct TypingIndicatorView: View {
    var isVisible: Bool
    @State private var isAnimating = false
    @State private var shown = true

    var body: some View {
        Group {
            if shown {
                HStack(spacing: 5) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.primary.opacity(0.4))
                            .frame(width: 10, height: 10)
                            .scaleEffect(isAnimating ? 1.0 : 0.5)
                            .opacity(isAnimating ? 1 : 0.5)
                            .animation(
                                .easeInOut(duration: 0.8)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.3),
                                value: isAnimating
                            )
                            .scaleEffect(isVisible ? 1 : 0)
                            .opacity(isVisible ? 1 : 0)
                            .animation(.easeIn(duration: 0.05).delay(CGFloat(index - 1) * 0.1), value: isVisible)
                    }
                }
            }
        }
        .frame(height: 20) //TODO: This should vary based on font size
        .onAppear {
            isAnimating = true
        }
        .onChange(of: isVisible) { oldValue, newValue in
            if oldValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    shown = newValue
                }
            }
        }
    }
}

#Preview("TypingIndicatorView") {
    TypingIndicatorView(isVisible: true)
        .padding()
}

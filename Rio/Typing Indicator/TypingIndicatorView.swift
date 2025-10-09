//
//  TypingIndicatorView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/7/25.
//

import SwiftUI

// MARK: - Typing Indicator View

struct TypingIndicatorView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.primary.opacity(0.4))
                    .frame(width: 10, height: 10)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1 : 0.5)
//                    .blur(radius: isAnimating ? 0 : 2)
                    .animation(
                        .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.3),
                        value: isAnimating
                    )
            }
        }
        .frame(height: 20) //TODO: This should vary based on font size
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview("TypingIndicatorView") {
    TypingIndicatorView()
        .padding()
}

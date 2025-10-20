//
//  TapBacks.swift
//  Rio
//
//  Created by Edward Sanchez on 10/20/25.
//

import SwiftUI

/// Custom layout that positions items in a circular arrangement around a center point
struct RadialLayout: Layout {
    var radius: CGFloat

    init(radius: CGFloat = 100) {
        self.radius = radius
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // Container size needs to accommodate the full circle plus item sizes
        return CGSize(width: radius * 2, height: radius * 2)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let count = subviews.count
        guard count > 0 else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        for (index, subview) in subviews.enumerated() {
            // Calculate angle for this item (starting from top, going clockwise)
            let angle = (CGFloat(index) / CGFloat(count)) * 360.0 - 90.0 // -90 to start from top
            let radians = angle * .pi / 180.0

            // Calculate position using polar coordinates
            let x = center.x + radius * cos(radians)
            let y = center.y + radius * sin(radians)

            // Place the subview at the calculated position
            subview.place(at: CGPoint(x: x, y: y), anchor: .center, proposal: .unspecified)
        }
    }
}

struct TapBacks: View {
    @State private var menuIsShowing = false

    let reactions = ["❤️", "👍", "😂", "😮", "😢", "🔥"]

    var body: some View {
        ZStack {
            // Radial menu with emoji reactions
            RadialLayout(radius: menuIsShowing ? 100 : 0) {
                ForEach(Array(reactions.enumerated()), id: \.offset) { index, emoji in
                    Circle()
                        .fill(.white)
                        .frame(width: 44, height: 44)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                        .overlay(
                            Text(emoji)
                                .font(.system(size: 24))
                        )
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(duration: 0.4, bounce: 0.5).delay(Double(index) * 0.05), value: menuIsShowing)
                }
            }

            // Main trigger circle
            Circle()
                .fill(.blue)
                .frame(width: 100, height: 100)
                .onTapGesture {
                    withAnimation(.spring(duration: 0.3, bounce: 0.4)) {
                        menuIsShowing.toggle()
                    }
                }
        }
    }
}

#Preview {
    TapBacks()
}

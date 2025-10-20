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
    var menuIsShowing: Bool

    init(radius: CGFloat = 100, menuIsShowing: Bool = false) {
        self.radius = radius
        self.menuIsShowing = menuIsShowing
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
            // When menu is hidden, all items are at center; when shown, they move to their positions
            let currentRadius = menuIsShowing ? radius : 0
            let x = center.x + currentRadius * cos(radians)
            let y = center.y + currentRadius * sin(radians)

            // Place the subview at the calculated position
            subview.place(at: CGPoint(x: x, y: y), anchor: .center, proposal: .unspecified)
        }
    }
}

struct TapBacks: View {
    @State private var menuIsShowing = false
    var radius: CGFloat = 100

    let reactions = ["❤️", "👍", "😂", "😮", "😢", "🔥"]

    var body: some View {
        ZStack {
            // Radial menu with emoji reactions
            RadialLayout(radius: radius, menuIsShowing: menuIsShowing) {
                GlassEffectContainer {
                    ForEach(Array(reactions.enumerated()), id: \.offset) { index, emoji in
                        Button {
                            print(emoji)
                        } label: {
                            Circle()
                                .fill(.clear)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text(emoji)
                                        .font(.system(size: 24))
                                )
                                .opacity(menuIsShowing ? 1 : 0)
                        }
                        .glassEffect(.regular, in: .circle)
                        .animation(
                            .spring(duration: 0.4, bounce: 0.5)
                            .delay(Double(index) * 0.05),
                            value: menuIsShowing
                        )
                    }
                }
            }
            .animation(.spring(duration: 0.4, bounce: 0.5), value: menuIsShowing)

            // Main trigger circle
            Circle()
                .fill(.blue)
                .frame(width: 100, height: 100)
                .onTapGesture {
                    menuIsShowing.toggle()
                }
        }
    }
}

#Preview {
    TapBacks()
}

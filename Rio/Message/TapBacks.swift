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
    var spacerPercentage: CGFloat
    var spacerCenterPercent: CGFloat

    init(
        radius: CGFloat = 100,
        menuIsShowing: Bool = false,
        spacerPercentage: CGFloat = 0,
        spacerCenterPercent: CGFloat = 0.5
    ) {
        self.radius = radius
        self.menuIsShowing = menuIsShowing
        self.spacerPercentage = max(0, min(1, spacerPercentage)) // Clamp between 0 and 1
        self.spacerCenterPercent = spacerCenterPercent
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // Container size needs to accommodate the full circle plus item sizes
        return CGSize(width: radius * 2, height: radius * 2)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let count = subviews.count
        guard count > 0 else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)

        // Calculate available arc (360 degrees minus the spacer)
        let availableArc = 360.0 * (1.0 - spacerPercentage)
        
        // Calculate the angle increment between items
        let angleIncrement = availableArc / CGFloat(count)
        
        // Calculate starting angle
        // Convert spacerCenterPercent to degrees (0% = top = -90°, going clockwise)
        let spacerCenterAngle = (spacerCenterPercent * 360.0) - 90.0
        let spacerArc = 360.0 * spacerPercentage
        // Start at the end of the spacer, plus half an increment to center the first item
        let arcStartAngle = spacerCenterAngle + (spacerArc / 2.0)
        let startAngle = arcStartAngle + (angleIncrement / 2.0)

        for (index, subview) in subviews.enumerated() {
            // Calculate angle for this item within the available arc
            let angle = startAngle + (CGFloat(index) * angleIncrement)
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

struct TapBacksModifier: ViewModifier {
    @State private var menuIsShowing = false
    var messageID: UUID
    var radius: CGFloat
    var spacerPercentage: CGFloat
    var spacerCenterPercent: CGFloat
    var reactions: [String]
    var onReactionSelected: (String) -> Void

    func body(content: Content) -> some View {
        content
            .background(
                RadialLayout(
                    radius: radius,
                    menuIsShowing: menuIsShowing,
                    spacerPercentage: spacerPercentage,
                    spacerCenterPercent: spacerCenterPercent
                ) {
                    GlassEffectContainer {
                        ForEach(Array(reactions.enumerated()), id: \.offset) { index, emoji in
                            Button {
                                onReactionSelected(emoji)
                                menuIsShowing = false
                            } label: {
                                Circle()
                                    .fill(.clear)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Text(emoji)
                                            .font(.system(size: 24))
                                            .opacity(menuIsShowing ? 1 : 0)
                                    )

                            }
                            .glassEffect(menuIsShowing ? .regular : .clear, in: .circle)
                            .animation(
                                .spring(duration: 0.4, bounce: 0.5)
                                .delay(Double(index) * 0.05),
                                value: menuIsShowing
                            )
                        }
                    }
                }
                .animation(.spring(duration: 0.4, bounce: 0.5), value: menuIsShowing)
            )
            .onTapGesture {
                menuIsShowing.toggle()
            }
    }
}

extension View {
    func tapBacks(
        messageID: UUID,
        radius: CGFloat = 100,
        spacerPercentage: CGFloat = 0.25,
        spacerCenterPercent: CGFloat = 0.65,
        reactions: [String] = ["❤️", "👍", "😂", "😮", "😢", "🔥"],
        onReactionSelected: @escaping (String) -> Void = { reaction in
            print("Selected reaction: \(reaction)")
        }
    ) -> some View {
        modifier(
            TapBacksModifier(
                messageID: messageID,
                radius: radius,
                spacerPercentage: spacerPercentage,
                spacerCenterPercent: spacerCenterPercent,
                reactions: reactions,
                onReactionSelected: onReactionSelected
            )
        )
    }
}

struct TapBackTestView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.blue)
            .frame(width: 200, height: 40)
            .containerShape(.rect)
            .glassEffect(.regular.interactive(), in: .rect)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .tapBacks(messageID: UUID()) { reaction in
                print("Tapped: \(reaction)")
            }
    }
}

#Preview {
    TapBackTestView()
}

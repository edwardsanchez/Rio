//
//  CircleStack.swift
//  Rio
//
//  Created by Edward Sanchez on 10/24/25.
//

import SwiftUI

/// Packs circles inside a circle, left→right along the diameter.
/// - spacing: points between neighbors, and also the margin to the container edge
/// - shrink: per-step size decay in 0...1 (0.2 means each next circle is 20% smaller)
struct CircleStack: Layout {
    var spacing: CGFloat
    var shrink: CGFloat

    init(spacing: CGFloat = 6, shrink: CGFloat = 0.2) {
        self.spacing = spacing
        // keep reasonable bounds so nothing collapses or explodes
        self.shrink = max(0, min(shrink, 0.95))
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        // Square by default if the proposal is unspecified
        let w = proposal.width ?? 120
        let h = proposal.height ?? 120
        let side = min(w, h)
        return .init(width: side, height: side)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else { return }

        let n = subviews.count
        let side = min(bounds.width, bounds.height)
        let radius: CGFloat = side / 2

        // geometric ratios for diameters: 1, r, r^2, ...
        let r: CGFloat = 1 - shrink
        var weights: [CGFloat] = []
        var current: CGFloat = 1
        for _ in 0..<n { weights.append(current); current *= r }
        let weightSum = weights.reduce(0, +)

        // inner usable diameter after outer margin on both sides
        let inner = max(0, 2 * (radius - spacing))
        let neighborGaps = spacing * CGFloat(n - 1)
        let baseDiameter = max(0, (inner - neighborGaps) / weightSum)

        let diameters = weights.map { baseDiameter * $0 }
        let radii = diameters.map { $0 / 2 }
        let chainWidth = diameters.reduce(0, +) + neighborGaps

        // start on the left of the inner circle area so the outer margin is respected
        var x = bounds.midX - chainWidth / 2 + radii[0]
        let y = bounds.midY

        for i in 0..<n {
            let d = diameters[i]
            subviews[i].place(
                at: CGPoint(x: x, y: y),
                anchor: .center,
                proposal: ProposedViewSize(width: d, height: d)
            )
            if i < n - 1 {
                x += radii[i] + spacing + radii[i + 1]
            }
        }
    }
}

// MARK: - Demo helpers

struct DemoAvatar: View {
    var color: Color
    var text: String

    var body: some View {
        ZStack {
            Circle().fill(color.gradient)
            Text(text)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
        }
        // Child views can be any content; clip them to circles here for clarity
        .clipShape(Circle())
    }
}

struct CircleStackPreviewCard<Content: View>: View {
    var title: String
    var diameter: CGFloat = 120
    var spacing: CGFloat
    var shrink: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // show the container circle so the packing is obvious
                Circle().fill(Color(.systemGray6))
                Circle().stroke(Color(.quaternaryLabel), lineWidth: 1)

                CircleStack(spacing: spacing, shrink: shrink) {
                    content()
                }
            }
            .frame(width: diameter, height: diameter)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

#Preview("CircleStack examples") {
    VStack(spacing: 16) {
        CircleStackPreviewCard(
            title: "1 circle • spacing 6 • shrink 0.2",
            spacing: 6, shrink: 0.1
        ) {
            DemoAvatar(color: .purple, text: "A")
        }

        CircleStackPreviewCard(
            title: "2 circles • spacing 6 • shrink 0.2",
            spacing: 6, shrink: 0.1
        ) {
            DemoAvatar(color: .purple, text: "A")
            DemoAvatar(color: .blue, text: "HT")
        }

        CircleStackPreviewCard(
            title: "3 circles • spacing 6 • shrink 0.2",
            spacing: 6, shrink: 0.1
        ) {
            DemoAvatar(color: .purple, text: "A")
            DemoAvatar(color: .blue, text: "HT")
            DemoAvatar(color: .orange, text: "B")
        }

        CircleStackPreviewCard(
            title: "4 circles • spacing 8 • shrink 0.25",
            spacing: 8, shrink: 0.1
        ) {
            DemoAvatar(color: .pink, text: "AL")
            DemoAvatar(color: .teal, text: "BO")
            DemoAvatar(color: .indigo, text: "CY")
            DemoAvatar(color: .mint, text: "DJ")
        }

        CircleStackPreviewCard(
            title: "5 circles • spacing 4 • shrink 0.12",
            spacing: 4, shrink: 0.1
        ) {
            ForEach(0..<5, id: \.self) { i in
                DemoAvatar(color: [.red, .green, .blue, .orange, .purple][i], text: "\(i+1)")
            }
        }
    }
}

//
//  CircleStack.swift
//  Rio
//
//  Created by Edward Sanchez on 10/24/25.
//

import SwiftUI

/// Packs circles inside a circular boundary using a kissing-circle chain.
/// - spacing: gap between neighboring circles along their tangent line
/// - shrink: per-step size decay in 0...1 (0.2 means each next circle is 20% smaller)
/// - rimPadding: margin between inner circles and the boundary ring
/// - startAngle: angle (clockwise) for the first circle on the rim
struct CircleStack: Layout {
    var spacing: CGFloat
    var shrink: CGFloat
    var rimPadding: CGFloat
    var startAngle: Angle

    init(
        spacing: CGFloat = 6,
        shrink: CGFloat = 0.2,
        rimPadding: CGFloat = 0,
        startAngle: Angle = .degrees(330)
    ) {
        self.spacing = spacing
        // keep reasonable bounds so nothing collapses or explodes
        self.shrink = max(0, min(shrink, 0.95))
        self.rimPadding = max(0, rimPadding)
        self.startAngle = startAngle
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

        let count = subviews.count
        let side = min(bounds.width, bounds.height)
        let outerRadius = side / 2
        let effectiveRadius = outerRadius - rimPadding
        guard effectiveRadius > .zero else { return }

        guard let chain = chain(for: count, effectiveRadius: effectiveRadius),
              chain.count == count
        else {
            return
        }

        let baseAngle = CGFloat(startAngle.radians)

        for (index, element) in chain.enumerated() {
            let radius = element.radius
            let sweep = element.angle
            let distance = max(0, effectiveRadius - radius)
            let angle = baseAngle - sweep
            let center = CGPoint(
                x: bounds.midX + distance * CGFloat(cos(Double(angle))),
                y: bounds.midY + distance * CGFloat(sin(Double(angle)))
            )
            let diameter = max(0, radius * 2)
            subviews[index].place(
                at: center,
                anchor: .center,
                proposal: ProposedViewSize(width: diameter, height: diameter)
            )
        }
    }

    private var shrinkRatio: CGFloat {
        max(0, 1 - shrink)
    }

    /// Generates radius/angle pairs for a kissing circle chain if possible.
    private func chain(
        for count: Int,
        effectiveRadius: CGFloat
    ) -> [(radius: CGFloat, angle: CGFloat)]? {
        guard effectiveRadius > .zero else { return nil }

        if count == 1 {
            return [(max(0, effectiveRadius), 0)]
        }

        guard let firstRadius = findFirstRadius(effectiveRadius: effectiveRadius, count: count),
              let radiiAndAngles = calculateRadiiAndAngles(
                  firstRadius: firstRadius,
                  count: count,
                  effectiveRadius: effectiveRadius
              )
        else {
            return nil
        }

        return radiiAndAngles
    }

    /// Angle between two tangent circles that also touch the boundary circle.
    private func calculateAngleBetween(
        _ r1: CGFloat,
        _ r2: CGFloat,
        effectiveRadius: CGFloat
    ) -> CGFloat? {
        let d1 = effectiveRadius - r1
        let d2 = effectiveRadius - r2
        guard d1 > .zero, d2 > .zero else { return nil }

        let centerDistance = r1 + r2 + spacing
        let numerator = d1 * d1 + d2 * d2 - centerDistance * centerDistance
        let denominator = 2 * d1 * d2
        guard denominator > .zero else { return nil }

        let value = numerator / denominator
        if value < -1.000001 || value > 1.000001 {
            return nil
        }
        let clamped = min(1, max(-1, value))
        return CGFloat(acos(Double(clamped)))
    }

    /// Finds the first radius so the chain closes around the 2π sweep.
    private func findFirstRadius(
        effectiveRadius: CGFloat,
        count: Int,
        tolerance: CGFloat = 1e-6
    ) -> CGFloat? {
        guard count >= 2 else { return max(0, effectiveRadius) }
        let hiLimit = max(0, effectiveRadius * 0.999999)
        var low: CGFloat = 0
        var high: CGFloat = hiLimit

        func totalAngle(for candidate: CGFloat) -> CGFloat? {
            var radii: [CGFloat] = [candidate]
            for _ in 1..<count {
                radii.append(radii.last! * shrinkRatio)
            }

            var sum: CGFloat = 0
            for index in 0..<(count - 1) {
                guard let delta = calculateAngleBetween(
                    radii[index],
                    radii[index + 1],
                    effectiveRadius: effectiveRadius
                ) else {
                    return nil
                }
                sum += delta
            }

            guard let closing = calculateAngleBetween(
                radii[count - 1],
                radii[0],
                effectiveRadius: effectiveRadius
            ) else {
                return nil
            }

            return sum + closing
        }

        guard let highAngle = totalAngle(for: high), highAngle >= 2 * CGFloat.pi else {
            return nil
        }

        for _ in 0..<200 {
            let mid = (low + high) * 0.5
            guard let angle = totalAngle(for: mid) else {
                return nil
            }

            let delta = angle - 2 * CGFloat.pi
            if abs(delta) < tolerance {
                return mid
            }

            if delta < 0 {
                low = mid
            } else {
                high = mid
            }
        }

        return (low + high) * 0.5
    }

    /// Produces cumulative sweep angles for each successive circle.
    private func calculateRadiiAndAngles(
        firstRadius: CGFloat,
        count: Int,
        effectiveRadius: CGFloat
    ) -> [(radius: CGFloat, angle: CGFloat)]? {
        var radii: [CGFloat] = [firstRadius]
        for _ in 1..<count {
            radii.append(radii.last! * shrinkRatio)
        }

        var result: [(radius: CGFloat, angle: CGFloat)] = [(firstRadius, 0)]
        var cumulative: CGFloat = 0

        for index in 1..<count {
            guard let delta = calculateAngleBetween(
                radii[index - 1],
                radii[index],
                effectiveRadius: effectiveRadius
            ) else {
                return nil
            }
            cumulative += delta
            result.append((radii[index], cumulative))
        }

        return result
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
    var diameter: CGFloat
    var spacing: CGFloat
    var shrink: CGFloat
    var rimPadding: CGFloat
    var startAngle: Angle
    @ViewBuilder var content: () -> Content

    init(
        title: String,
        diameter: CGFloat = 140,
        spacing: CGFloat,
        shrink: CGFloat,
        rimPadding: CGFloat = 0,
        startAngle: Angle = .degrees(330),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.diameter = diameter
        self.spacing = spacing
        self.shrink = shrink
        self.rimPadding = rimPadding
        self.startAngle = startAngle
        self.content = content
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // show the container circle so the packing is obvious
                Circle().fill(Color(.systemGray6))
                Circle().stroke(Color(.quaternaryLabel), lineWidth: 1)

                CircleStack(
                    spacing: spacing,
                    shrink: shrink,
                    rimPadding: rimPadding,
                    startAngle: startAngle
                ) {
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

struct CircleStackStartAnglePreviewCard: View {
    private let samples: [(angle: Angle, label: String)] = [
        (.degrees(330), "330°"),
        (.degrees(210), "210°"),
        (.degrees(90), "90°")
    ]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                    VStack(spacing: 4) {
                        ZStack {
                            Circle().fill(Color(.systemGray6))
                            Circle().stroke(Color(.quaternaryLabel), lineWidth: 1)

                            CircleStack(
                                spacing: 8,
                                shrink: 0.1,
                                rimPadding: 10,
                                startAngle: sample.angle
                            ) {
                                DemoAvatar(color: .purple, text: "A")
                                DemoAvatar(color: .blue, text: "HT")
                                DemoAvatar(color: .orange, text: "B")
                                DemoAvatar(color: .mint, text: "R")
                            }
                        }
                        .frame(width: 120, height: 120)

                        Text(sample.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Text("startAngle variations")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

#Preview("CircleStack examples") {
    VStack(spacing: 16) {
        CircleStackPreviewCard(
            title: "Kissing chain • 3 avatars • shrink 10% • rim 14",
            spacing: 8,
            shrink: 0.1,
            rimPadding: 10
        ) {
            DemoAvatar(color: .purple, text: "A")
            DemoAvatar(color: .blue, text: "HT")
            DemoAvatar(color: .orange, text: "B")
        }

        CircleStackPreviewCard(
            title: "Four avatars • shrink 18% • start 270° • rim 18",
            spacing: 8,
            shrink: 0.1,
            rimPadding: 10,
            startAngle: .degrees(270)
        ) {
            DemoAvatar(color: .pink, text: "AL")
            DemoAvatar(color: .teal, text: "BO")
            DemoAvatar(color: .indigo, text: "CY")
            DemoAvatar(color: .mint, text: "DJ")
        }


        CircleStackPreviewCard(
            title: "Ten circles • shrink 12% • spacing 2 • rim 10",
            spacing: 8,
            shrink: 0.1,
            rimPadding: 10
        ) {
            ForEach(0..<10, id: \.self) { index in
                let hue = Double(index) / 10
                DemoAvatar(
                    color: Color(hue: hue, saturation: 0.65, brightness: 0.95),
                    text: "\(index + 1)"
                )
            }
        }
        
        CircleStackStartAnglePreviewCard()
    }
    .padding(.horizontal, 16)
}

//
//  CircleStack.swift
//  Rio
//
//  Created by Edward Sanchez on 10/24/25.
//

import SwiftUI
import OSLog

/// Linear congruential generator so the greedy packing stays deterministic.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        // Parameters from "Numerical Recipes".
        state = state &* 6364136223846793005 &+ 1
        return state
    }
}

/// Packs circles inside a circular boundary with a greedy disc placement strategy.
/// - spacing: minimum gap between the primary circle and the rest; secondary circles scale the gap proportionally.
/// - rimPadding: margin between inner circles and the boundary ring
/// - startAngle: angle (clockwise) for the primary circle on the rim
struct GreedyCircleStack: Layout, Animatable {
    private static let logger = Logger.message

    var spacing: CGFloat
    var rimPadding: CGFloat
    var startAngle: Angle

    // When true, indicates target layout is vertical; used to set initial progress
    var isVertical: Bool
    // Spacing between circles when isVertical is enabled
    var verticalSpacing: CGFloat
    // Fixed circle diameter when isVertical is enabled (optional). If nil, fits to bounds.
    var verticalDiameter: CGFloat?
    // Interpolation progress between greedy (0) and vertical (1)
    var verticalProgress: CGFloat

    // Animatable conformance
    var animatableData: CGFloat {
        get { verticalProgress }
        set { verticalProgress = max(0, min(1, newValue)) }
    }

    private struct PackedCircle {
        var center: CGPoint
        var radius: CGFloat
        var isPrimary: Bool
    }

    init(
        spacing: CGFloat = 0,
        rimPadding: CGFloat = 0,
        startAngle: Angle = .degrees(315),
        isVertical: Bool = false,
        verticalSpacing: CGFloat = 8,
        verticalDiameter: CGFloat? = nil,
        verticalProgress: CGFloat? = nil
    ) {
        self.spacing = max(0, spacing)
        // keep reasonable bounds so nothing collapses or explodes
        self.rimPadding = max(0, rimPadding)
        self.startAngle = startAngle + .degrees(90)
        self.isVertical = isVertical
        self.verticalSpacing = max(0, verticalSpacing)
        self.verticalDiameter = verticalDiameter
        // If explicit progress not provided, derive from isVertical
        self.verticalProgress = max(0, min(1, verticalProgress ?? (isVertical ? 1 : 0)))
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        CGSize(
            width: proposal.width ?? 0,
            height: proposal.height ?? 0
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard !subviews.isEmpty else {
            GreedyCircleStack.logger.debug("CircleStack: no subviews to arrange")
            return
        }
        let containerDiameter = min(bounds.width, bounds.height)
        let parentRadius = max(0, containerDiameter / 2.0 - rimPadding)

        guard parentRadius > 0 else {
            GreedyCircleStack.logger.error("CircleStack: invalid parent radius \(parentRadius, privacy: .public) for bounds \(bounds.debugDescription, privacy: .public)")
            return
        }

        let angle = startAngle.radians
        let packed = packCircles(
            parentRadius: parentRadius,
            count: subviews.count,
            pinnedAngle: angle,
            spacing: spacing,
            rimPadding: rimPadding
        )

        if packed.count < subviews.count {
            GreedyCircleStack.logger.warning("CircleStack: packed only \(packed.count, privacy: .public)/\(subviews.count, privacy: .public) circles due to space constraints")
        }

        let origin = CGPoint(x: bounds.midX, y: bounds.midY)

        // Prepare vertical layout targets
        let count = subviews.count
        let availableHeight = bounds.height - verticalSpacing * CGFloat(max(0, count - 1))
        let fitDiameter = max(0, availableHeight / CGFloat(max(count, 1)))
        let computedDiameter = min(bounds.width, fitDiameter)
        let diameter = max(0, verticalDiameter ?? computedDiameter)
        let totalHeight = CGFloat(count) * diameter + CGFloat(max(0, count - 1)) * verticalSpacing
        var currentY = bounds.midY - totalHeight / 2 + diameter / 2

        // Prepare arrays for interpolation and collision resolution
        var centers: [CGPoint] = Array(repeating: .zero, count: count)
        var radii: [CGFloat] = Array(repeating: 0, count: count)

        let t = max(0, min(1, verticalProgress))

        for index in 0..<count {
            let greedyCircle = index < packed.count ? packed[index] : PackedCircle(center: .zero, radius: 0, isPrimary: false)

            let greedyPoint = CGPoint(
                x: origin.x + greedyCircle.center.x,
                y: origin.y - greedyCircle.center.y
            )
            let greedyRadius = greedyCircle.radius

            let verticalPoint = CGPoint(x: bounds.midX, y: currentY)
            let verticalRadius = diameter / 2

            let blendedX = greedyPoint.x + (verticalPoint.x - greedyPoint.x) * t
            let blendedY = greedyPoint.y + (verticalPoint.y - greedyPoint.y) * t
            let blendedRadius = max(0, greedyRadius + (verticalRadius - greedyRadius) * t)

            centers[index] = CGPoint(x: blendedX, y: blendedY)
            radii[index] = blendedRadius

            currentY += diameter + verticalSpacing
        }

        // Resolve overlaps to simulate solid-disc behavior
        resolveCollisions(centers: &centers, radii: radii, bounds: bounds)

        // Place subviews with collision-free positions
        for index in 0..<count {
            let r = radii[index]
            let proposal = ProposedViewSize(width: r * 2, height: r * 2)
            subviews[index].place(at: centers[index], anchor: .center, proposal: proposal)
        }
    }

    // MARK: - Collision resolution

    private func resolveCollisions(
        centers: inout [CGPoint],
        radii: [CGFloat],
        bounds: CGRect
    ) {
        let n = centers.count
        guard n > 1 else { return }

        let iterations = 14
        let epsilon: CGFloat = 0.0001

        for _ in 0..<iterations {
            var anyOverlap = false

            // Pairwise resolution
            for i in 0..<n {
                for j in (i + 1)..<n {
                    let dx = centers[j].x - centers[i].x
                    let dy = centers[j].y - centers[i].y
                    let distance = hypot(dx, dy)
                    let minDistance = radii[i] + radii[j] - epsilon

                    if distance < minDistance {
                        anyOverlap = true
                        let overlap = max(0, minDistance - distance)

                        // Direction unit vector (fallback to index-based direction if coincident)
                        let ux: CGFloat
                        let uy: CGFloat
                        if distance > 0.0001 {
                            ux = dx / distance
                            uy = dy / distance
                        } else {
                            // Deterministic slight push based on indices
                            let angle = (CGFloat(i * 37 + j * 19) .truncatingRemainder(dividingBy: 360)).radians
                            ux = cos(angle)
                            uy = sin(angle)
                        }

                        let move = overlap / 2
                        centers[i].x -= ux * move
                        centers[i].y -= uy * move
                        centers[j].x += ux * move
                        centers[j].y += uy * move
                    }
                }

                // Clamp to bounds to keep circles fully visible
                centers[i].x = max(bounds.minX + radii[i], min(bounds.maxX - radii[i], centers[i].x))
                centers[i].y = max(bounds.minY + radii[i], min(bounds.maxY - radii[i], centers[i].y))
            }

            if !anyOverlap { break }
        }
    }

    private func packCircles(
        parentRadius: CGFloat,
        count: Int,
        pinnedAngle: Double,
        spacing: CGFloat,
        rimPadding: CGFloat
    ) -> [PackedCircle] {
        guard count > 0 else { return [] }

//        let primaryRadius = parentRadius / (1.0 + CGFloat(sqrt(Double(count))))
        let n = Double(count)
        let drop = 0.3
        let secondaryRadius = parentRadius / 65
        let primaryRadius = parentRadius / (1 + pow(secondaryRadius * (n - 1), drop))
        let anchorDistance = parentRadius - primaryRadius
        let primaryCenter = CGPoint(
            x: anchorDistance * CGFloat(cos(pinnedAngle)),
            y: anchorDistance * CGFloat(sin(pinnedAngle))
        )
        var discs: [PackedCircle] = [
            PackedCircle(center: primaryCenter, radius: primaryRadius, isPrimary: true)
        ]

        GreedyCircleStack.logger.debug(
            """
            CircleStack: packing \(count, privacy: .public) circles | parentRadius=\(Double(parentRadius), privacy: .public) \
            primaryRadius=\(Double(primaryRadius), privacy: .public) rimPadding=\(Double(rimPadding), privacy: .public) \
            spacing=\(Double(spacing), privacy: .public) startAngle=\(pinnedAngle, privacy: .public)
            """
        )

        guard count > 1 else { return discs }

        let sampleCount = max(4000, count * 450)
        GreedyCircleStack.logger.debug("CircleStack: greedy sample count \(sampleCount, privacy: .public)")

        var rng = SeededGenerator(seed: 0xC1C1E5EEDBAADF0F)

        for index in 1..<count {
            var bestCircle = PackedCircle(center: .zero, radius: 0, isPrimary: false)

            for _ in 0..<sampleCount {
                let u = Double(rng.next()) / Double(UInt64.max)
                let v = Double(rng.next()) / Double(UInt64.max)
                let candidateRadius = parentRadius * CGFloat(sqrt(u))
                let theta = 2.0 * Double.pi * v
                let point = CGPoint(
                    x: candidateRadius * CGFloat(cos(theta)),
                    y: candidateRadius * CGFloat(sin(theta))
                )

                let allowableRadius = maxRadius(
                    at: point,
                    discs: discs,
                    parentRadius: parentRadius,
                    primaryRadius: primaryRadius,
                    spacing: spacing
                )

                if allowableRadius > bestCircle.radius {
                    bestCircle = PackedCircle(center: point, radius: allowableRadius, isPrimary: false)
                }
            }

            guard bestCircle.radius > .ulpOfOne else {
                GreedyCircleStack.logger.warning("CircleStack: stopping after \(discs.count, privacy: .public) circles; no space for index \(index, privacy: .public)")
                break
            }

            discs.append(bestCircle)
        }

        return discs
    }

    private func maxRadius(
        at point: CGPoint,
        discs: [PackedCircle],
        parentRadius: CGFloat,
        primaryRadius: CGFloat,
        spacing: CGFloat
    ) -> CGFloat {
        let distanceToOrigin = hypot(point.x, point.y)
        var maxRadius = parentRadius - distanceToOrigin
        guard maxRadius > .ulpOfOne else { return 0 }

        for disc in discs {
            let dx = point.x - disc.center.x
            let dy = point.y - disc.center.y
            let distance = hypot(dx, dy)

            guard distance > .ulpOfOne else {
                return 0
            }

            let limit: CGFloat
            if disc.isPrimary {
                limit = distance - disc.radius - spacing
            } else {
                limit = secondarySpacingLimit(
                    existingRadius: disc.radius,
                    centerDistance: distance,
                    primaryRadius: primaryRadius,
                    spacing: spacing
                )
            }

            maxRadius = min(maxRadius, limit)
            if maxRadius <= .ulpOfOne { return 0 }
        }

        return maxRadius
    }

    private func secondarySpacingLimit(
        existingRadius: CGFloat,
        centerDistance: CGFloat,
        primaryRadius: CGFloat,
        spacing: CGFloat
    ) -> CGFloat {
        guard centerDistance > .ulpOfOne else { return 0 }

        guard spacing > 0, primaryRadius > 0 else {
            return centerDistance - existingRadius
        }

        let scale = spacing / primaryRadius
        let candidateWithin = (centerDistance - existingRadius) / (1 + scale)

        if candidateWithin <= existingRadius {
            return max(candidateWithin, 0)
        } else {
            let candidateBeyond = centerDistance - existingRadius * (1 + scale)
            return max(candidateBeyond, 0)
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
    var spacing: CGFloat = 3
    var rimPadding: CGFloat = 3
    var startAngle: Angle = .degrees(45)
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // show the container circle so the packing is obvious
                Circle().fill(Color(.systemGray6))
                Circle().stroke(Color(.quaternaryLabel), lineWidth: 1)

                GreedyCircleStack(
                    spacing: spacing,
                    rimPadding: rimPadding,
                    startAngle: startAngle
                ) {
                    content()
                }
            }
//            .frame(width: 160, height: 160)

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
            title: "1 avatar"
        ) {
            DemoAvatar(color: .purple, text: "A")
        }

        CircleStackPreviewCard(
            title: "2 avatars"
        ) {
            DemoAvatar(color: .purple, text: "A")
            DemoAvatar(color: .blue, text: "B")
        }

        CircleStackPreviewCard(
            title: "3 avatars"
        ) {
            DemoAvatar(color: .purple, text: "A")
            DemoAvatar(color: .blue, text: "B")
            DemoAvatar(color: .orange, text: "C")
        }

        CircleStackPreviewCard(
            title: "4 avatars"
        ) {
            DemoAvatar(color: .pink, text: "A")
            DemoAvatar(color: .teal, text: "B")
            DemoAvatar(color: .indigo, text: "C")
            DemoAvatar(color: .mint, text: "D")
        }
        CircleStackPreviewCard(
            title: "5 avatars"
        ) {
            ForEach(0..<5, id: \.self) { index in
                DemoAvatar(
                    color: [.red, .green, .blue, .orange, .purple][index],
                    text: "\(index + 1)"
                )
            }
        }

        CircleStackPreviewCard(
            title: "10 avatars, tight spacing",
        ) {
            ForEach(0..<10, id: \.self) { index in
                DemoAvatar(
                    color: Color(hue: Double(index) / 10.0, saturation: 0.75, brightness: 0.9),
                    text: "\(index + 1)"
                )
            }
        }
    }
}

#Preview("Greedy vs Vertical (4 avatars)") {
    @Previewable @State var isVertical = false
    let diameter: CGFloat = 48
    let vSpacing: CGFloat = 10

    VStack(spacing: 12) {
        Toggle("Vertical layout", isOn: $isVertical)
            .toggleStyle(.switch)

        ZStack {
            if !isVertical {
                Circle().fill(Color(.systemGray6))
                Circle().stroke(Color(.quaternaryLabel), lineWidth: 1)
            }

            GreedyCircleStack(
                spacing: 3,
                rimPadding: 3,
                startAngle: .degrees(45),
                isVertical: isVertical,
                verticalSpacing: vSpacing,
                verticalDiameter: diameter
            ) {
                DemoAvatar(color: .pink, text: "A")
                DemoAvatar(color: .teal, text: "B")
                DemoAvatar(color: .indigo, text: "C")
                DemoAvatar(color: .mint, text: "D")
            }
        }
        .frame(
            width: 170,
            height: isVertical ? (diameter * 4 + vSpacing * 3) : 170
        )
    }
    .padding()
    .animation(.smooth(duration: 0.6), value: isVertical)
}

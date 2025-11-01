//
//  GreedyCircleStack.swift
//  Rio
//
//  Created by Edward Sanchez on 10/24/25.
//

import OSLog
import SwiftUI

/// Linear congruential generator so the greedy packing stays deterministic.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        // Parameters from "Numerical Recipes".
        state = state &* 6_364_136_223_846_793_005 &+ 1
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
    // Preferred square side when in greedy mode (fallback if proposal doesn't provide size)
    var greedyPreferredSide: CGFloat?

    // Animation progress: 0.0 = greedy layout, 1.0 = vertical layout
    var animationProgress: CGFloat

    private struct PackedCircle {
        var center: CGPoint
        var radius: CGFloat
        var isPrimary: Bool
    }

    private struct AnimatedCircle {
        var center: CGPoint
        var radius: CGFloat
    }

    init(
        spacing: CGFloat = 0,
        rimPadding: CGFloat = 0,
        startAngle: Angle = .degrees(315),
        isVertical: Bool = false,
        verticalSpacing: CGFloat = 8,
        verticalDiameter: CGFloat? = nil,
        greedyPreferredSide: CGFloat? = nil
    ) {
        self.spacing = max(0, spacing)
        // keep reasonable bounds so nothing collapses or explodes
        self.rimPadding = max(0, rimPadding)
        self.startAngle = startAngle + .degrees(90)
        self.isVertical = isVertical
        self.verticalSpacing = max(0, verticalSpacing)
        self.verticalDiameter = verticalDiameter
        self.greedyPreferredSide = greedyPreferredSide
        // Set animation progress based on isVertical
        animationProgress = isVertical ? 1.0 : 0.0
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let count = subviews.count
        guard count > 0 else { return .zero }

        if isVertical {
            // Width: respect proposal if present, else use verticalDiameter, else sensible default
            let proposedWidth = proposal.width ?? verticalDiameter ?? 60
            let diameter = min(verticalDiameter ?? proposedWidth, proposedWidth)
            let totalHeight = CGFloat(count) * diameter + CGFloat(max(0, count - 1)) * verticalSpacing
            return CGSize(width: proposedWidth, height: totalHeight)
        } else {
            // Greedy is a square; prefer parent's proposed size, else fallback
            if let w = proposal.width, let h = proposal.height {
                let side = min(w, h)
                return CGSize(width: side, height: side)
            } else if let w = proposal.width {
                return CGSize(width: w, height: w)
            } else if let h = proposal.height {
                return CGSize(width: h, height: h)
            } else {
                let side = greedyPreferredSide ?? 170
                return CGSize(width: side, height: side)
            }
        }
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
            GreedyCircleStack.logger
                .error(
                    "CircleStack: invalid parent radius \(parentRadius, privacy: .public) for bounds \(bounds.debugDescription, privacy: .public)"
                )
            return
        }

        let count = subviews.count
        let availableHeight = bounds.height - verticalSpacing * CGFloat(max(0, count - 1))
        let fitDiameter = max(0, availableHeight / CGFloat(max(count, 1)))
        let fallbackDiameter = max(0, min(bounds.width, fitDiameter))

        // Check if we're animating (progress is between 0 and 1)
        let isAnimating = animationProgress > 0.001 && animationProgress < 0.999

        if isAnimating {
            // During animation, interpolate between greedy and vertical layouts

            // Calculate greedy layout
            let angle = startAngle.radians
            let greedyPacked = packCircles(
                parentRadius: parentRadius,
                count: subviews.count,
                pinnedAngle: angle,
                spacing: spacing,
                rimPadding: rimPadding
            )

            // Calculate vertical layout positions (same order as greedy)
            let diameter = max(0, min(verticalDiameter ?? fallbackDiameter, bounds.width))
            var verticalPacked: [PackedCircle] = []
            let startX = bounds.minX + diameter / 2
            let startY = bounds.minY + diameter / 2

            for index in 0 ..< count where index < subviews.count {
                let desiredX = startX
                let desiredY = startY + CGFloat(index) * (diameter + verticalSpacing)
                let relativeX = desiredX - bounds.midX
                let relativeY = bounds.midY - desiredY
                verticalPacked.append(PackedCircle(
                    center: CGPoint(x: relativeX, y: relativeY),
                    radius: diameter / 2,
                    isPrimary: false
                ))
            }

            // Interpolate with collision resolution
            let interpolated = interpolateLayouts(
                greedyCircles: greedyPacked,
                verticalCircles: verticalPacked,
                progress: animationProgress,
                bounds: bounds
            )

            let origin = CGPoint(x: bounds.midX, y: bounds.midY)

            for (index, circle) in interpolated.enumerated() where index < subviews.count {
                let proposal = ProposedViewSize(width: circle.radius * 2, height: circle.radius * 2)
                let placement = CGPoint(
                    x: origin.x + circle.center.x,
                    y: origin.y - circle.center.y
                )

                subviews[index].place(at: placement, anchor: .center, proposal: proposal)
            }
        } else if animationProgress >= 0.999 {
            // Fully vertical layout
            let diameter = max(0, min(verticalDiameter ?? fallbackDiameter, bounds.width))
            var currentY = bounds.minY + diameter / 2
            let centerX = bounds.minX + diameter / 2
            for index in 0 ..< count where index < subviews.count {
                let proposal = ProposedViewSize(width: diameter, height: diameter)
                let placement = CGPoint(x: centerX, y: currentY)
                subviews[index].place(at: placement, anchor: .center, proposal: proposal)
                currentY += diameter + verticalSpacing
            }
        } else {
            // Fully greedy layout
            let angle = startAngle.radians
            let packed = packCircles(
                parentRadius: parentRadius,
                count: subviews.count,
                pinnedAngle: angle,
                spacing: spacing,
                rimPadding: rimPadding
            )

            if packed.count < subviews.count {
                GreedyCircleStack.logger
                    .warning(
                        "CircleStack: packed only \(packed.count, privacy: .public)/\(subviews.count, privacy: .public) circles due to space constraints"
                    )
            }

            let origin = CGPoint(x: bounds.midX, y: bounds.midY)

            for (index, circle) in packed.enumerated() where index < subviews.count {
                let proposal = ProposedViewSize(width: circle.radius * 2, height: circle.radius * 2)
                let placement = CGPoint(
                    x: origin.x + circle.center.x,
                    y: origin.y - circle.center.y
                )

                subviews[index].place(at: placement, anchor: .center, proposal: proposal)
            }
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
            CircleStack: packing \(count, privacy: .public) circles | parentRadius=\(
                Double(parentRadius),
                privacy: .public
            ) \
            primaryRadius=\(Double(primaryRadius), privacy: .public) rimPadding=\(
                Double(rimPadding),
                privacy: .public
            ) \
            spacing=\(Double(spacing), privacy: .public) startAngle=\(pinnedAngle, privacy: .public)
            """
        )

        guard count > 1 else { return discs }

        let sampleCount = max(4000, count * 450)
        GreedyCircleStack.logger.debug("CircleStack: greedy sample count \(sampleCount, privacy: .public)")

        var rng = SeededGenerator(seed: 0xC1C1_E5EE_DBAA_DF0F)

        for index in 1 ..< count {
            var bestCircle = PackedCircle(center: .zero, radius: 0, isPrimary: false)

            for _ in 0 ..< sampleCount {
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
                GreedyCircleStack.logger
                    .warning(
                        "CircleStack: stopping after \(discs.count, privacy: .public) circles; no space for index \(index, privacy: .public)"
                    )
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

            let limit: CGFloat = if disc.isPrimary {
                distance - disc.radius - spacing
            } else {
                secondarySpacingLimit(
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

    // MARK: - Simple Collision Avoidance

    /// Multi-pass collision resolution - only for small circle counts
    private func resolveCollisions(
        circles: inout [AnimatedCircle],
        spacing: CGFloat
    ) {
        // Only apply collision resolution for small numbers of circles (performance)
        guard circles.count > 1, circles.count <= 10 else { return }

        // Multiple passes to fully resolve overlaps (fewer passes for larger counts)
        let iterations = circles.count <= 5 ? 10 : 2

        for _ in 0 ..< iterations {
            // Check each pair and push apart if overlapping
            for i in 0 ..< circles.count {
                for j in (i + 1) ..< circles.count {
                    let dx = circles[j].center.x - circles[i].center.x
                    let dy = circles[j].center.y - circles[i].center.y
                    let distance = hypot(dx, dy)
                    let minDistance = circles[i].radius + circles[j].radius + spacing

                    // If overlapping, push them apart equally
                    if distance < minDistance && distance > .ulpOfOne {
                        let overlap = minDistance - distance
                        let offsetX = (dx / distance) * overlap * 0.5
                        let offsetY = (dy / distance) * overlap * 0.5

                        circles[i].center.x -= offsetX
                        circles[i].center.y -= offsetY
                        circles[j].center.x += offsetX
                        circles[j].center.y += offsetY
                    }
                }
            }
        }
    }

    /// Interpolates between greedy and vertical layouts with collision resolution
    private func interpolateLayouts(
        greedyCircles: [PackedCircle],
        verticalCircles: [PackedCircle],
        progress: CGFloat,
        bounds: CGRect
    ) -> [AnimatedCircle] {
        let count = min(greedyCircles.count, verticalCircles.count)
        guard count > 0 else { return [] }

        var animated: [AnimatedCircle] = []

        for i in 0 ..< count {
            let greedyPos = greedyCircles[i].center
            let verticalPos = verticalCircles[i].center
            let greedyRadius = greedyCircles[i].radius
            let verticalRadius = verticalCircles[i].radius

            // Linear interpolation for target position and radius
            let targetX = greedyPos.x + (verticalPos.x - greedyPos.x) * progress
            let targetY = greedyPos.y + (verticalPos.y - greedyPos.y) * progress
            let targetRadius = greedyRadius + (verticalRadius - greedyRadius) * progress

            animated.append(AnimatedCircle(
                center: CGPoint(x: targetX, y: targetY),
                radius: targetRadius
            ))
        }

        // Apply collision resolution
        resolveCollisions(circles: &animated, spacing: spacing)

        return animated
    }

    // MARK: - Animatable Conformance

    var animatableData: CGFloat {
        get { animationProgress }
        set { animationProgress = newValue }
    }
}

// MARK: - Preview helpers

private enum PreviewUsers {
    private static func make(_ name: String, avatar: ImageResource?) -> User {
        User(id: UUID(), name: name, resource: avatar) //No exact matches in call to initializer
    }

    static let mixed: [User] = [
        make("Lumen Moss", avatar: nil),
        make("Maya Park", avatar: .amy),
        make("Nova Lin", avatar: nil),
        make("Joaquin Wilde", avatar: .joaquin),
        make("Scarlet Chen", avatar: .scarlet),
        make("River Slate", avatar: nil),
        make("Eddie Carter", avatar: .edward),
        make("Nate Read", avatar: .read),
        make("Carta Bloom", avatar: .cartouche),
        make("Sage Hart", avatar: nil)
    ]
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
            ForEach(Array(PreviewUsers.mixed.prefix(1))) { user in
                AvatarView(user: user)
            }
        }

        CircleStackPreviewCard(
            title: "2 avatars"
        ) {
            ForEach(Array(PreviewUsers.mixed.prefix(2))) { user in
                AvatarView(user: user)
            }
        }

        CircleStackPreviewCard(
            title: "3 avatars"
        ) {
            ForEach(Array(PreviewUsers.mixed.prefix(3))) { user in
                AvatarView(user: user)
            }
        }

        CircleStackPreviewCard(
            title: "4 avatars"
        ) {
            ForEach(Array(PreviewUsers.mixed.prefix(4))) { user in
                AvatarView(user: user)
            }
        }

        CircleStackPreviewCard(
            title: "5 avatars"
        ) {
            ForEach(Array(PreviewUsers.mixed.prefix(5))) { user in
                AvatarView(user: user)
            }
        }

        CircleStackPreviewCard(
            title: "10 avatars, tight spacing"
        ) {
            ForEach(PreviewUsers.mixed) { user in
                AvatarView(user: user)
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
            .onChange(of: isVertical) { _, _ in
                // Trigger animation when toggle changes
            }

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
                ForEach(Array(PreviewUsers.mixed.prefix(5))) { user in
                    AvatarView(user: user)
                }
            }
            .animation(.smooth(duration: 1), value: isVertical)
        }
        // Let layout compute height in vertical mode; constrain only width
        .frame(width: 80)
        .frame(maxHeight: .infinity)
    }
    .padding()
}

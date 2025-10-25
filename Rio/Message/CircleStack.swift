//
//  CircleStack.swift
//  Rio
//
//  Created by Edward Sanchez on 10/24/25.
//

import SwiftUI
import OSLog

/// Packs circles inside a circular boundary using a kissing-circle chain.
/// - spacing: gap between neighboring circles along their tangent line
/// - shrink: per-step size decay in 0...1 (0.2 means each next circle is 20% smaller)
/// - rimPadding: margin between inner circles and the boundary ring
/// - startAngle: angle (clockwise) for the first circle on the rim
struct CircleStack: Layout {
    private static let logger = Logger.message

    private static func logDebug(_ message: @autoclosure () -> String) {
        let text = message()
        #if DEBUG
        print("[CircleStack] \(text)")
        #endif
        logger.debug("\(text, privacy: .public)")
    }

    private static func logError(_ message: @autoclosure () -> String) {
        let text = message()
        #if DEBUG
        print("[CircleStack][Error] \(text)")
        #endif
        logger.error("\(text, privacy: .public)")
    }

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
        self.spacing = max(0, spacing)
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

        let parametersDescription = """
        count=\(count) spacing=\(Double(spacing)) shrink=\(Double(shrink)) \
        rimPadding=\(Double(rimPadding)) startAngleDegrees=\(Double(startAngle.degrees)) \
        bounds=\(bounds.debugDescription)
        """
        CircleStack.logDebug("placeSubviews parameters: \(parametersDescription)")

        guard let chain = chain(for: count, effectiveRadius: effectiveRadius) else {
            CircleStack.logError("placeSubviews failed to compute chain for count=\(count)")
            return
        }

        let baseAngle = CGFloat(startAngle.radians)
        var placementLogs: [String] = []

        for (index, element) in chain.enumerated() {
            let radius = element.radius
            let sweep = element.angle
            let distance = max(0, effectiveRadius - radius)
            let angle = baseAngle + sweep
            let center = CGPoint(
                x: bounds.midX + distance * CGFloat(cos(Double(angle))),
                y: bounds.midY + distance * CGFloat(sin(Double(angle)))
            )
            let diameter = max(0, radius * 2)
            placementLogs.append("i\(index) radius=\(radius) diameter=\(diameter) angle=\(angle) center=(\(center.x),\(center.y))")
            subviews[index].place(
                at: center,
                anchor: .center,
                proposal: ProposedViewSize(width: diameter, height: diameter)
            )
        }

        let placementsDescription = placementLogs.joined(separator: " | ")
        CircleStack.logDebug("placeSubviews placements: \(placementsDescription)")
    }

    private var shrinkRatio: CGFloat {
        max(0, 1 - shrink)
    }

    private var shrinkRatioDouble: Double {
        Double(shrinkRatio)
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

        let neighborGap = Double(spacing)
        let effectiveRadiusDouble = Double(effectiveRadius)

        guard let firstRadius = findFirstRadius(
            effectiveRadius: effectiveRadiusDouble,
            count: count,
            neighborGap: neighborGap
        ) else {
            CircleStack.logError("chain unable to solve first radius for count=\(count)")
            return nil
        }

        guard let geometry = calculateRadiiAndAngles(
            firstRadius: firstRadius,
            count: count,
            effectiveRadius: effectiveRadiusDouble,
            neighborGap: neighborGap
        ) else {
            CircleStack.logError("chain failed to compute angle sequence after solving first radius")
            return nil
        }

        let radiiDescription = geometry.enumerated()
            .map { index, element in
                "i\(index)=\(Double(element.radius))"
            }
            .joined(separator: ", ")
        CircleStack.logDebug("chain radii: \(radiiDescription)")

        let anglesDescription = geometry.enumerated()
            .map { index, element in
                "i\(index)=\(Double(element.angle))"
            }
            .joined(separator: ", ")
        CircleStack.logDebug("chain angles: \(anglesDescription)")

        if geometry.count >= 2,
           let closing = calculateAngleBetween(
               Double(geometry[count - 1].radius),
               Double(geometry[0].radius),
               effectiveRadius: effectiveRadiusDouble,
               neighborGap: neighborGap
           ) {
            let totalSweep = Double(geometry.last?.angle ?? 0) + closing
            CircleStack.logDebug(
                "chain closingAngle=\(closing) totalSweep=\(totalSweep) delta=\(totalSweep - 2 * Double.pi)"
            )
        }

        return geometry
    }

    /// Angle between two tangent circles that also touch the boundary circle.
    private func calculateAngleBetween(
        _ r1: Double,
        _ r2: Double,
        effectiveRadius: Double,
        neighborGap: Double
    ) -> Double? {
        let radial1 = effectiveRadius - r1
        let radial2 = effectiveRadius - r2
        guard radial1 > 0, radial2 > 0 else { return nil }

        let centerDistance = r1 + r2 + neighborGap
        let maxDistance = radial1 + radial2
        let minDistance = abs(radial1 - radial2)
        let tolerance = 1e-9 * max(1.0, max(centerDistance, maxDistance))

        if centerDistance - maxDistance > tolerance { return nil }
        if minDistance - centerDistance > tolerance { return nil }

        let numerator = radial1 * radial1 + radial2 * radial2 - centerDistance * centerDistance
        let denominator = 2 * radial1 * radial2
        guard denominator > 0 else { return nil }

        let ratio = numerator / denominator
        if ratio.isNaN { return nil }
        let clamped = max(-1.0, min(1.0, ratio))
        return acos(clamped)
    }

    /// Finds the first circle radius that closes the chain around the boundary.
    private func findFirstRadius(
        effectiveRadius: Double,
        count: Int,
        neighborGap: Double,
        tolerance: Double = 1e-9
    ) -> Double? {
        guard count >= 2 else { return max(0, effectiveRadius) }

        let target = 2 * Double.pi
        let ratio = shrinkRatioDouble

        func totalAngle(for firstRadius: Double) -> Double? {
            guard firstRadius > 0 else { return 0 }

            var accumulated = 0.0
            var previousRadius = firstRadius

            for index in 1..<count {
                let nextRadius = firstRadius * pow(ratio, Double(index))
                guard let angle = calculateAngleBetween(
                    previousRadius,
                    nextRadius,
                    effectiveRadius: effectiveRadius,
                    neighborGap: neighborGap
                ) else {
                    return nil
                }
                accumulated += angle
                previousRadius = nextRadius
            }

            guard let closing = calculateAngleBetween(
                previousRadius,
                firstRadius,
                effectiveRadius: effectiveRadius,
                neighborGap: neighborGap
            ) else {
                return nil
            }

            return accumulated + closing
        }

        // Find an upper bound that yields a valid angle >= 2π.
        var high = max(1e-9, effectiveRadius * (1 - 1e-6))
        var highAngle: Double?
        for _ in 0..<128 {
            if let angle = totalAngle(for: high) {
                highAngle = angle
                if angle >= target { break }
            }
            high *= 0.95
        }

        guard let initialHighAngle = highAngle, initialHighAngle >= target else {
            CircleStack.logDebug("findFirstRadius unable to establish upper bound high=\(high) angle=\(String(describing: highAngle))")
            return nil
        }

        // Find a lower bound where the angle is <= 2π.
        var low = high
        var lowAngle = initialHighAngle
        for _ in 0..<128 where lowAngle > target {
            low *= 0.5
            if let angle = totalAngle(for: low) {
                lowAngle = angle
            } else {
                lowAngle = .infinity
            }
            if low < 1e-9 { break }
        }

        guard lowAngle.isFinite else {
            CircleStack.logDebug("findFirstRadius failed to locate finite lower bound from high=\(high)")
            return nil
        }

        if lowAngle - target > tolerance {
            CircleStack.logDebug("findFirstRadius lower bound still above target angle low=\(low) angle=\(lowAngle)")
            return nil
        }

        // Edge case: if even tiny circles are impossible, abort.
        if low == high {
            return nil
        }

        var result = high
        for _ in 0..<196 {
            let mid = (low + high) * 0.5
            if mid <= 0 { break }

            guard let angle = totalAngle(for: mid) else {
                high = mid
                continue
            }

            if abs(angle - target) <= tolerance {
                result = mid
                break
            }

            if angle > target {
                result = mid
                high = mid
            } else {
                result = mid
                low = mid
            }
        }

        guard let finalAngle = totalAngle(for: result) else {
            CircleStack.logError("findFirstRadius unable to evaluate final angle result=\(result)")
            return nil
        }

        let finalDelta = abs(finalAngle - target)
        guard finalDelta <= 1e-6 else {
            CircleStack.logError("findFirstRadius did not converge result=\(result) finalAngle=\(finalAngle)")
            return nil
        }

        CircleStack.logDebug("findFirstRadius succeeded radius=\(result) finalDelta=\(finalDelta)")
        return result
    }

    /// Creates the radii array and cumulative angles for placement.
    private func calculateRadiiAndAngles(
        firstRadius: Double,
        count: Int,
        effectiveRadius: Double,
        neighborGap: Double
    ) -> [(radius: CGFloat, angle: CGFloat)]? {
        let ratio = shrinkRatioDouble

        var radii: [Double] = []
        radii.reserveCapacity(count)
        for index in 0..<count {
            radii.append(firstRadius * pow(ratio, Double(index)))
        }

        var result: [(radius: CGFloat, angle: CGFloat)] = []
        result.reserveCapacity(count)

        var cumulative = 0.0
        result.append((CGFloat(radii[0]), 0))

        for index in 1..<count {
            guard let delta = calculateAngleBetween(
                radii[index - 1],
                radii[index],
                effectiveRadius: effectiveRadius,
                neighborGap: neighborGap
            ) else {
                return nil
            }
            cumulative += delta
            result.append((CGFloat(radii[index]), CGFloat(cumulative)))
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
    var spacing: CGFloat = 8
    var shrink: CGFloat = 0.1
    var rimPadding: CGFloat = 12
    var startAngle: Angle = .degrees(330)
    @ViewBuilder var content: () -> Content

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
            DemoAvatar(color: .blue, text: "HT")
        }

        CircleStackPreviewCard(
            title: "3 avatars"
        ) {
            DemoAvatar(color: .purple, text: "A")
            DemoAvatar(color: .blue, text: "HT")
            DemoAvatar(color: .orange, text: "B")
        }

        CircleStackPreviewCard(
            title: "4 avatars"
        ) {
            DemoAvatar(color: .pink, text: "AL")
            DemoAvatar(color: .teal, text: "BO")
            DemoAvatar(color: .indigo, text: "CY")
            DemoAvatar(color: .mint, text: "DJ")
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
            title: "Clockwise start @ 90°",
            spacing: 4,
            shrink: 0.15,
            rimPadding: 14,
            startAngle: .degrees(90)
        ) {
            DemoAvatar(color: .brown, text: "QH")
            DemoAvatar(color: .indigo, text: "RJ")
            DemoAvatar(color: .cyan, text: "SK")
            DemoAvatar(color: .orange, text: "TL")
        }
        CircleStackPreviewCard(
            title: "10 avatars, tight spacing",
            spacing: 2,
            shrink: 0.12,
            rimPadding: 10
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

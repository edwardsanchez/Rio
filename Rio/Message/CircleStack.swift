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
        guard let firstRadius = solveFirstRadius(
            effectiveRadius: Double(effectiveRadius),
            count: count,
            neighborGap: neighborGap
        ) else {
            CircleStack.logError("chain unable to solve first radius for count=\(count)")
            return nil
        }

        var radii: [Double] = []
        for index in 0..<count {
            radii.append(firstRadius * pow(shrinkRatioDouble, Double(index)))
        }

        let radiiDescription = radii.enumerated()
            .map { index, value in "i\(index)=\(value)" }
            .joined(separator: ", ")
        CircleStack.logDebug("chain radii: \(radiiDescription)")

        var result: [(radius: CGFloat, angle: CGFloat)] = []
        var cumulative: Double = 0

        result.append((CGFloat(radii[0]), 0))
        for index in 1..<count {
            guard let delta = angleBetween(
                radii[index - 1],
                radii[index],
                effectiveRadius: Double(effectiveRadius),
                neighborGap: neighborGap
            ) else {
                CircleStack.logError("chain angleBetween failed index=\(index) rPrev=\(radii[index - 1]) rNext=\(radii[index])")
                return nil
            }
            cumulative += delta
            result.append((CGFloat(radii[index]), CGFloat(cumulative)))
        }

        let anglesDescription = result.enumerated()
            .map { index, element in "i\(index)=\(Double(element.angle))" }
            .joined(separator: ", ")
        CircleStack.logDebug("chain angles: \(anglesDescription)")

        if let closing = angleBetween(
            radii[count - 1],
            radii[0],
            effectiveRadius: Double(effectiveRadius),
            neighborGap: neighborGap
        ) {
            let totalSweep = Double(result.last?.angle ?? 0) + closing
            CircleStack.logDebug(
                "chain closingAngle=\(closing) totalSweep=\(totalSweep) delta=\(totalSweep - 2 * Double.pi)"
            )
        }

        return result
    }

    /// Angle between two tangent circles that also touch the boundary circle.
    private func angleBetween(
        _ r1: Double,
        _ r2: Double,
        effectiveRadius: Double,
        neighborGap: Double
    ) -> Double? {
        let d1 = effectiveRadius - r1
        let d2 = effectiveRadius - r2
        guard d1 > 0, d2 > 0 else { return nil }

        let centerDistance = r1 + r2 + neighborGap
        let maxDistance = d1 + d2
        let minDistance = abs(d1 - d2)
        let tolerance = 1e-6 * max(1.0, max(centerDistance, maxDistance))

        if centerDistance - maxDistance > tolerance { return nil }
        if minDistance - centerDistance > tolerance { return nil }

        let numerator = d1 * d1 + d2 * d2 - centerDistance * centerDistance
        let denominator = 2 * d1 * d2
        guard denominator > 0 else { return nil }

        let value = numerator / denominator
        if value.isNaN { return nil }
        let clamped = max(-1.0, min(1.0, value))
        return acos(clamped)
    }

    /// Finds the first radius so the chain closes around the 2π sweep.
    private func solveFirstRadius(
        effectiveRadius: Double,
        count: Int,
        neighborGap: Double,
        tolerance: Double = 1e-9
    ) -> Double? {
        guard count >= 2 else { return max(0, effectiveRadius) }

        func totalAngle(for candidate: Double) -> Double? {
            var radii: [Double] = []
            for index in 0..<count {
                radii.append(candidate * pow(shrinkRatioDouble, Double(index)))
            }

            var sum = 0.0
            for index in 0..<(count - 1) {
                guard let delta = angleBetween(
                    radii[index],
                    radii[index + 1],
                    effectiveRadius: effectiveRadius,
                    neighborGap: neighborGap
                ) else {
                    CircleStack.logDebug("solveFirstRadius totalAngle failed @segment \(index) candidate=\(candidate) r1=\(radii[index]) r2=\(radii[index + 1])")
                    return nil
                }
                sum += delta
            }

            guard let closing = angleBetween(
                radii[count - 1],
                radii[0],
                effectiveRadius: effectiveRadius,
                neighborGap: neighborGap
            ) else {
                CircleStack.logDebug("solveFirstRadius closing angle failure candidate=\(candidate) rLast=\(radii[count - 1]) rFirst=\(radii[0])")
                return nil
            }

            return sum + closing
        }

        let theoreticalMax = max(1e-9, effectiveRadius * 0.99)
        var low = 0.0
        var high = theoreticalMax
        var result = theoreticalMax * 0.5

        for iteration in 0..<250 {
            let mid = (low + high) * 0.5
            guard mid > 0 else { break }

            guard let angle = totalAngle(for: mid) else {
                CircleStack.logDebug("solveFirstRadius totalAngle nil at mid=\(mid)")
                high = mid
                continue
            }

            let delta = angle - 2 * Double.pi
            result = mid

            if abs(delta) < tolerance {
                CircleStack.logDebug("solveFirstRadius converged mid=\(mid) iterations=\(iteration)")
                return mid
            }

            if delta > 0 {
                high = mid
            } else {
                low = mid
            }
        }

        guard let finalAngle = totalAngle(for: result) else {
            CircleStack.logError("solveFirstRadius unable to evaluate final angle at result=\(result)")
            return nil
        }

        let finalDelta = abs(finalAngle - 2 * Double.pi)
        if finalDelta < tolerance {
            CircleStack.logDebug("solveFirstRadius: result=\(result) finalDelta=\(finalDelta)")
            return result
        }

        CircleStack.logError("solveFirstRadius did not converge result=\(result) finalAngle=\(finalAngle)")
        return nil
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
                    rimPadding: rimPadding
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
//
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
    }
}

//
//  RadialLayout.swift
//  Rio
//
//  Created by Edward Sanchez on 10/21/25.
//

import SwiftUI

/// Custom layout that positions items in a circular arrangement around a center point
struct RadialLayout: Layout {
    var radius: CGFloat
    var menuIsShowing: Bool
    var itemCount: Int
    var itemSpacing: CGFloat
    var spacerCenterPercent: CGFloat
    var parentSize: CGSize

    struct AngleConfiguration {
        let angles: [CGFloat]
        let angleIncrement: CGFloat
        let gapArc: CGFloat
    }

    init(
        radius: CGFloat,
        menuIsShowing: Bool = false,
        itemCount: Int,
        itemSpacing: CGFloat,
        spacerCenterPercent: CGFloat,
        parentSize: CGSize
    ) {
        self.radius = radius
        self.menuIsShowing = menuIsShowing
        self.itemCount = itemCount
        self.itemSpacing = itemSpacing
        self.spacerCenterPercent = spacerCenterPercent
        self.parentSize = parentSize
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        // Container size needs to accommodate the full circle plus item sizes
        return CGSize(width: radius * 2, height: radius * 2)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let count = subviews.count
        guard count > 0 else { return }

        let angleConfiguration = RadialLayout.calculateAngles(
            radius: radius,
            itemCount: count,
            itemSpacing: itemSpacing,
            spacerCenterPercent: spacerCenterPercent
        )
        let angles = angleConfiguration.angles
        guard angles.count == count else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let parentWidth = parentSize.width
        let parentHeight = parentSize.height
        let collapsedPadding: CGFloat = 10
        let itemSize = subviews.first?.sizeThatFits(.unspecified) ?? .zero
        let itemWidth = itemSize.width
        let itemHeight = itemSize.height
        let marginX = itemWidth / 2 + collapsedPadding
        let marginY = itemHeight / 2 + collapsedPadding
        let parentOriginX = center.x - parentWidth / 2
        let parentOriginY = center.y - parentHeight / 2
        let collapsedDenominator = max(count - 1, 1)
        let distributeHorizontally = parentWidth >= parentHeight

        for (index, subview) in subviews.enumerated() {
            let angle = angles[index]
            let radians = angle * .pi / 180.0
            let currentRadius = menuIsShowing ? radius : 0
            let progress = count > 1 ? CGFloat(index) / CGFloat(collapsedDenominator) : 0.5
            let availableWidth = max(parentWidth - marginX * 2, 0)
            let relativeX = marginX + availableWidth * progress
            let distributedX = parentOriginX + relativeX
            let availableHeight = max(parentHeight - marginY * 2, 0)
            let relativeY = marginY + availableHeight * progress
            let distributedY = parentOriginY + relativeY

            // Calculate position using polar coordinates
            // When menu is hidden, all items are at center; when shown, they move to their positions
            let defaultY = center.y + currentRadius * sin(radians)
            let defaultX = center.x + radius * cos(radians)
            let collapsedX: CGFloat
            let collapsedY: CGFloat
            
            if !menuIsShowing {
                if distributeHorizontally,
                   parentWidth > marginX * 2,
                   parentWidth > 0,
                   itemWidth > 0 {
                    collapsedX = distributedX
                    collapsedY = center.y
                } else if !distributeHorizontally,
                          parentHeight > marginY * 2,
                          parentHeight > 0,
                          itemHeight > 0 {
                    collapsedX = center.x
                    collapsedY = distributedY
                } else {
                    collapsedX = center.x
                    collapsedY = center.y
                }
            } else {
                collapsedX = center.x
                collapsedY = center.y
            }
            let x = menuIsShowing ? defaultX : collapsedX
            let y = menuIsShowing ? defaultY : collapsedY

            // Place the subview at the calculated position
            subview.place(at: CGPoint(x: x, y: y), anchor: .center, proposal: .unspecified)
        }
    }

    static func calculateAngles(
        radius: CGFloat,
        itemCount: Int,
        itemSpacing: CGFloat,
        spacerCenterPercent: CGFloat
    ) -> AngleConfiguration {
        guard radius > 0, itemCount > 0 else {
            return AngleConfiguration(angles: [], angleIncrement: 0, gapArc: 0)
        }

        let safeRadius = max(radius, 0.001)
        let maxChordLength = 2 * safeRadius
        let clampedSpacing = min(itemSpacing, maxChordLength * 0.999)
        let spacingRatio = max(0, min(clampedSpacing / maxChordLength, 1))
        var angleIncrement = spacingRatio > 0
            ? (2 * asin(spacingRatio)) * 180 / .pi
            : 360 / CGFloat(itemCount)

        if angleIncrement.isNaN || angleIncrement.isInfinite || angleIncrement <= 0 {
            angleIncrement = 360 / CGFloat(itemCount)
        }

        var usedArc = angleIncrement * CGFloat(itemCount)
        if usedArc > 360 || usedArc.isNaN || usedArc.isInfinite {
            angleIncrement = 360 / CGFloat(itemCount)
            usedArc = angleIncrement * CGFloat(itemCount)
        }

        var gapArc = max(0, 360 - usedArc)
        let maxGapArc = 360 * 0.9
        if gapArc > maxGapArc {
            gapArc = maxGapArc
        }

        let spacerCenterAngle = (spacerCenterPercent * 360) - 90
        let arcStartAngle = spacerCenterAngle + (gapArc / 2)
        let startAngle = arcStartAngle + (angleIncrement / 2)

        let angles = (0..<itemCount).map { index in
            startAngle + (CGFloat(index) * angleIncrement)
        }

        return AngleConfiguration(
            angles: angles,
            angleIncrement: angleIncrement,
            gapArc: gapArc
        )
    }
}

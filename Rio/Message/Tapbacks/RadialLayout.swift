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
    
    /// Calculated spacer percentage based on item count and spacing
    private var spacerPercentage: CGFloat {
        let circumference = 2 * .pi * radius
        let totalItemSpacing = CGFloat(itemCount) * itemSpacing
        let spacerArc = max(0, circumference - totalItemSpacing)
        return min(0.9, max(0, spacerArc / circumference)) // Clamp between 0 and 0.9
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
}

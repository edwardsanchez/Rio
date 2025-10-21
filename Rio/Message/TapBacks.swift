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

struct TapBacksModifier: ViewModifier {
    @State private var menuIsShowing = true
    @State private var viewSize: CGSize = .zero
    @State private var viewFrame: CGRect = .zero
    @State private var tapLocation: CGPoint = .zero
    @State private var screenWidth: CGFloat = 0
    
    var messageID: UUID
    var reactions: [String]
    var onReactionSelected: (String) -> Void
    
    // MARK: - Continuous Layout Parameters
    
    private let widthMinimum: CGFloat = 30
    private let widthMaximum: CGFloat = 300
    private let tallHeightMinimum: CGFloat = 160
    private let tallHeightMaximum: CGFloat = 320
    private let sideSpacer: CGFloat = 0.75
    private let topSpacer: CGFloat = 0.5
    private let sideRadius: CGFloat = 100
    private let edgePadding: CGFloat = 80
    private let reactionSpacing: CGFloat = 44
    
    private struct ReactionBounds {
        var minX: CGFloat
        var maxX: CGFloat
        var minY: CGFloat
        var maxY: CGFloat
    }
    
    private var widthProgress: CGFloat {
        guard widthMaximum > widthMinimum else { return 0 }
        let interpolator = ValueInterpolator(
            inputMin: widthMinimum,
            inputMax: widthMaximum,
            outputMin: 0,
            outputMax: 1
        )
        return clamp(interpolator.interpolateFrom(input: viewSize.width))
    }
    
    private var narrowProgress: CGFloat {
        1 - widthProgress
    }
    
    private var tallProgress: CGFloat {
        guard tallHeightMaximum > tallHeightMinimum else { return 0 }
        let interpolator = ValueInterpolator(
            inputMin: tallHeightMinimum,
            inputMax: tallHeightMaximum,
            outputMin: 0,
            outputMax: 1
        )
        let heightFactor = clamp(interpolator.interpolateFrom(input: viewSize.height))
        return clamp(heightFactor * narrowProgress)
    }
    
    private var calculatedRadius: CGFloat {
        let wideRadius = max(400, viewSize.height * 1.5)
        var widthRadius = lerp(from: sideRadius, to: wideRadius, progress: widthProgress)
        let shrinkFactor: CGFloat = 1
        widthRadius -= (widthRadius - sideRadius) * cornerRadiusWeight * shrinkFactor
        widthRadius = max(widthRadius, sideRadius)
        let tallRadius = max(300, viewSize.height * 0.8)
        return lerp(from: widthRadius, to: tallRadius, progress: tallProgress)
    }
    
    private var calculatedSpacerCenterPercent: CGFloat {
        lerp(from: sideSpacer, to: topSpacer, progress: widthProgress)
    }
    
    private var calculatedOffset: CGSize {
        guard menuIsShowing else {
            return .zero
        }
        
        guard let bounds = reactionBounds() else {
            return .zero
        }
        
        let targetRight = viewSize.width / 2 + edgePadding
        let targetTop = -viewSize.height / 2 - edgePadding
        
        let sideDifference = targetRight - bounds.maxX
        let topDifference = targetTop - bounds.minY
        
        let sideWeight = sideAlignmentWeight(for: widthProgress)
        let topWeight = topAlignmentWeight(for: widthProgress)
        
        var offset = CGSize(
            width: sideDifference * sideWeight,
            height: topDifference * topWeight
        )
        
        let rightmostAfterOffset = bounds.maxX + offset.width
        if rightmostAfterOffset > targetRight {
            offset.width += targetRight - rightmostAfterOffset
        }
        
        let topmostAfterOffset = bounds.minY + offset.height
        if topmostAfterOffset < targetTop {
            offset.height += targetTop - topmostAfterOffset
        }
        
        return offset
    }
    
    private func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
    
    private func lerp(from start: CGFloat, to end: CGFloat, progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }
    
    private var cornerRadiusWeight: CGFloat {
        let peak = 1 - abs(widthProgress - 0.5) * 1
        return clamp(peak) * (1 - tallProgress)
    }
    
    private func reactionAngles() -> [CGFloat] {
        let radius = calculatedRadius
        guard radius > 0, reactions.isEmpty == false else { return [] }
        
        let count = reactions.count
        let circumference = 2 * .pi * radius
        let totalSpacing = CGFloat(count) * reactionSpacing
        let rawSpacerArc = circumference > 0 ? (circumference - totalSpacing) / circumference : 0
        let spacerPercentage = min(0.9, max(0, rawSpacerArc))
        let availableArc = 360.0 * (1.0 - spacerPercentage)
        let angleIncrement = count > 0 ? availableArc / CGFloat(count) : 0
        let spacerCenterAngle = (calculatedSpacerCenterPercent * 360.0) - 90.0
        let spacerArc = 360.0 * spacerPercentage
        let arcStartAngle = spacerCenterAngle + (spacerArc / 2.0)
        let startAngle = arcStartAngle + (angleIncrement / 2.0)
        
        return (0..<count).map { index in
            startAngle + (CGFloat(index) * angleIncrement)
        }
    }
    
    private func reactionBounds() -> ReactionBounds? {
        let angles = reactionAngles()
        guard angles.isEmpty == false else { return nil }
        
        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        
        for angle in angles {
            let radians = angle * .pi / 180.0
            let x = calculatedRadius * cos(radians)
            let y = calculatedRadius * sin(radians)
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
        }
        
        return ReactionBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY)
    }
    
    private func sideAlignmentWeight(for progress: CGFloat) -> CGFloat {
        if progress <= 0.5 {
            return 1
        }
        let normalized = (1 - progress) / 0.5
        return clamp(normalized)
    }
    
    private func topAlignmentWeight(for progress: CGFloat) -> CGFloat {
        if progress >= 0.5 {
            let normalized = (progress - 0.5) / 0.5
            return clamp(normalized)
        }
        return 0
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(menuIsShowing ? 1.1 : 1, anchor: UnitPoint(x: 0.2, y: 0.5))
            .animation(.smooth(duration: 0.4), value: menuIsShowing)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                viewSize = newSize
            }
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { newFrame in
                viewFrame = newFrame
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { width in
                screenWidth = width
            }
            .background(
                RadialLayout(
                    radius: calculatedRadius,
                    menuIsShowing: menuIsShowing,
                    itemCount: reactions.count,
                    itemSpacing: reactionSpacing,
                    spacerCenterPercent: calculatedSpacerCenterPercent,
                    parentSize: viewSize
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
                .offset(calculatedOffset)
                .animation(.bouncy(duration: 0.4), value: menuIsShowing)
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        tapLocation = value.location
                        menuIsShowing.toggle()
                    }
            )
    }
}

extension View {
    func tapBacks(
        messageID: UUID,
        reactions: [String] = ["❤️", "👍", "😂", "😮", "😢", "🔥"],
        onReactionSelected: @escaping (String) -> Void = { reaction in
            print("Selected reaction: \(reaction)")
        }
    ) -> some View {
        modifier(
            TapBacksModifier(
                messageID: messageID,
                reactions: reactions,
                onReactionSelected: onReactionSelected
            )
        )
    }
}

struct TapBackTestView: View {
    @State private var demoWidth: Double = 220
    @State private var demoHeight: Double = 120

    var body: some View {
        VStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Demo Message")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                RoundedRectangle(cornerRadius: 10)
                    .fill(.green)
                    .frame(width: CGFloat(demoWidth), height: CGFloat(demoHeight))
                    .containerShape(.rect)
                    .glassEffect(.regular.interactive(), in: .rect)
                    .tapBacks(messageID: UUID()) { reaction in
                        print("Tapped: \(reaction)")
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Width: \(Int(demoWidth))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $demoWidth, in: 30...300)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Height: \(Int(demoHeight))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $demoHeight, in: 30...300)
                }
            }
            .padding(.horizontal)
        }
        .frame(maxHeight: .infinity)
    }
}

#Preview {
    TapBackTestView()
}

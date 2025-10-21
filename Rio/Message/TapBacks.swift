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
    @State private var lastLoggedSize: CGSize = .zero
    
    var messageID: UUID
    var reactions: [String]
    var onReactionSelected: (String) -> Void
    
    // MARK: - Layout Cases

    enum LayoutCase: String, CaseIterable {
        case narrowShort = "Narrow + Short"
        case narrowTall = "Narrow + Tall"
        case mediumCorner = "Medium (Corner)"
        case wideTop = "Wide (Top)"

        var thresholds: (widthMin: CGFloat, widthMax: CGFloat, heightMin: CGFloat, heightMax: CGFloat) {
            switch self {
            case .narrowShort:
                return (0, 80, 0, 120)
            case .narrowTall:
                return (0, 80, 120, .infinity)
            case .mediumCorner:
                return (80, 220, 0, .infinity)
            case .wideTop:
                return (220, .infinity, 0, .infinity)
            }
        }

        var config: LayoutConfig {
            switch self {
            case .narrowShort:
                return LayoutConfig(
                    radius: 80,
                    spacerCenterPercent: 0.75, // 270° - right side
                    offsetX: 0,
                    offsetY: 0
                )
            case .narrowTall:
                return LayoutConfig(
                    radius: 300,
                    spacerCenterPercent: 0.75, // 270° - right side
                    offsetX: -200,
                    offsetY: 0
                )
            case .mediumCorner:
                return LayoutConfig(
                    radius: 100,
                    spacerCenterPercent: 0.625, // 135° - top-right corner
                    offsetX: 35,
                    offsetY: -35
                )
            case .wideTop:
                return LayoutConfig(
                    radius: 300,
                    spacerCenterPercent: 0.5, // 180° - top
                    offsetX: 0,
                    offsetY: 120
                )
            }
        }
    }

    struct LayoutConfig {
        var radius: CGFloat
        var spacerCenterPercent: CGFloat
        var offsetX: CGFloat
        var offsetY: CGFloat
    }

    private let reactionSpacing: CGFloat = 44
    private let logInterval: CGFloat = 5
    
    private struct ReactionBounds {
        var minX: CGFloat
        var maxX: CGFloat
        var minY: CGFloat
        var maxY: CGFloat
    }
    
    // MARK: - Layout Detection

    private func detectLayoutCase() -> LayoutCase {
        let w = viewSize.width
        let h = viewSize.height

        // Check each case in priority order
        for layoutCase in LayoutCase.allCases {
            let thresholds = layoutCase.thresholds
            if w >= thresholds.widthMin && w < thresholds.widthMax &&
               h >= thresholds.heightMin && h < thresholds.heightMax {
                return layoutCase
            }
        }

        // Default to wideTop if no match
        return .wideTop
    }

    private var currentConfig: LayoutConfig {
        detectLayoutCase().config
    }

    private var calculatedRadius: CGFloat {
        currentConfig.radius
    }

    private var calculatedSpacerCenterPercent: CGFloat {
        currentConfig.spacerCenterPercent
    }

    private var calculatedOffset: CGSize {
        guard menuIsShowing else {
            return .zero
        }
        return CGSize(width: currentConfig.offsetX, height: currentConfig.offsetY)
    }
    
    // MARK: - Debug Logging

    private func shouldLog(for size: CGSize) -> Bool {
        let widthBucket = floor(size.width / logInterval) * logInterval
        let heightBucket = floor(size.height / logInterval) * logInterval
        return abs(widthBucket - lastLoggedSize.width) >= logInterval ||
               abs(heightBucket - lastLoggedSize.height) >= logInterval
    }

    private func logGeometry(for size: CGSize) {
        let w = size.width
        let h = size.height
        let layoutCase = detectLayoutCase()
        let config = layoutCase.config

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Size: \(Int(w))×\(Int(h))")
        print("Layout Case: \(layoutCase.rawValue)")
        print("Radius: \(String(format: "%.1f", config.radius))")
        print("Offset: (\(String(format: "%.1f", config.offsetX)), \(String(format: "%.1f", config.offsetY)))")
        print("Spacer: \(String(format: "%.2f", config.spacerCenterPercent)) (\(String(format: "%.0f", config.spacerCenterPercent * 360 - 90))°)")
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

    func body(content: Content) -> some View {
        content
            .scaleEffect(menuIsShowing ? 1.1 : 1, anchor: UnitPoint(x: 0.2, y: 0.5))
            .animation(.smooth(duration: 0.4), value: menuIsShowing)
            .onGeometryChange(for: CGSize.self) { proxy in
                proxy.size
            } action: { newSize in
                viewSize = newSize
                if shouldLog(for: newSize) {
                    logGeometry(for: newSize)
                    let widthBucket = floor(newSize.width / logInterval) * logInterval
                    let heightBucket = floor(newSize.height / logInterval) * logInterval
                    lastLoggedSize = CGSize(width: widthBucket, height: heightBucket)
                }
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
    @State private var demoWidth: Double = 250
    @State private var demoHeight: Double = 200

    private let testCases: [(String, CGFloat, CGFloat)] = [
        ("Narrow + Short", 60, 80),
        ("Narrow + Tall", 60, 200),
        ("Medium (Corner)", 150, 150),
        ("Wide (Top)", 250, 80)
    ]

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
                Text("Test Cases")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(testCases, id: \.0) { testCase in
                        Button {
                            demoWidth = testCase.1
                            demoHeight = testCase.2
                        } label: {
                            VStack(spacing: 4) {
                                Text(testCase.0)
                                    .font(.caption)
                                Text("\(Int(testCase.1))×\(Int(testCase.2))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()
                    .padding(.vertical, 8)

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

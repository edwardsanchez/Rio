//
//  TapBacks.swift
//  Rio
//
//  Created by Edward Sanchez on 10/20/25.
//

import SwiftUI

struct ReactionsModifier: ViewModifier {
    @State private var menuIsShowing = true
    @State private var viewSize: CGSize = .zero
    @State private var viewFrame: CGRect = .zero
    @State private var tapLocation: CGPoint = .zero
    @State private var screenWidth: CGFloat = 0
    @State private var lastLoggedSize: CGSize = .zero

    @Namespace private var reactionNamespace
    @State private var selectedReactionID: Reaction.ID?

    var messageID: UUID
    var reactions: [Reaction]
    var onReactionSelected: (Int) -> Void

    private var selectedReaction: Reaction? {
        guard let selectedReactionID else { return nil }
        return reactions.first { $0.id == selectedReactionID }
    }

    private var selectedEmoji: String? {
        selectedReaction?.selectedEmoji
    }

    static var defaultReactions: [Reaction] {
        [
            .emoji("❤️"),
            .emoji("👍"),
            .emoji("😂"),
            .emoji("😮"),
            .emoji("😢"),
            .emoji("🔥"),
            .systemImage("face.dashed", selectedEmoji: "?")
        ]
    }

    private let reactionSpacing: CGFloat = 50
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

        let layoutCase = detectLayoutCase()
        let config = layoutCase.config
        let baseOffset = config.baseOffset(for: viewSize)
        let horizontalAdjustment = config.horizontalAnchor.xOffset(for: viewSize)
        let verticalAdjustment = config.verticalAnchor.yOffset(for: viewSize)
        return CGSize(
            width: baseOffset.width + horizontalAdjustment,
            height: baseOffset.height + verticalAdjustment
        )
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
        let baseOffset = config.baseOffset(for: size)
        let horizontalAdjustment = config.horizontalAnchor.xOffset(for: size)
        let verticalAdjustment = config.verticalAnchor.yOffset(for: size)
        let horizontalDescription: String
        let verticalDescription: String
        let angleConfiguration = RadialLayout.calculateAngles(
            radius: config.radius,
            itemCount: reactions.count,
            itemSpacing: reactionSpacing,
            spacerCenterPercent: config.spacerCenterPercent
        )

        switch config.horizontalAnchor {
        case .center:
            horizontalDescription = "center"
        case .leading:
            horizontalDescription = "leading"
        case .trailing:
            horizontalDescription = "trailing"
        }

        switch config.verticalAnchor {
        case .center:
            verticalDescription = "center"
        case .top:
            verticalDescription = "top"
        case .bottom:
            verticalDescription = "bottom"
        }

        let effectiveX = baseOffset.width + horizontalAdjustment
        let effectiveY = baseOffset.height + verticalAdjustment

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Size: \(Int(w))×\(Int(h))")
        print("Layout Case: \(layoutCase.rawValue)")
        print("Radius: \(String(format: "%.1f", config.radius))")
        print("Base Offset: (\(String(format: "%.1f", baseOffset.width)), \(String(format: "%.1f", baseOffset.height)))")
        print("Anchors: x=\(horizontalDescription) (\(String(format: "%.1f", horizontalAdjustment))), y=\(verticalDescription) (\(String(format: "%.1f", verticalAdjustment)))")
        print("Effective Offset: (\(String(format: "%.1f", effectiveX)), \(String(format: "%.1f", effectiveY)))")
        if angleConfiguration.angleIncrement > 0 {
            print("Angle Increment: \(String(format: "%.1f", angleConfiguration.angleIncrement))°")
        }
        if angleConfiguration.gapArc > 0 {
            print("Gap Arc: \(String(format: "%.1f", angleConfiguration.gapArc))°")
        }
        print("Spacer: \(String(format: "%.2f", config.spacerCenterPercent)) (\(String(format: "%.0f", config.spacerCenterPercent * 360 - 90))°)")
    }
    
    private func reactionAngles() -> [CGFloat] {
        guard reactions.isEmpty == false else { return [] }

        let configuration = RadialLayout.calculateAngles(
            radius: calculatedRadius,
            itemCount: reactions.count,
            itemSpacing: reactionSpacing,
            spacerCenterPercent: calculatedSpacerCenterPercent
        )
        return configuration.angles
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
            .overlay(alignment: .topTrailing) {
                if let reaction = selectedReaction {
                    reactionButton(for: reaction, isOverlay: true) {
                        // Will show who reacted
                    }
                }
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
                        ForEach(Array(reactions.enumerated()), id: \.element.id) { index, reaction in
                            reactionButton(for: reaction, isOverlay: false) {
                                onReactionSelected(index)
                                selectedReactionID = reaction.id
                                menuIsShowing = false
                            }
                            .animation(
                                .interpolatingSpring(menuIsShowing ? .bouncy : .smooth, initialVelocity: menuIsShowing ? 0 : -10)
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

    @ViewBuilder
    private func reactionButton(for reaction: Reaction, isOverlay: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            reactionBubble(for: reaction, isOverlay: isOverlay)
        }
        .glassEffect(menuIsShowing ? .regular : .clear, in: .circle)
        .matchedGeometryEffect(
            id: reaction.id,
            in: reactionNamespace,
            isSource: matchedGeometryIsSource(for: reaction, isOverlay: isOverlay)
        )
        .offset(x: isOverlay ? 20 : 0, y: isOverlay ? -20 : 0)
        .opacity(reactionOpacity(for: reaction, isOverlay: isOverlay))
        .animation(.none, value: selectedReactionID)
    }

    private func reactionBubble(for reaction: Reaction, isOverlay: Bool) -> some View {
        Circle()
            .fill(.clear)
            .frame(width: 44, height: 44)
            .overlay(
                reactionContent(for: reaction)
            )
    }

    private func reactionOpacity(for reaction: Reaction, isOverlay: Bool) -> Double {
        if isOverlay {
            return overlayOpacity(for: reaction)
        }
        return menuOpacity(for: reaction)
    }

    private func menuOpacity(for reaction: Reaction) -> Double {
        guard menuIsShowing else { return 0 }
        return selectedReactionID == reaction.id ? 0 : 1
    }

    private func overlayOpacity(for reaction: Reaction) -> Double {
        guard selectedReactionID == reaction.id else { return 0 }
        return 1
    }

    private func matchedGeometryIsSource(for reaction: Reaction, isOverlay: Bool) -> Bool {
        guard selectedReactionID == reaction.id else {
            return !isOverlay
        }
        return isOverlay ? !menuIsShowing : menuIsShowing
    }

    @ViewBuilder
    private func reactionContent(for reaction: Reaction) -> some View {
        switch reaction.display {
        case let .emoji(value, fontSize):
            Text(value)
                .font(.system(size: fontSize))
        case let .systemImage(name, pointSize, weight):
            Image(systemName: name)
                .font(.system(size: pointSize, weight: weight))
        }
    }
}

extension View {
    func reactions(
        messageID: UUID,
        reactions: [Reaction] = ReactionsModifier.defaultReactions,
        onReactionSelected: @escaping (Int) -> Void = { index in
            print("Selected reaction index: \(index)")
        }
    ) -> some View {
        modifier(
            ReactionsModifier(
                messageID: messageID,
                reactions: reactions,
                onReactionSelected: onReactionSelected
            )
        )
    }
}

// MARK: - Layout Cases

enum LayoutCase: String, CaseIterable {
    case narrowShort = "Narrow + Short"
    case narrowTall = "Narrow + Tall"
    case mediumCorner = "Medium (Corner)"
    case wideTop = "Wide (Top)"
    // I think we'll need another case for when it's short and medium eventually.

    var thresholds: (widthMin: CGFloat, widthMax: CGFloat, heightMin: CGFloat, heightMax: CGFloat) {
        switch self {
        case .narrowShort:
            return (0, 95, 0, 80)
        case .narrowTall:
            return (0, 95, 80, .infinity)
        case .mediumCorner:
            return (95, 250, 0, .infinity)
        case .wideTop:
            return (250, .infinity, 0, .infinity)
        }
    }

    var config: LayoutConfig {
        switch self {
        case .narrowShort:
            return LayoutConfig(
                radius: 80,
                spacerCenterPercent: 0.75, // 270° - right side
                horizontalAnchor: .trailing,
                verticalAnchor: .center
            ) { size in
                let baseX: CGFloat = size.width > 65 ? -25 : 10
                return CGSize(width: baseX, height: 0)
            }
        case .narrowTall:
            return LayoutConfig(
                radius: 500,
                spacerCenterPercent: 0.75, // 270° - right side
                horizontalAnchor: .trailing,
                verticalAnchor: .center
            ) { _ in
                CGSize(width: -435, height: 0)
            }
        case .mediumCorner:
            return LayoutConfig(
                radius: 100,
                spacerCenterPercent: 0.625, // 135° - top-right corner
                horizontalAnchor: .trailing,
                verticalAnchor: .top
            ) { _ in
                CGSize(width: -30, height: 30)
            }
        case .wideTop:
            return LayoutConfig(
                radius: 600,
                spacerCenterPercent: 0.51, // 180° - top
                horizontalAnchor: .leading,
                verticalAnchor: .top
            ) { _ in
                CGSize(width: 140, height: 540)
            }
        }
    }
}

struct Reaction: Identifiable, Equatable {
    static func == (lhs: Reaction, rhs: Reaction) -> Bool {
        lhs.id == rhs.id
    }

    enum Display {
        case emoji(value: String, fontSize: CGFloat)
        case systemImage(name: String, pointSize: CGFloat, weight: Font.Weight)
    }

    let id: String
    let display: Display
    let selectedEmoji: String

    static func emoji(_ value: String) -> Reaction {
        Reaction(
            id: value,
            display: .emoji(value: value, fontSize: 24),
            selectedEmoji: value
        )
    }

    static func systemImage(
        _ name: String,
        pointSize: CGFloat = 20,
        weight: Font.Weight = .medium,
        selectedEmoji: String
    ) -> Reaction {
        Reaction(
            id: name,
            display: .systemImage(name: name, pointSize: pointSize, weight: weight),
            selectedEmoji: selectedEmoji
        )
    }
}

enum HorizontalAnchor {
    case center
    case leading
    case trailing

    func xOffset(for size: CGSize) -> CGFloat {
        switch self {
        case .center:
            return 0
        case .leading:
            return -size.width / 2
        case .trailing:
            return size.width / 2
        }
    }
}

enum VerticalAnchor {
    case center
    case top
    case bottom

    func yOffset(for size: CGSize) -> CGFloat {
        switch self {
        case .center:
            return 0
        case .top:
            return -size.height / 2
        case .bottom:
            return size.height / 2
        }
    }
}

struct LayoutConfig {
    var radius: CGFloat
    var spacerCenterPercent: CGFloat
    var horizontalAnchor: HorizontalAnchor
    var verticalAnchor: VerticalAnchor
    private let offsetProvider: (CGSize) -> CGSize

    init(
        radius: CGFloat,
        spacerCenterPercent: CGFloat,
        horizontalAnchor: HorizontalAnchor,
        verticalAnchor: VerticalAnchor,
        offsetProvider: @escaping (CGSize) -> CGSize
    ) {
        self.radius = radius
        self.spacerCenterPercent = spacerCenterPercent
        self.horizontalAnchor = horizontalAnchor
        self.verticalAnchor = verticalAnchor
        self.offsetProvider = offsetProvider
    }

    func baseOffset(for size: CGSize) -> CGSize {
        offsetProvider(size)
    }
}

fileprivate struct TapBackTestView: View {
    @State private var demoWidth: Double = 250
    @State private var demoHeight: Double = 150

    private let testCases: [(String, CGFloat, CGFloat)] = [
        ("Narrow + Short", 60, 60),
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
                    .frame(width: demoWidth, height: demoHeight)
                    .containerShape(.rect)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 10))
                    .reactions(messageID: UUID()) { index in
                        print("Tapped reaction index: \(index)")
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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

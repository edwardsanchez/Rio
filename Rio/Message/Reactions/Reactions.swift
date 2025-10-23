//
//  Reactions.swift
//  Rio
//
//  Created by Edward Sanchez on 10/20/25.
//

import SwiftUI

struct ReactionsModifier: ViewModifier {
    @Environment(ChatData.self) private var chatData
    @State private var menuIsShowing = false
    @State private var viewSize: CGSize = .zero

    @Namespace private var reactionNamespace
    @State private var selectedReactionID: Reaction.ID?
    @State private var showBackgroundMenu = false

    var messageID: UUID
    var reactions: [Reaction]
    var isEnabled: Bool

    private var selectedReaction: Reaction? {
        guard let selectedReactionID else { return nil }
        return reactions.first { $0.id == selectedReactionID }
    }

    static var defaultReactions: [Reaction] {
        [
            .emoji("😍"),
            .emoji("👍"),
            .emoji("👎"),
            .emoji("😂"),
            .emoji("😲"),
            .emoji("🧐"),
            .systemImage("face.dashed", selectedEmoji: "?")
        ]
    }

    private let reactionSpacing: CGFloat = 50

    // Centralizes timing multipliers so related animations stay in sync.
    private enum AnimationTiming {
        static let baseDuration: TimeInterval = 0.4
        static let reactionStaggerStepMultiplier: Double = 0.125
        static let backgroundShowDelayMultiplier: Double = 0.5
        static let reactionHideDelayMultiplier: Double = 0.25
        static let backgroundFadeDurationMultiplier: Double = 0.875

        static var reactionStaggerStep: TimeInterval {
            baseDuration * reactionStaggerStepMultiplier
        }

        static var backgroundShowDelay: TimeInterval {
            baseDuration * backgroundShowDelayMultiplier
        }

        static var reactionHideDelay: TimeInterval {
            baseDuration * reactionHideDelayMultiplier
        }

        static var menuScaleAnimation: Animation {
            .interpolatingSpring(duration: baseDuration, bounce: 0.5, initialVelocity: -20)
        }

        static var menuOffsetAnimation: Animation {
            .bouncy(duration: baseDuration)
        }

        static func backgroundFadeAnimation(isShowing: Bool, additionalDelay: TimeInterval = 0) -> Animation {
            let base = Animation.easeInOut(duration: baseDuration * backgroundFadeDurationMultiplier)
            let delay = (isShowing ? backgroundShowDelay : 0) + additionalDelay
            return delay == 0 ? base : base.delay(delay)
        }
    }

    // MARK: - Layout Detection

    private var layoutCase: LayoutCase {
        LayoutCase.matching(for: viewSize)
    }

    private var currentConfig: LayoutConfig {
        layoutCase.config
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

        let config = layoutCase.config
        let baseOffset = config.baseOffset(for: viewSize)
        let horizontalAdjustment = config.horizontalAnchor.xOffset(for: viewSize)
        let verticalAdjustment = config.verticalAnchor.yOffset(for: viewSize)
        return CGSize(
            width: baseOffset.width + horizontalAdjustment,
            height: baseOffset.height + verticalAdjustment
        )
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content
                .scaleEffect(menuIsShowing ? 1.1 : 1, anchor: UnitPoint(x: 0.2, y: 0.5))
                .animation(AnimationTiming.menuScaleAnimation, value: menuIsShowing)
                .onGeometryChange(for: CGSize.self) { proxy in
                    proxy.size
                } action: { newSize in
                    viewSize = newSize
                }
                .overlay(alignment: .topTrailing) {
                    if let selectedReaction {
                        //Here only for the purposes of geometry matching
                        reactionButton(
                            for: selectedReaction,
                            isVisible: false,
                            isOverlay: true,
                            isSelected: false
                        ) {}
                            .allowsHitTesting(false)
                    }
                }
                .background(
                    menuView(isOverlay: false)
                        .opacity(showBackgroundMenu ? 1 : 0)
                )
                .background {
                    if menuIsShowing {
                        Color.black.opacity(0.5)
                            .frame(width: 10000, height: 10000, alignment: .center) //FIXME: This is likely not the proper way to do this.
                            .contentShape(.rect)
                            .onTapGesture {
                                menuIsShowing = false
                                setBackgroundMenuVisible(menuIsShowing)
                            }
                            .transition(.opacity.animation(.easeIn(duration: 0.2)))
                    }
                }
                .overlay {
                    menuView(isOverlay: true)
                }
                .onTapGesture {
                    menuIsShowing = false
                    setBackgroundMenuVisible(menuIsShowing)
                }
                .onLongPressGesture {
                    menuIsShowing = true
                    setBackgroundMenuVisible(menuIsShowing)
                }
                .sensoryFeedback(.impact, trigger: menuIsShowing)
                .onChange(of: menuIsShowing) { _, newValue in
                    chatData.isChatScrollDisabled = newValue
                    if newValue {
                        chatData.activeReactionMessageID = messageID
                    } else if chatData.activeReactionMessageID == messageID {
                        chatData.activeReactionMessageID = nil
                    }
                }
                .onDisappear {
                    if chatData.isChatScrollDisabled {
                        chatData.isChatScrollDisabled = false
                    }
                    if chatData.activeReactionMessageID == messageID {
                        chatData.activeReactionMessageID = nil
                    }
                }
        } else {
            content
        }
    }

    @ViewBuilder
    private func menuView(isOverlay: Bool) -> some View {
        RadialLayout(
            radius: calculatedRadius,
            menuIsShowing: menuIsShowing,
            itemCount: reactions.count,
            itemSpacing: reactionSpacing,
            spacerCenterPercent: calculatedSpacerCenterPercent,
            parentSize: viewSize
        ) {
            ForEach(Array(reactions.enumerated()), id: \.element.id) { index, reaction in
                reactionButton(
                    for: reaction,
                    isVisible: (selectedReaction != reaction) != isOverlay,
                    isOverlay: isOverlay,
                    isSelected: selectedReaction == reaction
                ) {
                    let isSameReaction = selectedReactionID == reaction.id
                    if menuIsShowing {
                        selectedReactionID = isSameReaction ? nil : reaction.id
                        menuIsShowing = false

                        setBackgroundMenuVisible(false, delay: AnimationTiming.reactionHideDelay)
                    } else {
                        menuIsShowing = true
                        setBackgroundMenuVisible(menuIsShowing)
                    }
                }
                .animation(
                    .interpolatingSpring(menuIsShowing ? .bouncy : .smooth, initialVelocity: menuIsShowing ? 0 : -5)
                    .delay(Double(index) * AnimationTiming.reactionStaggerStep),
                    value: menuIsShowing
                )
            }
        }
        .offset(calculatedOffset)
        .animation(AnimationTiming.menuOffsetAnimation, value: menuIsShowing)
    }

    private func setBackgroundMenuVisible(_ value: Bool, delay: TimeInterval = 0) {
        withAnimation(AnimationTiming.backgroundFadeAnimation(isShowing: value, additionalDelay: delay)) {
            showBackgroundMenu = value
        }
    }

    @ViewBuilder
    private func reactionButton(
        for reaction: Reaction,
        isVisible: Bool,
        isOverlay: Bool,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            reactionContent(for: reaction)
                .frame(width: 28, height: 28)
                .shadow(color: Color.base.opacity(1), radius: 3)
                .background {
                    Circle()
                        .fill(isSelected && menuIsShowing ? Color.accentColor.opacity(0.3) : .clear)
                        .frame(width: 44, height: 44)
                        .animation(.smooth, value: isSelected)
                }
        }
        .buttonBorderShape(.circle)
        .buttonStyle(.glass)
//        .glassEffect(menuIsShowing ? .regular.interactive() : .clear.interactive(), in: .circle)
        .animation(isVisible ? .smooth : nil) { content in
            content
                .opacity(isVisible ? 1 : 0)
        }
        .matchedGeometryEffect(
            id: reaction.id,
            in: reactionNamespace,
            isSource: matchedGeometryIsSource(for: reaction, isOverlay: isOverlay)
        )
        .offset(x: isOverlay ? 25 : 0, y: isOverlay ? -20 : 0)
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
                .foregroundStyle(.secondary)
        }
    }
}

extension View {
    func reactions(
        messageID: UUID,
        reactions: [Reaction] = ReactionsModifier.defaultReactions,
        isEnabled: Bool = true
    ) -> some View {
        modifier(
            ReactionsModifier(
                messageID: messageID,
                reactions: reactions,
                isEnabled: isEnabled
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
        let narrowWidth: Double = 105
        let shortHeight: Double = 80
        let wideWidth: Double = 250
        switch self {
        case .narrowShort:
            return (0, narrowWidth, 0, shortHeight)
        case .narrowTall:
            return (0, narrowWidth, shortHeight, .infinity)
        case .mediumCorner:
            return (narrowWidth, wideWidth, 0, .infinity)
        case .wideTop:
            return (wideWidth, .infinity, 0, .infinity)
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

    static func matching(for size: CGSize) -> LayoutCase {
        let width = size.width
        let height = size.height

        return allCases.first { layoutCase in
            let thresholds = layoutCase.thresholds
            return width >= thresholds.widthMin && width < thresholds.widthMax &&
            height >= thresholds.heightMin && height < thresholds.heightMax
        } ?? .wideTop
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
            RoundedRectangle(cornerRadius: 10)
                .fill(.green)
                .frame(width: demoWidth, height: demoHeight)
                .containerShape(.rect)
                .reactions(messageID: UUID())
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

#Preview("TapBackTestView") {
    TapBackTestView()
        .environment(ChatData())
}

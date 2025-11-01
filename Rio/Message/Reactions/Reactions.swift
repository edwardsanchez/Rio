//
//  Reactions.swift
//  Rio
//
//  Created by Edward Sanchez on 10/20/25.
//

import SwiftUI

struct ReactionsModifier: ViewModifier {
    @Environment(ChatData.self) private var chatData
    @Environment(ReactionsCoordinator.self) private var reactionsCoordinator

    let messageContext: MessageBubbleContext

    @State private var viewSize: CGSize = .zero

    @Namespace private var reactionNamespace
    @State private var reactionsMenuModel: ReactionsMenuModel

    private let availabilityGate: Bool

    static var defaultReactions: [Reaction] {
        [
            .emoji("😍"),
            .emoji("👍"),
            .emoji("👎"),
            .emoji("😂"),
            .emoji("😲"),
            .emoji("🧐"),
            .systemImage("face.dashed", selectedEmoji: "?") //Custom set
        ]
    }

    private let reactionSpacing: CGFloat = 50

    init(messageContext: MessageBubbleContext, reactions: [Reaction], isAvailable: Bool) {
        self.messageContext = messageContext
        _ = reactions
        let resolvedReactions = ReactionsModifier.makeReactions(from: messageContext.message)
        availabilityGate = isAvailable
        _reactionsMenuModel = State(
            initialValue: ReactionsMenuModel(
                messageID: messageContext.message.id,
                reactions: resolvedReactions
            )
        )
    }

    private var reactionBadgeAlignment: Alignment {
        messageContext.messageType.isOutbound ? .topLeading : .topTrailing
    }

    private var supportsInteractiveMenu: Bool {
        !messageContext.messageType.isOutbound
    }

    private var fallbackMessageReaction: Reaction? {
        guard let messageReaction = messageContext.message.reactions.last else { return nil }
        let emoji = messageReaction.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !emoji.isEmpty else { return nil }

        return Reaction(
            id: "message-reaction-\(messageContext.message.id.uuidString)",
            display: .emoji(value: emoji, fontSize: 24),
            selectedEmoji: emoji
        )
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        @Bindable var reactionsMenuModel = reactionsMenuModel
        @Bindable var reactionsCoordinator = reactionsCoordinator
        if availabilityGate {
            if messageContext.isReactionsOverlay {
                content
                    .scaleEffect(reactionsMenuModel.isShowingReactionMenu ? 1.1 : 1, anchor: UnitPoint(x: 0.2, y: 0.5))
                    .animation(
                        ReactionsAnimationTiming.menuScaleAnimation,
                        value: reactionsMenuModel.isShowingReactionMenu
                    )
                    .onGeometryChange(for: CGSize.self) { proxy in
                        proxy.size
                    } action: { newSize in
                        viewSize = newSize
                        reactionsMenuModel.viewSize = newSize
                    }
                    .overlay(alignment: reactionBadgeAlignment) {
                        if let badgeReaction = resolvedBadgeReaction(from: reactionsMenuModel) {
                            //Here only for the purposes of geometry matching as it has the right location to appear as
                            //a badge.
                            reactionButton(
                                for: badgeReaction,
                                isVisible: false,
                                isOverlay: true,
                                isSelected: reactionsMenuModel.selectedReaction?.id == badgeReaction.id,
                                alignment: reactionBadgeAlignment
                            ) {}
                                .allowsHitTesting(false)
                        }
                    }
                    .background {
                        //Background version so it animates BEHIND the bubble on open and on close, should disappear as
                        //open animation ends, should reappear when close animation starts
                        ReactionsMenuView(
                            isOverlay: false,
                            reactionsMenuModel: reactionsMenuModel,
                            reactionNamespace: reactionNamespace
                        )
                        .opacity(reactionsMenuModel.showBackgroundMenu ? 1 : 0)
                        .allowsHitTesting(false)
                    }
                    .overlay {
                        //Foreground version so it animates back on top of the bubble. Should be visible especially to
                        //show the one that was just selected so it ends up at the top
                        ReactionsMenuView(
                            isOverlay: true,
                            reactionsMenuModel: reactionsMenuModel,
                            reactionNamespace: reactionNamespace
                        )
                        .allowsHitTesting(!reactionsMenuModel.showBackgroundMenu)
                    }
                    .onAppear {
                        adoptSharedMenuModel()
                        reactionsMenuModel.coordinator = reactionsCoordinator
                        reactionsMenuModel.chatData = chatData
                        updateMenuModelReactionsIfNeeded()
                    }
                    .sheet(
                        isPresented: $reactionsCoordinator.isCustomEmojiPickerPresented,
                        onDismiss: {
                            reactionsMenuModel.setCustomEmojiHighlight(false)
                            if reactionsMenuModel.isShowingReactionMenu {
                                reactionsMenuModel.prepareCustomEmojiForMenuOpen()
                            }
                        }
                    ) {
                        EmojiPickerView { emoji in
                            reactionsMenuModel.applyCustomEmojiSelection(emoji.character)
                            reactionsMenuModel.setCustomEmojiHighlight(false)
                            reactionsCoordinator.isCustomEmojiPickerPresented = false
                        }
                        .presentationDetents([.height(300)])
                    }
                    .onTapGesture {
                        reactionsMenuModel.closeReactionsMenu()
                    }
                    .onChange(of: messageContext.message.reactionOptions) { _, _ in
                        updateMenuModelReactionsIfNeeded()
                    }
            } else {
                content
                    .contentShape(.rect)
                    .overlay(alignment: reactionBadgeAlignment) {
                        //This is the version that shows up when it's just a badge on the corner, if there's a reaction
                        //for this message.
                        if let badgeReaction = resolvedBadgeReaction(from: reactionsMenuModel) {
                            reactionButton(
                                for: badgeReaction,
                                isVisible: true,
                                isOverlay: true,
                                isSelected: reactionsMenuModel.selectedReaction?.id == badgeReaction.id,
                                alignment: reactionBadgeAlignment
                            ) {
                                openReactionsOverlay(
                                    reactionsMenuModel: reactionsMenuModel,
                                    reactionsCoordinator: reactionsCoordinator
                                )
                            }
                        }
                    }
                    .sensoryFeedback(.impact, trigger: reactionsMenuModel.isShowingReactionMenu)
                    .onAppear {
                        adoptSharedMenuModel()
                        reactionsMenuModel.coordinator = reactionsCoordinator
                        reactionsMenuModel.chatData = chatData
                        updateMenuModelReactionsIfNeeded()
                    }
                    .onChange(of: messageContext.message.reactionOptions) { _, _ in
                        updateMenuModelReactionsIfNeeded()
                    }
                    .onLongPressGesture {
                        openReactionsOverlay(
                            reactionsMenuModel: reactionsMenuModel,
                            reactionsCoordinator: reactionsCoordinator
                        )
                    }
            }
        } else {
            //For outbound messages since you can't like your own messages
            content
                .onChange(of: messageContext.message.reactionOptions) { _, _ in
                    updateMenuModelReactionsIfNeeded()
                }
        }
    }

    /// Helper to create reaction button with shared component
    private func reactionButton(
        for reaction: Reaction,
        isVisible: Bool,
        isOverlay: Bool,
        isSelected: Bool,
        alignment: Alignment,
        action: @escaping () -> Void
    ) -> some View {
        ReactionButton(
            reaction: reaction,
            isVisible: isVisible,
            isOverlay: isOverlay,
            isSelected: isSelected,
            menuIsShowing: reactionsMenuModel.isShowingReactionMenu,
            isCustomEmojiHighlighted: reactionsMenuModel.isCustomEmojiHighlighted,
            reactionNamespace: reactionNamespace,
            matchedGeometryIsSource: matchedGeometryIsSource(for: reaction, isOverlay: isOverlay),
            visibilityAnimation: isVisible ? .smooth : nil,
            overlayAlignment: alignment,
            action: action
        )
    }

    private func matchedGeometryIsSource(for reaction: Reaction, isOverlay: Bool) -> Bool {
        guard reactionsMenuModel.selectedReactionID == reaction.id else {
            return !isOverlay
        }

        return isOverlay ? !reactionsMenuModel.isShowingReactionMenu : reactionsMenuModel.isShowingReactionMenu
    }

    private func adoptSharedMenuModel() {
        if let sharedModel = reactionsCoordinator.menuModel(for: messageContext.message.id) {
            if sharedModel !== reactionsMenuModel {
                reactionsMenuModel = sharedModel
            }
        } else {
            reactionsCoordinator.registerMenuModel(reactionsMenuModel, for: messageContext.message.id)
            return
        }

        reactionsCoordinator.registerMenuModel(reactionsMenuModel, for: messageContext.message.id)
    }

    private func updateMenuModelReactionsIfNeeded() {
        let latest = ReactionsModifier.makeReactions(from: messageContext.message)
        if reactionsMenuModel.reactions != latest {
            reactionsMenuModel.reactions = latest
        }
    }

    private func openReactionsOverlay(
        reactionsMenuModel: ReactionsMenuModel,
        reactionsCoordinator: ReactionsCoordinator
    ) {
        if supportsInteractiveMenu {
            reactionsMenuModel.openReactionsMenu()
        }

        reactionsCoordinator.openReactionsMenu(
            with: messageContext,
            menuModel: reactionsMenuModel
        )
    }

    private func resolvedBadgeReaction(from menuModel: ReactionsMenuModel) -> Reaction? {
        if let selected = menuModel.selectedReaction {
            return selected
        }

        return fallbackMessageReaction
    }
}

extension View {
    func reactions(
        messageContext: MessageBubbleContext,
        reactions: [Reaction] = ReactionsModifier.defaultReactions,
        isAvailable: Bool = true
    ) -> some View {
        modifier(
            ReactionsModifier(
                messageContext: messageContext,
                reactions: reactions,
                isAvailable: isAvailable
            )
        )
    }

    func reactionError(isAvailable: Bool) -> some View {
        modifier(ReactionErrorModifier(isAvailable: isAvailable))
    }
}

private struct ReactionErrorModifier: ViewModifier {
    let isAvailable: Bool

    @State private var scale: CGFloat = 1
    @State private var feedbackTrigger = false
    @State private var animationTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        Group {
            if isAvailable {
                content
                    .scaleEffect(scale)
                    .contentShape(Rectangle())
                    .onLongPressGesture {
                        animationTask?.cancel()
                        feedbackTrigger.toggle()

                        animationTask = Task { @MainActor in
                            scale = 1

                            withAnimation(.bouncy(duration: 0.12)) {
                                scale = 1.02
                            }

                            try? await Task.sleep(nanoseconds: 180_000_000)
                            guard !Task.isCancelled else { return }

                            withAnimation(.bouncy(duration: 0.32)) {
                                scale = 1
                            }

                            animationTask = nil
                        }
                    }
                    .sensoryFeedback(.error, trigger: feedbackTrigger)
                    .onDisappear {
                        animationTask?.cancel()
                        animationTask = nil
                        scale = 1
                    }
            } else {
                content
            }
        }
    }
}

// MARK: - Layout Cases

private extension ReactionsModifier {
    static func makeReactions(from message: Message) -> [Reaction] {
        let baseReactions: [Reaction] = if message.reactionOptions.isEmpty {
            (0 ..< 6).map { index in
                Reaction.placeholder(id: "placeholder-\(message.id.uuidString)-\(index)")
            }
        } else {
            message.reactionOptions.enumerated().map { index, value in
                Reaction.emoji(
                    value,
                    id: "emoji-\(message.id.uuidString)-\(index)"
                )
            }
        }

        var combined = baseReactions
        if !combined.contains(where: { $0.id == Reaction.customEmojiReactionID }) {
            combined.append(.systemImage("face.dashed", selectedEmoji: "?"))
        }

        return combined
    }
}

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
            LayoutConfig(
                radius: 80,
                spacerCenterPercent: 0.75, // 270° - right side
                horizontalAnchor: .trailing,
                verticalAnchor: .center
            ) { size in
                let baseX: CGFloat = size.width > 65 ? -25 : 10
                return CGSize(width: baseX, height: 0)
            }
        case .narrowTall:
            LayoutConfig(
                radius: 500,
                spacerCenterPercent: 0.75, // 270° - right side
                horizontalAnchor: .trailing,
                verticalAnchor: .center
            ) { _ in
                CGSize(width: -435, height: 0)
            }
        case .mediumCorner:
            LayoutConfig(
                radius: 100,
                spacerCenterPercent: 0.625, // 135° - top-right corner
                horizontalAnchor: .trailing,
                verticalAnchor: .top
            ) { _ in
                CGSize(width: -30, height: 30)
            }
        case .wideTop:
            LayoutConfig(
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

private struct TapBackTestView: View {
    @State private var demoWidth: Double = 250
    @State private var demoHeight: Double = 150
    @State private var messageID = UUID()
    @Environment(ChatData.self) private var chatData

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
                .reactions(
                    messageContext: MessageBubbleContext(
                        message: Message(content: .text("Test"), from: chatData.currentUser, date: Date()),
                        theme: .defaultTheme,
                        showTail: true,
                        messageType: .outbound,
                        bubbleType: .talking,
                        layoutType: .talking,
                        isReactionsOverlay: false
                    )
                )
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
                    Slider(value: $demoWidth, in: 30 ... 300)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Height: \(Int(demoHeight))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $demoHeight, in: 30 ... 300)
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
        .environment(ReactionsCoordinator())
}

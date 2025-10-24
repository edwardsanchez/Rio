//
//  ReactionsMenuModel.swift
//  Rio
//
//  Created by Assistant on 10/24/25.
//

import SwiftUI

@Observable
final class ReactionsMenuModel {
    var chatData: ChatData?
    var onOpenEmojiPicker: (() -> Void)?

    let messageID: UUID
    var reactions: [Reaction]
    private var customEmojiSelection: String?
    private var customEmojiResetWorkItem: DispatchWorkItem?

    var viewSize: CGSize = .zero
    var selectedReactionID: Reaction.ID?
    var showBackgroundMenu = false

    private let reactionSpacing: CGFloat = 50
    private enum Constants {
        static let customEmojiReactionID = "face.dashed"
        static let customEmojiPlaceholder = "?"
        static let customEmojiFontSize: CGFloat = 24
    }

    init(messageID: UUID, reactions: [Reaction]) {
        self.messageID = messageID
        self.reactions = reactions
    }

    // MARK: - Animation Timing
    enum AnimationTiming {
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

    // MARK: - Derived State
    var menuIsShowing: Bool {
        chatData?.activeReactionMessageID == messageID
    }

    var selectedReaction: Reaction? {
        guard let selectedReactionID else { return nil }
        if selectedReactionID == Constants.customEmojiReactionID,
           let customEmojiSelection {
            return Reaction(
                id: Constants.customEmojiReactionID,
                display: .emoji(value: customEmojiSelection, fontSize: Constants.customEmojiFontSize),
                selectedEmoji: customEmojiSelection
            )
        }
        return reactions.first { $0.id == selectedReactionID }
    }

    private var layoutCase: LayoutCase {
        LayoutCase.matching(for: viewSize)
    }

    var calculatedRadius: CGFloat {
        layoutCase.config.radius
    }

    var calculatedSpacerCenterPercent: CGFloat {
        layoutCase.config.spacerCenterPercent
    }

    var calculatedOffset: CGSize {
        guard menuIsShowing else { return .zero }
        let config = layoutCase.config
        let baseOffset = config.baseOffset(for: viewSize)
        let horizontalAdjustment = config.horizontalAnchor.xOffset(for: viewSize)
        let verticalAdjustment = config.verticalAnchor.yOffset(for: viewSize)
        return CGSize(
            width: baseOffset.width + horizontalAdjustment,
            height: baseOffset.height + verticalAdjustment
        )
    }

    var calculatedReactionSpacing: CGFloat { reactionSpacing }

    // MARK: - Intents
    func setBackgroundMenuVisible(_ value: Bool, delay: TimeInterval = 0) {
        withAnimation(AnimationTiming.backgroundFadeAnimation(isShowing: value, additionalDelay: delay)) {
            showBackgroundMenu = value
        }
    }

    func openMenu() {
        prepareCustomEmojiForMenuOpen()
        chatData?.activeReactionMessageID = messageID
        setBackgroundMenuVisible(true)
    }

    func closeMenu(delay: TimeInterval = 0) {
        scheduleCustomEmojiRestore(after: AnimationTiming.baseDuration + delay)
        chatData?.activeReactionMessageID = nil
        setBackgroundMenuVisible(false, delay: delay)
    }

    func handleReactionTap(_ reaction: Reaction) {
        guard menuIsShowing else {
            openMenu()
            return
        }

        if reaction.id == Constants.customEmojiReactionID {
            onOpenEmojiPicker?()
            return
        }

        let isSameReaction = selectedReactionID == reaction.id
        selectedReactionID = isSameReaction ? nil : reaction.id
        chatData?.addReaction(reaction.selectedEmoji, toMessageId: messageID)
        closeMenu(delay: AnimationTiming.reactionHideDelay)
    }

    func applyCustomEmojiSelection(_ emoji: String) {
        selectedReactionID = Constants.customEmojiReactionID
        customEmojiSelection = emoji

        updateCustomReactionDisplay(showingEmoji: true)
        chatData?.addReaction(emoji, toMessageId: messageID)
        closeMenu(delay: AnimationTiming.reactionHideDelay)
    }

    func prepareCustomEmojiForMenuOpen() {
        customEmojiResetWorkItem?.cancel()
        updateCustomReactionDisplay(showingEmoji: false)
    }

    func restoreCustomEmojiAfterMenuClose(immediate: Bool = false) {
        customEmojiResetWorkItem?.cancel()

        guard customEmojiSelection != nil else { return }

        if immediate {
            updateCustomReactionDisplay(showingEmoji: true)
        } else {
            scheduleCustomEmojiRestore(after: AnimationTiming.baseDuration)
        }
    }

    private func scheduleCustomEmojiRestore(after delay: TimeInterval) {
        customEmojiResetWorkItem?.cancel()

        guard customEmojiSelection != nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.updateCustomReactionDisplay(showingEmoji: true)
        }

        customEmojiResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func updateCustomReactionDisplay(showingEmoji: Bool) {
        guard let index = reactions.firstIndex(where: { $0.id == Constants.customEmojiReactionID }) else { return }

        if showingEmoji, let emoji = customEmojiSelection {
            reactions[index] = Reaction(
                id: Constants.customEmojiReactionID,
                display: .emoji(value: emoji, fontSize: Constants.customEmojiFontSize),
                selectedEmoji: emoji
            )
        } else {
            reactions[index] = Reaction.systemImage(
                Constants.customEmojiReactionID,
                selectedEmoji: customEmojiSelection ?? Constants.customEmojiPlaceholder
            )
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

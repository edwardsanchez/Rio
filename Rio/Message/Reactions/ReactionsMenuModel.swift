//
//  ReactionsMenuModel.swift
//  Rio
//
//  Created by Assistant on 10/24/25.
//

import SwiftUI

// MARK: - Menu State Machine

enum MenuState {
    case closed
    case opening           // Background menu visible, reactions animating out
    case open              // Fully expanded, background hidden, overlay visible
    case selectedClosing   // User tapped reaction, animating back

    var isShowingMenu: Bool {
        self != .closed
    }
}

// MARK: - Reactions Menu Model

@Observable
final class ReactionsMenuModel {
    var coordinator: ReactionsCoordinator?
    var chatData: ChatData?

    let messageID: UUID
    var reactions: [Reaction]
    var viewSize: CGSize = .zero
    var selectedReactionID: Reaction.ID?
    var state: MenuState = .closed
    var showBackgroundMenu = false

    private let reactionSpacing: CGFloat = 50
    fileprivate var orchestrator: AnimationOrchestrator!
    fileprivate var customEmojiManager: CustomEmojiManager!

    private enum Constants {
        static let customEmojiReactionID = Reaction.customEmojiReactionID
    }

    init(messageID: UUID, reactions: [Reaction]) {
        self.messageID = messageID
        self.reactions = reactions
        self.orchestrator = AnimationOrchestrator(model: self)
        self.customEmojiManager = CustomEmojiManager(model: self)
    }

    // MARK: - Derived State
    var isShowingReactionMenu: Bool { state == .open }

    var selectedReaction: Reaction? {
        guard let selectedReactionID else { return nil }
        if selectedReactionID == Constants.customEmojiReactionID {
            return customEmojiManager.selectedReaction
        }

        return reactions.first { $0.id == selectedReactionID }
    }

    var isCustomEmojiHighlighted: Bool {
        customEmojiManager.isHighlighted
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
        guard isShowingReactionMenu else { return .zero }
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
    func openReactionsMenu() {
        orchestrator.transitionToOpening()
    }

    func closeReactionsMenu(delay: TimeInterval = 0) {
        orchestrator.transitionToClosing(delay: delay)
    }

    func handleReactionTap(_ reaction: Reaction) {
        guard isShowingReactionMenu else {
            openReactionsMenu()
            return
        }

        if reaction.id == Constants.customEmojiReactionID {
            customEmojiManager.openPicker()
            return
        }

        let isSameReaction = selectedReactionID == reaction.id
        selectedReactionID = isSameReaction ? nil : reaction.id
        chatData?.addReaction(reaction.selectedEmoji, toMessageId: messageID)
        closeReactionsMenu(delay: ReactionsAnimationTiming.reactionHideDelay)
    }

    func applyCustomEmojiSelection(_ emoji: String) {
        customEmojiManager.applySelection(emoji)
        selectedReactionID = Constants.customEmojiReactionID
        chatData?.addReaction(emoji, toMessageId: messageID)
        DispatchQueue.main.async { [weak self] in
            self?.closeReactionsMenu(delay: ReactionsAnimationTiming.reactionHideDelay)
        }
    }

    func prepareCustomEmojiForMenuOpen() {
        customEmojiManager.showPlaceholder()
    }

    func setCustomEmojiHighlight(_ highlighted: Bool) {
        customEmojiManager.setHighlight(highlighted)
    }
}

// MARK: - Animation Orchestrator

/// Centralizes all animation timing and state transitions
final class AnimationOrchestrator {
    weak var model: ReactionsMenuModel?
    private var fanOutWorkItem: DispatchWorkItem?
    private var backgroundHideWorkItem: DispatchWorkItem?
    private var closingWorkItem: DispatchWorkItem?

    init(model: ReactionsMenuModel) {
        self.model = model
    }

    func transitionToOpening() {
        cancelAll()
        guard let model else { return }

        model.customEmojiManager.showPlaceholder()
        
        // Immediately set state and show background
        model.state = .opening
        setBackgroundMenuVisible(true, includeShowDelay: false)

        // Schedule transition to fully open state
        let workItem = DispatchWorkItem { [weak self, weak model] in
            guard let self, let model else { return }
            withAnimation(ReactionsAnimationTiming.menuOpenAnimation) {
                model.state = .open
            }
            
            self.scheduleBackgroundMenuHide()
        }

        fanOutWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + ReactionsAnimationTiming.fanOutDelay,
            execute: workItem
        )
    }

    func transitionToClosing(delay: TimeInterval) {
        cancelAll()
        guard let model else { return }

        // Immediately show background menu
        setBackgroundMenuVisible(true, includeShowDelay: false)

        let collapseWorkItem = DispatchWorkItem { [weak self, weak model] in
            guard let self, let model else { return }
            
            withAnimation(ReactionsAnimationTiming.menuOpenAnimation) {
                model.state = .selectedClosing
            }

            self.scheduleBackgroundMenuHideAfterClose()
        }

        if delay == 0 {
            collapseWorkItem.perform()
        } else {
            closingWorkItem = collapseWorkItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + delay,
                execute: collapseWorkItem
            )
        }

        let totalDelay = ReactionsAnimationTiming.baseDuration + ReactionsAnimationTiming.overlayHoldDuration + delay
        model.customEmojiManager.scheduleRestore(after: totalDelay)
        model.customEmojiManager.setHighlight(false)
        model.coordinator?.closeReactionsMenu(after: totalDelay)
    }

    private func setBackgroundMenuVisible(
        _ value: Bool,
        delay: TimeInterval = 0,
        includeShowDelay: Bool = true
    ) {
        guard let model else { return }
        let animation = ReactionsAnimationTiming.backgroundFadeAnimation(
            isShowing: value,
            additionalDelay: delay,
            includeShowDelay: includeShowDelay
        )
        
        withAnimation(animation) {
            model.showBackgroundMenu = value
        }
    }

    private func scheduleBackgroundMenuHide() {
        backgroundHideWorkItem?.cancel()
        guard let model else { return }
        
        let workItem = DispatchWorkItem { [weak self, weak model] in
            guard let model else { return }
            guard model.isShowingReactionMenu else { return }
            self?.setBackgroundMenuVisible(false)
        }
        
        backgroundHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + ReactionsAnimationTiming.baseDuration,
            execute: workItem
        )
    }

    private func scheduleBackgroundMenuHideAfterClose() {
        backgroundHideWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self, weak model] in
            guard let model else { return }
            self?.setBackgroundMenuVisible(false)
            // Transition to closed state after background fades
            withAnimation(.easeInOut(duration: 0.01)) {
                model.state = .closed
            }
        }
        
        backgroundHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + ReactionsAnimationTiming.baseDuration + ReactionsAnimationTiming.overlayHoldDuration,
            execute: workItem
        )
    }

    private func cancelAll() {
        fanOutWorkItem?.cancel()
        backgroundHideWorkItem?.cancel()
        closingWorkItem?.cancel()
        fanOutWorkItem = nil
        backgroundHideWorkItem = nil
        closingWorkItem = nil
    }
}

// MARK: - Custom Emoji Manager

/// Manages the custom emoji placeholder ↔ selected emoji swapping behavior
final class CustomEmojiManager {
    weak var model: ReactionsMenuModel?
    private var selection: String?
    private var restoreWorkItem: DispatchWorkItem?
    private(set) var isHighlighted = false

    private enum Constants {
        static let customEmojiReactionID = Reaction.customEmojiReactionID
        static let customEmojiPlaceholder = "?"
        static let customEmojiFontSize: CGFloat = 24
    }

    init(model: ReactionsMenuModel) {
        self.model = model
    }

    var selectedReaction: Reaction? {
        guard let selection else { return nil }
        return Reaction(
            id: Constants.customEmojiReactionID,
            display: .emoji(value: selection, fontSize: Constants.customEmojiFontSize),
            selectedEmoji: selection
        )
    }

    func openPicker() {
        setHighlight(true)
        model?.coordinator?.isCustomEmojiPickerPresented = true
    }

    func applySelection(_ emoji: String) {
        selection = emoji
        restoreWorkItem?.cancel()
        updateReactionsList(showingEmoji: true)
    }

    func showPlaceholder() {
        restoreWorkItem?.cancel()
        updateReactionsList(showingEmoji: false)
    }

    func scheduleRestore(after delay: TimeInterval) {
        restoreWorkItem?.cancel()
        guard selection != nil else { return }

        let workItem = DispatchWorkItem { [weak self] in
            self?.updateReactionsList(showingEmoji: true)
        }

        restoreWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func setHighlight(_ highlighted: Bool) {
        guard isHighlighted != highlighted else { return }
        withAnimation(.smooth(duration: 0.2)) {
            isHighlighted = highlighted
        }
    }

    private func updateReactionsList(showingEmoji: Bool) {
        guard let model,
              let index = model.reactions.firstIndex(where: { $0.id == Constants.customEmojiReactionID }) else { return }

        if showingEmoji, let emoji = selection {
            model.reactions[index] = Reaction(
                id: Constants.customEmojiReactionID,
                display: .emoji(value: emoji, fontSize: Constants.customEmojiFontSize),
                selectedEmoji: emoji
            )
        } else {
            model.reactions[index] = Reaction.systemImage(
                Constants.customEmojiReactionID,
                selectedEmoji: selection ?? Constants.customEmojiPlaceholder
            )
        }
    }
}

// MARK: - Reaction Model

struct Reaction: Identifiable, Equatable {
    static func == (lhs: Reaction, rhs: Reaction) -> Bool {
        lhs.id == rhs.id
    }

    static let customEmojiReactionID = "face.dashed"

    enum Display {
        case emoji(value: String, fontSize: CGFloat)
        case systemImage(name: String, pointSize: CGFloat, weight: Font.Weight)
        case placeholder
    }

    let id: String
    let display: Display
    let selectedEmoji: String

    static func emoji(_ value: String, id: String? = nil) -> Reaction {
        Reaction(
            id: id ?? value,
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

    static func placeholder(id: String) -> Reaction {
        Reaction(
            id: id,
            display: .placeholder,
            selectedEmoji: ""
        )
    }
}

// MARK: - Animation Timing
enum ReactionsAnimationTiming {
    static let baseDuration: TimeInterval = 0.4
    static let matchedGeometryReturnDuration: TimeInterval = 0.35
    static let reactionStaggerStepMultiplier: Double = 0.125
    static let backgroundShowDelayMultiplier: Double = 0.5
    static let reactionHideDelayMultiplier: Double = 0.25
    static let backgroundFadeDurationMultiplier: Double = 0.875
    static let overlayHoldDelayMultiplier: Double = 0.75
    static let fanOutDelay: TimeInterval = 0.3

    static var reactionStaggerStep: TimeInterval {
        baseDuration * reactionStaggerStepMultiplier
    }

    static var backgroundShowDelay: TimeInterval {
        baseDuration * backgroundShowDelayMultiplier
    }

    static var reactionHideDelay: TimeInterval {
        baseDuration * reactionHideDelayMultiplier
    }

    static var overlayHoldDuration: TimeInterval {
        baseDuration * overlayHoldDelayMultiplier
    }

    static var menuScaleAnimation: Animation {
        .interpolatingSpring(duration: baseDuration, bounce: 0.5, initialVelocity: -20)
    }

    static var menuOffsetAnimation: Animation {
        .bouncy(duration: baseDuration)
    }

    static var menuOpenAnimation: Animation {
        .bouncy(duration: baseDuration)
    }

    static func backgroundFadeAnimation(
        isShowing: Bool,
        additionalDelay: TimeInterval = 0,
        includeShowDelay: Bool = true
    ) -> Animation {
        let base = Animation.easeInOut(duration: baseDuration * backgroundFadeDurationMultiplier)
        let showDelay = isShowing && includeShowDelay ? backgroundShowDelay : 0
        let delay = showDelay + additionalDelay
        return delay == 0 ? base : base.delay(delay)
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

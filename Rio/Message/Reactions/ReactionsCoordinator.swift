//
//  ReactionsCoordinator.swift
//  Rio
//
//  Created by Assistant on 10/25/25.
//

import SwiftUI

struct ReactingMessageContext {
    let message: Message
    let showTail: Bool
    let theme: ChatTheme
}

enum ReactionGeometrySource {
    case list
    case overlay
}

@Observable
final class ReactionsCoordinator {
    // Tracks the message currently displaying a reactions menu with full context
    var reactingMessage: ReactingMessageContext?
    // Tracks whether the emoji picker sheet is presented (only one can be shown at a time)
    var isCustomEmojiPickerPresented = false
    // Controls which bubble instance should be treated as the geometry source during transitions
    var geometrySource: ReactionGeometrySource = .list
    // Drives the dimmed background overlay visibility independently of the bubble teardown
    var isBackgroundDimmerVisible = false
    // Weak storage so list bubbles and overlay share the same menu model instance
    private var menuModels: [UUID: WeakMenuModel] = [:]
    private var closeWorkItems: [UUID: DispatchWorkItem] = [:]
    private var overlayRemovalWorkItems: [UUID: DispatchWorkItem] = [:]

    func openReactionsMenu(
        with context: ReactingMessageContext,
        menuModel: ReactionsMenuModel
    ) {
        cancelCloseTimer(for: context.message.id)
        cancelOverlayRemoval(for: context.message.id)
        registerMenuModel(menuModel, for: context.message.id)
        geometrySource = .list
        reactingMessage = context

        isBackgroundDimmerVisible = true
    }

    func closeReactionsMenu(after delay: TimeInterval = 0) {
        guard let messageID = reactingMessage?.message.id else {
            return
        }

        cancelCloseTimer(for: messageID)
        cancelOverlayRemoval(for: messageID)
        isCustomEmojiPickerPresented = false

        isBackgroundDimmerVisible = false

        guard delay > 0 else {
            finishClosing(messageID)
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.finishClosing(messageID)
        }

        closeWorkItems[messageID] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    func isMenuActive(for messageID: UUID) -> Bool {
        reactingMessage?.message.id == messageID
    }

    func registerMenuModel(_ model: ReactionsMenuModel, for messageID: UUID) {
        cleanupStaleMenuModels()
        if let existing = menuModels[messageID]?.model, existing !== model {
            menuModels[messageID] = WeakMenuModel(model)
        } else if menuModels[messageID] == nil {
            menuModels[messageID] = WeakMenuModel(model)
        }
    }

    func menuModel(for messageID: UUID) -> ReactionsMenuModel? {
        cleanupStaleMenuModels()
        return menuModels[messageID]?.model
    }

    func promoteGeometrySourceToOverlay(for messageID: UUID, after delay: TimeInterval = 0.18) {
        guard geometrySource != .overlay else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, reactingMessage?.message.id == messageID else { return }
            withAnimation(.smooth(duration: 0.35)) {
                self.geometrySource = .overlay
            }
        }
    }

    func resetGeometrySourceToList() {
        withAnimation(.smooth(duration: 0.35)) {
            geometrySource = .list
        }
    }

    func closeActiveMenu(delay: TimeInterval = 0) {
        guard let messageID = reactingMessage?.message.id else {
            closeReactionsMenu(after: delay)
            return
        }

        if let model = menuModels[messageID]?.model {
            model.closeReactionsMenu(delay: delay)
        } else {
            closeReactionsMenu(after: delay)
        }
    }

    // Legacy entry point used by older previews; keep for compatibility.
    func dismissReactionWithoutPickingEmoji(delay: TimeInterval = 0) {
        closeActiveMenu(delay: delay)
    }

    private func cleanupStaleMenuModels() {
        menuModels = menuModels.filter { $0.value.model != nil }
    }

    private func cancelCloseTimer(for messageID: UUID) {
        if let workItem = closeWorkItems[messageID] {
            workItem.cancel()
            closeWorkItems.removeValue(forKey: messageID)
        }
    }

    private func cancelOverlayRemoval(for messageID: UUID) {
        if let workItem = overlayRemovalWorkItems[messageID] {
            workItem.cancel()
            overlayRemovalWorkItems.removeValue(forKey: messageID)
        }
    }

    private func finishClosing(_ messageID: UUID) {
        closeWorkItems[messageID]?.cancel()
        closeWorkItems.removeValue(forKey: messageID)

        withAnimation(.smooth(duration: ReactionsAnimationTiming.matchedGeometryReturnDuration)) {
            geometrySource = .list
        }

        cancelOverlayRemoval(for: messageID)

        let removalWorkItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if reactingMessage?.message.id == messageID {
                reactingMessage = nil
            }

            overlayRemovalWorkItems.removeValue(forKey: messageID)
        }

        overlayRemovalWorkItems[messageID] = removalWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + ReactionsAnimationTiming.matchedGeometryReturnDuration,
            execute: removalWorkItem
        )
    }
}

private final class WeakMenuModel {
    weak var model: ReactionsMenuModel?

    init(_ model: ReactionsMenuModel) {
        self.model = model
    }
}

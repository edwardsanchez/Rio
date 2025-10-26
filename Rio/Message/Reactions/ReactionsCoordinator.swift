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

@Observable
final class ReactionsCoordinator {
    // Tracks the message currently displaying a reactions menu with full context
    var reactingMessage: ReactingMessageContext?
    // Tracks whether the emoji picker sheet is presented (only one can be shown at a time)
    var isCustomEmojiPickerPresented = false
    // Weak storage so list bubbles and overlay share the same menu model instance
    private var menuModels: [UUID: WeakMenuModel] = [:]

    func openReactionsMenu(
        with context: ReactingMessageContext,
        menuModel: ReactionsMenuModel
    ) {
        debugLog("Opening reactions menu for \(context.message.id.uuidString) with model \(self.modelIdentifier(menuModel))")
        self.registerMenuModel(menuModel, for: context.message.id)
        reactingMessage = context
    }

    func closeReactionsMenu() {
        if let reactingMessage {
            debugLog("Closing reactions menu for \(reactingMessage.message.id.uuidString)")
        } else {
            debugLog("Closing reactions menu with no active message")
        }
        reactingMessage = nil
        isCustomEmojiPickerPresented = false
    }

    func isMenuActive(for messageID: UUID) -> Bool {
        reactingMessage?.message.id == messageID
    }

    func registerMenuModel(_ model: ReactionsMenuModel, for messageID: UUID) {
        cleanupStaleMenuModels()
        if let existing = menuModels[messageID]?.model, existing !== model {
            debugLog("Replacing menu model for \(messageID.uuidString) with \(self.modelIdentifier(model))")
            menuModels[messageID] = WeakMenuModel(model)
        } else if menuModels[messageID] == nil {
            debugLog("Registering menu model \(self.modelIdentifier(model)) for \(messageID.uuidString)")
            menuModels[messageID] = WeakMenuModel(model)
        } else {
            debugLog("Keeping existing menu model for \(messageID.uuidString)")
        }
    }

    func menuModel(for messageID: UUID) -> ReactionsMenuModel? {
        cleanupStaleMenuModels()
        let model = menuModels[messageID]?.model
        if let model {
            debugLog("Found menu model \(self.modelIdentifier(model)) for \(messageID.uuidString)")
        } else {
            debugLog("No menu model registered for \(messageID.uuidString)")
        }
        return model
    }

    private func cleanupStaleMenuModels() {
        menuModels = menuModels.filter { $0.value.model != nil }
    }

    private func modelIdentifier(_ model: ReactionsMenuModel) -> String {
        String(describing: ObjectIdentifier(model))
    }

    private func debugLog(_ message: String) {
#if DEBUG
        print("[ReactionsCoordinator] \(message)")
#endif
    }
}

private final class WeakMenuModel {
    weak var model: ReactionsMenuModel?

    init(_ model: ReactionsMenuModel) {
        self.model = model
    }
}

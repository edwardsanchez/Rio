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
        self.registerMenuModel(menuModel, for: context.message.id)
        reactingMessage = context
    }

    func closeReactionsMenu() {
        reactingMessage = nil
        isCustomEmojiPickerPresented = false
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

    private func cleanupStaleMenuModels() {
        menuModels = menuModels.filter { $0.value.model != nil }
    }

}

private final class WeakMenuModel {
    weak var model: ReactionsMenuModel?

    init(_ model: ReactionsMenuModel) {
        self.model = model
    }
}

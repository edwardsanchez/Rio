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

    func openReactionsMenu(with context: ReactingMessageContext) {
        reactingMessage = context
    }

    func closeReactionsMenu() {
        reactingMessage = nil
        isCustomEmojiPickerPresented = false
    }

    func isMenuActive(for messageID: UUID) -> Bool {
        reactingMessage?.message.id == messageID
    }
}

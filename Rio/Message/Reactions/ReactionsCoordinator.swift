//
//  ReactionsCoordinator.swift
//  Rio
//
//  Created by Assistant on 10/25/25.
//

import SwiftUI

@Observable
final class ReactionsCoordinator {
    // Tracks which message currently displays a reactions menu
    var activeReactionMessageID: UUID?
    // Tracks whether the emoji picker sheet is presented (only one can be shown at a time)
    var isEmojiPickerPresented = false

    func openMenu(for messageID: UUID) {
        activeReactionMessageID = messageID
    }

    func closeMenu() {
        activeReactionMessageID = nil
        isEmojiPickerPresented = false
    }

    func isMenuActive(for messageID: UUID) -> Bool {
        activeReactionMessageID == messageID
    }
}

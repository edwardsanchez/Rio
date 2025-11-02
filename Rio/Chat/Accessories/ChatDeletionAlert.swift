//
//  ChatDeletionAlert.swift
//  Rio
//
//  Created by Edward Sanchez on 11/1/25.
//

import SwiftUI

/// Provides consistent alert content for chat deletion across the app
struct ChatDeletionAlert {
    let chat: Chat
    let currentUser: User

    var title: String {
        isGroupChat ? "Leave Group?" : "Delete Chat?"
    }

    var buttonTitle: String {
        isGroupChat ? "Leave Group" : "Delete Chat"
    }

    var message: String {
        if isGroupChat {
            "Are you sure you want to leave \"\(chat.title)\"?"
        } else {
            "Are you sure you want to delete this conversation with \(chat.title)?"
        }
    }

    private var isGroupChat: Bool {
        chat.participants.count > 2
    }
}

extension View {
    /// Presents a confirmation alert for chat deletion with consistent messaging
    func chatDeletionAlert(
        isPresented: Binding<Bool>,
        chat: Chat?,
        currentUser: User,
        onDelete: @escaping (Chat) -> Void
    ) -> some View {
        alert(
            chat.map { ChatDeletionAlert(chat: $0, currentUser: currentUser).title } ?? "",
            isPresented: isPresented,
            presenting: chat
        ) { presentedChat in
            Button(
                ChatDeletionAlert(chat: presentedChat, currentUser: currentUser).buttonTitle,
                role: .destructive
            ) {
                onDelete(presentedChat)
            }

            Button("Cancel", role: .cancel) {}
        } message: { presentedChat in
            Text(ChatDeletionAlert(chat: presentedChat, currentUser: currentUser).message)
        }
    }
}

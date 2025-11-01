//
//  User.swift
//  Rio
//
//  Created by Edward Sanchez on 10/8/25.
//
import Defaults
import SwiftUI

struct User: Identifiable, Codable, Defaults.Serializable {
    let id: UUID
    let name: String
    let avatar: Data?
}

extension User {
    init(id: UUID = UUID(), name: String, resource avatar: ImageResource?) {
        self.init(id: id, name: name, avatar: User.avatarData(from: avatar))
    }

    init(id: UUID = UUID(), name: String, avatar: String) {
        self.init(id: id, name: name, avatar: User.avatarData(from: avatar))
    }

    private static func avatarData(from resource: ImageResource?) -> Data? {
        if let resource {
            let image = UIImage(resource: resource)
            return image.pngData()
        } else {
            return nil
        }
    }

    private static func avatarData(from string: String) -> Data? {
        let image = UIImage(named: string)
        return image?.pngData()
    }
}

struct Chat: Identifiable {
    let id: UUID
    let title: String
    let participants: [User] // Always includes the current "outbound" user
    let messages: [Message]
    let theme: ChatTheme

    func hasUnreadMessages(for currentUser: User) -> Bool {
        messages.contains { message in
            !message.isReadByUser.contains { $0.id == currentUser.id }
        }
    }

    init(
        id: UUID = UUID(),
        title: String?,
        participants: [User],
        messages: [Message] = [],
        theme: ChatTheme,
        currentUser: User? = nil
    ) {
        let fallbackTitle = Chat.fallbackTitle(for: participants, currentUser: currentUser)
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedTitle = trimmedTitle.isEmpty ? fallbackTitle : trimmedTitle

        self.id = id
        self.title = resolvedTitle
        self.participants = participants
        self.messages = messages
        self.theme = theme
    }
}

extension Chat {
    static func fallbackTitle(for participants: [User], currentUser: User?) -> String {
        let otherParticipants: [User] = if let currentUser {
            participants.filter { $0.id != currentUser.id }
        } else {
            participants
        }

        switch otherParticipants.count {
        case 0:
            return "Note to Self"
        case 1:
            return otherParticipants.first?.name ?? ""
        default:
            return "\(otherParticipants.count) people"
        }
    }

    /// Returns a new Chat with all messages marked as read by the current user
    func markingAllAsRead(for currentUser: User) -> Chat {
        let updatedMessages = messages.map { message in
            var updatedMessage = message
            if !updatedMessage.isReadByUser.contains(where: { $0.id == currentUser.id }) {
                updatedMessage.isReadByUser.append(currentUser)
            }
            return updatedMessage
        }

        return Chat(
            id: id,
            title: title,
            participants: participants,
            messages: updatedMessages,
            theme: theme,
            currentUser: currentUser
        )
    }

    /// Returns a new Chat with the last message from another user marked as unread
    func markingAsUnread(for currentUser: User) -> Chat {
        guard let lastInboundMessage = messages.last(where: { $0.user.id != currentUser.id }) else {
            return self
        }

        let updatedMessages = messages.map { message in
            var updatedMessage = message
            if message.id == lastInboundMessage.id {
                updatedMessage.isReadByUser.removeAll { $0.id == currentUser.id }
            }
            return updatedMessage
        }

        return Chat(
            id: id,
            title: title,
            participants: participants,
            messages: updatedMessages,
            theme: theme,
            currentUser: currentUser
        )
    }
}

struct ChatAvatarGeometryKey: Hashable {
    let chatID: UUID
    let participantID: UUID
}

extension Chat {
    func avatarGeometryKey(for participant: User) -> ChatAvatarGeometryKey {
        ChatAvatarGeometryKey(chatID: id, participantID: participant.id)
    }
}

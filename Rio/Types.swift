//
//  User.swift
//  Rio
//
//  Created by Edward Sanchez on 10/8/25.
//
import SwiftUI

struct User: Identifiable {
    let id: UUID
    let name: String
    let avatar: ImageResource?
}

struct Chat: Identifiable {
    let id: UUID
    let title: String
    let participants: [User] // Always includes the current "outbound" user
    let messages: [Message]
    let theme: ChatTheme

    init(
        id: UUID = UUID(),
        title: String,
        participants: [User],
        messages: [Message] = [],
        theme: ChatTheme
    ) {
        self.id = id
        self.title = title
        self.participants = participants
        self.messages = messages
        self.theme = theme
    }
}

// MARK: - Message Type

enum MessageType {
    case inbound
    case outbound
}

struct ChatTheme {
    let backgroundColor: Color
    let inboundTextColor: Color
    let inboundBackgroundColor: Color
    let outboundTextColor: Color
    let outboundBackgroundColor: Color

    // Predefined themes matching asset catalog
    static let defaultTheme = ChatTheme(
        backgroundColor: .base,
        inboundTextColor: .primary,
        inboundBackgroundColor: .Default.inboundBubble,
        outboundTextColor: .white,
        outboundBackgroundColor: .Default.outboundBubble
    )

    static let theme1 = ChatTheme(
        backgroundColor: .base,
        inboundTextColor: .primary,
        inboundBackgroundColor: .Theme1.inboundBubble,
        outboundTextColor: .white,
        outboundBackgroundColor: .Theme1.outboundBubble
    )

    static let theme2 = ChatTheme(
        backgroundColor: .base,
        inboundTextColor: .primary,
        inboundBackgroundColor: .Theme2.inboundBubble,
        outboundTextColor: .white,
        outboundBackgroundColor: .Theme2.outboundBubble
    )
}

struct Message: Identifiable {
    let id: UUID
    let text: String
    let user: User
    let date: Date
    let isTypingIndicator: Bool
    let replacesTypingIndicator: Bool
    let bubbleMode: BubbleMode

    var messageType: MessageType {
        // We'll determine this based on the user - for now, any user that isn't "Edward" is outbound
        user.name == "Edward" ? .outbound : .inbound
    }

    init(
        id: UUID = UUID(),
        text: String,
        user: User,
        date: Date = Date.now,
        isTypingIndicator: Bool = false,
        replacesTypingIndicator: Bool = false,
        bubbleMode: BubbleMode? = nil
    ) {
        self.id = id
        self.text = text
        self.user = user
        self.date = date
        let resolvedBubbleMode = bubbleMode ?? (isTypingIndicator ? .thinking : .talking)
        self.bubbleMode = resolvedBubbleMode
        self.isTypingIndicator = isTypingIndicator || resolvedBubbleMode == .thinking
        self.replacesTypingIndicator = replacesTypingIndicator
    }
}

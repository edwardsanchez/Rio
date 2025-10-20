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

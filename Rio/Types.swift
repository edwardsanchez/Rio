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

// MARK: - Bubble Type

enum BubbleType {
    case thinking
    case talking
    case read
    
    var isRead: Bool {
        self == .read
    }
    
    var isThinking: Bool {
        self == .thinking
    }
    
    var isTalking: Bool {
        self == .talking
    }
}

// MARK: - Message Type

enum MessageType {
    case inbound(BubbleType)
    case outbound
    
    var isInbound: Bool {
        if case .inbound = self { return true }
        return false
    }
    
    var isOutbound: Bool {
        if case .outbound = self { return true }
        return false
    }
    
    var bubbleType: BubbleType {
        switch self {
        case .inbound(let type):
            return type
        case .outbound:
            return .talking
        }
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

struct Message: Identifiable {
    let id: UUID
    let content: ContentType
    let user: User
    let date: Date
    let isTypingIndicator: Bool
    let replacesTypingIndicator: Bool
    let messageType: MessageType

    var bubbleType: BubbleType {
        messageType.bubbleType
    }
    
    // Computed property to extract text content
    var text: String {
        if case .text(let textValue) = content {
            return textValue
        }
        return ""
    }
    
    // Check if content is text type
    var hasTextContent: Bool {
        if case .text = content {
            return true
        }
        return false
    }

    init(
        id: UUID = UUID(),
        content: ContentType,
        user: User,
        date: Date = Date.now,
        isTypingIndicator: Bool = false,
        replacesTypingIndicator: Bool = false,
        messageType: MessageType
    ) {
        self.id = id
        self.user = user
        self.date = date
        self.replacesTypingIndicator = replacesTypingIndicator
        self.messageType = messageType
        self.content = content
        
        // Update isTypingIndicator based on bubble type
        self.isTypingIndicator = isTypingIndicator || messageType.bubbleType.isThinking
    }
}

enum ContentType {
    case text(String), color(RGB), image(Image), video(URL), audio(URL), date(Date), dateRange(DateRange), location, url(URL), multiChoice(MultiChoice), emoji(String), code(String)
}

struct RGB {
    var red: Int
    var green: Int
    var blue: Int
}

struct DateRange {
    var start: Date
    var end: Date
}

struct MultiChoice {
    var image: Image
}

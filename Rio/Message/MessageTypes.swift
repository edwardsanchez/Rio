//
//  BubbleType.swift
//  Rio
//
//  Created by Edward Sanchez on 10/17/25.
//

import SwiftUI
import MapKit

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
    case text(String), color(RGB), image(Image), video(URL), audio(URL), date(Date), dateRange(DateRange), location(MKMapItem), url(URL), multiChoice(MultiChoice), emoji(String), code(String)
    
    var isEmoji: Bool {
        if case .emoji = self {
            return true
        }
        return false
    }
    
    /// Returns true if the content has something to display
    var hasContent: Bool {
        switch self {
        case .text(let string):
            return !string.isEmpty
        case .emoji(let string):
            return !string.isEmpty
        case .code(let string):
            return !string.isEmpty
        default:
            return true
        }
    }
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

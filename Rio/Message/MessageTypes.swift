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

enum DateGranularity {
    case dateAndTime
    case dateOnly
    case timeOnly
}

enum ContentType {
    case text(String), color(RGB), image(Image), labeledImage(LabeledImage), video(URL), audio(URL), date(Date, granularity: DateGranularity = .dateAndTime), dateRange(DateRange, granularity: DateGranularity = .dateAndTime), dateFrequency(DateFrequency), location(MKMapItem), url(URL), textChoice(String), multiChoice([Choice]), bool(Bool), value(Measurement), valueRange(ClosedRange<Measurement>), rating(Rating), emoji(String), code(String), file(URL)
    
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

struct Measurement: Comparable, Equatable {
    var value: CGFloat
    var type: ValueType
    
    // Equatable (required for Comparable)
    static func == (lhs: Measurement, rhs: Measurement) -> Bool {
        return lhs.value == rhs.value && lhs.type == rhs.type
    }
    
    // Comparable
    static func < (lhs: Measurement, rhs: Measurement) -> Bool {
        precondition(lhs.type == rhs.type, "Cannot compare measurements of different types")
        return lhs.value < rhs.value
    }
}

struct LabeledImage {
    var label: String
    var image: Image
}

enum ValueType: Equatable {
    case length(UnitLength), percentage(CFloat), currency(CGFloat), mass(UnitMass), volume(UnitVolume), temperature(UnitTemperature), duration(UnitDuration), speed(UnitSpeed), area(UnitArea), energy(UnitEnergy), number(CGFloat)
    
    // Custom equality that only compares the case type, not associated values
    static func == (lhs: ValueType, rhs: ValueType) -> Bool {
        switch (lhs, rhs) {
        case (.length(_), .length(_)): return true
        case (.percentage(_), .percentage(_)): return true
        case (.currency(_), .currency(_)): return true
        case (.mass(_), .mass(_)): return true
        case (.volume(_), .volume(_)): return true
        case (.temperature(_), .temperature(_)): return true
        case (.duration(_), .duration(_)): return true
        case (.speed(_), .speed(_)): return true
        case (.area(_), .area(_)): return true
        case (.energy(_), .energy(_)): return true
        case (.number(_), .number(_)): return true
        default: return false
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

struct Choice {
    var value: String //Can be text or image?
}

struct DateFrequency: Codable, Equatable {
    var dayOfWeek: DaysOfWeek
    var interval: Int
}

enum DaysOfWeek: Int, Codable, CaseIterable {
    case sunday, monday, tuesday, wednesday, thursday, friday, saturday
}

enum Rating: Int, Codable, CaseIterable {
    case one, two, three, four, five
}

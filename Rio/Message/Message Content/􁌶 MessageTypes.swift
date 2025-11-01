//
//  􁌶 MessageTypes.swift
//  Rio
//
//  Created by Edward Sanchez on 10/17/25.
//

import MapKit
import SwiftUI

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
        case let .inbound(type):
            type
        case .outbound:
            .talking
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
    let storedBubbleType: BubbleType?
    var reactions: [MessageReaction] = []
    var reactionOptions: [String] = []

    // Computed property to determine message type based on current user
    func messageType(currentUser: User) -> MessageType {
        if user.id == currentUser.id {
            .outbound
        } else {
            .inbound(storedBubbleType ?? .talking)
        }
    }

    var bubbleType: BubbleType {
        storedBubbleType ?? .talking
    }

    // Computed property to extract text content
    var text: String {
        if case let .text(textValue) = content {
            textValue
        } else {
            ""
        }
    }

    // Initializer for outbound messages (from current user)
    init(
        id: UUID = UUID(),
        content: ContentType,
        from user: User,
        date: Date = Date.now,
        reactions: [MessageReaction] = []
    ) {
        self.id = id
        self.user = user
        self.date = date
        replacesTypingIndicator = false
        storedBubbleType = nil
        self.content = content
        isTypingIndicator = false
        self.reactions = reactions
    }

    // Initializer for inbound messages (from other users)
    init(
        id: UUID = UUID(),
        content: ContentType,
        from user: User,
        date: Date = Date.now,
        isTypingIndicator: Bool = false,
        replacesTypingIndicator: Bool = false,
        bubbleType: BubbleType,
        reactions: [MessageReaction] = []
    ) {
        self.id = id
        self.user = user
        self.date = date
        self.replacesTypingIndicator = replacesTypingIndicator
        storedBubbleType = bubbleType
        self.content = content
        self.reactions = reactions

        // Update isTypingIndicator based on bubble type
        self.isTypingIndicator = isTypingIndicator || bubbleType.isThinking
    }
}

struct MessageReaction: Identifiable {
    let id: UUID = .init()
    let user: User
    let date: Date
    let emoji: String
}

enum DateGranularity {
    case dateAndTime
    case dateOnly
    case timeOnly
}

enum ContentType {
    case text(String), color(RGB), image(Image), labeledImage(LabeledImage), video(URL), audio(URL), date(
        Date,
        granularity: DateGranularity = .dateAndTime
    ), dateRange(DateRange, granularity: DateGranularity = .dateAndTime), dateFrequency(DateFrequency),
    location(MKMapItem), url(URL), textChoice(String), multiChoice([ChoiceValue]), bool(Bool), value(Measurement),
    valueRange(ClosedRange<Measurement>), rating(Rating), emoji(String), code(String), file(URL)

    var isEmoji: Bool {
        if case .emoji = self {
            true
        } else {
            false
        }
    }

    /// Returns true if the content has something to display
    var hasContent: Bool {
        switch self {
        case let .text(string):
            !string.isEmpty
        case let .emoji(string):
            !string.isEmpty
        case let .code(string):
            !string.isEmpty
        default:
            true
        }
    }
}

struct Measurement: Comparable, Equatable {
    var value: CGFloat
    var type: ValueType

    // Equatable (required for Comparable)
    static func == (lhs: Measurement, rhs: Measurement) -> Bool {
        lhs.value == rhs.value && lhs.type == rhs.type
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
    case length(UnitLength), percentage(CFloat), currency(CGFloat), mass(UnitMass), volume(UnitVolume),
         temperature(UnitTemperature), duration(UnitDuration), speed(UnitSpeed), area(UnitArea), energy(UnitEnergy),
         number(CGFloat)

    // Custom equality that only compares the case type, not associated values
    static func == (lhs: ValueType, rhs: ValueType) -> Bool {
        switch (lhs, rhs) {
        case (.length(_), .length(_)): true
        case (.percentage(_), .percentage(_)): true
        case (.currency(_), .currency(_)): true
        case (.mass(_), .mass(_)): true
        case (.volume(_), .volume(_)): true
        case (.temperature(_), .temperature(_)): true
        case (.duration(_), .duration(_)): true
        case (.speed(_), .speed(_)): true
        case (.area(_), .area(_)): true
        case (.energy(_), .energy(_)): true
        case (.number(_), .number(_)): true
        default: false
        }
    }
}

struct RGB {
    var red: Int
    var green: Int
    var blue: Int
    var name: String?
}

struct DateRange {
    var start: Date
    var end: Date
}

enum ChoiceValue {
    case color(RGB)
    case image(Image)
    case labeledImage(LabeledImage)
    case location(MKMapItem)
    case textChoice(String)
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

// MARK: - Message Copy Extension

extension Message {
    /// Copies the message content to the system clipboard
    func copyToClipboard() {
        let pasteboard = UIPasteboard.general

        switch content {
        // Simple text types
        case let .text(string), let .emoji(string), let .code(string), let .textChoice(string):
            pasteboard.string = string

        // Image types
        case let .image(image):
            copyImage(image, to: pasteboard)

        case let .labeledImage(labeledImage):
            copyImage(labeledImage.image, to: pasteboard)

        // Video/Audio - try to copy data, fallback to URL or description
        case let .video(url):
            copyMediaFromURL(url, fallbackText: "Video", to: pasteboard)

        case let .audio(url):
            copyMediaFromURL(url, fallbackText: "Audio", to: pasteboard)

        // Location - generate Apple Maps URL or use name
        case let .location(mapItem):
            if let mapsURL = generateAppleMapsURL(for: mapItem) {
                pasteboard.string = mapsURL
            } else if let name = mapItem.name {
                pasteboard.string = name
            } else {
                pasteboard.string = "Location"
            }

        // Dates
        case let .date(date, granularity):
            pasteboard.string = formatDate(date, granularity: granularity)

        case let .dateRange(range, granularity):
            pasteboard.string = formatDateRange(range, granularity: granularity)

        case let .dateFrequency(frequency):
            pasteboard.string = formatDateFrequency(frequency)

        // Values
        case let .value(measurement):
            pasteboard.string = formatMeasurementValue(measurement)

        case let .valueRange(range):
            let minStr = formatMeasurementValue(range.lowerBound)
            let maxStr = formatMeasurementValue(range.upperBound)
            pasteboard.string = "\(minStr) - \(maxStr)"

        case let .bool(value):
            pasteboard.string = value ? "YES" : "NO"

        case let .rating(rating):
            pasteboard.string = "\(rating.rawValue + 1) stars"

        // URLs and files
        case let .url(url):
            pasteboard.string = url.absoluteString

        case let .file(url):
            pasteboard.string = url.lastPathComponent

        // Color
        case let .color(rgb):
            if let name = rgb.name {
                pasteboard.string = name
            } else {
                let hex = String(format: "#%02X%02X%02X", rgb.red, rgb.green, rgb.blue)
                pasteboard.string = hex
            }

        // Multi-choice - skip for now
        case .multiChoice:
            break
        }
    }

    // MARK: - Helper Methods

    private func copyImage(_ image: Image, to pasteboard: UIPasteboard) {
        // Use ImageRenderer to convert SwiftUI Image to UIImage
        let renderer = ImageRenderer(content: image.resizable().scaledToFit())

        // Set a reasonable size for rendering
        renderer.proposedSize = ProposedViewSize(width: 1024, height: 1024)

        if let uiImage = renderer.uiImage {
            pasteboard.image = uiImage
        }
    }

    private func copyMediaFromURL(_ url: URL, fallbackText: String, to pasteboard: UIPasteboard) {
        // For remote URLs, just copy the URL string
        // For local files, we could copy the data, but that's complex for video
        if url.isFileURL {
            // Try to copy file data for local files
            if let data = try? Data(contentsOf: url) {
                pasteboard.setData(data, forPasteboardType: "public.data")
            } else {
                pasteboard.string = url.path
            }
        } else {
            // Remote URL - just copy the URL string
            pasteboard.string = url.absoluteString
        }
    }

    private func generateAppleMapsURL(for mapItem: MKMapItem) -> String? {
        let location = mapItem.location
        let coordinate = location.coordinate
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        if let name = mapItem.name {
            let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
            return "http://maps.apple.com/?q=\(encodedName)&ll=\(lat),\(lon)"
        } else {
            return "http://maps.apple.com/?ll=\(lat),\(lon)"
        }
    }

    private func formatDate(_ date: Date, granularity: DateGranularity) -> String {
        switch granularity {
        case .dateAndTime:
            date.formatted(date: .abbreviated, time: .shortened)
        case .dateOnly:
            date.formatted(date: .abbreviated, time: .omitted)
        case .timeOnly:
            date.formatted(date: .omitted, time: .shortened)
        }
    }

    private func formatDateRange(_ range: DateRange, granularity: DateGranularity) -> String {
        let startStr = formatDate(range.start, granularity: granularity)
        let endStr = formatDate(range.end, granularity: granularity)
        return "\(startStr) → \(endStr)"
    }

    private func formatDateFrequency(_ frequency: DateFrequency) -> String {
        let dayName = Calendar.current.weekdaySymbols[frequency.dayOfWeek.rawValue]
        let prefix = frequency.interval == 1 ? "Every" : "Every \(frequency.interval)"
        return "\(prefix) \(dayName)"
    }

    private func formatMeasurementValue(_ measurement: Measurement) -> String {
        switch measurement.type {
        case let .length(unit):
            String(format: "%.2f%@", measurement.value, unit.symbol)
        case .percentage:
            String(format: "%.1f%%", measurement.value)
        case .currency:
            String(format: "$%.2f", measurement.value)
        case let .mass(unit):
            String(format: "%.2f%@", measurement.value, unit.symbol)
        case let .volume(unit):
            String(format: "%.2f%@", measurement.value, unit.symbol)
        case let .temperature(unit):
            String(format: "%.1f%@", measurement.value, unit.symbol)
        case let .duration(unit):
            String(format: "%.0f%@", measurement.value, unit.symbol)
        case let .speed(unit):
            String(format: "%.1f%@", measurement.value, unit.symbol)
        case let .area(unit):
            String(format: "%.2f%@", measurement.value, unit.symbol)
        case let .energy(unit):
            String(format: "%.2f%@", measurement.value, unit.symbol)
        case .number:
            String(format: "%.2f", measurement.value)
        }
    }
}

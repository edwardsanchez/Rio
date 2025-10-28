//
//  MessageEmojiService.swift
//  Rio
//
//  Created by Assistant on 11/18/25.
//

import Foundation
import MapKit
import SwiftUI

enum EmojiReactionPrompt {
    static let system = """
        You are a conversation-aware emoji curator specializing in expressive yet thoughtful reactions for chat platforms.
        Your task is to return six emoji suggestions, each with:
        •    character: one emoji glyph (no emoji names, codes, or placeholders)
        
        Organize the reactions from most to least fitting based on the original message. Avoid repeating emojis and ensure reactions respond to the message rather than just mirror the sender’s tone.
        
        Key behavior requirements:
        1.    Be context-sensitive: Avoid 👍/👎 in serious/sensitive moments (e.g., grief, illness).
        2.    Use 👍 and or 👎 when a question is asked, and when doing so would not feel tone-deaf or insensitive.
        3.    If a humorous attempt is detected, include 1–2 laughing emojis near the top of the list.
        4.    Never duplicate emojis within the same list.
        5.    Responses should consider tone_hint (if provided) to guide overall mood and relevance.
        6.    Out of the 6, at least 4 should be a face, hand or in appropriate cases, a heart type emoji. These types are most common as reactions.
        """
}

enum EmojiReactionSchema {
    static let openAI: [String: Any] = [
        "name": "emoji_reaction_response",
        "schema": [
            "type": "object",
            "properties": [
                "suggestions": [
                    "type": "array",
                    "minItems": 6,
                    "maxItems": 6,
                    "items": [
                        "type": "object",
                        "properties": [
                            "character": ["type": "string"]
                        ],
                        "required": ["character"],
                        "additionalProperties": false
                    ]
                ]
            ],
            "required": ["suggestions"],
            "additionalProperties": false
        ]
    ]
}

enum OpenAIEmojiAPI {
    private static let defaultModel = "gpt-4.1-nano-2025-04-14"

    static func sendCompletion(
        systemPrompt: String,
        userPrompt: String,
        schema: [String: Any],
        model: String = defaultModel,
        session: URLSession = .shared,
        errorDomain: String
    ) async throws -> String {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
            throw NSError(
                domain: errorDomain,
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "OPENAI_API_KEY environment variable not set"]
            )
        }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        let payload: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": schema
            ]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: errorDomain,
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response from OpenAI"]
            )
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            throw NSError(
                domain: errorDomain,
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "OpenAI HTTP \(httpResponse.statusCode): \(body)"]
            )
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(
                domain: errorDomain,
                code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Failed to parse OpenAI content"]
            )
        }
        return content
    }
}

enum MessageEmojiService {
    private struct TimeoutError: Error {}

    static var isEnabled = true
    /// Debug helper to hold results before returning (seconds). Set to 0 to disable.
    #if DEBUG
    static var artificialDelay: TimeInterval = 4
    #else
    static var artificialDelay: TimeInterval = 0
    #endif

    private static let fallbackEmojis: [String] = {
        let reactions = ReactionsModifier.defaultReactions
            .filter { $0.id != Reaction.customEmojiReactionID }
            .map(\.selectedEmoji)
        if reactions.isEmpty {
            return ["😍", "👍", "👎", "😂", "😲", "🧐"]
        }
        return reactions
    }()
    private static let maxContextCharacters = 10_000
    private static let timeoutNanoseconds: UInt64 = 2_000_000_000

    static func fallbackReactionOptions() -> [String] {
        fallbackEmojis
    }

    static func reactionOptions(
        for message: Message,
        in messages: [Message],
        currentUser: User
    ) async -> [String] {
        guard isEnabled else {
            return fallbackEmojis
        }

        guard message.messageType(currentUser: currentUser).isInbound else {
            return []
        }

        guard let prompt = buildPrompt(for: message, in: messages, currentUser: currentUser) else {
            return fallbackEmojis
        }

        do {
            let suggestions = try await fetchWithTimeout(prompt: prompt)
            let resolved = suggestions.isEmpty ? fallbackEmojis : suggestions
            await applyArtificialDelayIfNeeded()
            return resolved
        } catch {
            return fallbackEmojis
        }
    }

    private static func fetchWithTimeout(prompt: String) async throws -> [String] {
        try await withThrowingTaskGroup(of: [String].self) { group in
            group.addTask {
                try await requestOpenAI(prompt: prompt)
            }

            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw TimeoutError()
            }

            guard let result = try await group.next() else {
                throw TimeoutError()
            }
            group.cancelAll()
            return result
        }
    }

    private static func requestOpenAI(prompt: String) async throws -> [String] {
        let rawContent = try await OpenAIEmojiAPI.sendCompletion(
            systemPrompt: EmojiReactionPrompt.system,
            userPrompt: prompt,
            schema: EmojiReactionSchema.openAI,
            errorDomain: "MessageEmojiService"
        )
        guard let data = rawContent.data(using: .utf8) else {
            throw NSError(
                domain: "MessageEmojiService",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Invalid OpenAI content encoding"]
            )
        }
        let decoded = try JSONDecoder().decode(OpenAIEmojiReactionResponse.self, from: data)
        let characters = decoded.suggestions
            .map(\.character)
            .filter { !$0.isEmpty }
        return Array(characters.prefix(6))
    }

    private static func buildPrompt(
        for message: Message,
        in messages: [Message],
        currentUser: User
    ) -> String? {
        guard let context = makeConversationContext(for: message, in: messages, currentUser: currentUser) else {
            return nil
        }

        let trimmedContext: String
        if context.count > maxContextCharacters {
            trimmedContext = String(context.suffix(maxContextCharacters))
        } else {
            trimmedContext = context
        }

        return """
        Conversation transcript (most recent last):
        \(trimmedContext)

        Return a JSON object with key "suggestions" containing exactly six objects with a "character" field holding a single emoji that would be an appropriate reaction to the final message shown above.
        """
    }

    private static func makeConversationContext(
        for message: Message,
        in messages: [Message],
        currentUser: User
    ) -> String? {
        guard let messageIndex = messages.firstIndex(where: { $0.id == message.id }) else {
            return nil
        }

        let lowerBound = max(0, messageIndex - 5)
        let relevantMessages = messages[lowerBound...messageIndex]

        let lines = relevantMessages.compactMap { entry -> String? in
            guard let text = contentDescription(for: entry) else {
                return nil
            }
            let speaker = entry.user.id == currentUser.id ? "You" : entry.user.name
            return "\(speaker): \(text)"
        }

        guard !lines.isEmpty else {
            return nil
        }

        return lines.joined(separator: "\n")
    }

    private static func contentDescription(for message: Message) -> String? {
        switch message.content {
        case .text(let text):
            return text
        case .emoji(let emoji):
            return emoji
        case .code(let snippet):
            return snippet
        case .url(let url):
            return url.absoluteString
        case .bool(let value):
            return value ? "True" : "False"
        case .rating(let rating):
            return "Rating: \(rating.rawValue + 1)/\(Rating.allCases.count)"
        case .date(let date, granularity: _):
            return DateFormatter.shortDateFormatter.string(from: date)
        case .dateRange(let range, granularity: _):
            let start = DateFormatter.shortDateFormatter.string(from: range.start)
            let end = DateFormatter.shortDateFormatter.string(from: range.end)
            return "\(start) – \(end)"
        case .dateFrequency:
            return "Repeating event"
        case .location(let item):
            return item.name ?? "Location shared"
        case .value(let measurement):
            return "\(measurement.value)"
        case .valueRange(let measurementRange):
            return "\(measurementRange.lowerBound.value) – \(measurementRange.upperBound.value)"
        case .textChoice(let choice):
            return choice
        case .multiChoice(let choices):
            return choices.map { describeChoiceValue($0) }.joined(separator: ", ")
        case .color:
            return "Color shared"
        case .image:
            return "Image shared"
        case .labeledImage(let labeled):
            return labeled.label
        case .video:
            return "Video shared"
        case .audio:
            return "Audio message"
        case .file:
            return "File shared"
        }
    }

    private static func describeChoiceValue(_ choice: ChoiceValue) -> String {
        switch choice {
        case .color(let rgb):
            if let name = rgb.name {
                return "Color \(name)"
            }
            return "Color"
        case .image:
            return "Image option"
        case .labeledImage(let labeled):
            return labeled.label
        case .location(let item):
            return item.name ?? "Location option"
        case .textChoice(let text):
            return text
        }
    }
}

private extension DateFormatter {
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private extension MessageEmojiService {
    static func applyArtificialDelayIfNeeded() async {
        guard artificialDelay > 0 else { return }
        let nanoseconds = UInt64(artificialDelay * 1_000_000_000)
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

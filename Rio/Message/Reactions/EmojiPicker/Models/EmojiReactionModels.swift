//
//  EmojiReactionModels.swift
//  EmojiPicker
//
//  Created by Edward Sanchez on 10/23/25.
//

import Foundation
import FoundationModels

// MARK: - Provider

enum EmojiProvider: String, CaseIterable, Identifiable {
    case openai = "OpenAI"
    case claude = "Claude"
    case apple = "Apple"
    var id: String { rawValue }
}

// MARK: - Fast Reaction Models

@Generable
struct FastEmojiSuggestion: Sendable {
    @Guide(description: "Emoji character for the reaction")
    let character: String
}

@Generable
struct FastEmojiReactionResponse: Sendable {
    @Guide(description: "Exactly six emoji reactions ordered best to worst", .count(6))
    let suggestions: [FastEmojiSuggestion]
}

// MARK: - OpenAI DTOs

struct OpenAIEmojiSuggestion: Decodable {
    let character: String
}

struct OpenAIEmojiReactionResponse: Decodable {
    let suggestions: [OpenAIEmojiSuggestion]
}

// MARK: - Claude DTOs

struct ClaudeEmojiSuggestion: Decodable {
    let character: String
}

struct ClaudeEmojiReactionResponse: Decodable {
    let suggestions: [ClaudeEmojiSuggestion]
}

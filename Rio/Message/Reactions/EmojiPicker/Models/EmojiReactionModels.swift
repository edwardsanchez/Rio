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
    case apple = "Apple"
    var id: String { rawValue }
}

// MARK: - Fast Reaction Models

@Generable
struct FastEmojiSuggestion: Sendable {
    @Guide(description: "Emoji character for the reaction")
    let character: String
    
    @Guide(description: "Short descriptive name for the emoji reaction")
    let name: String
    
    @Guide(description: "Brief reason tying the emoji to user_text")
    let reason: String
}

@Generable
struct FastEmojiReactionResponse: Sendable {
    @Guide(description: "Exactly six emoji reactions ordered best to worst", .count(6))
    let suggestions: [FastEmojiSuggestion]
}

// MARK: - OpenAI DTOs

struct OpenAIEmojiSuggestion: Decodable {
    let character: String
    let name: String
    let reason: String
}

struct OpenAIEmojiReactionResponse: Decodable {
    let suggestions: [OpenAIEmojiSuggestion]
}

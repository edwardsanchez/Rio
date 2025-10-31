//
//  EmojiAIService.swift
//  EmojiPicker
//
//  Created by Edward Sanchez on 10/23/25.
//

import Foundation

enum EmojiAIService {
    // MARK: - Emoji Filtering

    /// Gets all emojis from EmojiData
    static var allEmojis: [Emoji] {
        EmojiData.peopleEmojis +
            EmojiData.expressiveEmojis +
            EmojiData.natureEmojis +
            EmojiData.foodEmojis +
            EmojiData.activitiesEmojis +
            EmojiData.travelEmojis +
            EmojiData.objectsEmojis +
            EmojiData.symbolsEmojis
    }

    /// Filters emojis by category ID
    static func getEmojisForCategory(categoryId: String) -> [Emoji] {
        let allEmojis = Self.allEmojis
        return allEmojis.filter { $0.category.id == categoryId }
    }

    /// Converts emoji to dictionary format for model input
    static func emojiToDict(_ emoji: Emoji) -> [String: Any] {
        [
            "id": emoji.id,
            "character": emoji.character,
            "name": emoji.name,
            "keywords": emoji.keywords,
            "category_id": emoji.category.id
        ]
    }

    /// Converts array of emojis to dictionary format
    static func emojisToDict(_ emojis: [Emoji]) -> [[String: Any]] {
        emojis.map { emojiToDict($0) }
    }

    /// Finds an emoji by ID
    static func findEmoji(byId id: String) -> Emoji? {
        allEmojis.first { $0.id == id }
    }
}

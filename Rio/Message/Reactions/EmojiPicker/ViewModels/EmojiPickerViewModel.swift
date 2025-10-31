//
//  EmojiPickerViewModel.swift
//  EmojiPicker
//
//  Created by Edward Sanchez on 10/22/25.
//

import Foundation
import SwiftUI

@Observable
class EmojiPickerViewModel {
    var selectedCategory: EmojiCategory = .frequentlyUsed
    var searchText: String = ""
    private(set) var frequentlyUsedEmojis: [Emoji] = []

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isSearching: Bool {
        normalizedSearchText.count >= 3
    }

    var filteredEmojis: [Emoji] {
        guard isSearching else { return [] }

        let allEmojis = EmojiAIService.allEmojis
        let query = normalizedSearchText.lowercased()

        return allEmojis.filter { emoji in
            emoji.name.lowercased().contains(query) ||
                emoji.keywords.contains { $0.lowercased().contains(query) }
        }
    }

    private let userDefaults = UserDefaults.standard

    init() {
        frequentlyUsedEmojis = frequentlyUsedEmojiSnapshot
    }

    // Get emojis for a specific category
    func emojis(for category: EmojiCategory) -> [Emoji] {
        switch category {
        case .frequentlyUsed:
            frequentlyUsedEmojis
        case .people:
            EmojiData.peopleEmojis
        case .nature:
            EmojiData.natureEmojis
        case .food:
            EmojiData.foodEmojis
        case .activities:
            EmojiData.activitiesEmojis
        case .travel:
            EmojiData.travelEmojis
        case .objects:
            EmojiData.objectsEmojis
        case .symbols:
            EmojiData.symbolsEmojis
        case .expressive:
            EmojiData.expressiveEmojis
        }
    }

    // Refresh frequently used emojis (top 20)
    func refreshFrequentlyUsedEmojis() {
        frequentlyUsedEmojis = frequentlyUsedEmojiSnapshot
    }

    private var frequentlyUsedEmojiSnapshot: [Emoji] {
        let usageCounts = userDefaults.frequentlyUsedEmojiIDs
        guard !usageCounts.isEmpty else { return [] }

        // Get all emojis
        let allEmojis = [
            EmojiData.peopleEmojis,
            EmojiData.natureEmojis,
            EmojiData.foodEmojis,
            EmojiData.activitiesEmojis,
            EmojiData.travelEmojis,
            EmojiData.objectsEmojis,
            EmojiData.symbolsEmojis,
            EmojiData.expressiveEmojis
        ].flatMap { $0 }

        // Create a map for quick lookup
        let emojiMap = Dictionary(uniqueKeysWithValues: allEmojis.map { ($0.id, $0) })

        // Sort by usage count and get top 20
        return usageCounts
            .sorted { $0.value > $1.value }
            .prefix(20)
            .compactMap { emojiMap[$0.key] }
    }

    // Track emoji usage
    func trackEmojiUsage(_ emoji: Emoji, sourceCategory: EmojiCategory) {
        var counts = userDefaults.frequentlyUsedEmojiIDs
        counts[emoji.id, default: 0] += 1
        userDefaults.frequentlyUsedEmojiIDs = counts

        if sourceCategory != .frequentlyUsed {
            refreshFrequentlyUsedEmojis()
        }
    }
}

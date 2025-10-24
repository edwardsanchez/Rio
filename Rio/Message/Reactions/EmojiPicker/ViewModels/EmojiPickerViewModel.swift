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
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        frequentlyUsedEmojis = loadFrequentlyUsedEmojis()
    }
    
    // Get emojis for a specific category
    func emojis(for category: EmojiCategory) -> [Emoji] {
        switch category {
        case .frequentlyUsed:
            return frequentlyUsedEmojis
        case .people:
            return EmojiData.peopleEmojis
        case .nature:
            return EmojiData.natureEmojis
        case .food:
            return EmojiData.foodEmojis
        case .activities:
            return EmojiData.activitiesEmojis
        case .travel:
            return EmojiData.travelEmojis
        case .objects:
            return EmojiData.objectsEmojis
        case .symbols:
            return EmojiData.symbolsEmojis
        case .expressive:
            return EmojiData.expressiveEmojis
        }
    }
    
    // Refresh frequently used emojis (top 20)
    func refreshFrequentlyUsedEmojis() {
        frequentlyUsedEmojis = loadFrequentlyUsedEmojis()
    }
    
    private func loadFrequentlyUsedEmojis() -> [Emoji] {
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

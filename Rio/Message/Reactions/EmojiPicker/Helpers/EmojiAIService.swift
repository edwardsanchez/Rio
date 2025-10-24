//
//  EmojiAIService.swift
//  EmojiPicker
//
//  Created by Edward Sanchez on 10/23/25.
//

import Foundation

struct EmojiAIService {
    
    // MARK: - Category Index Builder
    
    /// Builds a comprehensive category index for the AI model
    /// Excludes frequentlyUsed category
    static func buildCategoryIndex() -> [[String: Any]] {
        var index: [[String: Any]] = []
        
        // People subcategories
        for subcat in PeopleSubcategories.allCases {
            let category = EmojiCategory.people(subcat)
            index.append([
                "category_id": category.id,
                "path": "people.\(subcat.rawValue)",
                "description": subcat.description
            ])
        }
        
        // Expressive subcategories
        for subcat in ExpressiveSubcategories.allCases {
            let category = EmojiCategory.expressive(subcat)
            index.append([
                "category_id": category.id,
                "path": "expressive.\(subcat.rawValue)",
                "description": subcat.description
            ])
        }
        
        // Nature subcategories
        for subcat in NatureSubCatchories.allCases {
            let category = EmojiCategory.nature(subcat)
            index.append([
                "category_id": category.id,
                "path": "nature.\(subcat.rawValue)",
                "description": subcat.description
            ])
        }
        
        // Food subcategories
        for subcat in FoodSubcategories.allCases {
            let category = EmojiCategory.food(subcat)
            index.append([
                "category_id": category.id,
                "path": "food.\(subcat.rawValue)",
                "description": subcat.description
            ])
        }
        
        // Activities subcategories
        for subcat in ActivitiesSubcategories.allCases {
            let category = EmojiCategory.activities(subcat)
            index.append([
                "category_id": category.id,
                "path": "activities.\(subcat.rawValue)",
                "description": subcat.description
            ])
        }
        
        // Travel subcategories
        for subcat in TravelSubcategories.allCases {
            let category = EmojiCategory.travel(subcat)
            index.append([
                "category_id": category.id,
                "path": "travel.\(subcat.rawValue)",
                "description": subcat.description
            ])
        }
        
        // Objects subcategories
        for subcat in ObjectsSubcategories.allCases {
            let category = EmojiCategory.objects(subcat)
            index.append([
                "category_id": category.id,
                "path": "objects.\(subcat.rawValue)",
                "description": subcat.description
            ])
        }
        
        // Symbols subcategories (including nested flags)
        let symbolsBasicCases: [(SymbolsSubcategories, String)] = [
            (.sign, "sign"),
            (.arrow, "arrow"),
            (.religious, "religious"),
            (.zodiac, "zodiac"),
            (.media, "media"),
            (.number, "number"),
            (.shape, "shape"),
            (.other, "other")
        ]
        
        for (subcat, rawValue) in symbolsBasicCases {
            index.append([
                "category_id": subcat.id,
                "path": "symbols.\(rawValue)",
                "description": subcat.description
            ])
        }
        
        // Flag subcategories
        for flagSubcat in SymbolsSubcategories.FlagSubcategories.allCases {
            let subcat = SymbolsSubcategories.flag(flagSubcat)
            index.append([
                "category_id": subcat.id,
                "path": "symbols.flag.\(flagSubcat.rawValue)",
                "description": flagSubcat.description
            ])
        }
        
        return index
    }
    
    // MARK: - Emoji Filtering
    
    /// Gets all emojis from EmojiData
    static func getAllEmojis() -> [Emoji] {
        return EmojiData.peopleEmojis +
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
        let allEmojis = getAllEmojis()
        return allEmojis.filter { $0.category.id == categoryId }
    }
    
    /// Converts emoji to dictionary format for model input
    static func emojiToDict(_ emoji: Emoji) -> [String: Any] {
        return [
            "id": emoji.id,
            "character": emoji.character,
            "name": emoji.name,
            "keywords": emoji.keywords,
            "category_id": emoji.category.id
        ]
    }
    
    /// Converts array of emojis to dictionary format
    static func emojisToDict(_ emojis: [Emoji]) -> [[String: Any]] {
        return emojis.map { emojiToDict($0) }
    }
    
    /// Finds an emoji by ID
    static func findEmoji(byId id: String) -> Emoji? {
        return getAllEmojis().first { $0.id == id }
    }
}

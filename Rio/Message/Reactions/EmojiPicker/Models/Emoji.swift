//
//  Emoji.swift
//  EmojiPicker
//
//  Created by Edward Sanchez on 10/22/25.
//

import Foundation

struct Emoji: Identifiable, Hashable {
    let id: String
    let character: String
    let name: String
    let keywords: [String]
    let category: EmojiCategory
    
    init(id: String, character: String, name: String, keywords: [String] = [], category: EmojiCategory) {
        self.id = id
        self.character = character
        self.name = name
        self.keywords = keywords
        self.category = category
    }
}


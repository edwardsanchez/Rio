//
//  DefaultsKeys.swift
//  EmojiPicker
//
//  Created by Edward Sanchez on 10/22/25.
//

import Foundation

extension UserDefaults {
    private enum Keys {
        static let frequentlyUsedEmojiIDs = "frequentlyUsedEmojiIDs"
    }

    var frequentlyUsedEmojiIDs: [String: Int] {
        get { (dictionary(forKey: Keys.frequentlyUsedEmojiIDs) as? [String: Int]) ?? [:] }
        set { set(newValue, forKey: Keys.frequentlyUsedEmojiIDs) }
    }
}

//
//  ContentTypeDetector.swift
//  Rio
//
//  Created by Edward Sanchez on 10/18/25.
//

import Foundation

/// Utility for detecting content types in text messages
struct ContentTypeDetector {
    
    /// Checks if a string contains only emoji characters (1-3 emoji)
    /// - Parameter text: The text to check
    /// - Returns: True if the text contains only 1-3 emoji characters
    static func isEmojiOnly(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        
        // Count emoji characters
        let emojiCount = trimmed.reduce(0) { count, char in
            count + (char.isEmoji ? 1 : 0)
        }
        
        // Check if all characters are emoji and count is 1-3
        let allEmoji = trimmed.allSatisfy { $0.isEmoji }
        return allEmoji && emojiCount >= 1 && emojiCount <= 3
    }
    
    /// Detects URLs in text and splits the text into segments
    /// - Parameter text: The text to parse
    /// - Returns: Array of tuples containing (content, isURL)
    static func detectURLs(in text: String) -> [(content: String, isURL: Bool)] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return [(content: text, isURL: false)]
        }
        
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        
        // If no URLs found, return the original text
        guard !matches.isEmpty else {
            return [(content: text, isURL: false)]
        }
        
        var segments: [(content: String, isURL: Bool)] = []
        var currentIndex = text.startIndex
        
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            
            // Add text before URL (if any)
            if currentIndex < range.lowerBound {
                let textBeforeURL = String(text[currentIndex..<range.lowerBound])
                if !textBeforeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    segments.append((content: textBeforeURL, isURL: false))
                }
            }
            
            // Add URL
            let urlString = String(text[range])
            segments.append((content: urlString, isURL: true))
            
            currentIndex = range.upperBound
        }
        
        // Add remaining text after last URL (if any)
        if currentIndex < text.endIndex {
            let remainingText = String(text[currentIndex...])
            if !remainingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                segments.append((content: remainingText, isURL: false))
            }
        }
        
        return segments
    }
    
    /// Creates appropriate ContentType based on text content
    /// - Parameter text: The text to analyze
    /// - Returns: Appropriate ContentType (.emoji for emoji-only 1-3, .text otherwise)
    static func contentType(for text: String) -> ContentType {
        if isEmojiOnly(text) {
            return .emoji(text.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            return .text(text)
        }
    }
}

// MARK: - Character Extension for Emoji Detection

extension Character {
    /// A simple emoji check based on Unicode scalar properties
    var isEmoji: Bool {
        // Check if the character contains emoji
        guard let firstScalar = unicodeScalars.first else { return false }
        
        // Emoji ranges and properties
        return firstScalar.properties.isEmoji && 
               (firstScalar.properties.isEmojiPresentation || 
                unicodeScalars.count > 1)
    }
}



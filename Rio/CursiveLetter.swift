//
//  CursiveLetter.swift
//  Rio
//
//  Created by Edward Sanchez on 9/25/25.
//

import SwiftUI
import SVGPath

struct CursiveLetter {
    let character: String
    let path: CGPath
    
    static let allLetters: [CursiveLetter] = {
        var letters: [CursiveLetter] = []

        // Load uppercase letters A-Z (files are prefixed with "Capital-")
        for ascii in 65...90 { // A-Z
            if let scalar = UnicodeScalar(ascii) {
                let char = String(scalar)
                if let letter = loadLetter(character: char, filename: "Capital-\(char)") {
                    letters.append(letter)
                    print("Successfully loaded letter: \(char)")
                } else {
                    print("Failed to load letter: \(char)")
                }
            }
        }

        // Load lowercase letters a-z
        for ascii in 97...122 { // a-z
            if let scalar = UnicodeScalar(ascii) {
                let char = String(scalar)
                if let letter = loadLetter(character: char) {
                    letters.append(letter)
                    print("Successfully loaded letter: \(char)")
                } else {
                    print("Failed to load letter: \(char)")
                }
            }
        }

        // Load numbers 0-9
        for ascii in 48...57 {
            if let character = UnicodeScalar(ascii) {
                let char = String(character)
                if let letter = loadLetter(character: char) {
                    letters.append(letter)
                    print("Successfully loaded number: \(char)")
                } else {
                    print("Failed to load number: \(char)")
                }
            }
        }

        // Load space
        if let spaceLetter = loadLetter(character: " ", filename: "space") {
            letters.append(spaceLetter)
            print("Successfully loaded space")
        } else {
            print("Failed to load space")
        }

        print("Total letters loaded: \(letters.count)")
        return letters
    }()
    
    private static func loadLetter(character: String, filename: String? = nil) -> CursiveLetter? {
        let svgFilename = filename ?? character
        
        // Try to load from subdirectory "svg" first, then fallback to root bundle resources
        var data: Data?
        if let url = Bundle.main.url(forResource: svgFilename, withExtension: "svg", subdirectory: "svg") {
            data = try? Data(contentsOf: url)
        } else if let url = Bundle.main.url(forResource: svgFilename, withExtension: "svg") {
            data = try? Data(contentsOf: url)
        }
        guard let svgData = data, let svgString = String(data: svgData, encoding: .utf8) else {
            print("Failed to load SVG file for character: \(character)")
            return nil
        }
        
        // Extract the path data from the SVG
        guard let pathData = extractPathData(from: svgString) else {
            print("Failed to extract path data for character: \(character)")
            return nil
        }
        
        // Create CGPath from SVG path data
        do {
            let cgPath = try CGPath.from(svgPath: pathData)
            return CursiveLetter(character: character, path: cgPath)
        } catch {
            print("Failed to create CGPath for character \(character): \(error)")
            return nil
        }
    }
    
    private static func extractPathData(from svgString: String) -> String? {
        // Look for the path d attribute - try multiple patterns
        let patterns = [
            #"<path\s+[^>]*d="([^"]*)"[^>]*>"#,
            #"<path[^>]*d="([^"]*)"[^>]*>"#,
            #"d="([^"]*)"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: svgString, options: [], range: NSRange(location: 0, length: svgString.count)),
               let range = Range(match.range(at: 1), in: svgString) {
                let pathData = String(svgString[range])
                print("Extracted path data: \(pathData.prefix(50))...")
                return pathData
            }
        }

        print("Failed to extract path data from SVG")
        return nil
    }
    
    static func letter(for character: String) -> CursiveLetter? {
        // Prefer exact-case match if available
        if let exact = allLetters.first(where: { $0.character == character }) {
            return exact
        }
        // Fallback to case-insensitive match
        return allLetters.first { $0.character.caseInsensitiveCompare(character) == .orderedSame }
    }
}

// SwiftUI Shape for rendering cursive letters
struct CursiveLetterShape: Shape {
    let letter: CursiveLetter
    
    func path(in rect: CGRect) -> Path {
        // 1) Translate so minX/minY is at the origin
        var t = CGAffineTransform(translationX: -letter.path.boundingBox.minX, y: -letter.path.boundingBox.minY)
        guard let originPath = letter.path.copy(using: &t) else { return Path(letter.path) }

        // 2) Flip vertically in local coordinates (Y-down SVG -> Y-up CoreGraphics)
        let originBox = originPath.boundingBox
        var flip = CGAffineTransform(scaleX: 1, y: -1)
        guard let flippedPath = originPath.copy(using: &flip) else { return Path(originPath) }
        var translateAfterFlip = CGAffineTransform(translationX: 0, y: originBox.height)
        guard let yUpPath = flippedPath.copy(using: &translateAfterFlip) else { return Path(flippedPath) }

        // 3) Compute scale to fit
        let scaleX = rect.width / originBox.width
        let scaleY = rect.height / originBox.height
        let scale = min(scaleX, scaleY)
        var s = CGAffineTransform(scaleX: scale, y: scale)
        guard let scaledPath = yUpPath.copy(using: &s) else { return Path(yUpPath) }

        // 4) Center in rect
        let scaledSize = CGSize(width: originBox.width * scale, height: originBox.height * scale)
        let offsetX = (rect.width - scaledSize.width) / 2
        let offsetY = (rect.height - scaledSize.height) / 2
        var centerT = CGAffineTransform(translationX: offsetX, y: offsetY)
        guard let centeredPath = scaledPath.copy(using: &centerT) else { return Path(scaledPath) }

        return Path(centeredPath)
    }
}

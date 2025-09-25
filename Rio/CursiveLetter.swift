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

        // Load uppercase letters A-Z
        for ascii in 65...90 {
            if let character = UnicodeScalar(ascii) {
                let char = String(character)
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
        
        guard let url = Bundle.main.url(forResource: svgFilename, withExtension: "svg", subdirectory: "svg"),
              let svgData = try? Data(contentsOf: url),
              let svgString = String(data: svgData, encoding: .utf8) else {
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
        return allLetters.first { $0.character.uppercased() == character.uppercased() }
    }
}

// SwiftUI Shape for rendering cursive letters
struct CursiveLetterShape: Shape {
    let letter: CursiveLetter
    
    func path(in rect: CGRect) -> Path {
        let path = Path(letter.path)
        
        // Get the bounding box of the original path
        let boundingBox = letter.path.boundingBox
        
        // Calculate scale to fit the letter in the given rect
        let scaleX = rect.width / boundingBox.width
        let scaleY = rect.height / boundingBox.height
        let scale = min(scaleX, scaleY)
        
        // Create transform to scale and position the path
        var transform = CGAffineTransform.identity
        transform = transform.scaledBy(x: scale, y: scale)
        transform = transform.translatedBy(x: -boundingBox.minX, y: -boundingBox.minY)
        
        // Center the scaled path in the rect
        let scaledSize = CGSize(width: boundingBox.width * scale, height: boundingBox.height * scale)
        let offsetX = (rect.width - scaledSize.width) / 2
        let offsetY = (rect.height - scaledSize.height) / 2
        transform = transform.translatedBy(x: offsetX / scale, y: offsetY / scale)
        
        return path.applying(transform)
    }
}

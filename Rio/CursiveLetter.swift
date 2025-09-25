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
    let advance: CGFloat
    let ascent: CGFloat
    let descent: CGFloat
    let verticalExtent: CGFloat
    let unitsPerEm: CGFloat

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
        
        let metrics = parseMetrics(from: svgString)
        
        // Extract the path data from the SVG
        guard let pathData = extractPathData(from: svgString) else {
            print("Failed to extract path data for character: \(character)")
            return nil
        }
        
        // Create CGPath from SVG path data
        do {
            let rawPath = try CGPath.from(svgPath: pathData)
            let rawBounds = rawPath.boundingBox

            if let m = metrics {
                // Normalize to Y-down with baseline at y=ascent if incoming path appears Y-up (minY < 0)
                var normalized = rawPath
                if rawBounds.minY < 0 {
                    var flip = CGAffineTransform(scaleX: 1, y: -1)
                    if let p1 = normalized.copy(using: &flip) { normalized = p1 }
                    var translate = CGAffineTransform(translationX: 0, y: m.ascent)
                    if let p2 = normalized.copy(using: &translate) { normalized = p2 }
                }

                return CursiveLetter(
                    character: character,
                    path: normalized,
                    advance: m.advance,
                    ascent: m.ascent,
                    descent: m.descent,
                    verticalExtent: m.verticalExtent,
                    unitsPerEm: m.unitsPerEm
                )
            } else {
                // Fallback: estimate metrics, and normalize to Y-down if needed
                var normalized = rawPath
                let box = rawBounds
                let height = max(1, box.height)
                let ascent = height * 0.8
                let descent = ascent - height
                if box.minY < 0 {
                    var flip = CGAffineTransform(scaleX: 1, y: -1)
                    if let p1 = normalized.copy(using: &flip) { normalized = p1 }
                    var translate = CGAffineTransform(translationX: 0, y: ascent)
                    if let p2 = normalized.copy(using: &translate) { normalized = p2 }
                }

                return CursiveLetter(
                    character: character,
                    path: normalized,
                    advance: max(1, box.width),
                    ascent: ascent,
                    descent: descent,
                    verticalExtent: height,
                    unitsPerEm: height
                )
            }
        } catch {
            print("Failed to create CGPath for character \(character): \(error)")
            return nil
        }
    }

    private static func parseMetrics(from svgString: String) -> (advance: CGFloat, ascent: CGFloat, descent: CGFloat, verticalExtent: CGFloat, unitsPerEm: CGFloat)? {
        func attr(_ name: String) -> CGFloat? {
            let pattern = name + #"\=\"([^\"]+)\""#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            guard let match = regex.firstMatch(in: svgString, options: [], range: NSRange(location: 0, length: svgString.count)) else { return nil }
            guard let range = Range(match.range(at: 1), in: svgString) else { return nil }
            return CGFloat(Double(svgString[range]) ?? .nan)
        }

        let advance = attr("data-advance")
        let ascent = attr("data-ascent")
        let descent = attr("data-descent")
        let vertical = attr("data-vertical-extent")
        let upm = attr("data-units-per-em")

        if let a = advance, let asc = ascent, let desc = descent, let v = vertical, let u = upm {
            return (advance: a, ascent: asc, descent: desc, verticalExtent: v, unitsPerEm: u)
        }

        // Fallback: parse viewBox="0 0 width height" and width attribute as advance
        if let viewBoxMatch = try? NSRegularExpression(pattern: #"viewBox\=\"0\s+0\s+([0-9\.\-]+)\s+([0-9\.\-]+)\""#, options: []) {
            if let m = viewBoxMatch.firstMatch(in: svgString, options: [], range: NSRange(location: 0, length: svgString.count)),
               let wRange = Range(m.range(at: 1), in: svgString),
               let hRange = Range(m.range(at: 2), in: svgString) {
                let width = CGFloat(Double(svgString[wRange]) ?? 0)
                let height = CGFloat(Double(svgString[hRange]) ?? 0)
                let adv = attr("width") ?? width
                let asc = height * 0.8
                let desc = asc - height
                return (advance: adv, ascent: asc, descent: desc, verticalExtent: height, unitsPerEm: height)
            }
        }

        return nil
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
        // Translate so minX/minY is at the origin
        var t = CGAffineTransform(translationX: -letter.path.boundingBox.minX, y: -letter.path.boundingBox.minY)
        guard let originPath = letter.path.copy(using: &t) else { return Path(letter.path) }

        // Compute scale to fit
        let originBox = originPath.boundingBox
        let scaleX = rect.width / originBox.width
        let scaleY = rect.height / originBox.height
        let scale = min(scaleX, scaleY)
        var s = CGAffineTransform(scaleX: scale, y: scale)
        guard let scaledPath = originPath.copy(using: &s) else { return Path(originPath) }

        // Center in rect
        let scaledSize = CGSize(width: originBox.width * scale, height: originBox.height * scale)
        let offsetX = (rect.width - scaledSize.width) / 2
        let offsetY = (rect.height - scaledSize.height) / 2
        var centerT = CGAffineTransform(translationX: offsetX, y: offsetY)
        guard let centeredPath = scaledPath.copy(using: &centerT) else { return Path(scaledPath) }

        return Path(centeredPath)
    }
}

struct CursiveWordShape: Shape {
    let text: String

    func path(in rect: CGRect) -> Path {
        var letters: [CursiveLetter] = []
        var totalAdvance: CGFloat = 0
        for ch in text {
            let s = String(ch)
            if let letter = CursiveLetter.letter(for: s) {
                letters.append(letter)
                totalAdvance += letter.advance
            }
        }
        guard let first = letters.first else { return Path() }

        let verticalExtent = first.verticalExtent
        let scaleX = rect.width / max(1, totalAdvance)
        let scaleY = rect.height / max(1, verticalExtent)
        let scale = min(scaleX, scaleY)

        let scaledWidth = totalAdvance * scale
        let offsetX = (rect.width - scaledWidth) / 2

        // Align baseline to the vertical center of the rect
        let baselineInRect = rect.midY
        let offsetY = baselineInRect - first.ascent * scale

        let combined = CGMutablePath()
        var penX: CGFloat = 0
        for letter in letters {
            var t = CGAffineTransform(translationX: penX, y: 0)
            combined.addPath(letter.path, transform: t)
            penX += letter.advance
        }

        // 1) Scale into screen space
        var scaleT = CGAffineTransform(scaleX: scale, y: scale)
        guard let scaled = combined.copy(using: &scaleT) else { return Path(combined) }

        // 2) Translate in screen space so baseline sits at rect.midY and centered horizontally
        var translateT = CGAffineTransform(translationX: offsetX, y: offsetY)
        guard let baselinePositioned = scaled.copy(using: &translateT) else { return Path(scaled) }

        // Clamp vertically inside rect without changing scale
        var positioned = baselinePositioned
        let b = positioned.boundingBox
        var dy: CGFloat = 0
        if b.minY < rect.minY {
            dy += (rect.minY - b.minY)
        }
        if b.maxY > rect.maxY {
            dy += (rect.maxY - b.maxY)
        }
        if dy != 0 {
            var clampT = CGAffineTransform(translationX: 0, y: dy)
            if let adjusted = positioned.copy(using: &clampT) {
                positioned = adjusted
            }
        }

        // Debug: verify if final drawing lies inside the provided rect
        let bounds = positioned.boundingBox
        let inside = rect.contains(bounds)
        let overflowTop = rect.minY - bounds.minY
        let overflowLeft = rect.minX - bounds.minX
        let overflowBottom = bounds.maxY - rect.maxY
        let overflowRight = bounds.maxX - rect.maxX
        print("CursiveWordShape: rect=\(rect) bounds=\(bounds) inside=\(inside) baselineY=\(baselineInRect) dy=\(dy). Overflows (top,left,bottom,right)=\(overflowTop),\(overflowLeft),\(overflowBottom),\(overflowRight)")

        return Path(positioned)
    }
}

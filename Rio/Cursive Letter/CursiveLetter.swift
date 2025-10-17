//
//  CursiveLetter.swift
//  Rio
//
//  Created by Edward Sanchez on 9/25/25.
//

import SwiftUI
import SVGPath
import OSLog

/**
 * CursiveLetter represents a single character in cursive handwriting style for the typing indicator system.
 *
 * This struct loads SVG font files containing cursive letter paths and provides the necessary typography
 * metrics for proper text layout and animation. Each letter includes its vector path data along with
 * font metrics like advance width, ascent, descent, and baseline positioning.
 *
 * The system supports uppercase letters (A-Z), lowercase letters (a-z), numbers (0-9), and spaces,
 * with SVG files expected to be in the app bundle under an "svg" subdirectory or root resources.
 * Uppercase letters use "Capital-" prefixed filenames to avoid case-insensitive filesystem issues.
 */
struct CursiveLetter {
    /// The character this letter represents (e.g., "a", "B", "3", " ")
    let character: String
    /// The vector path data for drawing this letter, normalized to Y-down coordinate system
    let path: CGPath
    /// Horizontal spacing to advance the pen position after drawing this letter
    let advance: CGFloat
    /// Distance from baseline to the top of the tallest part of the letter
    let ascent: CGFloat
    /// Distance from baseline to the bottom of the lowest part of the letter (typically negative)
    let descent: CGFloat
    /// Total vertical space occupied by this letter (ascent - descent)
    let verticalExtent: CGFloat
    /// Font units per em square, used for scaling calculations
    let unitsPerEm: CGFloat

    /**
     * Lazily-loaded collection of all available cursive letters.
     *
     * This static property loads all supported characters from SVG files in the app bundle:
     * - Uppercase A-Z (using "Capital-" prefixed filenames)
     * - Lowercase a-z (using character as filename)
     * - Numbers 0-9 (using character as filename)
     * - Space character (using "space" filename)
     *
     * Each character is loaded once at first access and cached for the app's lifetime.
     * Loading failures are logged with appropriate severity levels.
     */
    static let allLetters: [CursiveLetter] = {
        var letters: [CursiveLetter] = []

        // Load uppercase letters A-Z (files are prefixed with "Capital-")
        // This prefix avoids case-insensitive filesystem conflicts on macOS/iOS
        for ascii in 65...90 { // A-Z
            if let scalar = UnicodeScalar(ascii) {
                let char = String(scalar)
                if let letter = loadLetter(character: char, filename: "Capital-\(char)") {
                    letters.append(letter)
                    Logger.cursiveLetter.debug("Successfully loaded letter: \(char)")
                } else {
                    Logger.cursiveLetter.warning("Failed to load letter: \(char)")
                }
            }
        }

        // Load lowercase letters a-z
        for ascii in 97...122 { // a-z
            if let scalar = UnicodeScalar(ascii) {
                let char = String(scalar)
                if let letter = loadLetter(character: char) {
                    letters.append(letter)
                    Logger.cursiveLetter.debug("Successfully loaded letter: \(char)")
                } else {
                    Logger.cursiveLetter.fault("Failed to load letter: \(char)")
                }
            }
        }

        // Load numbers 0-9
        for ascii in 48...57 {
            if let character = UnicodeScalar(ascii) {
                let char = String(character)
                if let letter = loadLetter(character: char) {
                    letters.append(letter)
                    Logger.cursiveLetter.debug("Successfully loaded number: \(char)")
                } else {
                    Logger.cursiveLetter.fault("Failed to load number: \(char)")
                }
            }
        }

        // Load space character (uses special "space" filename)
        if let spaceLetter = loadLetter(character: " ", filename: "space") {
            letters.append(spaceLetter)
            Logger.cursiveLetter.debug("Successfully loaded space")
        } else {
            Logger.cursiveLetter.fault("Failed to load space")
        }

        Logger.cursiveLetter.info("Total letters loaded: \(letters.count)")
        return letters
    }()
    
    /**
     * Loads a single cursive letter from an SVG file in the app bundle.
     *
     * This method handles the complete pipeline of loading a character:
     * 1. Locates the SVG file (trying "svg" subdirectory first, then root)
     * 2. Parses typography metrics from SVG attributes or estimates them
     * 3. Extracts the vector path data from the SVG
     * 4. Normalizes coordinate system to Y-down with proper baseline positioning
     * 5. Creates a CursiveLetter instance with all necessary data
     *
     * - Parameters:
     *   - character: The character this letter represents
     *   - filename: Optional custom filename (defaults to character string)
     * - Returns: A CursiveLetter instance, or nil if loading fails
     */
    private static func loadLetter(character: String, filename: String? = nil) -> CursiveLetter? {
        let svgFilename = filename ?? character

        // Try to load from subdirectory "svg" first, then fallback to root bundle resources
        // This allows for organized file structure while maintaining backward compatibility
        var data: Data?
        if let url = Bundle.main.url(forResource: svgFilename, withExtension: "svg", subdirectory: "svg") {
            data = try? Data(contentsOf: url)
        } else if let url = Bundle.main.url(forResource: svgFilename, withExtension: "svg") {
            data = try? Data(contentsOf: url)
        }

        guard let svgData = data, let svgString = String(data: svgData, encoding: .utf8) else {
            Logger.cursiveLetter.fault("Failed to load SVG file for character: \(character)")
            return nil
        }

        // Parse typography metrics from SVG custom attributes
        let metrics = parseMetrics(from: svgString)

        // Extract the path data from the SVG
        guard let pathData = extractPathData(from: svgString) else {
            Logger.cursiveLetter.fault("Failed to extract path data for character: \(character)")
            return nil
        }

        // Create CGPath from SVG path data using SVGPath library
        do {
            let rawPath = try CGPath.from(svgPath: pathData)
            let rawBounds = rawPath.boundingBox

            if let m = metrics {
                // Use parsed metrics and normalize coordinate system
                // SVG fonts often use Y-up coordinates, but SwiftUI expects Y-down
                var normalized = rawPath
                if rawBounds.minY < 0 {
                    // Flip Y-axis to convert from Y-up to Y-down
                    var flip = CGAffineTransform(scaleX: 1, y: -1)
                    if let p1 = normalized.copy(using: &flip) { normalized = p1 }
                    // Translate so baseline is at y=ascent (proper Y-down positioning)
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
                // Fallback: estimate metrics from path bounds when SVG lacks custom attributes
                var normalized = rawPath
                let box = rawBounds
                let height = max(1, box.height)
                // Use typical typography proportions: ascent ≈ 80% of total height
                let ascent = height * 0.8
                let descent = ascent - height // Usually negative

                // Apply same coordinate normalization as above
                if box.minY < 0 {
                    var flip = CGAffineTransform(scaleX: 1, y: -1)
                    if let p1 = normalized.copy(using: &flip) { normalized = p1 }
                    var translate = CGAffineTransform(translationX: 0, y: ascent)
                    if let p2 = normalized.copy(using: &translate) { normalized = p2 }
                }

                return CursiveLetter(
                    character: character,
                    path: normalized,
                    advance: max(1, box.width), // Use width as advance (character spacing)
                    ascent: ascent,
                    descent: descent,
                    verticalExtent: height,
                    unitsPerEm: height
                )
            }
        } catch {
            Logger.cursiveLetter.fault("Failed to create CGPath for character \(character): \(error)")
            return nil
        }
    }

    /**
     * Parses typography metrics from SVG custom attributes or estimates them from viewBox.
     *
     * This method attempts to extract font metrics in the following priority order:
     * 1. Custom data attributes (data-advance, data-ascent, etc.) - preferred method
     * 2. SVG viewBox dimensions with estimated proportions - fallback method
     *
     * The custom attributes are expected to be embedded in the SVG by font generation tools
     * and provide accurate typography information for proper text layout.
     *
     * - Parameter svgString: The complete SVG file content as a string
     * - Returns: A tuple of typography metrics, or nil if parsing fails
     */
    private static func parseMetrics(from svgString: String) -> (
        advance: CGFloat,
        ascent: CGFloat,
        descent: CGFloat,
        verticalExtent: CGFloat,
        unitsPerEm: CGFloat
    )? {
        // Helper function to extract a named attribute value using regex
        func attr(_ name: String) -> CGFloat? {
            let pattern = name + #"\=\"([^\"]+)\""#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            guard let match = regex.firstMatch(in: svgString, options: [], range: NSRange(location: 0, length: svgString.count)) else { return nil }
            guard let range = Range(match.range(at: 1), in: svgString) else { return nil }
            return CGFloat(Double(svgString[range]) ?? .nan)
        }

        // Try to parse custom font metrics attributes first (most accurate)
        let advance = attr("data-advance")
        let ascent = attr("data-ascent")
        let descent = attr("data-descent")
        let vertical = attr("data-vertical-extent")
        let upm = attr("data-units-per-em")

        // If all custom attributes are present, use them
        if let a = advance, let asc = ascent, let desc = descent, let v = vertical, let u = upm {
            return (advance: a, ascent: asc, descent: desc, verticalExtent: v, unitsPerEm: u)
        }

        // Fallback: parse viewBox="0 0 width height" and estimate metrics
        // This provides basic dimensions when custom attributes are missing
        if let viewBoxMatch = try? NSRegularExpression(pattern: #"viewBox\=\"0\s+0\s+([0-9\.\-]+)\s+([0-9\.\-]+)\""#, options: []) {
            if let m = viewBoxMatch.firstMatch(in: svgString, options: [], range: NSRange(location: 0, length: svgString.count)),
               let wRange = Range(m.range(at: 1), in: svgString),
               let hRange = Range(m.range(at: 2), in: svgString) {
                let width = CGFloat(Double(svgString[wRange]) ?? 0)
                let height = CGFloat(Double(svgString[hRange]) ?? 0)
                // Use explicit width attribute if available, otherwise use viewBox width
                let adv = attr("width") ?? width
                // Estimate typical typography proportions
                let asc = height * 0.8
                let desc = asc - height
                return (advance: adv, ascent: asc, descent: desc, verticalExtent: height, unitsPerEm: height)
            }
        }

        return nil
    }
    
    /**
     * Extracts the vector path data from an SVG string using multiple regex patterns.
     *
     * This method tries progressively more permissive regex patterns to find the 'd' attribute
     * of a path element, which contains the actual vector drawing commands. The patterns are
     * ordered from most specific to most general to handle various SVG formatting styles.
     *
     * - Parameter svgString: The complete SVG file content as a string
     * - Returns: The path data string (SVG path commands), or nil if extraction fails
     */
    private static func extractPathData(from svgString: String) -> String? {
        // Try multiple regex patterns to handle different SVG formatting styles
        // Ordered from most specific to most general for better matching accuracy
        let patterns = [
            #"<path\s+[^>]*d="([^"]*)"[^>]*>"#,  // Path with whitespace and other attributes
            #"<path[^>]*d="([^"]*)"[^>]*>"#,     // Path with any attributes
            #"d="([^"]*)"#                       // Just the d attribute (most permissive)
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: svgString, options: [], range: NSRange(location: 0, length: svgString.count)),
               let range = Range(match.range(at: 1), in: svgString) {
                let pathData = String(svgString[range])
                Logger.cursiveLetter.debug("Extracted path data: \(pathData.prefix(50))...")
                return pathData
            }
        }

        Logger.cursiveLetter.fault("Failed to extract path data from SVG")
        return nil
    }

    /**
     * Retrieves a CursiveLetter instance for the given character.
     *
     * This method performs a two-stage lookup:
     * 1. Exact case-sensitive match (preferred for performance and accuracy)
     * 2. Case-insensitive fallback (handles mixed-case input gracefully)
     *
     * - Parameter character: The character to look up
     * - Returns: A CursiveLetter instance, or nil if the character is not supported
     */
    static func letter(for character: String) -> CursiveLetter? {
        // Prefer exact-case match if available (faster and more precise)
        if let exact = allLetters.first(where: { $0.character == character }) {
            return exact
        }
        // Fallback to case-insensitive match for user convenience
        return allLetters.first { $0.character.caseInsensitiveCompare(character) == .orderedSame }
    }
}

/**
 * SwiftUI Shape that renders a single cursive letter, automatically scaled and centered to fit the available space.
 *
 * This shape takes a CursiveLetter and transforms its vector path to fit within the provided rectangle
 * while maintaining aspect ratio. The letter is centered both horizontally and vertically within the bounds.
 *
 * The transformation pipeline:
 * 1. Translate path to origin (remove any offset from original coordinates)
 * 2. Scale uniformly to fit the rectangle (preserving aspect ratio)
 * 3. Center the scaled letter within the rectangle
 */
struct CursiveLetterShape: Shape {
    let letter: CursiveLetter

    func path(in rect: CGRect) -> Path {
        // Step 1: Translate so minX/minY is at the origin
        // This normalizes the path coordinates to start from (0,0)
        var t = CGAffineTransform(translationX: -letter.path.boundingBox.minX, y: -letter.path.boundingBox.minY)
        guard let originPath = letter.path.copy(using: &t) else { return Path(letter.path) }

        // Step 2: Compute uniform scale to fit within the rectangle
        // Use the smaller scale factor to ensure the entire letter fits
        let originBox = originPath.boundingBox
        let scaleX = rect.width / originBox.width
        let scaleY = rect.height / originBox.height
        let scale = min(scaleX, scaleY) // Preserve aspect ratio
        var s = CGAffineTransform(scaleX: scale, y: scale)
        guard let scaledPath = originPath.copy(using: &s) else { return Path(originPath) }

        // Step 3: Center the scaled letter within the provided rectangle
        let scaledSize = CGSize(width: originBox.width * scale, height: originBox.height * scale)
        let offsetX = (rect.width - scaledSize.width) / 2
        let offsetY = (rect.height - scaledSize.height) / 2
        var centerT = CGAffineTransform(translationX: offsetX, y: offsetY)
        guard let centeredPath = scaledPath.copy(using: &centerT) else { return Path(scaledPath) }

        return Path(centeredPath)
    }
}

/**
 * SwiftUI Shape that renders complete words or phrases in cursive handwriting style.
 *
 * This shape combines multiple CursiveLetter instances into a single path, handling proper
 * character spacing, baseline alignment, and scaling to fit the available space. It's designed
 * for rendering animated cursive text in the typing indicator system.
 *
 * The rendering pipeline:
 * 1. Layout individual letters with proper advance spacing
 * 2. Combine all letter paths into a single path
 * 3. Scale to fit the rectangle while respecting font size constraints
 * 4. Position with proper baseline alignment and centering
 * 5. Clamp to rectangle bounds to prevent overflow
 */
struct CursiveWordShape: Shape {
    let text: String
    let fontSize: CGFloat

    init(text: String, fontSize: CGFloat = 17) {
        self.text = text
        self.fontSize = fontSize
    }

    func path(in rect: CGRect) -> Path {
        guard let layout = Self.layout(for: text, fontSize: fontSize) else {
            return Path()
        }

        // Step 1: Combine all letter paths with proper horizontal spacing
        let combined = CGMutablePath()
        var penX: CGFloat = 0 // Current horizontal position (like a pen moving across paper)
        for letter in layout.letters {
            let transform = CGAffineTransform(translationX: penX, y: 0)
            combined.addPath(letter.path, transform: transform)
            penX += letter.advance // Move pen forward by the letter's advance width
        }

        // Step 2: Calculate scaling to fit the rectangle
        // Consider both the layout's base scale (from fontSize) and the rectangle constraints
        let fitScaleX = rect.width / max(layout.totalAdvance, 1)
        let fitScaleY = rect.height / max(layout.verticalExtent, 1)
        let scale = min(layout.baseScale, fitScaleX, fitScaleY)

        var scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        guard let scaled = combined.copy(using: &scaleTransform) else { return Path(combined) }

        // Step 3: Center horizontally within the rectangle
        let scaledWidth = layout.totalAdvance * scale
        let offsetX = (rect.width - scaledWidth) / 2

        // Step 4: Position vertically with proper baseline alignment
        // Place the baseline at the vertical center of the rectangle
        let baselineInRect = rect.midY
        let offsetY = baselineInRect - layout.ascent * scale

        var translate = CGAffineTransform(translationX: offsetX, y: offsetY)
        guard let baselinePositioned = scaled.copy(using: &translate) else { return Path(scaled) }

        // Step 5: Clamp to rectangle bounds to prevent overflow
        var positioned = baselinePositioned
        let bounds = positioned.boundingBox
        var dy: CGFloat = 0

        // Adjust if text extends above the rectangle
        if bounds.minY < rect.minY {
            dy += rect.minY - bounds.minY
        }

        // Adjust if text extends below the rectangle
        if bounds.maxY > rect.maxY {
            dy += rect.maxY - bounds.maxY
        }

        // Apply vertical clamping adjustment if needed
        if dy != 0 {
            var clamp = CGAffineTransform(translationX: 0, y: dy)
            if let adjusted = positioned.copy(using: &clamp) {
                positioned = adjusted
            }
        }

        return Path(positioned)
    }

    /**
     * Calculates the preferred size for rendering the given text at the specified font size.
     *
     * This method computes the natural dimensions the text would occupy when rendered
     * at the given font size, useful for layout calculations and container sizing.
     *
     * - Parameters:
     *   - text: The text to measure
     *   - fontSize: The desired font size in points
     * - Returns: The preferred size, or nil if the text contains no renderable characters
     */
    static func preferredSize(for text: String, fontSize: CGFloat) -> CGSize? {
        guard let layout = layout(for: text, fontSize: fontSize) else { return nil }
        let width = layout.totalAdvance * layout.baseScale
        let height = layout.verticalExtent * layout.baseScale
        return CGSize(width: width, height: height)
    }

    /**
     * Internal layout data structure containing all information needed to render text.
     *
     * This struct encapsulates the results of text layout calculations, including
     * the individual letters, spacing metrics, and scaling factors.
     */
    private struct Layout {
        let letters: [CursiveLetter]      // Individual letter instances
        let totalAdvance: CGFloat         // Total horizontal space needed
        let ascent: CGFloat               // Distance from baseline to top
        let verticalExtent: CGFloat       // Total vertical space needed
        let baseScale: CGFloat            // Scale factor from font units to points
    }

    /**
     * Performs text layout calculations for the given string and font size.
     *
     * This method handles the complex process of:
     * 1. Converting characters to CursiveLetter instances
     * 2. Calculating total advance width (horizontal spacing)
     * 3. Determining vertical metrics (ascent, descent, extent)
     * 4. Computing scale factor from font units to the desired point size
     *
     * - Parameters:
     *   - text: The text to lay out
     *   - fontSize: The desired font size in points
     * - Returns: A Layout instance with all calculated metrics, or nil if no letters found
     */
    private static func layout(for text: String, fontSize: CGFloat) -> Layout? {
        var letters: [CursiveLetter] = []
        var totalAdvance: CGFloat = 0

        // Convert each character to a CursiveLetter and accumulate advance widths
        for ch in text {
            let s = String(ch)
            if let letter = CursiveLetter.letter(for: s) {
                letters.append(letter)
                totalAdvance += letter.advance
            }
        }
        guard !letters.isEmpty else { return nil }

        // Calculate vertical metrics by taking the maximum/minimum across all letters
        let ascent = letters.map(\.ascent).max() ?? 0
        let descent = letters.map(\.descent).min() ?? 0 // Usually negative
        var verticalExtent = letters.map(\.verticalExtent).max() ?? 0
        // Ensure vertical extent is at least the ascent-descent difference
        verticalExtent = max(verticalExtent, ascent - descent, 1)

        // Calculate scale factor to convert from font units to the desired point size
        let unitsPerEm = letters.first(where: { $0.unitsPerEm > 0 })?.unitsPerEm ?? verticalExtent
        let denominator = max(unitsPerEm, 1) // Prevent division by zero
        let baseScale = fontSize / denominator

        return Layout(
            letters: letters,
            totalAdvance: totalAdvance,
            ascent: ascent,
            verticalExtent: verticalExtent,
            baseScale: baseScale
        )
    }
}

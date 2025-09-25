//
//  CursiveTestView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/24/25.
//

import SwiftUI
import SVGPath
import os.log

struct CursiveTestView: View {
    @State private var debugInfo: String = "Loading..."
    @State private var helloLetters: [CGPath] = []
    
    private let logger = Logger(subsystem: "app.amorfati.Rio", category: "CursiveLetters")

    var body: some View {
        VStack {
            Text("Cursive hello")
                .font(.title)
                .padding()

            Text(debugInfo)
                .padding()
                .foregroundColor(.blue)
                .multilineTextAlignment(.leading)
                .font(.caption)

            ZStack {
                Rectangle().fill(Color.gray.opacity(0.08))
                CursiveWordShape(text: "Hello")
                    .fill(Color.blue.opacity(0.25))
                CursiveWordShape(text: "Hello")
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(width: 400, height: 120)
            .border(Color.red.opacity(0.4))
            .padding()

            Spacer()
        }
        .onAppear {
            loadHelloLetters()
        }
    }

    private func loadHelloLetters() {
        let letters = ["H", "e", "l", "l", "o"]
        var loadedPaths: [CGPath] = []
        var debugMessages: [String] = []
        var allBounds: [CGRect] = []

        // First pass: load all paths and collect their bounds
        for letter in letters {
            do {
                if let path = try loadRawLetter(letter) {
                    loadedPaths.append(path)
                    allBounds.append(path.boundingBox)
                    debugMessages.append("✅ \(letter)")
                } else {
                    debugMessages.append("❌ \(letter)")
                }
            } catch {
                debugMessages.append("❌ \(letter) (\(error.localizedDescription))")
            }
        }

        // Normalize, scale, and center each path into a fixed frame
        var scaledPaths: [CGPath] = []
        for (index, path) in loadedPaths.enumerated() {
            let bounds = allBounds[index]

            // Target size
            let targetWidth: CGFloat = 60
            let targetHeight: CGFloat = 80
            let scaleX = targetWidth / bounds.width
            let scaleY = targetHeight / bounds.height
            let scale = min(scaleX, scaleY)

            // Flip vertically about glyph maxY, then compose: center -> scale -> translate-to-origin
            var transform = CGAffineTransform.identity
            let scaledWidth = bounds.width * scale
            let scaledHeight = bounds.height * scale
            let centerOffsetX = (80 - scaledWidth) / 2
            let centerOffsetY = (100 - scaledHeight) / 2
            // Flip in local glyph coordinates
            transform = transform.translatedBy(x: 0, y: bounds.maxY)
            transform = transform.scaledBy(x: 1, y: -1)
            transform = transform.translatedBy(x: 0, y: -bounds.maxY)
            // Then layout
            transform = transform.translatedBy(x: centerOffsetX, y: centerOffsetY)
            transform = transform.scaledBy(x: scale, y: scale)
            transform = transform.translatedBy(x: -bounds.minX, y: -bounds.minY)

            if let scaledPath = path.copy(using: &transform) {
                let finalBounds = scaledPath.boundingBox
                let scaledWidth = bounds.width * scale
                let scaledHeight = bounds.height * scale
                
                logger.info("📐 Letter \(index): scale=\(scale, privacy: .public)")
                logger.info("   Original bounds=\(bounds.debugDescription, privacy: .public)")
                logger.info("   Final bounds=\(finalBounds.debugDescription, privacy: .public)")
                logger.info("   Final size=\(scaledWidth, privacy: .public)×\(scaledHeight, privacy: .public)")
                
                // Also print to console for easier debugging
                print("Letter \(letters[index]): orig=\(bounds) final=\(finalBounds) center=(40,50)")
                
                scaledPaths.append(scaledPath)
            }
        }

        self.helloLetters = scaledPaths
        self.debugInfo = "Loaded: \(debugMessages.joined(separator: " ")) | Individual scaling"
    }

    private func loadRawLetter(_ letter: String) throws -> CGPath? {
        logger.info("🔍 Loading letter: \(letter, privacy: .public)")

        // Handle uppercase letters with Capital- prefix
        let resourceName = letter.first?.isUppercase == true ? "Capital-\(letter)" : letter

        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "svg") else {
            logger.error("❌ SVG file not found: \(resourceName, privacy: .public).svg")
            return nil
        }
        logger.info("✅ Found SVG file: \(url.lastPathComponent, privacy: .public)")

        guard let svgData = try? Data(contentsOf: url) else {
            logger.error("❌ Failed to read SVG data")
            return nil
        }
        logger.info("✅ Read SVG data: \(svgData.count, privacy: .public) bytes")

        guard let svgString = String(data: svgData, encoding: .utf8) else {
            logger.error("❌ Failed to decode SVG string")
            return nil
        }
        logger.info("✅ Decoded SVG string: \(svgString.count, privacy: .public) characters")

        // Extract path data
        let pattern = #"d="([^"]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            logger.error("❌ Failed to create regex")
            return nil
        }

        guard let match = regex.firstMatch(in: svgString, options: [], range: NSRange(location: 0, length: svgString.count)) else {
            logger.error("❌ No path data found in SVG")
            logger.error("SVG content: \(svgString, privacy: .public)")
            return nil
        }

        guard let range = Range(match.range(at: 1), in: svgString) else {
            logger.error("❌ Failed to extract path range")
            return nil
        }

        let pathData = String(svgString[range])
        logger.info("✅ Extracted path data: \(String(pathData.prefix(100)), privacy: .public)...")

        // Create SVGPath and convert to CGPath (no scaling here)
        do {
            let svgPath = try SVGPath(string: pathData)
            logger.info("✅ Created SVGPath")

            let cgPath = CGPath.from(svgPath: svgPath)
            logger.info("✅ Converted to CGPath")

            let bounds = cgPath.boundingBox
            logger.info("✅ Path bounds: \(bounds.debugDescription, privacy: .public)")

            logger.info("✅ Successfully loaded raw letter \(letter, privacy: .public)")
            return cgPath
        } catch {
            logger.error("❌ SVGPath error: \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }
}

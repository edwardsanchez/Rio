//
//  CursiveTestView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/24/25.
//

import SwiftUI
import SVGPath

struct CursiveTestView: View {
    @State private var debugInfo: String = "Loading..."
    @State private var helloLetters: [CGPath] = []

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

            if !helloLetters.isEmpty {
                HStack(spacing: 10) {
                    ForEach(Array(helloLetters.enumerated()), id: \.offset) { index, path in
                        Path(path)
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            .frame(width: 60, height: 80)
                            .animation(.easeInOut(duration: 0.5).delay(Double(index) * 0.2), value: helloLetters.count)
                    }
                }
                .padding()
            } else {
                Text("Loading letters...")
                    .foregroundColor(.gray)
                    .padding()
            }

            Spacer()
        }
        .onAppear {
            loadHelloLetters()
        }
    }

    private func loadHelloLetters() {
        let letters = ["H", "E", "L", "L", "O"]
        var loadedPaths: [CGPath] = []
        var debugMessages: [String] = []

        for letter in letters {
            do {
                if let path = try loadLetterWithDebug(letter) {
                    loadedPaths.append(path)
                    debugMessages.append("✅ \(letter)")
                } else {
                    debugMessages.append("❌ \(letter)")
                }
            } catch {
                debugMessages.append("❌ \(letter) (\(error.localizedDescription))")
            }
        }

        self.helloLetters = loadedPaths
        self.debugInfo = "Loaded: \(debugMessages.joined(separator: " "))"
    }

    private func loadLetterWithDebug(_ letter: String) throws -> CGPath? {
        print("🔍 Loading letter: \(letter)")

        guard let url = Bundle.main.url(forResource: letter, withExtension: "svg") else {
            print("❌ SVG file not found: \(letter).svg")
            return nil
        }
        print("✅ Found SVG file: \(url.lastPathComponent)")

        guard let svgData = try? Data(contentsOf: url) else {
            print("❌ Failed to read SVG data")
            return nil
        }
        print("✅ Read SVG data: \(svgData.count) bytes")

        guard let svgString = String(data: svgData, encoding: .utf8) else {
            print("❌ Failed to decode SVG string")
            return nil
        }
        print("✅ Decoded SVG string: \(svgString.count) characters")

        // Extract path data
        let pattern = #"d="([^"]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            print("❌ Failed to create regex")
            return nil
        }

        guard let match = regex.firstMatch(in: svgString, options: [], range: NSRange(location: 0, length: svgString.count)) else {
            print("❌ No path data found in SVG")
            print("SVG content: \(svgString)")
            return nil
        }

        guard let range = Range(match.range(at: 1), in: svgString) else {
            print("❌ Failed to extract path range")
            return nil
        }

        let pathData = String(svgString[range])
        print("✅ Extracted path data: \(pathData.prefix(100))...")

        // Create SVGPath and convert to CGPath
        do {
            let svgPath = try SVGPath(string: pathData)
            print("✅ Created SVGPath")

            let cgPath = CGPath.from(svgPath: svgPath)
            print("✅ Converted to CGPath")

            let bounds = cgPath.boundingBox
            print("✅ Path bounds: \(bounds)")

            // Scale the path to fit our letter frame (60x80)
            let targetHeight: CGFloat = 80
            let scale = targetHeight / bounds.height
            var transform = CGAffineTransform(scaleX: scale, y: scale)
            transform = transform.translatedBy(x: -bounds.minX, y: -bounds.minY)

            guard let scaledPath = cgPath.copy(using: &transform) else {
                print("❌ Failed to scale path")
                return nil
            }

            print("✅ Successfully loaded and scaled letter \(letter)")
            return scaledPath
        } catch {
            print("❌ SVGPath error: \(error)")
            throw error
        }
    }
}

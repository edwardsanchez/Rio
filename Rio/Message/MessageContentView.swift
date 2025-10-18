//
//  MessageContentView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/18/25.
//

import SwiftUI

/// A view that renders different types of message content based on the ContentType enum
struct MessageContentView: View {
    let content: ContentType
    let textColor: Color
    
    var body: some View {
        switch content {
        case .text(let text):
            Text(text)
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
            
        case .color(let rgb):
            // Placeholder for color content
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(
                        red: Double(rgb.red) / 255.0,
                        green: Double(rgb.green) / 255.0,
                        blue: Double(rgb.blue) / 255.0
                    ))
                    .frame(width: 100, height: 100)
                Text("RGB(\(rgb.red), \(rgb.green), \(rgb.blue))")
                    .font(.caption)
                    .foregroundStyle(textColor)
            }
            
        case .image(let image):
            // Placeholder for image content
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 200)
            
        case .video(let url):
            // Placeholder for video content
            VStack(spacing: 4) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(textColor.opacity(0.6))
                Text("Video: \(url.lastPathComponent)")
                    .font(.caption)
                    .foregroundStyle(textColor)
            }
            .padding()
            
        case .audio(let url):
            // Placeholder for audio content
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .font(.system(size: 24))
                Text("Audio: \(url.lastPathComponent)")
                    .font(.caption)
            }
            .foregroundStyle(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
        case .date(let date):
            // Placeholder for date content
            VStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 30))
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
            }
            .foregroundStyle(textColor)
            .padding()
            
        case .dateRange(let range):
            // Placeholder for date range content
            VStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 30))
                HStack {
                    Text(range.start.formatted(date: .abbreviated, time: .omitted))
                    Image(systemName: "arrow.right")
                    Text(range.end.formatted(date: .abbreviated, time: .omitted))
                }
                .font(.caption)
            }
            .foregroundStyle(textColor)
            .padding()
            
        case .location:
            // Placeholder for location content
            VStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.system(size: 30))
                Text("Location")
                    .font(.caption)
            }
            .foregroundStyle(textColor)
            .padding()
            
        case .url(let url):
            // Placeholder for URL content
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "link")
                    .font(.system(size: 20))
                Text(url.absoluteString)
                    .font(.caption)
                    .lineLimit(2)
            }
            .foregroundStyle(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
        case .multiChoice(let multiChoice):
            // Placeholder for multi-choice content
            VStack(spacing: 8) {
                multiChoice.image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 150)
                Text("Multi-choice")
                    .font(.caption)
                    .foregroundStyle(textColor)
            }
            
        case .emoji(let emoji):
            // Emoji content - larger text
            Text(emoji)
                .font(.system(size: 60))
                .padding()
            
        case .code(let code):
            // Placeholder for code content
            Text(code)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(8)
        }
    }
}

#Preview("All Content Types") {
    ScrollView {
        VStack(alignment: .leading, spacing: 24) {
            // Text
            VStack(alignment: .leading, spacing: 8) {
                Text("Text").font(.headline)
                MessageContentView(content: .text("Hello, World! This is a text message."), textColor: .primary)
                    .padding()
            }
            
            // Text (Multi-line)
            VStack(alignment: .leading, spacing: 8) {
                Text("Text (Multi-line)").font(.headline)
                MessageContentView(content: .text("This is a longer message that demonstrates text wrapping behavior. It contains multiple lines of text to show how the content view handles longer messages."), textColor: .primary)
                    .padding()
            }
            
            // Color
            VStack(alignment: .leading, spacing: 8) {
                Text("Color").font(.headline)
                MessageContentView(content: .color(RGB(red: 255, green: 100, blue: 50)), textColor: .primary)
                    .padding()
            }
            
            // Image
            VStack(alignment: .leading, spacing: 8) {
                Text("Image").font(.headline)
                MessageContentView(content: .image(Image(systemName: "photo")), textColor: .primary)
                    .padding()
            }
            
            // Video
            VStack(alignment: .leading, spacing: 8) {
                Text("Video").font(.headline)
                MessageContentView(content: .video(URL(string: "https://example.com/video.mp4")!), textColor: .primary)
                    .padding()
            }
            
            // Audio
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio").font(.headline)
                MessageContentView(content: .audio(URL(string: "https://example.com/audio.mp3")!), textColor: .primary)
                    .padding()
            }
            
            // Date
            VStack(alignment: .leading, spacing: 8) {
                Text("Date").font(.headline)
                MessageContentView(content: .date(Date.now), textColor: .primary)
                    .padding()
            }
            
            // Date Range
            VStack(alignment: .leading, spacing: 8) {
                Text("Date Range").font(.headline)
                MessageContentView(
                    content: .dateRange(
                        DateRange(
                            start: Date.now,
                            end: Date.now.addingTimeInterval(86400 * 7)
                        )
                    ),
                    textColor: .primary
                )
                .padding()
            }
            
            // Location
            VStack(alignment: .leading, spacing: 8) {
                Text("Location").font(.headline)
                MessageContentView(content: .location, textColor: .primary)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }
            
            // URL
            VStack(alignment: .leading, spacing: 8) {
                Text("URL").font(.headline)
                MessageContentView(content: .url(URL(string: "https://www.apple.com/swift")!), textColor: .primary)
                    .padding()
            }
            
            // Multi-choice
            VStack(alignment: .leading, spacing: 8) {
                Text("Multi-choice").font(.headline)
                MessageContentView(
                    content: .multiChoice(MultiChoice(image: Image(systemName: "questionmark.circle"))),
                    textColor: .primary
                )
                .padding()
            }
            
            // Emoji
            VStack(alignment: .leading, spacing: 8) {
                Text("Emoji").font(.headline)
                MessageContentView(content: .emoji("👋🎉🚀"), textColor: .primary)
                    .padding()
            }
            
            // Code
            VStack(alignment: .leading, spacing: 8) {
                Text("Code").font(.headline)
                MessageContentView(
                    content: .code("func hello() {\n    print(\"Hello, World!\")\n    return true\n}"),
                    textColor: .primary
                )
                .padding()
            }
        }
        .padding()
    }
}


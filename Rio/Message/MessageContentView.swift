//
//  MessageContentView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/18/25.
//

import SwiftUI
import MapKit
import AVKit

/// A view that renders different types of message content based on the ContentType enum
struct MessageContentView: View {
    let content: ContentType
    let textColor: Color
    
    @State private var contentWidth = CGFloat.zero
    @State private var showingVideoFullScreen = false
    @State private var showingAudioFullScreen = false
    
    let insetCornerRadius: CGFloat = 10
    
    var body: some View {
        switch content {
        case .text(let text):
            Text(text)
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
            
        case .color(let rgb):
            // Placeholder for color content
            Text("Color Description")
                .font(.caption)
                .foregroundStyle(textColor)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: insetCornerRadius)
                        .fill(Color(
                            red: Double(rgb.red) / 255.0,
                            green: Double(rgb.green) / 255.0,
                            blue: Double(rgb.blue) / 255.0
                        ))
                        .stroke(textColor.opacity(0.5), lineWidth: 2)
                }
            
        case .image(let image):
            // Placeholder for image content
            image
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: insetCornerRadius))
            
        case .video(let url):
            VideoPlayer(player: AVPlayer(url: url))
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: insetCornerRadius))
            
        case .audio(let url):
            VideoPlayer(player: AVPlayer(url: url))
                .aspectRatio(16/9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: insetCornerRadius))
            
        case .date(let date, let granularity):
            switch granularity {
            case .dateAndTime:
                Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    .foregroundStyle(textColor)
                    .font(.caption.bold())
            case .dateOnly:
                Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .foregroundStyle(textColor)
                    .font(.caption.bold())
            case .timeOnly:
                Label(date.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                    .foregroundStyle(textColor)
                    .font(.caption.bold())
            }

        case .dateRange(let range, let granularity):
            switch granularity {
            case .dateAndTime:
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                    HStack(spacing: 4) {
                        Text(range.start.formatted(date: .abbreviated, time: .shortened))
                        Image(systemName: "arrow.right")
                        Text(range.end.formatted(date: .abbreviated, time: .shortened))
                    }
                }
                .font(.caption.bold())
                .foregroundStyle(textColor)
            case .dateOnly:
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                    HStack(spacing: 4) {
                        Text(range.start.formatted(date: .abbreviated, time: .omitted))
                        Image(systemName: "arrow.right")
                        Text(range.end.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                .font(.caption.bold())
                .foregroundStyle(textColor)
            case .timeOnly:
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                    HStack(spacing: 4) {
                        Text(range.start.formatted(date: .omitted, time: .shortened))
                        Image(systemName: "arrow.right")
                        Text(range.end.formatted(date: .omitted, time: .shortened))
                    }
                }
                .font(.caption.bold())
                .foregroundStyle(textColor)
            }
            
        case .location(let mapItem):
            // Interactive map view that opens in Apple Maps when tapped
            Button {
                mapItem.openInMaps()
            } label: {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: mapItem.location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))) {
                    Marker(mapItem.name ?? "Location", coordinate: mapItem.location.coordinate)
                }
                .aspectRatio(CGSize(width: 1, height: 1), contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: insetCornerRadius))
                .allowsHitTesting(false)
            }
            .buttonStyle(.plain)
            
        case .url(let url):
            URLPreviewCard(url: url, textColor: textColor)
            
        case .singleChoice(let choice):
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                    .foregroundStyle(textColor)
                Text(choice.value.isEmpty ? "Single Choice" : choice.value)
                    .font(.caption)
                    .foregroundStyle(textColor)
            }
            
        case .multiChoice(let choices):
            // Placeholder for multi-choice content
            VStack(spacing: 8) {
                Image(systemName: "checklist")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                    .foregroundStyle(textColor)
                if let firstChoice = choices.first, !firstChoice.value.isEmpty {
                    Text(firstChoice.value)
                        .font(.caption)
                        .foregroundStyle(textColor)
                } else {
                    Text("Multi Choice")
                        .font(.caption)
                        .foregroundStyle(textColor)
                }
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
                .background(Color.primary.opacity(0.15))
                .cornerRadius(12)
            
        case .bool(let value):
            Label(value ? "YES" : "NO", systemImage: value ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                .foregroundStyle(textColor)
                .font(.caption.bold())
            
        case .rating(let rating):
            HStack(spacing: 2) {
                ForEach(0..<(rating.rawValue + 1), id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }
            .font(.title3)
            
        case .value(let measurement):
            Label(formatMeasurementValue(measurement), systemImage: measurementSymbol(for: measurement.type))
                .foregroundStyle(textColor)
                .font(.title3.bold())
            
        case .valueRange(let range):
            HStack(spacing: 8) {
                Image(systemName: measurementSymbol(for: range.lowerBound.type))
                HStack(spacing: 4) {
                    Text(formatMeasurementValue(range.lowerBound))
                    Image(systemName: "arrow.right")
                    Text(formatMeasurementValue(range.upperBound))
                }
            }
            .font(.caption.bold())
            .foregroundStyle(textColor)
            
        case .file(let url):
            Label(url.lastPathComponent, systemImage: "doc.fill")
                .foregroundStyle(textColor)
                .font(.caption.bold())
            
        case .dateFrequency(let frequency):
            let dayName = Calendar.current.weekdaySymbols[frequency.dayOfWeek.rawValue]
            let prefix = frequency.interval == 1 ? "Every" : "Every \(frequency.interval)"
            Label("\(prefix) \(dayName)", systemImage: "calendar")
                .foregroundStyle(textColor)
                .font(.caption.bold())
        }
    }
    
    // MARK: - Helper Functions
    
    private func measurementSymbol(for type: ValueType) -> String {
        switch type {
        case .length(_): return "ruler.fill"
        case .percentage(_): return "percent"
        case .currency(_): return "dollarsign.circle.fill"
        case .mass(_): return "scalemass.fill"
        case .volume(_): return "flask.fill"
        case .temperature(_): return "thermometer.medium"
        case .duration(_): return "clock.fill"
        case .speed(_): return "speedometer.fill"
        case .area(_): return "square.fill"
        case .energy(_): return "bolt.fill"
        case .number(_): return "number"
        }
    }
    
    private func formatMeasurementValue(_ measurement: Measurement) -> String {
        switch measurement.type {
        case .length(_): return String(format: "%.2f", measurement.value)
        case .percentage(_): return String(format: "%.1f%%", measurement.value)
        case .currency(_): return String(format: "$%.2f", measurement.value)
        case .mass(_): return String(format: "%.2f", measurement.value)
        case .volume(_): return String(format: "%.2f", measurement.value)
        case .temperature(_): return String(format: "%.1f°", measurement.value)
        case .duration(_): return String(format: "%.0f", measurement.value)
        case .speed(_): return String(format: "%.1f", measurement.value)
        case .area(_): return String(format: "%.2f", measurement.value)
        case .energy(_): return String(format: "%.2f", measurement.value)
        case .number(_): return String(format: "%.2f", measurement.value)
        }
    }
}

#Preview("All Content Types") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    
    let sampleUser = User(id: UUID(), name: "Edward", avatar: .edward)
    
    ScrollView {
        VStack(alignment: .trailing, spacing: 24) {
            // Text
            VStack(alignment: .leading, spacing: 8) {
                Text("Text").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .text("Hello, World! This is a text message."),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            
            // Text (Multi-line)
            VStack(alignment: .leading, spacing: 8) {
                Text("Text (Multi-line)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .text("This is a longer message that demonstrates text wrapping behavior. It contains multiple lines of text to show how the content view handles longer messages."),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // URL
            VStack(alignment: .leading, spacing: 8) {
                Text("URL (with metadata)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .url(URL(string: "https://www.apple.com")!),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // URL - Alternative
            VStack(alignment: .leading, spacing: 8) {
                Text("URL (Unresolved)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .url(URL(string: "https://somefakeURL.com")!),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Color
            VStack(alignment: .leading, spacing: 8) {
                Text("Color").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .color(RGB(red: 255, green: 100, blue: 50)),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Image
            VStack(alignment: .leading, spacing: 8) {
                MessageBubbleView(
                    message: Message(
                        content: .image(Image(.cat)),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Video
            VStack(alignment: .leading, spacing: 8) {
                Text("Video").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .video(URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4")!),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Audio
            VStack(alignment: .leading, spacing: 8) {
                Text("Audio").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .audio(URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3")!),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Date - Date and Time
            VStack(alignment: .leading, spacing: 8) {
                Text("Date (Date & Time)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .date(Date.now, granularity: .dateAndTime),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Date - Date Only
            VStack(alignment: .leading, spacing: 8) {
                Text("Date (Date Only)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .date(Date.now, granularity: .dateOnly),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Date - Time Only
            VStack(alignment: .leading, spacing: 8) {
                Text("Date (Time Only)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .date(Date.now, granularity: .timeOnly),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Date Range - Date and Time
            VStack(alignment: .leading, spacing: 8) {
                Text("Date Range (Date & Time)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .dateRange(
                            DateRange(
                                start: Date.now,
                                end: Date.now.addingTimeInterval(86400 * 3 + 3600 * 2)
                            ),
                            granularity: .dateAndTime
                        ),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Date Range - Date Only
            VStack(alignment: .leading, spacing: 8) {
                Text("Date Range (Date Only)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .dateRange(
                            DateRange(
                                start: Date.now,
                                end: Date.now.addingTimeInterval(86400 * 7)
                            ),
                            granularity: .dateOnly
                        ),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Date Range - Time Only
            VStack(alignment: .leading, spacing: 8) {
                Text("Date Range (Time Only)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .dateRange(
                            DateRange(
                                start: Date.now,
                                end: Date.now.addingTimeInterval(3600 * 2)
                            ),
                            granularity: .timeOnly
                        ),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Location
            VStack(alignment: .leading, spacing: 8) {
                Text("Location").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .location({
                            let coordinate = CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090)
                            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                            let mapItem = MKMapItem(location: location, address: nil)
                            mapItem.name = "Apple Park"
                            return mapItem
                        }()),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            
            // Single Choice
            VStack(alignment: .leading, spacing: 8) {
                Text("Single Choice").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .singleChoice(Choice(value: "Option A")),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Multi-choice
            VStack(alignment: .leading, spacing: 8) {
                Text("Multi-choice").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .multiChoice([Choice(value: "Option A"), Choice(value: "Option B")]),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Emoji
            VStack(alignment: .leading, spacing: 8) {
                Text("Emoji").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .emoji("👋🎉🚀"),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Code
            VStack(alignment: .leading, spacing: 8) {
                Text("Code").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .code("func hello() {\n    print(\"Hello, World!\")\n    return true\n}"),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Boolean - True
            VStack(alignment: .leading, spacing: 8) {
                Text("Boolean (True)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .bool(true),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Boolean - False
            VStack(alignment: .leading, spacing: 8) {
                Text("Boolean (False)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .bool(false),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Rating - Five Stars
            VStack(alignment: .leading, spacing: 8) {
                Text("Rating (5 Stars)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .rating(.five),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Rating - Three Stars
            VStack(alignment: .leading, spacing: 8) {
                Text("Rating (3 Stars)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .rating(.three),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value - Length
            VStack(alignment: .leading, spacing: 8) {
                Text("Value (Length)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .value(Measurement(value: 42.5, type: .length(.meters))),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value - Percentage
            VStack(alignment: .leading, spacing: 8) {
                Text("Value (Percentage)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .value(Measurement(value: 75.5, type: .percentage(75.5))),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value - Currency
            VStack(alignment: .leading, spacing: 8) {
                Text("Value (Currency)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .value(Measurement(value: 99.99, type: .currency(99.99))),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value - Mass
            VStack(alignment: .leading, spacing: 8) {
                Text("Value (Mass)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .value(Measurement(value: 150.0, type: .mass(.kilograms))),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value - Volume
            VStack(alignment: .leading, spacing: 8) {
                Text("Value (Volume)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .value(Measurement(value: 500.0, type: .volume(.milliliters))),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value - Temperature
            VStack(alignment: .leading, spacing: 8) {
                Text("Value (Temperature)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .value(Measurement(value: 72.5, type: .temperature(.fahrenheit))),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value - Duration
            VStack(alignment: .leading, spacing: 8) {
                Text("Value (Duration)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .value(Measurement(value: 60, type: .duration(.minutes))),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value - Speed
            VStack(alignment: .leading, spacing: 8) {
                Text("Value (Speed)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .value(Measurement(value: 65.5, type: .speed(.milesPerHour))),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value - Area
            VStack(alignment: .leading, spacing: 8) {
                Text("Value (Area)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .value(Measurement(value: 250.0, type: .area(.squareMeters))),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value - Energy
            VStack(alignment: .leading, spacing: 8) {
                Text("Value (Energy)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .value(Measurement(value: 2500.0, type: .energy(.calories))),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value - Number
            VStack(alignment: .leading, spacing: 8) {
                Text("Value (Number)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .value(Measurement(value: 42.0, type: .number(42.0))),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value Range - Length
            VStack(alignment: .leading, spacing: 8) {
                Text("Value Range (Length)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .valueRange(
                            Measurement(value: 10.0, type: .length(.meters))...Measurement(value: 50.0, type: .length(.meters))
                        ),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value Range - Percentage
            VStack(alignment: .leading, spacing: 8) {
                Text("Value Range (Percentage)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .valueRange(
                            Measurement(value: 20.5, type: .percentage(20.5))...Measurement(value: 80.5, type: .percentage(80.5))
                        ),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value Range - Currency
            VStack(alignment: .leading, spacing: 8) {
                Text("Value Range (Currency)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .valueRange(
                            Measurement(value: 50.0, type: .currency(50.0))...Measurement(value: 100.0, type: .currency(100.0))
                        ),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value Range - Mass
            VStack(alignment: .leading, spacing: 8) {
                Text("Value Range (Mass)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .valueRange(
                            Measurement(value: 50.0, type: .mass(.kilograms))...Measurement(value: 150.0, type: .mass(.kilograms))
                        ),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value Range - Volume
            VStack(alignment: .leading, spacing: 8) {
                Text("Value Range (Volume)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .valueRange(
                            Measurement(value: 100.0, type: .volume(.milliliters))...Measurement(value: 500.0, type: .volume(.milliliters))
                        ),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value Range - Temperature
            VStack(alignment: .leading, spacing: 8) {
                Text("Value Range (Temperature)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .valueRange(
                            Measurement(value: 32.0, type: .temperature(.fahrenheit))...Measurement(value: 98.6, type: .temperature(.fahrenheit))
                        ),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value Range - Duration
            VStack(alignment: .leading, spacing: 8) {
                Text("Value Range (Duration)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .valueRange(
                            Measurement(value: 30, type: .duration(.minutes))...Measurement(value: 120, type: .duration(.minutes))
                        ),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value Range - Speed
            VStack(alignment: .leading, spacing: 8) {
                Text("Value Range (Speed)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .valueRange(
                            Measurement(value: 30.0, type: .speed(.milesPerHour))...Measurement(value: 70.0, type: .speed(.milesPerHour))
                        ),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value Range - Area
            VStack(alignment: .leading, spacing: 8) {
                Text("Value Range (Area)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .valueRange(
                            Measurement(value: 100.0, type: .area(.squareMeters))...Measurement(value: 500.0, type: .area(.squareMeters))
                        ),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value Range - Energy
            VStack(alignment: .leading, spacing: 8) {
                Text("Value Range (Energy)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .valueRange(
                            Measurement(value: 1500.0, type: .energy(.calories))...Measurement(value: 3000.0, type: .energy(.calories))
                        ),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Value Range - Number
            VStack(alignment: .leading, spacing: 8) {
                Text("Value Range (Number)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .valueRange(
                            Measurement(value: 10.0, type: .number(10.0))...Measurement(value: 100.0, type: .number(100.0))
                        ),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // File
            VStack(alignment: .leading, spacing: 8) {
                Text("File").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .file(URL(fileURLWithPath: "/path/to/document.pdf")),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Date Frequency - Every Friday
            VStack(alignment: .leading, spacing: 8) {
                Text("Date Frequency (Every Friday)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .dateFrequency(DateFrequency(dayOfWeek: .friday, interval: 1)),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
            
            // Date Frequency - Every Other Friday
            VStack(alignment: .leading, spacing: 8) {
                Text("Date Frequency (Every Other Friday)").font(.headline)
                MessageBubbleView(
                    message: Message(
                        content: .dateFrequency(DateFrequency(dayOfWeek: .friday, interval: 2)),
                        user: sampleUser,
                        messageType: .outbound
                    ),
                    showTail: true,
                    theme: .defaultTheme
                )
            }
        }
        .padding()
    }
    .environment(bubbleConfig)
}

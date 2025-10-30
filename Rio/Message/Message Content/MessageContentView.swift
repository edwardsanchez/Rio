//
//  MessageContentView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/18/25.
//

import AVKit
import MapKit
import SwiftUI

/// A view that renders different types of message content based on the ContentType enum
struct MessageContentView: View {
    let content: ContentType
    let textColor: Color
    var messageID: UUID? // Optional message ID for creating unique image identifiers
    @Binding var selectedImageData: ImageData?

    @State private var contentWidth = CGFloat.zero
    @State private var showingVideoFullScreen = false
    @State private var showingAudioFullScreen = false

    let insetCornerRadius: CGFloat = 10

    @State private var fallbackID = UUID().uuidString

    private var uniquePrefix: String {
        messageID?.uuidString ?? fallbackID
    }

    var body: some View {
        contentView
    }

    @ViewBuilder
    private var contentView: some View {
        switch content {
        case let .text(text):
            Text(text)
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)

        case let .color(rgb):
            colorView(rgb)

        case let .image(image):
            imageView(image)
                .onTapGesture {
                    selectedImageData = ImageData(image: image)
                }

        case let .labeledImage(labeledImage):
            labeledImageView(labeledImage)
                .onTapGesture {
                    selectedImageData = ImageData(image: labeledImage.image, label: labeledImage.label)
                }

        case let .video(url):
            VideoPlayer(player: AVPlayer(url: url))
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: insetCornerRadius))

        case let .audio(url):
            VideoPlayer(player: AVPlayer(url: url))
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: insetCornerRadius))

        case let .date(date, granularity):
            switch granularity {
            case .dateAndTime:
                Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    .foregroundStyle(textColor)
                    .font(.callout.bold())
            case .dateOnly:
                Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .foregroundStyle(textColor)
                    .font(.callout.bold())
            case .timeOnly:
                Label(date.formatted(date: .omitted, time: .shortened), systemImage: "clock.fill")
                    .foregroundStyle(textColor)
                    .font(.callout.bold())
            }

        case let .dateRange(range, granularity):
            switch granularity {
            case .dateAndTime:
                HStack(spacing: 4) {
                    Image(systemName: "calendar.badge.clock")
                    Text(range.start.formatted(date: .abbreviated, time: .shortened))
                        .fixedSize(horizontal: true, vertical: true)
                    Image(systemName: "arrow.right")
                    Text(range.end.formatted(date: .abbreviated, time: .shortened))
                        .fixedSize(horizontal: true, vertical: true)
                }
                .font(.callout.bold())
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
                .font(.callout.bold())
                .foregroundStyle(textColor)
            case .timeOnly:
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                    HStack(spacing: 4) {
                        Text(range.start.formatted(date: .omitted, time: .shortened))
                        Image(systemName: "arrow.right")
                        Text(range.end.formatted(date: .omitted, time: .shortened))
                    }
                }
                .font(.caption.bold())
                .foregroundStyle(textColor)
            }

        case let .location(mapItem):
            locationView(mapItem)

        case let .url(url):
            URLPreviewCard(url: url, textColor: textColor)

        case let .textChoice(text):
            Label(text, systemImage: "checkmark.circle.fill")
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)

        case let .multiChoice(choices):
            if let first = choices.first {
                switch first {
                case .textChoice:
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                            choiceItemView(choice, index: index)
                        }
                    }
                default:
                    let columns = choices.count.gridColumns
                    let minimum: CGFloat = {
                        if case .location = first {
                            return 120
                        }

                        return 60
                    }()

                    HStack(spacing: 0) {
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible(minimum: minimum, maximum: 120), spacing: 12),
                                count: columns
                            ),
                            alignment: .center,
                            spacing: 12
                        ) {
                            ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                                choiceItemView(choice, index: index)
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }

        case let .emoji(emoji):
            // Emoji content - larger text
            Text(emoji)
                .font(.system(size: 60))
                .padding(.bottom, -30)

        case let .code(code):
            // Placeholder for code content
            Text(code)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .background(Color.primary.opacity(0.15))
                .cornerRadius(12)

        case let .bool(value):
            Label(value ? "YES" : "NO", systemImage: value ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                .foregroundStyle(textColor)
                .font(.caption.bold())

        case let .rating(rating):
            HStack(spacing: 2) {
                ForEach(0 ..< (rating.rawValue + 1), id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                }
            }
            .font(.title3)

        case let .value(measurement):
            Label(formatMeasurementValue(measurement), systemImage: measurementSymbol(for: measurement.type))
                .foregroundStyle(textColor)
                .font(.title3.bold())

        case let .valueRange(range):
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

        case let .file(url):
            Label(url.lastPathComponent, systemImage: "doc.fill")
                .foregroundStyle(textColor)
                .font(.caption.bold())

        case let .dateFrequency(frequency):
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
        case .length: "ruler.fill"
        case .percentage: "percent"
        case .currency: "dollarsign.circle.fill"
        case .mass: "scalemass.fill"
        case .volume: "flask.fill"
        case .temperature: "thermometer.medium"
        case .duration: "clock.fill"
        case .speed: "speedometer"
        case .area: "square.fill"
        case .energy: "bolt.fill"
        case .number: "number"
        }
    }

    private func formatMeasurementValue(_ measurement: Measurement) -> String {
        switch measurement.type {
        case let .length(unit):
            String(format: "%.2f%@", measurement.value, unit.symbol)
        case .percentage:
            String(format: "%.1f%%", measurement.value)
        case .currency:
            String(format: "$%.2f", measurement.value)
        case let .mass(unit):
            String(format: "%.2f%@", measurement.value, unit.symbol)
        case let .volume(unit):
            String(format: "%.2f%@", measurement.value, unit.symbol)
        case let .temperature(unit):
            String(format: "%.1f%@", measurement.value, unit.symbol)
        case let .duration(unit):
            String(format: "%.0f%@", measurement.value, unit.symbol)
        case let .speed(unit):
            String(format: "%.1f%@", measurement.value, unit.symbol)
        case let .area(unit):
            String(format: "%.2f%@", measurement.value, unit.symbol)
        case let .energy(unit):
            String(format: "%.2f%@", measurement.value, unit.symbol)
        case .number:
            String(format: "%.2f", measurement.value)
        }
    }

    // MARK: - Reusable Content View Helpers

    private func colorView(_ rgb: RGB, compact: Bool = false) -> some View {
        // Compact chip for multi-choice grids
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: insetCornerRadius)
                .fill(Color(
                    red: Double(rgb.red) / 255.0,
                    green: Double(rgb.green) / 255.0,
                    blue: Double(rgb.blue) / 255.0
                ))
                .stroke(textColor.opacity(0.5), lineWidth: 2)
//                .aspectRatio(1, contentMode: .fit)
                .frame(height: 60)
                .frame(maxWidth: 100)

            if let name = rgb.name {
                Text(name)
                    .font(.caption)
                    .foregroundStyle(textColor)
                    .lineLimit(1)
            }
        }
    }

    private func imageView(_ image: Image, compact: Bool = false) -> some View {
        image
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: insetCornerRadius))
            .if(compact) { view in
                view.frame(maxWidth: 80, maxHeight: 80)
            }
    }

    private func labeledImageView(_ labeledImage: LabeledImage, compact: Bool = false) -> some View {
        VStack(spacing: compact ? 4 : 8) {
            Group {
                labeledImage.image
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: insetCornerRadius))
                    .if(compact) { view in
                        view.frame(maxWidth: 80, maxHeight: 80)
                    }
            }

            Text(labeledImage.label)
                .font(compact ? .caption2 : .callout)
                .foregroundStyle(textColor)
                .lineLimit(compact ? 1 : nil)
        }
    }

    private func locationView(_ mapItem: MKMapItem, compact: Bool = false) -> some View {
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
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func choiceItemView(_ choice: ChoiceValue, index: Int) -> some View {
        switch choice {
        case let .color(rgb):
            colorView(rgb, compact: true)
        case let .image(image):
            imageView(image, compact: true)
                .onTapGesture {
                    selectedImageData = ImageData(image: image)
                }
        case let .labeledImage(labeledImage):
            labeledImageView(labeledImage, compact: true)
                .onTapGesture {
                    selectedImageData = ImageData(image: labeledImage.image, label: labeledImage.label)
                }
        case let .location(mapItem):
            locationView(mapItem, compact: true)
        case let .textChoice(text):
            Label(text, systemImage: "checkmark.square.fill")
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview 1: Text & Choices

#Preview("Text & Choices") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var selectedImageData: ImageData?

    let sampleUser = User(id: UUID(), name: "Edward", avatar: .edward)

    NavigationStack {
        ScrollView {
            LazyVStack(alignment: .trailing, spacing: 24) {
                // Text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .text("Hello, World! This is a text message."),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Text (Multi-line)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text (Multi-line)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .text(
                                "This is a longer message that demonstrates text wrapping behavior. It contains multiple lines of text to show how the content view handles longer messages."
                            ),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Text Choice
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text Choice").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .textChoice("This is a text choice option"),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Multi-choice - Text Choices
                VStack(alignment: .leading, spacing: 8) {
                    Text("Multi-choice (Text - 3)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .multiChoice([
                                .textChoice("Option A"),
                                .textChoice("Option B"),
                                .textChoice("Option C")
                            ]),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Multi-choice - Prime number (7 days)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Multi-choice (Text - 7)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .multiChoice([
                                .textChoice("Monday"),
                                .textChoice("Tuesday"),
                                .textChoice("Wednesday"),
                                .textChoice("Thursday"),
                                .textChoice("Friday"),
                                .textChoice("Saturday"),
                                .textChoice("Sunday")
                            ]),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }
            }
            .padding(20)
        }
        .environment(bubbleConfig)
        .environment(ChatData())
        .environment(ReactionsCoordinator())
    }
}

// MARK: - Preview 2: Images

#Preview("Images") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var selectedImageData: ImageData?

    let sampleUser = User(id: UUID(), name: "Edward", avatar: .edward)

    ZStack {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .trailing, spacing: 24) {
                    // Image
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Image").font(.headline)
                        MessageBubbleView(
                            message: Message(
                                content: .image(Image(.cat)),
                                from: sampleUser
                            ),
                            showTail: true,
                            theme: .defaultTheme,
                            selectedImageData: $selectedImageData
                        )
                    }

                    // Labeled Image
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Labeled Image").font(.headline)
                        MessageBubbleView(
                            message: Message(
                                content: .labeledImage(LabeledImage(
                                    label: "A cute cat in the garden",
                                    image: Image(.cat)
                                )),
                                from: sampleUser
                            ),
                            showTail: true,
                            theme: .defaultTheme,
                            selectedImageData: $selectedImageData
                        )
                    }

                    // Multi-choice - Images
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Multi-choice (Images - 4)").font(.headline)
                        MessageBubbleView(
                            message: Message(
                                content: .multiChoice([
                                    .image(Image(.cat)),
                                    .image(Image(.cat)),
                                    .image(Image(.cat)),
                                    .image(Image(.cat))
                                ]),
                                from: sampleUser
                            ),
                            showTail: true,
                            theme: .defaultTheme,
                            selectedImageData: $selectedImageData
                        )
                    }
                }
                .padding(20)
            }
            .environment(bubbleConfig)
            .environment(ChatData())
            .environment(ReactionsCoordinator())
        }

        // Image detail overlay
        if let imageData = selectedImageData {
            ImageDetailView(
                imageData: imageData,
                isPresented: Binding(
                    get: { selectedImageData != nil },
                    set: { newValue in
                        if !newValue {
                            selectedImageData = nil
                        }
                    }
                )
            )
            .zIndex(1)
        }
    }
}

// MARK: - Preview 3: Audio & Video

#Preview("Audio & Video") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var selectedImageData: ImageData?

    let sampleUser = User(id: UUID(), name: "Edward", avatar: .edward)

    NavigationStack {
        ScrollView {
            LazyVStack(alignment: .trailing, spacing: 24) {
                // Video
                VStack(alignment: .leading, spacing: 8) {
                    Text("Video").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .video(
                                URL(
                                    string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4"
                                )!
                            ),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Audio
                VStack(alignment: .leading, spacing: 8) {
                    Text("Audio").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .audio(
                                URL(string: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3")!
                            ),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }
            }
            .padding(20)
        }
        .environment(bubbleConfig)
        .environment(ChatData())
        .environment(ReactionsCoordinator())
    }
}

// MARK: - Preview 4: Colors & Locations

#Preview("Colors & Locations") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var selectedImageData: ImageData?

    let sampleUser = User(id: UUID(), name: "Edward", avatar: .edward)

    NavigationStack {
        ScrollView {
            LazyVStack(alignment: .trailing, spacing: 24) {
                // Color
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .color(RGB(red: 255, green: 100, blue: 50, name: "Coral Orange")),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Location
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .location({
                                let coordinate = CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090)
                                let location = CLLocation(
                                    latitude: coordinate.latitude,
                                    longitude: coordinate.longitude
                                )
                                let mapItem = MKMapItem(location: location, address: nil)
                                mapItem.name = "Apple Park"
                                return mapItem
                            }()),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Multi-choice - Colors (2)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Multi-choice (Colors - 2)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .multiChoice([
                                .color(RGB(red: 255, green: 100, blue: 50, name: "Coral")),
                                .color(RGB(red: 100, green: 200, blue: 255, name: "Sky Blue"))
                            ]),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Multi-choice - Colors (3)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Multi-choice (Colors - 3)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .multiChoice([
                                .color(RGB(red: 255, green: 100, blue: 50, name: "Coral")),
                                .color(RGB(red: 100, green: 200, blue: 255, name: "Sky")),
                                .color(RGB(red: 50, green: 255, blue: 100, name: "Mint")),
                                .color(RGB(red: 200, green: 50, blue: 255, name: "Purple")),
                                .color(RGB(red: 255, green: 255, blue: 100, name: "Yellow")),
                                .color(RGB(red: 100, green: 100, blue: 100, name: "Gray"))
                            ]),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Multi-choice - Locations
                VStack(alignment: .leading, spacing: 8) {
                    Text("Multi-choice (Locations - 2)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .multiChoice([
                                .location({
                                    let coordinate = CLLocationCoordinate2D(latitude: 37.3346, longitude: -122.0090)
                                    let location = CLLocation(
                                        latitude: coordinate.latitude,
                                        longitude: coordinate.longitude
                                    )
                                    let mapItem = MKMapItem(location: location, address: nil)
                                    mapItem.name = "Apple Park"
                                    return mapItem
                                }()),
                                .location({
                                    let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                                    let location = CLLocation(
                                        latitude: coordinate.latitude,
                                        longitude: coordinate.longitude
                                    )
                                    let mapItem = MKMapItem(location: location, address: nil)
                                    mapItem.name = "San Francisco"
                                    return mapItem
                                }())
                            ]),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }
            }
            .padding(20)
        }
        .environment(bubbleConfig)
        .environment(ChatData())
        .environment(ReactionsCoordinator())
    }
}

// MARK: - Preview 5: Values

#Preview("Values") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var selectedImageData: ImageData?

    let sampleUser = User(id: UUID(), name: "Edward", avatar: .edward)

    NavigationStack {
        ScrollView {
            LazyVStack(alignment: .trailing, spacing: 24) {
                // Value - Length
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value (Length)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .value(Measurement(value: 42.5, type: .length(.meters))),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value - Percentage
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value (Percentage)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .value(Measurement(value: 75.5, type: .percentage(75.5))),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value - Currency
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value (Currency)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .value(Measurement(value: 99.99, type: .currency(99.99))),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value - Mass
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value (Mass)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .value(Measurement(value: 150.0, type: .mass(.kilograms))),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value - Volume
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value (Volume)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .value(Measurement(value: 500.0, type: .volume(.milliliters))),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value - Temperature
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value (Temperature)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .value(Measurement(value: 72.5, type: .temperature(.fahrenheit))),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value - Duration
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value (Duration)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .value(Measurement(value: 60, type: .duration(.minutes))),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value - Speed
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value (Speed)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .value(Measurement(value: 65.5, type: .speed(.milesPerHour))),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value - Area
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value (Area)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .value(Measurement(value: 250.0, type: .area(.squareMeters))),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value - Energy
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value (Energy)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .value(Measurement(value: 2500.0, type: .energy(.calories))),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value - Number
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value (Number)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .value(Measurement(value: 42.0, type: .number(42.0))),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }
            }
            .padding(20)
        }
        .environment(bubbleConfig)
        .environment(ChatData())
        .environment(ReactionsCoordinator())
    }
}

// MARK: - Preview 6: Value Ranges

#Preview("Value Ranges") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var selectedImageData: ImageData?

    let sampleUser = User(id: UUID(), name: "Edward", avatar: .edward)

    NavigationStack {
        ScrollView {
            LazyVStack(alignment: .trailing, spacing: 24) {
                // Value Range - Length
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value Range (Length)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .valueRange(
                                Measurement(value: 10.0, type: .length(.meters)) ... Measurement(
                                    value: 50.0,
                                    type: .length(.meters)
                                )
                            ),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value Range - Percentage
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value Range (Percentage)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .valueRange(
                                Measurement(value: 20.5, type: .percentage(20.5)) ... Measurement(
                                    value: 80.5,
                                    type: .percentage(80.5)
                                )
                            ),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value Range - Currency
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value Range (Currency)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .valueRange(
                                Measurement(value: 50.0, type: .currency(50.0)) ... Measurement(
                                    value: 100.0,
                                    type: .currency(100.0)
                                )
                            ),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value Range - Mass
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value Range (Mass)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .valueRange(
                                Measurement(value: 50.0, type: .mass(.kilograms)) ... Measurement(
                                    value: 150.0,
                                    type: .mass(.kilograms)
                                )
                            ),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value Range - Volume
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value Range (Volume)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .valueRange(
                                Measurement(value: 100.0, type: .volume(.milliliters)) ... Measurement(
                                    value: 500.0,
                                    type: .volume(.milliliters)
                                )
                            ),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value Range - Temperature
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value Range (Temperature)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .valueRange(
                                Measurement(value: 32.0, type: .temperature(.fahrenheit)) ... Measurement(
                                    value: 98.6,
                                    type: .temperature(.fahrenheit)
                                )
                            ),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value Range - Duration
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value Range (Duration)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .valueRange(
                                Measurement(value: 30, type: .duration(.minutes)) ... Measurement(
                                    value: 120,
                                    type: .duration(.minutes)
                                )
                            ),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value Range - Speed
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value Range (Speed)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .valueRange(
                                Measurement(value: 30.0, type: .speed(.milesPerHour)) ... Measurement(
                                    value: 70.0,
                                    type: .speed(.milesPerHour)
                                )
                            ),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value Range - Area
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value Range (Area)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .valueRange(
                                Measurement(value: 100.0, type: .area(.squareMeters)) ... Measurement(
                                    value: 500.0,
                                    type: .area(.squareMeters)
                                )
                            ),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value Range - Energy
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value Range (Energy)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .valueRange(
                                Measurement(value: 1500.0, type: .energy(.calories)) ... Measurement(
                                    value: 3000.0,
                                    type: .energy(.calories)
                                )
                            ),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Value Range - Number
                VStack(alignment: .leading, spacing: 8) {
                    Text("Value Range (Number)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .valueRange(
                                Measurement(value: 10.0, type: .number(10.0)) ... Measurement(
                                    value: 100.0,
                                    type: .number(100.0)
                                )
                            ),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }
            }
            .padding(20)
        }
        .environment(bubbleConfig)
        .environment(ChatData())
        .environment(ReactionsCoordinator())
    }
}

// MARK: - Preview 7: Dates

#Preview("Dates") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var selectedImageData: ImageData?

    let sampleUser = User(id: UUID(), name: "Edward", avatar: .edward)

    NavigationStack {
        ScrollView {
            LazyVStack(alignment: .trailing, spacing: 24) {
                // Date - Date and Time
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date (Date & Time)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .date(Date.now, granularity: .dateAndTime),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Date - Date Only
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date (Date Only)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .date(Date.now, granularity: .dateOnly),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Date - Time Only
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date (Time Only)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .date(Date.now, granularity: .timeOnly),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
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
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
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
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
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
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Date Frequency - Every Friday
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date Frequency (Every Friday)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .dateFrequency(DateFrequency(dayOfWeek: .friday, interval: 1)),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Date Frequency - Every Other Friday
                VStack(alignment: .leading, spacing: 8) {
                    Text("Date Frequency (Every Other Friday)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .dateFrequency(DateFrequency(dayOfWeek: .friday, interval: 2)),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }
            }
            .padding(20)
        }
        .environment(bubbleConfig)
        .environment(ChatData())
        .environment(ReactionsCoordinator())
    }
}

// MARK: - Preview 8: Miscellaneous

#Preview("Miscellaneous") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var selectedImageData: ImageData?

    let sampleUser = User(id: UUID(), name: "Edward", avatar: .edward)

    NavigationStack {
        ScrollView {
            LazyVStack(alignment: .trailing, spacing: 24) {
                // URL
                VStack(alignment: .leading, spacing: 8) {
                    Text("URL (with metadata)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .url(URL(string: "https://www.apple.com")!),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // URL - Alternative
                VStack(alignment: .leading, spacing: 8) {
                    Text("URL (Unresolved)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .url(URL(string: "https://somefakeURL.com")!),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Emoji
                VStack(alignment: .leading, spacing: 8) {
                    Text("Emoji").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .emoji("👋🎉🚀"),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Code
                VStack(alignment: .leading, spacing: 8) {
                    Text("Code").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .code("func hello() {\n    print(\"Hello, World!\")\n    return true\n}"),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Boolean - True
                VStack(alignment: .leading, spacing: 8) {
                    Text("Boolean (True)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .bool(true),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Boolean - False
                VStack(alignment: .leading, spacing: 8) {
                    Text("Boolean (False)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .bool(false),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Rating - Five Stars
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rating (5 Stars)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .rating(.five),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // Rating - Three Stars
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rating (3 Stars)").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .rating(.three),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }

                // File
                VStack(alignment: .leading, spacing: 8) {
                    Text("File").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .file(URL(fileURLWithPath: "/path/to/document.pdf")),
                            from: sampleUser
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                }
            }
            .padding(20)
        }
        .environment(bubbleConfig)
        .environment(ChatData())
        .environment(ReactionsCoordinator())
    }
}

// MARK: - Int Extension

extension Int {
    var isPrime: Bool {
        guard self > 1 else { return false }
        guard self > 3 else { return true }
        if self % 2 == 0 || self % 3 == 0 { return false }
        var i = 5
        while i * i <= self {
            if self % i == 0 || self % (i + 2) == 0 { return false }
            i += 6
        }

        return true
    }

    var gridColumns: Int {
        if isPrime { return 1 }
        if self % 5 == 0 { return 5 }
        if self % 3 == 0 { return 3 }
        if self % 2 == 0 { return 2 }
        return 1
    }
}

// MARK: - View Extension

extension View {
    @ViewBuilder
    func `if`(_ condition: Bool, transform: (Self) -> some View) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

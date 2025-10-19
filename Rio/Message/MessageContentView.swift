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
    var messageID: UUID? = nil  // Optional message ID for creating unique image identifiers
    @Binding var selectedImageData: ImageData?
    let namespace: Namespace.ID
    
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
        case .text(let text):
            Text(text)
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
            
        case .color(let rgb):
            colorView(rgb)
            
        case .image(let image):
            let imageID = "\(uniquePrefix)-standalone-image"
            imageView(image)
                .matchedGeometryEffect(id: imageID, in: namespace)
                .onTapGesture {
                    withAnimation(.smooth(duration: 0.4)) {
                        selectedImageData = ImageData(id: imageID, image: image)
                    }
                }
            
        case .labeledImage(let labeledImage):
            let imageID = "\(uniquePrefix)-standalone-labeled"
            labeledImageView(labeledImage, imageID: imageID)
                .onTapGesture {
                    withAnimation(.smooth(duration: 0.4)) {
                        selectedImageData = ImageData(id: imageID, image: labeledImage.image, label: labeledImage.label)
                    }
                }
            
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

        case .dateRange(let range, let granularity):
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
            
        case .location(let mapItem):
            locationView(mapItem)
            
        case .url(let url):
            URLPreviewCard(url: url, textColor: textColor)
            
        case .textChoice(let text):
            Label(text, systemImage: "checkmark.circle.fill")
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
            
        case .multiChoice(let choices):
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
                            columns: Array(repeating: GridItem(.flexible(minimum: minimum, maximum: 120), spacing: 12), count: columns),
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
        case .speed(_): return "speedometer"
        case .area(_): return "square.fill"
        case .energy(_): return "bolt.fill"
        case .number(_): return "number"
        }
    }
    
    private func formatMeasurementValue(_ measurement: Measurement) -> String {
        switch measurement.type {
        case .length(let unit):
            return String(format: "%.2f%@", measurement.value, unit.symbol)
        case .percentage(_):
            return String(format: "%.1f%%", measurement.value)
        case .currency(_):
            return String(format: "$%.2f", measurement.value)
        case .mass(let unit):
            return String(format: "%.2f%@", measurement.value, unit.symbol)
        case .volume(let unit):
            return String(format: "%.2f%@", measurement.value, unit.symbol)
        case .temperature(let unit):
            return String(format: "%.1f%@", measurement.value, unit.symbol)
        case .duration(let unit):
            return String(format: "%.0f%@", measurement.value, unit.symbol)
        case .speed(let unit):
            return String(format: "%.1f%@", measurement.value, unit.symbol)
        case .area(let unit):
            return String(format: "%.2f%@", measurement.value, unit.symbol)
        case .energy(let unit):
            return String(format: "%.2f%@", measurement.value, unit.symbol)
        case .number(_):
            return String(format: "%.2f", measurement.value)
        }
    }
    
    // MARK: - Reusable Content View Helpers
    
    @ViewBuilder
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
    
    @ViewBuilder
    private func imageView(_ image: Image, compact: Bool = false) -> some View {
        image
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: insetCornerRadius))
            .if(compact) { view in
                view.frame(maxWidth: 80, maxHeight: 80)
            }
    }
    
    @ViewBuilder
    private func labeledImageView(_ labeledImage: LabeledImage, compact: Bool = false, imageID: String? = nil) -> some View {
        VStack(spacing: compact ? 4 : 8) {
            labeledImage.image
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: insetCornerRadius))
                .if(compact) { view in
                    view.frame(maxWidth: 80, maxHeight: 80)
                }
                .if(imageID != nil) { view in
                    view.matchedGeometryEffect(id: imageID!, in: namespace)
                }
            Text(labeledImage.label)
                .font(compact ? .caption2 : .callout)
                .foregroundStyle(textColor)
                .lineLimit(compact ? 1 : nil)
        }
    }
    
    @ViewBuilder
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
        case .color(let rgb):
            colorView(rgb, compact: true)
        case .image(let image):
            let imageID = "\(uniquePrefix)-grid-image-\(index)"
            imageView(image, compact: true)
                .matchedGeometryEffect(id: imageID, in: namespace)
                .onTapGesture {
                    withAnimation(.smooth(duration: 0.4)) {
                        selectedImageData = ImageData(id: imageID, image: image)
                    }
                }
        case .labeledImage(let labeledImage):
            let imageID = "\(uniquePrefix)-grid-labeled-\(index)"
            labeledImageView(labeledImage, compact: true, imageID: imageID)
                .onTapGesture {
                    withAnimation(.smooth(duration: 0.4)) {
                        selectedImageData = ImageData(id: imageID, image: labeledImage.image, label: labeledImage.label)
                    }
                }
        case .location(let mapItem):
            locationView(mapItem, compact: true)
        case .textChoice(let text):
            Label(text, systemImage: "checkmark.square.fill")
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview 1: Text & Choices

#Preview("Text & Choices") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var selectedImageData: ImageData? = nil
    @Previewable @Namespace var imageNamespace
    
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
                            user: sampleUser,
                            messageType: .outbound
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
                    )
                }
                
                // Text Choice
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text Choice").font(.headline)
                    MessageBubbleView(
                        message: Message(
                            content: .textChoice("This is a text choice option"),
                            user: sampleUser,
                            messageType: .outbound
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                            user: sampleUser,
                            messageType: .outbound
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                            user: sampleUser,
                            messageType: .outbound
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
                    )
                }
            }
            .padding(20)
        }
        .environment(bubbleConfig)
    }
}

// MARK: - Preview 2: Images

#Preview("Images") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var selectedImageData: ImageData? = nil
    @Previewable @Namespace var imageNamespace
    
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
                                user: sampleUser,
                                messageType: .outbound
                            ),
                            showTail: true,
                            theme: .defaultTheme,
                            selectedImageData: $selectedImageData,
                            namespace: imageNamespace
                        )
                    }
                    
                    // Labeled Image
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Labeled Image").font(.headline)
                        MessageBubbleView(
                            message: Message(
                                content: .labeledImage(LabeledImage(label: "A cute cat in the garden", image: Image(.cat))),
                                user: sampleUser,
                                messageType: .outbound
                            ),
                            showTail: true,
                            theme: .defaultTheme,
                            selectedImageData: $selectedImageData,
                            namespace: imageNamespace
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
                                user: sampleUser,
                                messageType: .outbound
                            ),
                            showTail: true,
                            theme: .defaultTheme,
                            selectedImageData: $selectedImageData,
                            namespace: imageNamespace
                        )
                    }
                }
                .padding(20)
            }
            .environment(bubbleConfig)
        }
        
        // Image detail overlay
        if let imageData = selectedImageData {
            ImageDetailView(
                imageData: imageData,
                namespace: imageNamespace,
                isPresented: Binding(
                    get: { selectedImageData != nil },
                    set: { newValue in
                        if !newValue {
                            withAnimation(.smooth(duration: 0.4)) {
                                selectedImageData = nil
                            }
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
    @Previewable @State var selectedImageData: ImageData? = nil
    @Previewable @Namespace var imageNamespace
    
    let sampleUser = User(id: UUID(), name: "Edward", avatar: .edward)
    
    NavigationStack {
        ScrollView {
            LazyVStack(alignment: .trailing, spacing: 24) {
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
                    )
                }
            }
            .padding(20)
        }
        .environment(bubbleConfig)
    }
}

// MARK: - Preview 4: Colors & Locations

#Preview("Colors & Locations") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var selectedImageData: ImageData? = nil
    @Previewable @Namespace var imageNamespace
    
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
                            user: sampleUser,
                            messageType: .outbound
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                            user: sampleUser,
                            messageType: .outbound
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                            user: sampleUser,
                            messageType: .outbound
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                                    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                                    let mapItem = MKMapItem(location: location, address: nil)
                                    mapItem.name = "Apple Park"
                                    return mapItem
                                }()),
                                .location({
                                    let coordinate = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                                    let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                                    let mapItem = MKMapItem(location: location, address: nil)
                                    mapItem.name = "San Francisco"
                                    return mapItem
                                }())
                            ]),
                            user: sampleUser,
                            messageType: .outbound
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
                    )
                }
            }
            .padding(20)
        }
        .environment(bubbleConfig)
    }
}

// MARK: - Preview 5: Values

#Preview("Values") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var selectedImageData: ImageData? = nil
    @Previewable @Namespace var imageNamespace
    
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
                            user: sampleUser,
                            messageType: .outbound
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
                    )
                }
            }
            .padding(20)
        }
        .environment(bubbleConfig)
    }
}

// MARK: - Preview 6: Value Ranges

#Preview("Value Ranges") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var selectedImageData: ImageData? = nil
    @Previewable @Namespace var imageNamespace
    
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
                                Measurement(value: 10.0, type: .length(.meters))...Measurement(value: 50.0, type: .length(.meters))
                            ),
                            user: sampleUser,
                            messageType: .outbound
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
                    )
                }
            }
            .padding(20)
        }
        .environment(bubbleConfig)
    }
}

// MARK: - Preview 7: Dates

#Preview("Dates") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var selectedImageData: ImageData? = nil
    @Previewable @Namespace var imageNamespace
    
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
                            user: sampleUser,
                            messageType: .outbound
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
                    )
                }
            }
            .padding(20)
        }
        .environment(bubbleConfig)
    }
}

// MARK: - Preview 8: Miscellaneous

#Preview("Miscellaneous") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var selectedImageData: ImageData? = nil
    @Previewable @Namespace var imageNamespace
    
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
                            user: sampleUser,
                            messageType: .outbound
                        ),
                        showTail: true,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
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
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData,
                        namespace: imageNamespace
                    )
                }
            }
            .padding(20)
        }
        .environment(bubbleConfig)
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
        if self.isPrime { return 1 }
        if self % 5 == 0 { return 5 }
        if self % 3 == 0 { return 3 }
        if self % 2 == 0 { return 2 }
        return 1
    }
}

// MARK: - View Extension

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

//
//  􀝦 ThemePickerView.swift
//  Rio
//
//  Created by ChatGPT on 10/29/25.
//

import SwiftUI

struct ThemePickerView: View {
    let selectedColor: Color
    let onSelect: (Color) -> Void

    private let circleSize: CGFloat = 60
    private let gridSpacing: CGFloat = 20

    private var selectedOptionID: ThemeColorOption.ID? {
        ThemeColorOption.spectrum.first { option in
            option.matches(selectedColor)
        }?.id
    }

    var body: some View {
        LazyVGrid(columns: ThemeColorOption.gridColumns, spacing: 20) {
            ForEach(ThemeColorOption.spectrum) { option in
                colorRow(for: option)
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 20)
        .ignoresSafeArea()
    }

    private func colorRow(for option: ThemeColorOption) -> some View {
        let isSelected = option.id == selectedOptionID

        return Circle()
            .fill(option.color)
            .frame(width: circleSize, height: circleSize)
            .overlay {
                Circle()
                    .strokeBorder(
                        isSelected ? Color.primary.opacity(0.3) : Color.primary.opacity(0.15),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .scaleEffect(isSelected ? 1.2 : 1)
            .animation(.spring(bounce: 0.6), value: isSelected)
            .overlay {
                Circle()
                    .fill(.white)
                    .padding(20)
                    .scaleEffect(isSelected ? 1 : 0)
                    .animation(.smooth, value: isSelected)
            }
            .contentShape(Circle())
            .accessibilityElement()
            .accessibilityLabel(option.accessibilityLabel)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            .accessibilityHint("Sets the chat theme color")
            .onTapGesture {
                onSelect(option.color)
            }
    }
}

struct ThemeColorOption: Identifiable {
    let id: String
    let color: Color
    let accessibilityLabel: String

    func matches(_ otherColor: Color) -> Bool {
        color == otherColor
    }
}

extension ThemeColorOption {
    static let spectrum: [ThemeColorOption] = [
        ThemeColorOption(id: "default", color: .defaultBubble, accessibilityLabel: "Default"),
        ThemeColorOption(id: "pink", color: Color.customPink, accessibilityLabel: "Pink"),
        ThemeColorOption(id: "red", color: Color(.systemRed), accessibilityLabel: "Red"),
        ThemeColorOption(id: "orange", color: Color(.systemOrange), accessibilityLabel: "Orange"),
        ThemeColorOption(
            id: "yellow",
            color: Color(.systemYellow).mix(with: .red, by: 0.3),
            accessibilityLabel: "Yellow"
        ),
        ThemeColorOption(id: "brown", color: Color.customLime, accessibilityLabel: "Brown"),
        ThemeColorOption(
            id: "green",
            color: Color(.systemGreen).mix(with: .black, by: 0.05),
            accessibilityLabel: "Green"
        ),
        ThemeColorOption(
            id: "teal",
            color: Color(.systemTeal).mix(with: .black, by: 0.04).mix(with: .green, by: 0.02),
            accessibilityLabel: "Teal"
        ),
        ThemeColorOption(id: "cyan", color: Color(.systemCyan).mix(with: .black, by: 0.04), accessibilityLabel: "Cyan"),
        ThemeColorOption(id: "blue", color: Color(.systemBlue), accessibilityLabel: "Blue"),
        ThemeColorOption(id: "indigo", color: Color(.systemIndigo), accessibilityLabel: "Indigo"),
        ThemeColorOption(id: "purple", color: Color(.systemPurple), accessibilityLabel: "Purple")
    ]

    static let gridColumns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 20, alignment: .center),
        count: 4
    )
}

#Preview {
    @Previewable @State var selectedColor: Color = ThemeColorOption.spectrum.first?.color ?? .defaultBubble

    ThemePickerView(selectedColor: selectedColor) { newColor in
        selectedColor = newColor
    }
    .padding()
    .frame(height: 320)
    .background(Color(.systemBackground))
}

struct ChatTheme {
    let inboundTextColor: Color
    let inboundBackgroundColor: Color
    let outboundTextColor: Color
    let outboundBackgroundColor: Color

    init(
        outboundBackgroundColor: Color,
        inboundBackgroundColor: Color? = nil,
        inboundTextColor: Color = .primary,
        outboundTextColor: Color = .white
    ) {
        self.outboundBackgroundColor = outboundBackgroundColor
        self.outboundTextColor = outboundTextColor
        self.inboundTextColor = inboundTextColor
        self.inboundBackgroundColor = inboundBackgroundColor
            ?? ChatTheme.resolveInboundBackgroundColor(for: outboundBackgroundColor)
    }

    private static func resolveInboundBackgroundColor(for outboundColor: Color) -> Color {
        let outboundColorMix = 0.03
        return Color(
            light: Color.gray.mix(with: .base, by: 0.9).mix(with: outboundColor, by: outboundColorMix),
            dark: Color.gray.mix(with: .base, by: 0.7).mix(with: outboundColor, by: outboundColorMix)
        )
    }

    // Predefined themes matching asset catalog
    static let defaultTheme = ChatTheme(
        outboundBackgroundColor: .defaultBubble
    )

    static let theme1 = ChatTheme(
        outboundBackgroundColor: .green
    )

    static let theme2 = ChatTheme(
        outboundBackgroundColor: .purple
    )
}

private struct ChatThemeColorPairRow: View {
    let option: ThemeColorOption

    private var theme: ChatTheme {
        ChatTheme(outboundBackgroundColor: option.color)
    }

    var body: some View {
        HStack(spacing: 16) {
            Text(option.accessibilityLabel)
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)

            colorChip(theme.outboundBackgroundColor, label: "Outbound")
            colorChip(theme.inboundBackgroundColor, label: "Inbound")
        }
    }

    @ViewBuilder
    private func colorChip(_ color: Color, label: String) -> some View {
        VStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 10)
                .fill(color)
                .frame(width: 44, height: 36)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                }
        }
    }
}

private struct ChatThemeColorsPreview: View {
    private let options = ThemeColorOption.spectrum

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("ChatTheme Color Pairs")
                .font(.headline)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(options) { option in
                    ChatThemeColorPairRow(option: option)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.base))
    }
}

#Preview("ChatTheme Colors") {
    ChatThemeColorsPreview()
}

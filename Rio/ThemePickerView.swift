//
//  ThemePickerView.swift
//  Rio
//
//  Created by ChatGPT on 10/29/25.
//

import SwiftUI
import UIKit

struct ThemePickerView: View {
    let selectedColor: Color
    let onSelect: (Color) -> Void

    private let circleSize: CGFloat = 56
    private let gridSpacing: CGFloat = 18

    private var selectedOptionID: ThemeColorOption.ID? {
        ThemeColorOption.spectrum.first { option in
            option.matches(selectedColor)
        }?.id
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Choose Theme")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: ThemeColorOption.gridColumns, spacing: gridSpacing) {
                ForEach(ThemeColorOption.spectrum) { option in
                    colorRow(for: option)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }

    private func colorRow(for option: ThemeColorOption) -> some View {
        let isSelected = option.id == selectedOptionID

        return Circle()
            .fill(option.color)
            .frame(width: circleSize, height: circleSize)
            .overlay {
                Circle()
                    .strokeBorder(
                        isSelected ? Color.primary : Color.primary.opacity(0.15),
                        lineWidth: isSelected ? 4 : 1
                    )
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
        color.isApproximatelyEqual(to: otherColor)
    }
}

extension ThemeColorOption {
    static let spectrum: [ThemeColorOption] = [
        ThemeColorOption(id: "red", color: Color(.systemRed), accessibilityLabel: "Red"),
        ThemeColorOption(id: "orange", color: Color(.systemOrange), accessibilityLabel: "Orange"),
        ThemeColorOption(id: "pink", color: Color(.systemPink), accessibilityLabel: "Pink"),
        ThemeColorOption(id: "brown", color: Color(.systemBrown), accessibilityLabel: "Brown"),
        ThemeColorOption(id: "yellow", color: Color(.systemYellow).mix(with: .red, by: 0.2), accessibilityLabel: "Yellow"),
        ThemeColorOption(id: "green", color: Color(.systemGreen), accessibilityLabel: "Green"),
        ThemeColorOption(id: "teal", color: Color(.systemTeal), accessibilityLabel: "Teal"),
        ThemeColorOption(id: "cyan", color: Color(.systemCyan), accessibilityLabel: "Cyan"),
        ThemeColorOption(id: "blue", color: Color(.systemBlue), accessibilityLabel: "Blue"),
        ThemeColorOption(id: "indigo", color: Color(.systemIndigo), accessibilityLabel: "Indigo"),
        ThemeColorOption(id: "purple", color: Color(.systemPurple), accessibilityLabel: "Purple"),
        ThemeColorOption(id: "default", color: .defaultBubble, accessibilityLabel: "Default")
    ]

    static let gridColumns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 18, alignment: .center), count: 4)
}

private extension Color {
    func isApproximatelyEqual(to other: Color, tolerance: CGFloat = 0.01) -> Bool {
        let lhs = UIColor(self).resolvedForComparison
        let rhs = UIColor(other).resolvedForComparison

        guard let lhsComponents = lhs.rgbComponents,
              let rhsComponents = rhs.rgbComponents else {
            return false
        }

        return zip(lhsComponents, rhsComponents).allSatisfy { abs($0 - $1) <= tolerance }
    }
}

private extension UIColor {
    var resolvedForComparison: UIColor {
        if #available(iOS 13.0, *) {
            return resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        }
        return self
    }

    var rgbComponents: [CGFloat]? {
        guard let converted = cgColor.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB)!,
            intent: .defaultIntent,
            options: nil
        ) else {
            return nil
        }

        return converted.components
    }
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

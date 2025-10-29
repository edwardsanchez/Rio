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
        ThemeColorOption(id: "systemRed", color: Color(.systemRed), accessibilityLabel: "System Red"),
        ThemeColorOption(id: "systemOrange", color: Color(.systemOrange), accessibilityLabel: "System Orange"),
        ThemeColorOption(id: "systemPink", color: Color(.systemPink), accessibilityLabel: "System Pink"),
        ThemeColorOption(id: "systemBrown", color: Color(.systemBrown), accessibilityLabel: "System Brown"),
        ThemeColorOption(id: "systemMint", color: Color(.systemMint), accessibilityLabel: "System Mint"),
        ThemeColorOption(id: "systemGreen", color: Color(.systemGreen), accessibilityLabel: "System Green"),
        ThemeColorOption(id: "systemTeal", color: Color(.systemTeal), accessibilityLabel: "System Teal"),
        ThemeColorOption(id: "systemCyan", color: Color(.systemCyan), accessibilityLabel: "System Cyan"),
        ThemeColorOption(id: "systemBlue", color: Color(.systemBlue), accessibilityLabel: "System Blue"),
        ThemeColorOption(id: "systemIndigo", color: Color(.systemIndigo), accessibilityLabel: "System Indigo"),
        ThemeColorOption(id: "systemPurple", color: Color(.systemPurple), accessibilityLabel: "System Purple"),
        ThemeColorOption(id: "defaultBubble", color: .defaultBubble, accessibilityLabel: "Default Bubble")
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

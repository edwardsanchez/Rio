//
//  EmojiCellView.swift
//  EmojiPicker
//
//  Created by Edward Sanchez on 10/22/25.
//

import SwiftUI

struct EmojiCellView: View {
    let emoji: Emoji
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(emoji.character)
                .font(.system(size: 32))
        }
        .buttonStyle(EmojiCellButtonStyle())
    }
}

#Preview {
    EmojiCellView(emoji: Emoji(
        id: "grinningFace",
        character: "😀",
        name: "Grinning Face",
        keywords: [],
        category: .people(.ageBased)
    )) {
        print("Tapped!")
    }
}

private struct EmojiCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? Color.secondary.opacity(0.2) : Color.clear)
            )
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

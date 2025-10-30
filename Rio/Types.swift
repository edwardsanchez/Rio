//
//  User.swift
//  Rio
//
//  Created by Edward Sanchez on 10/8/25.
//
import SwiftUI

struct User: Identifiable {
    let id: UUID
    let name: String
    let avatar: ImageResource?
}

struct Chat: Identifiable {
    let id: UUID
    let title: String
    let participants: [User] // Always includes the current "outbound" user
    let messages: [Message]
    let theme: ChatTheme

    init(
        id: UUID = UUID(),
        title: String?,
        participants: [User],
        messages: [Message] = [],
        theme: ChatTheme,
        currentUser: User? = nil
    ) {
        let fallbackTitle = Chat.fallbackTitle(for: participants, currentUser: currentUser)
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedTitle = trimmedTitle.isEmpty ? fallbackTitle : trimmedTitle

        self.id = id
        self.title = resolvedTitle
        self.participants = participants
        self.messages = messages
        self.theme = theme
    }
}

extension Chat {
    static func fallbackTitle(for participants: [User], currentUser: User?) -> String {
        let otherParticipants: [User]
        if let currentUser {
            otherParticipants = participants.filter { $0.id != currentUser.id }
        } else {
            otherParticipants = participants
        }

        switch otherParticipants.count {
        case 0:
            return "Note to Self"
        case 1:
            return otherParticipants.first?.name ?? ""
        default:
            return "\(otherParticipants.count) people"
        }
    }
}

struct ChatAvatarGeometryKey: Hashable {
    let chatID: UUID
    let participantID: UUID
}

extension Chat {
    func avatarGeometryKey(for participant: User) -> ChatAvatarGeometryKey {
        ChatAvatarGeometryKey(chatID: id, participantID: participant.id)
    }
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
        Color.base.mix(with: outboundColor, by: 0.5).withSaturation(0.01)
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

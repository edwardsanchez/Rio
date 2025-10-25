//
//  ChatTitleView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/24/25.
//

import SwiftUI

struct ChatTitleView: View {
    let chat: Chat

    private let avatarSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ForEach(chat.participants) { participant in
                    avatarView(for: participant)
                }
            }

            Text(chat.title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .glassEffect(.regular.interactive())
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func avatarView(for user: User) -> some View {
        Group {
            if let avatar = user.avatar {
                Image(avatar)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color.secondary.opacity(0.15))
                    .overlay(
                        Text(initials(for: user))
                            .font(.title.weight(.medium))
                            .foregroundStyle(.primary)
                    )
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .accessibilityLabel(user.name)
    }

    private func initials(for user: User) -> String {
        guard let firstCharacter = user.name.trimmingCharacters(in: .whitespacesAndNewlines).first else {
            return "?"
        }

        return String(firstCharacter).uppercased()
    }
}

#Preview("ChatTitleView Samples") {
    VStack(spacing: 24) {
        ChatTitleView(chat: .sample(title: "Solo Chat", participantNames: ["Amy"]))
        ChatTitleView(chat: .sample(title: "Pair Chat", participantNames: ["Amy", "Ben"]))
        ChatTitleView(chat: .sample(title: "Trio Chat", participantNames: ["Amy", "Ben", "Cara"]))
        ChatTitleView(chat: .sample(title: "Quartet Chat", participantNames: ["Amy", "Ben", "Cara", "Dan"]))
        ChatTitleView(chat: .sample(title: "Group Hang", participantNames: ["Amy", "Ben", "Cara", "Dan", "Eli", "Fiona", "Gus", "Hana"]))
    }
    .padding()
    .background(Color.base)
}

private extension Chat {
    static func sample(title: String, participantNames: [String]) -> Chat {
        Chat(
            title: title,
            participants: participantNames.map { name in
                User(id: UUID(), name: name, avatar: nil)
            },
            theme: .defaultTheme
        )
    }
}

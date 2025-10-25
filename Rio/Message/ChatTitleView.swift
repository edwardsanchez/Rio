//
//  ChatTitleView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/24/25.
//

import SwiftUI

struct ChatTitleView: View {
    let chat: Chat

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ForEach(chat.participants) { participant in
                    AvatarView(user: participant)
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

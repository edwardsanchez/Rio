//
//  ChatTitleView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/24/25.
//

import SwiftUI

struct ChatTitleView: View {
    let chat: Chat
    var isVertical: Bool = false
    var onTap: (() -> Void)?
    var avatarNamespace: Namespace.ID?
    var avatarMatchedGeometryId: AnyHashable?
    var isGeometrySource: Bool = true

    private var resolvedAvatarGeometryId: AnyHashable {
        avatarMatchedGeometryId ?? AnyHashable("chat-avatar-\(chat.id)")
    }

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 4) {
                avatarContent
                    .animation(.smooth(duration: 0.35), value: isVertical)
                    .onTapGesture {
                        onTap?()
                    }

                Text(chat.title)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 10)
                    .background {
                        Capsule()
                            .fill(Color.clear)
                    }
                    .glassEffect(.regular.interactive())
                    .offset(y: -10)
                    .onTapGesture {
                        onTap?()
                    }
            }
        }
    }

    private var avatarBase: some View {
        GreedyCircleStack(isVertical: isVertical, verticalSpacing: 20, verticalDiameter: 44) {
            ForEach(chat.participants) { participant in
                AvatarView(user: participant, avatarSize: nil)
            }
        }
        .padding(3)
        .background {
            Circle()
                .fill(Color.clear)
        }
        .glassEffect(.regular.interactive())
        .frame(width: 60, height: 60)
    }

    @ViewBuilder
    private var avatarContent: some View {
        if let namespace = avatarNamespace {
            avatarBase
                .matchedGeometryEffect(
                    id: resolvedAvatarGeometryId,
                    in: namespace,
                    properties: .frame,
                    anchor: .center,
                    isSource: isGeometrySource
                )
        } else {
            avatarBase
        }
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

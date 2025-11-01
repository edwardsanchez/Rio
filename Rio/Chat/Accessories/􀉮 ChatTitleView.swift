//
//  􀉮 ChatTitleView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/24/25.
//

import SwiftUI

struct ChatTitleView: View {
    @Environment(ChatData.self) private var chatData

    let chat: Chat
    var isVertical: Bool
    var onTap: (() -> Void)?
    var avatarNamespace: Namespace.ID?
    var isGeometrySource: Bool = true
    var matchedGeometryAnimation: Animation?

    init(
        chat: Chat,
        isVertical: Bool = false,
        onTap: (() -> Void)? = nil,
        avatarNamespace: Namespace.ID? = nil,
        isGeometrySource: Bool = true,
        matchedGeometryAnimation: Animation? = nil
    ) {
        self.chat = chat
        self.isVertical = isVertical
        self.onTap = onTap
        self.avatarNamespace = avatarNamespace
        self.isGeometrySource = isGeometrySource
        self.matchedGeometryAnimation = matchedGeometryAnimation
    }

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 4) {
                avatarContent
                    .onTapGesture {
                        onTap?()
                    }

                if !isVertical {
                    title
                        .transition(.identity)
                        .transaction { transaction in
                            transaction.animation = nil
                            transaction.disablesAnimations = true
                        }
                }
            }
        }
    }

    private var title: some View {
        Text(chat.title)
            .padding(.vertical, 3)
            .padding(.horizontal, 10)
            .background {
                Capsule()
                    .fill(Color.clear)
            }
            .glassEffect(isVertical ? .identity : .regular.interactive())
            .offset(y: -10)
            .onTapGesture {
                onTap?()
            }
    }

    private var displayParticipants: [User] {
        chat.participants.filter { $0.id != chatData.currentUser.id }
    }

    private var avatarBase: some View {
        GreedyCircleStack(
            spacing: 3,
            rimPadding: 3,
            isVertical: isVertical,
            verticalSpacing: 20,
            verticalDiameter: 44
        ) {
            ForEach(displayParticipants) { participant in
                AvatarView(
                    user: participant,
                    namespace: avatarNamespace,
                    matchedGeometryID: chat.avatarGeometryKey(for: participant),
                    isGeometrySource: isGeometrySource,
                    matchedGeometryAnimation: matchedGeometryAnimation
                )
                .id(participant.id)
            }
        }
        .glassEffect(isVertical ? .identity : .regular.interactive())
        .frame(width: isVertical ? nil : 60, height: isVertical ? nil : 60)
        .frame(maxWidth: .infinity, maxHeight: isVertical ? .infinity : nil, alignment: isVertical ? .topLeading : .top)
    }

    private var avatarContent: some View {
        avatarBase
            .frame(maxWidth: .infinity, alignment: isVertical ? .leading : .center)
    }
}

#Preview("ChatTitleView Samples") {
    let chatData = ChatData()

    return VStack(spacing: 24) {
        ChatTitleView(chat: .sample(title: "Solo Chat", participantNames: ["Lumen Moss"]))
        ChatTitleView(chat: .sample(title: "Pair Chat", participantNames: ["Maya Park", "River Slate"]))
        ChatTitleView(chat: .sample(title: "Trio Chat", participantNames: ["Maya Park", "River Slate", "Scarlet Chen"]))
        ChatTitleView(chat: .sample(
            title: "Quartet Chat",
            participantNames: ["Maya Park", "River Slate", "Scarlet Chen", "Nate Read"]
        ))
        ChatTitleView(chat: .sample(
            title: "Group Hang",
            participantNames: [
                "Maya Park",
                "River Slate",
                "Scarlet Chen",
                "Nate Read",
                "Eddie Carter",
                "Sage Hart",
                "Carta Bloom",
                "Nova Lin"
            ]
        ))
    }
    .padding()
    .background(Color.base)
    .environment(chatData)
}

#Preview("ChatTitleView Single") {
    @Previewable @State var isVertical = true
    @Previewable @State var chat = Chat.sample(
        title: "Quartet Chat",
        participantNames: ["Maya Park", "River Slate", "Scarlet Chen", "Nate Read"]
    )

    let chatData = ChatData()

    ChatTitleView(
        chat: chat,
        isVertical: isVertical,
        onTap: {
            withAnimation(.smooth(duration: 3)) {
                isVertical.toggle()
            }
        }
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
    .background(Color.base)
    .environment(chatData)
}

private extension Chat {
    static func sample(title: String, participantNames: [String]) -> Chat {
        Chat(
            title: title,
            participants: participantNames.map { name in
                User(id: UUID(), name: name, avatar: name)
            },
            theme: .defaultTheme
        )
    }
}

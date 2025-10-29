//
//  ChatTitleView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/24/25.
//

import SwiftUI

struct ChatTitleView: View {
    let chat: Chat
    var isVertical: Bool
    var onTap: (() -> Void)?
    var avatarNamespace: Namespace.ID?
    var avatarMatchedGeometryId: AnyHashable?
    var isGeometrySource: Bool = true

    private var resolvedAvatarGeometryId: AnyHashable {
        avatarMatchedGeometryId ?? AnyHashable("chat-avatar-\(chat.id)")
    }

    init(
        chat: Chat,
        isVertical: Bool = false,
        onTap: (() -> Void)? = nil,
        avatarNamespace: Namespace.ID? = nil,
        avatarMatchedGeometryId: AnyHashable? = nil,
        isGeometrySource: Bool = true
    ) {
        self.chat = chat
        self.isVertical = isVertical
        self.onTap = onTap
        self.avatarNamespace = avatarNamespace
        self.avatarMatchedGeometryId = avatarMatchedGeometryId
        self.isGeometrySource = isGeometrySource
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

    private var avatarBase: some View {
        GreedyCircleStack(
            isVertical: isVertical,
            verticalSpacing: 20,
            verticalDiameter: 44
        ) {
            ForEach(chat.participants) { participant in
                AvatarView(user: participant, avatarSize: nil)
            }
        }
        .padding(3)
        .background {
            Circle()
                .fill(Color.clear)
        }
        .glassEffect(isVertical ? .identity : .regular.interactive())
        .frame(width: 60, height: 60)
        .frame(maxWidth: .infinity, maxHeight: isVertical ? .infinity : nil, alignment: isVertical ? .topLeading : .top)
    }

    @ViewBuilder
    private var avatarContent: some View {
        Group {
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
        .frame(maxWidth: .infinity, alignment: isVertical ? .leading : .center)
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

#Preview("ChatTitleView Single") {
    @Previewable @State var isVertical = true
    ChatTitleView(
        chat: .sample(title: "Quartet Chat", participantNames: ["Amy", "Ben", "Cara", "Dan"]),
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

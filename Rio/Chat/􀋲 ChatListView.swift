//
//  􀋲 ChatListView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/24/25.
//

import SwiftUI

struct ChatListView: View {
    @Environment(ChatData.self) private var chatData

    var body: some View {
        List(chatData.chats, id: \.id) { chat in
            NavigationLink(destination: ChatView(chat: chat)) {
                ChatRowView(chat: chat)
            }
            .listRowSeparator(.hidden, edges: isFirstChat(chat) ? .top : [])
            .listRowSeparator(.hidden, edges: isLastChat(chat) ? .bottom : [])
        }
        .listStyle(.plain)
        .navigationTitle("Chats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func isFirstChat(_ chat: Chat) -> Bool {
        chatData.chats.first?.id == chat.id
    }

    private func isLastChat(_ chat: Chat) -> Bool {
        chatData.chats.last?.id == chat.id
    }
}

struct ChatRowView: View {
    let chat: Chat

    var body: some View {
        HStack {
            AvatarStackView(chat: chat, isVertical: false)
                .frame(width: 50, height: 50)
                .background {
                    Circle()
                        .fill(chat.theme.outboundBackgroundColor.opacity(0.2))
                }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    if let lastMessage = chat.messages.last {
                        Text(lastMessage.date, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Show last message preview
                if let lastMessage = chat.messages.last {
                    Text(lastMessage.isTypingIndicator ? "typing..." : lastMessage.text)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    @Previewable @State var chatData = ChatData()
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var reactionsCoordinator = ReactionsCoordinator()

    NavigationStack {
        ChatListView()
    }
    .environment(chatData)
    .environment(bubbleConfig)
    .environment(reactionsCoordinator)
}

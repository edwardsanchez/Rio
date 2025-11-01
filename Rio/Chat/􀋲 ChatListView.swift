//
//  􀋲 ChatListView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/24/25.
//

import SwiftUI

struct ChatListView: View {
    @Environment(ChatData.self) private var chatData
    @State private var chatPendingDeletion: Chat?
    @State private var isDeleteAlertPresented = false

    var body: some View {
        List {
            ForEach(chatData.chats, id: \.id) { chat in
                NavigationLink(destination: ChatView(chat: chat)) {
                    ChatRowView(chat: chat)
                }
                .listRowSeparator(.hidden, edges: isFirstChat(chat) ? .top : [])
                .listRowSeparator(.hidden, edges: isLastChat(chat) ? .bottom : [])
                .contextMenu {
                    Button(role: .destructive) {
                        chatPendingDeletion = chat
                        isDeleteAlertPresented = true
                    } label: {
                        Label(
                            isGroupChat(chat) ? "Leave Group" : "Delete Chat",
                            systemImage: "xmark"
                        )
                    }
                }
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    chatPendingDeletion = chatData.chats[index]
                    isDeleteAlertPresented = true
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            //Leave commented out for now
//            ToolbarItem(placement: .topBarTrailing) {
//                EditButton()
//            }
            ToolbarItem(placement: .topBarLeading) {
                Button("New", systemImage: "square.and.pencil") {
                    //TODO: Implement New Chat
                }
            }
        }
        .chatDeletionAlert(
            isPresented: $isDeleteAlertPresented,
            chat: chatPendingDeletion,
            currentUser: chatData.currentUser
        ) { chat in
            chatData.removeChat(withId: chat.id)
            chatPendingDeletion = nil
        }
    }

    private func isGroupChat(_ chat: Chat) -> Bool {
        chat.participants.count > 2
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

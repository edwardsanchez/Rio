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
        Group {
            if chatData.chats.isEmpty {
                VStack {
                    Spacer()
                    Text("Looking a little sad in here!")
                        .font(.title)
                        .foregroundStyle(.tertiary)

//                    Button(action: {
//
//                    }, label: {
//                        Label("New Chat", systemImage: "square.and.pencil")
//                            .padding(.horizontal, 10)
//                            .font(.title3)
//                    })
//                    .padding(10)
//                    .buttonStyle(.glass)
                    Spacer()
                    Image(.mouth)
                        .resizable()
                        .renderingMode(.template)
                        .aspectRatio(contentMode: .fit)
                        .flip(.vertical)
                        .padding(.horizontal, 60)
                        .padding(.bottom, 40)
                        .foregroundStyle(.tertiary)
                }
            } else {
                List {
                    ForEach(chatData.chats, id: \.id) { chat in
                        ZStack {
                            //Invisible Navigation to hide chevron
                            NavigationLink(destination: ChatView(chat: chat)) {
                                EmptyView()
                            }
                            .opacity(0)

                            ChatRowView(chat: chat)
                        }
                        .listRowSeparator(.hidden, edges: isFirstChat(chat) ? .top : [])
                        .listRowSeparator(.hidden, edges: isLastChat(chat) ? .bottom : [])
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                toggleReadStatus(for: chat)
                            } label: {
                                Label(hasUnreadMessages(chat) ? "Mark Read" : "Mark Unread", image: hasUnreadMessages(chat) ? .messageFill : .messageBadgeFilledFill)
                            }
                            .tint(.blue)

                            Button {
                                toggleAlerts(for: chat)
                            } label: {
                                Label(
                                    isChatMuted(chat) ? "Show Alerts" : "Hide Alerts",
                                    systemImage: isChatMuted(chat) ? "bell.fill" : "bell.slash.fill"
                                )
                            }
                            .tint(.indigo)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                chatPendingDeletion = chat
                                isDeleteAlertPresented = true
                            } label: {
                                Label(
                                    isGroupChat(chat) ? "Leave" : "Delete",
                                    systemImage: isGroupChat(chat) ? "xmark" : "trash"
                                )
                            }
                        }
                        .contextMenu {
                            Button {
                                toggleReadStatus(for: chat)
                            } label: {
                                Label(hasUnreadMessages(chat) ? "Mark Read" : "Mark Unread", image: hasUnreadMessages(chat) ? .messageFill : .messageBadgeFilledFill)
                            }

                            Button {
                                toggleAlerts(for: chat)
                            } label: {
                                Label(
                                    isChatMuted(chat) ? "Show Alerts" : "Hide Alerts",
                                    systemImage: isChatMuted(chat) ? "bell.fill" : "bell.slash.fill"
                                )
                            }

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
                }
                .listStyle(.plain)

            }
        }
        .navigationTitle("Messages")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
//            chatData.chats = [] //Uncomment for empty view
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("User", systemImage: "person.crop.circle") {
                    //TODO: Implement User Settings
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
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

    private func isChatMuted(_ chat: Chat) -> Bool {
        chatData.isChatMuted(chat.id)
    }

    private func hasUnreadMessages(_ chat: Chat) -> Bool {
        chat.hasUnreadMessages(for: chatData.currentUser)
    }

    private func toggleAlerts(for chat: Chat) {
        let isMuted = isChatMuted(chat)
        chatData.setChatMuted(chat.id, isMuted: !isMuted)
        // TODO: Connect hide alerts toggle to notification preferences
    }

    private func toggleReadStatus(for chat: Chat) {
        if hasUnreadMessages(chat) {
            chatData.markChatAsRead(chat.id)
        } else {
            chatData.markChatAsUnread(chat.id)
        }
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
    @Environment(ChatData.self) private var chatData

    private var isAlertHidden: Bool {
        chatData.isChatMuted(chat.id)
    }

    var body: some View {
        HStack {
            AvatarStackView(chat: chat, isVertical: false)
                .frame(width: 50, height: 50)
                .background {
                    Circle()
                        .fill(chat.theme.outboundBackgroundColor.opacity(0.2))
                }
                .overlay(alignment: .leading) {
                    if chat.hasUnreadMessages(for: chatData.currentUser) {
                        Circle()
                            .fill(chat.theme.outboundBackgroundColor)
                            .frame(width: 10, height: 10)
                            .offset(x: -14)
                            .transition(.scale.animation(.smooth))
                    }
                }
                .padding(.leading, 10)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(chat.title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Spacer()

                    if let lastMessage = chat.messages.last {
                        HStack(spacing: 3) {
                            Image(systemName: isAlertHidden ? "bell.slash.fill" : "bell.fill")
                                .contentTransition(.symbolEffect(.replace))
                                .opacity(isAlertHidden ? 1 : 0)

                            Text(lastMessage.date, style: .time)
                            Image(systemName: "chevron.right")
                                .padding(.leading, 4)
                                .fontWeight(.medium)
                        }
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

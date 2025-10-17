//
//  ChatListView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/24/25.
//

import SwiftUI

struct ChatListView: View {
    @Environment(ChatData.self) private var chatData

    var body: some View {
        List(chatData.chats) { chat in
            NavigationLink(destination: ChatDetailView(chat: chat)) {
                ChatRowView(chat: chat)
            }
        }
        .navigationTitle("Chats")
    }
}

struct ChatRowView: View {
    let chat: Chat
    
    var body: some View {
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
            
            HStack {
                // Show participant count
                Text("\(chat.participants.count) participants")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
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
    NavigationStack {
        ChatListView()
    }
    .environment(ChatData())
    .environment(BubbleConfiguration())
}

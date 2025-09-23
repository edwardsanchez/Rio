//
//  ContentView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/19/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @State private var message: String = ""
    
    // Define users
    private let edwardUser = User(id: UUID(), name: "Edward", avatar: nil)
    private let victorUser = User(id: UUID(), name: "Victor", avatar: .usersample)
    
    @State private var messages: [Message] = []
    @State private var newMessageId: UUID? = nil
    @State private var inputFieldFrame: CGRect = .zero
    @State private var scrollViewFrame: CGRect = .zero
    
    @FocusState private var isMessageFieldFocused: Bool
    
    init() {
        // Initialize with sample messages using the same user instances
        _messages = State(initialValue: [
            Message(text: "Hi Rio!\nHow are you doing today?", user: victorUser),
            Message(text: "Are you good?", user: victorUser),
            Message(text: "Hey!\nI'm doing well, thanks for asking!", user: edwardUser)
        ])
    }
    
    var body: some View {
        ScrollView {
            MessageListView(
                messages: messages,
                newMessageId: $newMessageId,
                inputFieldFrame: inputFieldFrame,
                scrollViewFrame: scrollViewFrame
            )
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { newValue in
                scrollViewFrame = newValue
            }
        }
        .contentMargins(20)
        .overlay(alignment: .bottom) {
            HStack {
                TextField("Message", text: $message)
                    .frame(maxWidth: .infinity)
                    .padding(15)
                    .background {
                        Color.clear
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .global)
                            } action: { newValue in
                                inputFieldFrame = newValue
                            }
                    }
                    .glassEffect(.clear.interactive())
                    .focused($isMessageFieldFocused)
                    .overlay(alignment: .trailing) {
                        Button {
                            let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmedMessage.isEmpty else { return }
                            let newMessage = Message(text: trimmedMessage, user: edwardUser)
                            newMessageId = newMessage.id
                            messages.append(newMessage)
                            message = ""
                            isMessageFieldFocused = true
                        } label: {
                            Image(systemName: "arrow.up")
                                .padding(4)
                                .fontWeight(.bold)
                        }
                        .buttonBorderShape(.circle)
                        .buttonStyle(.borderedProminent)
                        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                
            }
            .padding(.horizontal, 30)
        }
        .onAppear {
            isMessageFieldFocused = true
        }
        .background {
            Color.base
                .ignoresSafeArea()
        }
        .overlay {
            Rectangle()
                .fill(Gradient(colors: [.white, .black]))
                .ignoresSafeArea()
                .opacity(0.2)
                .blendMode(.overlay)
        }
    }

}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

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

    // Use 5 seconds for testing, change to 300 (5 minutes) for production
    private let tailContinuationThreshold: TimeInterval = 5
    @FocusState private var isMessageFieldFocused: Bool

    init() {
        // Initialize with sample messages
        let victor = User(id: UUID(), name: "Victor", avatar: .usersample)
        let edward = User(id: UUID(), name: "Edward", avatar: nil)

        _messages = State(initialValue: [
            Message(text: "Hi Rio!\nHow are you doing today?", user: victor, showTail: false),
            Message(text: "Are you good?", user: victor),
            Message(text: "Hey!\nI'm doing well, thanks for asking!", user: edward)
        ])
    }

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                }
            }
            .contentMargins(20)
            HStack {
                TextField("Message", text: $message)
                    .frame(maxWidth: .infinity)
                    .padding(15)
                    .glassEffect(.clear.interactive())
                    .focused($isMessageFieldFocused)
                    .overlay(alignment: .trailing) {
                        Button {
                            let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmedMessage.isEmpty else { return }
                            messages.append(Message(text: trimmedMessage, user: edwardUser))
                            updateMessageTails()
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
            // Update tails when view appears to handle initial messages
            updateMessageTails()
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

    private func updateMessageTails() {
        guard !messages.isEmpty else { return }

        var updatedMessages = messages
        for index in updatedMessages.indices {
            if index < updatedMessages.count - 1 {
                let current = updatedMessages[index]
                let next = updatedMessages[index + 1]
                let isSameUser = current.user.id == next.user.id
                let timeDifference = next.date.timeIntervalSince(current.date)
                let isWithinThreshold = abs(timeDifference) <= tailContinuationThreshold
                // Hide tail only if same user AND within time threshold
                updatedMessages[index].showTail = !(isSameUser && isWithinThreshold)
            } else {
                // Last message always shows tail
                updatedMessages[index].showTail = true
            }
        }

        messages = updatedMessages
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

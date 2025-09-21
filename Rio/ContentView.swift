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

    @FocusState private var isMessageFieldFocused: Bool

    init() {
        // Initialize with sample messages
        let victor = User(id: UUID(), name: "Victor", avatar: .usersample)
        let edward = User(id: UUID(), name: "Edward", avatar: nil)

        _messages = State(initialValue: [
            Message(text: "Hi Rio!\nHow are you doing today?", user: victor),
            Message(text: "Are you good?", user: victor),
            Message(text: "Hey!\nI'm doing well, thanks for asking!", user: edward)
        ])
    }

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        MessageBubble(
                            message: message,
                            showTail: shouldShowTail(at: index)
                        )
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

    private func shouldShowTail(at index: Int) -> Bool {
        let tailContinuationThreshold: TimeInterval = 5
        guard index < messages.count - 1 else {
            // Last message always shows tail
            return true
        }

        let current = messages[index]
        let next = messages[index + 1]
        let isSameUser = current.user.id == next.user.id
        let timeDifference = next.date.timeIntervalSince(current.date)
        let isWithinThreshold = abs(timeDifference) <= tailContinuationThreshold

        // Show tail if NOT (same user AND within threshold)
        return !(isSameUser && isWithinThreshold)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

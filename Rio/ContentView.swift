//
//  ContentView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/19/25.
//

import SwiftUI
import SwiftData

struct DateHeaderView: View {
    var date: Date

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }

    var body: some View {
        Text(dateFormatter.string(from: date))
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

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
        // Initialize with sample messages using the same user instances
        _messages = State(initialValue: [
            Message(text: "Hi Rio!\nHow are you doing today?", user: victorUser),
            Message(text: "Are you good?", user: victorUser),
            Message(text: "Hey!\nI'm doing well, thanks for asking!", user: edwardUser)
        ])
    }

    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 5) {
                    ForEach(0..<messages.count, id: \.self) { index in
                        VStack(spacing: 5) {
                            if shouldShowDateHeader(at: index) {
                                DateHeaderView(date: messages[index].date)
                                    .padding(.vertical, 5)
                            }
                            MessageBubble(
                                message: messages[index],
                                showTail: shouldShowTail(at: index)
                            )
                        }
                    }
                }
            }
            .contentMargins(20)
            HStack {
                TextField("Message", text: $message)
                    .frame(maxWidth: .infinity)
                    .padding(15)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
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
        let current = messages[index]

        // Check if this is the last message overall
        let isLastMessage = index == messages.count - 1

        print("=== Tail Check for index \(index) ===")
        print("Message: '\(current.text.prefix(20))...' by \(current.user.name)")
        print("Is last message: \(isLastMessage)")
        print("Is inbound: \(current.isInbound)")

        if isLastMessage {
            // Last message always shows tail
            print("Result: TRUE (last message)")
            return true
        }

        let next = messages[index + 1]
        let isNextSameUser = current.user.id == next.user.id
        print("Next message by: \(next.user.name)")
        print("Is next same user: \(isNextSameUser)")

        // For outbound messages (from Edward), only show tail if it's the last in a sequence
        if !current.isInbound {
            // Only show tail if the next message is from a different user (end of outbound sequence)
            let result = !isNextSameUser
            print("Result: \(result) (outbound logic - show tail only if next is different user)")
            return result
        }

        // For inbound messages, keep the existing logic with time threshold
        let timeDifference = next.date.timeIntervalSince(current.date)
        let isWithinThreshold = abs(timeDifference) <= tailContinuationThreshold
        print("Time difference to next: \(timeDifference) seconds")
        print("Is within threshold: \(isWithinThreshold)")

        // Show tail if next message is from different user OR if time gap is too large
        let result = !isNextSameUser || !isWithinThreshold
        print("Result: \(result) (inbound logic)")
        return result
    }

    private func shouldShowDateHeader(at index: Int) -> Bool {
        guard index > 0 else {
            // Always show date header for the first message
            return true
        }
        
        // Use 5 seconds for testing, change to 3600 (1 hour) for production
        let dateHeaderThreshold: TimeInterval = 3600

        let current = messages[index]
        let previous = messages[index - 1]
        let timeDifference = current.date.timeIntervalSince(previous.date)

        // Show date header if messages are more than threshold apart
        return abs(timeDifference) > dateHeaderThreshold
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

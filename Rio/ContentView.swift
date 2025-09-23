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
            VStack(spacing: 5) {
                ForEach(messages) { message in
                    let index = messages.firstIndex(where: { $0.id == message.id }) ?? 0
                    let isNew = message.id == newMessageId
                    
                    VStack(spacing: 5) {
                        if shouldShowDateHeader(at: index) {
                            DateHeaderView(date: message.date)
                                .padding(.vertical, 5)
                        }
                        
                        if message.isInbound {
                            // Inbound messages: simple slide from bottom
                            MessageBubble(
                                message: message,
                                showTail: shouldShowTail(at: index),
                                width: nil,
                                height: nil,
                            )
                            .offset(y: isNew ? 50 : 0)
                            .opacity(isNew ? 0 : 1)
                            .animation(.spring(response: 1.5, dampingFraction: 0.8), value: isNew)
                            .onAppear {
                                if isNew {
                                    withAnimation(.spring(response: 1.5, dampingFraction: 0.8)) {
                                        newMessageId = nil
                                    }
                                }
                            }
                        } else {
                            // Outbound messages: animate from input field position
                            HStack {
                                Spacer()
                                    .frame(width: !isNew ? 0 : nil)

                                MessageBubble(
                                    message: message,
                                    showTail: shouldShowTail(at: index),
                                    width: isNew ? inputFieldFrame.width : nil,
                                    height: isNew ? inputFieldFrame.height : nil
                                )
                                .offset(
                                    y: isNew ? calculateYOffset() : 0
                                )
                            }
                            .onAppear {
                                if isNew {
                                    withAnimation(.smooth(duration: 1)) {
                                        newMessageId = nil
                                    }
                                }
                            }
                        }
                    }
                }
            }
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
    
    private func shouldShowTail(at index: Int) -> Bool {
        let tailContinuationThreshold: TimeInterval = 300
        let current = messages[index]
        
        // Check if this is the last message overall
        let isLastMessage = index == messages.count - 1
        
        if isLastMessage {
            // Last message always shows tail
            return true
        }
        
        let next = messages[index + 1]
        let isNextSameUser = current.user.id == next.user.id
        
        // For outbound messages (from Edward), only show tail if it's the last in a sequence
        if !current.isInbound {
            // Only show tail if the next message is from a different user (end of outbound sequence)
            return !isNextSameUser
        }
        
        // For inbound messages, keep the existing logic with time threshold
        let timeDifference = next.date.timeIntervalSince(current.date)
        let isWithinThreshold = abs(timeDifference) <= tailContinuationThreshold
        
        // Show tail if next message is from different user OR if time gap is too large
        return !isNextSameUser || !isWithinThreshold
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
    
    private func calculateYOffset() -> CGFloat {
        // Calculate the vertical distance from the input field to where the message should appear
        let inputFieldBottom = inputFieldFrame.maxY
        let scrollViewBottom = scrollViewFrame.maxY
        
        // The message needs to move from the input field position up to its place in the scroll view
        // This is a rough approximation - you might need to fine-tune this value
        return max(0, inputFieldBottom - scrollViewBottom + 50)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

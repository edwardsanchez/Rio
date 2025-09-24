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
    @State private var scrollPosition = ScrollPosition()

    // Timer for automated inbound message
    @State private var autoReplyTimer: Timer? = nil

    @FocusState private var isMessageFieldFocused: Bool

    // Track if user is manually scrolling to avoid interrupting
    @State private var isUserScrolling = false
    
    init() {
        // Initialize with sample messages using the same user instances
        _messages = State(initialValue: [
            Message(text: "Hi Rio!\nHow are you doing today?", user: victorUser),
            Message(text: "Are you good?", user: victorUser),
            Message(text: "Hey!\nI'm doing well, thanks for asking!", user: edwardUser),
            Message(text: "This is a very long message that should demonstrate text wrapping behavior in the chat bubble. It contains enough text to exceed the normal width of a single line and should wrap nicely within the bubble constraints without stretching horizontally across the entire screen.", user: victorUser)
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
            .onGeometryChange(for: CGRect.self) { geometryProxy in
                geometryProxy.frame(in: .global)
            } action: { newValue in
                scrollViewFrame = newValue
            }
        }
        .scrollPosition($scrollPosition)
        .contentMargins(.horizontal, 20)
        .contentMargins(.bottom, 120)
        .onChange(of: messages.count) { _, _ in
            // Auto-scroll to the latest message when a new message is added
            scrollToLatestMessage()
        }
        .onChange(of: newMessageId) { _, newId in
            if newId != nil {
                // Slight delay to allow message to be added to view hierarchy
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    scrollToLatestMessage()
                }
            }
        }
        .onAppear {
            // Scroll to the bottom when the view first appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scrollToLatestMessage()
            }
            isMessageFieldFocused = true
        }
        .overlay(alignment: .bottom) {
            inputField
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
        .onDisappear {
            autoReplyTimer?.invalidate()
            autoReplyTimer = nil
        }
    }
    
    var inputField: some View {
        HStack {
            TextField("Message", text: $message, axis: .vertical)
                .lineLimit(5)
                .padding(15)
                .background {
                    Color.clear
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .global)
                        } action: { newValue in
                            inputFieldFrame = newValue
                        }
                }
                .glassEffect(.clear.interactive(), in: .containerRelative)
                .focused($isMessageFieldFocused)
                .overlay(alignment: .bottomTrailing) {
                    sendButton
                }
        }
        .padding(.horizontal, 30)
    }
    
    var sendButton: some View {
        Button {
            let newMessage = Message(text: message, user: edwardUser)
            newMessageId = newMessage.id
            messages.append(newMessage)
            message = ""
            isMessageFieldFocused = true
            
            // Reset and restart the auto-reply timer
            resetAutoReplyTimer()
        } label: {
            Image(systemName: "arrow.up")
                .padding(4)
                .fontWeight(.bold)
        }
        .buttonBorderShape(.circle)
        .buttonStyle(.borderedProminent)
        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .padding(.bottom, 5)
    }

    // MARK: - Scrolling

    private func scrollToLatestMessage() {
        guard let lastMessage = messages.last else { return }

        withAnimation(.smooth) {
            scrollPosition.scrollTo(id: lastMessage.id, anchor: .bottom)
        }
    }

    // MARK: - Timer Management

    private func resetAutoReplyTimer() {
        // Cancel existing timer if any
        autoReplyTimer?.invalidate()

        // Start a new 4-second timer
        autoReplyTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            // Send automated inbound "hi" message
            let inboundMessage = Message(text: "hi", user: victorUser)
            newMessageId = inboundMessage.id
            messages.append(inboundMessage)
        }
    }

}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

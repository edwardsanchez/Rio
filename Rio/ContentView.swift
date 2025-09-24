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
    @State private var inputFieldHeight: CGFloat = 50 // Track input field height for dynamic spacing
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
        VStack(spacing: 0) {
            // Main scroll view for messages
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
            .scrollClipDisabled()
        .scrollPosition($scrollPosition)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .contentMargins(.bottom, 10)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Gradient(colors: [.base.opacity(0), .base.opacity(1)]))
                    .ignoresSafeArea()
                    .frame(height: 170)
                    .offset(y: 120)
            }
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
            .onChange(of: inputFieldHeight) { _, _ in
                // Auto-scroll when input field height changes to keep latest message visible
                // Use instant scroll to avoid competing animations
                scrollToLatestMessageInstant()
            }
        .onAppear {
            // Scroll to the bottom when the view first appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                scrollToLatestMessage()
            }
            isMessageFieldFocused = true
        }

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
    
    @State private var keyboardIsUp = false
    
    var inputField: some View {
        HStack {
            TextField("Message", text: $message, axis: .vertical)
                .lineLimit(1...5) // Allow 1 to 5 lines
                .padding(15)
                .background {
                    Color.clear
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .global)
                        } action: { newValue in
                            inputFieldFrame = newValue
                            // Update input field height for dynamic spacing
                            inputFieldHeight = newValue.height
                        }
                }
                .glassEffect(.clear.tint(.white.opacity(0.5)).interactive(), in: .containerRelative)
                .focused($isMessageFieldFocused)
                .overlay(alignment: .bottomTrailing) {
                    sendButton
                }
        }
        .padding(.horizontal, 30)
        .padding(.top, 15)
        .background(alignment: .bottom) {
            Rectangle()
                .fill(Gradient(colors: [.base.opacity(0), .base.opacity(1)]))
                .ignoresSafeArea()
                .frame(height: 170)
                .offset(y: 120)
        }
        .safeAreaPadding(.bottom, keyboardIsUp ? nil : 0)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.smooth(duration: 0.2), value: inputFieldHeight)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation {
                    keyboardIsUp = keyboardFrame.height > 0
                }
            }
        }
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

        withAnimation(.smooth(duration: 0.3)) {
            scrollPosition.scrollTo(id: lastMessage.id, anchor: .bottom)
        }
    }

    private func scrollToLatestMessageInstant() {
        guard let lastMessage = messages.last else { return }

        // Instant scroll without animation for input field height changes
        scrollPosition.scrollTo(id: lastMessage.id, anchor: .bottom)
    }

    // MARK: - Timer Management

    private func resetAutoReplyTimer() {
        // Cancel existing timer if any
        autoReplyTimer?.invalidate()

        // Start a new 4-second timer
        autoReplyTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            // Array of random responses
            let randomResponses = [
                "That's a very good point!",
                "Oh yeah!",
                "I don't know.",
                "I disagree tbh.",
                "Erm, sure!",
                "You think?",
                "Never!",
                "That's cool!"
            ]

            // Pick a random response
            let randomResponse = randomResponses.randomElement() ?? "hi"

            // Send automated inbound message with random response
            let inboundMessage = Message(text: randomResponse, user: victorUser)
            newMessageId = inboundMessage.id
            messages.append(inboundMessage)
        }
    }

}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

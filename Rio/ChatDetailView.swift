//
//  ChatDetailView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/24/25.
//

import SwiftUI

struct ChatDetailView: View {
    let chat: Chat
    let chatData: ChatData
    
    @State private var message: String = ""
    @State private var messages: [Message] = []
    @State private var newMessageId: UUID? = nil
    @State private var inputFieldFrame: CGRect = .zero
    @State private var scrollViewFrame: CGRect = .zero
    @State private var inputFieldHeight: CGFloat = 50 // Track input field height for dynamic spacing
    @State private var scrollPosition = ScrollPosition()
    @FocusState private var isMessageFieldFocused: Bool

    // Timer for automated inbound message
    @State private var autoReplyTimer: Timer? = nil

    // Track inbound response state to prevent multiple simultaneous responses
    @State private var isInboundResponsePending = false
    @State private var currentTypingIndicatorId: UUID? = nil

    // Control whether the system should auto-reply with messages
    @State private var shouldAutoReply = true

    // Track keyboard state
    @State private var keyboardIsUp = false

    // Track if user is manually scrolling to avoid interrupting
    @State private var isUserScrolling = false
    
    // Array of random responses
    private let autoReplyMessages = [
        "That's a very good point!",
        "Oh yeah!",
        "I don't know.",
        "I disagree tbh.",
        "Erm, sure!",
        "You think?",
        "Never!",
        "That's cool!"
    ]
    
    init(chat: Chat, chatData: ChatData) {
        self.chat = chat
        self.chatData = chatData
        _messages = State(initialValue: chat.messages)
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
        .navigationTitle(chat.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    shouldAutoReply.toggle()
                    // If auto-reply is disabled, clean up any pending auto-reply state
                    if !shouldAutoReply {
                        cleanupAutoReplyState()
                    }
                } label: {
                    Image(systemName: shouldAutoReply ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                        .foregroundColor(shouldAutoReply ? .blue : .gray)
                }
                .accessibilityLabel(shouldAutoReply ? "Auto-reply enabled" : "Auto-reply disabled")
                .accessibilityHint("Tap to toggle automatic message responses")
            }
        }
        .onDisappear {
            autoReplyTimer?.invalidate()
            autoReplyTimer = nil
            isInboundResponsePending = false
            currentTypingIndicatorId = nil
        }
    }
    var inputField: some View {
        HStack {
            HStack(alignment: .bottom) {
                TextField("Message", text: $message, axis: .vertical)
                    .lineLimit(1...5) // Allow 1 to 5 lines
                    .padding([.vertical, .leading], 15)
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
                    .focused($isMessageFieldFocused)
                    .onSubmit {
                        sendMessage()
                    }
                    .submitLabel(.send)

                sendButton
                    .padding(.bottom, 5)
            }
            .glassEffect(.clear.tint(.white.opacity(0.5)).interactive(), in: .rect(cornerRadius: 25))
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation {
                keyboardIsUp = false
            }
        }
        .background {
            Rectangle()
                .fill(Gradient(colors: [.base.opacity(0), .base.opacity(1)]))
                .ignoresSafeArea()
                .frame(height: 100)
                .offset(y: 30)
        }
    }
    
    var isEmpty: Bool {
        message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var sendButton: some View { //TODO: Toby: Reduce button size
        Button {
            sendMessage()
        } label: {
            Image(systemName: "arrow.up")
                .padding(5)
                .fontWeight(.bold)
        }
        .buttonBorderShape(.circle)
        .buttonStyle(.borderedProminent)
        .opacity(isEmpty ? 0 : 1)
        .scaleEffect(isEmpty ? 0.9  : 1)
        .animation(.smooth(duration: 0.2), value: isEmpty)
    }

    // MARK: - Message Sending

    private func sendMessage() {
        // Capture the message text before clearing to avoid race conditions
        let messageText = message.trimmingCharacters(in: .whitespacesAndNewlines)

        // Guard against empty messages
        guard !messageText.isEmpty else { return }

        // Clear the text field immediately to provide instant feedback
        message = ""

        // Check if there's an existing typing indicator that needs to be moved to the end
        var typingIndicatorToMove: Message? = nil
        if let typingIndicatorId = currentTypingIndicatorId,
           let typingIndex = messages.firstIndex(where: { $0.id == typingIndicatorId }) {
            // Store the typing indicator and remove it temporarily
            typingIndicatorToMove = messages[typingIndex]
            messages.remove(at: typingIndex)

            // Also remove from chatData
            if let chatIndex = chatData.chats.firstIndex(where: { $0.id == chat.id }) {
                var updatedChat = chatData.chats[chatIndex]
                var updatedMessages = updatedChat.messages
                if let messageIndex = updatedMessages.firstIndex(where: { $0.id == typingIndicatorId }) {
                    updatedMessages.remove(at: messageIndex)
                    updatedChat = Chat(
                        id: updatedChat.id,
                        title: updatedChat.title,
                        participants: updatedChat.participants,
                        messages: updatedMessages
                    )
                    chatData.chats[chatIndex] = updatedChat
                }
            }
        }

        // Create and send the message
        let newMessage = Message(text: messageText, user: chatData.edwardUser)
        newMessageId = newMessage.id
        messages.append(newMessage)
        chatData.addMessage(newMessage, to: chat.id)

        // Re-add the typing indicator with a new timestamp to make it the last message
        if let typingIndicator = typingIndicatorToMove {
            let updatedTypingIndicator = Message(
                id: typingIndicator.id, // Keep the same ID
                text: typingIndicator.text,
                user: typingIndicator.user,
                date: Date.now, // Update timestamp to current time
                isTypingIndicator: typingIndicator.isTypingIndicator
            )
            messages.append(updatedTypingIndicator)
            chatData.addMessage(updatedTypingIndicator, to: chat.id)
        }

        // Restore focus after a brief delay to ensure text clearing completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isMessageFieldFocused = true
        }

        resetAutoReplyTimer()
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

    private func cleanupAutoReplyState() {
        // Cancel any existing timer
        autoReplyTimer?.invalidate()
        autoReplyTimer = nil

        // Remove any existing typing indicator
        if let typingIndicatorId = currentTypingIndicatorId,
           let typingIndex = messages.firstIndex(where: { $0.id == typingIndicatorId }) {
            messages.remove(at: typingIndex)

            // Also remove from chatData
            if let chatIndex = chatData.chats.firstIndex(where: { $0.id == chat.id }) {
                var updatedChat = chatData.chats[chatIndex]
                var updatedMessages = updatedChat.messages
                if let messageIndex = updatedMessages.firstIndex(where: { $0.id == typingIndicatorId }) {
                    updatedMessages.remove(at: messageIndex)
                    updatedChat = Chat(
                        id: updatedChat.id,
                        title: updatedChat.title,
                        participants: updatedChat.participants,
                        messages: updatedMessages
                    )
                    chatData.chats[chatIndex] = updatedChat
                }
            }
        }

        // Reset state variables
        isInboundResponsePending = false
        currentTypingIndicatorId = nil
    }

    private func resetAutoReplyTimer() {
        // If auto-reply is disabled, don't start any auto-reply logic
        guard shouldAutoReply else { return }

        // If an inbound response is already pending, don't start a new one
        guard !isInboundResponsePending else { return }

        // Only start auto-reply if there are other participants
        guard let randomUser = chatData.getRandomParticipantForReply(in: chat) else { return }

        // Mark that an inbound response is now pending
        isInboundResponsePending = true

        // Cancel existing timer if any (but don't remove existing typing indicator)
        autoReplyTimer?.invalidate()

        // Stage 1: Wait 1 second before showing typing indicator
        autoReplyTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            // Only show typing indicator if no typing indicator is currently displayed
            let hasExistingTypingIndicator = messages.contains { $0.isTypingIndicator }

            if !hasExistingTypingIndicator {
                // Stage 2: Show typing indicator for 10 seconds
                let typingIndicatorMessage = Message(
                    text: "", // Text is not used for typing indicator
                    user: randomUser,
                    isTypingIndicator: true
                )
                currentTypingIndicatorId = typingIndicatorMessage.id
                newMessageId = typingIndicatorMessage.id
                messages.append(typingIndicatorMessage)
                chatData.addMessage(typingIndicatorMessage, to: chat.id)
            }

            // Stage 3: After 10 seconds, replace typing indicator with final message
            autoReplyTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
                // Remove any existing typing indicator message
                if let typingIndicatorId = currentTypingIndicatorId,
                   let typingIndex = messages.firstIndex(where: { $0.id == typingIndicatorId }) {
                    messages.remove(at: typingIndex)
                    // Also remove from chatData
                    if let chatIndex = chatData.chats.firstIndex(where: { $0.id == chat.id }) {
                        var updatedChat = chatData.chats[chatIndex]
                        var updatedMessages = updatedChat.messages
                        if let messageIndex = updatedMessages.firstIndex(where: { $0.id == typingIndicatorId }) {
                            updatedMessages.remove(at: messageIndex)
                            updatedChat = Chat(
                                id: updatedChat.id,
                                title: updatedChat.title,
                                participants: updatedChat.participants,
                                messages: updatedMessages
                            )
                            chatData.chats[chatIndex] = updatedChat
                        }
                    }
                }

                // Pick a random response and add final message
                let randomResponse = autoReplyMessages.randomElement() ?? "Hello!"
                let finalMessage = Message(text: randomResponse, user: randomUser)
                newMessageId = finalMessage.id
                messages.append(finalMessage)
                chatData.addMessage(finalMessage, to: chat.id)

                // Clear the pending state and typing indicator ID
                isInboundResponsePending = false
                currentTypingIndicatorId = nil
            }
        }
    }
}

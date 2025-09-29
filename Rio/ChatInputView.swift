//
//  ChatInputView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/27/25.
//

import SwiftUI

struct ChatInputView: View {
    @State private var message: String = ""
    @FocusState private var isMessageFieldFocused: Bool
    @Binding var inputFieldFrame: CGRect
    @State private var keyboardIsUp = false
    @Binding var shouldFocusInput: Bool

    // Chat data
    @Binding var messages: [Message]
    @Binding var newMessageId: UUID?
    let chat: Chat
    @Environment(ChatData.self) private var chatData
    @Binding var autoReplyEnabled: Bool

    // Timer for automated inbound message
    @State private var autoReplyTimer: Timer? = nil

    // Track inbound response state to prevent multiple simultaneous responses
    @State private var isInboundResponsePending = false
    @State private var currentTypingIndicatorId: UUID? = nil

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
    
    var body: some View {
        inputField
            .onChange(of: shouldFocusInput) { _, newValue in
                if newValue {
                    isMessageFieldFocused = true
                    shouldFocusInput = false
                }
            }
            .onAppear {
                shouldFocusInput = true
            }
            .onDisappear {
                autoReplyTimer?.invalidate()
                autoReplyTimer = nil
                isInboundResponsePending = false
                currentTypingIndicatorId = nil
            }
    }
    
    var inputField: some View {
        GlassEffectContainer {
            HStack(spacing: 2) {
                Button {
                    
                } label: {
                    Image(systemName: "plus")
                        .imageScale(.large)
                        .padding(9)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)

                HStack(alignment: .bottom) {
                    TextField("Message", text: $message, axis: .vertical)
                        .lineLimit(1...5) // Allow 1 to 5 lines
                        .padding([.vertical, .leading], 15)
                        .focused($isMessageFieldFocused)
                        .onSubmit {
                            sendMessage()
                        }
                        .submitLabel(.send)

                    sendButton
                        .padding(.bottom, 5)
                }
                .glassEffect(.regular.tint(.base.opacity(0.5)).interactive(), in: .rect(cornerRadius: 25))
                .onGeometryChange(for: CGRect.self) { proxy in
                    // Capture the text input field frame (excluding the plus button)
                    // This is after the glass effect and padding are applied
                    proxy.frame(in: .global)
                } action: { newValue in
                    inputFieldFrame = newValue
                    inputFieldFrame.origin.x -= 15
                }
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
        .animation(.smooth(duration: 0.2), value: inputFieldFrame.height)
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
        guard autoReplyEnabled else { return }

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

    func toggleAutoReply() {
        autoReplyEnabled.toggle()
        // If auto-reply is disabled, clean up any pending auto-reply state
        if !autoReplyEnabled {
            cleanupAutoReplyState()
        }
    }
}

#Preview {
    @Previewable @State var inputFieldFrame: CGRect = .zero
    @Previewable @State var inputFieldHeight: CGFloat = 50
    @Previewable @State var messages: [Message] = []
    @Previewable @State var newMessageId: UUID? = nil
    @Previewable @State var shouldFocusInput = false
    @Previewable @State var autoReplyEnabled = true

    let chatData = ChatData()
    let chat = chatData.chats.first!

    return ChatInputView(
        inputFieldFrame: $inputFieldFrame,
        shouldFocusInput: $shouldFocusInput,
        messages: $messages,
        newMessageId: $newMessageId,
        chat: chat,
        autoReplyEnabled: $autoReplyEnabled
    )
    .environment(chatData)
    .background(Color.base)
}

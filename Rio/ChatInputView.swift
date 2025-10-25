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
    @Binding var newMessageId: UUID?
    let chat: Chat
    @Environment(ChatData.self) private var chatData
    @Binding var autoReplyEnabled: Bool
    @Environment(BubbleConfiguration.self) private var bubbleConfig

    // Timer for automated inbound message
    @State private var autoReplyTimer: Timer?

    // Track inbound response state to prevent multiple simultaneous responses
    @State private var isInboundResponsePending = false
    @State private var currentTypingIndicatorId: UUID?
    @State private var readToThinkingTimer: Timer?

    // Array of random responses
    private let autoReplyMessages = [
        "That's a very good point!",
        "Oh yeah!",
        "I don't know.",
        "I disagree tbh.",
        "Erm, sure!",
        "You think?",
        "Never!",
        "That's cool!",
        "👍",
        "😊",
        "🤔💭",
        "🎉🎊🥳"
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
                readToThinkingTimer?.invalidate()
                readToThinkingTimer = nil
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

    private var messages: [Message] {
        chatData.chats.first(where: { $0.id == chat.id })?.messages ?? []
    }

    var sendButton: some View {
        Button {
            sendMessage()
        } label: {
            Image(systemName: "arrow.up")
                .padding(5)
                .fontWeight(.bold)
        }
        .buttonBorderShape(.circle)
        .buttonStyle(.borderedProminent)
        .tint(chat.theme.outboundBackgroundColor)
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
        var typingIndicatorToMove: Message?
        if let typingIndicatorId = currentTypingIndicatorId,
           let chatIndex = chatData.chats.firstIndex(where: { $0.id == chat.id }) {
            var updatedChat = chatData.chats[chatIndex]
            var updatedMessages = updatedChat.messages
            if let typingIndex = updatedMessages.firstIndex(where: { $0.id == typingIndicatorId }) {
                typingIndicatorToMove = updatedMessages[typingIndex]
                updatedMessages.remove(at: typingIndex)
                updatedChat = Chat(
                    id: updatedChat.id,
                    title: updatedChat.title,
                    participants: updatedChat.participants,
                    messages: updatedMessages,
                    theme: updatedChat.theme
                )
                chatData.chats[chatIndex] = updatedChat
            }
        }

        // Parse message content and create message(s)
        let segments = ContentTypeDetector.detectURLs(in: messageText)
        var createdMessages: [Message] = []

        for segment in segments {
            let content: ContentType
            if segment.isURL {
                // Create URL content type
                if let url = URL(string: segment.content) {
                    content = .url(url)
                } else {
                    // Fallback to text if URL creation fails
                    content = .text(segment.content)
                }
            } else {
                // Use content type detector to check for emoji-only (1-3 emoji)
                content = ContentTypeDetector.contentType(for: segment.content)
            }

            let newMessage = Message(
                content: content,
                user: chatData.edwardUser,
                messageType: .outbound
            )
            createdMessages.append(newMessage)
        }

        // Set newMessageId to the first message for animation
        if let firstMessage = createdMessages.first {
            newMessageId = firstMessage.id
        }

        // Add all created messages
        for msg in createdMessages {
            chatData.addMessage(msg, to: chat.id)
        }

        // Re-add the typing indicator with a new timestamp to make it the last message
        if let typingIndicator = typingIndicatorToMove {
            let updatedTypingIndicator = Message(
                id: typingIndicator.id, // Keep the same ID
                content: typingIndicator.content,
                user: typingIndicator.user,
                date: Date.now, // Update timestamp to current time
                isTypingIndicator: typingIndicator.isTypingIndicator,
                replacesTypingIndicator: typingIndicator.replacesTypingIndicator,
                messageType: typingIndicator.messageType
            )
            chatData.addMessage(updatedTypingIndicator, to: chat.id)
            chatData.setTypingIndicator(true, for: typingIndicator.user.id, in: chat.id)
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
        readToThinkingTimer?.invalidate()
        readToThinkingTimer = nil

        // Remove any existing typing indicator
        if let typingIndicatorId = currentTypingIndicatorId,
           let chatIndex = chatData.chats.firstIndex(where: { $0.id == chat.id }) {
            var updatedChat = chatData.chats[chatIndex]
            var updatedMessages = updatedChat.messages
            if let messageIndex = updatedMessages.firstIndex(where: { $0.id == typingIndicatorId }) {
                let typingIndicatorUserId = updatedMessages[messageIndex].user.id
                updatedMessages.remove(at: messageIndex)
                updatedChat = Chat(
                    id: updatedChat.id,
                    title: updatedChat.title,
                    participants: updatedChat.participants,
                    messages: updatedMessages,
                    theme: updatedChat.theme
                )
                chatData.chats[chatIndex] = updatedChat
                chatData.setTypingIndicator(false, for: typingIndicatorUserId, in: chat.id)
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

        // Stage 1: Wait 1 second before showing typing indicator in .read state
        autoReplyTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            // Only show typing indicator if no typing indicator is currently displayed
            let hasExistingTypingIndicator = messages.contains { $0.isTypingIndicator }

            if !hasExistingTypingIndicator {
                // Stage 2: Show typing indicator in .read state
                let typingIndicatorMessage = Message(
                    content: .text(""), // Text is not used for typing indicator
                    user: randomUser,
                    isTypingIndicator: true,
                    messageType: .inbound(.read)
                )
                currentTypingIndicatorId = typingIndicatorMessage.id
                newMessageId = typingIndicatorMessage.id
                chatData.addMessage(typingIndicatorMessage, to: chat.id)
                chatData.setTypingIndicator(true, for: randomUser.id, in: chat.id)

                // Schedule transition from .read to .thinking after 3 seconds
                readToThinkingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
                    if let indicatorId = currentTypingIndicatorId,
                       let currentIndicator = messages.first(where: { $0.id == indicatorId }) {
                        // Only transition if still in .read state
                        if currentIndicator.bubbleType.isRead {
                            let updatedIndicator = Message(
                                id: currentIndicator.id,
                                content: currentIndicator.content,
                                user: currentIndicator.user,
                                date: currentIndicator.date,
                                isTypingIndicator: true,
                                replacesTypingIndicator: false,
                                messageType: .inbound(.thinking)
                            )
                            chatData.updateMessage(updatedIndicator, in: chat.id)
                        }
                    }
                    readToThinkingTimer = nil
                }
            }

            // Stage 3: After 5 more seconds (8 total), replace typing indicator with final message
            autoReplyTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { _ in
                let indicatorWasVisible = chatData.isTypingIndicatorVisible(for: randomUser.id, in: chat.id)

                // Cancel read-to-thinking timer since we're going straight to talking
                readToThinkingTimer?.invalidate()
                readToThinkingTimer = nil

                let randomResponse = autoReplyMessages.randomElement() ?? "Hello!"

                // Detect content type for auto-reply (emoji detection)
                let contentType = ContentTypeDetector.contentType(for: randomResponse)

                if let typingIndicatorId = currentTypingIndicatorId,
                   messages.contains(where: { $0.id == typingIndicatorId }) {
                    let updatedMessage = Message(
                        id: typingIndicatorId,
                        content: contentType,
                        user: randomUser,
                        date: Date.now,
                        isTypingIndicator: false,
                        replacesTypingIndicator: indicatorWasVisible,
                        messageType: .inbound(.talking)
                    )
                    chatData.updateMessage(updatedMessage, in: chat.id)
                    newMessageId = nil
                } else {
                    let fallbackMessage = Message(
                        content: contentType,
                        user: randomUser,
                        replacesTypingIndicator: indicatorWasVisible,
                        messageType: .inbound(.talking)
                    )
                    newMessageId = fallbackMessage.id
                    chatData.addMessage(fallbackMessage, to: chat.id)
                }

                chatData.setTypingIndicator(false, for: randomUser.id, in: chat.id)

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
    @Previewable @State var newMessageId: UUID?
    @Previewable @State var shouldFocusInput = false
    @Previewable @State var autoReplyEnabled = true
    @Previewable @State var bubbleConfig = BubbleConfiguration()

    let chatData = ChatData()
    let chat = chatData.chats.first!

    return ChatInputView(
        inputFieldFrame: $inputFieldFrame,
        shouldFocusInput: $shouldFocusInput,
        newMessageId: $newMessageId,
        chat: chat,
        autoReplyEnabled: $autoReplyEnabled
    )
    .environment(chatData)
    .environment(bubbleConfig)
    .background(Color.base)
}

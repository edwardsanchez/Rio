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
        .onDisappear {
            autoReplyTimer?.invalidate()
            autoReplyTimer = nil
        }
    }
    
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
                .glassEffect(.clear.tint(.white.opacity(0.5)).interactive(), in: .rect(cornerRadius: 25))
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
        .background {
            Rectangle()
                .fill(Gradient(colors: [.base.opacity(0), .base.opacity(1)]))
                .ignoresSafeArea()
                .frame(height: 100)
                .offset(y: 30)
        }
    }
    
    var sendButton: some View {
        Button {
            let newMessage = Message(text: message, user: chatData.edwardUser)
            newMessageId = newMessage.id
            messages.append(newMessage)
            chatData.addMessage(newMessage, to: chat.id)
            message = ""
            isMessageFieldFocused = true
            
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

        // Only start auto-reply if there are other participants
        guard let randomUser = chatData.getRandomParticipantForReply(in: chat) else { return }

        // Start a new timer with random interval
        autoReplyTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 2...5), repeats: false) { _ in
            // Pick a random response
            let randomResponse = autoReplyMessages.randomElement() ?? "Hello!"

            // Send automated inbound message with random response
            let inboundMessage = Message(text: randomResponse, user: randomUser)
            newMessageId = inboundMessage.id
            messages.append(inboundMessage)
            chatData.addMessage(inboundMessage, to: chat.id)
        }
    }
}

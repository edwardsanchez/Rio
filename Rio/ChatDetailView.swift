//
//  ChatDetailView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/24/25.
//

import SwiftUI

struct ChatDetailView: View {
    let chat: Chat
    @Environment(ChatData.self) private var chatData

    @State private var messages: [Message] = []
    @State private var newMessageId: UUID? = nil
    @State private var inputFieldFrame: CGRect = .zero
    @State private var scrollViewFrame: CGRect = .zero
    @State private var scrollPosition = ScrollPosition()

    // Track if user is manually scrolling to avoid interrupting
    @State private var isUserScrolling = false

    // Trigger for setting focus on the input field
    @State private var shouldFocusInput = false

    // Auto-reply state for toolbar
    @State private var autoReplyEnabled = true

    // Physics-based parallax effect state
    @State private var scrollVelocity: CGFloat = 0
    @State private var previousScrollY: CGFloat = 0

    init(chat: Chat) {
        self.chat = chat
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
                    scrollViewFrame: scrollViewFrame,
                    scrollVelocity: scrollVelocity
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
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { oldValue, newValue in
                let currentY = newValue
                let velocity = currentY - previousScrollY

                // Apply smoothing to prevent jittery movement
                withAnimation(.smooth(duration: 0.1)) {
                    scrollVelocity = velocity
                }

                previousScrollY = currentY
            }
            .onScrollPhaseChange { oldPhase, newPhase in
                // When scrolling stops, smoothly return to neutral position
                if newPhase == .idle {
                    withAnimation(.smooth(duration: 0.8)) {
                        scrollVelocity = 0
                    }
                }
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
            .onChange(of: inputFieldFrame.height) { _, _ in
                // Auto-scroll when input field height changes to keep latest message visible
                // Use instant scroll to avoid competing animations
                scrollToLatestMessageInstant()
            }
            .onAppear {
                // Scroll to the bottom when the view first appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToLatestMessage()
                }
                shouldFocusInput = true
            }

            ChatInputView(
                inputFieldFrame: $inputFieldFrame,
                shouldFocusInput: $shouldFocusInput,
                messages: $messages,
                newMessageId: $newMessageId,
                chat: chat,
                autoReplyEnabled: $autoReplyEnabled
            )
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
                    autoReplyEnabled.toggle()
                } label: {
                    Image(systemName: autoReplyEnabled ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                        .foregroundColor(autoReplyEnabled ? .accentColor : .gray)
                }
            }
        }
        .coordinateSpace(name: "field")
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


}

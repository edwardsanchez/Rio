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

    @State private var newMessageId: UUID?
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
    @State private var scrollPhase: ScrollPhase = .idle

    // Image zoom transition
    @State private var selectedImageData: ImageData?

    init(chat: Chat) {
        self.chat = chat
    }

    private var currentChat: Chat? {
        chatData.chats.first(where: { $0.id == chat.id })
    }

    private var messages: [Message] {
        currentChat?.messages ?? []
    }

    var body: some View {
        ZStack {
            messagesView
            inputFieldView
            imageOverlay
        }
        .tint(chat.theme.outboundBackgroundColor)
    }

    var inputFieldView: some View {
        Color.clear
            .safeAreaInset(edge: .bottom) {
                ChatInputView(
                    inputFieldFrame: $inputFieldFrame,
                    shouldFocusInput: $shouldFocusInput,
                    newMessageId: $newMessageId,
                    chat: chat,
                    autoReplyEnabled: $autoReplyEnabled
                )
            }
    }

    var imageOverlay: some View {
        Group {
            if let imageData = selectedImageData {
                ImageDetailView(
                    imageData: imageData,
                    isPresented: Binding(
                        get: { selectedImageData != nil },
                        set: { newValue in
                            if !newValue {
                                selectedImageData = nil
                            }
                        }
                    )
                )
                .zIndex(1)
            }
        }
    }

    var messagesView: some View {
        // Main scroll view for messages
        NavigationStack {
            ScrollView {
                MessageListView(
                    messages: messages,
                    newMessageId: $newMessageId,
                    inputFieldFrame: inputFieldFrame,
                    scrollViewFrame: scrollViewFrame,
                    scrollVelocity: scrollVelocity,
                    scrollPhase: scrollPhase,
                    theme: chat.theme,
                    selectedImageData: $selectedImageData
                )
                .onGeometryChange(for: CGRect.self) { geometryProxy in
                    geometryProxy.frame(in: .global)
                } action: { newValue in
                    scrollViewFrame = newValue
                }
            }
            .scrollClipDisabled()
            .scrollDisabled(chatData.isChatScrollDisabled)
            .scrollPosition($scrollPosition)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .padding(.bottom, 60)

            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, newValue in
                let currentY = newValue

                // Initialize previousScrollY on first call to prevent bad initial positioning
                if previousScrollY == 0 {
                    previousScrollY = currentY
                    return
                }

                let velocity = currentY - previousScrollY

                // Apply smoothing to prevent jittery movement
                withAnimation(.smooth(duration: 0.4)) {
                    scrollVelocity = velocity
                }

                previousScrollY = currentY
            }
            .onScrollPhaseChange { _, newPhase in
                // Track scroll phase for cascading jelly effect
                scrollPhase = newPhase

                // When scrolling stops, smoothly return to neutral position
                if newPhase == .idle {
                    withAnimation(.smooth(duration: 0.2)) {
                        scrollVelocity = 0
                    }
                }
            }
            .onChange(of: messages.last?.id) { _, _ in
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
                // Initialize scroll tracking state
                scrollVelocity = 0
                previousScrollY = 0

                // Scroll to the bottom when the view first appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    scrollToLatestMessage()
                }
                shouldFocusInput = true
            }
            .frame(maxWidth: .infinity)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    titleView
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        autoReplyEnabled.toggle()
                    } label: {
                        Image(systemName: autoReplyEnabled ? "info.circle.fill" : "info.circle")
                            .opacity(autoReplyEnabled ? 1 : 0.3)
                    }
                }
            }
        }
    }

    var titleView: some View {
        GreedyCircleStack {
            ForEach(chat.participants) { participant in
                AvatarView(user: participant, avatarSize: nil)
            }
        }
            .frame(width: 60)
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

#Preview("Chat Detail") {
    let edwardUser = User(id: UUID(), name: "Edward", avatar: .edward)
    let mayaUser = User(id: UUID(), name: "Maya", avatar: .edward)
    let sophiaUser = User(id: UUID(), name: "Sophia", avatar: .scarlet)

    let sampleMessages = [
        Message(content: .text("Hi Rio!\nHow are you doing today?"), user: mayaUser, date: Date().addingTimeInterval(-7200), messageType: .inbound(.talking)),
        Message(content: .text("Are you good?"), user: mayaUser, date: Date().addingTimeInterval(-7100), messageType: .inbound(.talking)),
        Message(content: .text("Hey!\nI'm doing well, thanks for asking!"), user: edwardUser, date: Date().addingTimeInterval(-7000), messageType: .outbound),
        Message(content: .text("This is a very long message that should demonstrate text wrapping behavior in the chat bubble. It contains enough text to exceed the normal width of a single line and should wrap nicely within the bubble constraints."), user: mayaUser, date: Date().addingTimeInterval(-3600), messageType: .inbound(.talking)),
        Message(content: .text("That looks great!"), user: edwardUser, date: Date().addingTimeInterval(-3500), messageType: .outbound),
        Message(content: .text("Thanks! 😊"), user: sophiaUser, date: Date().addingTimeInterval(-100), messageType: .inbound(.talking)),
        Message(content: .text("You're welcome!"), user: edwardUser, date: Date().addingTimeInterval(-50), messageType: .outbound)
    ]

    let sampleChat = Chat(
        title: "Maya & Sophia",
        participants: [edwardUser, mayaUser, sophiaUser],
        messages: sampleMessages,
        theme: .defaultTheme
    )

    let chatData = ChatData()
    chatData.chats = [sampleChat]

    return ChatDetailView(chat: sampleChat)
        .environment(chatData)
        .environment(BubbleConfiguration())
}

#Preview("Outbound Geometry Match Debug") {
    let edwardUser = User(id: UUID(), name: "Edward", avatar: .edward)
    let mayaUser = User(id: UUID(), name: "Maya", avatar: .edward)

    // Create a message that was just sent with a stable ID
    let newMessageId = UUID()
    let newMessage = Message(
        id: newMessageId,
        content: .text("This is a test message!"),
        user: edwardUser,
        messageType: .outbound
    )

    let previousMessages = [
        Message(content: .text("Hi Rio!\nHow are you doing today?"), user: mayaUser, date: Date().addingTimeInterval(-7200), messageType: .inbound(.talking)),
        Message(content: .text("Hey! I'm doing well, thanks!"), user: edwardUser, date: Date().addingTimeInterval(-7000), messageType: .outbound)
    ]

    let allMessages = previousMessages + [newMessage]

    OutboundGeometryMatchDebugView(messages: allMessages, newMessageId: newMessageId)
        .environment(BubbleConfiguration())
        .environment(ChatData())
}

private struct OutboundGeometryMatchDebugView: View {
    let messages: [Message]
    let newMessageId: UUID

    @State private var inputFieldFrame: CGRect = .zero
    @State private var scrollViewFrame: CGRect = .zero
    @State private var currentNewMessageId: UUID?
    @State private var selectedImageData: ImageData?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Scroll view with messages
                ScrollView {
                    MessageListView(
                        messages: messages,
                        newMessageId: $currentNewMessageId,
                        inputFieldFrame: inputFieldFrame,
                        scrollViewFrame: scrollViewFrame,
                        scrollVelocity: 0,
                        scrollPhase: .idle,
                        theme: .defaultTheme,
                        selectedImageData: $selectedImageData
                    )
                    .onGeometryChange(for: CGRect.self) { geometryProxy in
                        geometryProxy.frame(in: .global)
                    } action: { newValue in
                        scrollViewFrame = newValue
                    }
                }
                .scrollClipDisabled()
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .background(Color.base)

                // Mock input field to show where the message should be aligned
                VStack(spacing: 0) {
                    Text("Mock Input Field (for reference)")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.bottom, 4)

                    HStack(alignment: .bottom) {
                        Text("This is a test message!")
                            .padding([.vertical, .leading], 15)
                            .padding(.trailing, 40)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Color.white.opacity(0.2))
                    .overlay {
                        RoundedRectangle(cornerRadius: 25)
                            .stroke(Color.red, lineWidth: 2)
                    }
                    .cornerRadius(25)
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .global)
                    } action: { newValue in
                        inputFieldFrame = newValue
                        inputFieldFrame.origin.x -= 15
                    }
                    .padding(.horizontal, 30)
                }
                .padding(.bottom, 20)
            }
            .onAppear {
                // Set the message as "new" when the view appears
                currentNewMessageId = newMessageId
            }
        }
    }
}

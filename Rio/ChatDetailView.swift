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

    @State private var reactionsCoordinator = ReactionsCoordinator()
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
    @Namespace private var bubbleNamespace

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
            reactionsOverlay
        }
        .tint(chat.theme.outboundBackgroundColor)
        .environment(reactionsCoordinator)
    }

    var scrimView: some View {
        Rectangle()
            .fill(.base.opacity(0.9))
            .ignoresSafeArea()
            .transition(.asymmetric(insertion: .opacity.animation(.easeIn), removal: .opacity.animation(.easeIn(duration: 0.4).delay(0.5))))
    }

    //This is the overlay that shows a copy of the message bubble that show the reactions animations.
    var reactionsOverlay: some View {
        Group {
            ZStack {
                if reactionsCoordinator.isBackgroundDimmerVisible {
                    scrimView
                        .onTapGesture {
                            reactionsCoordinator.closeActiveMenu()
                        }
                }

                VStack {
                    if let context = reactionsCoordinator.reactingMessage {
                        Spacer()

                        MessageBubbleView(
                            message: context.message,
                            showTail: context.showTail,
                            theme: context.theme,
                            bubbleNamespace: bubbleNamespace,
                            activeReactingMessageID: reactionsCoordinator.reactingMessage?.message.id,
                            geometrySource: reactionsCoordinator.geometrySource,
                            isReactionsOverlay: true,
                            selectedImageData: $selectedImageData
                        )
                        .padding(.horizontal, 20)
                        .onAppear {
                            reactionsCoordinator.promoteGeometrySourceToOverlay(for: context.message.id)
                        }
                        .onDisappear {
                            reactionsCoordinator.resetGeometrySourceToList()
                        }
                    }

                    Spacer()

                    if reactionsCoordinator.isBackgroundDimmerVisible {
                        contextMenu
                        .transition(.move(edge: .bottom))
                    } else {
                        contextMenu //Spacer
                            .hidden()
                            .allowsHitTesting(false)
                    }
                }
                .padding(.bottom, 20)
                .ignoresSafeArea()
                .animation(.smooth, value: reactionsCoordinator.isBackgroundDimmerVisible)
            }
        }
    }

    var contextMenu: some View {
        VStack(spacing: 30) {
            //DO NOT DELETE
//            Button(action: {
//
//            }) {
//                Label("Reply", systemImage: "arrowshape.turn.up.left")
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .contentShape(.rect)
//            }

            Button(action: {
                if let message = reactionsCoordinator.reactingMessage?.message {
                    message.copyToClipboard()
                    // Provide haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    // Close the reactions menu
                    reactionsCoordinator.closeActiveMenu()
                }
            }) {
                Label("Copy", systemImage: "document.on.document")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }

            //TODO: Need to implement save for inbound + outbound images and videos

            //TODO: For outbound, need to eventually implement Undo send
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 40)
        .buttonSizing(.flexible)
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: .containerRelative)
        .padding(.top, 60)
        .padding(.horizontal, 20)
        .contentShape(.rect)
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
                    selectedImageData: $selectedImageData,
                    bubbleNamespace: bubbleNamespace,
                    reactionsCoordinator: reactionsCoordinator,
                    geometrySource: reactionsCoordinator.geometrySource
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
                    ChatTitleView(chat: chat, onTap: {
                        tapAvatar()
                    })
                        .padding(.top, 25)
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

    func tapAvatar() {
        //TODO: Make it so tapping it shows people in group and chat settings, ability to kick someone out or invite others
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
    @Previewable @State var chatData = ChatData()
    
    // Use the same users from ChatData to ensure UUID matching
    let edwardUser = chatData.edwardUser
    let mayaUser = chatData.mayaUser
    let sophiaUser = chatData.sophiaUser

    let sampleMessages = [
        Message(content: .text("Hi Rio!\nHow are you doing today?"), from: mayaUser, date: Date().addingTimeInterval(-7200), bubbleType: .talking),
        Message(content: .text("Are you good?"), from: mayaUser, date: Date().addingTimeInterval(-7100), bubbleType: .talking),
        Message(content: .text("Hey!\nI'm doing well, thanks for asking!"), from: edwardUser, date: Date().addingTimeInterval(-7000)),
        Message(content: .text("This is a very long message that should demonstrate text wrapping behavior in the chat bubble. It contains enough text to exceed the normal width of a single line and should wrap nicely within the bubble constraints."), from: mayaUser, date: Date().addingTimeInterval(-3600), bubbleType: .talking),
        Message(content: .text("That looks great!"), from: edwardUser, date: Date().addingTimeInterval(-3500)),
        Message(content: .text("Thanks! 😊"), from: sophiaUser, date: Date().addingTimeInterval(-100), bubbleType: .talking),
        Message(content: .text("You're welcome!"), from: edwardUser, date: Date().addingTimeInterval(-50))
    ]

    let sampleChat = Chat(
        title: "Maya & Sophia",
        participants: [edwardUser, mayaUser, sophiaUser],
        messages: sampleMessages,
        theme: .theme1,
        currentUser: edwardUser
    )

    chatData.chats = [sampleChat]

    return ChatDetailView(chat: sampleChat)
        .environment(chatData)
        .environment(BubbleConfiguration())
}

#Preview("Outbound Geometry Match Debug") {
    let chatData = ChatData()
    let edwardUser = chatData.edwardUser
    let mayaUser = chatData.mayaUser

    // Create a message that was just sent with a stable ID
    let newMessageId = UUID()
    let newMessage = Message(
        id: newMessageId,
        content: .text("This is a test message!"),
        from: edwardUser
    )

    let previousMessages = [
        Message(content: .text("Hi Rio!\nHow are you doing today?"), from: mayaUser, date: Date().addingTimeInterval(-7200), bubbleType: .talking),
        Message(content: .text("Hey! I'm doing well, thanks!"), from: edwardUser, date: Date().addingTimeInterval(-7000))
    ]

    let allMessages = previousMessages + [newMessage]

    OutboundGeometryMatchDebugView(messages: allMessages, newMessageId: newMessageId)
        .environment(BubbleConfiguration())
        .environment(ChatData())
        .environment(ReactionsCoordinator())
}

private struct OutboundGeometryMatchDebugView: View {
    let messages: [Message]
    let newMessageId: UUID

    @State private var inputFieldFrame: CGRect = .zero
    @State private var scrollViewFrame: CGRect = .zero
    @State private var currentNewMessageId: UUID?
    @State private var selectedImageData: ImageData?
    @Environment(ReactionsCoordinator.self) private var reactionsCoordinator
    @Namespace private var bubbleNamespace

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
                        selectedImageData: $selectedImageData,
                        bubbleNamespace: bubbleNamespace,
                        reactionsCoordinator: reactionsCoordinator,
                        geometrySource: reactionsCoordinator.geometrySource
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

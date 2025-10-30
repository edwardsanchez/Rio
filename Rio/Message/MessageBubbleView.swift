//
//  MessageBubbleView.swift
//  Rio
//
//  Created by Edward Sanchez on 9/20/25.
//
//  Text Wrapping Approach:
//  The chat bubble layout uses a combination of techniques to ensure long messages
//  wrap properly instead of stretching horizontally:
//
//  1. Inline Spacer Constraint: A Spacer with minLength: 10 is placed opposite
//     each bubble (after inbound, before outbound). This creates a minimum gap
//     that prevents the bubble from expanding to the full width of the container,
//     forcing text to wrap when it would otherwise exceed the available space.
//
//     Animation Consideration: For outbound messages, the spacer is conditionally
//     applied only when NOT animating (isNew = false). This preserves the proper
//     alignment with the input field during the send animation.
//
//  2. Fixed Size Modifier: The Text view uses .fixedSize(horizontal: false, vertical: true)
//     to prevent horizontal expansion while allowing vertical growth. This ensures
//     the text wraps within the bubble's natural width constraints.
//
//  3. Natural Sizing: The bubble expands naturally based on content up to the
//     constraint imposed by the spacer, avoiding hard-coded max-width values
//     that might not adapt well to different screen sizes.
//

import OSLog
import SwiftUI

struct MessageBubbleView: View {
    @Environment(ChatData.self) private var chatData
    let message: Message
    let showTail: Bool
    let isNew: Bool
    let scrollViewFrame: CGRect
    @Binding var newMessageId: UUID?
    let scrollVelocity: CGFloat
    let scrollPhase: ScrollPhase
    let visibleMessageIndex: Int
    let theme: ChatTheme
    let bubbleNamespace: Namespace.ID?
    let activeReactingMessageID: UUID?
    let geometrySource: ReactionGeometrySource
    let isReactionsOverlay: Bool

    @State private var bubbleManager: MessageBubbleManager
    @State private var thinkingContentWidth: CGFloat = 0
    @Binding var selectedImageData: ImageData?

    @Environment(BubbleConfiguration.self) private var bubbleConfig

    // Computed property for message type
    private var messageType: MessageType {
        message.messageType(currentUser: chatData.currentUser)
    }

    private var isActiveReactionBubble: Bool {
        activeReactingMessageID == message.id
    }

    private var shouldDisplayBubble: Bool {
        guard let activeID = activeReactingMessageID else { return true }
        guard activeID == message.id else { return true }

        if isReactionsOverlay {
            return true
        } else {
            return geometrySource == .list
        }
    }

    private var displayOpacity: Double {
        shouldDisplayBubble ? 1 : 0
    }

    private var allowsInteraction: Bool {
        shouldDisplayBubble && (!isActiveReactionBubble || isReactionsOverlay)
    }

    private var matchedGeometryID: String {
        "bubble-\(message.id)"
    }

    private var isSourceForGeometry: Bool {
        guard let activeID = activeReactingMessageID, activeID == message.id else {
            return geometrySource == .list
        }

        switch geometrySource {
        case .list:
            return !isReactionsOverlay
        case .overlay:
            return isReactionsOverlay
        }
    }

    init(
        message: Message,
        showTail: Bool = true,
        isNew: Bool = false,
        scrollViewFrame: CGRect = .zero,
        newMessageId: Binding<UUID?> = .constant(nil),
        scrollVelocity: CGFloat = 0,
        scrollPhase: ScrollPhase = .idle,
        visibleMessageIndex: Int = 0,
        theme: ChatTheme = .defaultTheme,
        bubbleNamespace: Namespace.ID? = nil,
        activeReactingMessageID: UUID? = nil,
        geometrySource: ReactionGeometrySource = .list,
        isReactionsOverlay: Bool = false,
        selectedImageData: Binding<ImageData?>
    ) {
        self.message = message
        self.showTail = showTail
        self.isNew = isNew
        self.scrollViewFrame = scrollViewFrame
        _newMessageId = newMessageId
        self.scrollVelocity = scrollVelocity
        self.scrollPhase = scrollPhase
        self.visibleMessageIndex = visibleMessageIndex
        self.theme = theme
        self.bubbleNamespace = bubbleNamespace
        self.activeReactingMessageID = activeReactingMessageID
        self.geometrySource = geometrySource
        self.isReactionsOverlay = isReactionsOverlay
        _selectedImageData = selectedImageData
        // Initialize manager with message and config
        _bubbleManager = State(initialValue: MessageBubbleManager(
            message: message,
            config: BubbleConfiguration()
        ))
    }

    var body: some View {
        Group {
            if let namespace = bubbleNamespace {
                decoratedBubbleLayout
                    .matchedGeometryEffect(
                        id: matchedGeometryID,
                        in: namespace,
                        properties: .frame,
                        anchor: .center,
                        isSource: isSourceForGeometry
                    )
            } else {
                decoratedBubbleLayout
            }
        }
    }

    private var decoratedBubbleLayout: some View {
        baseBubbleLayout
            .opacity(displayOpacity)
            .allowsHitTesting(allowsInteraction)
            .animation(.smooth(duration: 0.2), value: shouldDisplayBubble)
    }

    private var baseBubbleLayout: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if messageType.isInbound {
                Group {
                    inboundAvatar
                        .opacity(inboundAvatarOpacity)
                    bubbleView(
                        textColor: theme.inboundTextColor,
                        backgroundColor: theme.inboundBackgroundColor
                    )
                    .opacity(bubbleManager.bubbleFadeOpacity)
                }
                .offset(y: bubbleYOffset)
                // Add spacer with minimum width to force text wrapping
                // This creates a constraint that prevents the bubble from expanding
                // beyond the available width while still allowing natural sizing
                // For inbound messages, always show the spacer since they don't animate from input field
                Spacer(minLength: 10)
            } else {
                // For outbound messages, only show spacer when not animating
                // This preserves the animation alignment with the input field
                if !isNew {
                    // Add spacer with minimum width to force text wrapping
                    // This creates a constraint that prevents the bubble from expanding
                    // beyond the available width while still allowing natural sizing
                    Spacer(minLength: 10)
                }

                bubbleView(
                    textColor: theme.outboundTextColor,
                    backgroundColor: theme.outboundBackgroundColor
                )
                .opacity(bubbleOpacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .offset(y: rowYOffset + parallaxOffset)
        .animation(.interactiveSpring, value: parallaxOffset)
        .animation(.smooth(duration: 0.4), value: rowYOffset)
        .animation(.smooth(duration: 0.4), value: bubbleOpacity)
        .animation(.smooth(duration: 0.4), value: inboundAvatarOpacity)
        .onAppear {
            if isNew {
                withAnimation(.smooth(duration: 0.5)) {
                    newMessageId = nil
                }
            }

            bubbleManager.configureInitialContentState(for: message.bubbleType)
        }
        .onChange(of: message.bubbleType) { oldType, newType in
            bubbleManager.handleBubbleTypeChange(
                from: oldType,
                to: newType,
                hasContent: message.content.hasContent,
                isEmoji: message.content.isEmoji
            )
        }
        .onDisappear {
            bubbleManager.cancelPendingContentTransitions()
        }
    }

    // Computed properties for positioning and animation
    private var frameAlignment: Alignment {
        messageType.isInbound ? .leading : .trailing
    }

    private var rowYOffset: CGFloat {
        guard isNew else { return 0 }

        if messageType.isInbound {
            // Read state should not slide up, only scale avatar
            // Thinking and Talking states slide up from 20px below
            return bubbleManager.displayedBubbleType.isRead ? 0 : 20
        } else {
            return 0
        }
    }

    private var bubbleYOffset: CGFloat {
        guard isNew else { return 0 }
        return 0
    }

    private var bubbleOpacity: Double {
        guard messageType.isInbound else { return 1 }
        // For read state, bubble is always hidden (handled by BubbleView)
        // For thinking/talking, fade in when new
        if bubbleManager.displayedBubbleType.isRead {
            return 1 // Let BubbleView handle opacity
        }

        return isNew ? 0 : 1
    }

    private var inboundAvatarOpacity: Double {
        guard messageType.isInbound else { return 1 }
        guard isNew else { return 1 }
        // For read state, avatar scales from 0, don't use opacity fade
        // For thinking/talking, use opacity fade
        return bubbleManager.displayedBubbleType.isRead ? 1 : 0
    }

    // Physics-based parallax offset for cascading jelly effect
    private var parallaxOffset: CGFloat {
        bubbleConfig.calculateParallaxOffset(
            scrollVelocity: scrollVelocity,
            scrollPhase: scrollPhase,
            visibleMessageIndex: visibleMessageIndex,
            isNewMessage: isNew
        )
    }

    private var inboundAvatar: some View {
        Group {
            if let avatar = message.user.avatar {
                let avatarSize: CGFloat = bubbleManager.displayedBubbleType.isRead ? 20 : 40
                let avatarFrameHeight: CGFloat = bubbleManager.displayedBubbleType.isRead ? 0 : 40
                let avatarOffsetX: CGFloat = bubbleManager.displayedBubbleType.isRead ? 9 : 0

                Image(avatar)
                    .resizable()
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(.circle)
                    .frame(height: avatarFrameHeight)
                    .scaleEffect(isNew && bubbleManager.displayedBubbleType.isRead ? 0 : 1, anchor: .center)
                    .opacity(isNew && bubbleManager.displayedBubbleType.isRead ? 0 : 1)
                    .offset(y: 10)
                    .offset(x: avatarOffsetX)
                    .animation(.bouncy(duration: 0.3), value: isNew)
                    .animation(.bouncy(duration: 0.3), value: bubbleManager.displayedBubbleType)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 40, height: 40)
            }
        }
    }

    // swiftlint:disable unused_declaration
    var typingIndicatorMessages: [String] {
        [
            "Searching for best vegan restaurants in Paris",
            "Looking up reviews",
            "Checking which restaurants are open on Sundays"
        ]
    }

    private var typingIndicatorContainerWidth: CGFloat? {
        guard message.isTypingIndicator else { return nil }
        let scrollWidth = scrollViewFrame.width
        guard scrollWidth > 0 else { return nil }

        let horizontalContentInset: CGFloat = 40 // .contentMargins(.horizontal, 20)
        let avatarWidth: CGFloat = messageType.isInbound ? 40 : 0
        let bubbleSpacing: CGFloat = messageType.isInbound ? 12 : 0
        let trailingSpacer: CGFloat = messageType.isInbound ? 10 : 0

        let width = scrollWidth - horizontalContentInset - avatarWidth - bubbleSpacing - trailingSpacer
        return width > 0 ? width : nil
    }

    // swiftlint:enable unused_declaration

    private func bubbleView(
        textColor: Color,
        backgroundColor: Color
    ) -> some View {
        let hasContent = message.content.hasContent

        return ZStack(alignment: .leading) {
            Text("H") // Measure Spacer
                .opacity(0)

            if hasContent, bubbleManager.includeTalkingTextInLayout {
                MessageContentView(
                    content: message.content,
                    textColor: textColor,
                    messageID: message.id,
                    selectedImageData: $selectedImageData
                )
                .padding(.vertical, 4)
                .opacity(bubbleManager.showTalkingContent ? 1 : 0)
            }
        }
        .animation(.smooth(duration: 0.2), value: bubbleManager.showTypingIndicatorContent)
        .frame(width: bubbleManager.lockedWidth, alignment: .leading)
        //.matchedGeometryEffect(id: -, in: -)
        //This here is the width we want to control with matched geometry when you read the input field.
        //We can use matched geometry, this is not the source.
        .chatBubble(
            messageType: messageType,
            backgroundColor: backgroundColor,
            showTail: showTail,
            messageID: message.id,
            context: ReactingMessageContext(message: message, showTail: showTail, theme: theme),
            isReactionsOverlay: isReactionsOverlay,
            bubbleType: message.bubbleType,
            layoutType: bubbleManager.displayedBubbleType,
            animationWidth: nil,
            animationHeight: nil,
            isVisible: bubbleManager.shouldShowBubbleBackground(for: message.content)
        )
        .overlay(alignment: .leading) {
            TypingIndicatorView(isVisible: bubbleManager.showTypingIndicatorContent)
                .padding(.leading, 20)
        }
    }

    // DO NOT DELETE
    //    private func updateThinkingWidth(_ width: CGFloat) {
    //        guard width > 0 else { return }
    //        if abs(thinkingContentWidth - width) > 0.5 {
    //            thinkingContentWidth = width
    //        }
    //        if message.bubbleType == .thinking {
    //            isWidthLocked = true
    //        }
    //    }
}

private struct MessageBubblePreviewContainer: View {
    @State private var bubbleType: BubbleType? = .read
    @State private var newMessageId: UUID?
    @State private var selectedImageData: ImageData?

    // Use a stable message ID that persists across state changes
    private let messageId = UUID()
    private let sampleUser = User(id: UUID(), name: "Maya Maria Antonia", avatar: .scarlet)

    private var currentMessage: Message {
        switch bubbleType {
        case .read:
            Message(
                id: messageId,
                content: .text(""),
                from: sampleUser,
                isTypingIndicator: true,
                bubbleType: .read
            )
        case .thinking:
            Message(
                id: messageId,
                content: .text(""),
                from: sampleUser,
                isTypingIndicator: true,
                bubbleType: .thinking
            )
        case .talking:
            Message(
                id: messageId,
                content: .text("How are you?"),
                from: sampleUser,
                bubbleType: .talking
            )
        case .none:
            // Placeholder - won't be shown
            Message(
                id: messageId,
                content: .text(""),
                from: sampleUser,
                bubbleType: .talking
            )
        }
    }

    private var isNew: Bool {
        messageId == newMessageId
    }

    var body: some View {
        VStack(spacing: 24) {
            if bubbleType != nil {
                MessageBubbleView(
                    message: currentMessage,
                    showTail: true,
                    isNew: isNew,
                    scrollViewFrame: .zero,
                    newMessageId: $newMessageId,
                    scrollVelocity: 0,
                    scrollPhase: .idle,
                    visibleMessageIndex: 0,
                    theme: .defaultTheme,
                    selectedImageData: $selectedImageData
                )
                .frame(height: 100)
            } else {
                // Empty space when no message
                Color.clear
                    .frame(height: 100)
            }

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button("None") {
                        bubbleType = nil
                        newMessageId = nil
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(bubbleType == nil ? .blue : .gray)

                    Button("Read") {
                        let wasNone = bubbleType == nil
                        bubbleType = .read
                        if wasNone {
                            newMessageId = messageId
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(bubbleType == .read ? .blue : .gray)

                    Button("Thinking") {
                        let wasNone = bubbleType == nil
                        bubbleType = .thinking
                        if wasNone {
                            newMessageId = messageId
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(bubbleType == .thinking ? .blue : .gray)

                    Button("Talking") {
                        let wasNone = bubbleType == nil
                        bubbleType = .talking
                        if wasNone {
                            newMessageId = messageId
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(bubbleType == .talking ? .blue : .gray)
                }
            }
            .padding(.top, 50)
        }
        .padding()
    }
}

#Preview("Inbound Message Bubble Morph") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()

    MessageBubblePreviewContainer()
        .environment(bubbleConfig)
        .environment(ChatData())
        .environment(ReactionsCoordinator())
}

#Preview("Message States") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    @Previewable @State var selectedImageData: ImageData?

    let currentUser = User(id: UUID(), name: "Edward", avatar: .edward)
    let maya = User(id: UUID(), name: "Maya Maria Antonia", avatar: .scarlet)

    ZStack {
        VStack(spacing: 20) {
            MessageBubbleView(
                message: Message(
                    content: .text(""),
                    from: maya,
                    isTypingIndicator: true,
                    bubbleType: .read
                ),
                showTail: true,
                theme: .theme1,
                selectedImageData: $selectedImageData
            )

            // 1. Inbound thinking
            MessageBubbleView(
                message: Message(
                    content: .text(""),
                    from: maya,
                    isTypingIndicator: true,
                    bubbleType: .thinking
                ),
                showTail: true,
                theme: .theme1,
                selectedImageData: $selectedImageData
            )

            // 2. Inbound talking
            MessageBubbleView(
                message: Message(
                    content: .text("Hey! How's it going?"),
                    from: maya,
                    bubbleType: .talking
                ),
                showTail: true,
                theme: .theme1,
                selectedImageData: $selectedImageData
            )

            // 3. Outbound talking
            MessageBubbleView(
                message: Message(
                    content: .text("Great! Just working on some code."),
                    from: currentUser
                ),
                showTail: true,
                theme: .theme1,
                selectedImageData: $selectedImageData
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
        .environment(bubbleConfig)
        .environment(ChatData())
        .environment(ReactionsCoordinator())

        // Image detail overlay
        if let imageData = selectedImageData {
            ImageDetailView(
                imageData: imageData,
                isPresented: Binding(
                    get: { selectedImageData != nil },
                    set: { newValue in
                        if !newValue {
                            withAnimation(.smooth(duration: 0.4)) {
                                selectedImageData = nil
                            }
                        }
                    }
                )
            )
            .zIndex(1)
        }
    }
}

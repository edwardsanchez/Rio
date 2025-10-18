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

import SwiftUI
import OSLog

struct MessageBubbleView: View {
    let message: Message
    let showTail: Bool
    let isNew: Bool
    let inputFieldFrame: CGRect
    let scrollViewFrame: CGRect
    @Binding var newMessageId: UUID?
    let scrollVelocity: CGFloat
    let scrollPhase: ScrollPhase
    let visibleMessageIndex: Int
    let theme: ChatTheme

    @State private var showTypingIndicatorContent = false
    @State private var showTalkingContent = false
    @State private var thinkingContentWidth: CGFloat = 0
    @State private var isWidthLocked = false
    @State private var widthUnlockWorkItem: DispatchWorkItem? = nil
    @State private var revealWorkItem: DispatchWorkItem? = nil
    @State private var includeTalkingTextInLayout = false
    @State private var displayedBubbleType: BubbleType
    @State private var modeDelayWorkItem: DispatchWorkItem? = nil
    
    @Environment(BubbleConfiguration.self) private var bubbleConfig

    init(
        message: Message,
        showTail: Bool = true,
        isNew: Bool = false,
        inputFieldFrame: CGRect = .zero,
        scrollViewFrame: CGRect = .zero,
        newMessageId: Binding<UUID?> = .constant(nil),
        scrollVelocity: CGFloat = 0,
        scrollPhase: ScrollPhase = .idle,
        visibleMessageIndex: Int = 0,
        theme: ChatTheme = .defaultTheme
    ) {
        self.message = message
        self.showTail = showTail
        self.isNew = isNew
        self.inputFieldFrame = inputFieldFrame
        self.scrollViewFrame = scrollViewFrame
        self._newMessageId = newMessageId
        self.scrollVelocity = scrollVelocity
        self.scrollPhase = scrollPhase
        self.visibleMessageIndex = visibleMessageIndex
        self.theme = theme
        // Initialize displayedBubbleType to match actual bubbleType
        self._displayedBubbleType = State(initialValue: message.bubbleType)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if message.messageType.isInbound {
                Group {
                    inboundAvatar
                        .opacity(inboundAvatarOpacity)
                    bubbleView(
                        textColor: theme.inboundTextColor,
                        backgroundColor: theme.inboundBackgroundColor
                    )
                }
                .opacity(bubbleOpacity)
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
        .offset(x: xOffset, y: rowYOffset + parallaxOffset)
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
                configureInitialContentState()
        }
        .onChange(of: message.bubbleType) { oldType, newType in
            handleBubbleTypeChange(from: oldType, to: newType)
        }
        .onDisappear {
            cancelPendingContentTransitions()
        }
    }

    // Computed properties for positioning and animation
    private var frameAlignment: Alignment {
        if message.messageType.isInbound {
            return .leading
        } else {
            return isNew ? .leading : .trailing
        }
    }

    private var rowYOffset: CGFloat {
        guard isNew else { return 0 }

        if message.messageType.isInbound {
            // Read state should not slide up, only scale avatar
            // Thinking and Talking states slide up from 20px below
            return displayedBubbleType.isRead ? 0 : 20
        } else {
            return calculateYOffset()
        }
    }

    private var bubbleYOffset: CGFloat {
        guard isNew else { return 0 }
        return 0
    }

    private var xOffset: CGFloat {
        guard isNew && message.messageType.isOutbound else { return 0 }

        let logger = Logger(subsystem: "Rio", category: "Animation")

        // Both frames are now captured in the same coordinate space (MainContainer)
        logger.debug("🎯 TextField frame in MainContainer: \(String(describing: inputFieldFrame))")
        logger.debug("🎯 Scroll view frame in MainContainer: \(String(describing: scrollViewFrame))")

        let textFieldRelativeToContent = inputFieldFrame.minX

        logger.debug("🎯 TextField relative to content: \(textFieldRelativeToContent)")

        return textFieldRelativeToContent
    }

    private var bubbleOpacity: Double {
        guard message.messageType.isInbound else { return 1 }
        // For read state, bubble is always hidden (handled by BubbleView)
        // For thinking/talking, fade in when new
        if displayedBubbleType.isRead {
            return 1  // Let BubbleView handle opacity
        }
        return isNew ? 0 : 1
    }

    private var inboundAvatarOpacity: Double {
        guard message.messageType.isInbound else { return 1 }
        guard isNew else { return 1 }
        // For read state, avatar scales from 0, don't use opacity fade
        // For thinking/talking, use opacity fade
        return displayedBubbleType.isRead ? 1 : 0
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

    private func calculateYOffset() -> CGFloat {
        // Both frames are in global coordinates
        // Calculate the vertical distance from the input field to the scroll view
        // The message bubble needs to appear at the input field's vertical position

        // Calculate where the input field is relative to the scroll view's bottom
        let inputFieldBottom = inputFieldFrame.maxY
        let scrollViewBottom = scrollViewFrame.maxY

        // The offset moves the bubble UP from its normal position to align with input field
        let offset = inputFieldBottom - scrollViewBottom

        let logger = Logger(subsystem: "Rio", category: "Animation")
        logger.debug("🎯 Input field bottom: \(inputFieldBottom)")
        logger.debug("🎯 Scroll view bottom: \(scrollViewBottom)")
        logger.debug("🎯 Y Offset: \(offset)")

        return offset
    }

    private var inboundAvatar: some View {
        Group {
            if let avatar = message.user.avatar {
                let avatarSize: CGFloat = displayedBubbleType.isRead ? 20 : 40
                let avatarFrameHeight: CGFloat = displayedBubbleType.isRead ? 0 : 40
                let avatarOffsetX: CGFloat = displayedBubbleType.isRead ? 9 : 0

                Image(avatar)
                    .resizable()
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(.circle)
                    .frame(height: avatarFrameHeight)
                    .scaleEffect(isNew && displayedBubbleType.isRead ? 0 : 1, anchor: .center)
                    .opacity(isNew && displayedBubbleType.isRead ? 0 : 1)
                    .offset(y: 10)
                    .offset(x: avatarOffsetX)
                    .animation(.bouncy(duration: 0.3), value: isNew)
                    .animation(.bouncy(duration: 0.3), value: displayedBubbleType)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 40, height: 40)
            }
        }
    }

    var typingIndicatorMessages: [String] {
        return [
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
        let avatarWidth: CGFloat = message.messageType.isInbound ? 40 : 0
        let bubbleSpacing: CGFloat = message.messageType.isInbound ? 12 : 0
        let trailingSpacer: CGFloat = message.messageType.isInbound ? 10 : 0

        let width = scrollWidth - horizontalContentInset - avatarWidth - bubbleSpacing - trailingSpacer
        return width > 0 ? width : nil
    }


    @ViewBuilder
    private func bubbleView(
        textColor: Color,
        backgroundColor: Color
    ) -> some View {

        let hasContent = message.content.hasContent

        ZStack(alignment: .leading) {
            Text("H") //Measure Spacer
                .opacity(0)

            if hasContent && includeTalkingTextInLayout {
                MessageContentView(
                    content: message.content,
                    textColor: textColor
                )
                    .opacity(showTalkingContent ? 1 : 0)
            }
        }
        .animation(.smooth(duration: 0.2), value: showTypingIndicatorContent)
        .animation(.smooth(duration: 0.35), value: showTalkingContent)
        .frame(width: lockedWidth, alignment: .leading)
        .chatBubble(
            messageType: message.messageType,
            backgroundColor: backgroundColor,
            showTail: showTail,
            bubbleType: message.bubbleType,
            layoutType: displayedBubbleType,
            animationWidth: outboundAnimationWidth,
            animationHeight: outboundAnimationHeight,
            isVisible: !message.content.isEmoji
        )
        .overlay(alignment: .leading) {
            TypingIndicatorView(isVisible: showTypingIndicatorContent)
                .padding(.leading, 20)
        }
    }

    private var lockedWidth: CGFloat? {
        guard isWidthLocked, thinkingContentWidth > 0 else { return nil }
        return thinkingContentWidth
    }

    //DO NOT DELETE
//    private func updateThinkingWidth(_ width: CGFloat) {
//        guard width > 0 else { return }
//        if abs(thinkingContentWidth - width) > 0.5 {
//            thinkingContentWidth = width
//        }
//        if message.bubbleType == .thinking {
//            isWidthLocked = true
//        }
//    }

    private func configureInitialContentState() {
        cancelPendingContentTransitions()
        switch message.bubbleType {
        case .thinking:
            isWidthLocked = true
            showTypingIndicatorContent = true
            showTalkingContent = false
            includeTalkingTextInLayout = false
        case .talking:
            isWidthLocked = false
            showTypingIndicatorContent = false
            showTalkingContent = message.content.hasContent
            includeTalkingTextInLayout = message.content.hasContent
        case .read:
            isWidthLocked = false
            showTypingIndicatorContent = false
            showTalkingContent = false
            includeTalkingTextInLayout = false
        }
    }

    private func handleBubbleTypeChange(from oldType: BubbleType, to newType: BubbleType) {
        guard oldType != newType else { return }
        cancelPendingContentTransitions()
        
        // Handle displayedBubbleType delay for thinking→read transition
        if oldType == .thinking && newType == .read {
            // Keep displayedBubbleType at .thinking during explosion
            // It will be updated to .read after explosion completes
            startThinkingToReadTransition()
            scheduleDisplayedTypeUpdate(to: newType, delay: bubbleConfig.explosionDuration)
        } else if oldType == .read && newType == .talking {
            // Handle displayedBubbleType delay for read→talking transition
            // Use a tiny delay (0.02s) to let geometry settle before showing bubble
            // This ensures the bubble appears with its final size and tail position already in place
            startReadToTalkingTransition()
            scheduleDisplayedTypeUpdate(to: newType, delay: 0.02)
        } else {
            // For all other transitions, update displayedBubbleType immediately
            displayedBubbleType = newType
            
            if oldType == .thinking && newType == .talking {
                startTalkingTransition()
            } else if oldType == .talking && newType == .thinking {
                startThinkingState()
            } else if oldType == .read && newType == .thinking {
                startReadToThinkingTransition()
            } else if oldType == .talking && newType == .read {
                startTalkingToReadTransition()
            } else {
                configureInitialContentState()
            }
        }
    }

    private func startTalkingTransition() {
        if !message.content.hasContent {
            isWidthLocked = false
            showTypingIndicatorContent = false
            showTalkingContent = false
            includeTalkingTextInLayout = false
            return
        }

        if thinkingContentWidth > 0 {
            isWidthLocked = true
        }

        withAnimation(.smooth(duration: 0.2)) {
            showTypingIndicatorContent = false
        }

        showTalkingContent = false
        includeTalkingTextInLayout = false

        scheduleTextLayoutInclusion()
        scheduleWidthUnlock()
        scheduleTalkingReveal()
    }

    private func startThinkingState() {
        isWidthLocked = true
        showTalkingContent = false
        includeTalkingTextInLayout = false
        withAnimation(.smooth(duration: 0.2)) {
            showTypingIndicatorContent = true
        }
    }
    
    private func startReadToThinkingTransition() {
        // Delay typing indicator until read→thinking animation completes
        isWidthLocked = true
        showTalkingContent = false
        includeTalkingTextInLayout = false
        
        // Wait for the bubble animation to complete before showing typing indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + bubbleConfig.readToThinkingDuration / 3) {
            withAnimation(.smooth(duration: 0.3)) {
                self.showTypingIndicatorContent = true
            }
        }
    }
    
    private func startReadToTalkingTransition() {
        // Quick opacity fade when going from read to talking (fast response)
        if !message.content.hasContent {
            isWidthLocked = false
            showTypingIndicatorContent = false
            showTalkingContent = false
            includeTalkingTextInLayout = false
            return
        }
        
        isWidthLocked = false
        showTypingIndicatorContent = false
        includeTalkingTextInLayout = true
        
        // Quick fade in without offset animation
        withAnimation(.smooth(duration: 0.3)) {
            showTalkingContent = true
        }
    }
    
    private func startThinkingToReadTransition() {
        // Immediately hide typing indicator (no animation) when bubbleType changes to read
        showTypingIndicatorContent = false

        // After explosion completes (managed by displayedBubbleType delay), clean up remaining state
        DispatchQueue.main.asyncAfter(deadline: .now() + bubbleConfig.explosionDuration) {
            self.isWidthLocked = false
            self.showTalkingContent = false
            self.includeTalkingTextInLayout = false
        }
    }
    
    //This should only happen if the message is unsent
    private func startTalkingToReadTransition() {
        // Fade out talking content and go to read state
        withAnimation(.smooth(duration: 0.3)) {
            showTalkingContent = false
        }
        isWidthLocked = false
        showTypingIndicatorContent = false
        includeTalkingTextInLayout = false
    }

    private func scheduleTextLayoutInclusion() {
        // Include text in layout after morph phase, so it affects height during resize phase
        DispatchQueue.main.asyncAfter(deadline: .now() + bubbleConfig.morphDuration) {
            includeTalkingTextInLayout = true
        }
    }

    private func scheduleWidthUnlock() {
        let unlockItem = DispatchWorkItem {
            withAnimation(.smooth(duration: bubbleConfig.resizeCutoffDuration)) {
                isWidthLocked = false
            }
        }

        widthUnlockWorkItem = unlockItem
        DispatchQueue.main.asyncAfter(deadline: .now() + bubbleConfig.morphDuration) {
            guard !unlockItem.isCancelled else { return }
            unlockItem.perform()
            widthUnlockWorkItem = nil
        }
    }

    private func scheduleTalkingReveal() {
        let revealItem = DispatchWorkItem {
            withAnimation(.smooth(duration: 0.35)) {
                showTalkingContent = true
            }
        }

        revealWorkItem = revealItem
        DispatchQueue.main.asyncAfter(deadline: .now() + bubbleConfig.textRevealDelay) {
            guard !revealItem.isCancelled else { return }
            revealItem.perform()
            revealWorkItem = nil
        }
    }

    private func scheduleDisplayedTypeUpdate(to type: BubbleType, delay: TimeInterval) {
        // Cancel any pending bubbleType updates
        modeDelayWorkItem?.cancel()
        
        let delayItem = DispatchWorkItem {
            self.displayedBubbleType = type
        }
        
        modeDelayWorkItem = delayItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard !delayItem.isCancelled else { return }
            delayItem.perform()
            self.modeDelayWorkItem = nil
        }
    }

    private func cancelPendingContentTransitions() {
        widthUnlockWorkItem?.cancel()
        widthUnlockWorkItem = nil
        revealWorkItem?.cancel()
        revealWorkItem = nil
        modeDelayWorkItem?.cancel()
        modeDelayWorkItem = nil
    }

    private var outboundAnimationWidth: CGFloat? {
        guard message.messageType.isOutbound, isNew else { return nil }
        return inputFieldFrame.width
    }

    private var outboundAnimationHeight: CGFloat? {
        guard message.messageType.isOutbound, isNew else { return nil }
        return inputFieldFrame.height
    }
}

private struct MessageBubblePreviewContainer: View {
    @State private var bubbleType: BubbleType? = .read
    @State private var newMessageId: UUID? = nil
    
    // Use a stable message ID that persists across state changes
    private let messageId = UUID()
    private let sampleUser = User(id: UUID(), name: "Maya", avatar: .edward)
    
    private var currentMessage: Message {
        switch bubbleType {
        case .read:
            Message(
                id: messageId,
                content: .text(""),
                user: sampleUser,
                isTypingIndicator: true,
                messageType: .inbound(.read)
            )
        case .thinking:
            Message(
                id: messageId,
                content: .text(""),
                user: sampleUser,
                isTypingIndicator: true,
                messageType: .inbound(.thinking)
            )
        case .talking:
            Message(
                id: messageId,
                content: .text("How are you?"),
                user: sampleUser,
                messageType: .inbound(.talking)
            )
        case .none:
            // Placeholder - won't be shown
            Message(
                id: messageId,
                content: .text(""),
                user: sampleUser,
                messageType: .inbound(.talking)
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
                    inputFieldFrame: .zero,
                    scrollViewFrame: .zero,
                    newMessageId: $newMessageId,
                    scrollVelocity: 0,
                    scrollPhase: .idle,
                    visibleMessageIndex: 0,
                    theme: .defaultTheme
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
}

#Preview("Message States") {
    @Previewable @State var bubbleConfig = BubbleConfiguration()
    
    VStack(spacing: 20) {
        
        MessageBubbleView(
            message: Message(
                content: .text(""),
                user: User(id: UUID(), name: "Maya", avatar: .scarlet),
                isTypingIndicator: true,
                messageType: .inbound(.read)
            ),
            showTail: true,
            theme: .theme1
        )
        
        // 1. Inbound thinking
        MessageBubbleView(
            message: Message(
                content: .text(""),
                user: User(id: UUID(), name: "Maya", avatar: .scarlet),
                isTypingIndicator: true,
                messageType: .inbound(.thinking)
            ),
            showTail: true,
            theme: .theme1
        )

        // 2. Inbound talking
        MessageBubbleView(
            message: Message(
                content: .text("Hey! How's it going?"),
                user: User(id: UUID(), name: "Maya", avatar: .scarlet),
                messageType: .inbound(.talking)
            ),
            showTail: true,
            theme: .theme1
        )

        // 3. Outbound talking
        MessageBubbleView(
            message: Message(
                content: .text("Great! Just working on some code."),
                user: User(id: UUID(), name: "Edward", avatar: .edward),
                messageType: .outbound
            ),
            showTail: true,
            theme: .theme1
        )
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 40)
    .environment(bubbleConfig)
}

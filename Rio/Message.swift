//
//  Message.swift
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
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if message.messageType == .inbound {
                inboundAvatar
                    .opacity(inboundAvatarOpacity)
                bubbleView(
                    textColor: theme.inboundTextColor,
                    backgroundColor: theme.inboundBackgroundColor
                )
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
        .onAppear {
            if isNew {
                withAnimation(.smooth(duration: 0.5)) {
                    newMessageId = nil
                }
            }
        }
    }

    // Computed properties for positioning and animation
    private var frameAlignment: Alignment {
        if message.messageType == .inbound {
            return .leading
        } else {
            return isNew ? .leading : .trailing
        }
    }

    private var rowYOffset: CGFloat {
        guard isNew else { return 0 }

        switch message.messageType {
        case .inbound:
            return 0
        case .outbound:
            return calculateYOffset()
        }
    }

    private var bubbleYOffset: CGFloat {
        guard isNew else { return 0 }
        return 0
    }

    private var xOffset: CGFloat {
        guard isNew && message.messageType == .outbound else { return 0 }

        let logger = Logger(subsystem: "Rio", category: "Animation")

        // Both frames are now captured in the same coordinate space (MainContainer)
        logger.debug("🎯 TextField frame in MainContainer: \(String(describing: inputFieldFrame))")
        logger.debug("🎯 Scroll view frame in MainContainer: \(String(describing: scrollViewFrame))")

        let textFieldRelativeToContent = inputFieldFrame.minX

        logger.debug("🎯 TextField relative to content: \(textFieldRelativeToContent)")

        return textFieldRelativeToContent
    }

    private var bubbleOpacity: Double {
        guard message.messageType == .inbound else { return 1 }
        return isNew ? 0 : 1
    }

    private var inboundAvatarOpacity: Double {
        guard message.messageType == .inbound else { return 1 }
        guard isNew else { return 1 }
        return 0
    }

    // Physics-based parallax offset for cascading jelly effect
    private var parallaxOffset: CGFloat {
        // Don't apply parallax during new message animations
        guard !isNew else { return 0 }

        // Use shared parallax calculator
        let calculator = ParallaxCalculator(
            scrollVelocity: scrollVelocity,
            scrollPhase: scrollPhase,
            visibleMessageIndex: visibleMessageIndex
        )
        return calculator.offset
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
                Image(avatar)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .clipShape(.circle)
                    .offset(y: 10)
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
        let avatarWidth: CGFloat = message.messageType == .inbound ? 40 : 0
        let bubbleSpacing: CGFloat = message.messageType == .inbound ? 12 : 0
        let trailingSpacer: CGFloat = message.messageType == .inbound ? 10 : 0

        let width = scrollWidth - horizontalContentInset - avatarWidth - bubbleSpacing - trailingSpacer
        return width > 0 ? width : nil
    }


    @ViewBuilder
    private func bubbleView(
        textColor: Color,
        backgroundColor: Color
    ) -> some View {

        Group {
            if message.isTypingIndicator {
                TypingIndicatorView()
                    .transition(.opacity.animation(.easeIn(duration: 0.2)))
            } else {
                Text(message.text)
                    .foregroundStyle(textColor)
                    // Prevent horizontal expansion while allowing vertical growth
                    // This ensures text wraps properly within the bubble
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.animation(.smooth(duration: 0.2)))
            }
        }
        .chatBubble(
            messageType: message.messageType,
            backgroundColor: backgroundColor,
            showTail: showTail,
            bubbleMode: message.bubbleMode,
            animationWidth: outboundAnimationWidth,
            animationHeight: outboundAnimationHeight
        )
    }

    private var outboundAnimationWidth: CGFloat? {
        guard message.messageType == .outbound, isNew else { return nil }
        return inputFieldFrame.width
    }

    private var outboundAnimationHeight: CGFloat? {
        guard message.messageType == .outbound, isNew else { return nil }
        return inputFieldFrame.height
    }
}

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

// MARK: - Shared Parallax Effect Logic

/// Calculates the cascading jelly parallax offset for scroll-based animations
struct ParallaxCalculator {
    let scrollVelocity: CGFloat
    let scrollPhase: ScrollPhase
    let visibleMessageIndex: Int

    var offset: CGFloat {
        // Ensure we have a valid scroll velocity
        guard scrollVelocity != 0 else { return 0 }

        // Only apply cascading effect during active scrolling phases
        let shouldApplyCascade = scrollPhase == .tracking || scrollPhase == .decelerating

        if shouldApplyCascade {
            // Create cascading effect based on visible message position
            // Messages lower in the visible area get higher multipliers
            let baseMultiplier: CGFloat = 0.8
            let cascadeIncrement: CGFloat = 0.2
            let maxCascadeMessages = 20 // Limit cascade to prevent excessive multipliers

            // Calculate position-based multiplier (clamped to prevent extreme values)
            let cascadePosition = min(visibleMessageIndex, maxCascadeMessages)
            let multiplier = baseMultiplier + (CGFloat(cascadePosition) * cascadeIncrement)

            return -scrollVelocity * multiplier
        } else {
            // Use consistent multiplier when not actively scrolling
            let multiplier: CGFloat = 0.2
            return -scrollVelocity * multiplier
        }
    }
}

struct User: Identifiable {
    let id: UUID
    let name: String
    let avatar: ImageResource?
}

struct Chat: Identifiable {
    let id: UUID
    let title: String
    let participants: [User] // Always includes the current "outbound" user
    let messages: [Message]

    init(id: UUID = UUID(), title: String, participants: [User], messages: [Message] = []) {
        self.id = id
        self.title = title
        self.participants = participants
        self.messages = messages
    }
}

// Component to handle the entire message list with date headers
struct MessageListView: View {
    let messages: [Message]
    @Binding var newMessageId: UUID?
    let inputFieldFrame: CGRect
    let scrollViewFrame: CGRect
    let scrollVelocity: CGFloat
    let scrollPhase: ScrollPhase

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(zip(messages.indices, messages)), id: \.1.id) { index, message in
                let isNew = message.id == newMessageId
                var isLastMessageInChat: Bool { messages.last!.id == message.id }
                let showTail = shouldShowTail(at: index)

                VStack(spacing: 5) {
                    if shouldShowDateHeader(at: index) {
                        DateHeaderView(
                            date: message.date,
                            scrollVelocity: scrollVelocity,
                            scrollPhase: scrollPhase,
                            visibleMessageIndex: index
                        )
                        .padding(.vertical, 5)
                    }

                    MessageBubbleView(
                        message: message,
                        showTail: showTail,
                        isNew: isNew,
                        inputFieldFrame: inputFieldFrame,
                        scrollViewFrame: scrollViewFrame,
                        newMessageId: $newMessageId,
                        scrollVelocity: scrollVelocity,
                        scrollPhase: scrollPhase,
                        visibleMessageIndex: index
                    )
                    .padding(.bottom, isLastMessageInChat ? 20 : (showTail ? 15 : 5))
                    .id(message.id) // Essential for ScrollPosition to work
                }
            }
        }
        .scrollTargetLayout() // Optimizes scrolling performance for iOS 18+
    }

    private func shouldShowTail(at index: Int) -> Bool { //Move inside Message Bubble
        let tailContinuationThreshold: TimeInterval = 300
        let current = messages[index]

        // Check if this is the last message overall
        let isLastMessage = index == messages.count - 1

        if isLastMessage {
            // Last message always shows tail
            return true
        }

        let next = messages[index + 1]
        let isNextSameUser = current.user.id == next.user.id

        // For outbound messages (from Edward), only show tail if it's the last in a sequence
        if !current.isInbound {
            // Only show tail if the next message is from a different user (end of outbound sequence)
            return !isNextSameUser
        }

        // For inbound messages, keep the existing logic with time threshold
        let timeDifference = next.date.timeIntervalSince(current.date)
        let isWithinThreshold = abs(timeDifference) <= tailContinuationThreshold

        // Show tail if next message is from different user OR if time gap is too large
        return !isNextSameUser || !isWithinThreshold
    }

    private func shouldShowDateHeader(at index: Int) -> Bool { //keep here
        guard index > 0 else {
            // Always show date header for the first message
            return true
        }

        // Use 5 seconds for testing, change to 3600 (1 hour) for production
        let dateHeaderThreshold: TimeInterval = 3600

        let current = messages[index]
        let previous = messages[index - 1]
        let timeDifference = current.date.timeIntervalSince(previous.date)

        // Show date header if messages are more than threshold apart
        return abs(timeDifference) > dateHeaderThreshold
    }
}

struct DateHeaderView: View {
    var date: Date
    let scrollVelocity: CGFloat
    let scrollPhase: ScrollPhase
    let visibleMessageIndex: Int

    init(date: Date, scrollVelocity: CGFloat = 0, scrollPhase: ScrollPhase = .idle, visibleMessageIndex: Int = 0) {
        self.date = date
        self.scrollVelocity = scrollVelocity
        self.scrollPhase = scrollPhase
        self.visibleMessageIndex = visibleMessageIndex
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }

    private var parallaxCalculator: ParallaxCalculator {
        ParallaxCalculator(
            scrollVelocity: scrollVelocity,
            scrollPhase: scrollPhase,
            visibleMessageIndex: visibleMessageIndex
        )
    }

    var body: some View {
        Text(dateFormatter.string(from: date))
            .font(.caption)
            .foregroundColor(.secondary)
            .offset(y: parallaxCalculator.offset)
            .animation(.interactiveSpring, value: parallaxCalculator.offset)
    }
}

// MARK: - Bubble Tail Type

enum BubbleTailType {
    case talking
    case thinking
}

// MARK: - Typing Indicator View

struct TypingIndicatorView: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.primary.opacity(0.4))
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        .smooth(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.25),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct Message: Identifiable {
    let id: UUID
    let text: String
    let user: User
    let date: Date
    let isTypingIndicator: Bool

    var isInbound: Bool {
        // We'll determine this based on the user - for now, any user that isn't "Edward" is inbound
        user.name != "Edward"
    }

    init(id: UUID = UUID(), text: String, user: User, date: Date = Date.now, isTypingIndicator: Bool = false) {
        self.id = id
        self.text = text
        self.user = user
        self.date = date
        self.isTypingIndicator = isTypingIndicator
    }
}

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

    init(message: Message, showTail: Bool = true, isNew: Bool = false, inputFieldFrame: CGRect = .zero, scrollViewFrame: CGRect = .zero, newMessageId: Binding<UUID?> = .constant(nil), scrollVelocity: CGFloat = 0, scrollPhase: ScrollPhase = .idle, visibleMessageIndex: Int = 0) {
        self.message = message
        self.showTail = showTail
        self.isNew = isNew
        self.inputFieldFrame = inputFieldFrame
        self.scrollViewFrame = scrollViewFrame
        self._newMessageId = newMessageId
        self.scrollVelocity = scrollVelocity
        self.scrollPhase = scrollPhase
        self.visibleMessageIndex = visibleMessageIndex
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if message.isInbound {
                inboundAvatar
                bubbleView(
                    textColor: .primary,
                    backgroundColor: .userBubble,
                    tailAlignment: .bottomLeading,
                    tailOffset: CGSize(width: 5, height: 5.5),
                    tailRotation: Angle(degrees: 180),
                    showTail: showTail,
                    backgroundOpacity: 0.6,
                    width: nil,
                    height: nil
                )
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
                    textColor: .white,
                    backgroundColor: .accentColor,
                    tailAlignment: .bottomTrailing,
                    tailOffset: CGSize(width: -5, height: 5.5),
                    tailRotation: .zero,
                    showTail: showTail,
                    backgroundOpacity: 1,
                    width: isNew ? inputFieldFrame.width : nil,
                    height: isNew ? inputFieldFrame.height : nil
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .offset(x: xOffset, y: yOffset + parallaxOffset)
        .animation(.interactiveSpring, value: parallaxOffset)
        .opacity(opacity)
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
        if message.isInbound {
            return .leading
        } else {
            return isNew ? .leading : .trailing
        }
    }

    private var yOffset: CGFloat {
        guard isNew else { return 0 }

        if message.isInbound {
            return 50
        } else {
            return calculateYOffset()
        }
    }

    private var xOffset: CGFloat {
        guard isNew && !message.isInbound else { return 0 }

        let logger = Logger(subsystem: "Rio", category: "Animation")

        // Both frames are now captured in the same coordinate space (MainContainer)
        logger.debug("🎯 TextField frame in MainContainer: \(String(describing: inputFieldFrame))")
        logger.debug("🎯 Scroll view frame in MainContainer: \(String(describing: scrollViewFrame))")

        let textFieldRelativeToContent = inputFieldFrame.minX

        logger.debug("🎯 TextField relative to content: \(textFieldRelativeToContent)")

        return textFieldRelativeToContent
    }

    private var opacity: Double {
        if message.isInbound && isNew {
            return 0
        }
        return 1
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
        let avatarWidth: CGFloat = message.isInbound ? 40 : 0
        let bubbleSpacing: CGFloat = message.isInbound ? 12 : 0
        let trailingSpacer: CGFloat = message.isInbound ? 10 : 0

        let width = scrollWidth - horizontalContentInset - avatarWidth - bubbleSpacing - trailingSpacer
        return width > 0 ? width : nil
    }


    @ViewBuilder
    private func bubbleView(
        textColor: Color,
        backgroundColor: Color,

        tailAlignment: Alignment,
        tailOffset: CGSize,
        tailRotation: Angle,
        showTail: Bool,
        backgroundOpacity: Double,
        width: CGFloat?,
        height: CGFloat?
    ) -> some View {

        Group {
            if message.isTypingIndicator {
                TypingIndicatorView()
                    .chatBubble(
                        backgroundColor: backgroundColor,
                        tailAlignment: tailAlignment,
                        tailOffset: tailOffset,
                        tailRotation: tailRotation,
                        showTail: showTail,
                        backgroundOpacity: backgroundOpacity,
                        width: width,
                        height: height,
                        tailType: .thinking
                    )
            } else {
                Text(message.text)
                    .foregroundStyle(textColor)
                    // Prevent horizontal expansion while allowing vertical growth
                    // This ensures text wraps properly within the bubble
                    .fixedSize(horizontal: false, vertical: true)
                    .chatBubble(
                        backgroundColor: backgroundColor,
                        tailAlignment: tailAlignment,
                        tailOffset: tailOffset,
                        tailRotation: tailRotation,
                        showTail: showTail,
                        backgroundOpacity: backgroundOpacity,
                        width: width,
                        height: height,
                        tailType: .talking
                    )
            }
        }

    }
}

private struct ChatBubbleModifier: ViewModifier {
    let backgroundColor: Color
    let tailAlignment: Alignment
    let tailOffset: CGSize
    let tailRotation: Angle
    let showTail: Bool
    let backgroundOpacity: Double
    let width: CGFloat?
    let height: CGFloat?
    let tailType: BubbleTailType

    func body(content: Content) -> some View {
        content
            .padding()
            .background(alignment: .leading) {
                backgroundView
            }
    }

    @ViewBuilder
    private var backgroundView: some View {
        let base = RoundedRectangle(cornerRadius: 20)
            .fill(backgroundColor)
            .frame(width: width, height: height)
            .overlay(alignment: tailAlignment) {
                tailView
            }

        base
            .compositingGroup()
            .opacity(backgroundOpacity)
    }

    @ViewBuilder
    private var tailView: some View {
        switch tailType {
        case .talking:
            Image(.cartouche)
                .resizable()
                .frame(width: 15, height: 15)
                .rotation3DEffect(tailRotation, axis: (x: 0, y: 1, z: 0))
                .offset(x: tailOffset.width, y: tailOffset.height)
                .foregroundStyle(backgroundColor)
                .opacity(showTail ? 1 : 0)

        case .thinking:
            // Thinking bubble tail with two circles
            ZStack(alignment: tailAlignment == .bottomLeading ? .bottomLeading : .bottomTrailing) {
                // Larger circle (closer to bubble)
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 14, height: 14)
                    .offset(
                        x: tailAlignment == .bottomLeading ? 0 : -8,
                        y: 0
                    )

                // Smaller circle (further from bubble)
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 8, height: 8)
                    .offset(
                        x: tailAlignment == .bottomLeading ? -6 : 6,
                        y: 9
                    )
            }
            .opacity(showTail ? 1 : 0)
        }
    }
}

private extension View {
    func chatBubble(
        backgroundColor: Color,
        tailAlignment: Alignment,
        tailOffset: CGSize,
        tailRotation: Angle,
        showTail: Bool,
        backgroundOpacity: Double,
        width: CGFloat?,
        height: CGFloat?,
        tailType: BubbleTailType = .talking
    ) -> some View {
        modifier(
            ChatBubbleModifier(
                backgroundColor: backgroundColor,
                tailAlignment: tailAlignment,
                tailOffset: tailOffset,
                tailRotation: tailRotation,
                showTail: showTail,
                backgroundOpacity: backgroundOpacity,
                width: width,
                height: height,
                tailType: tailType
            )
        )
    }
}

#Preview("Thinking Bubble") {
    VStack(spacing: 20) {
        // Thinking bubble (inbound style)
        Text("Thinking about your question...")
            .foregroundStyle(.primary)
            .chatBubble(
                backgroundColor: .userBubble,
                tailAlignment: .bottomLeading,
                tailOffset: CGSize(width: 5, height: 5.5),
                tailRotation: Angle(degrees: 180),
                showTail: true,
                backgroundOpacity: 0.6,
                width: nil,
                height: nil,
                tailType: .thinking
            )

        // Talking bubble for comparison (inbound style)
        Text("Regular message")
            .foregroundStyle(.primary)
            .chatBubble(
                backgroundColor: .userBubble,
                tailAlignment: .bottomLeading,
                tailOffset: CGSize(width: 5, height: 5.5),
                tailRotation: Angle(degrees: 180),
                showTail: true,
                backgroundOpacity: 0.6,
                width: nil,
                height: nil,
                tailType: .talking
            )
    }
    .padding()
}

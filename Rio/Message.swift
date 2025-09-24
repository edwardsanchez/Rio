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

    var body: some View {
        VStack(spacing: 15) {
            ForEach(messages) { message in
                let index = messages.firstIndex(where: { $0.id == message.id }) ?? 0
                let isNew = message.id == newMessageId

                VStack(spacing: 5) {
                    if shouldShowDateHeader(at: index) {
                        DateHeaderView(date: message.date)
                            .padding(.vertical, 5)
                    }

                    MessageBubble(
                        message: message,
                        showTail: shouldShowTail(at: index),
                        isNew: isNew,
                        inputFieldFrame: inputFieldFrame,
                        scrollViewFrame: scrollViewFrame,
                        newMessageId: $newMessageId
                    )
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

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }

    var body: some View {
        Text(dateFormatter.string(from: date))
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

struct Message: Identifiable {
    let id: UUID
    let text: String
    let user: User
    let date: Date

    var isInbound: Bool {
        // We'll determine this based on the user - for now, any user that isn't "Edward" is inbound
        user.name != "Edward"
    }

    init(id: UUID = UUID(), text: String, user: User, date: Date = Date.now) {
        self.id = id
        self.text = text
        self.user = user
        self.date = date
    }
}

struct MessageBubble: View {
    let message: Message
    let showTail: Bool
    let isNew: Bool
    let inputFieldFrame: CGRect
    let scrollViewFrame: CGRect
    @Binding var newMessageId: UUID?

    init(message: Message, showTail: Bool = true, isNew: Bool = false, inputFieldFrame: CGRect = .zero, scrollViewFrame: CGRect = .zero, newMessageId: Binding<UUID?> = .constant(nil)) {
        self.message = message
        self.showTail = showTail
        self.isNew = isNew
        self.inputFieldFrame = inputFieldFrame
        self.scrollViewFrame = scrollViewFrame
        self._newMessageId = newMessageId
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
        .offset(y: yOffset)
        .opacity(opacity)
        .onAppear {
            if isNew {
                withAnimation(animationStyle) {
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

    private var opacity: Double {
        if message.isInbound && isNew {
            return 0
        }
        return 1
    }

    private var animationStyle: Animation {
        if message.isInbound {
            return .spring(duration: 0.5)
        } else {
            return .smooth(duration: 0.5)
        }
    }

    private func calculateYOffset() -> CGFloat {
        // Calculate the vertical distance from the input field to where the message should appear
        let inputFieldBottom = inputFieldFrame.maxY
        let scrollViewBottom = scrollViewFrame.maxY
        return max(0, inputFieldBottom - scrollViewBottom)
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
                height: height
            )
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
                Image(.cartouche)
                    .resizable()
                    .frame(width: 15, height: 15)
                    .rotation3DEffect(tailRotation, axis: (x: 0, y: 1, z: 0))
                    .offset(x: tailOffset.width, y: tailOffset.height)
                    .foregroundStyle(backgroundColor)
                    .opacity(showTail ? 1 : 0)
            }
        
        base
            .compositingGroup()
            .opacity(backgroundOpacity)
            
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
        height: CGFloat?
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
                height: height
            )
        )
    }
}

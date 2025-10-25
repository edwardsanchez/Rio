//
//  MessageListView.swift
//  Rio
//
//  Created by Edward Sanchez on 10/8/25.
//

import SwiftUI

// Component to handle the entire message list with date headers
struct MessageListView: View {
    let messages: [Message]
    @Binding var newMessageId: UUID?
    let inputFieldFrame: CGRect
    let scrollViewFrame: CGRect
    let scrollVelocity: CGFloat
    let scrollPhase: ScrollPhase
    let theme: ChatTheme
    @Binding var selectedImageData: ImageData?
    @Environment(ChatData.self) private var chatData

    var body: some View {
        LazyVStack(spacing: 0) {
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
                        visibleMessageIndex: index,
                        theme: theme,
                        currentUser: chatData.currentUser,
                        selectedImageData: $selectedImageData
                    )
                    .padding(.bottom, isLastMessageInChat ? 20 : (showTail ? 15 : 5))
                    .id(message.id) // Essential for ScrollPosition to work
                }
            }
        }
        .scrollTargetLayout() // Optimizes scrolling performance for iOS 18+
    }

    private func shouldShowTail(at index: Int) -> Bool { // Move inside Message Bubble
        let tailContinuationThreshold: TimeInterval = 300
        let current = messages[index]

        // Check if this is the last message overall
        let isLastMessage = index == messages.count - 1

        if isLastMessage {
            // Last message always shows tail
            return true
        }

        // Show tail if there's a date header between current and next message
        if shouldShowDateHeader(at: index + 1) {
            return true
        }

        let next = messages[index + 1]
        let isNextSameUser = current.user.id == next.user.id

        // For outbound messages (from current user), only show tail if it's the last in a sequence
        if current.messageType(currentUser: chatData.currentUser).isOutbound {
            // Only show tail if the next message is from a different user (end of outbound sequence)
            return !isNextSameUser
        }

        // For inbound messages, keep the existing logic with time threshold
        let timeDifference = next.date.timeIntervalSince(current.date)
        let isWithinThreshold = abs(timeDifference) <= tailContinuationThreshold

        // Show tail if next message is from different user OR if time gap is too large
        return !isNextSameUser || !isWithinThreshold
    }

    private func shouldShowDateHeader(at index: Int) -> Bool { // keep here
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
